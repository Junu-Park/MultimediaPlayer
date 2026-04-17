import UIKit
import AVFoundation

final class DownloadService: NSObject {

    static let shared = DownloadService()

    // Notification names (userInfo key: "id")
    static let progressNotification = Notification.Name("DownloadService.progress")
    static let completionNotification = Notification.Name("DownloadService.completion")
    static let failureNotification = Notification.Name("DownloadService.failure")

    private static let sessionIdentifier = "com.arthur.MultimediaPlayer.download"
    private static let persistenceKey = "DownloadService.completedItems"

    private var session: AVAssetDownloadURLSession!
    private var taskForID: [String: AVAssetDownloadTask] = [:]
    private(set) var items: [DownloadItem] = []

    private override init() {
        super.init()
        setupSession()
        loadPersistedItems()
    }

    // MARK: - Session

    private func setupSession() {
        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        session = AVAssetDownloadURLSession(
            configuration: config,
            assetDownloadDelegate: self,
            delegateQueue: .main
        )
    }

    // MARK: - Public API

    /// 카탈로그 아이템 등록 (최초 1회, 이미 있으면 무시)
    func register(_ item: DownloadItem) {
        guard !items.contains(where: { $0.id == item.id }) else { return }
        var registered = item
        // 이전에 완료된 다운로드가 있으면 복원
        if let path = completedPaths[item.id], FileManager.default.fileExists(atPath: path) {
            registered.localURL = URL(fileURLWithPath: path)
            registered.state = .completed
            registered.progress = 1.0
        }
        items.append(registered)
    }

    func download(id: String) {
        guard let index = itemIndex(id: id),
              items[index].state == .idle || items[index].state == .failed else { return }

        let item = items[index]
        let asset = AVURLAsset(url: item.sourceURL)
        guard let task = session.makeAssetDownloadTask(
            asset: asset,
            assetTitle: item.title,
            assetArtworkData: nil,
            options: nil
        ) else { return }

        taskForID[id] = task
        items[index].state = .downloading
        items[index].progress = 0
        task.taskDescription = id
        task.resume()
    }

    func cancel(id: String) {
        taskForID[id]?.cancel()
        taskForID.removeValue(forKey: id)
        if let index = itemIndex(id: id) {
            items[index].state = .idle
            items[index].progress = 0
        }
    }

    func localURL(for id: String) -> URL? {
        items.first { $0.id == id }?.localURL
    }

    // MARK: - Persistence

    private var completedPaths: [String: String] {
        UserDefaults.standard.dictionary(forKey: Self.persistenceKey) as? [String: String] ?? [:]
    }

    private func persistCompletedItem(id: String, localURL: URL) {
        var paths = completedPaths
        paths[id] = localURL.path
        UserDefaults.standard.set(paths, forKey: Self.persistenceKey)
    }

    private func loadPersistedItems() {
        // items는 register() 시점에 복원되므로 여기서는 별도 처리 없음
    }

    private func itemIndex(id: String) -> Int? {
        items.firstIndex { $0.id == id }
    }
}

// MARK: - AVAssetDownloadDelegate

extension DownloadService: AVAssetDownloadDelegate {

    func urlSession(
        _ session: URLSession,
        assetDownloadTask: AVAssetDownloadTask,
        didLoad timeRange: CMTimeRange,
        totalTimeRangesLoaded loadedTimeRanges: [NSValue],
        timeRangeExpectedToLoad: CMTimeRange
    ) {
        guard let id = assetDownloadTask.taskDescription,
              let index = itemIndex(id: id) else { return }

        var progress = 0.0
        for value in loadedTimeRanges {
            let loaded = value.timeRangeValue
            guard timeRangeExpectedToLoad.duration.seconds > 0 else { continue }
            progress += loaded.duration.seconds / timeRangeExpectedToLoad.duration.seconds
        }
        items[index].progress = min(progress, 1.0)

        NotificationCenter.default.post(
            name: Self.progressNotification,
            object: nil,
            userInfo: ["id": id, "progress": items[index].progress]
        )
    }

    func urlSession(
        _ session: URLSession,
        assetDownloadTask: AVAssetDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let id = assetDownloadTask.taskDescription,
              let index = itemIndex(id: id) else { return }

        items[index].localURL = location
        items[index].state = .completed
        items[index].progress = 1.0
        taskForID.removeValue(forKey: id)

        persistCompletedItem(id: id, localURL: location)
        NotificationService.shared.scheduleDownloadCompletion(title: items[index].title)

        NotificationCenter.default.post(
            name: Self.completionNotification,
            object: nil,
            userInfo: ["id": id]
        )
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let id = task.taskDescription,
              let index = itemIndex(id: id) else { return }

        // 취소는 error로 처리되지만 이미 cancel()에서 상태를 변경했으므로 무시
        if let error = error as? NSError, error.code == NSURLErrorCancelled { return }

        if error != nil {
            items[index].state = .failed
            items[index].progress = 0
            taskForID.removeValue(forKey: id)

            NotificationCenter.default.post(
                name: Self.failureNotification,
                object: nil,
                userInfo: ["id": id]
            )
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
            appDelegate.backgroundSessionCompletionHandler?()
            appDelegate.backgroundSessionCompletionHandler = nil
        }
    }
}
