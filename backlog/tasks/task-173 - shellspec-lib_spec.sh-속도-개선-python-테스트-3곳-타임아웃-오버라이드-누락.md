---
id: TASK-173
title: shellspec lib_spec.sh 속도 개선 - python 테스트 3곳 타임아웃 오버라이드 누락
status: Done
assignee: []
created_date: '2026-09-20 10:20'
updated_date: '2026-09-20 10:25'
labels: []
dependencies: []
modified_files:
  - spec/lib_spec.sh
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
spec/lib_spec.sh:931,1164,1385의 python 관련 테스트 3개가 git은 mock 처리했지만 LT_PYTHON_TAGS_TIMEOUT을 오버라이드 안 해서 매번 진짜 20초 기본값을 기다림 - 같은 파일 947행의 형제 테스트는 이미 LT_PYTHON_TAGS_TIMEOUT=1로 올바르게 처리 중이라 그 패턴을 그대로 적용. 1385행 단독 실행만 22.6초 걸림이 확인돼 전체 70~80초의 대부분을 차지. mock으로 이미 대체된 git 호출의 타임아웃 값 자체를 테스트하는 게 아니라 커버리지 손실 없음. 예상 결과: lib_spec.sh 전체 ~80초 -> ~15~20초. 다른 원인(shellspec 자체 오버헤드, Include 재파싱, --jobs 병렬화)은 서브에이전트 조사로 기각됨.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 spec/lib_spec.sh:931,1164,1385 세 테스트에 LT_PYTHON_TAGS_TIMEOUT 오버라이드가 추가된다
- [x] #2 lib_spec.sh 전체 실행 시간이 크게 줄어든다(목표 ~15-20초대)
- [x] #3 기존 146+ examples 전부 통과 유지(커버리지 손실 없음)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
shellspec --profile로 재확인 결과 남은 ~38~42초는 특정 테스트가 아니라 146개 예제 각각의 Include scripts/lib.sh 재로딩 고정 오버헤드 누적으로 보임 - 추가로 줄이려면 shellspec 내부 구조를 건드려야 해서 이번 범위 밖으로 둠.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
spec/lib_spec.sh:931/1181/1403(현재 라인 기준) 세 python 테스트에 LT_PYTHON_TAGS_TIMEOUT=1 추가(같은 파일 기존 TASK-138.2 회귀 테스트와 동일 패턴 재사용). shellspec --profile로 확인: 가장 느렸던 예제들이 20초+에서 1초대로 줄어듦. 전체 lib_spec.sh 실행시간 ~80초->~38~42초(약 2배 이상 단축). 146 examples 0 failures로 커버리지 손실 없음 확인. 남은 시간은 Include 재로딩 고정비용으로 판단, 추가 최적화는 범위 밖.
<!-- SECTION:FINAL_SUMMARY:END -->
