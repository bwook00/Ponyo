# Ponyo - macOS Agent Orchestrator Design

## Problem

여러 GitHub 레포의 이슈를 동시에 처리할 때 tmux 환경에서 4-6개의 AI Agent(Claude Code, Codex)를 병렬로 돌리면 어떤 터미널에서 어떤 작업 중인지 파악이 어렵고, 할 일 관리와 Agent 배치에 인지적 부담이 큼.

## Solution

tmux 페인을 시각적으로 관리하고, GitHub Issues를 드래그 앤 드롭으로 페인에 배치하면 자동으로 git worktree 생성 + Agent 실행까지 수행하는 네이티브 macOS 앱.

## Tech Stack

- Language: Swift
- UI: SwiftUI
- External dependencies: 0 (Foundation Process, URLSession으로 충분)
- System requirements: tmux, claude CLI, codex CLI

## Data Model

```
AppState
├── githubToken: String (Keychain 저장)
├── repos: [RepoConfig]
│   ├── owner: String (e.g. "user")
│   ├── name: String (e.g. "repo-A")
│   └── localPath: String (e.g. "/Users/.../repo-A")
├── tmuxSession: String = "ponyo"
├── taskPool: [Issue]           ← 오늘 할 일 (GitHub Issues)
└── paneSlots: [PaneSlot]       ← 작업 공간 (tmux 페인)

Issue (from GitHub)
├── number: Int
├── title: String
├── body: String
├── labels: [String]
└── repo: RepoConfig

PaneSlot
├── paneId: String (tmux pane identifier)
├── agent: Agent (.claudeCode | .codex)
├── issue: Issue?
├── status: PaneStatus (.idle | .running | .crashed)
└── worktreePath: String?
```

## Architecture (MVVM + Services)

```
Views              ViewModels         Services
─────              ──────────         ────────
MenuBarView        DashboardVM        TmuxService
DashboardView      TaskPoolVM         GitService
  TaskPoolView     PaneSlotVM         GitHubService
  PaneGridView                        AgentLauncher
  PaneCardView                        StateStore
SettingsView
OnboardView                           PaneMonitor (Timer, 2초)
```

### Services

**TmuxService** - Process 기반 tmux CLI 제어
- listPanes(): 페인 목록 + 상태 조회
- createPane(): 새 페인 생성 (split-window)
- killPane(id): 페인 삭제
- sendKeys(paneId, command): 명령 전송
- setPaneTitle(paneId, title): 페인 타이틀 설정

**GitService** - Process 기반 git CLI 제어
- addWorktree(repoPath, branchName, targetPath): worktree 생성
- removeWorktree(repoPath, worktreePath): worktree 삭제
- listWorktrees(repoPath): worktree 목록

**GitHubService** - URLSession 기반 REST API
- fetchIssues(repo): 이슈 목록 조회
- addLabel(repo, issueNumber, label): 라벨 추가
- removeLabel(repo, issueNumber, label): 라벨 제거

**AgentLauncher** - tmux send-keys로 Agent 실행
- launchCC(paneId, worktreePath, issueContext): Claude Code 실행
- launchCodex(paneId, worktreePath, issueContext): Codex 실행
- stopAgent(paneId): Ctrl+C 전송

**StateStore** - JSON 파일 기반 상태 저장
- save(state): ~/.ponyo/state.json에 저장
- load(): 상태 복원

**PaneMonitor** - 2초 간격 Timer
- tmux list-panes -F "#{pane_index} #{pane_pid} #{pane_current_command}"
- Agent 프로세스 이름(claude/codex) 확인으로 running/idle 판별

## UI Structure

### Menu Bar (기본 모드)

메뉴바 아이콘 클릭 시 드롭다운:
- Tasks: N remaining
- Panes: N running, N idle
- 각 페인 요약 (Agent 종류, 레포, 이슈 번호, 상태)
- [Open Dashboard] [Settings] 버튼

### Dashboard (독립 창 모드)

좌측: TaskPool (오늘 할 일 목록)
- GitHub Issues 카드 리스트 (레포명, 이슈 번호, 제목, 라벨)
- 하단에 레포 관리 (추가/제거)

우측: PaneGrid (페인 그리드)
- 각 PaneCard에 Agent 종류, 레포, 이슈, 브랜치, 상태 표시
- 상태 인디케이터: 🟢 Running / 🟡 Idle / 🔴 Crashed
- [↩] 되돌리기 버튼, [✕] 완료 버튼
- [+ Add Pane] 카드
- 빈 페인에 "Drop task here" 안내

## User Flows

### Flow 1: 이슈를 Pane에 드롭 (핵심 플로우)

1. TaskPool에서 이슈 카드를 PaneSlot으로 드래그 앤 드롭
2. Agent 선택 팝오버 표시 (Claude Code / Codex)
3. [Launch] 클릭 시 자동 실행:
   - `git worktree add ~/.ponyo/worktrees/{repo}--issue-{N} -b feat/issue-{N}`
   - `tmux split-window -t ponyo` (새 페인) 또는 기존 빈 페인 사용
   - `cd ~/.ponyo/worktrees/{repo}--issue-{N}`
   - `claude "Fix #{N}: {title}\n\n{body}"` 또는 `codex "..."`
   - `tmux select-pane -T "CC | {repo} | feat/issue-{N} | #{N} {title}"`
   - GitHub API로 "in-progress" 라벨 추가

### Flow 2: 되돌리기 (↩)

1. Agent에 Ctrl+C 전송 (정상 종료)
2. 이슈를 TaskPool로 이동
3. Worktree 유지 (나중에 재개 가능)
4. 페인은 idle 상태로 유지
5. "in-progress" 라벨 제거

### Flow 3: 완료 (✕)

1. Agent에 Ctrl+C 전송 (정상 종료)
2. Worktree 삭제 (브랜치는 유지 - PR용)
3. 페인 삭제 (tmux kill-pane)
4. "in-progress" 라벨 제거
5. Issue close는 하지 않음 (PR merge 시 자동 처리)

### Flow 4: 앱 시작 / 세션 복구

1. tmux has-session -t ponyo 확인
2. 있으면: 기존 세션에 연결, ~/.ponyo/state.json에서 상태 복구
3. 없으면: tmux new-session -d -s ponyo 생성
4. PaneMonitor 시작 (2초 간격 상태 폴링)

### Flow 5: 초기 설정 (Onboarding)

1. GitHub Personal Access Token 입력 → macOS Keychain 저장
2. 관리할 레포 추가 (owner/repo + local clone 경로)
3. tmux 경로 확인
4. Agent CLI 경로 확인 (claude, codex)

## Git Worktree Strategy

```
디스크 구조:
~/repos/repo-A/                        ← 원본 (main branch, .git 공유)
~/.ponyo/worktrees/repo-A--issue-42/   ← worktree (feat/issue-42)
~/.ponyo/worktrees/repo-A--issue-15/   ← worktree (feat/issue-15)
~/.ponyo/worktrees/repo-B--issue-7/    ← worktree (feat/issue-7)
```

- 한 레포의 복수 이슈 = 복수 worktree (정상 패턴)
- .git 디렉토리 공유로 디스크 오버헤드 최소
- 완료(✕) 시 worktree 삭제, 브랜치 유지
- 되돌리기(↩) 시 worktree 유지, 재개 시 재사용

## tmux Integration

세션: "ponyo" (고정)
페인 타이틀 형식: "{Agent} | {repo} | {branch} | #{N} {title}"

tmux status-bar에 페인 타이틀이 자동 표시되어 터미널에서도 맥락 파악 가능.

## Agent Configuration

- Claude Code: 각 레포의 CLAUDE.md를 자동으로 읽음 (worktree에 포함)
- Codex: 각 레포의 AGENTS.md를 자동으로 읽음 (worktree에 포함)
- 이슈 내용(title + body)을 Agent 실행 시 프롬프트로 전달

## Decisions

- Issue close는 앱에서 하지 않음 → PR merge 시 "Closes #N"으로 자동 처리
- 알림 시스템 불필요 → Dashboard를 항상 띄워놓는 사용 패턴
- 히스토리/로깅 불필요 → v1 스코프 외
- Agent 역할 분담(CC vs Codex) → v2에서 고려
- Agent 협업 시각화 → v2에서 고려
