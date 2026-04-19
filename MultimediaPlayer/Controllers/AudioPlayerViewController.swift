import UIKit
import AVFoundation
import AVKit
import SnapKit

final class AudioPlayerViewController: UIViewController {

    private let mediaItem: MediaItem
    private let manager: PlayerManager

    private var isLive: Bool { manager.isLive }

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
        let cfg = UIImage.SymbolConfiguration(pointSize: 120, weight: .thin)
        let artwork = UIImage(systemName: "music.note", withConfiguration: cfg)
        self.manager = PlayerManager(mediaItem: mediaItem, artworkImage: artwork)
        super.init(nibName: nil, bundle: nil)
        manager.delegate = self
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "라디오"
        setupLayout()
        setupActions()
        titleLabel.text = mediaItem.title
        manager.play()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            manager.pause()
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

    // MARK: - UI Updates

    private func updateLiveMode(_ live: Bool) {
        seekSlider.isHidden = live
        currentTimeLabel.isHidden = live
        durationLabel.isHidden = live
        speedControl.isHidden = live
        liveBadge.isHidden = !live
        skipBackButton.isEnabled = !live
        skipForwardButton.isEnabled = !live
        skipBackButton.alpha = live ? 0.4 : 1.0
        skipForwardButton.alpha = live ? 0.4 : 1.0
    }

    private func updatePlayPauseButton(isPlaying: Bool) {
        let name = isPlaying ? "pause.fill" : "play.fill"
        let cfg = UIImage.SymbolConfiguration(pointSize: 48, weight: .medium)
        playPauseButton.setImage(UIImage(systemName: name, withConfiguration: cfg), for: .normal)
    }

    private func updateProgress(time: CMTime, duration: CMTime) {
        guard !isLive, duration.isNumeric else { return }
        totalDuration = duration.seconds
        guard !seekSlider.isTracking else { return }
        currentTimeLabel.text = formatTime(time.seconds)
        durationLabel.text = formatTime(totalDuration)
        seekSlider.value = totalDuration > 0 ? Float(time.seconds / totalDuration) : 0
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

    @objc private func playPauseTapped() { manager.togglePlayPause() }
    @objc private func skipBackTapped() { manager.skipBackward() }
    @objc private func skipForwardTapped() { manager.skipForward() }

    @objc private func speedChanged() {
        let speed = speeds[speedControl.selectedSegmentIndex]
        manager.setRate(speed)
    }

    @objc private func sliderTouchBegan() {
        manager.pause()
    }

    @objc private func sliderValueChanged() {
        currentTimeLabel.text = formatTime(Double(seekSlider.value) * totalDuration)
    }

    @objc private func sliderTouchEnded() {
        let duration = manager.duration
        guard duration.isNumeric else { return }
        let targetSeconds = duration.seconds * Double(seekSlider.value)
        manager.seek(to: targetSeconds, resumePlay: true)
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

// MARK: - PlayerManagerDelegate

extension AudioPlayerViewController: PlayerManagerDelegate {
    func playerManager(_ manager: PlayerManager, didUpdateIsPlaying isPlaying: Bool) {
        updatePlayPauseButton(isPlaying: isPlaying)
    }

    func playerManager(_ manager: PlayerManager, didUpdateTime time: CMTime, duration: CMTime) {
        updateProgress(time: time, duration: duration)
    }

    func playerManager(_ manager: PlayerManager, didUpdateLive isLive: Bool) {
        updateLiveMode(isLive)
    }

    func playerManagerDidFinish(_ manager: PlayerManager) {
        updatePlayPauseButton(isPlaying: false)
    }

    func playerManager(_ manager: PlayerManager, didFail error: Error?) {
        showError(error)
    }
}
