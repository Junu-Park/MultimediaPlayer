import Foundation

enum MediaType {
    case vodVideo
    case liveVideo
    case vodAudio
    case liveAudio
}

struct MediaItem {
    let title: String
    let url: URL
    let type: MediaType

    var isAudio: Bool {
        type == .vodAudio || type == .liveAudio
    }
}
