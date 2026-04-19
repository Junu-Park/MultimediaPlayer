import UIKit
import AVFoundation
import CoreMotion

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var backgroundSessionCompletionHandler: (() -> Void)?

    /// 현재 앱이 허용하는 방향. 각 VC의 supportedInterfaceOrientations와 교집합되어 실제 방향이 정해진다.
    /// 단일 출처. VC에서 override 하지 말고 이 값만 갱신할 것.
    private static var orientationMask: UIInterfaceOrientationMask = .portrait
    private static let motionManager = CMMotionManager()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        setupAudioSession()
        NotificationManager.shared.requestPermission()
        return true
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        AppDelegate.orientationMask
    }

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        backgroundSessionCompletionHandler = completionHandler
    }

    private func setupAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    // MARK: - Orientation

    /// Portrait로 회전한 뒤 completion 호출. 회전 애니메이션이 실제로 끝난 뒤 호출됨.
    static func rotateToPortrait(completion: @escaping () -> Void) {
        Task { @MainActor in
            orientationMask = .portrait
            applyOrientationRequest(.portrait)
            await waitUntilOrientation(targetIsPortrait: true)
            completion()
        }
    }

    /// 현재 기기 물리 방향을 읽어 해당 가로 방향으로 회전한 뒤 completion 호출.
    /// 회전 애니메이션이 실제로 끝난 뒤 호출되며, 완료 후에는 mask가 .landscape로 넓혀져
    /// 두 가로 방향 모두 자유롭게 회전할 수 있다.
    static func rotateToLandscape(completion: @escaping () -> Void) {
        Task { @MainActor in
            let targetDirection = await detectLandscapeMask()
            orientationMask = targetDirection
            applyOrientationRequest(targetDirection)
            await waitUntilOrientation(targetIsPortrait: false)
            orientationMask = .landscape
            completion()
        }
    }

    /// iOS 16+는 requestGeometryUpdate로, iOS 15는 UIDevice KVC로 회전을 요청한다.
    private static func applyOrientationRequest(_ mask: UIInterfaceOrientationMask) {
        let scene = activeWindowScene()
        if #available(iOS 16.0, *) {
            scene?.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
            scene?.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        } else {
            UIDevice.current.setValue(fallbackOrientation(for: mask).rawValue, forKey: "orientation")
        }
    }

    private static func fallbackOrientation(for mask: UIInterfaceOrientationMask) -> UIInterfaceOrientation {
        if mask.contains(.portrait) { return .portrait }
        if mask.contains(.landscapeLeft) { return .landscapeLeft }
        if mask.contains(.landscapeRight) { return .landscapeRight }
        return .portrait
    }

    /// interfaceOrientation이 목표 상태에 도달할 때까지 최대 2초 폴링.
    private static func waitUntilOrientation(targetIsPortrait: Bool) async {
        var waited: Double = 0
        while waited < 2 {
            if let orient = activeWindowScene()?.interfaceOrientation,
               orient.isPortrait == targetIsPortrait {
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
            waited += 0.05
        }
    }

    private static func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }

    /// 가속도계를 1회 켜서 현재 기기 방향에 맞는 landscape mask를 결정.
    /// 기기가 세로/평평한 상태면 기본 .landscapeRight 반환.
    private static func detectLandscapeMask() async -> UIInterfaceOrientationMask {
        guard motionManager.isAccelerometerAvailable else { return .landscapeRight }

        motionManager.accelerometerUpdateInterval = 0.05

        let xValue: Double = await withCheckedContinuation { continuation in
            let lock = NSLock()
            var resumed = false
            motionManager.startAccelerometerUpdates(to: OperationQueue.main) { data, _ in
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                motionManager.stopAccelerometerUpdates()
                continuation.resume(returning: data?.acceleration.x ?? 0)
            }
        }

        return xValue > 0 ? .landscapeLeft : .landscapeRight
    }
}
