# http-parity

Demo / test app: **[`cl-stack-http`](https://github.com/egao1980/cl-stack-http)** feature parity vs **requests** / **httpx**, preferring **[`http-backend-async`](https://github.com/egao1980/http-backend-async)** (libuv).

Default origin is a **local httpbin-shaped fixture** (cleartext). Optional public live via `HTTP_PARITY_FIXTURE=0` + `HTTP_PARITY_BASE` (httpbingo often 402s async TLS at the Fly edge).

## Matrix

See [MATRIX.md](MATRIX.md). Status keys: `have` · `partial` · `missing` · `sep` (other package).

## Realistic demo

Login → JSON catalog list/create → download blobs (async + session `base-url`):

```bash
export HTTP_PARITY_BACKEND=async
export HTTP_PARITY_FIXTURE=1
ros -l scripts/demo.lisp
```

## Finance demo (live CE + CD filenames)

Public HTTPS: Frankfurter FX (query + date range) + Fin-node equity JSON downloads.
Exercises real-world `Content-Encoding` (`br` default, forced `gzip`) and
`Content-Disposition` filenames via `http:download` → directory.

```bash
export HTTP_PARITY_BACKEND=async
export HTTP_PARITY_FIXTURE=0
# soft-loads http-encoding-brotli / http-encoding-chipz when available
ros -l scripts/finance-demo.lisp
```

Live Rove case (skipped unless set):

```bash
export HTTP_PARITY_FINANCE=1
ros -e '(asdf:test-system "http-parity")' -q
```

## Run tests

```bash
export HTTP_PARITY_BACKEND=async          # default
export HTTP_PARITY_FIXTURE=1              # default — local origin
export HTTP_ASYNC_EVENT_BACKEND=libuv     # or libev

ros -l scripts/run.lisp
# or
ros -e '(asdf:test-system "http-parity")' -q
```

Public live (optional):

```bash
export HTTP_PARITY_FIXTURE=0
export HTTP_PARITY_BASE=https://httpbingo.org
export HTTP_PARITY_LIVE=1
ros -l scripts/run.lisp
```

Print matrix only:

```lisp
(asdf:load-system "http-parity")
(http-parity:print-matrix)
```

## Env

| Variable | Default | Meaning |
|----------|---------|---------|
| `HTTP_PARITY_BACKEND` | `async` | `:async` / `:dexador` / `:winhttp` |
| `HTTP_PARITY_FIXTURE` | on | local httpbin fixture; `0` → use `HTTP_PARITY_BASE` |
| `HTTP_PARITY_BASE` | `https://httpbingo.org` | Public origin when fixture off |
| `HTTP_PARITY_LIVE` | on | `0`/`false`/`off` skips cases |
| `HTTP_PARITY_BR_URL` | `{BASE}/brotli` | Optional br probe |
| `HTTP_PARITY_FINANCE` | off | `1` → live Frankfurter/Fin-node CE+CD test |
| `HTTP_ASYNC_EVENT_BACKEND` | `libuv` | Event backend for async |

## Coverage

| Area | Cases |
|------|-------|
| Verbs | GET sync+async, POST, HEAD, OPTIONS, PUT/PATCH/DELETE |
| JSON | `response-json`, `:json` post, `http:json` helper |
| Session | cookies + default params |
| Auth | basic, bearer, digest |
| Redirect | follow, history, max-redirects |
| CE | gzip, deflate, optional br; finance demo = live br+gzip |
| Stream | `:want-stream` sync + async |
| Files | multipart tuples, download/upload + CD filename + MIME ext |
| Status | `raise-for-status`, short timeout |
| SOCKS | local SOCKS5h GET (async); winhttp/dexador missing |

## Layering

| Layer | Role |
|-------|------|
| `http-protocol` + backends | urllib3 / httpx wire |
| `cl-stack-http` | requests-like DX under test |
| **http-parity** | this demo / CI canary |

## License

MIT
