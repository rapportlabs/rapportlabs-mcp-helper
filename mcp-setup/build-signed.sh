#!/usr/bin/env bash
set -euo pipefail

# 권한 문제 없는 완전히 서명된 DMG 생성 스크립트
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"

# 컬러 출력
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

echo -e "${CYAN}🔒 RPLS MCP Setup - 완전 서명 빌드${NC}"
echo ""

# 사용법 체크
if [ $# -gt 1 ]; then
    echo "사용법: $0 [버전]"
    echo "예시: $0 1.2.0"
    exit 1
fi

# 1. Apple Developer 설정 확인
log_step "1️⃣  Apple Developer 설정 확인"

# 개발자 인증서 자동 감지
INSTALLER_CERT=$(security find-identity -v -p codesigning | grep "Developer ID Installer" | head -1 | sed -E 's/.*"([^"]+)".*/\1/' || echo "")
APP_CERT=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed -E 's/.*"([^"]+)".*/\1/' || echo "")

if [ -z "$INSTALLER_CERT" ]; then
    log_error "Developer ID Installer 인증서를 찾을 수 없습니다."
    echo ""
    echo "해결방법:"
    echo "1. Apple Developer Program 가입: https://developer.apple.com/programs/"
    echo "2. Xcode에서 인증서 다운로드:"
    echo "   Xcode > Settings > Accounts > Manage Certificates > +"
    echo "3. 또는 직접 다운로드: https://developer.apple.com/account/resources/certificates"
    exit 1
fi

log_success "Developer ID Installer: $INSTALLER_CERT"

if [ -n "$APP_CERT" ]; then
    log_success "Developer ID Application: $APP_CERT"
else
    log_warn "Developer ID Application 인증서가 없습니다 (DMG 서명 불가)"
fi

# 2. 공증 설정 확인 및 입력
log_step "2️⃣  Apple 공증 설정"

# Apple ID 입력
if [ -z "${APPLE_ID:-}" ]; then
    read -p "Apple ID (이메일): " APPLE_ID
    export APPLE_ID
fi

# Team ID 입력
if [ -z "${TEAM_ID:-}" ]; then
    echo ""
    echo "Team ID 찾기:"
    echo "1. https://developer.apple.com/account 접속"
    echo "2. Membership 메뉴에서 Team ID 확인"
    echo "3. 또는 다음 명령어 실행: xcrun altool --list-providers -u \"$APPLE_ID\" -p \"앱전용비밀번호\""
    echo ""
    read -p "Team ID (10자리 영숫자): " TEAM_ID
    export TEAM_ID
fi

# App Specific Password 입력
if [ -z "${APP_SPECIFIC_PASSWORD:-}" ]; then
    echo ""
    echo "앱 전용 비밀번호 생성:"
    echo "1. https://appleid.apple.com/account/manage 접속"
    echo "2. 로그인 > 보안 > 앱 전용 비밀번호"
    echo "3. '비밀번호 생성' 클릭"
    echo ""
    read -s -p "앱 전용 비밀번호 (입력 숨겨짐): " APP_SPECIFIC_PASSWORD
    echo ""
    export APP_SPECIFIC_PASSWORD
fi

log_success "공증 설정 완료"
log_info "Apple ID: $APPLE_ID"
log_info "Team ID: $TEAM_ID"

# 3. 환경변수 설정 및 빌드 실행
log_step "3️⃣  서명된 빌드 시작"

export ENABLE_CODE_SIGNING=true
export ENABLE_NOTARIZATION=true
export DEVELOPER_ID="$INSTALLER_CERT"

# 버전 설정
if [ $# -eq 1 ]; then
    export VERSION="$1"
    log_info "버전 설정: $VERSION"
fi

echo ""
log_info "🚀 완전 서명 빌드를 시작합니다..."
log_warn "공증 과정은 수 분이 소요될 수 있습니다."
echo ""

# 메인 빌드 스크립트 실행
"$SCRIPT_DIR/create-dmg.sh"

echo ""
log_success "🎉 권한 문제 없는 DMG가 생성되었습니다!"
echo ""
echo -e "${GREEN}✨ 이제 다른 Mac에서도 권한 경고 없이 설치됩니다!${NC}"
