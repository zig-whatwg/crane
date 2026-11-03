//! A view converted from JavaScript names one placeholder ArrayBuffer,
//! `buffer_sources.engine_buffer` - its bytes live in the engine. Every view
//! converted on every thread shares it, so it is a constant that nothing
//! writes (lane gstate4; it was a process-wide `pub var`).
const std = @import("std");
const webidl = @import("webidl");

test "an engine view's placeholder buffer is one constant, empty, shared by every view" {
    try std.testing.expect(@typeInfo(@TypeOf(&webidl.buffer_sources.engine_buffer)).pointer.is_const);
    // Never dereferenced: fromEngine only records the handle.
    const a = webidl.ArrayBufferView.fromEngine(1, 0, 4, @ptrFromInt(0x1000)).?;
    const b = webidl.ArrayBufferView.fromEngine(11, 2, 3, @ptrFromInt(0x2000)).?;
    try std.testing.expectEqual(a.getViewedArrayBuffer(), b.getViewedArrayBuffer());
    try std.testing.expectEqual(@as(usize, 0), a.getViewedArrayBuffer().data.len);
    try std.testing.expect(!a.getViewedArrayBuffer().detached);
}
