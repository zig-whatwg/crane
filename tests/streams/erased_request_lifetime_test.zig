//! An erased read request (Streams 4.5.2 "read request", 4.5.4 "read-into
//! request": a struct of chunk, close and error steps) keeps its steps after
//! the call that erased it has returned.
//!
//! `TypedReadRequest(C).erase()` and `TypedReadIntoRequest(C).erase()`
//! pointed the erased request at `&VTable{ ... }` - a struct literal of
//! runtime function pointers, which lives in erase()'s own stack frame and
//! is gone when erase() returns. Whatever ran next in that frame's place
//! overwrote it: on x86-64 Linux byob_e2e_test's "ReadIntoRequest - callback
//! execution" called a null chunk step (SEGV at 0x0), on macOS the frame
//! happened to keep its bytes (lane linux1, 2026-11-08). Each test here
//! erases, then runs a call whose frame takes the place erase()'s had and
//! fills it, then runs every step.

const std = @import("std");
const testing = std.testing;

const read_request = @import("streams_read_request");
const read_into_request = @import("streams_read_into_request");

/// A frame as big as erase()'s and more, filled, at the depth erase() ran at:
/// whatever erase() left on its stack is overwritten.
noinline fn reuseTheFrame() void {
    var frame: [4096]u8 = undefined;
    @memset(&frame, 0);
    std.mem.doNotOptimizeAway(&frame);
}

const Steps = struct {
    chunks: u32 = 0,
    closes: u32 = 0,
    errors: u32 = 0,

    fn onChunk(self: *Steps, _: read_request.Value) void {
        self.chunks += 1;
    }
    fn onIntoChunk(self: *Steps, _: read_into_request.ArrayBufferView) void {
        self.chunks += 1;
    }
    fn onClose(self: *Steps) void {
        self.closes += 1;
    }
    fn onError(self: *Steps, _: read_request.Value) void {
        self.errors += 1;
    }
    fn onIntoError(self: *Steps, _: read_into_request.Value) void {
        self.errors += 1;
    }
};

noinline fn eraseReadRequest(steps: *Steps) read_request.ReadRequest {
    const typed = read_request.TypedReadRequest(Steps).init(testing.allocator, steps, Steps.onChunk, Steps.onClose, Steps.onError);
    return typed.erase();
}

noinline fn eraseReadIntoRequest(steps: *Steps) read_into_request.ReadIntoRequest {
    const typed = read_into_request.TypedReadIntoRequest(Steps).init(testing.allocator, steps, Steps.onIntoChunk, Steps.onClose, Steps.onIntoError);
    return typed.erase();
}

test "an erased read request runs its steps after the frame that erased it is reused" {
    var steps: Steps = .{};
    const request = eraseReadRequest(&steps);
    reuseTheFrame();
    request.executeChunkSteps(read_request.Value.undefined_value());
    request.executeCloseSteps();
    request.executeErrorSteps(read_request.Value.undefined_value());
    try testing.expectEqual(Steps{ .chunks = 1, .closes = 1, .errors = 1 }, steps);
}

test "an erased read-into request runs its steps after the frame that erased it is reused" {
    var steps: Steps = .{};
    const request = eraseReadIntoRequest(&steps);
    reuseTheFrame();
    var bytes = [_]u8{ 1, 2, 3 };
    request.executeChunkSteps(read_into_request.ArrayBufferView.fromSlice(&bytes));
    request.executeCloseSteps();
    request.executeErrorSteps(.undefined);
    try testing.expectEqual(Steps{ .chunks = 1, .closes = 1, .errors = 1 }, steps);
}
