---
id: TASK-168
title: raw 모드 불가 터미널에서 버전 폴백을 숫자입력 대신 순차 Enter/스킵 방식으로 교체
status: Done
assignee: []
created_date: '2026-09-20 01:08'
updated_date: '2026-09-20 01:38'
labels: []
dependencies: []
modified_files:
  - scripts/lib.sh
  - scripts/install/00_select.sh
  - spec/lib_spec.sh
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
stty -g 실패로 lt_arrow_menu()가 타는 번호-타이핑 폴백을 버전 선택에서만 대체한다. lt_arrow_menu()는 ask_yes_no/scope 질문과 공유하는 함수라 손대지 않고(범위: 언어 선택 폴백은 이번에 안 건드림, 사용자 확인 완료), ask_version()이 stty -g < /dev/tty 성공 여부를 스스로 먼저 확인해 안 될 때만 새 경로로 분기한다: lib.sh에 순수함수 lt_render_version_table()(옵션 라벨 목록을 SDKMAN sdk list 스타일 번호 매긴 표로 렌더링, 유닛 테스트 가능) 추가 + 00_select.sh에 lt_version_walkthrough()(표를 보여준 뒤 순서대로 'N번째 사용? [Enter=예, 다른 키+Enter=다음]'으로 순회 - 숫자/버전 문자열 타이핑 없음, 전부 스킵하면 안전하게 default 사용) 추가. 성공 시(raw 모드 가능)는 기존 lt_arrow_menu 경로 그대로.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 raw 모드 불가 환경(stty -g 실패)에서 버전 선택 시 숫자나 문자열을 타이핑하지 않고도(Enter 또는 임의 키+Enter만으로) 원하는 fetch된 버전을 선택할 수 있다
- [x] #2 선택 전 fetch된 버전 목록 전체가 SDKMAN 스타일 표로 한 번 출력된다
- [x] #3 lt_valid_menu_choice()(TASK-164)는 그대로 유지(ask_yes_no/scope 질문 폴백에서 계속 사용)하고, 신규 lt_render_version_table()에 대한 shellspec 유닛 테스트가 추가된다
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
ask_version()이 raw 모드 가능 여부를 스스로 확인해 안 될 때만 lt_render_version_table()(표)+lt_version_walkthrough()(Enter/스킵 순회)로 분기, lt_arrow_menu()/lt_valid_menu_choice()는 다른 폴백(ask_yes_no/scope)용으로 그대로 유지. expect+가짜 stty로 표 렌더링과 스킵→선택 흐름이 install list에 정확히 반영됨을 확인, 정상 raw 모드 경로 회귀 없음. shellspec 146+5 examples 0 failures. 커밋 108ad8a.
<!-- SECTION:FINAL_SUMMARY:END -->
