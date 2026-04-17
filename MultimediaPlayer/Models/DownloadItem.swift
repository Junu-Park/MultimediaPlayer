import Foundation

enum DownloadState {
    case idle
    case downloading
    case completed
    case failed
}

struct DownloadItem {
    let id: String
    let title: String
    let sourceURL: URL
    let mediaType: MediaType
    var localURL: URL?
    var progress: Double = 0
    var state: DownloadState = .idle
}
