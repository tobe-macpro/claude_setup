#!/bin/bash
# =============================================================
# 2nd Claude Agent Setup - 추가 에이전트 배포 스크립트
#
# 이미 Claude Code가 설치된 환경에서 새 에이전트 세션을 추가합니다.
#
# 사용법 (모두 동작):
#   curl -fsSL https://tbe.kr/2ndclaude_setup.sh | bash
#   bash <(curl -fsSL https://tbe.kr/2ndclaude_setup.sh)
#   curl -o setup.sh https://tbe.kr/2ndclaude_setup.sh && bash setup.sh
# =============================================================

# ── 파이프 실행 처리 ──
# curl | bash 시 stdin이 파이프라서 read가 작동 안 함
# 파일을 /tmp에 저장하고 /dev/tty를 stdin으로 연결하여 재실행
if [ ! -t 0 ]; then
    _SCRIPT="/tmp/_claude_2nd_setup.sh"
    # 이미 파이프에서 전체 스크립트를 읽었으므로 stdin(cat)으로 저장
    cat > "$_SCRIPT"
    chmod +x "$_SCRIPT"
    bash "$_SCRIPT" < /dev/tty
    _EXIT=$?
    rm -f "$_SCRIPT"
    exit $_EXIT
fi

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
    echo "  curl -fsSL https://tbe.kr/myclaude_setup.sh | bash"
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
    read -p "  덮어쓰시겠습니까? [y/N]: " OVERWRITE
    if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
        echo "  기존 설정을 유지합니다."
        echo -e "  시작하려면: cd $PROJECT_DIR && source autostart.sh"
        exit 0
    fi
fi

mkdir -p "$PROJECT_DIR"
echo -e "  ${GREEN}✓${NC} 디렉토리: $PROJECT_DIR"

# ── 2. 업무 매뉴얼 (CLAUDE.md) ──
echo -e "${YELLOW}[2/4]${NC} 업무 매뉴얼 설정..."
echo ""
echo "  CLAUDE.md는 이 에이전트의 업무 지시서입니다."
echo "  1) URL에서 다운로드"
echo "  2) 노션(Notion) 페이지"
echo "  3) 로컬 파일 복사"
echo "  4) 기존 에이전트에서 복사"
echo "  5) 건너뛰기"
echo ""
read -p "  선택 [1-5]: " CLAUDE_MD_CHOICE

case "$CLAUDE_MD_CHOICE" in
    1)
        read -p "  URL: " CLAUDE_MD_URL
        if [ -n "$CLAUDE_MD_URL" ]; then
            curl -fsSL "$CLAUDE_MD_URL" -o "$PROJECT_DIR/CLAUDE.md" && \
            echo -e "  ${GREEN}✓${NC} 다운로드 완료" || \
            echo -e "  ${RED}✗${NC} 다운로드 실패"
        fi
        ;;
    2)
        read -p "  노션 페이지 URL/ID: " NOTION_PAGE
        NOTION_PAGE_ID=$(echo "$NOTION_PAGE" | grep -oE '[a-f0-9]{32}' | tail -1 || true)
        [ -z "$NOTION_PAGE_ID" ] && NOTION_PAGE_ID="$NOTION_PAGE"
        cat > "$PROJECT_DIR/CLAUDE.md" << NOTIONMD
# 업무 매뉴얼 (노션 연동)
시작 시 아래 노션 페이지를 읽고 지시사항을 따르세요.
- 노션 페이지 ID: $NOTION_PAGE_ID
- URL: $NOTION_PAGE
NOTIONMD
        echo -e "  ${GREEN}✓${NC} 노션 연동 설정 완료"
        ;;
    3)
        read -p "  파일 경로: " CLAUDE_MD_PATH
        [ -f "$CLAUDE_MD_PATH" ] && cp "$CLAUDE_MD_PATH" "$PROJECT_DIR/CLAUDE.md" && \
        echo -e "  ${GREEN}✓${NC} 복사 완료" || \
        echo -e "  ${RED}✗${NC} 파일 없음"
        ;;
    4)
        read -p "  경로 (예: ~/claude-agent/CLAUDE.md): " SRC_PATH
        [ -f "$SRC_PATH" ] && cp "$SRC_PATH" "$PROJECT_DIR/CLAUDE.md" && \
        echo -e "  ${GREEN}✓${NC} 복사 완료" || \
        echo -e "  ${RED}✗${NC} 파일 없음"
        ;;
    *)
        echo -e "  ${YELLOW}→${NC} 나중에 $PROJECT_DIR/CLAUDE.md 작성하세요."
        ;;
esac

# ── 3. 텔레그램 봇 설정 ──
echo ""
echo -e "${YELLOW}[3/4]${NC} 텔레그램 봇 설정..."
echo -e "  ${YELLOW}⚠ 기존 에이전트와 다른 봇을 사용해야 합니다${NC}"
echo ""
read -p "  텔레그램 연동? [y/N]: " USE_TELEGRAM

if [[ "$USE_TELEGRAM" =~ ^[Yy]$ ]]; then
    read -p "  Bot Token: " TG_TOKEN

    # Chat ID 자동 감지
    echo "  Chat ID 감지 중..."
    TG_CHAT_ID=""
    TG_UPDATES=$(curl -s "https://api.telegram.org/bot${TG_TOKEN}/getUpdates?limit=5" 2>/dev/null)
    TG_CHAT_ID=$(echo "$TG_UPDATES" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if data.get('result'):
        print(data['result'][-1]['message']['chat']['id'])
except: pass
" 2>/dev/null)

    if [ -n "$TG_CHAT_ID" ]; then
        echo -e "  ${GREEN}✓${NC} Chat ID: $TG_CHAT_ID"
        read -p "  맞습니까? [Y/n]: " CONFIRM
        [[ "$CONFIRM" =~ ^[Nn]$ ]] && read -p "  Chat ID 입력: " TG_CHAT_ID
    else
        echo -e "  ${YELLOW}→${NC} 봇에게 아무 메시지를 보내세요."
        read -p "  보냈으면 Enter: "
        TG_UPDATES=$(curl -s "https://api.telegram.org/bot${TG_TOKEN}/getUpdates?limit=5" 2>/dev/null)
        TG_CHAT_ID=$(echo "$TG_UPDATES" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if data.get('result'):
        print(data['result'][-1]['message']['chat']['id'])
except: pass
" 2>/dev/null)
        if [ -z "$TG_CHAT_ID" ]; then
            read -p "  Chat ID 직접 입력: " TG_CHAT_ID
        else
            echo -e "  ${GREEN}✓${NC} Chat ID: $TG_CHAT_ID"
        fi
    fi

    # .env 생성
    cat > "$PROJECT_DIR/.env" << EOF
AGENT_NAME=$AGENT_NAME
TELEGRAM_BOT_TOKEN=$TG_TOKEN
TELEGRAM_CHAT_ID=$TG_CHAT_ID
PROJECT_DIR=$PROJECT_DIR
EOF

    # autostart.sh
    cat > "$PROJECT_DIR/autostart.sh" << 'AUTOSTART'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -f .env ] && export $(grep -v '^#' .env | xargs)
AGENT_NAME="${AGENT_NAME:-agent}"
echo "🤖 Claude Agent ($AGENT_NAME) 시작..."
if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
    PROMPT="시작하면서 텔레그램(BOT_TOKEN: $TELEGRAM_BOT_TOKEN, CHAT_ID: $TELEGRAM_CHAT_ID)에 '$AGENT_NAME 시작됨. 폴링 시작.' 메시지를 보내고, 텔레그램 메시지를 계속 폴링하면서 반응해."
else
    PROMPT="준비 완료."
fi
claude --dangerously-skip-permissions -p "$PROMPT"
AUTOSTART
    chmod +x "$PROJECT_DIR/autostart.sh"
    echo -e "  ${GREEN}✓${NC} 텔레그램 설정 완료"
else
    cat > "$PROJECT_DIR/autostart.sh" << 'AUTOSTART'
#!/bin/bash
cd "$(cd "$(dirname "$0")" && pwd)"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
claude --dangerously-skip-permissions
AUTOSTART
    chmod +x "$PROJECT_DIR/autostart.sh"
fi

# ── 4. 자동시작 ──
echo ""
echo -e "${YELLOW}[4/4]${NC} 맥 로그인 시 자동시작..."
read -p "  자동시작 설정? [y/N]: " AUTO_START

if [[ "$AUTO_START" =~ ^[Yy]$ ]]; then
    mkdir -p ~/Applications
    APP_NAME="ClaudeAgent_${AGENT_NAME}.app"
    cat > /tmp/_claude_autostart.scpt << SCPT
tell application "Terminal"
    activate
    do script "source $PROJECT_DIR/autostart.sh"
end tell
SCPT
    osacompile -o ~/Applications/"$APP_NAME" /tmp/_claude_autostart.scpt 2>/dev/null
    rm -f /tmp/_claude_autostart.scpt
    osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$HOME/Applications/$APP_NAME\", hidden:false}" 2>/dev/null
    echo -e "  ${GREEN}✓${NC} 자동시작: ~/Applications/$APP_NAME"
fi

# ── 권한 + .gitignore ──
mkdir -p "$PROJECT_DIR/.claude"
cat > "$PROJECT_DIR/.claude/settings.local.json" << 'JSON'
{"permissions":{"allow":["Bash(*)","Read(*)","Write(*)","Edit(*)"]}}
JSON
echo ".env" > "$PROJECT_DIR/.gitignore"

# ── 완료 ──
echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}  에이전트 '${AGENT_NAME}' 준비 완료!${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo ""
echo "  📂 $PROJECT_DIR"
echo "  🚀 cd $PROJECT_DIR && source autostart.sh"
echo ""

read -p "  지금 바로 시작? [y/N]: " START_NOW
if [[ "$START_NOW" =~ ^[Yy]$ ]]; then
    cd "$PROJECT_DIR"
    source autostart.sh
fi
