import UIKit
import AVFoundation
import MediaPlayer

/// 재생 상태 변화를 VC에 전달하는 Delegate.
protocol PlayerManagerDelegate: AnyObject {
    func playerManager(_ manager: PlayerManager, didUpdateIsPlaying isPlaying: Bool)
    func playerManager(_ manager: PlayerManager, didUpdateTime time: CMTime, duration: CMTime)
    func playerManager(_ manager: PlayerManager, didUpdateLive isLive: Bool)
    func playerManagerDidFinish(_ manager: PlayerManager)
    func playerManager(_ manager: PlayerManager, didFail error: Error?)
}

/// AVPlayer 생명주기, KVO 관찰, 오디오 세션·인터럽션·라우트 변경,
/// 잠금화면/제어센터(MediaPlayer) 연동을 한 곳에서 관리한다.
/// Audio/Video 플레이어 VC가 공통으로 사용.
final class PlayerManager {

    weak var delegate: PlayerManagerDelegate?

    /// VideoPlayerViewController가 AVPlayerLayer/PIP를 만들 때 참조.
    let player: AVPlayer

    private let playerItem: AVPlayerItem
    private let mediaItem: MediaItem

    private var timeObserverToken: Any?
    private var statusObserver: NSKeyValueObservation?
    private var durationObserver: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?

    /// NowPlayingInfo에 표시할 아트워크. nil이면 아트워크 키를 세팅하지 않는다.
    var artworkImage: UIImage? {
        didSet { refreshNowPlayingInfo() }
    }

    var isLive: Bool {
        player.currentItem?.duration == .indefinite
    }

    var isPlaying: Bool {
        player.timeControlStatus == .playing
    }

    var currentTime: CMTime {
        player.currentTime()
    }

    var duration: CMTime {
        player.currentItem?.duration ?? .zero
    }

    // MARK: - Init

    init(mediaItem: MediaItem, artworkImage: UIImage? = nil) {
        self.mediaItem = mediaItem
        self.artworkImage = artworkImage
        self.playerItem = AVPlayerItem(url: mediaItem.url)
        self.player = AVPlayer(playerItem: playerItem)

        setupObservers()
        setupNotificationObservers()
        setupRemoteCommands()
        refreshNowPlayingInfo()
    }

    deinit {
        teardown()
    }

    // MARK: - Public API

    func play() { player.play() }
    func pause() { player.pause() }
    func togglePlayPause() { isPlaying ? pause() : play() }

    func seek(to seconds: Double, resumePlay: Bool = false, completion: ((Bool) -> Void)? = nil) {
        let target = CMTime(seconds: seconds, preferredTimescale: 1)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            if resumePlay { self?.player.play() }
            completion?(finished)
        }
    }

    func skipBackward(_ seconds: Double = 15) {
        let target = CMTimeMaximum(
            CMTimeSubtract(player.currentTime(), CMTime(seconds: seconds, preferredTimescale: 1)),
            .zero
        )
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func skipForward(_ seconds: Double = 15) {
        guard let duration = player.currentItem?.duration, duration.isNumeric else { return }
        let target = CMTimeMinimum(
            CMTimeAdd(player.currentTime(), CMTime(seconds: seconds, preferredTimescale: 1)),
            duration
        )
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func setRate(_ rate: Float) {
        player.rate = rate
        updateNowPlayingRate()
    }

    // MARK: - Observers

    private func setupObservers() {
        statusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async { self?.handleStatus(item.status) }
        }

        durationObserver = playerItem.observe(\.duration, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.handleDurationChange() }
        }

        timeControlObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.handleTimeControlStatus() }
        }

        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.handlePeriodicTime(time)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    private func handleStatus(_ status: AVPlayerItem.Status) {
        switch status {
        case .readyToPlay:
            delegate?.playerManager(self, didUpdateLive: isLive)
            refreshNowPlayingInfo()
        case .failed:
            delegate?.playerManager(self, didFail: playerItem.error)
        default:
            break
        }
    }

    private func handleDurationChange() {
        delegate?.playerManager(self, didUpdateLive: isLive)
    }

    private func handleTimeControlStatus() {
        let playing = isPlaying
        if playing {
            try? AVAudioSession.sharedInstance().setActive(true)
        } else {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        delegate?.playerManager(self, didUpdateIsPlaying: playing)
        updateNowPlayingRate()
    }

    private func handlePeriodicTime(_ time: CMTime) {
        delegate?.playerManager(self, didUpdateTime: time, duration: duration)
        updateNowPlayingTime(time: time)
    }

    @objc private func playerItemDidFinish() {
        player.seek(to: .zero)
        refreshNowPlayingInfo()
        delegate?.playerManagerDidFinish(self)
    }

    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            pause()
        case .ended:
            let options = (userInfo[AVAudioSessionInterruptionOptionKey] as? UInt).map {
                AVAudioSession.InterruptionOptions(rawValue: $0)
            }
            if options?.contains(.shouldResume) == true {
                play()
            }
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        if reason == .oldDeviceUnavailable {
            pause()
        }
    }

    // MARK: - Remote Commands / Now Playing

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skipBackward()
            return .success
        }
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { [weak self] _ in
            self?.skipForward()
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self,
                  let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self.seek(to: event.positionTime, resumePlay: true)
            return .success
        }
    }

    /// NowPlayingInfo 전체를 새로 세팅. 제목/길이/재생시간/아트워크 변경, live 전환 시에 호출.
    func refreshNowPlayingInfo() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: mediaItem.title,
            MPNowPlayingInfoPropertyPlaybackRate: player.rate,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
        ]

        if let duration = player.currentItem?.duration, duration.isNumeric {
            info[MPMediaItemPropertyPlaybackDuration] = duration.seconds
        }
        if player.currentTime().isNumeric {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
        }

        if let image = artworkImage {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: CGSize(width: 300, height: 300)) { _ in image }
        }

        let live = isLive
        let center = MPRemoteCommandCenter.shared()
        center.changePlaybackPositionCommand.isEnabled = !live
        center.skipBackwardCommand.isEnabled = !live
        center.skipForwardCommand.isEnabled = !live

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingTime(time: CMTime) {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = time.seconds
        info[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingRate() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Teardown

    private func teardown() {
        statusObserver = nil
        durationObserver = nil
        timeControlObserver = nil
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        NotificationCenter.default.removeObserver(self)

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)
        center.skipBackwardCommand.removeTarget(nil)
        center.skipForwardCommand.removeTarget(nil)
        center.changePlaybackPositionCommand.removeTarget(nil)
    }
}
