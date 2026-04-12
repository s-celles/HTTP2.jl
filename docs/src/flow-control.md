# Flow control

HTTP/2 defines two levels of flow control (RFC 9113 §5.2): the
connection-level window and a per-stream window. HTTP2.jl models
both as [`FlowControlWindow`](@ref HTTP2.FlowControlWindow)
instances. The [`FlowController`](@ref HTTP2.FlowController) ties
them together — it owns one connection window and a dictionary of
stream windows keyed by stream ID, and its operations correctly
decrement **both** windows when a stream sends or receives DATA.

Above that, [`DataSender`](@ref HTTP2.DataSender) and
[`DataReceiver`](@ref HTTP2.DataReceiver) layer frame-size limits
on top of the flow controller, splitting outgoing DATA into frames
no larger than the peer's `MAX_FRAME_SIZE`.

## Role signalling

Flow control is **role-neutral**. A `FlowControlWindow` is a
sliding window regardless of who created it, and the
`FlowController` distinguishes only connection-level from
stream-level — never server from client. The
[`apply_settings_initial_window_size!`](@ref
HTTP2.apply_settings_initial_window_size!) function responds to a
peer's SETTINGS frame the same way whether that frame came from a
server or a client.

Client-role code that sends DATA constructs the same `DataSender`
shape as server-role code; the roles diverge only in which side
originally advertises the initial window.

## Window

```@docs
HTTP2.FlowControlWindow
```

## Window operations

```@docs
HTTP2.consume!
HTTP2.try_consume!
HTTP2.release!
HTTP2.available
HTTP2.should_send_update
HTTP2.get_update_increment
HTTP2.update_initial_size!
```

## Multi-stream controller

```@docs
HTTP2.FlowController
```

## Controller operations

```@docs
HTTP2.create_stream_window!
HTTP2.get_stream_window
HTTP2.remove_stream_window!
HTTP2.consume_send!
HTTP2.max_sendable
HTTP2.apply_window_update!
HTTP2.apply_settings_initial_window_size!
HTTP2.generate_window_updates
```

## High-level senders and receivers

```@docs
HTTP2.DataSender
HTTP2.send_data_frames
HTTP2.DataReceiver
```
