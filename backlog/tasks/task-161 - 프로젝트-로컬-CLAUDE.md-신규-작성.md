---
id: TASK-161
title: 프로젝트 로컬 CLAUDE.md 신규 작성
status: To Do
assignee: []
created_date: '2026-09-19 15:41'
updated_date: '2026-09-19 15:44'
labels: []
milestone: m-21
dependencies: []
references:
  - decision-9
documentation:
  - docs/shell-style-guide.md
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
이 저장소에 CLAUDE.md가 없었는데 decision-9/task-114가 'CLAUDE.md의 claude-rails 워크플로'를 참조하고 있어 실제로는 공백이었던 상태. backlog.md 설정 특이사항(filesystem_only: true, remote_operations: false, task_prefix: task)과 POSIX sh 유의사항(docs/shell-style-guide.md, decision-19 링크)을 담는 프로젝트 로컬 CLAUDE.md를 신설해 이 공백을 메움. claude-rails 훅 자체 상세 내용은 사용자 글로벌 CLAUDE.md/메모리에 이미 있으므로 중복 기술하지 않음. m-21 소속 예정.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 저장소 루트에 CLAUDE.md가 생성돼 있다
- [ ] #2 backlog.md 설정 특이사항과 POSIX sh 유의사항이 담겨있다
<!-- AC:END -->
