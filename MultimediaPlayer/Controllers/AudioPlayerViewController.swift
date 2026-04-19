import UIKit
import AVFoundation
import AVKit
import MediaPlayer
import SnapKit

final class AudioPlayerViewController: UIViewController {

    private let mediaItem: MediaItem

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?

    private var timeObserverToken: Any?
    private var statusObserver: NSKeyValueObservation?
    private var durationObserver: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?

    private var isLive: Bool {
        player?.currentItem?.duration == .indefinite
    }

    // MARK: - UI

    private let artworkView: UIImageView = {
        let iv = UIImageView()
        let cfg = UIImage.SymbolConfiguration(pointSize: 80, weight: .thin)
        iv.image = UIImage(systemName: "music.note", withConfiguration: cfg)
        iv.tintColor = .secondaryLabel
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = UIColor.secondarySystemBackground
        iv.layer.cornerRadius = 20
        iv.layer.masksToBounds = true
        return iv
    }()

    private let titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 20, weight: .semibold)
        lbl.textAlignment = .center
        lbl.numberOfLines = 2
        return lbl
    }()

    private let liveBadge: UILabel = {
        let lbl = UILabel()
        lbl.text = " ● LIVE "
        lbl.textColor = .white
        lbl.font = .systemFont(ofSize: 12, weight: .bold)
        lbl.backgroundColor = .systemRed
        lbl.layer.cornerRadius = 4
        lbl.layer.masksToBounds = true
        lbl.textAlignment = .center
        lbl.isHidden = true
        return lbl
    }()

    private let seekSlider: UISlider = {
        let s = UISlider()
        s.minimumTrackTintColor = .label
        s.maximumTrackTintColor = .tertiaryLabel
        return s
    }()

    private let currentTimeLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        lbl.textColor = .secondaryLabel
        lbl.text = "00:00"
        return lbl
    }()

    private let durationLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        lbl.textColor = .secondaryLabel
        lbl.textAlignment = .right
        lbl.text = "00:00"
        return lbl
    }()

    private let speedControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["0.5x", "0.75x", "1.0x", "1.25x", "1.5x", "2.0x"])
        sc.selectedSegmentIndex = 2
        return sc
    }()

    private let playPauseButton: UIButton = {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 48, weight: .medium)
        btn.setImage(UIImage(systemName: "play.fill", withConfiguration: cfg), for: .normal)
        btn.tintColor = .label
        return btn
    }()

    private let skipBackButton: UIButton = {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)
        btn.setImage(UIImage(systemName: "gobackward.15", withConfiguration: cfg), for: .normal)
        btn.tintColor = .label
        return btn
    }()

    private let skipForwardButton: UIButton = {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)
        btn.setImage(UIImage(systemName: "goforward.15", withConfiguration: cfg), for: .normal)
        btn.tintColor = .label
        return btn
    }()

    private let routePickerView: AVRoutePickerView = {
        let picker = AVRoutePickerView()
        picker.tintColor = .label
        return picker
    }()

    private var totalDuration: Double = 0
    private let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    // MARK: - Init

    init(mediaItem: MediaItem) {
        self.mediaItem = mediaItem
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        removeObservers()
        removeNotificationObservers()
        clearNowPlaying()
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "라디오"
        setupLayout()
        setupActions()
        setupPlayer()
        setupNotificationObservers()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            player?.pause()
        }
    }

    // MARK: - Layout

    private func setupLayout() {
        [artworkView, titleLabel, liveBadge,
         currentTimeLabel, seekSlider, durationLabel,
         speedControl, skipBackButton, playPauseButton, skipForwardButton,
         routePickerView].forEach { view.addSubview($0) }

        artworkView.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(32)
            $0.width.height.equalTo(220)
        }

        titleLabel.snp.makeConstraints {
            $0.top.equalTo(artworkView.snp.bottom).offset(24)
            $0.leading.trailing.equalToSuperview().inset(32)
        }

        liveBadge.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(8)
            $0.centerX.equalToSuperview()
            $0.height.equalTo(24)
        }

        seekSlider.snp.makeConstraints {
            $0.top.equalTo(liveBadge.snp.bottom).offset(24)
            $0.leading.trailing.equalToSuperview().inset(32)
        }

        currentTimeLabel.snp.makeConstraints {
            $0.top.equalTo(seekSlider.snp.bottom).offset(4)
            $0.leading.equalTo(seekSlider)
        }

        durationLabel.snp.makeConstraints {
            $0.top.equalTo(seekSlider.snp.bottom).offset(4)
            $0.trailing.equalTo(seekSlider)
        }

        speedControl.snp.makeConstraints {
            $0.top.equalTo(currentTimeLabel.snp.bottom).offset(20)
            $0.leading.trailing.equalToSuperview().inset(32)
        }

        playPauseButton.snp.makeConstraints {
            $0.top.equalTo(speedControl.snp.bottom).offset(32)
            $0.centerX.equalToSuperview()
            $0.size.equalTo(64)
        }

        skipBackButton.snp.makeConstraints {
            $0.centerY.equalTo(playPauseButton)
            $0.trailing.equalTo(playPauseButton.snp.leading).offset(-40)
            $0.size.equalTo(50)
        }

        skipForwardButton.snp.makeConstraints {
            $0.centerY.equalTo(playPauseButton)
            $0.leading.equalTo(playPauseButton.snp.trailing).offset(40)
            $0.size.equalTo(50)
        }

        routePickerView.snp.makeConstraints {
            $0.top.equalTo(playPauseButton.snp.bottom).offset(24)
            $0.centerX.equalToSuperview()
            $0.size.equalTo(36)
        }
    }

    // MARK: - Actions Setup

    private func setupActions() {
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        skipBackButton.addTarget(self, action: #selector(skipBackTapped), for: .touchUpInside)
        skipForwardButton.addTarget(self, action: #selector(skipForwardTapped), for: .touchUpInside)
        speedControl.addTarget(self, action: #selector(speedChanged), for: .valueChanged)
        seekSlider.addTarget(self, action: #selector(sliderTouchBegan), for: .touchDown)
        seekSlider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        seekSlider.addTarget(self, action: #selector(sliderTouchEnded), for: [.touchUpInside, .touchUpOutside])
    }

    // MARK: - Player

    private func setupPlayer() {
        playerItem = AVPlayerItem(url: mediaItem.url)
        player = AVPlayer(playerItem: playerItem)

        setupObservers()
        setupRemoteCommands()
        titleLabel.text = mediaItem.title
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
                let isPlaying = player.timeControlStatus == .playing
                self?.updatePlayPauseButton(isPlaying: isPlaying)
                if isPlaying {
                    try? AVAudioSession.sharedInstance().setActive(true)
                } else {
                    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                }
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

    // MARK: - Notification Observers

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

    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }

    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            player?.pause()
        case .ended:
            let options = (userInfo[AVAudioSessionInterruptionOptionKey] as? UInt).map {
                AVAudioSession.InterruptionOptions(rawValue: $0)
            }
            if options?.contains(.shouldResume) == true {
                player?.play()
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
            player?.pause()
        }
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
            return UIImage(systemName: "music.note", withConfiguration: cfg) ?? UIImage()
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

    // MARK: - State Updates

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
        let live = isLive
        seekSlider.isHidden = live
        currentTimeLabel.isHidden = live
        durationLabel.isHidden = live
        speedControl.isHidden = live
        liveBadge.isHidden = !live
        skipBackButton.isEnabled = !live
        skipForwardButton.isEnabled = !live
        skipBackButton.alpha = live ? 0.4 : 1.0
        skipForwardButton.alpha = live ? 0.4 : 1.0

        MPRemoteCommandCenter.shared().changePlaybackPositionCommand.isEnabled = !live
        MPRemoteCommandCenter.shared().skipBackwardCommand.isEnabled = !live
        MPRemoteCommandCenter.shared().skipForwardCommand.isEnabled = !live
    }

    private func updatePlayPauseButton(isPlaying: Bool) {
        let name = isPlaying ? "pause.fill" : "play.fill"
        let cfg = UIImage.SymbolConfiguration(pointSize: 48, weight: .medium)
        playPauseButton.setImage(UIImage(systemName: name, withConfiguration: cfg), for: .normal)
    }

    private func updateProgress(time: CMTime) {
        guard !isLive,
              let duration = player?.currentItem?.duration,
              duration.isNumeric else { return }
        totalDuration = duration.seconds
        guard !seekSlider.isTracking else { return }
        currentTimeLabel.text = formatTime(time.seconds)
        durationLabel.text = formatTime(totalDuration)
        seekSlider.value = totalDuration > 0 ? Float(time.seconds / totalDuration) : 0
    }

    @objc private func playerItemDidFinish() {
        player?.seek(to: .zero)
        updatePlayPauseButton(isPlaying: false)
        updateNowPlayingInfo()
    }

    private func showError(_ error: Error?) {
        let msg = error?.localizedDescription ?? "재생 중 오류가 발생했습니다."
        let alert = UIAlertController(title: "재생 오류", message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "닫기", style: .cancel) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    // MARK: - Button Actions

    @objc private func playPauseTapped() {
        guard let player = player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    @objc private func skipBackTapped() { skipBack() }
    @objc private func skipForwardTapped() { skipForward() }

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

    @objc private func speedChanged() {
        let speed = speeds[speedControl.selectedSegmentIndex]
        player?.rate = speed
        updateNowPlayingInfo()
    }

    @objc private func sliderTouchBegan() {
        player?.pause()
    }

    @objc private func sliderValueChanged() {
        currentTimeLabel.text = formatTime(Double(seekSlider.value) * totalDuration)
    }

    @objc private func sliderTouchEnded() {
        guard let duration = player?.currentItem?.duration, duration.isNumeric else { return }
        let targetTime = CMTimeMultiplyByFloat64(duration, multiplier: Float64(seekSlider.value))
        player?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            self?.player?.play()
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, !seconds.isNaN, seconds >= 0 else { return "00:00" }
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}
