---
id: TASK-166
title: Ctrl-C 시 터미널 raw 모드 고착 버그 수정
status: Done
assignee: []
created_date: '2026-09-19 15:54'
updated_date: '2026-09-19 19:44'
labels: []
milestone: m-22
dependencies: []
references:
  - task-108
documentation:
  - scripts/install/00_select.sh
modified_files:
  - scripts/install/00_select.sh
type: bug
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
scripts/install/00_select.sh의 lt_arrow_menu()가 모든 호출부(ask_yes_no, ask_version, pin-scope 프롬프트)에서 $(...) 커맨드 서브스티튜션으로 호출되는데, POSIX 서브스티튜션은 서브셸을 포크하므로 그 안에서 설정되는 _LT_RAW_STTY(line 383)가 부모 프로세스로 전파되지 않는다. 결과적으로 EXIT trap(line 548-549)의 stty 복원 안전장치가 사실상 죽은 코드가 되어, 메뉴 진행 중 Ctrl-C를 누르면 터미널이 raw/no-echo 상태로 고착된다. expect로 실제 pty에서 재현 확인됨. TASK-108(Done, m-10)이 이 안전장치가 있다고 명시했지만 spec/select_spec.sh가 /dev/tty 인터랙티브 경로를 커버리지에서 제외해 발견되지 못했음. m-22 소속 예정, TASK-163/164/165와 같은 파일을 다루므로 조율 필요.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 $(...)로 lt_arrow_menu를 호출해도 부모 프로세스의 EXIT trap이 raw stty 상태를 실제로 복원한다
- [x] #2 메뉴 진행 중 SIGINT를 보내는 회귀 테스트(또는 재현 스크립트)로 확인된다
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
TASK-164와 같은 파일(00_select.sh)을 같은 세션에서 같이 작업 - task/TASK-164 브랜치에 두 태스크 커밋이 함께 있음(23306ef).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
_LT_RAW_STTY_FILE($$-scoped, LT_VERSION_LIST_UNREACHABLE_FILE과 동일 패턴)을 추가해 lt_arrow_menu()의 명령 치환 서브셸이 캡처한 원본 stty 설정을 부모 프로세스의 EXIT trap(lt_restore_raw_stty)이 읽을 수 있게 함. expect로 SIGINT를 실제로 보내고 stty 호출 자체를 로깅해 검증: 수정 전엔 'stty -g'+'stty -icanon...' 2개 호출만 있고 복원 호출이 없었는데, 수정 후엔 원본 설정 그대로 복원하는 3번째 stty 호출이 실제로 발생함을 확인. 커밋 23306ef(TASK-164와 공유).
<!-- SECTION:FINAL_SUMMARY:END -->
