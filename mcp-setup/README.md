# RPLS MCP Setup - DMG 빌더

Claude Desktop 사용자를 위한 MCP (Model Context Protocol) 환경을 자동 구성하는 macOS 설치 패키지를 생성합니다.

## 🎯 기능

- **자동 Node.js 설치**: NVM을 통해 LTS 버전 설치
- **mcp-remote 설치**: 글로벌 npm 패키지로 설치
- **Claude Desktop 설정**: `claude_desktop_config.json` 자동 업데이트
- **스마트 감지**: Claude Desktop이 없는 경우 설치 생략

## 🚀 사용법

### 빠른 빌드

```bash
./build.sh
```

### 버전 지정 빌드

```bash
./build.sh 1.2.0
```

### 고급 빌드 (직접)

```bash
./create-dmg.sh
```

### 환경변수로 버전 설정

```bash
VERSION=1.2.0 ./create-dmg.sh
```

### 🔒 권한 문제 없는 완전 서명 빌드 (권장!)

```bash
# Apple Developer ID가 있는 경우 - 대화형 설정
./build-signed.sh 1.2.0

# 또는 환경변수로 설정
export DEVELOPER_ID="Developer ID Installer: Your Name (TEAM_ID)"
export ENABLE_CODE_SIGNING=true
export ENABLE_NOTARIZATION=true
export APPLE_ID="your-apple-id@example.com"
export TEAM_ID="YOUR_TEAM_ID"
export APP_SPECIFIC_PASSWORD="your-app-specific-password"
./build.sh 1.2.0
```

## 📦 생성되는 파일

빌드 완료 후 `mac/macos/dist/` 디렉토리에 생성됩니다:

- `rpls-mcp-setup-{버전}.pkg` - macOS 설치 패키지
- `rpls-mcp-setup-{버전}.dmg` - 배포용 디스크 이미지

## 🛠 시스템 요구사항

### 빌드 환경

- macOS 10.12 이상
- Xcode Command Line Tools
- Git (버전 자동 감지용, 선택적)

### 타겟 시스템

- macOS 10.12 이상
- Claude Desktop 앱 설치 필요
- 인터넷 연결 (Node.js 다운로드용)

## 📋 설치되는 내용

1. **Node.js 환경**

   - NVM 설치 (없는 경우)
   - Node.js LTS 버전
   - 셸 프로필 자동 구성

2. **MCP 도구**

   - `mcp-remote` npm 패키지

3. **Claude Desktop 설정**
   ```json
   {
     "mcpServers": {
       "rpls": {
         "command": "npx",
         "args": [
           "mcp-remote",
           "https://agentgateway.damoa.rapportlabs.dance/mcp"
         ]
       }
     }
   }
   ```

## 🔍 디버깅

### 빌드 로그

모든 단계에서 상세한 컬러 로그를 제공합니다:

- 🔵 정보 메시지
- 🟢 성공 메시지
- 🟡 경고 메시지
- 🔴 에러 메시지
- 🟣 단계별 진행사항

### 일반적인 문제

**Q: PKG 빌드가 실패해요**
A: Xcode Command Line Tools가 설치되어 있는지 확인하세요:

```bash
xcode-select --install
```

**Q: 권한 에러가 발생해요**
A: 스크립트에 실행 권한이 있는지 확인하세요:

```bash
chmod +x build.sh create-dmg.sh
```

**Q: DMG 마운트 테스트를 건너뛰고 싶어요**
A: 프롬프트에서 'N' 또는 Enter를 누르세요.

## 🔐 권한 문제 해결 가이드

### 설치 시 발생하는 권한 문제들

#### 1. "신뢰할 수 없는 개발자" 경고

**문제**: macOS에서 서명되지 않은 PKG 파일 실행 시 차단
**해결방법**:

```bash
# 방법 1: 시스템 설정에서 허용
System Settings > Privacy & Security > General > "Open Anyway" 클릭

# 방법 2: 터미널에서 격리 속성 제거
xattr -d com.apple.quarantine rpls-mcp-setup-*.pkg

# 방법 3: 일시적 보안 정책 완화
sudo spctl --master-disable  # 설치 후 다시 활성화 권장: sudo spctl --master-enable
```

#### 2. 관리자 권한 요구

**문제**: 설치 중 비밀번호 입력 요구
**해결방법**: 정상적인 과정입니다. 사용자 비밀번호를 입력하세요.

#### 3. 네트워크 연결 실패

**문제**: Node.js 다운로드 실패
**해결방법**:

```bash
# 1. 네트워크 연결 확인
ping google.com

# 2. 방화벽 설정 확인 (회사 네트워크)
# 3. VPN 비활성화 후 재시도
# 4. 수동 Node.js 설치
brew install node
# 또는 https://nodejs.org 에서 직접 다운로드
```

#### 4. npm 글로벌 설치 실패

**문제**: `npm install -g` 권한 오류
**해결방법**:

```bash
# 방법 1: npm prefix 변경 (권장)
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'
export PATH=~/.npm-global/bin:$PATH

# 방법 2: sudo 사용 (비권장)
sudo npm install -g mcp-remote

# 방법 3: npx 사용 (설치 불필요)
# 스크립트가 자동으로 npx 사용으로 전환
```

### 🔒 완전한 권한 보장 (Apple Developer용)

#### 방법 1: 대화형 스크립트 (가장 쉬움)

```bash
./build-signed.sh 1.0.0
```

이 스크립트가 자동으로 다음을 처리합니다:

- ✅ 개발자 인증서 자동 감지
- ✅ Apple ID, Team ID, 앱 전용 비밀번호 입력 안내
- ✅ PKG + DMG 코드 사이닝
- ✅ Apple 공증 및 스테이플링
- ✅ 권한 문제 완전 해결!

#### 방법 2: 환경변수 설정

```bash
# 필수 설정
export DEVELOPER_ID="Developer ID Installer: Your Name (TEAM_ID)"
export ENABLE_CODE_SIGNING=true
export ENABLE_NOTARIZATION=true

# 공증용 설정
export APPLE_ID="your-apple-id@example.com"
export TEAM_ID="YOUR_TEAM_ID"
export APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"

# 빌드 실행
./build.sh 1.0.0
```

#### Apple 공증 설정 가이드

1. **Apple ID**: 개발자 계정 이메일
2. **Team ID**: [개발자 포털](https://developer.apple.com/account)에서 확인
3. **앱 전용 비밀번호**: [Apple ID 관리](https://appleid.apple.com/account/manage)에서 생성

#### 결과

완전 서명된 DMG는 다른 Mac에서:

- ❌ "신뢰할 수 없는 개발자" 경고 **없음**
- ❌ 시스템 설정 변경 **불필요**
- ✅ **즉시 설치 가능**

### 문제 신고 전 체크리스트

설치 실패 시 다음을 확인 후 이슈 신고해주세요:

- [ ] macOS 버전: `sw_vers -productVersion`
- [ ] Claude Desktop 설치 위치: `/Applications/Claude.app` 또는 `~/Applications/Claude.app`
- [ ] 네트워크 연결 상태
- [ ] 관리자 권한 여부
- [ ] 에러 메시지 전문
- [ ] 콘솔 로그 (`Console.app`에서 "rpls" 검색)

## 📁 프로젝트 구조

```
mcp-setup/
├── build.sh                    # 🚀 기본 빌드 (서명 없음)
├── build-signed.sh             # 🔒 권한 보장 빌드 (서명+공증)
├── create-dmg.sh               # ⚙️  메인 DMG 생성 엔진
├── README.md                   # 📖 사용 설명서
└── mac/
    └── macos/
        ├── install-scripts/
        │   ├── postinstall     # 📦 PKG 설치 후 실행 스크립트
        │   └── claude-mcp-setup.sh # 🔧 실제 Claude 설정 로직
        └── dist/               # 📁 빌드 결과물
            ├── rpls-mcp-setup-*.pkg
            └── rpls-mcp-setup-*.dmg
```

## 🤝 기여

이슈나 개선사항이 있으면 GitHub 이슈를 등록해주세요.

## 📄 라이센스

MIT License
