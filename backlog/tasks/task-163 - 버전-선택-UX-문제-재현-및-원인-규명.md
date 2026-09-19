---
id: TASK-163
title: 버전 선택 UX 문제 재현 및 원인 규명
status: To Do
assignee: []
created_date: '2026-09-19 15:41'
updated_date: '2026-09-19 15:44'
labels: []
milestone: m-22
dependencies: []
documentation:
  - scripts/install/00_select.sh
type: spike
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-129/m-15가 Done이지만 실사용(로컬 clone 후 ./install.sh 직접 실행)에서 버전 선택 단계가 화살표 메뉴가 아니라 번호를 타이핑하는 프롬프트처럼 느껴진다는 사용자 제보. scripts/install/00_select.sh의 lt_arrow_menu()(line 353-424)는 stty -g < /dev/tty가 실패하면 번호-타이핑 폴백(line 358-376)으로 조용히 전환되는데, 이게 원인인지 다른 원인(예: 목록 fetch 자체 실패, 다른 코드 경로)인지 실제 터미널에서 재현해 확정. AC: 재현 절차/로그로 정확한 실패 지점을 기록. m-22 소속 예정, 스파이크.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 실제 터미널에서 버전 선택 단계를 재현해 stty 폴백인지 다른 원인인지 확정한다
<!-- AC:END -->
