# Changelog

All notable changes to HTTP2.jl will be documented in this file.

The format is based on [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and HTTP2.jl adheres to [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] — 2026-04-12

First tagged release of HTTP2.jl. Pure-Julia HTTP/2 library
(RFC 9113) with HPACK header compression (RFC 7541), covering
both server and client roles and cross-tested against
`libnghttp2` via [Nghttp2Wrapper.jl](https://github.com/s-celles/Nghttp2Wrapper.jl).
Extracted from [gRPCServer.jl](https://github.com/s-celles/gRPCServer.jl)
and developed standalone under the HTTP2.jl constitution (pure
Julia, TDD with TestItemRunner, reference parity, Keep a Changelog,
warning-free Documenter).

**Version renumber note**: this tag is `v0.1.0`, but the
working-copy `Project.toml` reached `v0.5.0` through
milestone-by-milestone minor bumps during Milestones 2–6. The
backwards bump from `0.5.0` to `0.1.0` is permitted because
HTTP2.jl has never been registered on the Julia General registry
before this tag; no downstream consumer has resolved a version
higher than `0.1.0` yet. SemVer 2.0.0 §5 only prohibits
republished versions and backwards-incompatible public API
removals without a MAJOR bump — it does not prohibit renumbering
a package that has never been published. See `ROADMAP.md` for the
full milestone trajectory and commit SHAs for each step.

### Added

- **Frame layer (RFC 9113 §6)** — full encode / decode for all
  frame types via `encode_frame` / `decode_frame`; constructors
  for DATA, HEADERS, SETTINGS, PING, GOAWAY, RST_STREAM,
  WINDOW_UPDATE, CONTINUATION, PRIORITY. Doctests for every
  public constructor. Exports: `FrameType`, `FrameFlags`,
  `ErrorCode`, `SettingsParameter`, `FrameHeader`, `Frame`,
  `encode_frame`, `decode_frame`, `encode_frame_header`,
  `decode_frame_header`, `has_flag`, `data_frame`,
  `headers_frame`, `settings_frame`, `parse_settings_frame`,
  `ping_frame`, `goaway_frame`, `parse_goaway_frame`,
  `rst_stream_frame`, `window_update_frame`,
  `parse_window_update_frame`, `continuation_frame`,
  `FRAME_HEADER_SIZE`, `CONNECTION_PREFACE`,
  `DEFAULT_INITIAL_WINDOW_SIZE`, `DEFAULT_MAX_FRAME_SIZE`,
  `MIN_MAX_FRAME_SIZE`, `MAX_MAX_FRAME_SIZE`,
  `DEFAULT_HEADER_TABLE_SIZE`. First delivered at Milestone 2.
- **HPACK header compression (RFC 7541)** — encoder, decoder,
  dynamic table, Huffman compression, integer and string
  primitive encoding. Cross-validated against 23,688 conformance
  cases from [hpack-test-case](https://github.com/http2jp/hpack-test-case)
  covering the nghttp2, go-hpack, python-hpack, and raw-data
  suites. Exports: `DynamicTable`, `HPACKEncoder`, `HPACKDecoder`,
  `encode_headers`, `decode_headers`, `set_max_table_size!`,
  `encode_table_size_update`, `huffman_encode`, `huffman_decode`,
  `huffman_encoded_length`, `encode_integer`, `decode_integer`,
  `encode_string`, `decode_string`. First delivered at Milestone 2.
- **Stream state machine (RFC 9113 §5)** — `HTTP2Stream` with
  idle → open → half-closed → closed transitions, reserved
  states for server push (tracked but not affirmatively handled),
  odd / even stream-ID parity enforcement. Role-aware helpers
  `is_client_initiated` / `is_server_initiated`. Exports:
  `HTTP2Stream`, `StreamError`, `StreamState`, `is_client_initiated`,
  `is_server_initiated`, `can_send`, `can_receive`, `is_closed`,
  `receive_headers!`, `send_headers!`, `receive_data!`,
  `send_data!`, `receive_rst_stream!`, `send_rst_stream!`,
  `update_send_window!`, `update_recv_window!`, `get_data`,
  `peek_data`, `get_header`, `get_headers`, `get_method`,
  `get_path`, `get_authority`, `get_content_type`,
  `get_grpc_encoding`, `get_grpc_accept_encoding`,
  `get_grpc_timeout`, `get_metadata`. First delivered at
  Milestone 3.
- **Flow control (RFC 9113 §5.2)** — `FlowController` +
  `FlowControlWindow` handling WINDOW_UPDATE, zero-window edge
  cases, and stream vs connection window interactions. Exports:
  `FlowControlWindow`, `FlowController`, `consume!`,
  `try_consume!`, `release!`, `available`, `should_send_update`,
  `get_update_increment`, `update_initial_size!`,
  `create_stream_window!`, `get_stream_window`,
  `remove_stream_window!`, `consume_send!`, `max_sendable`,
  `apply_window_update!`, `apply_settings_initial_window_size!`,
  `generate_window_updates`, `DataSender`, `send_data_frames`,
  `DataReceiver`. First delivered at Milestone 3.
- **Connection layer** — `HTTP2Connection` with preface
  exchange, SETTINGS negotiation, GOAWAY, graceful shutdown.
  Exports: `HTTP2Connection`, `ConnectionError`,
  `ConnectionSettings`, `ConnectionState`, `apply_settings!`,
  `to_frame`, `get_stream`, `can_send_on_stream`,
  `create_stream`, `remove_stream`, `active_stream_count`,
  `process_preface`, `process_frame`, `process_settings_frame!`,
  `process_ping_frame!`, `process_goaway_frame!`,
  `process_window_update_frame!`, `process_headers_frame!`,
  `process_continuation_frame!`, `process_data_frame!`,
  `process_rst_stream_frame!`, `send_headers`, `send_data`,
  `send_trailers`, `send_rst_stream`, `send_goaway`, `is_open`.
  First delivered at Milestone 3.
- **Reference parity with libnghttp2** — separate
  `test/interop/` environment with its own `Project.toml`
  (`julia = "1.12"`) that brings Nghttp2Wrapper.jl in as a
  test-only dependency pinned to commit
  `a3dbdfb548c3d4bfbf4ddfce2a835a990f19dcc2`. 14 `Interop:`
  `@testitem` units cross-test HTTP2.jl against `libnghttp2`
  for: connection preface, frame type / flag / settings
  parameter constants, HPACK encode-both-ways via
  `HpackDeflater` / `HpackInflater`, SETTINGS round-trip, PING
  round-trip, GOAWAY across 3 error codes, RST_STREAM, DATA
  padding, WINDOW_UPDATE, live h2c TCP handshake (HTTP2.jl
  server vs nghttp2 client), ALPN helper extension, live h2c
  TCP client (HTTP2.jl client vs nghttp2 server), and live TLS
  ALPN handshake. Server-role parity first delivered at
  Milestone 4; live TCP cross-tests added at Milestone 5;
  client-role parity at Milestone 6. **Operationally fulfills
  constitution Principle III for both server and client roles.**
- **Transport layer — server-role IO entry point** — new
  public function `serve_connection!(conn::HTTP2Connection,
  io::IO; max_frame_size::Int = DEFAULT_MAX_FRAME_SIZE)` in
  `src/serve.jl` that drives a server-role connection over any
  `Base.IO` transport satisfying the IO adapter contract
  (`read(io, n::Int)`, `write(io, bytes)`, `close(io)`).
  Handles preface, server preface write-back, frame read loop
  with `max_frame_size` enforcement, and graceful EOF. Known-
  compatible transports: `Base.IOBuffer` (via a split-IO
  wrapper), `Base.BufferStream`, `Sockets.TCPSocket`,
  `OpenSSL.SSLStream`. First delivered at Milestone 5.
- **Optional TLS ALPN helper via package extension** —
  `HTTP2.set_alpn_h2!(ctx::OpenSSL.SSLContext, protocols::Vector{String} = ["h2"])`
  provided by the `HTTP2OpenSSLExt` package extension.
  Registers the ALPN protocol list on a TLS context via
  OpenSSL.jl's `ssl_set_alpn`, converting the user-facing
  `Vector{String}` into RFC 7301 §3.1 wire format (length-
  prefixed concatenation, max 255 bytes per name). The
  extension loads automatically when HTTP2 and OpenSSL are
  both in the environment; without OpenSSL, the generic
  function has zero methods and calls throw `MethodError` —
  keeping HTTP2.jl's runtime dependency graph empty
  (constitution Principle I). First delivered at Milestone 5
  (scaffold), live-tested at Milestone 6.
- **Transport layer — client-role IO entry point** — new
  public function `open_connection!(conn::HTTP2Connection,
  io::IO; request_headers, request_body=nothing,
  max_frame_size=DEFAULT_MAX_FRAME_SIZE, read_timeout=nothing)`
  in `src/client.jl` that drives a single client-role request
  / response exchange over any `Base.IO` transport. Sends
  preface + initial SETTINGS with `SETTINGS_ENABLE_PUSH = 0`,
  writes the request HEADERS (plus optional DATA) on an odd
  stream ID, reads the response HEADERS / CONTINUATION / DATA
  into a local `ClientStreamState`, and returns a `NamedTuple`
  with fields `(:status, :headers, :body)`. Handles graceful
  GOAWAY, `RST_STREAM`, `FRAME_SIZE_ERROR`, and unexpected
  `PUSH_PROMISE` per RFC 9113 §8.4. Exports:
  `serve_connection!`, `set_alpn_h2!`, `open_connection!`.
  First delivered at Milestone 6.
- **Test suite** — 24,809 main-env assertions and 24,937
  interop-env assertions (+ 1 `@test_broken` documenting the
  server-side ALPN gap), totalling **49,746 pass + 1 broken**
  at the release commit. The main suite is runnable on Julia
  ≥ 1.10; the interop suite requires Julia ≥ 1.12 because of
  Nghttp2Wrapper.jl's minimum.
- **Documentation** — 10-page Documenter site (Home, Frames,
  HPACK, Streams, Connection, Flow control, Interop parity,
  TLS & transport, Client, API Reference). Warning-free build
  enforced as a pre-commit gate from Milestone 1 onward.
- **CI** — GitHub Actions matrix `julia=[1.10, 1] × os=[ubuntu-latest]`
  for the main `test` job, plus a separate `interop` job
  pinned to `julia=1` for the `test/interop/` env. A
  `Documentation` workflow builds the docs and, as of this
  release, deploys to `gh-pages` on tag pushes (see Changed).

### Changed

- `Project.toml` version renumbered from `0.5.0` to `0.1.0`
  for the first tagged release. See the "Version renumber
  note" at the top of this section for the SemVer
  justification.
- `.github/workflows/Documentation.yml` gains a
  `permissions: contents: write` block and a `push: tags: ['v*']`
  trigger so that Documenter's `deploydocs` call can push the
  rendered site to the `gh-pages` branch on each tagged
  release. Previously the build ran on every push / pull
  request but the deploy step was a silent no-op because the
  default `GITHUB_TOKEN` permissions are read-only.
- `README.md` expanded from its 2-line stub into a full
  landing page covering elevator pitch, installation, a
  worked example, supported features, current limitations,
  status badges, and cross-links to the changelog, roadmap,
  and parity page.
- `CHANGELOG.md` restructured to consolidate the
  milestone-scoped `### Added (Milestone N)` / `### Changed
  (Milestone N)` / `### Notes (Milestone N)` subsections from
  Milestones 2–6 into a single dated `## [0.1.0] — 2026-04-12`
  release section with standard Keep a Changelog subsection
  headings. Per-bullet "First delivered at Milestone N"
  attributions preserve the milestone narrative.
- `ROADMAP.md` marks Milestones 0–7 as completed with a
  status snapshot table, commit SHAs, and test counts, and
  defers the remaining work (M8 gRPCServer.jl reverse
  integration, plus post-M8 items like multi-request client
  sessions, affirmative server push, and macOS / Windows CI)
  to named future milestones.
- `upstream-bugs.md` entries for the OpenSSL.jl ALPN select
  callback binding and the Nghttp2Wrapper.jl `HTTP2Server`
  response body drop now carry specific GitHub issue URLs in
  their `Upstream link` fields (previously bare repository
  URLs).

### Notes

- **Constitution Principle III operationally fulfilled for
  both server and client roles**. Server role at Milestone 4
  (and deepened at Milestone 5); client role at Milestone 6.
  Every wire-observable protocol feature has at least one
  cross-test against `libnghttp2` via Nghttp2Wrapper.jl in
  `test/interop/`.
- **Constitution Principle I preserved**. `Project.toml`'s
  `[deps]` block is empty. The only optional dependency is
  OpenSSL via `[weakdeps]` + `[extensions]` for the TLS ALPN
  helper, which loads only when OpenSSL.jl is already in the
  environment and does not become a runtime dep of HTTP2.jl
  itself.
- **Deferred upstream at `v0.1.0`** — two items in
  `upstream-bugs.md` are open at release time:
  1. OpenSSL.jl does not bind `SSL_CTX_set_alpn_select_cb`,
     blocking server-side h2 TLS ALPN selection. HTTP2.jl's
     `set_alpn_h2!` helper is the client-side half of the
     ALPN story; server-side h2 TLS serving remains blocked.
  2. Nghttp2Wrapper.jl's `HTTP2Server` handler calls
     `nghttp2_submit_response2` with a `C_NULL` data
     provider, silently dropping response bodies. The
     `Interop: h2c live TCP client` cross-test asserts
     `isempty(result.body)` with a flip-to-equality TODO that
     fires once the upstream fix lands.
- **Deferred in HTTP2.jl itself at `v0.1.0`** — multi-request
  client sessions over one connection, affirmative server
  push handling, multi-frame request bodies, server-side h2
  TLS, macOS / Windows interop CI, stream priority beyond
  best-effort, extensible SETTINGS per RFC 7540 §6.5.2,
  performance benchmarking, fuzz harness, and allocation-free
  hot paths. See `ROADMAP.md` "Future / Post-M8" section for
  the triage list.
- **Provenance**: the M0 extraction from gRPCServer.jl commit
  `4abc09324736b3597da5502385dbce24a1edb174` is documented in
  the Provenance appendix at the bottom of this file,
  preserved verbatim from the original Milestone 0 entry.
- **First tagged release**: this is the first commit to carry
  a git tag on the main branch. Milestone 7 (release
  engineering) landed the consolidation, the README
  expansion, the docs deployment wiring, and the General
  registry submission. Subsequent releases follow standard
  SemVer + Keep a Changelog discipline per constitution
  Principle IV.

---

## Provenance

> This appendix is not part of the Keep-a-Changelog-formatted entries
> above; it is the provenance record for the initial lift-and-shift that
> created HTTP2.jl. It is kept here (rather than in a separate `NOTICE`
> file) so the record lives alongside the changelog entry it
> substantiates.

HTTP2.jl began as a lift-and-shift extraction of the `http2` submodule of
gRPCServer.jl. The production sources and their matching unit tests were
copied verbatim into this repository; the only modifications applied
during extraction were (a) rewriting the file-level header comment of
each source file to identify HTTP2.jl as its current home, and (b) in
test files only, rewriting `using gRPCServer` → `using HTTP2` and the
word-bounded identifier prefix `gRPCServer.` → `HTTP2.`. No other edits
were made. See `specs/001-extract-http2-module/research.md` (R3, R4, R8)
for the evidence supporting that this was a safe textual substitution.

### Upstream origin

- **Repository**: <https://github.com/s-celles/gRPCServer.jl>
- **Branch**: `develop`
- **Commit**: `4abc09324736b3597da5502385dbce24a1edb174`
- **Commit message**: `feat: add gRPCClient.jl integration tests`

### Extracted files

Production sources (5 files, copied to `src/`):

| Upstream path | Target path | LOC |
|---|---|---|
| `src/http2/frames.jl` | `src/frames.jl` | 547 |
| `src/http2/hpack.jl` | `src/hpack.jl` | 963 |
| `src/http2/stream.jl` | `src/stream.jl` | 462 |
| `src/http2/flow_control.jl` | `src/flow_control.jl` | 440 |
| `src/http2/connection.jl` | `src/connection.jl` | 717 |

Unit tests (5 files, copied to `test/`):

| Upstream path | Target path | LOC |
|---|---|---|
| `test/unit/test_hpack.jl` | `test/test_hpack.jl` | 378 |
| `test/unit/test_http2_stream.jl` | `test/test_http2_stream.jl` | 488 |
| `test/unit/test_http2_conformance.jl` | `test/test_http2_conformance.jl` | 427 |
| `test/unit/test_stream_state_validation.jl` | `test/test_stream_state_validation.jl` | 218 |
| `test/unit/test_connection_management.jl` | `test/test_connection_management.jl` | 244 |

Total: 10 files, ~4884 lines of code.

### License inheritance

gRPCServer.jl is distributed under the MIT License. HTTP2.jl is also
distributed under the MIT License, with copyright held by Sébastien
Celles (see the top-level `LICENSE` file). Because both the upstream
project and HTTP2.jl share the same author and the same license, the
extracted code retains its original copyright and license unchanged: no
re-licensing occurred and none was required.

Any contributor who subsequently modifies the extracted files in
HTTP2.jl does so under the MIT License in force in this repository
(see `./LICENSE`).

### Exclusions — files deliberately NOT extracted at Milestone 0

The following files exist in the upstream project alongside the ten
files above but were intentionally left behind. Each exclusion is
recorded here per spec FR-010 so future maintainers can tell the
difference between "forgotten" and "deliberately excluded".

- **`test/TestUtils.jl`** — gRPC integration harness that builds a raw
  TCP/HTTP2 mock client scoped to the upstream gRPC test suite. Not
  used by any of the five HTTP/2 unit test files extracted here. Not
  planned for re-extraction; if HTTP2.jl ever needs a test helper of
  its own it will be written from scratch under the constitution's TDD
  rule.
- **`test/fixtures/hpack-test-case/`** — HPACK conformance vectors
  (go-hpack, nghttp2, python-hpack, raw-data). Not referenced by
  `test_hpack.jl` as currently extracted — the upstream
  Huffman/integer/string tests are hand-rolled. Deferred to Milestone 2
  (Frames & HPACK), which will pull in the vector set as part of the
  HPACK conformance push.
  **→ Resolved at Milestone 2**: extracted into
  `test/fixtures/hpack-test-case/` and exercised by the four
  `HPACK conformance:` test items (23,688 conformance tests total).
- **`src/http2/*.cov`** — Julia code-coverage artifacts (e.g.
  `hpack.jl.1286406.cov`) left over from upstream test runs. Build
  outputs, not source. Excluded by allow-listed copy; will never be
  extracted.
- **`test/unit/test_streams.jl`** — gRPC-layer stream wrapper tests
  (`ServerStream`, `ClientStream`, `BidiStream`). Exercises
  abstractions built on top of the HTTP/2 state machine, not the state
  machine itself. The HTTP/2 state-machine coverage lives entirely in
  `test_http2_stream.jl` and `test_stream_state_validation.jl`, both of
  which were extracted.

### Verification

The extraction and its post-conditions are verified by the step-by-step
walkthrough in `specs/001-extract-http2-module/quickstart.md`. In
particular:

- `rg -n '\bgRPCServer\b' src/ test/` — MUST return zero matches
- `find src/ test/ -name '*.cov' -print` — MUST return zero lines
- `head -n 1 src/*.jl` — every first line MUST end with `HTTP2.jl`

These checks were run at extraction time and passed; re-running them
from a fresh clone will reproduce the same results.
