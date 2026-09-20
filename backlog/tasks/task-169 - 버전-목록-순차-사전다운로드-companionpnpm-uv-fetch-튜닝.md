---
id: TASK-169
title: 버전 목록 순차 사전다운로드 + companion(pnpm/uv) fetch 튜닝
status: Done
assignee: []
created_date: '2026-09-20 01:33'
updated_date: '2026-09-20 01:51'
labels: []
dependencies: []
modified_files:
  - scripts/lib.sh
  - scripts/install/00_select.sh
  - spec/lib_spec.sh
  - >-
    backlog/decisions/decision-22 -
    버전-목록은-언어-선택-전에-전부-순차-사전다운로드-decision-16-TASK-119.2를-뒤집음.md
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
companion(pnpm/uv) 버전 프롬프트가 목록을 못 보여주는 원인: (1) pnpm(1.88MB)/uv(9.65MB) 목록이 다른 플러그인보다 훨씬 큰데도 공통 LT_VERSION_FETCH_TIMEOUT(5초)를 그대로 씀 (2) uv가 런당 GitHub API를 2번(latest+list) 호출해 시간당 60회 비로그인 제한을 쉽게 소진 (3) decision-17의 서킷브레이커(한 플러그인이라도 fetch 실패하면 그 세션 나머지 전부 즉시 실패 처리)가 부모보다 늦게 물어보는 companion에 불리하게 작용. 실측(에이전트 조사): nodejs 331KB/0.15s, java ~0.27s, pnpm 1.88MB, gradle 425KB/0.09s, uv 9.65MB/0.89-2.9s.

변경사항(사용자 확인 완료):
1. 순차 사전다운로드: 00_select.sh가 언어 선택 질문 시작 전에 .tool-versions의 8개 플러그인(언어5+companion3) 전부의 버전 목록을 순서대로 미리 fetch해 캐시를 채운다. '버전 정보 가져오는 중...' 표시. decision-16(조회는 lazy, prefetch 없음)과 TASK-119.2(거절할 언어는 fetch 안 함 최적화)를 뒤집으므로 새 decision으로 기록. 서킷브레이커(decision-17) 설계 자체는 안 건드림 - 실패가 첫 질문 전에 보이게만 함.
2. pnpm/uv 목록 fetch에 python처럼 별도의 넉넉한 타임아웃 부여(공통 5초 대신).
3. uv의 /releases/latest 별도 호출 제거, 이미 받은 목록의 최신 항목을 기본값으로 재사용 - GitHub API 호출 런당 2회→1회.

병렬 백그라운드 프리페치는 캐시 파일 동시쓰기 경쟁 상태 위험이 있어 기각, 순차 방식으로 확정(사용자 확인).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 언어 선택 질문 시작 전에 8개 플러그인 전부의 버전 목록이 순서대로 사전 fetch되어 캐시가 채워진다
- [x] #2 pnpm/uv 목록 fetch가 python처럼 확대된 타임아웃을 쓴다
- [x] #3 uv가 런당 GitHub API를 1회만 호출한다(latest 별도 호출 제거)
- [x] #4 decision-16/TASK-119.2를 뒤집는 정책 변경이 새 decision으로 기록된다
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
decision-22 기록 후 00_select.sh에 8개 플러그인 순차 사전다운로드 추가('버전 정보 가져오는 중...' 표시). pnpm/uv 목록 fetch에 LT_LARGE_LIST_TIMEOUT(20초) 부여, uv는 lt_resolve_version_list()를 통해 목록 첫 항목을 기본값으로 재사용해 GitHub API 호출 런당 2회->1회로 축소. shellspec 2건을 바뀐 fetch 경로(목록 캐시/서킷브레이커 파일 격리 + 멀티라인 mock)에 맞게 갱신. expect로 사전다운로드 메시지와 pnpm companion 버전 목록이 실제로 뜨는 것 확인. 커밋 7947a97.
<!-- SECTION:FINAL_SUMMARY:END -->
