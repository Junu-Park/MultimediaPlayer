import UIKit
import SnapKit

final class DownloadListViewController: UITableViewController {

    // MARK: - Catalog

    private let catalog: [DownloadItem] = [
        DownloadItem(
            id: "video-vod",
            title: "비디오 VOD 샘플",
            sourceURL: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8")!,
            mediaType: .vodVideo
        ),
        DownloadItem(
            id: "audio-vod",
            title: "라디오 VOD 샘플",
            sourceURL: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8")!,
            mediaType: .vodAudio
        ),
    ]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "다운로드"
        tableView.register(DownloadCell.self, forCellReuseIdentifier: DownloadCell.reuseID)
        tableView.rowHeight = 80
        tableView.allowsSelection = false

        catalog.forEach { DownloadService.shared.register($0) }
        setupObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Observers

    private func setupObservers() {
        [DownloadService.progressNotification,
         DownloadService.completionNotification,
         DownloadService.failureNotification].forEach {
            NotificationCenter.default.addObserver(
                self, selector: #selector(handleDownloadNotification(_:)), name: $0, object: nil
            )
        }
    }

    @objc private func handleDownloadNotification(_ notification: Notification) {
        guard let id = notification.userInfo?["id"] as? String,
              let index = DownloadService.shared.items.firstIndex(where: { $0.id == id }) else { return }
        tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
    }

    // MARK: - TableView DataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        DownloadService.shared.items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DownloadCell.reuseID, for: indexPath) as! DownloadCell
        let item = DownloadService.shared.items[indexPath.row]
        cell.configure(with: item)
        cell.onAction = { [weak self] in self?.handleAction(for: item) }
        cell.onPlay = { [weak self] in self?.play(item: item) }
        return cell
    }

    // MARK: - Actions

    private func handleAction(for item: DownloadItem) {
        switch item.state {
        case .idle, .failed:
            DownloadService.shared.download(id: item.id)
        case .downloading:
            DownloadService.shared.cancel(id: item.id)
        case .completed:
            break
        }
        reloadRow(id: item.id)
    }

    private func play(item: DownloadItem) {
        guard let localURL = item.localURL else { return }
        let mediaItem = MediaItem(title: item.title, url: localURL, type: item.mediaType)

        if item.mediaType.isAudio {
            navigationController?.pushViewController(AudioPlayerViewController(mediaItem: mediaItem), animated: true)
        } else {
            present(VideoPlayerViewController(mediaItem: mediaItem), animated: true)
        }
    }

    private func reloadRow(id: String) {
        guard let index = DownloadService.shared.items.firstIndex(where: { $0.id == id }) else { return }
        tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
    }
}

// MARK: - MediaType + isAudio

private extension MediaType {
    var isAudio: Bool { self == .vodAudio || self == .liveAudio }
}

// MARK: - DownloadCell

final class DownloadCell: UITableViewCell {
    static let reuseID = "DownloadCell"

    var onAction: (() -> Void)?
    var onPlay: (() -> Void)?

    private let titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 16, weight: .medium)
        return lbl
    }()

    private let statusLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 12)
        lbl.textColor = .secondaryLabel
        return lbl
    }()

    private let progressView: UIProgressView = {
        let pv = UIProgressView(progressViewStyle: .default)
        pv.isHidden = true
        return pv
    }()

    private let actionButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        return btn
    }()

    private let playButton: UIButton = {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        btn.setImage(UIImage(systemName: "play.circle.fill", withConfiguration: cfg), for: .normal)
        btn.isHidden = true
        return btn
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        [titleLabel, statusLabel, progressView, actionButton, playButton].forEach {
            contentView.addSubview($0)
        }

        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(14)
            $0.leading.equalToSuperview().offset(16)
            $0.trailing.equalTo(actionButton.snp.leading).offset(-8)
        }

        statusLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(4)
            $0.leading.equalTo(titleLabel)
        }

        progressView.snp.makeConstraints {
            $0.top.equalTo(statusLabel.snp.bottom).offset(8)
            $0.leading.equalTo(titleLabel)
            $0.trailing.equalTo(actionButton.snp.leading).offset(-8)
        }

        actionButton.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.trailing.equalTo(playButton.snp.leading).offset(-8)
            $0.width.equalTo(60)
        }

        playButton.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview().inset(16)
            $0.size.equalTo(36)
        }

        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
    }

    func configure(with item: DownloadItem) {
        titleLabel.text = item.title

        switch item.state {
        case .idle:
            statusLabel.text = "대기 중"
            progressView.isHidden = true
            actionButton.setTitle("다운로드", for: .normal)
            actionButton.isHidden = false
            playButton.isHidden = true

        case .downloading:
            statusLabel.text = String(format: "%.0f%%", item.progress * 100)
            progressView.progress = Float(item.progress)
            progressView.isHidden = false
            actionButton.setTitle("취소", for: .normal)
            actionButton.isHidden = false
            playButton.isHidden = true

        case .completed:
            statusLabel.text = "완료"
            progressView.isHidden = true
            actionButton.isHidden = true
            playButton.isHidden = false

        case .failed:
            statusLabel.text = "실패"
            progressView.isHidden = true
            actionButton.setTitle("재시도", for: .normal)
            actionButton.isHidden = false
            playButton.isHidden = true
        }
    }

    @objc private func actionTapped() { onAction?() }
    @objc private func playTapped() { onPlay?() }
}
