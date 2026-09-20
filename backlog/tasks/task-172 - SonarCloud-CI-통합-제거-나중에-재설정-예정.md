---
id: TASK-172
title: SonarCloud CI 통합 제거 (나중에 재설정 예정)
status: Done
assignee: []
created_date: '2026-09-20 10:11'
updated_date: '2026-09-20 10:13'
labels: []
dependencies: []
modified_files:
  - .github/workflows/sonarcloud.yml
  - .github/workflows/sonarcloud-issues-to-github.yml
  - sonar-project.properties
  - README.md
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
사용자가 SonarCloud 설정(SONAR_TOKEN 등)을 나중에 다시 적용할 예정이라, 지금은 실패만 하는 CI 통합을 저장소에서 완전히 제거한다. 제거 대상: .github/workflows/sonarcloud.yml, .github/workflows/sonarcloud-issues-to-github.yml, sonar-project.properties, README.md의 SonarCloud 뱃지(11행)와 기여하기 섹션의 SonarCloud 문단(264행). docs/posix-sh-vs-bash-research.md의 SonarCloud 룰 메타데이터 언급과 spec/bootstrap_asdf_spec.sh의 'SonarCloud S6506' 테스트 설명 문자열은 CI 통합이 아니라 조사기록/회귀테스트 설명이라 그대로 둔다. decision-13/14/18/19/20/21 등 SonarCloud를 언급하는 backlog 과거 기록도 그대로 둔다(과거 기록 편집 금지 관례). 재설정 시점은 사용자가 정할 사안이라 이번 범위 밖.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 .github/workflows/sonarcloud.yml, sonarcloud-issues-to-github.yml, sonar-project.properties가 삭제된다
- [x] #2 README.md의 SonarCloud 뱃지와 기여하기 섹션 문단이 제거된다
- [x] #3 docs/posix-sh-vs-bash-research.md, spec/bootstrap_asdf_spec.sh, backlog 과거 기록은 그대로 유지된다
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
sonarcloud.yml/sonarcloud-issues-to-github.yml/sonar-project.properties 삭제, README의 SonarCloud 뱃지+기여하기 문단 제거. docs/posix-sh-vs-bash-research.md와 spec/bootstrap_asdf_spec.sh의 Sonar 언급, backlog 과거 decision들은 확인 후 그대로 유지. shellspec bootstrap_asdf_spec 4/4 통과. 커밋 c7f2f19.
<!-- SECTION:FINAL_SUMMARY:END -->
