# Windows11 One Click Optimizer
사용방법은 리포지토리 Clone 후
Windows11_OneClick_Optimizer.cmd를 더블클릭 후
Recommended to reboot 메시지가 뜨면 재부팅을 수행하면 됩니다.

피드백은 s_vettel@naver.com으로 부탁드립니다.

업데이트(2026-06-04): Certificate Propagation 서비스 비활성화와 Family, Solitaire & Casual Games, Feedback Hub 앱 제거 항목을 추가했습니다.

업데이트(2026-06-01): Xbox, Xbox Identity Provider, Xbox Live, Game Bar, Game Speech Window 앱 제거 항목을 추가했습니다.

업데이트(2026-05-31): Windows 백업의 내 앱 기억하기 비활성화와 파일 탐색기 동기화 공급자 알림 표시 비활성화 항목을 추가했습니다.

---
## 테스트 기기

### 랩탑
갤럭시 북6 프로 Core Ultra X7 358H 32GB, Windows 11 Pro x64

서피스 프로 11 Snapdragon X Plus 16GB, Windows 11 Home

서피스 프로 9 i5-1235u 16GB, Windows 11 Home

### 데스크탑
Core Ultra 7 270k Plus 32GB 5600MHz, Windows 11 Pro

---
## 벤치마크 결과 비교(Geekbench 6 기준)
Surface Pro 9  
https://browser.geekbench.com/v6/cpu/8716178 - 최적화 전 벤치마크(8123)  
https://browser.geekbench.com/v6/cpu/8809756 - 최적화 후 벤치마크(9157, 12.7% 상승)  
  
Surface Pro 11, Snapdragon X Plus  
https://browser.geekbench.com/v6/cpu/8257745 - 최적화 전 벤치마크(12649)  
https://browser.geekbench.com/v6/cpu/8811750 - 최적화 후 벤치마크(13368, 5.7% 상승)  

---

## 1. 개인정보 / 추천 / 광고 관련 기능 비활성화

스크립트는 Windows 11의 개인정보, 추천 콘텐츠, 광고성 기능을 축소하거나 비활성화합니다.

적용 항목은 다음과 같습니다.

- 광고 ID 사용 비활성화
- 언어 목록 기반 웹사이트 접근 비활성화
- 시작 메뉴 앱 실행 추적 비활성화
- Microsoft 추천 콘텐츠 비활성화
- Windows 소비자 기능 비활성화
- Windows Spotlight 관련 기능 비활성화
- 맞춤형 환경 / 진단 데이터 기반 추천 비활성화
- 사전 설치 앱 추천 및 자동 설치 관련 Content Delivery 항목 비활성화

---

## 2. 피드백 및 진단 데이터 관련 설정 조정

Windows 진단 데이터, 피드백 요청, 입력 개인화 관련 수집 기능을 제한합니다.

적용 항목은 다음과 같습니다.

- 진단 데이터 수준 제한
- 진단 로그 수집 제한
- 덤프 수집 제한
- 피드백 알림 비활성화
- 진단 데이터 기반 맞춤 환경 비활성화
- 피드백 주기 비활성화
- 입력 개인화 관련 수집 비활성화
- 필기 / 입력 텍스트 암시적 수집 제한
- 연락처 기반 학습 데이터 수집 비활성화

> 참고: `AllowTelemetry` 값은 `1`로 설정됩니다. 이는 완전 차단이 아니라 Windows 정책상 최소 / 필수 진단 데이터 수준으로 제한하는 방식입니다.

---

## 3. 계정 / Windows 백업 / 내 앱 기억하기 비활성화

Windows 백업의 앱 기억하기 기능을 비활성화합니다.

적용 항목은 다음과 같습니다.

- 계정 > Windows 백업 > 내 앱 기억하기 비활성화
- 앱 목록 및 앱 관련 설정 동기화 비활성화
- 사용자에 의한 앱 동기화 설정 재활성화 방지

설정되는 주요 값은 다음과 같습니다.

```text
HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync
DisableAppSyncSettingSync = 2
DisableAppSyncSettingSyncUserOverride = 1
DisableApplicationSettingSync = 2
DisableApplicationSettingSyncUserOverride = 1
```

적용 효과는 다음과 같습니다.

- Windows 백업에서 앱 기억하기 기능 비활성화
- Microsoft 계정 기반 앱 동기화 제한
- 동일 계정으로 로그인한 다른 Windows 장치 간 앱 복원 / 추천 동작 축소

---

## 4. Windows 검색 / Bing / Cortana / 클라우드 검색 비활성화

Windows 검색 기능에서 웹 검색, Bing, Cortana, 클라우드 검색 관련 기능을 비활성화합니다.

적용 항목은 다음과 같습니다.

- Bing 웹 검색 비활성화
- Cortana 동의 비활성화
- 검색에서 위치 사용 비활성화
- Microsoft 계정 클라우드 검색 비활성화
- Azure AD 클라우드 검색 비활성화
- 장치 검색 기록 비활성화
- 동적 검색 상자 콘텐츠 비활성화
- Windows Search 웹 검색 비활성화
- 검색 상자 추천 비활성화
- 클라우드 검색 비활성화
- 측정 연결에서 웹 검색 사용 비활성화

---

## 5. 지정 Windows 서비스 비활성화 및 중지

아래 서비스의 시작 유형을 `사용 안 함(Disabled)`으로 변경하고, 실행 중이면 중지합니다.

| 서비스 이름 | 표시 이름 | 처리 내용 |
|---|---|---|
| `DiagTrack` | Connected User Experiences and Telemetry | 시작 유형 Disabled, 서비스 중지 |
| `SCardSvr` | Smart Card | 시작 유형 Disabled, 서비스 중지 |
| `ScDeviceEnum` | Smart Card Device Enumeration Service | 시작 유형 Disabled, 서비스 중지 |
| `SCPolicySvc` | Smart Card Removal Policy | 시작 유형 Disabled, 서비스 중지 |
| `CertPropSvc` | Certificate Propagation | 시작 유형 Disabled, 서비스 중지 |
| `WSearch` | Windows Search | 시작 유형 Disabled, 서비스 중지 |
| `SEMgrSvc` | Payments and NFC/SE Manager | 시작 유형 Disabled, 서비스 중지 |

서비스가 시스템에 존재하지 않는 경우에는 오류로 중단하지 않고 경고만 출력한 뒤 다음 항목으로 진행합니다.

---

## 6. Windows Update 배달 최적화 비활성화

Windows Update의 배달 최적화 기능 중 다른 PC와 업데이트 데이터를 주고받는 P2P 다운로드 기능을 비활성화합니다.

설정되는 주요 값은 다음과 같습니다.

```text
DODownloadMode = 0
DownloadMode = 0
```

적용 효과는 다음과 같습니다.

- LAN / 인터넷 기반 P2P 업데이트 다운로드 비활성화
- Windows Update 다운로드를 HTTP 기반 방식으로 제한
- 다른 장치에 업데이트 데이터를 제공하는 동작 차단

---

## 7. 전원 설정 조정

전원 계획 및 CPU 성능 관련 전원 설정을 조정합니다.

적용 항목은 다음과 같습니다.

- 전원 계획을 Balanced로 설정
- AC 전원 사용 시 CPU 최소 상태를 100%로 설정
- AC 전원 사용 시 CPU 최대 상태를 100%로 설정
- AC 전원 사용 시 Energy Performance Preference를 0으로 설정
- 배터리 사용 시 CPU 최소 상태를 5%로 설정
- 배터리 사용 시 CPU 최대 상태를 100%로 설정
- 배터리 사용 시 Energy Performance Preference를 50으로 설정
- 현재 전원 계획을 다시 활성화

---

## 8. 메모리 관리 기능 활성화

PowerShell `MMAgent` 기능을 사용하여 Windows 메모리 관리 기능을 활성화합니다.

활성화 항목은 다음과 같습니다.

- Memory Compression
- Page Combining

적용 후 현재 `MMAgent` 상태를 출력합니다.

---

## 9. Xbox Game Bar 관련 기능 비활성화

Xbox Game Bar 및 게임 관련 자동 기능을 비활성화합니다.

적용 항목은 다음과 같습니다.

- 컨트롤러 버튼으로 Game Bar 실행 비활성화
- Game Bar 시작 패널 표시 비활성화
- 자동 게임 모드 비활성화

---

## 10. Xbox / Game Bar 관련 앱 제거

`Program Files\WindowsApps` 아래에 설치되는 Xbox 및 Game Bar 관련 Appx 패키지를 제거합니다.

제거 대상은 다음과 같습니다.

| 항목 | Appx 패키지 패턴 |
|---|---|
| Xbox | `*Microsoft.GamingApp*` |
| Xbox legacy app | `*Microsoft.XboxApp*` |
| Xbox Identity Provider | `*Microsoft.XboxIdentityProvider*` |
| Xbox Live | `*Microsoft.Xbox.TCUI*` |
| Game Bar | `*Microsoft.XboxGamingOverlay*` |
| Game Bar overlay component | `*Microsoft.XboxGameOverlay*` |
| Game Speech Window | `*Microsoft.XboxSpeechToTextOverlay*` |

처리 범위는 다음과 같습니다.

- 현재 사용자 또는 시스템에 설치된 Appx 패키지 제거
- Provisioned Appx 패키지 제거
- Game Bar / Xbox 관련 프로세스가 실행 중인 경우 제거 전 강제 종료

제거 전 종료 대상 프로세스는 다음과 같습니다.

```text
GameBar
GameBarFTServer
GameBarPresenceWriter
XboxAppServices
XboxPcApp
```

`Program Files\WindowsApps` 폴더를 직접 삭제하지 않고 Windows Appx 제거 명령을 사용합니다.

---

## 11. Family / Solitaire & Casual Games / Feedback Hub 앱 제거

`Program Files\WindowsApps` 아래에 설치되는 Family, Solitaire & Casual Games, Feedback Hub 관련 Appx 패키지를 제거합니다.

제거 대상은 다음과 같습니다.

| 항목 | Appx 패키지 패턴 |
|---|---|
| Family | `*MicrosoftCorporationII.MicrosoftFamily*` |
| Family 보조 패턴 | `*MicrosoftFamily*` |
| Solitaire & Casual Games | `*Microsoft.MicrosoftSolitaireCollection*` |
| Feedback Hub | `*Microsoft.WindowsFeedbackHub*` |

처리 범위는 다음과 같습니다.

- 현재 사용자 또는 시스템에 설치된 Appx 패키지 제거
- Provisioned Appx 패키지 제거

`Program Files\WindowsApps` 폴더를 직접 삭제하지 않고 Windows Appx 제거 명령을 사용합니다.

---

## 12. 접근성 / 시각 효과 / 투명 효과 비활성화

Windows 개인 설정의 투명 효과를 비활성화합니다.

설정 경로와 값은 다음과 같습니다.

```text
HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize
EnableTransparency = 0
```

적용 효과는 다음과 같습니다.

- 시작 메뉴, 작업 표시줄, 창 배경 등에 적용되는 투명 효과 비활성화
- 시각 효과 감소
- 저사양 환경에서 UI 렌더링 부담 일부 감소 가능

---

## 13. 파일 탐색기 / 폴더 옵션 / 동기화 공급자 알림 비활성화

파일 탐색기의 폴더 옵션에서 동기화 공급자 알림 표시 기능을 비활성화합니다.

적용 항목은 다음과 같습니다.

- 폴더 옵션 > 보기 > 고급 설정 > 동기화 공급자 알림 표시 비활성화
- 파일 탐색기 내 OneDrive, Microsoft 365, 동기화 공급자 관련 추천 / 알림 표시 제한

설정되는 주요 값은 다음과 같습니다.

```text
HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced
ShowSyncProviderNotifications = 0
```

적용 효과는 다음과 같습니다.

- 파일 탐색기 상단 또는 내부에 표시되는 동기화 공급자 알림 감소
- Microsoft 서비스 추천성 알림 표시 축소
- 폴더 옵션의 고급 보기 설정과 일치하도록 Explorer 설정 적용

---

## 14. 잠금 화면 추천 / 팁 / 상태 표시 비활성화

잠금 화면에서 표시되는 추천 콘텐츠, 팁, Spotlight 관련 기능을 비활성화합니다.

적용 항목은 다음과 같습니다.

- 잠금 화면 Windows Spotlight 회전 배경 비활성화
- 잠금 화면 오버레이 추천 비활성화
- 잠금 화면 팁 / 추천 콘텐츠 비활성화
- 잠금 화면 상세 상태 앱 비활성화
- 잠금 화면 위젯 비활성화

---

## 15. 작업 표시줄 위젯 비활성화

Windows 11 작업 표시줄 및 정책 설정을 통해 위젯 기능을 비활성화합니다.

적용 항목은 다음과 같습니다.

- 정책 기반 위젯 비활성화
- Widgets Board 비활성화
- 작업 표시줄 Widgets 버튼 비활성화

관련 값은 다음과 같습니다.

```text
TaskbarDa = 0
```

---

## 16. 날씨 / 뉴스 앱 제거

Windows 기본 앱 중 날씨 및 뉴스 관련 Appx 패키지를 제거합니다.

제거 대상은 다음과 같습니다.

- Microsoft Bing Weather
- Microsoft Bing News
- Microsoft News
- Microsoft MicrosoftNews

처리 범위는 다음과 같습니다.

- 현재 사용자 또는 시스템에 설치된 Appx 패키지 제거
- Provisioned Appx 패키지 제거

단, 다음 패키지는 현재 설정상 제거하지 않습니다.

```text
MicrosoftWindows.Client.WebExperience
```

해당 패키지는 `$RemoveWebExperiencePack = $false`로 설정되어 있으므로 유지됩니다.
