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
