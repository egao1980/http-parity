# http-parity

Demo / test app: **[`cl-stack-http`](https://github.com/egao1980/cl-stack-http)** feature parity vs **requests** / **httpx**, preferring **[`http-backend-async`](https://github.com/egao1980/http-backend-async)** (libuv).

Default origin is a **local httpbin-shaped fixture** (cleartext). Optional public live via `HTTP_PARITY_FIXTURE=0` + `HTTP_PARITY_BASE` (httpbingo often 402s async TLS at the Fly edge).

## Matrix

See [MATRIX.md](MATRIX.md). Status keys: `have` · `partial` · `missing` · `sep` (other package).

## Run locally

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
| `HTTP_ASYNC_EVENT_BACKEND` | `libuv` | Event backend for async |

## Coverage

| Area | Cases |
|------|-------|
| Verbs | GET sync+async, POST, HEAD, OPTIONS, PUT/PATCH/DELETE |
| JSON | `response-json`, `:json` post, `http:json` helper |
| Session | cookies + default params |
| Auth | basic, bearer, digest |
| Redirect | follow, history, max-redirects |
| CE | gzip, deflate, optional br |
| Stream | `:want-stream` sync + async |
| Files | multipart tuples, download/upload round-trip |
| Status | `raise-for-status`, short timeout |

## Layering

| Layer | Role |
|-------|------|
| `http-protocol` + backends | urllib3 / httpx wire |
| `cl-stack-http` | requests-like DX under test |
| **http-parity** | this demo / CI canary |

## License

MIT
