# MultimediaPlayer

AVFoundation 기반 iOS 멀티미디어 플레이어 클론 코딩 프로젝트.  
실무에서 SwiftUI + Clean Architecture 기반 멀티미디어 앱을 개발한 경험을 바탕으로, UIKit MVC 환경에서 동일한 미디어 기능을 구현하며 아키텍처별 차이를 비교하기 위해 진행했습니다.

---

## ⚙️ 시작하기

`Secret.xcconfig.example`을 복사해 `Secret.xcconfig`를 생성하고 URL 값을 채웁니다.

```bash
cp Secret.xcconfig.example Secret.xcconfig
```

```xcconfig
VIDEO_VOD_URL = https:$()/your-video-vod-url
AUDIO_VOD_URL = https:$()/your-audio-vod-url
```

> `$()` 는 xcconfig에서 `//` 주석 처리를 피하기 위한 빈 문자열 확장입니다.

---

## ✨ 구현 기능

### 🎬 비디오 플레이어
- HLS VOD 재생 (seek, 전체 재생시간 표시)
- 라이브 HLS 재생 (LIVE 뱃지, seek 비활성화)
- 커스텀 컨트롤 오버레이 (3초 자동 숨김, 탭 토글)
- 15초 앞/뒤 건너뛰기
- PIP (Picture in Picture)
- AirPlay
- 잠금화면/제어센터 연동 (MediaPlayer 프레임워크)
- 기기 방향 감지 기반 자동 가로 전환, 종료 시 세로 복귀 (CoreMotion + `requestGeometryUpdate` / iOS 15 fallback)

### 📻 라디오 플레이어
- HLS 오디오 VOD 재생 (seek, 재생속도 조절: 0.5x ~ 2.0x)
- 라이브 오디오 HLS 재생 (LIVE 뱃지, seek 비활성화)
- 백그라운드 재생
- 잠금화면/제어센터 연동
- 오디오 인터럽션 처리 (전화, 알림)
- 이어폰 분리 자동 일시정지
- AirPlay

### 📥 다운로드
- HLS 오프라인 저장 (AVAssetDownloadURLSession)
- 백그라운드 다운로드 지원
- 진행률 표시
- 완료 시 로컬 푸시 알림
- 다운로드 파일 삭제 (디스크에서 완전 제거)
- 앱 재시작 후 완료 상태 복원 (UserDefaults 영속화)

---

## 🛠 기술 스택

| 분류 | 사용 기술 |
|------|-----------|
| 언어 | Swift 5 |
| 최소 버전 | iOS 15.0 |
| 지원 기기 | iPhone, iPad |
| UI | UIKit, SnapKit |
| 아키텍처 | MVC |
| 미디어 재생 | AVFoundation (AVPlayer, AVPlayerLayer) |
| HLS 다운로드 | AVAssetDownloadURLSession |
| 잠금화면 연동 | MediaPlayer (MPNowPlayingInfoCenter, MPRemoteCommandCenter) |
| PIP | AVPictureInPictureController |
| AirPlay | AVRoutePickerView |
| 알림 | UNUserNotificationCenter |
| 기기 방향 감지 | CoreMotion (CMMotionManager) |

---

## 📁 프로젝트 구조

```
MultimediaPlayer/
├── App/                  # AppDelegate, SceneDelegate, Config
├── Models/               # MediaItem, DownloadItem
├── Controllers/          # MainViewController, VideoPlayerViewController,
│                         # AudioPlayerViewController, DownloadListViewController
├── Views/                # PlayerControlView (커스텀 비디오 컨트롤)
├── Services/             # DownloadManager, NotificationManager
└── Resources/            # Assets.xcassets
Secret.xcconfig           # URL 설정 (gitignore)
Secret.xcconfig.example   # 설정 템플릿
```

---

## 🔧 트러블 슈팅

### 1. 세로 잠금 상태에서 `UIDevice.current.orientation`이 실제 방향을 알려주지 않음
- **문제**: 메인 화면이 세로 고정인 상태에서 기기를 가로로 들어도 `UIDevice.current.orientation`이 `.unknown` 또는 `.faceUp`만 반환해 실제 기기 방향을 판별할 수 없음.
- **원인**: `UIDevice.orientation`은 앱이 해당 방향을 지원할 때만 값이 갱신됨. 세로 잠금이면 가로 방향은 반영되지 않음.
- **해결**: `CMMotionManager`로 가속도계를 한 번 읽어 `x` 축 값으로 기울기를 직접 판단. VOD 진입 시점에만 센서를 켜서 배터리 영향 최소화.

### 2. 가속도계 값 → 화면 방향 매핑 오류
- **문제**: 기기를 왼쪽으로 기울이면 반대 방향(오른쪽)으로 회전.
- **원인**: `UIDeviceOrientation`(가속도계)과 `UIInterfaceOrientation`(UI/status bar가 어느 방향을 향하는가)은 서로 반대 방향으로 정의되어 있으나, 같은 방향이라고 이해하고 매핑.
- **해결**:
  - 가속도계 `x > 0`(Portrait 기준 휴대폰이 왼쪽으로 기운 상태) → `.landscapeLeft`(Portrait 기준 오른쪽 면이 상단으로)
  - 가속도계 `x <= 0`(Portrait 기준 휴대폰이 안 기울거나 오른쪽으로 기운 상태) → `.landscapeRight`(Portrait 기준 왼쪽 면이 상단으로)

### 3. `requestGeometryUpdate` 호출 후 회전 완료 시점을 알 수 없음
- **문제**: VOD 화면을 닫을 때 회전 애니메이션 없이 즉시 세로로 바뀌는 현상.
- **원인**: `requestGeometryUpdate`는 회전을 요청만 하고 완료를 알리는 콜백이 없음. 시간을 어림잡아 기다리면 타이밍이 어긋남.
- **해결**: `UIWindowScene.interfaceOrientation` 값을 짧은 간격(50ms)으로 반복 확인해 실제 방향이 목표에 도달한 뒤 다음 동작 실행. `AppDelegate.rotateToLandscape(completion:)` / `rotateToPortrait(completion:)`로 공용 함수 추출.

### 4. Xcode 경고 — "All interface orientations must be supported unless the app requires full screen"
- **문제**: iPhone과 iPad 모두 지원하는 Universal 설정 + 세로만 허용하는 `UISupportedInterfaceOrientations` 조합에서 경고 발생.
- **원인**: iPad Multitasking(Split View / Slide Over / Stage Manager) 지원을 위해서는 iPad Orientation을 4방향 모두 허용하거나 `UIRequiresFullScreen = YES`로 Multitasking을 사용하지 않겠다고 선언해야 함.
- **해결**: 현재 Multitasking 기능 미제공으로 설정, `UIRequiresFullScreen = YES`.

---

## 💬 회고

### MVC의 장점

**UIKit과의 높은 친화성**이 가장 큰 이점이었습니다. UIKit 자체가 MVC를 전제로 설계되어 있어, `UIViewController`가 화면 생명주기와 UI 이벤트를 모두 담당하는 구조가 자연스럽게 맞아떨어졌습니다. 별도의 바인딩 레이어 없이도 빠르게 기능을 구현할 수 있었고, 코드 흐름을 한 파일 안에서 위에서 아래로 읽을 수 있어 초기 구현 속도가 빨랐습니다.

또한 `PlayerControlViewDelegate`처럼 프로토콜을 활용해 View와 Controller 사이의 역할을 명확하게 나눌 수 있었고, `DownloadManager` 같은 싱글턴 서비스 레이어를 두어 Controller가 직접 네트워크나 파일 I/O를 다루지 않도록 구조화하는 것도 어렵지 않았습니다.

### MVC의 단점 — Massive View Controller

**VideoPlayerViewController**와 **AudioPlayerViewController**가 대표적입니다.

두 파일 모두 다음 역할을 한 클래스에서 담당합니다.
- AVPlayer 생명주기 관리 (재생/일시정지/탐색)
- KVO 옵저버 등록/해제 (status, duration, timeControlStatus)
- UI 상태 업데이트 (버튼 이미지, 시간 레이블, LIVE 뱃지 전환)
- MediaPlayer 연동 (nowPlayingInfo 갱신, RemoteCommand 등록)
- 오디오 세션 관리 (인터럽션, 라우트 변경 처리)

결과적으로 `AudioPlayerViewController`는 500줄 이상, `VideoPlayerViewController`는 300줄 이상에 달하며, 한 곳을 수정할 때 다른 역할에 의도치 않은 영향을 주는 일이 반복되었습니다.

**재생 상태와 UI 상태의 이중 관리**도 문제였습니다. 예를 들어 재생속도를 변경하면:
1. `player.rate` 업데이트
2. `UISegmentedControl` 선택 인덱스 업데이트
3. `nowPlayingInfo` 갱신

이 세 가지가 ViewController 안에서 직접 연결되어 있어, 새로운 진입점(예: RemoteCommand에서 속도 변경)이 생길 때마다 같은 로직을 여러 곳에 흩어서 작성해야 했습니다.

### MVVM 전환 시 어떤 부분부터 할지

우선순위 순으로 다음 순서를 권장합니다.

**1단계 — AudioPlayerViewModel 분리**  
`AudioPlayerViewController`에서 재생 로직을 `AudioPlayerViewModel`로 추출합니다. `playbackRate`, `isPlaying`, `currentTime`, `duration`을 `@Published` 또는 클로저 바인딩으로 노출하면, ViewController는 UI 업데이트만 담당하게 됩니다. MediaPlayer 연동도 ViewModel 안으로 이동합니다.

**2단계 — VideoPlayerViewModel 분리**  
비디오는 `PlayerControlViewDelegate` 프로토콜이 이미 ViewController와 View 사이를 분리하고 있어 상대적으로 리팩토링이 수월합니다. Delegate를 ViewModel이 구현하도록 변경하면 자연스럽게 분리됩니다.

**3단계 — DownloadViewModel 도입**  
`DownloadManager`의 NotificationCenter 이벤트를 ViewModel이 수신하고, 가공된 `[DownloadCellModel]` 배열을 바인딩으로 노출합니다. ViewController는 배열을 받아 `reloadData()`만 호출하면 됩니다.

이 프로젝트를 통해 MVC의 한계를 직접 체감했으며, 실무에서 MVVM + Clean Architecture를 적용했을 때의 이점을 더 깊이 이해할 수 있었습니다.
