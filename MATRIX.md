# Feature matrix — requests / httpx → cl-stack-http

Printed at runtime by `(http-parity:print-matrix)`.

| Area | Python | Status | Notes |
|------|--------|--------|-------|
| verbs | get/post/put/patch/delete/head/options | **have** | stack-http facade |
| async | AsyncClient / `*-async` | **have** | blackbird; sync `SEND` awaits |
| session | Session cookies + base_url | **have** | `with-session` |
| json | `json=` / `r.json()` | **have** | `:json` + `response-json` |
| form | `data=` urlencoded | **have** | `:form-data` (protocol 0.2) |
| files | `files=` multipart | **have** | `coerce-files` / `path-http-file` |
| download | path write | **have** | `download`; dir + CD filename (`:filename :content-disposition`) |
| upload | path read | **have** | `upload` |
| text / content / ok | `r.text` / `.content` / `.ok` | **have** | response DX |
| stream | `iter_bytes` / `iter_lines` | **have** | `:want-stream` |
| gzip / deflate | Content-Encoding | **have** | chipz; finance demo forces gzip AE |
| br / zstd | Content-Encoding | **partial** | soft-load; finance demo hits live `br` (Frankfurter/Fin-node) |
| basic / bearer | auth | **have** | protocol `:auth` |
| digest | HTTPDigestAuth | **have** | stack-http sync retry (`http-protocol` 0.2.1+) |
| netrc / trust_env | `trust_env` | **have** | env proxy + `~/.netrc` |
| redirect | `allow_redirects` / history | **have** | protocol |
| timeout | `timeout=` | **have** | `http-timeout` |
| proxy | `proxies=` | **have** | `http-proxy-config` |
| socks | socks5 | **partial** | async SOCKS5 |
| http2 | `http2=True` | **missing** | wave-1 = HTTP/1.1 |
| oauth2 | auth plugins | **sep** | [`cl-stack-oauth2`](https://github.com/egao1980/cl-stack-oauth2) |
| jwt | JWT helpers | **sep** | [`cl-stack-jwt`](https://github.com/egao1980/cl-stack-jwt) |
| websocket | WS | **sep** | [`ws-protocol`](https://github.com/egao1980/ws-protocol) |
