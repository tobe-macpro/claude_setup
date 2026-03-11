# Claude Agent Setup

새 Mac에서 Claude Code CLI + 텔레그램 연동 환경을 원클릭으로 구성합니다.

## 설치

```bash
bash <(curl -fsSL http://tbe.kr/myclaude_setup.sh)
```

## 구성 요소

| 항목 | 설명 |
|------|------|
| Claude Code CLI | Anthropic의 공식 CLI 에이전트 |
| CLAUDE.md | 업무 매뉴얼 (Claude가 자동으로 읽음) |
| 텔레그램 봇 | 실시간 양방향 소통 (선택) |
| 자동시작 | 맥 부팅 시 자동 실행 (선택) |

## 파일 구조

```
~/claude-agent/           # 기본 프로젝트 디렉토리
├── CLAUDE.md             # 업무 매뉴얼
├── autostart.sh          # 자동시작 스크립트
├── .env                  # 환경변수 (텔레그램 토큰 등)
├── .gitignore            # .env 제외
└── .claude/
    └── settings.local.json  # 권한 설정
```

## 업무 매뉴얼 (CLAUDE.md)

CLAUDE.md에 업무 지시를 작성하면 Claude가 시작할 때 자동으로 읽습니다.

```markdown
# My Agent

## 역할
- 서버 모니터링
- 텔레그램으로 알림 발송

## 할 일
- 5분마다 서버 상태 체크
- 에러 발생 시 텔레그램 알림
```

## 텔레그램 봇 만들기

1. [@BotFather](https://t.me/BotFather)에게 `/newbot` 전송
2. 봇 이름, username 입력
3. Bot Token 받기
4. 봇에게 아무 메시지 보낸 후 Chat ID 확인:
   ```
   curl https://api.telegram.org/bot{TOKEN}/getUpdates
   ```
