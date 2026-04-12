# Upstream bugs

This file tracks bugs in HTTP2.jl's upstream dependencies and in the
tooling HTTP2.jl relies on for development (Julia itself, Documenter,
TestItemRunner, CI actions, etc.). It is the canonical place to
record a finding when the root cause lives outside this repository —
CLAUDE.md's working rule for contributors and AI assistants is
"if you find an upstream bug create entry in upstream-bugs.md file".

Every entry MUST include:

- **Package**: the upstream package, tool, or service.
- **Issue**: a one-line summary of what goes wrong.
- **Upstream link**: URL to the upstream tracker (issue, PR, or commit).
- **Impact on HTTP2.jl**: what breaks, where it breaks, and whether a
  workaround exists locally.
- **Workaround**: the local workaround, if any, and where it lives
  in this repository.
- **Status**: one of `open`, `fixed-upstream`, `worked-around`,
  `resolved`.

Entries are added in reverse-chronological order (newest first).

## Entries

### Nghttp2Wrapper.jl `HTTP2Server` drops the response body

- **Package**: Nghttp2Wrapper.jl
- **Issue**: `Nghttp2Wrapper.HTTP2Server` dispatches request
  handlers, collects the returned `ServerResponse` object, and
  sends it via `nghttp2_submit_response2(session, stream_id,
  nva, nvlen, C_NULL)` — the trailing `C_NULL` is the
  `data_provider` argument. With `C_NULL`, nghttp2 submits
  HEADERS with `END_STREAM` set and **no DATA frames**, so the
  `ServerResponse.body` bytes never reach the client. Any
  handler returning `ServerResponse(200, "hello")` will be seen
  by a client as a 200 response with an empty body.
- **Upstream link**:
  <https://github.com/s-celles/Nghttp2Wrapper.jl> —
  `src/server.jl:404` in the commit pinned by HTTP2.jl's
  `test/interop/` env (`a3dbdfb548c3d4bfbf4ddfce2a835a990f19dcc2`).
  Upstream fix will need to plumb a `data_provider` callback
  that reads from `resp.body`.
- **Impact on HTTP2.jl**: at Milestone 6 the new
  `Interop: h2c live TCP client` item cross-tests HTTP2.jl's
  client-role entry point (`open_connection!`) against
  Nghttp2Wrapper's server and verifies the wire-level round
  trip (preface + SETTINGS + HEADERS request + HEADERS response
  with `:status` + graceful close). Body parity is **not**
  verified because the body never reaches the client — the
  test asserts `isempty(result.body)` with a comment pointing at
  this entry. A handler that echoed headers only (empty-body
  response) would not be affected.
- **Workaround**: the M6 interop test accepts the empty body as
  expected and documents the upstream gap inline. No ccall
  workaround is attempted from HTTP2.jl — that would mask the
  upstream defect and violate Principle I's "no ccall into
  non-Julia protocol logic" rule. When the upstream fix lands,
  the test's `@test isempty(result.body)` flips back to
  `@test String(result.body) == "hello from nghttp2"`.
- **Status**: `open` — file an issue upstream referencing
  `src/server.jl:404` and this entry.

### OpenSSL.jl does not bind `SSL_CTX_set_alpn_select_cb`

- **Package**: OpenSSL.jl
- **Issue**: OpenSSL.jl exports the client-side ALPN setter
  (`ssl_set_alpn`, wrapping `SSL_CTX_set_alpn_protos`) but does
  **not** bind the server-side selection callback
  (`SSL_CTX_set_alpn_select_cb`). Without that binding, a Julia
  TLS server cannot choose a protocol from the list advertised by
  a connecting client, which is the whole point of ALPN on the
  server side.
- **Upstream link**: <https://github.com/JuliaWeb/OpenSSL.jl> —
  no specific issue filed yet; follow-up TODO to open one citing
  RFC 7301 §3.2 and linking this entry.
- **Impact on HTTP2.jl**: server-side `h2` (HTTP/2 over TLS) is
  blocked at Milestone 5. HTTP2.jl is server-role only until
  Milestone 6, and without the selection callback the server
  cannot negotiate `h2` over TLS. `h2c` (cleartext) is unaffected
  and is the primary delivered capability at M5.
- **Workaround**: the M5 `HTTP2OpenSSLExt` package extension
  ships the **client-side** helper
  `HTTP2.set_alpn_h2!(::OpenSSL.SSLContext)` (forward-compatible
  with Milestone 6's client-role work). The limitation is
  documented on `docs/src/tls.md` under "## Current limitations".
  No ccall workaround is attempted locally — per constitution
  Principle I, missing upstream bindings are tracked here, not
  papered over in HTTP2.jl.
- **Status**: `open` — revisit once OpenSSL.jl lands the binding
  or once HTTP2.jl's own roadmap progresses to Milestone 7+ and
  the TLS gap becomes a shipping blocker.

### gRPC-specific header helpers live in src/stream.jl

- **Package**: HTTP2.jl (self-reference — layering concern inherited from M0 extraction)
- **Issue**: `src/stream.jl` defines `get_grpc_encoding`,
  `get_grpc_accept_encoding`, `get_grpc_timeout`, and
  `get_metadata`, each of which reads gRPC-specific headers
  (`grpc-encoding`, `grpc-accept-encoding`, `grpc-timeout`, and
  the set of reserved gRPC headers excluded from user metadata).
  These concepts are gRPC-layer, not HTTP/2-layer, and
  conceptually belong in a gRPC adapter (e.g., gRPCServer.jl)
  rather than in HTTP2.jl.
- **Upstream link**: n/a — this is a design concern in HTTP2.jl
  itself, inherited from the original extraction from gRPCServer.jl
  at Milestone 0. See the Provenance appendix in `CHANGELOG.md`.
- **Impact on HTTP2.jl**: the exported public API surface (post-
  Milestone 3) includes these four symbols. Removing them is a
  breaking change for any downstream consumer that adopted them
  between their introduction and the refactor, so the removal
  has to wait for a major-version bump or for the downstream
  consumers to be identified.
- **Workaround**: documented on the `Streams` page in
  `docs/src/streams.md` under "### gRPC convenience helpers".
  The note explicitly tells users these helpers are gRPC-layer
  conveniences kept for historical reasons.
- **Status**: `open` — revisit when Milestone 8 (gRPCServer.jl
  reverse integration) makes the natural split between HTTP2.jl
  and a gRPC layer easy to execute, or when a dedicated
  layering-cleanup milestone is scheduled.
