# sed 사용 지점 BSD/GNU 이식성 감사 (TASK-126)

이 저장소는 macOS 전용 도구지만, `sed` 문법이 BSD sed(macOS 기본 `/bin/sed`)와
GNU sed 사이에서 갈라지는 지점(특히 `-i` in-place 옵션의 인자 방식)이 있어
예방적으로 전수 감사한다.

## TASK-126.1: 전수 목록화

`grep -rn '\bsed\b'`로 저장소 전체(scripts/, spec/, .github/, install.sh,
uninstall.sh)를 검색한 결과, 실제 sed **호출**은 2곳뿐이다(그 외 매치는
전부 sed를 언급하는 주석). `.github/workflows/`와 `spec/`에는 sed 호출이
전혀 없다.

| # | 파일:줄 | 호출 | 옵션 | 컨텍스트 |
|---|---|---|---|---|
| 1 | `scripts/lib.sh:601` | `sed -n 's/[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\(\.[0-9][0-9]*\)*\).*/\1/p'` | `-n`, BRE(확장 정규식 아님, `-E`/`-r` 없음), in-place 아님(읽기 전용, 파이프 입력) | `version_core()` — 버전 문자열에서 X.Y[.Z] 숫자만 추출 |
| 2 | `scripts/uninstall/03_clean_env_vars.sh:61` | `sed -E -i '.bak' "$@" "$rc"` | `-E`(확장 정규식), `-i '.bak'`(in-place, 백업 접미사 `.bak`를 **별도 인자**로 전달), `"$@"`는 동적으로 조립된 다수의 `-e` 표현식 | `03_clean_env_vars.sh` — rc 파일에서 이 도구가 추가한 줄들을 제거 |

주석(scripts/lib.sh:24, 147, 149 / scripts/install/04_configure_shell_env.sh:18
/ scripts/uninstall/03_clean_env_vars.sh:19,22,26-38,40-45)은 sed를
언급하지만 호출이 아니므로 감사 대상에서 제외. 특히 `03_clean_env_vars.sh`의
주석은 이미 TASK-56(BSD sed의 `\|` 대체 미지원 버그)을 근거로 `-E`를 쓰는
이유와 `-i`에 빈 백업 접미사가 아니라 명시적 `.bak`를 주는 이유를 설명하고
있어, 이 지점이 과거 한 차례 BSD/GNU sed 이식성 버그의 직접적 수정
지점이었음을 보여준다.

## TASK-126.2: BSD/GNU 문법 위험 평가 (이 macOS 개발 머신의 실제 /usr/bin/sed로 검증)

검증 환경: macOS 26.6.2(BuildVersion 25G83), `/bin/sed`는 이 워크트리
샌드박스에 존재하지 않고(제한된 파일뷰) 실제 `sed`는 `/usr/bin/sed`
(BSD sed, `sed – stream editor` man 페이지, `sed script [-EHalnru] [-i extension] [file ...]`
사용법 — GNU sed의 `sed [OPTION]... {script} [input-file]...` 형식과
다름)로 확인됨. 아래는 전부 이 실제 바이너리로 직접 실행해 검증한 결과다 —
문헌 지식이나 Linux GNU sed 결과로 추정하지 않았다.

| # | 호출 | 위험 여부 | 실제 검증 결과 |
|---|---|---|---|
| 1 | `scripts/lib.sh:601` (`sed -n 's/.../.../p'`, `-n` + 순수 BRE) | **안전** | `-i` 없음(in-place 아님) → BSD/GNU `-i` 인자 방식 차이 자체가 적용 대상이 아님. BRE 문법(`\(...\)`, `[^0-9]*` 등)은 POSIX 표준이라 BSD/GNU 공통. 실제 실행: `"temurin-25.0.2+10.0.LTS"` -> `25.0.2`, `"lts"` -> 빈 문자열(정상), `"1.2"` -> `1.2` — 의도대로 동작 확인. |
| 2 | `scripts/uninstall/03_clean_env_vars.sh:61` (`sed -E -i '.bak' "$@" "$rc"`) | **안전** (실제 코드는 이미 올바른 형태) | 실제 rc 파일 샘플로 정확히 동일한 호출(`sed -E -i '.bak' -e '\#pattern#d' ... file`)을 실행 — 대상 줄만 정확히 삭제되고, `file.bak`에 원본 전체가 그대로 백업됨(exit 0). BSD sed는 `-i`에 접미사 인자를 **반드시, 그리고 반드시 별도 토큰으로** 요구하는데, 이 코드는 이미 `.bak`를 명시적으로 주고 있어 안전. |

### 참고: 실제로 재현한 BSD sed 함정 (이 코드가 이미 피하고 있는 것)

같은 `/usr/bin/sed`로 `sed -i -e 's/hello/hi/' file`(접미사 인자를 주지
않고 바로 `-e`를 붙이는, 흔히 GNU sed 스타일로 착각하기 쉬운 형태)을
실행해보면: BSD sed가 `-e`라는 문자열 자체를 `-i`의 백업 접미사로
집어삼켜서, 편집은 되지만(`hello`->`hi`) 원본 파일이 아니라
`file-e`라는 엉뚱한 이름의 백업 파일이 생긴다(치환 스크립트 `'s/hello/hi/'`
자체는 여전히 첫 인자로 남아 이 예제에선 우연히 잘 동작했지만, 진짜
GNU 스타일 `-i` 스크립트라면 `-i` 뒤 첫 인자를 스크립트가 아니라
접미사로 오인해 완전히 깨진다). `03_clean_env_vars.sh:61`은 이 함정을
이미 알고 `.bak`를 명시적으로 줘서 회피하고 있다(주석에도 명시).
새 스크립트를 작성할 때 반드시 피해야 할 안티패턴으로 기록해 둔다.

### 결론

두 호출 모두 **위험 없음**. 별도 수정 불필요(TASK-126.3에서 최종 확인).

## TASK-126.3: 최종 판정

TASK-126.2에서 이 macOS 개발 머신의 실제 `/usr/bin/sed`로 저장소 내 2개
sed 호출 지점을 전부 실행 검증한 결과 둘 다 안전했다. 코드를 억지로
고치지 않고 감사 결과만 기록하고 종료한다(없는 문제를 만들어 고치지
않는다는 지침에 따름):

- `scripts/lib.sh:601`: `-i` 없는 읽기전용 BRE 매칭 — BSD/GNU 차이가
  애초에 적용되지 않는 구조.
- `scripts/uninstall/03_clean_env_vars.sh:61`: `-i '.bak'`에 접미사를
  명시적으로 주는, 이미 BSD-안전한 형태. 실행 검증(대상 줄 삭제 +
  `.bak` 백업 생성)도 통과.
- 이 두 지점 모두 과거 TASK-56(BSD sed `\|` 미지원) 수정을 계기로 이미
  BSD/GNU 이식성을 의식해서 작성된 코드였고, 이번 감사가 실제 /usr/bin/sed
  검증으로 그 주장을 재확인한 것이다.
- 저장소 전체에 이 2곳 외의 sed 호출은 없다(TASK-126.1).

**수정 사항 없음. 감사만으로 종료.**
