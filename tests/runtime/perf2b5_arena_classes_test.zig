//! The state arena's size classes are exact to 16 bytes up to 4 KiB (lane
//! perf2, batch 5; tmp/plans/perf2b5-design.md 3.1).
//!
//! A node is one State block now (Z7): the generated State with every level's
//! InternalState and the NodeBase by value. Power-of-two classes would put a
//! div's ~1,250 bytes in a 2,048-byte block and a Document's 2,168-byte state
//! in 4,096 (lane nav2 batch 7's pin). With 16-byte classes a block holds its
//! request with less than 16 bytes to spare, as a malloc's tiny quantum does;
//! above 4 KiB the classes stay powers of two (8 and 16 KiB), and past 16 KiB
//! nothing is recycled or rounded.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");

const ArenaAllocator = runtime.ArenaAllocator;

test "a block holds its request with less than 16 bytes to spare, up to 4 KiB" {
    const cases = [_][2]usize{
        .{ 16, 16 },       .{ 17, 32 },       .{ 104, 112 },     .{ 1_240, 1_248 }, .{ 1_288, 1_296 },
        .{ 2_168, 2_176 }, .{ 4_095, 4_096 }, .{ 4_096, 4_096 },
    };
    for (cases) |case| {
        const held = ArenaAllocator.heldBytes(case[0], 8);
        if (held != case[1]) {
            std.debug.print("{d} bytes are held in {d}, expected {d}\n", .{ case[0], held, case[1] });
            return error.NotExactClass;
        }
    }
}

test "past 4 KiB the classes are 8 and 16 KiB, and past 16 KiB a request is held as it is" {
    try testing.expectEqual(@as(usize, 8_192), ArenaAllocator.heldBytes(4_097, 8));
    try testing.expectEqual(@as(usize, 16_384), ArenaAllocator.heldBytes(8_193, 8));
    try testing.expectEqual(@as(usize, 20_000), ArenaAllocator.heldBytes(20_000, 8));
}

test "a freed block serves its own 16-byte class only: a smaller request in it, never a larger one" {
    var arena_value = ArenaAllocator.init(testing.allocator);
    defer arena_value.deinit();
    const arena = &arena_value;

    // A div-sized state goes back...
    const block = try arena.createRaw(1_288, 8);
    arena.destroyRaw(block, 1_288, 8);
    // ...and a request 16 bytes smaller is another class: a new block.
    const smaller_class = try arena.createRaw(1_280, 8);
    try testing.expect(smaller_class != block);
    // A request one byte larger is another class too.
    const larger = try arena.createRaw(1_297, 8);
    try testing.expect(larger != block);
    // A request in the same class takes the block back, zeroed.
    const same_class = try arena.createRaw(1_281, 8);
    try testing.expectEqual(block, same_class);
    for (same_class[0..1_281]) |byte| try testing.expectEqual(@as(u8, 0), byte);
    arena.destroyRaw(same_class, 1_281, 8);
    arena.destroyRaw(larger, 1_297, 8);
    arena.destroyRaw(smaller_class, 1_280, 8);
}

test "every scheme's classes hold their requests, rise with them, and bound their slack" {
    const classes = runtime.arena_classes;
    inline for (.{ classes.ClassScheme.quantum16, classes.ClassScheme.eighths, classes.ClassScheme.powers_of_two }) |scheme| {
        const C = classes.SizeClasses(scheme);
        var previous: usize = 0;
        var size: usize = 8;
        while (size <= C.max_size) : (size += 1) {
            const class = C.of(size);
            const held = C.bytes(class);
            try testing.expect(class < C.count);
            try testing.expect(held >= size);
            // A class is the smallest that holds the request.
            if (class > 0) try testing.expect(C.bytes(class - 1) < size);
            try testing.expect(class >= previous);
            previous = class;
            switch (scheme) {
                .quantum16 => if (size <= 4096) try testing.expect(held - size < 16),
                .eighths => if (size > 512) try testing.expect((held - size) * 8 <= held),
                .powers_of_two => {},
            }
        }
        // Every class is used.
        try testing.expectEqual(C.count - 1, C.of(C.max_size));
    }
    // The arena's own scheme is the exact one (the fallback: `class_scheme`).
    try testing.expectEqual(classes.ClassScheme.quantum16, classes.scheme);
}

test "a freed block is poisoned when its Browser asked for it, and left as it was by default" {
    for ([_]bool{ false, true }) |poison| {
        var arena_value = ArenaAllocator.init(testing.allocator);
        defer arena_value.deinit();
        const arena = &arena_value;
        arena.poison_freed = poison;
        const block = try arena.createRaw(96, 8);
        @memset(block[0..96], 0x11);
        arena.destroyRaw(block, 96, 8);
        // The first word is the free list's link; the rest is the state's.
        const expected: u8 = if (poison) ArenaAllocator.poison_byte else 0x11;
        for (block[8..96]) |byte| try testing.expectEqual(expected, byte);
        // A reuse zeroes the request, poisoned or not.
        const again = try arena.createRaw(96, 8);
        try testing.expectEqual(block, again);
        for (again[0..96]) |byte| try testing.expectEqual(@as(u8, 0), byte);
        arena.destroyRaw(again, 96, 8);
    }
}

test "a released NodeBase is poisoned in Debug builds and where the Browser asked, never by default in a release build" {
    const rule = runtime.BrowserScope.releasedNodePoison;
    try testing.expect(rule(.Debug, false));
    try testing.expect(rule(.Debug, true));
    inline for (.{ std.builtin.OptimizeMode.ReleaseSafe, .ReleaseFast, .ReleaseSmall }) |mode| {
        try testing.expect(!rule(mode, false));
        try testing.expect(rule(mode, true));
    }
    try testing.expectEqual(@as(u8, 0xdd), ArenaAllocator.poison_byte);
}
