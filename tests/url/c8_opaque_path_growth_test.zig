//! The opaque path state appends each code point's encoding to the URL's
//! path (URL Standard, basic URL parser, "opaque path state" step 4) - and
//! parsing an opaque path takes memory linear in its length (lane crashes8).
//!
//! The parser appended by concatenating the whole path so far with the next
//! character's encoding and "freeing" the old copy - on the parse's
//! ArenaAllocator, where a free is a no-op. An opaque path of n bytes took
//! about n^2/2 bytes: html/cross-origin-embedder-policy/worker-inheritance.sub.https.html
//! starts a worker from `data:application/javascript,` plus the whole of
//! testharness.js, URI-encoded (~350 KB), and each parse of that URL took
//! ~60 GB, the whole 0.1 sweep's memory peak.
//!
//! The allocator here fails any allocation that would take what the parse
//! holds past a cap a few times the input's length, so a parse whose memory
//! grows with the square of its input fails at once instead of taking the
//! machine; the cap is the bound the test pins.

const std = @import("std");
const testing = std.testing;
const parser = @import("url").parser.basic_url_parser;

/// Fails an allocation that would take the live bytes past `cap`.
const Capped = struct {
    child: std.mem.Allocator,
    cap: usize,
    live: usize = 0,
    peak: usize = 0,

    fn allocator(self: *Capped) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable: std.mem.Allocator.VTable = .{ .alloc = alloc, .resize = resize, .remap = remap, .free = free };

    fn grow(self: *Capped, old_len: usize, new_len: usize) bool {
        const next = self.live - old_len + new_len;
        if (next > self.cap) return false;
        self.live = next;
        self.peak = @max(self.peak, next);
        return true;
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *Capped = @ptrCast(@alignCast(ctx));
        if (!self.grow(0, len)) return null;
        return self.child.rawAlloc(len, alignment, ret) orelse {
            self.live -= len;
            return null;
        };
    }
    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret: usize) bool {
        const self: *Capped = @ptrCast(@alignCast(ctx));
        if (!self.grow(memory.len, new_len)) return false;
        if (self.child.rawResize(memory, alignment, new_len, ret)) return true;
        self.live = self.live - new_len + memory.len;
        return false;
    }
    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret: usize) ?[*]u8 {
        const self: *Capped = @ptrCast(@alignCast(ctx));
        if (!self.grow(memory.len, new_len)) return null;
        return self.child.rawRemap(memory, alignment, new_len, ret) orelse {
            self.live = self.live - new_len + memory.len;
            return null;
        };
    }
    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *Capped = @ptrCast(@alignCast(ctx));
        self.child.rawFree(memory, alignment, ret);
        self.live -= memory.len;
    }
};

/// What the parse may hold at once: a multiple of its input's length, and a
/// floor for the record's own fields and the arena's first block.
const cap_factor = 32;
const cap_floor = 64 * 1024;

fn expectLinear(input: []const u8, expected_path: []const u8) !void {
    var capped: Capped = .{ .child = testing.allocator, .cap = cap_factor * input.len + cap_floor };
    var record = parser.parse(capped.allocator(), input, null) catch |err| {
        std.debug.print("{d}-byte input: {s} at the {d}-byte cap\n", .{ input.len, @errorName(err), capped.cap });
        return err;
    };
    defer record.deinit();
    try testing.expect(record.hasOpaquePath());
    try testing.expectEqualStrings(expected_path, record.path.opaque_path);
}

test "a data: URL whose opaque path is a whole URI-encoded script parses in memory linear in its length" {
    // The shape of worker-inheritance's worker URL: a scheme, then a long
    // ASCII path, much of it percent-encoded already.
    const prefix = "data:application/javascript,";
    const unit = "promise_test(t%20%3D%3E%20t.done())%3B%0A";
    const repeats = 8 * 1024; // ~340 KB
    const input = try testing.allocator.alloc(u8, prefix.len + unit.len * repeats);
    defer testing.allocator.free(input);
    @memcpy(input[0..prefix.len], prefix);
    for (0..repeats) |i| @memcpy(input[prefix.len + i * unit.len ..][0..unit.len], unit);

    // Opaque path state: nothing in it is in the C0 control percent-encode
    // set, so the path is the input after the scheme's colon.
    try expectLinear(input, input["data:".len..]);
}

test "an opaque path with code points to percent-encode parses in memory linear in its length" {
    // Non-ASCII input takes the parser's other branch: each byte of "é"
    // (C3 A9) and each C0 control is UTF-8 percent-encoded.
    const prefix = "javascript:";
    const unit = "x\xc3\xa9\x01";
    const encoded = "x%C3%A9%01";
    const repeats = 16 * 1024;
    const input = try testing.allocator.alloc(u8, prefix.len + unit.len * repeats);
    defer testing.allocator.free(input);
    @memcpy(input[0..prefix.len], prefix);
    for (0..repeats) |i| @memcpy(input[prefix.len + i * unit.len ..][0..unit.len], unit);
    const expected = try testing.allocator.alloc(u8, encoded.len * repeats);
    defer testing.allocator.free(expected);
    for (0..repeats) |i| @memcpy(expected[i * encoded.len ..][0..encoded.len], encoded);

    try expectLinear(input, expected);
}

test "short opaque paths: unchanged by the bound" {
    try expectLinear("data:,", ",");
    try expectLinear("data:text/plain,hi", "text/plain,hi");
    try expectLinear("mailto:a@b.test", "a@b.test");
    try expectLinear("javascript:void(0) ", "void(0)");
    try expectLinear("a:", "");
}
