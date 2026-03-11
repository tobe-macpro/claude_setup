#!/bin/bash
# =============================================================
# 2nd Claude Agent Setup - 추가 에이전트 배포 스크립트
#
# 이미 Claude Code가 설치된 환경에서 새 에이전트 세션을 추가합니다.
#
# 사용법:
#   bash <(curl -fsSL https://tbe.kr/2ndclaude_setup.sh)
# =============================================================

set -e

# ── 색상 ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   2nd Claude Agent Setup              ║${NC}"
echo -e "${BLUE}║   추가 에이전트 배포                    ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
echo ""

# ── 0. Claude Code 확인 ──
if ! command -v claude &>/dev/null; then
    echo -e "${RED}✗ Claude Code CLI가 설치되어 있지 않습니다.${NC}"
    echo "  먼저 기본 셋업을 실행하세요:"
    echo "  bash <(curl -fsSL https://tbe.kr/myclaude_setup.sh)"
    exit 1
fi
echo -e "${GREEN}✓${NC} Claude Code: $(claude --version 2>/dev/null || echo 'installed')"

# ── 1. 에이전트 이름/디렉토리 ──
echo -e "${YELLOW}[1/4]${NC} 에이전트 설정..."
echo ""
read -p "  에이전트 이름 (예: monitor, support, dev): " AGENT_NAME
AGENT_NAME="${AGENT_NAME:-agent2}"

DEFAULT_DIR="$HOME/claude-${AGENT_NAME}"
read -p "  프로젝트 디렉토리 [$DEFAULT_DIR]: " PROJECT_DIR
PROJECT_DIR="${PROJECT_DIR:-$DEFAULT_DIR}"

if [ -d "$PROJECT_DIR" ]; then
    echo -e "  ${YELLOW}⚠${NC} 디렉토리가 이미 존재합니다: $PROJECT_DIR"
    read -p "  계속하시겠습니까? [y/N]: " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        echo "중단합니다."
        exit 0
    fi
fi

mkdir -p "$PROJECT_DIR"
echo -e "  ${GREEN}✓${NC} 디렉토리: $PROJECT_DIR"

# ── 2. 업무 매뉴얼 (CLAUDE.md) ──
echo -e "${YELLOW}[2/4]${NC} 업무 매뉴얼 설정..."
echo ""
echo "  CLAUDE.md는 이 에이전트의 업무 지시서입니다."
echo "  1) URL에서 다운로드 (GitHub raw URL 등)"
echo "  2) 노션(Notion) 페이지에서 가져오기"
echo "  3) 로컬 파일 경로 지정"
echo "  4) 기존 CLAUDE.md 복사 (다른 에이전트에서)"
echo "  5) 나중에 직접 작성"
echo ""
read -p "  선택 [1/2/3/4/5]: " CLAUDE_MD_CHOICE

case "$CLAUDE_MD_CHOICE" in
    1)
        read -p "  CLAUDE.md URL: " CLAUDE_MD_URL
        if [ -n "$CLAUDE_MD_URL" ]; then
            curl -fsSL "$CLAUDE_MD_URL" -o "$PROJECT_DIR/CLAUDE.md"
            echo -e "  ${GREEN}✓${NC} CLAUDE.md 다운로드 완료"
        fi
        ;;
    2)
        echo ""
        echo "  노션 페이지를 업무 매뉴얼로 사용합니다."
        read -p "  노션 페이지 URL/ID: " NOTION_PAGE

        NOTION_PAGE_ID=$(echo "$NOTION_PAGE" | grep -oE '[a-f0-9]{32}' | tail -1)
        if [ -z "$NOTION_PAGE_ID" ]; then
            NOTION_PAGE_ID=$(echo "$NOTION_PAGE" | grep -oE '[a-f0-9-]{36}' | tail -1)
        fi
        if [ -z "$NOTION_PAGE_ID" ]; then
            NOTION_PAGE_ID="$NOTION_PAGE"
        fi

        cat > "$PROJECT_DIR/CLAUDE.md" << NOTIONMD
# 업무 매뉴얼

## 노션 연동
이 에이전트의 업무 매뉴얼은 노션에서 관리됩니다.
시작할 때 아래 노션 페이지를 읽고 지시사항을 따르세요.

- 노션 페이지 ID: $NOTION_PAGE_ID
- 원본 URL: $NOTION_PAGE

## 사용법
시작 시 Notion MCP를 사용하여 위 페이지를 fetch하고,
그 내용을 업무 지시서로 삼아 작업을 수행합니다.
NOTIONMD

        echo -e "  ${GREEN}✓${NC} 노션 연동 CLAUDE.md 생성 완료"
        ;;
    3)
        read -p "  CLAUDE.md 파일 경로: " CLAUDE_MD_PATH
        if [ -f "$CLAUDE_MD_PATH" ]; then
            cp "$CLAUDE_MD_PATH" "$PROJECT_DIR/CLAUDE.md"
            echo -e "  ${GREEN}✓${NC} CLAUDE.md 복사 완료"
        else
            echo -e "  ${RED}✗${NC} 파일을 찾을 수 없습니다"
        fi
        ;;
    4)
        read -p "  복사할 CLAUDE.md 경로 (예: ~/claude-agent/CLAUDE.md): " SRC_PATH
        if [ -f "$SRC_PATH" ]; then
            cp "$SRC_PATH" "$PROJECT_DIR/CLAUDE.md"
            echo -e "  ${GREEN}✓${NC} CLAUDE.md 복사 완료"
        else
            echo -e "  ${RED}✗${NC} 파일을 찾을 수 없습니다"
        fi
        ;;
    5)
        echo -e "  ${YELLOW}→${NC} 나중에 $PROJECT_DIR/CLAUDE.md 를 직접 작성하세요."
        ;;
esac

# ── 3. 텔레그램 봇 설정 ──
echo -e "${YELLOW}[3/4]${NC} 텔레그램 봇 설정..."
echo ""
echo -e "  ${YELLOW}⚠ 주의: 기존 에이전트와 다른 봇을 사용해야 합니다!${NC}"
echo "  같은 봇으로 2개 세션이 폴링하면 409 충돌 발생."
echo ""
read -p "  텔레그램 봇을 연동하시겠습니까? [y/N]: " USE_TELEGRAM

if [[ "$USE_TELEGRAM" =~ ^[Yy]$ ]]; then
    read -p "  Bot Token (@BotFather → /newbot으로 새로 생성): " BOT_TOKEN

    # Chat ID 자동 감지
    echo "  Chat ID 자동 감지 중..."
    CHAT_ID=""
    UPDATES=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?limit=5" 2>/dev/null)
    CHAT_ID=$(echo "$UPDATES" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if data.get('result'):
        print(data['result'][-1]['message']['chat']['id'])
except: pass
" 2>/dev/null)

    if [ -n "$CHAT_ID" ]; then
        echo -e "  ${GREEN}✓${NC} Chat ID 자동 감지: $CHAT_ID"
    else
        echo -e "  ${YELLOW}→${NC} 봇에게 아무 메시지를 보낸 후 Enter를 눌러주세요."
        read -p "  (메시지 보냈으면 Enter): "
        UPDATES=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?limit=5" 2>/dev/null)
        CHAT_ID=$(echo "$UPDATES" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if data.get('result'):
        print(data['result'][-1]['message']['chat']['id'])
except: pass
" 2>/dev/null)
        if [ -n "$CHAT_ID" ]; then
            echo -e "  ${GREEN}✓${NC} Chat ID 감지: $CHAT_ID"
        else
            read -p "  Chat ID를 직접 입력하세요: " CHAT_ID
        fi
    fi

    cat > "$PROJECT_DIR/.env" << EOF
# Claude Agent ($AGENT_NAME) 환경 설정
AGENT_NAME=$AGENT_NAME
TELEGRAM_BOT_TOKEN=$BOT_TOKEN
TELEGRAM_CHAT_ID=$CHAT_ID
PROJECT_DIR=$PROJECT_DIR
EOF

    # autostart 스크립트
    cat > "$PROJECT_DIR/autostart.sh" << 'AUTOSTART'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

AGENT_NAME="${AGENT_NAME:-agent}"
echo "🤖 Claude Agent ($AGENT_NAME) 시작..."

if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
    PROMPT="시작하면서 텔레그램(BOT_TOKEN: $TELEGRAM_BOT_TOKEN, CHAT_ID: $TELEGRAM_CHAT_ID)에 '$AGENT_NAME 에이전트 시작됨. 텔레그램 폴링 시작합니다.' 메시지를 보내고, 텔레그램 메시지를 계속 폴링하면서 반응해."
else
    PROMPT="준비 완료. 지시를 기다립니다."
fi

claude --dangerously-skip-permissions -p "$PROMPT"
AUTOSTART
    chmod +x "$PROJECT_DIR/autostart.sh"
    echo -e "  ${GREEN}✓${NC} 텔레그램 봇 + autostart 설정 완료"
else
    cat > "$PROJECT_DIR/autostart.sh" << 'AUTOSTART'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
claude --dangerously-skip-permissions
AUTOSTART
    chmod +x "$PROJECT_DIR/autostart.sh"
fi

# ── 4. 자동시작 (선택) ──
echo -e "${YELLOW}[4/4]${NC} 맥 로그인 시 자동시작..."
echo ""
read -p "  맥 부팅 시 자동 시작하시겠습니까? [y/N]: " AUTO_START

if [[ "$AUTO_START" =~ ^[Yy]$ ]]; then
    mkdir -p ~/Applications
    APP_NAME="ClaudeAgent_${AGENT_NAME}.app"

    cat > /tmp/claude-agent-autostart.scpt << SCPT
tell application "Terminal"
    activate
    do script "source $PROJECT_DIR/autostart.sh"
end tell
SCPT
    osacompile -o ~/Applications/"$APP_NAME" /tmp/claude-agent-autostart.scpt 2>/dev/null
    rm -f /tmp/claude-agent-autostart.scpt

    osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$HOME/Applications/$APP_NAME\", hidden:false}" 2>/dev/null

    echo -e "  ${GREEN}✓${NC} 자동시작: ~/Applications/$APP_NAME"
fi

# ── 권한 설정 ──
mkdir -p "$PROJECT_DIR/.claude"
cat > "$PROJECT_DIR/.claude/settings.local.json" << 'PERMS'
{
  "permissions": {
    "allow": [
      "Bash(*)",
      "Read(*)",
      "Write(*)",
      "Edit(*)"
    ]
  }
}
PERMS

# ── .gitignore ──
echo ".env" > "$PROJECT_DIR/.gitignore"

# ── 완료 ──
echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}  에이전트 '${AGENT_NAME}' 배포 완료!${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo ""
echo -e "  📂 디렉토리: $PROJECT_DIR"
echo -e "  📋 매뉴얼:   $PROJECT_DIR/CLAUDE.md"
echo -e "  🚀 시작:     cd $PROJECT_DIR && claude"
echo -e "  🔄 자동시작: source $PROJECT_DIR/autostart.sh"
echo ""

# ── 바로 시작? ──
read -p "  지금 바로 에이전트를 시작하시겠습니까? [y/N]: " START_NOW
if [[ "$START_NOW" =~ ^[Yy]$ ]]; then
    echo ""
    source "$PROJECT_DIR/autostart.sh"
fi
