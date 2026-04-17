import UIKit
import AVFoundation
import AVKit
import MediaPlayer
import SnapKit

final class VideoPlayerViewController: UIViewController {

    private let mediaItem: MediaItem

    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var playerItem: AVPlayerItem?

    private var timeObserverToken: Any?
    private var statusObserver: NSKeyValueObservation?
    private var durationObserver: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?

    private var pipController: AVPictureInPictureController?

    private let controlView = PlayerControlView()

    private var isLive: Bool {
        player?.currentItem?.duration == .indefinite
    }

    // MARK: - Init

    init(mediaItem: MediaItem) {
        self.mediaItem = mediaItem
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        removeObservers()
        NotificationCenter.default.removeObserver(self)
        clearNowPlaying()
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupPlayer()
        setupControlView()
        setupTapGesture()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.bounds
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .all }
    override var shouldAutorotate: Bool { true }
    override var prefersStatusBarHidden: Bool { true }

    // MARK: - Player

    private func setupPlayer() {
        playerItem = AVPlayerItem(url: mediaItem.url)
        player = AVPlayer(playerItem: playerItem)

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        playerLayer = layer

        setupObservers()
        setupRemoteCommands()
        setupPIP()
        player?.play()
    }

    private func setupObservers() {
        guard let item = playerItem, let player = player else { return }

        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async { self?.handleStatus(item.status) }
        }

        durationObserver = item.observe(\.duration, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.updateLiveMode() }
        }

        timeControlObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                self?.controlView.update(isPlaying: player.timeControlStatus == .playing)
                self?.updateNowPlayingRate()
            }
        }

        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.updateProgress(time: time)
            self?.updateNowPlayingTime(time: time)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
    }

    private func removeObservers() {
        statusObserver = nil
        durationObserver = nil
        timeControlObserver = nil
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }

    private func setupPIP() {
        guard AVPictureInPictureController.isPictureInPictureSupported(),
              let playerLayer = playerLayer else { return }
        pipController = AVPictureInPictureController(playerLayer: playerLayer)
        pipController?.delegate = self
        controlView.setPIPAvailable(true)
    }

    // MARK: - Control View

    private func setupControlView() {
        controlView.delegate = self
        controlView.configure(title: mediaItem.title)
        view.addSubview(controlView)

        controlView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    private func setupTapGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        view.addGestureRecognizer(tap)
    }

    @objc private func handleTap() {
        controlView.toggleVisibility()
    }

    // MARK: - Remote Commands

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            self?.player?.play()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.player?.pause()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self, let player = self.player else { return .commandFailed }
            player.timeControlStatus == .playing ? player.pause() : player.play()
            return .success
        }
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skipBack()
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
            let target = CMTime(seconds: event.positionTime, preferredTimescale: 1)
            self.player?.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                self.player?.play()
            }
            return .success
        }

        updateNowPlayingInfo()
    }

    private func updateNowPlayingInfo() {
        let rate = player?.rate ?? 0
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: mediaItem.title,
            MPNowPlayingInfoPropertyPlaybackRate: rate,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
        ]

        if let duration = player?.currentItem?.duration, duration.isNumeric {
            info[MPMediaItemPropertyPlaybackDuration] = duration.seconds
        }
        if let currentTime = player?.currentTime(), currentTime.isNumeric {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime.seconds
        }

        let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: 300, height: 300)) { _ in
            let cfg = UIImage.SymbolConfiguration(pointSize: 120, weight: .thin)
            return UIImage(systemName: "play.rectangle", withConfiguration: cfg) ?? UIImage()
        }
        info[MPMediaItemPropertyArtwork] = artwork

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingTime(time: CMTime) {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = time.seconds
        info[MPNowPlayingInfoPropertyPlaybackRate] = player?.rate ?? 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingRate() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyPlaybackRate] = player?.rate ?? 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateRemoteCommandAvailability() {
        let live = isLive
        MPRemoteCommandCenter.shared().changePlaybackPositionCommand.isEnabled = !live
        MPRemoteCommandCenter.shared().skipBackwardCommand.isEnabled = !live
        MPRemoteCommandCenter.shared().skipForwardCommand.isEnabled = !live
    }

    private func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)
        center.skipBackwardCommand.removeTarget(nil)
        center.skipForwardCommand.removeTarget(nil)
        center.changePlaybackPositionCommand.removeTarget(nil)
    }

    // MARK: - State

    private func handleStatus(_ status: AVPlayerItem.Status) {
        switch status {
        case .readyToPlay:
            updateLiveMode()
            updateNowPlayingInfo()
        case .failed:
            showError(playerItem?.error)
        default:
            break
        }
    }

    private func updateLiveMode() {
        controlView.update(isLive: isLive)
        updateRemoteCommandAvailability()
    }

    private func updateProgress(time: CMTime) {
        guard !isLive,
              let duration = player?.currentItem?.duration,
              duration.isNumeric else { return }
        controlView.update(currentTime: time.seconds, duration: duration.seconds)
    }

    @objc private func playerItemDidFinish() {
        player?.seek(to: .zero)
        controlView.update(isPlaying: false)
        controlView.show()
        updateNowPlayingInfo()
    }

    private func showError(_ error: Error?) {
        let msg = error?.localizedDescription ?? "재생 중 오류가 발생했습니다."
        let alert = UIAlertController(title: "재생 오류", message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "닫기", style: .cancel) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }

    private func skipBack() {
        guard let player = player else { return }
        let target = CMTimeMaximum(
            CMTimeSubtract(player.currentTime(), CMTime(seconds: 15, preferredTimescale: 1)),
            .zero
        )
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func skipForward() {
        guard let player = player,
              let duration = player.currentItem?.duration,
              duration.isNumeric else { return }
        let target = CMTimeMinimum(
            CMTimeAdd(player.currentTime(), CMTime(seconds: 15, preferredTimescale: 1)),
            duration
        )
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }
}

// MARK: - PlayerControlViewDelegate

extension VideoPlayerViewController: PlayerControlViewDelegate {

    func controlViewDidTapPlayPause(_ view: PlayerControlView) {
        guard let player = player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    func controlViewDidTapSkipBack(_ view: PlayerControlView) { skipBack() }
    func controlViewDidTapSkipForward(_ view: PlayerControlView) { skipForward() }

    func controlViewDidBeginSeeking(_ view: PlayerControlView) {
        player?.pause()
    }

    func controlViewDidEndSeeking(_ view: PlayerControlView, to value: Float) {
        guard let duration = player?.currentItem?.duration, duration.isNumeric else { return }
        let targetTime = CMTimeMultiplyByFloat64(duration, multiplier: Float64(value))
        player?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            self?.player?.play()
        }
    }

    func controlViewDidTapPIP(_ view: PlayerControlView) {
        if pipController?.isPictureInPictureActive == true {
            pipController?.stopPictureInPicture()
        } else {
            pipController?.startPictureInPicture()
        }
    }

    func controlViewDidTapClose(_ view: PlayerControlView) {
        player?.pause()
        dismiss(animated: true)
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension VideoPlayerViewController: AVPictureInPictureControllerDelegate {

    func pictureInPictureControllerWillStartPictureInPicture(_ controller: AVPictureInPictureController) {
        controlView.hide()
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        controlView.show()
    }

    func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(true)
    }
}
