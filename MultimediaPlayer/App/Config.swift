import Foundation

enum Config {
    static let videoVODURL: URL = url(for: "VIDEO_VOD_URL")
    static let audioVODURL: URL = url(for: "AUDIO_VOD_URL")

    private static func url(for key: String) -> URL {
        guard let value = Bundle.main.infoDictionary?[key] as? String,
              let url = URL(string: value) else {
            fatalError("Secret.xcconfig에 \(key) 값이 없거나 올바르지 않습니다.")
        }
        return url
    }
}
