//! ASCII fast path optimizations

const std = @import("std");
const builtin = @import("builtin");

pub fn countAsciiPrefix(bytes: []const u8) usize {
    if (bytes.len == 0) return 0;

    // Comptime CPU detection for optimal SIMD
    if (comptime builtin.cpu.arch == .x86_64) {
        // Check for AVX2 support at comptime
        const has_avx2 = comptime std.Target.x86.featureSetHas(builtin.cpu.features, .avx2);
        if (has_avx2) {
            return countAsciiPrefixAvx2(bytes);
        } else {
            return countAsciiPrefixSse2(bytes);
        }
    } else if (comptime builtin.cpu.arch == .aarch64) {
        // ARM NEON uses 16-byte vectors
        return countAsciiPrefixNeon(bytes);
    } else {
        return countAsciiPrefixScalar(bytes);
    }
}

fn countAsciiPrefixScalar(bytes: []const u8) usize {
    var i: usize = 0;

    const word_size = @sizeOf(usize);
    const mask: usize = if (word_size == 8)
        0x8080808080808080
    else
        0x80808080;

    while (i + word_size <= bytes.len) {
        const word = std.mem.readInt(usize, bytes[i..][0..word_size], .little);

        if ((word & mask) != 0) {
            while (i < bytes.len and bytes[i] < 0x80) : (i += 1) {}
            return i;
        }

        i += word_size;
    }

    while (i < bytes.len and bytes[i] < 0x80) : (i += 1) {}

    return i;
}

// AVX2 path: Process 32 bytes at once (modern x86_64)
fn countAsciiPrefixAvx2(bytes: []const u8) usize {
    var i: usize = 0;

    const Vec32 = @Vector(32, u8);
    const mask32: Vec32 = @splat(0x80);

    // Process 32-byte chunks with AVX2
    while (i + 32 <= bytes.len) {
        const chunk: Vec32 = bytes[i..][0..32].*;

        if (@reduce(.Or, chunk & mask32) != 0) {
            // Found non-ASCII byte, scan backwards to find exact position
            while (i < bytes.len and bytes[i] < 0x80) : (i += 1) {}
            return i;
        }

        i += 32;
    }

    // Process remaining bytes with 16-byte SSE2
    const Vec16 = @Vector(16, u8);
    const mask16: Vec16 = @splat(0x80);

    if (i + 16 <= bytes.len) {
        const chunk: Vec16 = bytes[i..][0..16].*;
        if (@reduce(.Or, chunk & mask16) != 0) {
            while (i < bytes.len and bytes[i] < 0x80) : (i += 1) {}
            return i;
        }
        i += 16;
    }

    // Process remaining bytes scalar
    while (i < bytes.len and bytes[i] < 0x80) : (i += 1) {}

    return i;
}

// SSE2 path: Process 16 bytes at once (legacy x86_64)
fn countAsciiPrefixSse2(bytes: []const u8) usize {
    var i: usize = 0;

    const Vec = @Vector(16, u8);
    const mask: Vec = @splat(0x80);

    while (i + 16 <= bytes.len) {
        const chunk: Vec = bytes[i..][0..16].*;

        if (@reduce(.Or, chunk & mask) != 0) {
            while (i < bytes.len and bytes[i] < 0x80) : (i += 1) {}
            return i;
        }

        i += 16;
    }

    while (i < bytes.len and bytes[i] < 0x80) : (i += 1) {}

    return i;
}

// NEON path: Process 16 bytes at once (ARM)
fn countAsciiPrefixNeon(bytes: []const u8) usize {
    var i: usize = 0;

    const Vec = @Vector(16, u8);
    const mask: Vec = @splat(0x80);

    while (i + 16 <= bytes.len) {
        const chunk: Vec = bytes[i..][0..16].*;

        if (@reduce(.Or, chunk & mask) != 0) {
            while (i < bytes.len and bytes[i] < 0x80) : (i += 1) {}
            return i;
        }

        i += 16;
    }

    while (i < bytes.len and bytes[i] < 0x80) : (i += 1) {}

    return i;
}

pub inline fn isAscii(bytes: []const u8) bool {
    return countAsciiPrefix(bytes) == bytes.len;
}

pub fn copyAsciiToUtf16(input: []const u8, output: []u16) usize {
    const len = @min(input.len, output.len);

    for (input[0..len], 0..) |byte, i| {
        std.debug.assert(byte < 0x80);
        output[i] = byte;
    }

    return len;
}

pub fn copyUtf16ToAscii(input: []const u16, output: []u8) usize {
    const len = @min(input.len, output.len);

    for (input[0..len], 0..) |code_unit, i| {
        std.debug.assert(code_unit < 0x80);
        output[i] = @intCast(code_unit);
    }

    return len;
}

pub fn countAsciiPrefixUtf16(code_units: []const u16) usize {
    var i: usize = 0;

    while (i < code_units.len and code_units[i] < 0x80) : (i += 1) {}

    return i;
}

// Tests







