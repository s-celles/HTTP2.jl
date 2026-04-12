@testitem "Stream: state enum" begin
    using HTTP2
    @test HTTP2.StreamState.IDLE isa HTTP2.StreamState.T
    @test HTTP2.StreamState.OPEN isa HTTP2.StreamState.T
    @test HTTP2.StreamState.HALF_CLOSED_LOCAL isa HTTP2.StreamState.T
    @test HTTP2.StreamState.HALF_CLOSED_REMOTE isa HTTP2.StreamState.T
    @test HTTP2.StreamState.CLOSED isa HTTP2.StreamState.T
    @test HTTP2.StreamState.RESERVED_LOCAL isa HTTP2.StreamState.T
    @test HTTP2.StreamState.RESERVED_REMOTE isa HTTP2.StreamState.T
end

@testitem "Stream: error type" begin
    using HTTP2
    err = HTTP2.StreamError(UInt32(1), UInt32(2), "Test error")
    @test err isa Exception
    @test err.stream_id == 1
    @test err.error_code == 2
    @test err.message == "Test error"

    io = IOBuffer()
    showerror(io, err)
    output = String(take!(io))
    @test occursin("StreamError", output)
    @test occursin("stream=1", output)
    @test occursin("code=2", output)
    @test occursin("Test error", output)
end

@testitem "Stream: construction" begin
    using HTTP2
    stream = HTTP2.HTTP2Stream(1)
    @test stream.id == 1
    @test stream.state == HTTP2.StreamState.IDLE
    @test stream.send_window == HTTP2.DEFAULT_INITIAL_WINDOW_SIZE
    @test stream.recv_window == HTTP2.DEFAULT_INITIAL_WINDOW_SIZE
    @test isempty(stream.request_headers)
    @test isempty(stream.response_headers)
    @test isempty(stream.trailers)
    @test !stream.headers_complete
    @test !stream.end_stream_received
    @test !stream.end_stream_sent
    @test !stream.reset

    stream2 = HTTP2.HTTP2Stream(3, 1000)
    @test stream2.send_window == 1000
    @test stream2.recv_window == 1000
end

@testitem "Stream: id classification" begin
    using HTTP2
    # Client-initiated streams are odd
    @test HTTP2.is_client_initiated(1) == true
    @test HTTP2.is_client_initiated(3) == true
    @test HTTP2.is_client_initiated(101) == true
    @test HTTP2.is_client_initiated(2) == false
    @test HTTP2.is_client_initiated(0) == false

    # Server-initiated streams are even (and > 0)
    @test HTTP2.is_server_initiated(2) == true
    @test HTTP2.is_server_initiated(4) == true
    @test HTTP2.is_server_initiated(100) == true
    @test HTTP2.is_server_initiated(1) == false
    @test HTTP2.is_server_initiated(0) == false
end

@testitem "Stream: direction predicates" begin
    using HTTP2
    stream = HTTP2.HTTP2Stream(1)

    # IDLE state - cannot send or receive
    @test HTTP2.can_send(stream) == false
    @test HTTP2.can_receive(stream) == false

    # Transition to OPEN
    HTTP2.receive_headers!(stream, false)
    @test stream.state == HTTP2.StreamState.OPEN
    @test HTTP2.can_send(stream) == true
    @test HTTP2.can_receive(stream) == true

    # Transition to HALF_CLOSED_REMOTE
    stream2 = HTTP2.HTTP2Stream(3)
    HTTP2.receive_headers!(stream2, true)
    @test stream2.state == HTTP2.StreamState.HALF_CLOSED_REMOTE
    @test HTTP2.can_send(stream2) == true
    @test HTTP2.can_receive(stream2) == false

    # Transition to HALF_CLOSED_LOCAL
    stream3 = HTTP2.HTTP2Stream(5)
    HTTP2.receive_headers!(stream3, false)
    HTTP2.send_headers!(stream3, true)
    @test stream3.state == HTTP2.StreamState.HALF_CLOSED_LOCAL
    @test HTTP2.can_send(stream3) == false
    @test HTTP2.can_receive(stream3) == true
end

@testitem "Stream: is_closed" begin
    using HTTP2
    stream = HTTP2.HTTP2Stream(1)
    @test HTTP2.is_closed(stream) == false

    # Close via state transition
    HTTP2.receive_headers!(stream, true)
    HTTP2.send_headers!(stream, true)
    @test stream.state == HTTP2.StreamState.CLOSED
    @test HTTP2.is_closed(stream) == true

    # Close via reset
    stream2 = HTTP2.HTTP2Stream(3)
    HTTP2.receive_rst_stream!(stream2, UInt32(0))
    @test HTTP2.is_closed(stream2) == true
end

@testitem "Stream: receive_headers transitions" begin
    using HTTP2
    # IDLE -> OPEN (no end_stream)
    stream1 = HTTP2.HTTP2Stream(1)
    HTTP2.receive_headers!(stream1, false)
    @test stream1.state == HTTP2.StreamState.OPEN
    @test stream1.end_stream_received == false

    # IDLE -> HALF_CLOSED_REMOTE (with end_stream)
    stream2 = HTTP2.HTTP2Stream(3)
    HTTP2.receive_headers!(stream2, true)
    @test stream2.state == HTTP2.StreamState.HALF_CLOSED_REMOTE
    @test stream2.end_stream_received == true

    # OPEN -> HALF_CLOSED_REMOTE (trailers with end_stream)
    stream3 = HTTP2.HTTP2Stream(5)
    HTTP2.receive_headers!(stream3, false)
    HTTP2.receive_headers!(stream3, true)
    @test stream3.state == HTTP2.StreamState.HALF_CLOSED_REMOTE

    # HALF_CLOSED_LOCAL -> CLOSED (trailers with end_stream)
    stream4 = HTTP2.HTTP2Stream(7)
    HTTP2.receive_headers!(stream4, false)
    HTTP2.send_headers!(stream4, true)
    @test stream4.state == HTTP2.StreamState.HALF_CLOSED_LOCAL
    HTTP2.receive_headers!(stream4, true)
    @test stream4.state == HTTP2.StreamState.CLOSED

    # RESERVED_REMOTE -> HALF_CLOSED_LOCAL (no end_stream)
    stream5 = HTTP2.HTTP2Stream(9)
    stream5.state = HTTP2.StreamState.RESERVED_REMOTE
    HTTP2.receive_headers!(stream5, false)
    @test stream5.state == HTTP2.StreamState.HALF_CLOSED_LOCAL

    # RESERVED_REMOTE -> CLOSED (with end_stream)
    stream6 = HTTP2.HTTP2Stream(11)
    stream6.state = HTTP2.StreamState.RESERVED_REMOTE
    HTTP2.receive_headers!(stream6, true)
    @test stream6.state == HTTP2.StreamState.CLOSED

    # Invalid state should throw
    stream_closed = HTTP2.HTTP2Stream(13)
    stream_closed.state = HTTP2.StreamState.CLOSED
    @test_throws HTTP2.StreamError HTTP2.receive_headers!(stream_closed, false)
end

@testitem "Stream: send_headers transitions" begin
    using HTTP2
    # IDLE -> OPEN (no end_stream)
    stream1 = HTTP2.HTTP2Stream(1)
    HTTP2.send_headers!(stream1, false)
    @test stream1.state == HTTP2.StreamState.OPEN
    @test stream1.end_stream_sent == false

    # IDLE -> HALF_CLOSED_LOCAL (with end_stream)
    stream2 = HTTP2.HTTP2Stream(3)
    HTTP2.send_headers!(stream2, true)
    @test stream2.state == HTTP2.StreamState.HALF_CLOSED_LOCAL
    @test stream2.end_stream_sent == true

    # OPEN -> HALF_CLOSED_LOCAL (response with end_stream)
    stream3 = HTTP2.HTTP2Stream(5)
    HTTP2.receive_headers!(stream3, false)
    HTTP2.send_headers!(stream3, true)
    @test stream3.state == HTTP2.StreamState.HALF_CLOSED_LOCAL

    # HALF_CLOSED_REMOTE -> CLOSED (response with end_stream)
    stream4 = HTTP2.HTTP2Stream(7)
    HTTP2.receive_headers!(stream4, true)
    @test stream4.state == HTTP2.StreamState.HALF_CLOSED_REMOTE
    HTTP2.send_headers!(stream4, true)
    @test stream4.state == HTTP2.StreamState.CLOSED

    # RESERVED_LOCAL -> HALF_CLOSED_REMOTE (no end_stream)
    stream5 = HTTP2.HTTP2Stream(9)
    stream5.state = HTTP2.StreamState.RESERVED_LOCAL
    HTTP2.send_headers!(stream5, false)
    @test stream5.state == HTTP2.StreamState.HALF_CLOSED_REMOTE

    # RESERVED_LOCAL -> CLOSED (with end_stream)
    stream6 = HTTP2.HTTP2Stream(11)
    stream6.state = HTTP2.StreamState.RESERVED_LOCAL
    HTTP2.send_headers!(stream6, true)
    @test stream6.state == HTTP2.StreamState.CLOSED

    # Invalid state should throw
    stream_closed = HTTP2.HTTP2Stream(13)
    stream_closed.state = HTTP2.StreamState.CLOSED
    @test_throws HTTP2.StreamError HTTP2.send_headers!(stream_closed, false)
end

@testitem "Stream: receive_data" begin
    using HTTP2

    @testset "receive_data! happy path" begin
        stream = HTTP2.HTTP2Stream(1)
        HTTP2.receive_headers!(stream, false)
        @test stream.state == HTTP2.StreamState.OPEN

        data1 = UInt8[1, 2, 3, 4, 5]
        initial_window = stream.recv_window
        HTTP2.receive_data!(stream, data1, false)
        @test stream.recv_window == initial_window - length(data1)
        @test stream.state == HTTP2.StreamState.OPEN
        @test stream.end_stream_received == false

        data2 = UInt8[6, 7, 8]
        HTTP2.receive_data!(stream, data2, true)
        @test stream.state == HTTP2.StreamState.HALF_CLOSED_REMOTE
        @test stream.end_stream_received == true

        all_data = HTTP2.get_data(stream)
        @test all_data == UInt8[1, 2, 3, 4, 5, 6, 7, 8]
    end

    @testset "receive_data! Flow Control Error" begin
        stream = HTTP2.HTTP2Stream(1, 10)
        HTTP2.receive_headers!(stream, false)
        large_data = UInt8[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
        @test_throws HTTP2.StreamError HTTP2.receive_data!(stream, large_data, false)
    end

    @testset "receive_data! Invalid State" begin
        stream = HTTP2.HTTP2Stream(1)
        @test_throws HTTP2.StreamError HTTP2.receive_data!(stream, UInt8[1], false)

        stream2 = HTTP2.HTTP2Stream(3)
        HTTP2.receive_headers!(stream2, true)
        @test_throws HTTP2.StreamError HTTP2.receive_data!(stream2, UInt8[1], false)
    end

    @testset "receive_data! HALF_CLOSED_LOCAL -> CLOSED" begin
        stream = HTTP2.HTTP2Stream(1)
        HTTP2.receive_headers!(stream, false)
        HTTP2.send_headers!(stream, true)
        @test stream.state == HTTP2.StreamState.HALF_CLOSED_LOCAL

        HTTP2.receive_data!(stream, UInt8[1, 2, 3], true)
        @test stream.state == HTTP2.StreamState.CLOSED
    end
end

@testitem "Stream: send_data" begin
    using HTTP2

    @testset "send_data! happy path" begin
        stream = HTTP2.HTTP2Stream(1)
        HTTP2.receive_headers!(stream, false)
        @test stream.state == HTTP2.StreamState.OPEN

        initial_window = stream.send_window
        HTTP2.send_data!(stream, 100, false)
        @test stream.send_window == initial_window - 100
        @test stream.state == HTTP2.StreamState.OPEN
        @test stream.end_stream_sent == false

        HTTP2.send_data!(stream, 50, true)
        @test stream.state == HTTP2.StreamState.HALF_CLOSED_LOCAL
        @test stream.end_stream_sent == true
    end

    @testset "send_data! Flow Control Error" begin
        stream = HTTP2.HTTP2Stream(1, 10)
        HTTP2.receive_headers!(stream, false)
        @test_throws HTTP2.StreamError HTTP2.send_data!(stream, 11, false)
    end

    @testset "send_data! Invalid State" begin
        stream = HTTP2.HTTP2Stream(1)
        @test_throws HTTP2.StreamError HTTP2.send_data!(stream, 10, false)

        stream2 = HTTP2.HTTP2Stream(3)
        HTTP2.send_headers!(stream2, true)
        @test_throws HTTP2.StreamError HTTP2.send_data!(stream2, 10, false)
    end

    @testset "send_data! HALF_CLOSED_REMOTE -> CLOSED" begin
        stream = HTTP2.HTTP2Stream(1)
        HTTP2.receive_headers!(stream, true)
        @test stream.state == HTTP2.StreamState.HALF_CLOSED_REMOTE

        HTTP2.send_data!(stream, 100, true)
        @test stream.state == HTTP2.StreamState.CLOSED
    end
end

@testitem "Stream: RST_STREAM" begin
    using HTTP2
    # receive_rst_stream!
    stream1 = HTTP2.HTTP2Stream(1)
    HTTP2.receive_headers!(stream1, false)
    HTTP2.receive_rst_stream!(stream1, UInt32(8))  # CANCEL
    @test stream1.state == HTTP2.StreamState.CLOSED
    @test stream1.reset == true

    # send_rst_stream!
    stream2 = HTTP2.HTTP2Stream(3)
    HTTP2.receive_headers!(stream2, false)
    HTTP2.send_rst_stream!(stream2, UInt32(2))  # INTERNAL_ERROR
    @test stream2.state == HTTP2.StreamState.CLOSED
    @test stream2.reset == true
end

@testitem "Stream: window updates" begin
    using HTTP2
    stream = HTTP2.HTTP2Stream(1, 1000)

    # Update send window
    HTTP2.update_send_window!(stream, 500)
    @test stream.send_window == 1500

    # Update recv window
    HTTP2.update_recv_window!(stream, 300)
    @test stream.recv_window == 1300

    # Overflow should throw
    stream2 = HTTP2.HTTP2Stream(3, 2147483600)
    @test_throws HTTP2.StreamError HTTP2.update_send_window!(stream2, 100)
    @test_throws HTTP2.StreamError HTTP2.update_recv_window!(stream2, 100)
end

@testitem "Stream: data buffer" begin
    using HTTP2
    stream = HTTP2.HTTP2Stream(1)
    HTTP2.receive_headers!(stream, false)

    HTTP2.receive_data!(stream, UInt8[1, 2, 3], false)
    HTTP2.receive_data!(stream, UInt8[4, 5], false)

    # peek_data should not consume
    peeked = HTTP2.peek_data(stream)
    @test peeked == UInt8[1, 2, 3, 4, 5]

    # Can peek again
    peeked2 = HTTP2.peek_data(stream)
    @test peeked2 == UInt8[1, 2, 3, 4, 5]

    # get_data consumes the buffer
    data = HTTP2.get_data(stream)
    @test data == UInt8[1, 2, 3, 4, 5]

    # Buffer is now empty
    @test HTTP2.get_data(stream) == UInt8[]
end

@testitem "Stream: HTTP header accessors" begin
    using HTTP2
    stream = HTTP2.HTTP2Stream(1)
    stream.request_headers = [
        (":method", "POST"),
        (":path", "/helloworld.Greeter/SayHello"),
        (":authority", "localhost:50051"),
        ("content-type", "application/grpc"),
        ("grpc-encoding", "gzip"),
        ("grpc-accept-encoding", "gzip,identity"),
        ("grpc-timeout", "10S"),
        ("x-custom-header", "value1"),
        ("X-Custom-Header", "value2"),
        ("te", "trailers"),
    ]

    # get_header (case-insensitive)
    @test HTTP2.get_header(stream, ":method") == "POST"
    @test HTTP2.get_header(stream, ":METHOD") == "POST"
    @test HTTP2.get_header(stream, "Content-Type") == "application/grpc"
    @test HTTP2.get_header(stream, "nonexistent") === nothing

    # get_headers (multiple values)
    custom_values = HTTP2.get_headers(stream, "x-custom-header")
    @test length(custom_values) == 2
    @test "value1" in custom_values
    @test "value2" in custom_values

    # Empty result for nonexistent header
    @test HTTP2.get_headers(stream, "nonexistent") == String[]
end

@testitem "Stream: gRPC header helpers" begin
    using HTTP2
    stream = HTTP2.HTTP2Stream(1)
    stream.request_headers = [
        (":method", "POST"),
        (":path", "/helloworld.Greeter/SayHello"),
        (":authority", "localhost:50051"),
        ("content-type", "application/grpc+proto"),
        ("grpc-encoding", "gzip"),
        ("grpc-accept-encoding", "gzip,identity"),
        ("grpc-timeout", "10S"),
    ]

    @test HTTP2.get_method(stream) == "POST"
    @test HTTP2.get_path(stream) == "/helloworld.Greeter/SayHello"
    @test HTTP2.get_authority(stream) == "localhost:50051"
    @test HTTP2.get_content_type(stream) == "application/grpc+proto"
    @test HTTP2.get_grpc_encoding(stream) == "gzip"
    @test HTTP2.get_grpc_accept_encoding(stream) == "gzip,identity"
    @test HTTP2.get_grpc_timeout(stream) == "10S"
end

@testitem "Stream: metadata" begin
    using HTTP2
    stream = HTTP2.HTTP2Stream(1)
    stream.request_headers = [
        (":method", "POST"),
        (":path", "/test"),
        ("content-type", "application/grpc"),
        ("te", "trailers"),
        ("grpc-encoding", "identity"),
        ("grpc-accept-encoding", "gzip"),
        ("grpc-timeout", "5S"),
        ("grpc-status", "0"),
        ("grpc-message", "OK"),
        ("x-request-id", "12345"),
        ("authorization", "Bearer token"),
        ("x-custom-bin", "binary-data"),
    ]

    metadata = HTTP2.get_metadata(stream)

    # Should only include custom metadata
    @test length(metadata) == 3
    metadata_dict = Dict(metadata)
    @test haskey(metadata_dict, "x-request-id")
    @test metadata_dict["x-request-id"] == "12345"
    @test haskey(metadata_dict, "authorization")
    @test haskey(metadata_dict, "x-custom-bin")

    # Should NOT include pseudo-headers or reserved headers
    @test !haskey(metadata_dict, ":method")
    @test !haskey(metadata_dict, "content-type")
    @test !haskey(metadata_dict, "te")
    @test !haskey(metadata_dict, "grpc-encoding")
end

@testitem "Stream: show" begin
    using HTTP2
    stream = HTTP2.HTTP2Stream(1)
    str = sprint(show, stream)
    @test occursin("HTTP2Stream", str)
    @test occursin("id=1", str)
    @test occursin("state=IDLE", str)
    @test occursin("send_window=", str)
    @test occursin("recv_window=", str)

    # With RESET flag
    stream2 = HTTP2.HTTP2Stream(3)
    stream2.reset = true
    str2 = sprint(show, stream2)
    @test occursin("RESET", str2)
end

@testitem "Stream: reset behaviour" begin
    using HTTP2
    stream = HTTP2.HTTP2Stream(1)
    HTTP2.receive_headers!(stream, false)
    stream.reset = true

    # Reset stream cannot send or receive
    @test HTTP2.can_send(stream) == false
    @test HTTP2.can_receive(stream) == false
    @test HTTP2.is_closed(stream) == true
end

@testitem "Stream: END_STREAM flag" begin
    using HTTP2
    stream = HTTP2.HTTP2Stream(1)
    HTTP2.receive_headers!(stream, false)

    # Set end_stream_sent manually
    stream.end_stream_sent = true
    @test HTTP2.can_send(stream) == false

    # Reset and test end_stream_received
    stream2 = HTTP2.HTTP2Stream(3)
    HTTP2.receive_headers!(stream2, false)
    stream2.end_stream_received = true
    @test HTTP2.can_receive(stream2) == false
end

@testitem "Stream: state machine invariants" begin
    using HTTP2

    @testset "Stream states per RFC 7540 Section 5.1" begin
        @test HTTP2.StreamState.IDLE isa HTTP2.StreamState.T
        @test HTTP2.StreamState.OPEN isa HTTP2.StreamState.T
        @test HTTP2.StreamState.HALF_CLOSED_LOCAL isa HTTP2.StreamState.T
        @test HTTP2.StreamState.HALF_CLOSED_REMOTE isa HTTP2.StreamState.T
        @test HTTP2.StreamState.CLOSED isa HTTP2.StreamState.T
    end

    @testset "Stream transitions: IDLE -> OPEN on HEADERS" begin
        stream = HTTP2.HTTP2Stream(UInt32(1))
        @test stream.state == HTTP2.StreamState.IDLE

        HTTP2.receive_headers!(stream, false)  # Not END_STREAM
        @test stream.state == HTTP2.StreamState.OPEN
    end

    @testset "Stream transitions: IDLE -> HALF_CLOSED_REMOTE on HEADERS with END_STREAM" begin
        stream = HTTP2.HTTP2Stream(UInt32(1))
        @test stream.state == HTTP2.StreamState.IDLE

        HTTP2.receive_headers!(stream, true)  # END_STREAM
        @test stream.state == HTTP2.StreamState.HALF_CLOSED_REMOTE
        @test stream.end_stream_received
    end

    @testset "Stream transitions: OPEN -> HALF_CLOSED_LOCAL on send END_STREAM" begin
        stream = HTTP2.HTTP2Stream(UInt32(1))
        stream.state = HTTP2.StreamState.OPEN

        HTTP2.send_headers!(stream, true)  # END_STREAM
        @test stream.state == HTTP2.StreamState.HALF_CLOSED_LOCAL
        @test stream.end_stream_sent
    end

    @testset "Client vs server initiated streams" begin
        @test HTTP2.is_client_initiated(1)
        @test HTTP2.is_client_initiated(3)
        @test HTTP2.is_client_initiated(5)
        @test !HTTP2.is_client_initiated(2)
        @test !HTTP2.is_client_initiated(4)

        @test HTTP2.is_server_initiated(2)
        @test HTTP2.is_server_initiated(4)
        @test !HTTP2.is_server_initiated(1)
        @test !HTTP2.is_server_initiated(0)
    end
end

@testitem "Stream: state validation (Issue #6 fixes)" begin
    using HTTP2

    @testset "can_send function behavior" begin
        # Test that can_send returns true for OPEN state
        stream = HTTP2.HTTP2Stream(1)
        HTTP2.receive_headers!(stream, false)
        @test stream.state == HTTP2.StreamState.OPEN
        @test HTTP2.can_send(stream) == true

        # Test that can_send returns true for HALF_CLOSED_REMOTE state
        stream2 = HTTP2.HTTP2Stream(3)
        HTTP2.receive_headers!(stream2, true)
        @test stream2.state == HTTP2.StreamState.HALF_CLOSED_REMOTE
        @test HTTP2.can_send(stream2) == true

        # Test that can_send returns false for CLOSED state
        stream3 = HTTP2.HTTP2Stream(5)
        HTTP2.receive_headers!(stream3, true)
        HTTP2.send_headers!(stream3, true)
        @test stream3.state == HTTP2.StreamState.CLOSED
        @test HTTP2.can_send(stream3) == false

        # Test that can_send returns false for reset stream
        stream4 = HTTP2.HTTP2Stream(7)
        HTTP2.receive_headers!(stream4, false)
        HTTP2.receive_rst_stream!(stream4, UInt32(8))  # CANCEL
        @test HTTP2.can_send(stream4) == false

        # Test that can_send returns false for IDLE state
        stream5 = HTTP2.HTTP2Stream(9)
        @test stream5.state == HTTP2.StreamState.IDLE
        @test HTTP2.can_send(stream5) == false

        # Test that can_send returns false after end_stream_sent
        stream6 = HTTP2.HTTP2Stream(11)
        HTTP2.receive_headers!(stream6, false)
        stream6.end_stream_sent = true
        @test HTTP2.can_send(stream6) == false
    end

    @testset "can_send_on_stream helper function" begin
        # Create a connection with a stream
        conn = HTTP2.HTTP2Connection()
        conn.state = HTTP2.ConnectionState.OPEN

        # Test with non-existent stream
        @test HTTP2.can_send_on_stream(conn, UInt32(999)) == false

        # Create a stream in OPEN state
        stream = HTTP2.create_stream(conn, UInt32(1))
        HTTP2.receive_headers!(stream, false)
        @test HTTP2.can_send_on_stream(conn, UInt32(1)) == true

        # Create a stream in HALF_CLOSED_REMOTE state (typical for unary RPC)
        stream2 = HTTP2.create_stream(conn, UInt32(3))
        HTTP2.receive_headers!(stream2, true)
        @test HTTP2.can_send_on_stream(conn, UInt32(3)) == true

        # Create a stream and close it
        stream3 = HTTP2.create_stream(conn, UInt32(5))
        HTTP2.receive_headers!(stream3, true)
        HTTP2.send_headers!(stream3, true)
        @test HTTP2.can_send_on_stream(conn, UInt32(5)) == false
    end

    @testset "StreamError export" begin
        err = HTTP2.StreamError(UInt32(1), UInt32(2), "Test error")
        @test err isa Exception
        @test err.stream_id == 1
        @test err.error_code == 2
        @test err.message == "Test error"
    end

    @testset "RST_STREAM marks stream as not sendable" begin
        stream = HTTP2.HTTP2Stream(1)
        HTTP2.receive_headers!(stream, false)
        @test HTTP2.can_send(stream) == true

        HTTP2.receive_rst_stream!(stream, UInt32(8))  # CANCEL

        @test HTTP2.can_send(stream) == false
        @test stream.reset == true
        @test stream.state == HTTP2.StreamState.CLOSED
    end

    @testset "Stream state after receiving END_STREAM with DATA" begin
        stream = HTTP2.HTTP2Stream(1)

        HTTP2.receive_headers!(stream, false)
        @test stream.state == HTTP2.StreamState.OPEN
        @test HTTP2.can_send(stream) == true

        HTTP2.receive_data!(stream, UInt8[1, 2, 3, 4, 5], true)
        @test stream.state == HTTP2.StreamState.HALF_CLOSED_REMOTE
        @test HTTP2.can_send(stream) == true

        HTTP2.send_headers!(stream, false)
        @test stream.state == HTTP2.StreamState.HALF_CLOSED_REMOTE
        @test HTTP2.can_send(stream) == true

        HTTP2.send_headers!(stream, true)
        @test stream.state == HTTP2.StreamState.CLOSED
        @test HTTP2.can_send(stream) == false
    end
end
