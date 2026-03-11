#!/bin/bash
# =============================================================
# Claude Agent Setup - 원클릭 설치 스크립트
#
# 사용법:
#   bash <(curl -fsSL http://tbe.kr/myclaude_setup.sh)
#
# 새 Mac에서 Claude Code CLI + 텔레그램 연동 환경을
# 자동으로 구성합니다.
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
echo -e "${BLUE}║   Claude Agent Setup Wizard           ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
echo ""

# ── 1. 기본 도구 설치 ──
echo -e "${YELLOW}[1/6]${NC} 기본 도구 확인 및 설치..."

if ! command -v brew &>/dev/null; then
    echo "  Homebrew 설치 중..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Apple Silicon path
    if [ -f /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi
echo -e "  ${GREEN}✓${NC} Homebrew: $(brew --version | head -1)"

if ! command -v node &>/dev/null; then
    echo "  Node.js 설치 중..."
    brew install node
fi
echo -e "  ${GREEN}✓${NC} Node.js: $(node --version)"

# ── 2. Claude Code CLI 설치 ──
echo -e "${YELLOW}[2/6]${NC} Claude Code CLI 설치..."
if ! command -v claude &>/dev/null; then
    npm install -g @anthropic-ai/claude-code
fi
echo -e "  ${GREEN}✓${NC} Claude Code: $(claude --version 2>/dev/null || echo 'installed')"

# ── 3. 프로젝트 디렉토리 설정 ──
echo -e "${YELLOW}[3/6]${NC} 프로젝트 설정..."
echo ""

DEFAULT_DIR="$HOME/claude-agent"
read -p "  프로젝트 디렉토리 [$DEFAULT_DIR]: " PROJECT_DIR
PROJECT_DIR="${PROJECT_DIR:-$DEFAULT_DIR}"

mkdir -p "$PROJECT_DIR"
echo -e "  ${GREEN}✓${NC} 디렉토리: $PROJECT_DIR"

# ── 4. 업무 매뉴얼 (CLAUDE.md) 설정 ──
echo -e "${YELLOW}[4/6]${NC} 업무 매뉴얼 설정..."
echo ""
echo "  CLAUDE.md는 Claude가 시작할 때 자동으로 읽는 업무 지시서입니다."
echo "  1) URL에서 다운로드 (GitHub raw URL 등)"
echo "  2) 노션(Notion) 페이지에서 가져오기"
echo "  3) 로컬 파일 경로 지정"
echo "  4) 나중에 직접 작성"
echo ""
read -p "  선택 [1/2/3/4]: " CLAUDE_MD_CHOICE

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
        echo "  노션 페이지를 CLAUDE.md로 사용합니다."
        echo "  노션 페이지 URL 또는 페이지 ID를 입력하세요."
        echo "  (예: https://www.notion.so/My-Page-abc123...)"
        echo ""
        read -p "  노션 페이지 URL/ID: " NOTION_PAGE

        # URL에서 페이지 ID 추출
        NOTION_PAGE_ID=$(echo "$NOTION_PAGE" | grep -oE '[a-f0-9]{32}' | tail -1)
        if [ -z "$NOTION_PAGE_ID" ]; then
            # 하이픈 포함 UUID 형태
            NOTION_PAGE_ID=$(echo "$NOTION_PAGE" | grep -oE '[a-f0-9-]{36}' | tail -1)
        fi
        if [ -z "$NOTION_PAGE_ID" ]; then
            NOTION_PAGE_ID="$NOTION_PAGE"
        fi

        # CLAUDE.md에 노션 연동 지시 작성
        cat > "$PROJECT_DIR/CLAUDE.md" << NOTIONMD
# 업무 매뉴얼

## 노션 연동
이 에이전트의 업무 매뉴얼은 노션에서 관리됩니다.
시작할 때 아래 노션 페이지를 읽고 지시사항을 따르세요.

- 노션 페이지 ID: $NOTION_PAGE_ID
- 원본 URL: $NOTION_PAGE

## 사용법
Claude 시작 시 Notion MCP를 사용하여 위 페이지를 fetch하고,
그 내용을 업무 지시서로 삼아 작업을 수행합니다.

\`\`\`
# Claude가 시작 시 실행할 명령 (자동)
# mcp__claude_ai_Notion__notion-fetch 로 페이지 내용을 읽습니다
\`\`\`
NOTIONMD

        # .env에 노션 페이지 ID 저장
        echo "NOTION_PAGE_ID=$NOTION_PAGE_ID" >> "$PROJECT_DIR/.env" 2>/dev/null || \
        echo "NOTION_PAGE_ID=$NOTION_PAGE_ID" > "$PROJECT_DIR/.env"

        echo -e "  ${GREEN}✓${NC} 노션 연동 CLAUDE.md 생성 완료"
        echo -e "  ${YELLOW}→${NC} Claude가 시작할 때 노션 페이지를 자동으로 읽습니다."
        ;;
    3)
        read -p "  CLAUDE.md 파일 경로: " CLAUDE_MD_PATH
        if [ -f "$CLAUDE_MD_PATH" ]; then
            cp "$CLAUDE_MD_PATH" "$PROJECT_DIR/CLAUDE.md"
            echo -e "  ${GREEN}✓${NC} CLAUDE.md 복사 완료"
        else
            echo -e "  ${RED}✗${NC} 파일을 찾을 수 없습니다: $CLAUDE_MD_PATH"
        fi
        ;;
    4)
        echo -e "  ${YELLOW}→${NC} 나중에 $PROJECT_DIR/CLAUDE.md 를 직접 작성하세요."
        ;;
esac

# ── 5. 텔레그램 봇 설정 (선택) ──
echo -e "${YELLOW}[5/6]${NC} 텔레그램 봇 설정..."
echo ""
read -p "  텔레그램 봇을 연동하시겠습니까? [y/N]: " USE_TELEGRAM

if [[ "$USE_TELEGRAM" =~ ^[Yy]$ ]]; then
    read -p "  Bot Token (@BotFather에서 발급): " BOT_TOKEN
    read -p "  Chat ID (본인 ID): " CHAT_ID
    read -p "  봇 이름 (표시용): " BOT_NAME
    BOT_NAME="${BOT_NAME:-my-claude-bot}"

    # .env 파일 생성
    cat > "$PROJECT_DIR/.env" << EOF
# Claude Agent 환경 설정
TELEGRAM_BOT_TOKEN=$BOT_TOKEN
TELEGRAM_CHAT_ID=$CHAT_ID
TELEGRAM_BOT_NAME=$BOT_NAME
PROJECT_DIR=$PROJECT_DIR
EOF

    # .gitignore에 .env 추가
    echo ".env" >> "$PROJECT_DIR/.gitignore" 2>/dev/null

    # 자동시작 스크립트 생성
    cat > "$PROJECT_DIR/autostart.sh" << 'AUTOSTART'
#!/bin/bash
# Claude Agent 자동 시작 스크립트

# 프로젝트 디렉토리로 이동
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# NVM 로드 (있는 경우)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# .env 로드
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

echo "🤖 Claude Agent 시작..."
echo "📂 경로: $(pwd)"

# 텔레그램 연동 시작
if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
    PROMPT="시작하면서 텔레그램(BOT_TOKEN: $TELEGRAM_BOT_TOKEN, CHAT_ID: $TELEGRAM_CHAT_ID)에 '$(hostname) 부팅 완료. Claude 준비됨. 텔레그램 폴링 시작합니다.' 메시지를 보내고, 텔레그램 메시지를 계속 폴링하면서 반응해."
else
    PROMPT="준비 완료. 지시를 기다립니다."
fi

claude --dangerously-skip-permissions -p "$PROMPT"
AUTOSTART
    chmod +x "$PROJECT_DIR/autostart.sh"

    echo -e "  ${GREEN}✓${NC} 텔레그램 봇 설정 완료"
    echo -e "  ${GREEN}✓${NC} autostart.sh 생성 완료"
else
    # 텔레그램 없이 기본 autostart
    cat > "$PROJECT_DIR/autostart.sh" << 'AUTOSTART'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
echo "🤖 Claude Agent 시작..."
claude --dangerously-skip-permissions
AUTOSTART
    chmod +x "$PROJECT_DIR/autostart.sh"
    echo -e "  ${YELLOW}→${NC} 텔레그램 없이 진행"
fi

# ── 6. 맥 로그인 자동시작 설정 ──
echo -e "${YELLOW}[6/6]${NC} 맥 로그인 시 자동시작 설정..."
echo ""
read -p "  맥 부팅 시 Claude를 자동 시작하시겠습니까? [y/N]: " AUTO_START

if [[ "$AUTO_START" =~ ^[Yy]$ ]]; then
    mkdir -p ~/Applications

    # AppleScript 앱 생성
    cat > /tmp/claude-autostart.scpt << SCPT
tell application "Terminal"
    activate
    do script "source $PROJECT_DIR/autostart.sh"
end tell
SCPT
    osacompile -o ~/Applications/ClaudeAgentAutoStart.app /tmp/claude-autostart.scpt 2>/dev/null
    rm -f /tmp/claude-autostart.scpt

    # 로그인 항목에 추가
    osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$HOME/Applications/ClaudeAgentAutoStart.app\", hidden:false}" 2>/dev/null

    echo -e "  ${GREEN}✓${NC} 자동시작 설정 완료"
    echo -e "  ${GREEN}✓${NC} ~/Applications/ClaudeAgentAutoStart.app 생성"
else
    echo -e "  ${YELLOW}→${NC} 수동 시작: source $PROJECT_DIR/autostart.sh"
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

# ── 완료 ──
echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}  설치 완료!${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo ""
echo -e "  📂 프로젝트: $PROJECT_DIR"
echo -e "  📋 매뉴얼:   $PROJECT_DIR/CLAUDE.md"
echo -e "  🚀 시작:     cd $PROJECT_DIR && claude"
echo -e "  🔄 자동시작: source $PROJECT_DIR/autostart.sh"
echo ""
echo -e "  ${YELLOW}다음 단계:${NC}"
echo -e "  1. CLAUDE.md에 업무 지시 작성"
echo -e "  2. cd $PROJECT_DIR && claude 로 시작"
echo -e "  3. Claude에게 할 일을 지시하세요!"
echo ""
