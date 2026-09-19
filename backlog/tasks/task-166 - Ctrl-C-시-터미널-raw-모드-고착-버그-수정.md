---
id: TASK-166
title: Ctrl-C 시 터미널 raw 모드 고착 버그 수정
status: To Do
assignee: []
created_date: '2026-09-19 15:54'
updated_date: '2026-09-19 15:54'
labels: []
milestone: m-22
dependencies: []
references:
  - task-108
documentation:
  - scripts/install/00_select.sh
type: bug
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
scripts/install/00_select.sh의 lt_arrow_menu()가 모든 호출부(ask_yes_no, ask_version, pin-scope 프롬프트)에서 $(...) 커맨드 서브스티튜션으로 호출되는데, POSIX 서브스티튜션은 서브셸을 포크하므로 그 안에서 설정되는 _LT_RAW_STTY(line 383)가 부모 프로세스로 전파되지 않는다. 결과적으로 EXIT trap(line 548-549)의 stty 복원 안전장치가 사실상 죽은 코드가 되어, 메뉴 진행 중 Ctrl-C를 누르면 터미널이 raw/no-echo 상태로 고착된다. expect로 실제 pty에서 재현 확인됨. TASK-108(Done, m-10)이 이 안전장치가 있다고 명시했지만 spec/select_spec.sh가 /dev/tty 인터랙티브 경로를 커버리지에서 제외해 발견되지 못했음. m-22 소속 예정, TASK-163/164/165와 같은 파일을 다루므로 조율 필요.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 $(...)로 lt_arrow_menu를 호출해도 부모 프로세스의 EXIT trap이 raw stty 상태를 실제로 복원한다
- [ ] #2 메뉴 진행 중 SIGINT를 보내는 회귀 테스트(또는 재현 스크립트)로 확인된다
<!-- AC:END -->
