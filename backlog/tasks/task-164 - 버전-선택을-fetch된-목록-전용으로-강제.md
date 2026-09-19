---
id: TASK-164
title: 버전 선택을 fetch된 목록 전용으로 강제
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
재현 태스크에서 규명된 원인에 맞춰 수정 - 어떤 환경(stty 실패 폴백 포함)에서도 fetch된 목록 밖 값이 선택/설치되지 않도록 보장. ask_version()/lt_arrow_menu()가 언어(nodejs/java/python/rust/golang)와 동반툴(pnpm/gradle/uv) 공통 함수라 한 번 수정으로 8개 플러그인 전부에 적용됨. shellspec에 '목록 밖 입력은 무시되고 기본값 유지'를 검증하는 케이스 추가. 재현 태스크에 의존. m-22 소속 예정.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 어떤 환경에서도 fetch된 목록 밖 값이 선택/설치되지 않는다
- [ ] #2 shellspec에 목록 밖 입력 무시 케이스가 추가된다
<!-- AC:END -->
