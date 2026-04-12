# Connection

The connection layer owns an HTTP/2 connection's lifecycle: the
preface handshake, SETTINGS exchange, GOAWAY, and dispatch of
incoming frames to the appropriate state-machine handlers. An
[`HTTP2Connection`](@ref HTTP2.HTTP2Connection) holds the local
and remote [`ConnectionSettings`](@ref HTTP2.ConnectionSettings),
the set of active streams, the HPACK encoder/decoder pair, the
[`FlowController`](@ref HTTP2.FlowController), and the current
[`ConnectionState`](@ref HTTP2.ConnectionState).

## Role signalling

The connection layer is **currently server-role only**. Specifically:

- [`process_preface`](@ref HTTP2.process_preface) processes the
  **client** connection preface received over the wire from a
  client — i.e., the server side of the handshake.
- The `process_*_frame!` family is exercised exclusively by
  server-side code paths in the current test suite.
- The outbound `send_*` APIs ([`send_headers`](@ref
  HTTP2.send_headers), [`send_data`](@ref HTTP2.send_data),
  [`send_goaway`](@ref HTTP2.send_goaway), etc.) are role-neutral
  in their signatures, but the documented exercised paths build
  them in server-role contexts.

**Milestone 6** adds client-role connection setup — sending the
preface, processing the server's SETTINGS, and verifying the
outbound `send_*` APIs work from a client context.

## State enum

```@docs
HTTP2.ConnectionState
```

## Error type

```@docs
HTTP2.ConnectionError
```

## Connection and settings

```@docs
HTTP2.HTTP2Connection
HTTP2.ConnectionSettings
HTTP2.apply_settings!
HTTP2.to_frame
```

## Stream lifecycle

```@docs
HTTP2.get_stream
HTTP2.can_send_on_stream
HTTP2.create_stream
HTTP2.remove_stream
HTTP2.active_stream_count
```

## Preface (server role)

```@docs
HTTP2.process_preface
```

## Frame processing (server role)

```@docs
HTTP2.process_frame
HTTP2.process_settings_frame!
HTTP2.process_ping_frame!
HTTP2.process_goaway_frame!
HTTP2.process_window_update_frame!
HTTP2.process_headers_frame!
HTTP2.process_continuation_frame!
HTTP2.process_data_frame!
HTTP2.process_rst_stream_frame!
```

## Outbound APIs

```@docs
HTTP2.send_headers
HTTP2.send_data
HTTP2.send_trailers
HTTP2.send_rst_stream
HTTP2.send_goaway
```

## State predicates

```@docs
HTTP2.is_open
```

`is_closed` is also defined for `HTTP2Connection` and shares its
name with the stream-layer method — see [Streams](@ref) for the
shared export.
