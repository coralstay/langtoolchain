---
id: TASK-165
title: 버전/언어 선택에 뒤로가기 기능 추가
status: To Do
assignee: []
created_date: '2026-09-19 15:41'
updated_date: '2026-09-19 15:44'
labels: []
milestone: m-22
dependencies:
  - TASK-163
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
언어 선택 -> 버전 선택 -> 동반툴 여부 -> 동반툴 버전으로 이어지는 00_select.sh의 순차 흐름에 이전 질문으로 되돌아가는 조작을 신규 추가(현재는 전혀 없음, backlog 전체 검색 결과 이전에 논의된 적도 없는 완전히 새로운 요청). 순차 흐름에 상태를 되감는 구조가 필요해 구현 전에 설계 방식(예: 메뉴에 '뒤로' 옵션 추가 vs 별도 상태 스택)을 decision으로 먼저 기록. m-22 소속 예정.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 이전 질문으로 되돌아가는 조작이 언어/버전/동반툴 선택 흐름에 추가된다
- [ ] #2 구현 전에 설계 방식이 decision으로 기록된다
<!-- AC:END -->
