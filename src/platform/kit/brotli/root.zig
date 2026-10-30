//! Incremental RFC 7932 contexts backed by the pinned Google Brotli C library.
//! Like Chromium's net/filter/brotli_source_stream.cc, expose consumption and
//! terminal state; Compression Streams owns its stricter trailing-data policy.
const std = @import("std");
const platform = @import("platform");
// brotli/decode.h and encode.h, translated by build.zig (addCImport).
const c = @import("brotli_c");

// The C API's free callback has no size. A 16-byte aligned prefix records the
// exact allocation, so even native allocations use the caller's leak checker.
const Memory = struct {
    allocator: std.mem.Allocator,
    failed: bool = false,

    fn alloc(raw: ?*anyopaque, size: usize) callconv(.c) ?*anyopaque {
        const self: *Memory = @ptrCast(@alignCast(raw.?));
        const total = std.math.add(usize, size, 16) catch {
            self.failed = true;
            return null;
        };
        const bytes = self.allocator.alignedAlloc(u8, .@"16", total) catch {
            self.failed = true;
            return null;
        };
        const header: *usize = @ptrCast(bytes.ptr);
        header.* = total;
        return bytes.ptr + 16;
    }

    fn free(raw: ?*anyopaque, address: ?*anyopaque) callconv(.c) void {
        const ptr = address orelse return;
        const self: *Memory = @ptrCast(@alignCast(raw.?));
        const bytes: [*]align(16) u8 = @alignCast(@as([*]u8, @ptrCast(ptr)) - 16);
        const header: *const usize = @ptrCast(bytes);
        self.allocator.free(bytes[0..header.*]);
    }
};

const Decoder = struct { memory: Memory, state: *c.BrotliDecoderState };
const Encoder = struct { memory: Memory, state: *c.BrotliEncoderState };

/// All allocations, including the C context, belong to allocator.
pub fn createBrotliDecoder(allocator: std.mem.Allocator) platform.CodecError!*platform.BrotliDecoder {
    const self = try allocator.create(Decoder);
    errdefer allocator.destroy(self);
    self.memory = .{ .allocator = allocator };
    self.state = c.BrotliDecoderCreateInstance(Memory.alloc, Memory.free, &self.memory) orelse return error.OutOfMemory;
    // RFC 7932: do not enable BROTLI_DECODER_PARAM_LARGE_WINDOW (Compression §3).
    return @ptrCast(self);
}

pub fn destroyBrotliDecoder(handle: *platform.BrotliDecoder) void {
    const self: *Decoder = @ptrCast(@alignCast(handle));
    c.BrotliDecoderDestroyInstance(self.state);
    self.memory.allocator.destroy(self);
}

pub fn decompressBrotli(handle: *platform.BrotliDecoder, input: platform.Bytes, output: []u8) platform.CodecError!platform.CodecProgress {
    const self: *Decoder = @ptrCast(@alignCast(handle));
    var available_in = input.len;
    var next_in: [*c]const u8 = input.ptr;
    var available_out = output.len;
    var next_out: [*c]u8 = output.ptr;
    const result = c.BrotliDecoderDecompressStream(self.state, &available_in, &next_in, &available_out, &next_out, null);
    if (self.memory.failed) return error.OutOfMemory;
    const status: platform.CodecStatus = switch (result) {
        c.BROTLI_DECODER_RESULT_SUCCESS => .finished,
        c.BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT => .need_input,
        c.BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT => .need_output,
        else => return if (self.memory.failed) error.OutOfMemory else error.InvalidData,
    };
    return .{ .consumed = input.len - available_in, .produced = output.len - available_out, .status = status };
}

pub fn createBrotliEncoder(allocator: std.mem.Allocator) platform.CodecError!*platform.BrotliEncoder {
    const self = try allocator.create(Encoder);
    errdefer allocator.destroy(self);
    self.memory = .{ .allocator = allocator };
    self.state = c.BrotliEncoderCreateInstance(Memory.alloc, Memory.free, &self.memory) orelse return error.OutOfMemory;
    // Quality is implementation-defined. A moderate level avoids the reference
    // encoder's default (11) spending seconds on ordinary stream writes.
    if (c.BrotliEncoderSetParameter(self.state, c.BROTLI_PARAM_QUALITY, 6) == 0) {
        c.BrotliEncoderDestroyInstance(self.state);
        return error.InvalidData;
    }
    return @ptrCast(self);
}

pub fn destroyBrotliEncoder(handle: *platform.BrotliEncoder) void {
    const self: *Encoder = @ptrCast(@alignCast(handle));
    c.BrotliEncoderDestroyInstance(self.state);
    self.memory.allocator.destroy(self);
}

pub fn compressBrotli(handle: *platform.BrotliEncoder, input: platform.Bytes, output: []u8, finish: bool) platform.CodecError!platform.CodecProgress {
    const self: *Encoder = @ptrCast(@alignCast(handle));
    var available_in = input.len;
    var next_in: [*c]const u8 = input.ptr;
    var available_out = output.len;
    var next_out: [*c]u8 = output.ptr;
    const operation: c.BrotliEncoderOperation = if (finish) c.BROTLI_OPERATION_FINISH else c.BROTLI_OPERATION_PROCESS;
    if (c.BrotliEncoderCompressStream(self.state, operation, &available_in, &next_in, &available_out, &next_out, null) == 0)
        return if (self.memory.failed) error.OutOfMemory else error.InvalidData;
    // Some optional encoder allocations have an upstream fallback. Honor the
    // caller allocator's failure even when that fallback returns success.
    if (self.memory.failed) return error.OutOfMemory;
    const status: platform.CodecStatus = if (c.BrotliEncoderIsFinished(self.state) != 0)
        .finished
    else if (available_in != 0 or c.BrotliEncoderHasMoreOutput(self.state) != 0 or finish)
        .need_output
    else
        .need_input;
    return .{ .consumed = input.len - available_in, .produced = output.len - available_out, .status = status };
}
