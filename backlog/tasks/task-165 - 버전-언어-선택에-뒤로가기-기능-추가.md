---
id: TASK-165
title: 버전/언어 선택에 뒤로가기 기능 추가
status: Done
assignee: []
created_date: '2026-09-19 15:41'
updated_date: '2026-09-19 19:57'
labels: []
milestone: m-22
dependencies:
  - TASK-163
references:
  - decision-21
modified_files:
  - scripts/lib.sh
  - scripts/install/00_select.sh
  - spec/lib_spec.sh
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
언어 선택 -> 버전 선택 -> 동반툴 여부 -> 동반툴 버전으로 이어지는 00_select.sh의 순차 흐름에 이전 질문으로 되돌아가는 조작을 신규 추가(현재는 전혀 없음, backlog 전체 검색 결과 이전에 논의된 적도 없는 완전히 새로운 요청). 순차 흐름에 상태를 되감는 구조가 필요해 구현 전에 설계 방식(예: 메뉴에 '뒤로' 옵션 추가 vs 별도 상태 스택)을 decision으로 먼저 기록. m-22 소속 예정.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 이전 질문으로 되돌아가는 조작이 언어/버전/동반툴 선택 흐름에 추가된다
- [x] #2 구현 전에 설계 방식이 decision으로 기록된다
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
구현 중 IFS= read로 두 필드 분리가 깨지는 실수를 expect 재현 테스트로 바로 잡아냄(plugin에 'nodejs lts'가 통째로 들어가던 증상) - 코드 리뷰만으론 놓치기 쉬운 종류라 실제 pty 구동 검증이 값을 했음.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
decision-21(언어 단위 뒤로가기, 하위 스텝 스택은 범위 밖)을 먼저 기록한 뒤 구현. 언어 순회를 stream read에서 위치매개변수 인덱스 순회(lt_run_language_loop)로 바꿔 되감기 가능하게 하고, 2번째 언어부터 '◀ 뒤로' 옵션 노출 + lt_forget_language_lines()로 이전 기록 정리. lt_nth_arg() 헬퍼를 lib.sh에 추가(유닛 테스트 4개). expect로 실제 pty에서 뒤로가기 전체 흐름 검증 완료, --all/--yes 비대화형 경로 회귀 없음. 커밋 0c68d52.
<!-- SECTION:FINAL_SUMMARY:END -->
