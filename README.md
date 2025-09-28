# zson

*A fast and minimal JSON pretty-printer / minifier with ANSI colors written in [Zig](https://ziglang.org).*

[한국어 README](README.ko.md)

---

## Features

- Pretty-print (`--indent 2|4`)
- Compact/minify (`--compact`)
- Trailing comma fix (`--allow-trailing-commas`)
- Color highlighting (auto-detect TTY, override with `--color` / `--no-color`)
- Input from file, stdin, or direct string (`--eval`)

---

## Install

Requires **Zig 0.13.0+**

Clone and build:

```bash
git clone https://github.com/YOURNAME/zson.git
cd zson
zig build -Doptimize=ReleaseSafe
```

The binary will be located at:

```bash
./zig-out/bin/zson
```

Optionally, copy it into your PATH:

```bash
sudo cp zig-out/bin/zson /usr/local/bin/
```

---

## Usage

Pretty-print with 2-space indentation:

```bash
zson data.json
```

Pretty-print with 4-space indentation:

```bash
zson --indent 4 data.json
```

Compact (minified) output:

```bash
zson --compact data.json
```

Read from stdin:

```bash
cat data.json | zson
```

Evaluate direct string:

```bash
zson --eval '{"user":"nathan","roles":["ADMIN","USER"]}'
```

Allow trailing commas:

```bash
zson --allow-trailing-commas broken.json
```

Force color (even when piping):

```bash
zson --color data.json | less -R
```

---

## Example Output (with colors)

```json
{
  "user": "Nathan",
  "roles": ["ADMIN", "USER"],
  "active": true,
  "score": 42
}
```

---

## License

MIT
