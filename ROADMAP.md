# Roadmap

This document outlines the planned milestones for HTTP2.jl, a pure Julia
HTTP/2 implementation. The library is being extracted from the `http2`
module of
[gRPCServer.jl](https://github.com/s-celles/gRPCServer.jl/tree/develop/src/http2)
and validated against
[Nghttp2Wrapper.jl](https://github.com/s-celles/Nghttp2Wrapper.jl) (a thin
wrapper over the `libnghttp2` reference implementation).

Each milestone respects the
[constitution](.specify/memory/constitution.md): pure Julia only, TDD with
`TestItemRunner.jl`, SemVer + Keep a Changelog, warning-free Documenter
builds, and RFC-grounded cross-tests against Nghttp2Wrapper.jl.

---

## Milestone 0 — Source Extraction from gRPCServer.jl

**Status**: Not started
**Target version**: `0.0.1` (unreleased scaffold)

Lift the existing pure-Julia HTTP/2 implementation out of gRPCServer.jl
together with its tests, preserving git history and copyright.

**Source modules** (`~3100` LOC) in `gRPCServer/src/http2/`:

- [ ] `frames.jl` (~547 LOC) — frame types, wire format encode/decode
- [ ] `hpack.jl` (~963 LOC) — HPACK header compression (RFC 7541)
- [ ] `stream.jl` (~462 LOC) — stream state machine (RFC 9113 §5)
- [ ] `connection.jl` (~717 LOC) — connection lifecycle, SETTINGS, preface
- [ ] `flow_control.jl` (~440 LOC) — window update / flow control (RFC 9113 §5.2)

**Tests to carry over** from `gRPCServer/test/unit/`:

- [ ] `test_hpack.jl` (~378 LOC)
- [ ] `test_http2_stream.jl` (~488 LOC)
- [ ] `test_http2_conformance.jl` (~427 LOC)
- [ ] `test_stream_state_validation.jl` (~218 LOC)
- [ ] `test_connection_management.jl` (~244 LOC)
- [ ] Relevant slices of `test_streams.jl` and any http2-specific helpers in
      `TestUtils.jl`

**Tasks**:

- [ ] Copy sources into `src/` preserving per-file RFC citations (update
      header comments from "for gRPCServer.jl" to "for HTTP2.jl")
- [ ] Copy tests into `test/` and re-home any `GRPCServer.HTTP2` references
      to `HTTP2` module paths
- [ ] Record provenance and the originating gRPCServer.jl commit SHA in
      `NOTICE` (or file-level headers)
- [ ] Update `CHANGELOG.md` `Unreleased` with the initial import entry

**Exit criteria**: sources and tests are in-tree, files compile as a raw
module (tests may still fail), and provenance is recorded.

---

## Milestone 1 — Package Scaffolding & CI

**Status**: Not started
**Target version**: `0.0.1`

Stand up HTTP2.jl as a real Julia package so the extracted code can be
developed in isolation.

- [ ] `Project.toml` with `name = "HTTP2"`, UUID, `[compat]` entries, and
      minimum Julia version declared
- [ ] `src/HTTP2.jl` root module that `include`s the five extracted files
      in dependency order
- [ ] `test/runtests.jl` wired to `TestItemRunner.jl` (not `Test`-only)
- [ ] GitHub Actions workflow: Julia LTS + stable, ubuntu/macos/windows
- [ ] `Documenter.jl` skeleton under `docs/` with a landing page and API
      index — builds warning-free
- [ ] `CHANGELOG.md` seeded in Keep a Changelog format with an `Unreleased`
      section
- [ ] `upstream-bugs.md` seeded (empty) per project convention

**Exit criteria**: `] test` runs under TestItemRunner, CI is green on the
declared Julia versions, and `make -C docs` (or equivalent) produces a
warning-free build.

---

## Milestone 2 — Frames & HPACK, Converted to TestItemRunner

**Status**: Not started
**Target version**: `0.1.0-DEV`

Bring the two leaf modules — frames and HPACK — up to constitution standard
without touching higher layers.

- [ ] Refactor `test_hpack.jl` into `@testitem` units
- [ ] Refactor the frame-related slices of `test_http2_conformance.jl` into
      `@testitem` units grouped by frame type (DATA, HEADERS, PRIORITY,
      RST_STREAM, SETTINGS, PING, GOAWAY, WINDOW_UPDATE, CONTINUATION)
- [ ] Add doctests for public `encode_frame` / `decode_frame` / HPACK
      encoder-decoder round-trips
- [ ] Write `docs/src/frames.md` and `docs/src/hpack.md` pages
- [ ] HPACK conformance: run the
      [hpack-test-case](https://github.com/http2jp/hpack-test-case) vectors
      as a TestItemRunner group (read-only JSON fixtures, no C dep)

**Exit criteria**: frames and HPACK pass all migrated tests plus the
hpack-test-case vectors; public API for both is documented.

---

## Milestone 3 — Stream, Flow Control & Connection

**Status**: Not started
**Target version**: `0.1.0-DEV`

Bring the stateful layers up to the same standard as M2.

- [ ] Refactor `test_http2_stream.jl` and `test_stream_state_validation.jl`
      into `@testitem` units organised by state transition
- [ ] Refactor `test_connection_management.jl` into `@testitem` units
      covering the connection preface, SETTINGS exchange, GOAWAY, and
      graceful shutdown
- [ ] Add flow-control tests exercising window update edge cases (zero
      windows, overflow, stream vs connection window interactions)
- [ ] Write `docs/src/streams.md`, `docs/src/connection.md`,
      `docs/src/flow-control.md`
- [ ] Ensure the public API distinguishes **server** and **client**
      roles explicitly, even if client role is partial in this milestone

**Exit criteria**: all migrated gRPCServer.jl tests pass on HTTP2.jl
standalone; stateful layers documented.

---

## Milestone 4 — Reference Parity with Nghttp2Wrapper.jl

**Status**: Not started
**Target version**: `0.1.0-DEV`

Constitution Principle III requires cross-tests against `libnghttp2` via
Nghttp2Wrapper.jl. This milestone builds that harness.

- [ ] Add Nghttp2Wrapper.jl as a `test`-scoped dependency
- [ ] Create `test/interop/` with a TestItemRunner group `@testitem
      "nghttp2-parity"`
- [ ] Cross-test matrix (minimum set required by the constitution):
  - [ ] Connection preface byte-for-byte
  - [ ] SETTINGS frame round-trip and ACK semantics
  - [ ] HEADERS encode by HTTP2.jl, decode by nghttp2 (and vice versa) for
        the hpack-test-case vector set
  - [ ] DATA frame with padding / END_STREAM variations
  - [ ] Flow control: WINDOW_UPDATE handshake, initial window change
  - [ ] RST_STREAM error code propagation
  - [ ] GOAWAY with last-stream-id
  - [ ] PING / PONG with opaque data
- [ ] Document any deliberate divergences (still RFC-compliant) in
      `docs/src/nghttp2-parity.md` with RFC 9113 section citations
- [ ] Any nghttp2 or Nghttp2Wrapper.jl bugs surfaced along the way go into
      `upstream-bugs.md`

**Exit criteria**: the interop test group is green in CI on at least Linux;
`docs/src/nghttp2-parity.md` lists every cross-test and its RFC anchor.

---

## Milestone 5 — TLS & ALPN Integration

**Status**: Not started
**Target version**: `0.1.0-DEV`

HTTP/2 over TCP (`h2c`) works without TLS, but real-world HTTP/2 needs
ALPN-negotiated `h2`. The constitution permits `MbedTLS`/`OpenSSL` for TLS
only; protocol logic stays pure Julia.

- [ ] Define the minimal TLS adapter interface (`IO`-like) that HTTP2.jl
      consumes, so TLS is injectable and mockable
- [ ] Provide an `OpenSSL.jl`-backed ALPN helper as an optional weak
      dependency (`Base.get_extension`) — not a hard dep
- [ ] Reference-test `h2` end-to-end against Nghttp2Wrapper.jl with ALPN
      negotiation (client ↔ server round-trip)
- [ ] Document `h2c` vs `h2` deployment in `docs/src/tls.md`
- [ ] If OpenSSL.jl lacks any binding HTTP2.jl needs (e.g. ALPN callback
      surface), file an entry in `upstream-bugs.md` and open an upstream
      issue — no `ccall` workarounds per Principle I

**Exit criteria**: ALPN-negotiated `h2` handshake interops with nghttp2 in
both directions.

---

## Milestone 6 — Client Role Completion

**Status**: Not started
**Target version**: `0.2.0-DEV`

gRPCServer.jl only exercised the server half of the state machine. Round
out the client half so HTTP2.jl is symmetric.

- [ ] Audit each state transition for client-role coverage gaps
- [ ] Add client-role `@testitem` units mirroring the server tests
- [ ] Cross-test HTTP2.jl client ↔ nghttp2 server via Nghttp2Wrapper.jl
- [ ] Document client usage in `docs/src/client.md`

**Exit criteria**: HTTP2.jl can drive a request/response exchange as a
client against nghttp2 without divergence.

---

## Milestone 7 — First Tagged Release `v0.1.0`

**Status**: Not started
**Target version**: `0.1.0`

- [ ] `CHANGELOG.md` `Unreleased` → `0.1.0` section finalised
- [ ] `Project.toml` bumped; git tag `v0.1.0`
- [ ] Documenter docs deployed (gh-pages) warning-free
- [ ] README.md expanded beyond the current stub: scope, install, minimal
      example, link to nghttp2 parity status
- [ ] Registration in Julia's General registry

**Exit criteria**: `Pkg.add("HTTP2")` installs and runs the quickstart.

---

## Milestone 8 — gRPCServer.jl Reverse Integration

**Status**: Not started
**Target version**: `0.2.0`

Close the loop: make gRPCServer.jl consume HTTP2.jl as a dependency
instead of vendoring its own copy. This is the acceptance test for the
whole extraction.

- [ ] Replace `gRPCServer/src/http2/**` with an `import HTTP2` and delete
      the vendored modules
- [ ] Run gRPCServer.jl's full unit + integration + interop test suites
      against HTTP2.jl
- [ ] File any regressions discovered as issues on HTTP2.jl (not
      gRPCServer.jl); fix them here and release a patch if needed
- [ ] Cut HTTP2.jl `0.2.0` once gRPCServer.jl is fully swapped over

**Exit criteria**: gRPCServer.jl's CI is green against HTTP2.jl ≥ `0.2.0`
with its HTTP/2 sources removed.

---

## Future / Post-`0.2.0`

Not scheduled — to be triaged after M8 lands:

- Stream priority (RFC 9113 §5.3) beyond best-effort
- HTTP/2 server push (currently rejected per ENABLE_PUSH = 0; consider if
  any consumer actually wants it)
- Extensible SETTINGS per RFC 7540 §6.5.2
- Performance benchmarking harness (`benchmark/`) with a baseline vs
  nghttp2 throughput comparison
- Fuzz harness for the frame decoder (pure-Julia, e.g. `Supposition.jl`)
- Allocation-free hot paths for DATA frame forwarding
