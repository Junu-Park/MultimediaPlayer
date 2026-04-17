import UIKit
import AVKit
import SnapKit

protocol PlayerControlViewDelegate: AnyObject {
    func controlViewDidTapPlayPause(_ view: PlayerControlView)
    func controlViewDidTapSkipBack(_ view: PlayerControlView)
    func controlViewDidTapSkipForward(_ view: PlayerControlView)
    func controlViewDidBeginSeeking(_ view: PlayerControlView)
    func controlViewDidEndSeeking(_ view: PlayerControlView, to value: Float)
    func controlViewDidTapPIP(_ view: PlayerControlView)
    func controlViewDidTapClose(_ view: PlayerControlView)
}

final class PlayerControlView: UIView {

    weak var delegate: PlayerControlViewDelegate?

    // MARK: - UI Elements

    private let closeButton: UIButton = {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        btn.setImage(UIImage(systemName: "xmark", withConfiguration: cfg), for: .normal)
        btn.tintColor = .white
        return btn
    }()

    private let titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.textColor = .white
        lbl.font = .systemFont(ofSize: 16, weight: .semibold)
        return lbl
    }()

    private let playPauseButton: UIButton = {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 44, weight: .medium)
        btn.setImage(UIImage(systemName: "play.fill", withConfiguration: cfg), for: .normal)
        btn.tintColor = .white
        return btn
    }()

    private let skipBackButton: UIButton = {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 32, weight: .medium)
        btn.setImage(UIImage(systemName: "gobackward.15", withConfiguration: cfg), for: .normal)
        btn.tintColor = .white
        return btn
    }()

    private let skipForwardButton: UIButton = {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 32, weight: .medium)
        btn.setImage(UIImage(systemName: "goforward.15", withConfiguration: cfg), for: .normal)
        btn.tintColor = .white
        return btn
    }()

    private let seekSlider: UISlider = {
        let s = UISlider()
        s.minimumTrackTintColor = .white
        s.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.4)
        s.thumbTintColor = .white
        return s
    }()

    private let currentTimeLabel: UILabel = {
        let lbl = UILabel()
        lbl.textColor = .white
        lbl.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        lbl.text = "00:00"
        return lbl
    }()

    private let durationLabel: UILabel = {
        let lbl = UILabel()
        lbl.textColor = .white
        lbl.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        lbl.text = "00:00"
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

    private let pipButton: UIButton = {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        btn.setImage(UIImage(systemName: "pip.enter", withConfiguration: cfg), for: .normal)
        btn.tintColor = .white
        btn.isHidden = true
        return btn
    }()

    private let routePickerView: AVRoutePickerView = {
        let picker = AVRoutePickerView()
        picker.tintColor = .white
        picker.activeTintColor = .systemBlue
        return picker
    }()

    private let gradientLayer = CAGradientLayer()

    // MARK: - State

    private(set) var isControlsVisible = true
    private var isLive = false
    private var totalDuration: Double = 0
    private var hideTimer: Timer?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    // MARK: - Setup

    private func setup() {
        setupGradient()
        [closeButton, titleLabel,
         skipBackButton, playPauseButton, skipForwardButton,
         currentTimeLabel, seekSlider, durationLabel, liveBadge,
         pipButton, routePickerView].forEach { addSubview($0) }
        setupConstraints()
        setupActions()
        scheduleHideTimer()
    }

    private func setupGradient() {
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0.72).cgColor,
            UIColor.clear.cgColor,
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.72).cgColor,
        ]
        gradientLayer.locations = [0, 0.25, 0.75, 1.0]
        layer.insertSublayer(gradientLayer, at: 0)
    }

    private func setupConstraints() {
        closeButton.snp.makeConstraints {
            $0.top.equalTo(safeAreaLayoutGuide).offset(8)
            $0.leading.equalToSuperview().offset(16)
            $0.size.equalTo(40)
        }

        titleLabel.snp.makeConstraints {
            $0.centerY.equalTo(closeButton)
            $0.leading.equalTo(closeButton.snp.trailing).offset(8)
            $0.trailing.equalToSuperview().inset(56)
        }

        playPauseButton.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(60)
        }

        skipBackButton.snp.makeConstraints {
            $0.centerY.equalTo(playPauseButton)
            $0.trailing.equalTo(playPauseButton.snp.leading).offset(-36)
            $0.size.equalTo(50)
        }

        skipForwardButton.snp.makeConstraints {
            $0.centerY.equalTo(playPauseButton)
            $0.leading.equalTo(playPauseButton.snp.trailing).offset(36)
            $0.size.equalTo(50)
        }

        routePickerView.snp.makeConstraints {
            $0.bottom.equalTo(safeAreaLayoutGuide).inset(12)
            $0.trailing.equalToSuperview().inset(16)
            $0.size.equalTo(32)
        }

        pipButton.snp.makeConstraints {
            $0.centerY.equalTo(routePickerView)
            $0.trailing.equalTo(routePickerView.snp.leading).offset(-8)
            $0.size.equalTo(32)
        }

        seekSlider.snp.makeConstraints {
            $0.bottom.equalTo(routePickerView.snp.top).offset(-12)
            $0.leading.equalTo(currentTimeLabel.snp.trailing).offset(8)
            $0.trailing.equalTo(durationLabel.snp.leading).offset(-8)
        }

        currentTimeLabel.snp.makeConstraints {
            $0.centerY.equalTo(seekSlider)
            $0.leading.equalToSuperview().offset(16)
        }

        durationLabel.snp.makeConstraints {
            $0.centerY.equalTo(seekSlider)
            $0.trailing.equalTo(pipButton.snp.leading).offset(-8)
        }

        liveBadge.snp.makeConstraints {
            $0.centerY.equalTo(seekSlider)
            $0.leading.equalToSuperview().offset(16)
            $0.height.equalTo(24)
        }
    }

    private func setupActions() {
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        skipBackButton.addTarget(self, action: #selector(skipBackTapped), for: .touchUpInside)
        skipForwardButton.addTarget(self, action: #selector(skipForwardTapped), for: .touchUpInside)
        pipButton.addTarget(self, action: #selector(pipTapped), for: .touchUpInside)
        seekSlider.addTarget(self, action: #selector(sliderTouchBegan), for: .touchDown)
        seekSlider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        seekSlider.addTarget(self, action: #selector(sliderTouchEnded), for: [.touchUpInside, .touchUpOutside])
    }

    // MARK: - Button Actions

    @objc private func closeTapped() {
        delegate?.controlViewDidTapClose(self)
    }

    @objc private func playPauseTapped() {
        scheduleHideTimer()
        delegate?.controlViewDidTapPlayPause(self)
    }

    @objc private func skipBackTapped() {
        scheduleHideTimer()
        delegate?.controlViewDidTapSkipBack(self)
    }

    @objc private func skipForwardTapped() {
        scheduleHideTimer()
        delegate?.controlViewDidTapSkipForward(self)
    }

    @objc private func pipTapped() {
        scheduleHideTimer()
        delegate?.controlViewDidTapPIP(self)
    }

    @objc private func sliderTouchBegan() {
        cancelHideTimer()
        delegate?.controlViewDidBeginSeeking(self)
    }

    @objc private func sliderValueChanged() {
        let time = Double(seekSlider.value) * totalDuration
        currentTimeLabel.text = formatTime(time)
    }

    @objc private func sliderTouchEnded() {
        scheduleHideTimer()
        delegate?.controlViewDidEndSeeking(self, to: seekSlider.value)
    }

    // MARK: - Public Update

    func configure(title: String) {
        titleLabel.text = title
    }

    func update(isPlaying: Bool) {
        let name = isPlaying ? "pause.fill" : "play.fill"
        let cfg = UIImage.SymbolConfiguration(pointSize: 44, weight: .medium)
        playPauseButton.setImage(UIImage(systemName: name, withConfiguration: cfg), for: .normal)
    }

    func update(isLive: Bool) {
        self.isLive = isLive
        seekSlider.isHidden = isLive
        currentTimeLabel.isHidden = isLive
        durationLabel.isHidden = isLive
        liveBadge.isHidden = !isLive
        skipBackButton.isEnabled = !isLive
        skipForwardButton.isEnabled = !isLive
        skipBackButton.alpha = isLive ? 0.4 : 1.0
        skipForwardButton.alpha = isLive ? 0.4 : 1.0
    }

    func update(currentTime: Double, duration: Double) {
        guard !isLive, !seekSlider.isTracking else { return }
        totalDuration = duration
        currentTimeLabel.text = formatTime(currentTime)
        durationLabel.text = formatTime(duration)
        seekSlider.value = duration > 0 ? Float(currentTime / duration) : 0
    }

    func setPIPAvailable(_ available: Bool) {
        pipButton.isHidden = !available
    }

    // MARK: - Visibility

    func toggleVisibility() {
        isControlsVisible ? hide() : show()
    }

    func show() {
        guard !isControlsVisible else {
            scheduleHideTimer()
            return
        }
        isControlsVisible = true
        isUserInteractionEnabled = true
        UIView.animate(withDuration: 0.25) { self.alpha = 1 }
        scheduleHideTimer()
    }

    func hide() {
        guard isControlsVisible else { return }
        isControlsVisible = false
        cancelHideTimer()
        UIView.animate(withDuration: 0.25, animations: {
            self.alpha = 0
        }, completion: { _ in
            self.isUserInteractionEnabled = false
        })
    }

    private func scheduleHideTimer() {
        cancelHideTimer()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }

    private func cancelHideTimer() {
        hideTimer?.invalidate()
        hideTimer = nil
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
