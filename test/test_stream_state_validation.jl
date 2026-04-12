# Unit tests for stream state validation in gRPC responses
# These tests verify the fix for GitHub Issue #6

using Test
using HTTP2

@testset "Stream State Validation Tests" begin
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
        # Verify StreamError is accessible and can be constructed
        err = HTTP2.StreamError(UInt32(1), UInt32(2), "Test error")
        @test err isa Exception
        @test err.stream_id == 1
        @test err.error_code == 2
        @test err.message == "Test error"
    end

    @testset "RST_STREAM marks stream as not sendable" begin
        # When client sends RST_STREAM, stream should no longer be sendable
        stream = HTTP2.HTTP2Stream(1)
        HTTP2.receive_headers!(stream, false)
        @test HTTP2.can_send(stream) == true

        # Receive RST_STREAM from client
        HTTP2.receive_rst_stream!(stream, UInt32(8))  # CANCEL

        # Stream should now be not sendable
        @test HTTP2.can_send(stream) == false
        @test stream.reset == true
        @test stream.state == HTTP2.StreamState.CLOSED
    end

    @testset "Stream state after receiving END_STREAM with DATA" begin
        # Simulate a unary RPC where client sends request with END_STREAM
        stream = HTTP2.HTTP2Stream(1)

        # Client sends HEADERS (no END_STREAM yet)
        HTTP2.receive_headers!(stream, false)
        @test stream.state == HTTP2.StreamState.OPEN
        @test HTTP2.can_send(stream) == true

        # Client sends DATA with END_STREAM
        HTTP2.receive_data!(stream, UInt8[1, 2, 3, 4, 5], true)
        @test stream.state == HTTP2.StreamState.HALF_CLOSED_REMOTE
        @test HTTP2.can_send(stream) == true  # Server can still send response

        # Server sends response headers (no END_STREAM)
        HTTP2.send_headers!(stream, false)
        @test stream.state == HTTP2.StreamState.HALF_CLOSED_REMOTE
        @test HTTP2.can_send(stream) == true

        # Server sends trailers with END_STREAM
        HTTP2.send_headers!(stream, true)
        @test stream.state == HTTP2.StreamState.CLOSED
        @test HTTP2.can_send(stream) == false
    end

    @testset "send_grpc_response on closed stream" begin
        # Test that send_grpc_response gracefully handles closed streams
        conn = HTTP2.HTTP2Connection()
        conn.state = HTTP2.ConnectionState.OPEN
        io = IOBuffer()

        # Create and close a stream
        stream = HTTP2.create_stream(conn, UInt32(1))
        HTTP2.receive_headers!(stream, true)
        HTTP2.send_headers!(stream, true)  # Close the stream
        @test HTTP2.can_send_on_stream(conn, UInt32(1)) == false

        # This should return early without throwing (logs a warning)
        # Using Test.@test_logs to verify warning is logged
        @test_logs (:warn, r"Cannot send gRPC response") HTTP2.send_grpc_response(
            conn, io, UInt32(1),
            HTTP2.StatusCode.OK, "", UInt8[]
        )

        # IO buffer should be empty since no data was sent
        @test position(io) == 0
    end

    @testset "send_error_response on closed stream" begin
        # Test that send_error_response gracefully handles closed streams
        conn = HTTP2.HTTP2Connection()
        conn.state = HTTP2.ConnectionState.OPEN
        io = IOBuffer()

        # Create and close a stream
        stream = HTTP2.create_stream(conn, UInt32(3))
        HTTP2.receive_headers!(stream, true)
        HTTP2.send_headers!(stream, true)  # Close the stream
        @test HTTP2.can_send_on_stream(conn, UInt32(3)) == false

        # This should return early without throwing (logs a warning)
        @test_logs (:warn, r"Cannot send error response") HTTP2.send_error_response(
            conn, io, UInt32(3),
            HTTP2.StatusCode.INTERNAL, "Test error"
        )

        # IO buffer should be empty since no data was sent
        @test position(io) == 0
    end

    @testset "send_grpc_response on non-existent stream" begin
        # Test that send_grpc_response handles non-existent streams
        conn = HTTP2.HTTP2Connection()
        conn.state = HTTP2.ConnectionState.OPEN
        io = IOBuffer()

        # Stream 999 doesn't exist
        @test HTTP2.can_send_on_stream(conn, UInt32(999)) == false

        # This should return early without throwing
        @test_logs (:warn, r"Cannot send gRPC response") HTTP2.send_grpc_response(
            conn, io, UInt32(999),
            HTTP2.StatusCode.OK, "", UInt8[]
        )

        # IO buffer should be empty
        @test position(io) == 0
    end

    @testset "send_error_response on non-existent stream" begin
        # Test that send_error_response handles non-existent streams
        conn = HTTP2.HTTP2Connection()
        conn.state = HTTP2.ConnectionState.OPEN
        io = IOBuffer()

        # Stream 999 doesn't exist
        @test_logs (:warn, r"Cannot send error response") HTTP2.send_error_response(
            conn, io, UInt32(999),
            HTTP2.StatusCode.CANCELLED, "Client cancelled"
        )

        # IO buffer should be empty
        @test position(io) == 0
    end

    @testset "get_response_content_type helper" begin
        # Test content-type mirroring logic
        stream = HTTP2.HTTP2Stream(1)
        stream.request_headers = [("content-type", "application/grpc+proto")]
        @test HTTP2.get_response_content_type(stream) == "application/grpc+proto"

        stream2 = HTTP2.HTTP2Stream(3)
        stream2.request_headers = [("content-type", "application/grpc")]
        @test HTTP2.get_response_content_type(stream2) == "application/grpc"

        stream3 = HTTP2.HTTP2Stream(5)
        stream3.request_headers = []  # No content-type
        @test HTTP2.get_response_content_type(stream3) == "application/grpc"

        stream4 = HTTP2.HTTP2Stream(7)
        stream4.request_headers = [("content-type", "text/plain")]  # Invalid
        @test HTTP2.get_response_content_type(stream4) == "application/grpc"
    end
end
