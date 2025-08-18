#!/usr/bin/env bash
set -euo pipefail

# 간단한 빌드 래퍼 스크립트
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"

echo "🚀 RPLS MCP Setup 빌드를 시작합니다..."
echo ""

# 버전 설정 옵션
if [ $# -eq 1 ]; then
    export VERSION="$1"
    echo "📌 버전이 $VERSION로 설정되었습니다."
else
    echo "💡 사용법: $0 [버전]"
    echo "   예시: $0 1.2.0"
    echo ""
    echo "   버전을 지정하지 않으면 Git 태그나 기본값을 사용합니다."
fi

echo ""

# 메인 빌드 스크립트 실행
"$SCRIPT_DIR/create-dmg.sh"
