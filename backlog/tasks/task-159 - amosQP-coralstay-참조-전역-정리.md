---
id: TASK-159
title: amosQP -> coralstay 참조 전역 정리
status: Done
assignee: []
created_date: '2026-09-19 15:41'
updated_date: '2026-09-19 16:08'
labels: []
milestone: m-21
dependencies:
  - TASK-158
modified_files:
  - README.md
  - .github/workflows/e2e-verify.yml
  - install.sh
  - uninstall.sh
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
GitHub 계정이 amosQP에서 coralstay로 개명(동일인, 확인됨)됐는데 README.md의 curl 설치/제거 URL 3곳, git clone 안내, 하단 크레딧(총 6곳)과 .github/workflows/e2e-verify.yml:146의 curl 설치 URL이 여전히 옛 이름을 참조 중. curl-pipe 설치 원라이너라 계정명이 나중에 제3자에게 재등록되면 조용히 낯선 소스로 넘어갈 위험. SonarCloud 프로젝트 키/조직명(sonar-project.properties, sonarcloud-issues-to-github.yml의 amosqp/amosQP_langtoolchain)은 사용자가 SonarCloud 재설정 시 별도 처리 예정이라 이번 범위에서 제외. m-21 소속 예정.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 README.md/e2e-verify.yml의 amosQP 참조가 coralstay로 바뀌어 있다 (SonarCloud 키 제외)
- [x] #2 grep -rn amosQP 결과 sonar-project.properties/sonarcloud-issues-to-github.yml 외엔 안 남아있다
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
당초 계획(README 6곳 + e2e-verify.yml)에 없던 install.sh:44/uninstall.sh:23의 REPO_URL 기본값도 발견해서 같이 고침 - curl|bash 경로의 실제 self-clone 대상이라 문서만 고치는 것보다 훨씬 중요한 지점이었음. spec/repo_override_spec.sh의 amosQP 언급은 TASK-117.6 이전 상태를 설명하는 과거형 주석이라 의도적으로 안 건드림.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
README.md 6곳 + e2e-verify.yml + install.sh/uninstall.sh REPO_URL까지 amosQP->coralstay 교체(SonarCloud 키 제외). grep -rn amosQP 결과 살아있는 코드 중엔 sonar-project.properties/sonarcloud-issues-to-github.yml(SonarCloud 식별자, 계획대로 제외)과 spec/repo_override_spec.sh의 과거형 설명 주석만 남음. shellcheck 기존 경고(SC3043, local 사용) 외 신규 이슈 없음, shellspec repo_override_spec 5/5 통과. 커밋 3fe1a57.
<!-- SECTION:FINAL_SUMMARY:END -->
