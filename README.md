# AI Usage Monitor

macOS 메뉴바 앱으로 AI 서비스 사용량을 실시간으로 모니터링합니다.

<img width="300" alt="screenshot" src="docs/screenshot.png">

## 지원 서비스

- **Claude** - Claude Code OAuth 자격증명을 통한 사용량 조회
  - 5시간 윈도우 사용량
  - 7일 윈도우 사용량
  - 플랜 정보 (Max, Pro, Team 등)

- **Codex** - `~/.codex` 세션 기반 사용량 추적

## 설치

### 요구사항
- macOS 14.0 (Sonoma) 이상
- Claude Code 설치 및 로그인 (Claude 모니터링용)

### 다운로드
[Releases](../../releases) 페이지에서 최신 DMG 파일을 다운로드하세요.

### 설치 방법
1. DMG 파일을 열고 "AI Usage Monitor"를 Applications 폴더로 드래그
2. **중요**: 첫 실행 시 앱을 **우클릭** → **열기** 선택
   - 서명되지 않은 앱이므로 Gatekeeper 경고가 표시됩니다
   - "열기" 버튼을 클릭하여 실행을 허용하세요

## 기능

### 메뉴바 표시
- 각 서비스별 남은 쿼터를 시각적 바 차트로 표시
- X축: 5시간 남은 비율 (바 개수)
- Y축: 7일 남은 비율 (바 높이)

### 상세 정보
- 5시간/7일 윈도우별 남은 쿼터 퍼센트
- 다음 리필까지 남은 시간
- 사용량 히스토리 그래프

### 설정
- 서비스별 활성화/비활성화
- 갱신 주기 설정 (1분, 5분, 15분, 30분)
- 로그인 시 자동 실행
- 다국어 지원 (한국어, English, 日本語, 中文, Español, Français, Deutsch, Português, Русский, Italiano)

## 빌드

```bash
# 개발 빌드
swift build

# 릴리스 빌드 (.app 번들 생성)
./scripts/build-app.sh 1.0.0
```

## 라이선스

MIT License
