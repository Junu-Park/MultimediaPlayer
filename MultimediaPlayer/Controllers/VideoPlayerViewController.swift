import UIKit
import AVFoundation
import AVKit
import SnapKit

final class VideoPlayerViewController: UIViewController {

    private let mediaItem: MediaItem
    private let manager: PlayerManager

    private var playerLayer: AVPlayerLayer?
    private var pipController: AVPictureInPictureController?

    private let controlView = PlayerControlView()

    private var isLive: Bool { manager.isLive }

    // MARK: - Init

    init(mediaItem: MediaItem) {
        self.mediaItem = mediaItem
        let cfg = UIImage.SymbolConfiguration(pointSize: 120, weight: .thin)
        let artwork = UIImage(systemName: "play.rectangle", withConfiguration: cfg)
        self.manager = PlayerManager(mediaItem: mediaItem, artworkImage: artwork)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        manager.delegate = self
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupPlayerLayer()
        setupControlView()
        setupTapGesture()
        setupPIP()
        controlView.configure(title: mediaItem.title)
        manager.play()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.bounds
    }

    override var prefersStatusBarHidden: Bool { true }

    // MARK: - Setup

    private func setupPlayerLayer() {
        let layer = AVPlayerLayer(player: manager.player)
        layer.videoGravity = .resizeAspect
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        playerLayer = layer
    }

    private func setupControlView() {
        controlView.delegate = self
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

    private func setupPIP() {
        guard AVPictureInPictureController.isPictureInPictureSupported(),
              let playerLayer = playerLayer else { return }
        pipController = AVPictureInPictureController(playerLayer: playerLayer)
        pipController?.delegate = self
        controlView.setPIPAvailable(true)
    }

    // MARK: - UI Updates

    private func showError(_ error: Error?) {
        let msg = error?.localizedDescription ?? "재생 중 오류가 발생했습니다."
        let alert = UIAlertController(title: "재생 오류", message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "닫기", style: .cancel) { [weak self] _ in
            AppDelegate.rotateToPortrait {
                self?.dismiss(animated: false)
            }
        })
        present(alert, animated: true)
    }
}

// MARK: - PlayerManagerDelegate

extension VideoPlayerViewController: PlayerManagerDelegate {
    func playerManager(_ manager: PlayerManager, didUpdateIsPlaying isPlaying: Bool) {
        controlView.update(isPlaying: isPlaying)
    }

    func playerManager(_ manager: PlayerManager, didUpdateTime time: CMTime, duration: CMTime) {
        guard !isLive, duration.isNumeric else { return }
        controlView.update(currentTime: time.seconds, duration: duration.seconds)
    }

    func playerManager(_ manager: PlayerManager, didUpdateLive isLive: Bool) {
        controlView.update(isLive: isLive)
    }

    func playerManagerDidFinish(_ manager: PlayerManager) {
        controlView.update(isPlaying: false)
        controlView.show()
    }

    func playerManager(_ manager: PlayerManager, didFail error: Error?) {
        showError(error)
    }
}

// MARK: - PlayerControlViewDelegate

extension VideoPlayerViewController: PlayerControlViewDelegate {

    func controlViewDidTapPlayPause(_ view: PlayerControlView) {
        manager.togglePlayPause()
    }

    func controlViewDidTapSkipBack(_ view: PlayerControlView) { manager.skipBackward() }
    func controlViewDidTapSkipForward(_ view: PlayerControlView) { manager.skipForward() }

    func controlViewDidBeginSeeking(_ view: PlayerControlView) {
        manager.pause()
    }

    func controlViewDidEndSeeking(_ view: PlayerControlView, to value: Float) {
        let duration = manager.duration
        guard duration.isNumeric else { return }
        let targetSeconds = duration.seconds * Double(value)
        manager.seek(to: targetSeconds, resumePlay: true)
    }

    func controlViewDidTapPIP(_ view: PlayerControlView) {
        if pipController?.isPictureInPictureActive == true {
            pipController?.stopPictureInPicture()
        } else {
            pipController?.startPictureInPicture()
        }
    }

    func controlViewDidTapClose(_ view: PlayerControlView) {
        manager.pause()
        AppDelegate.rotateToPortrait { [weak self] in
            self?.dismiss(animated: false)
        }
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
