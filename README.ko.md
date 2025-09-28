# zson

*[Zig](https://ziglang.org)으로 작성된 빠르고 미니멀한 JSON 예쁘게 출력 / 압축 도구 (ANSI 컬러 지원).*

[English README](README.md)

---

## 기능

- 예쁘게 출력 (`--indent 2|4`)
- 압축/미니파이 (`--compact`)
- 트레일링 콤마 제거 (`--allow-trailing-commas`)
- 컬러 하이라이팅 (TTY 자동 감지, `--color` / `--no-color`로 제어)
- 파일, stdin, 문자열 직접 입력(`--eval`) 지원

---

## 사용법

2칸 들여쓰기 예쁘게 출력:

```bash
zson data.json
```

4칸 들여쓰기 예쁘게 출력:

```bash
zson --indent 4 data.json
```

압축(미니파이) 출력:

```bash
zson --compact data.json
```

stdin에서 읽기:

```bash
cat data.json | zson
```

문자열 직접 평가:

```bash
zson --eval '{"user":"nathan","roles":["ADMIN","USER"]}'
```

트레일링 콤마 허용:

```bash
zson --allow-trailing-commas broken.json
```

컬러 강제 (파이프 상황에서도):

```bash
zson --color data.json | less -R
```

---

## 출력 예시 (컬러 포함)

```json
{
  "user": "Nathan",
  "roles": ["ADMIN", "USER"],
  "active": true,
  "score": 42
}
```

---

## 라이선스

MIT