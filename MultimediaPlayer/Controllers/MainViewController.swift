import UIKit

class MainViewController: UITableViewController {

    private struct Section {
        let title: String
        let items: [Item]
    }

    private struct Item {
        let title: String
        let subtitle: String
    }

    private let sections: [Section] = [
        Section(title: "비디오", items: [
            Item(title: "VOD 재생", subtitle: "정적 HLS 스트림"),
            Item(title: "실시간 스트리밍", subtitle: "라이브 HLS 스트림"),
            Item(title: "다운로드", subtitle: "오프라인 저장 후 재생"),
        ]),
        Section(title: "라디오", items: [
            Item(title: "VOD 재생 (다시듣기)", subtitle: "오디오 HLS 스트림"),
            Item(title: "실시간 청취", subtitle: "라이브 오디오 HLS"),
            Item(title: "다운로드", subtitle: "오디오 오프라인 저장 후 재생"),
        ]),
        Section(title: "웹뷰", items: [
            Item(title: "웹뷰 열기", subtitle: "JS Bridge 포함"),
        ]),
    ]

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
        sections[section].items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let item = sections[indexPath.section].items[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = item.title
        config.secondaryText = item.subtitle
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch (indexPath.section, indexPath.row) {
        case (0, 0): break // TODO: VideoPlayerViewController (VOD)
        case (0, 1): break // TODO: VideoPlayerViewController (Live)
        case (0, 2): break // TODO: VideoPlayerViewController (Download)
        case (1, 0): break // TODO: AudioPlayerViewController (VOD)
        case (1, 1): break // TODO: AudioPlayerViewController (Live)
        case (1, 2): break // TODO: AudioPlayerViewController (Download)
        case (2, 0): break // TODO: WebViewController
        default: break
        }
    }
}
