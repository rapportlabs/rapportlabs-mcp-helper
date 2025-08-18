#!/usr/bin/env bash
set -euo pipefail

# 컬러 출력을 위한 함수들
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

# 스크립트 디렉토리 설정
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
MACOS_DIR="$SCRIPT_DIR/mac/macos"
SCRIPTS_DIR="$MACOS_DIR/install-scripts"
PAYLOAD_DIR="$MACOS_DIR/payload"
DIST_DIR="$MACOS_DIR/dist"
TMP_DMG_DIR="$MACOS_DIR/.dmg-src"

# 버전 설정 (환경변수나 git tag에서 가져오기)
VERSION="${VERSION:-$(git describe --tags 2>/dev/null | sed 's/^v//' || echo '1.0.0')}"
PKG_ID="com.rapportlabs.rpls.mcp.setup"
PKG_NAME="rpls-mcp-setup-${VERSION}.pkg"
DMG_NAME="rpls-mcp-setup-${VERSION}.dmg"

# 코드 사이닝 설정 (선택적)
DEVELOPER_ID="${DEVELOPER_ID:-}"
ENABLE_CODE_SIGNING="${ENABLE_CODE_SIGNING:-false}"
ENABLE_NOTARIZATION="${ENABLE_NOTARIZATION:-false}"
APPLE_ID="${APPLE_ID:-}"
APP_SPECIFIC_PASSWORD="${APP_SPECIFIC_PASSWORD:-}"
TEAM_ID="${TEAM_ID:-}"

# DMG 설정
DMG_TITLE="RPLS MCP Setup"
DMG_BACKGROUND_COLOR="#F5F5F5"

log_step "🚀 RPLS MCP Setup DMG 생성 시작"
log_info "버전: $VERSION"
log_info "패키지명: $PKG_NAME"
log_info "DMG명: $DMG_NAME"

# 1. 의존성 체크
log_step "1️⃣  의존성 체크 중..."

check_dependency() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log_error "$1이 설치되어 있지 않습니다."
        return 1
    fi
}

check_dependency "pkgbuild"
check_dependency "hdiutil"

# macOS 버전 체크
MACOS_VERSION=$(sw_vers -productVersion)
log_info "macOS 버전: $MACOS_VERSION"

# 코드 사이닝 의존성 체크
if [ "$ENABLE_CODE_SIGNING" = "true" ]; then
    log_info "코드 사이닝 활성화됨 - 개발자 인증서 확인 중..."
    
    # Developer ID 자동 감지 (지정되지 않은 경우)
    if [ -z "$DEVELOPER_ID" ]; then
        AUTO_DEVELOPER_ID=$(security find-identity -v -p codesigning | grep "Developer ID Installer" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
        if [ -n "$AUTO_DEVELOPER_ID" ]; then
            DEVELOPER_ID="$AUTO_DEVELOPER_ID"
            log_success "Developer ID 자동 감지됨: $DEVELOPER_ID"
        else
            log_error "Developer ID Installer 인증서를 찾을 수 없습니다."
            log_error "Apple Developer Program에 가입하고 인증서를 설치하세요."
            exit 1
        fi
    fi
    
    # 공증 의존성 체크
    if [ "$ENABLE_NOTARIZATION" = "true" ]; then
        check_dependency "xcrun"
        
        if [ -z "$APPLE_ID" ] || [ -z "$APP_SPECIFIC_PASSWORD" ] || [ -z "$TEAM_ID" ]; then
            log_error "공증을 위해 다음 환경변수가 필요합니다:"
            log_error "  APPLE_ID (Apple ID 이메일)"
            log_error "  APP_SPECIFIC_PASSWORD (앱 전용 비밀번호)"
            log_error "  TEAM_ID (팀 ID)"
            exit 1
        fi
        
        log_info "공증 설정 확인됨"
        log_info "  Apple ID: $APPLE_ID"
        log_info "  Team ID: $TEAM_ID"
    fi
fi

# 2. 디렉토리 준비
log_step "2️⃣  디렉토리 준비 중..."

mkdir -p "$PAYLOAD_DIR" "$DIST_DIR"

# 기존 빌드 파일들 정리
if [ -f "$DIST_DIR/$PKG_NAME" ]; then
    log_info "기존 PKG 파일 삭제: $PKG_NAME"
    rm -f "$DIST_DIR/$PKG_NAME"
fi

if [ -f "$DIST_DIR/$DMG_NAME" ]; then
    log_info "기존 DMG 파일 삭제: $DMG_NAME"
    rm -f "$DIST_DIR/$DMG_NAME"
fi

# 3. 스크립트 파일 검증 및 권한 설정
log_step "3️⃣  스크립트 파일 검증 중..."

POSTINSTALL_SCRIPT="$SCRIPTS_DIR/postinstall"
SETUP_SCRIPT="$SCRIPTS_DIR/claude-mcp-setup.sh"

if [ ! -f "$POSTINSTALL_SCRIPT" ]; then
    log_error "postinstall 스크립트를 찾을 수 없습니다: $POSTINSTALL_SCRIPT"
    exit 1
fi

if [ ! -f "$SETUP_SCRIPT" ]; then
    log_error "claude-mcp-setup.sh 스크립트를 찾을 수 없습니다: $SETUP_SCRIPT"
    exit 1
fi

# 실행 권한 설정
chmod +x "$POSTINSTALL_SCRIPT"
chmod +x "$SETUP_SCRIPT"
log_info "스크립트 실행 권한 설정 완료"

# 4. PKG 생성
log_step "4️⃣  PKG 파일 생성 중..."

# 기본 PKG 빌드
PKG_BUILD_ARGS=(
    --identifier "$PKG_ID"
    --version "$VERSION"
    --root "$PAYLOAD_DIR"
    --scripts "$SCRIPTS_DIR"
    --install-location "/"
)

# 코드 사이닝 옵션 추가
if [ "$ENABLE_CODE_SIGNING" = "true" ] && [ -n "$DEVELOPER_ID" ]; then
    log_info "코드 사이닝 활성화됨: $DEVELOPER_ID"
    
    # Developer ID 인증서 확인
    if security find-identity -v -p codesigning | grep -q "$DEVELOPER_ID"; then
        PKG_BUILD_ARGS+=(--sign "$DEVELOPER_ID")
        log_info "코드 사이닝 인증서 확인됨"
    else
        log_warn "코드 사이닝 인증서를 찾을 수 없습니다: $DEVELOPER_ID"
        log_warn "서명 없이 PKG를 생성합니다."
    fi
else
    log_info "코드 사이닝 비활성화 (사용자가 직접 허용 필요)"
fi

pkgbuild "${PKG_BUILD_ARGS[@]}" "$DIST_DIR/$PKG_NAME"

if [ -f "$DIST_DIR/$PKG_NAME" ]; then
    PKG_SIZE=$(du -h "$DIST_DIR/$PKG_NAME" | cut -f1)
    log_success "PKG 생성 완료: $PKG_NAME ($PKG_SIZE)"
else
    log_error "PKG 생성 실패"
    exit 1
fi

# 5. DMG 임시 디렉토리 준비
log_step "5️⃣  DMG 임시 디렉토리 준비 중..."

rm -rf "$TMP_DMG_DIR"
mkdir -p "$TMP_DMG_DIR"

# PKG 파일을 임시 디렉토리에 복사
cp "$DIST_DIR/$PKG_NAME" "$TMP_DMG_DIR/"

# README 파일 생성
cat > "$TMP_DMG_DIR/README.txt" << 'EOF'
RPLS MCP Setup for Claude Desktop
==================================

이 설치 프로그램은 Claude Desktop 사용자를 위한 MCP (Model Context Protocol) 환경을 자동으로 구성합니다.

설치 내용:
- Node.js (nvm을 통해)
- mcp-remote 패키지
- Claude Desktop 설정 업데이트

설치 방법:
1. rpls-mcp-setup-*.pkg 파일을 더블클릭
2. 설치 마법사를 따라 진행
3. Claude Desktop 재시작

주의사항:
- Claude Desktop이 설치되지 않은 경우 설치가 생략됩니다
- 네트워크 연결이 필요합니다 (Node.js 다운로드)

문의: https://github.com/rapportlabs/mcp-helper

EOF

log_info "README.txt 파일 생성 완료"

# 6. DMG 생성
log_step "6️⃣  DMG 파일 생성 중..."

hdiutil create \
    -volname "$DMG_TITLE" \
    -srcfolder "$TMP_DMG_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DIST_DIR/$DMG_NAME"

if [ -f "$DIST_DIR/$DMG_NAME" ]; then
    DMG_SIZE=$(du -h "$DIST_DIR/$DMG_NAME" | cut -f1)
    log_success "DMG 생성 완료: $DMG_NAME ($DMG_SIZE)"
else
    log_error "DMG 생성 실패"
    exit 1
fi

# DMG 코드 사이닝
if [ "$ENABLE_CODE_SIGNING" = "true" ] && [ -n "$DEVELOPER_ID" ]; then
    log_step "🔒 DMG 코드 사이닝 중..."
    
    # DMG용 Developer ID 찾기
    DMG_DEVELOPER_ID=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -n "$DMG_DEVELOPER_ID" ]; then
        log_info "DMG 서명용 인증서: $DMG_DEVELOPER_ID"
        
        if codesign --sign "$DMG_DEVELOPER_ID" --timestamp --options runtime "$DIST_DIR/$DMG_NAME"; then
            log_success "DMG 코드 사이닝 완료"
            
            # 서명 검증
            if codesign --verify --deep --strict "$DIST_DIR/$DMG_NAME"; then
                log_success "DMG 서명 검증 완료"
            else
                log_warn "DMG 서명 검증 실패"
            fi
        else
            log_warn "DMG 코드 사이닝 실패 - 계속 진행"
        fi
    else
        log_warn "Developer ID Application 인증서를 찾을 수 없습니다"
        log_info "PKG만 서명되었습니다"
    fi
fi

# 7. Apple 공증 (Notarization)
if [ "$ENABLE_NOTARIZATION" = "true" ] && [ "$ENABLE_CODE_SIGNING" = "true" ]; then
    log_step "🍎 Apple 공증 진행 중..."
    log_info "이 과정은 몇 분이 소요될 수 있습니다..."
    
    # PKG 공증
    log_info "PKG 공증 중: $PKG_NAME"
    PKG_SUBMISSION_ID=$(xcrun notarytool submit "$DIST_DIR/$PKG_NAME" \
        --apple-id "$APPLE_ID" \
        --password "$APP_SPECIFIC_PASSWORD" \
        --team-id "$TEAM_ID" \
        --wait 2>&1 | grep "id:" | awk '{print $2}')
    
    if [ -n "$PKG_SUBMISSION_ID" ]; then
        log_success "PKG 공증 완료: $PKG_SUBMISSION_ID"
        
        # PKG 스테이플링
        if xcrun stapler staple "$DIST_DIR/$PKG_NAME"; then
            log_success "PKG 스테이플링 완료"
        else
            log_warn "PKG 스테이플링 실패"
        fi
    else
        log_warn "PKG 공증 실패 - 계속 진행"
    fi
    
    # DMG 공증 (코드 사이닝된 경우만)
    if codesign --verify "$DIST_DIR/$DMG_NAME" 2>/dev/null; then
        log_info "DMG 공증 중: $DMG_NAME"
        DMG_SUBMISSION_ID=$(xcrun notarytool submit "$DIST_DIR/$DMG_NAME" \
            --apple-id "$APPLE_ID" \
            --password "$APP_SPECIFIC_PASSWORD" \
            --team-id "$TEAM_ID" \
            --wait 2>&1 | grep "id:" | awk '{print $2}')
        
        if [ -n "$DMG_SUBMISSION_ID" ]; then
            log_success "DMG 공증 완료: $DMG_SUBMISSION_ID"
            
            # DMG 스테이플링
            if xcrun stapler staple "$DIST_DIR/$DMG_NAME"; then
                log_success "DMG 스테이플링 완료"
            else
                log_warn "DMG 스테이플링 실패"
            fi
        else
            log_warn "DMG 공증 실패"
        fi
    else
        log_info "DMG가 서명되지 않아 공증을 건너뜁니다"
    fi
    
    log_success "🎉 공증 과정 완료!"
fi

# 8. 정리
log_step "8️⃣  임시 파일 정리 중..."
rm -rf "$TMP_DMG_DIR"
log_info "임시 디렉토리 정리 완료"

# 9. 최종 결과 출력
log_step "✅ 빌드 완료!"
echo ""
echo -e "${CYAN}생성된 파일들:${NC}"
echo "  📦 PKG: $DIST_DIR/$PKG_NAME"
echo "  💿 DMG: $DIST_DIR/$DMG_NAME"

# 코드 사이닝 상태 표시
if [ "$ENABLE_CODE_SIGNING" = "true" ]; then
    echo ""
    echo -e "${GREEN}🔒 보안 상태:${NC}"
    
    # PKG 서명 확인
    if codesign --verify "$DIST_DIR/$PKG_NAME" 2>/dev/null; then
        echo "  ✅ PKG 코드 사이닝됨"
        
        # PKG 공증 확인
        if spctl --assess --type install "$DIST_DIR/$PKG_NAME" 2>/dev/null; then
            echo "  ✅ PKG Apple 공증됨"
        else
            echo "  ⚠️  PKG 공증 상태 불명"
        fi
    else
        echo "  ❌ PKG 서명되지 않음"
    fi
    
    # DMG 서명 확인
    if codesign --verify "$DIST_DIR/$DMG_NAME" 2>/dev/null; then
        echo "  ✅ DMG 코드 사이닝됨"
        
        # DMG 공증 확인
        if spctl --assess --type install "$DIST_DIR/$DMG_NAME" 2>/dev/null; then
            echo "  ✅ DMG Apple 공증됨"
        else
            echo "  ⚠️  DMG 공증 상태 불명"
        fi
    else
        echo "  ⚠️  DMG 서명되지 않음"
    fi
    
    echo ""
    echo -e "${GREEN}✨ 권한 문제 없이 배포 가능!${NC}"
else
    echo ""
    echo -e "${YELLOW}⚠️  서명되지 않은 패키지:${NC}"
    echo "  사용자가 시스템 설정에서 허용 필요"
fi

echo ""
echo -e "${CYAN}사용 방법:${NC}"
echo "  1. DMG 파일을 마운트하여 PKG 설치"
echo "  2. 또는 PKG 파일을 직접 실행"
echo ""
echo -e "${CYAN}테스트 방법:${NC}"
echo "  hdiutil attach \"$DIST_DIR/$DMG_NAME\""
echo ""

# 9. 선택적: DMG 마운트 테스트
read -p "생성된 DMG 파일을 테스트로 마운트하시겠습니까? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "DMG 마운트 테스트 중..."
    hdiutil attach "$DIST_DIR/$DMG_NAME"
    log_success "DMG가 성공적으로 마운트되었습니다. Finder를 확인하세요."
fi

log_success "🎉 모든 작업이 완료되었습니다!"
