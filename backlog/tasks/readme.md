# tasks

**무엇인가**: 실제로 진행 중이거나 완료된 작업 단위를 담는다(현재 242개, TASK-1부터
TASK-166까지 — 중간 번호 다수가 `task-N.M` 형태의 서브태스크). 각 파일은 제목, 설명,
수용 기준(AC), 상태(To Do/In Progress/Done), 소속 마일스톤 등을 가진 하나의 태스크다.

**언제 쓰나**: 계획이 필요한 작업은 plan mode → `backlog draft create` → 재승인 →
`backlog draft promote` 순서를 거쳐 여기 생긴다. 이 저장소는 사실상 모든 작업을
이 경로로 만들어왔다 — `backlog task create`로 직접 만드는 경우는 드물다.

**시작 전 필수 확인**: 이 저장소의 `require_active_task.py` 훅이 `backlog task view
<ID> --plain`으로 태스크를 먼저 읽지 않으면 Edit/Write 자체를 차단한다(대상 파일이
이 저장소 밖에 있어도 cwd가 이 저장소면 걸린다). 또한 태스크를 `In Progress`로 바꾸고
`task/<ID>`(예: `task/TASK-158`) 브랜치로 전환해야 실제 코드/문서 수정이 가능하다.

**완료 시**: 테스트 통과 등 객관적 증거 확인 후 `--check-ac`/`--check-dod`를 체크하고
`--final-summary`를 남긴 다음 `-s Done`으로 옮긴다. Done 상태 + final summary가 없으면
push를 막는 훅이 따로 있다.

**관련 명령**:

- `backlog task create "title" --ac "..."` — 새 태스크 생성(드묾, 보통은 draft 경유)
- `backlog task edit TASK-N -s "In Progress"` — 상태/마일스톤 등 메타데이터 수정
- `backlog task view TASK-N --plain` — 작업 시작 전 반드시 읽어야 하는 상세 내용
- `backlog task list --status "<status>" --plain` — 상태별 목록 조회
- `backlog task archive TASK-N` — 더 이상 유효하지 않은 태스크를 `archive/`로 이동
