---
id: TASK-158
title: README.md 개명 + 저장소 구조 섹션 추가
status: To Do
assignee: []
created_date: '2026-09-19 15:41'
updated_date: '2026-09-19 15:44'
labels: []
milestone: m-21
dependencies: []
documentation:
  - backlog/config.yml
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
readme.md -> README.md로 파일명 관례 통일(git-format/claude-rails와 일치). README에 최상위 디렉토리(scripts/, spec/, docs/, backlog/, .claude/, .github/) 한 줄 역할 설명과 backlog/config.yml 특이 설정(filesystem_only: true, remote_operations: false) 설명 섹션 신설. 별도 구조 문서 파일은 만들지 않고 더 깊은 내용은 backlog decision list/task view로 라우팅 (claude-rails 패턴). m-21 소속 예정.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 readme.md가 README.md로 git mv 되어 있다
- [ ] #2 README에 저장소 구조 섹션이 있고 backlog/config.yml의 filesystem_only/remote_operations 설정이 언급되어 있다
<!-- AC:END -->
