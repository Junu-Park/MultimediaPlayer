import UIKit

class MainViewController: UITableViewController {

    // MARK: - Data

    private struct Row {
        let title: String
        let subtitle: String
        let action: Action

        enum Action {
            case playVideo(MediaItem)
            case playAudio(MediaItem)
            case openDownloadList
            case notImplemented(String)
        }
    }

    private struct Section {
        let title: String
        let rows: [Row]
    }

    private let sections: [Section] = [
        Section(title: "비디오", rows: [
            Row(
                title: "VOD 재생",
                subtitle: "정적 HLS 스트림",
                action: .playVideo(MediaItem(
                    title: "VOD 재생",
                    url: URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!,
                    type: .vodVideo
                ))
            ),
            Row(
                title: "실시간 스트리밍",
                subtitle: "라이브 HLS 스트림",
                action: .playVideo(MediaItem(
                    title: "실시간 스트리밍",
                    url: URL(string: "https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8")!,
                    type: .liveVideo
                ))
            ),
            Row(
                title: "다운로드",
                subtitle: "오프라인 저장 후 재생",
                action: .openDownloadList
            ),
        ]),
        Section(title: "라디오", rows: [
            Row(
                title: "VOD 재생 (다시듣기)",
                subtitle: "오디오 HLS 스트림",
                action: .playAudio(MediaItem(
                    title: "VOD 다시듣기",
                    url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8")!,
                    type: .vodAudio
                ))
            ),
            Row(
                title: "실시간 청취",
                subtitle: "라이브 오디오 HLS",
                action: .playAudio(MediaItem(
                    title: "실시간 청취",
                    url: URL(string: "https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8")!,
                    type: .liveAudio
                ))
            ),
            Row(
                title: "다운로드",
                subtitle: "오디오 오프라인 저장 후 재생",
                action: .openDownloadList
            ),
        ]),
    ]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "멀티미디어 플레이어"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].title
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let row = sections[indexPath.section].rows[indexPath.row]
        var cfg = cell.defaultContentConfiguration()
        cfg.text = row.title
        cfg.secondaryText = row.subtitle
        cell.contentConfiguration = cfg
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch sections[indexPath.section].rows[indexPath.row].action {
        case .playVideo(let item):
            present(VideoPlayerViewController(mediaItem: item), animated: true)
        case .playAudio(let item):
            navigationController?.pushViewController(AudioPlayerViewController(mediaItem: item), animated: true)
        case .openDownloadList:
            navigationController?.pushViewController(DownloadListViewController(), animated: true)
        case .notImplemented(let message):
            let alert = UIAlertController(title: "준비 중", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default))
            present(alert, animated: true)
        }
    }
}
