//! The span engine's size classes for State blocks (allocator-hardening
//! design 3.3): the state arena's classes, moved here when the arena became a
//! view of the heap (lane hard1, batch A), so a block's class - and so
//! `ArenaAllocator.heldBytes`, the DOM memory V8 is told about (dm1-dm3) -
//! is what it was.
//!
//! std-only, like browser_heap.zig.

const std = @import("std");

/// How the state arena rounds a request to a block it can recycle.
///
/// Lane perf2 batch 5 (tmp/plans/perf2b5-design.md 3.1): a node is ONE State
/// block now - the generated State with every level's InternalState and the
/// NodeBase by value (runtime.FlattenedState, Z7) - so the block's class is a
/// node's whole storage. Power-of-two classes put a div's ~1,250 bytes in a
/// 2,048-byte block and a Document's 2,168-byte state in 4,096 (lane nav2
/// batch 7). Classes trade slack against reuse: a freed block serves only
/// requests of its own class, and finer classes are narrower bands - jemalloc
/// and PartitionAlloc keep four to eight per doubling, macOS malloc a 16-byte
/// quantum to 1 KiB and 512 bytes above. The choice is MEASURED (the perf
/// window's memory rows, both schemes) and stays one constant away.
pub const ClassScheme = enum {
    /// Every multiple of 16 bytes to 4 KiB, then 8 and 16 KiB: a block holds
    /// its request with less than 16 bytes to spare.
    quantum16,
    /// 16-byte steps to 512 bytes, then eight classes per doubling to 16 KiB:
    /// at most 12.5% slack, wider bands to recycle in.
    eighths,
    /// Powers of two from 16 bytes to 16 KiB: the classes before batch 5.
    powers_of_two,
};

/// The scheme State blocks use.
pub const class_scheme: ClassScheme = .quantum16;

/// The size classes of `scheme`, for requests of 1 byte to `max_size`.
pub fn SizeClasses(comptime scheme: ClassScheme) type {
    return struct {
        /// The largest request a class holds; past it a block is a run of
        /// whole spans (`Engine`'s large buckets).
        pub const max_size: usize = 16 * 1024;

        /// How many classes there are.
        pub const count: usize = switch (scheme) {
            .quantum16 => 4096 / 16 + 2,
            .eighths => 512 / 16 + 5 * 8,
            .powers_of_two => 14 - 4 + 1,
        };

        /// The class of a request of `size` bytes, 1 <= size <= max_size.
        pub fn of(size: usize) usize {
            std.debug.assert(size >= 1 and size <= max_size);
            switch (scheme) {
                .quantum16 => {
                    if (size <= 4096) return (size + 15) / 16 - 1;
                    return if (size <= 8192) 256 else 257;
                },
                .eighths => {
                    if (size <= 512) return (size + 15) / 16 - 1;
                    // The doubling (base, 2 * base] the size falls in, and its
                    // eighth: classes base + k * base / 8, k = 1..8.
                    const d: usize = std.math.log2_int(usize, size - 1);
                    const base = @as(usize, 1) << @intCast(d);
                    const step = base / 8;
                    const k = (size - base + step - 1) / step;
                    return 32 + (d - 9) * 8 + (k - 1);
                },
                .powers_of_two => {
                    const shift = std.math.log2_int_ceil(usize, @max(size, 16));
                    return shift - 4;
                },
            }
        }

        /// The bytes a block of `class` holds.
        pub fn bytes(class: usize) usize {
            std.debug.assert(class < count);
            switch (scheme) {
                .quantum16 => {
                    if (class < 256) return (class + 1) * 16;
                    return if (class == 256) 8192 else 16384;
                },
                .eighths => {
                    if (class < 32) return (class + 1) * 16;
                    const i = class - 32;
                    const base = @as(usize, 1) << @intCast(9 + i / 8);
                    return base + (i % 8 + 1) * (base / 8);
                },
                .powers_of_two => return @as(usize, 1) << @intCast(class + 4),
            }
        }
    };
}

/// The classes State blocks use.
pub const Classes = SizeClasses(class_scheme);

/// The largest alignment a class block has: every class is a multiple of 16
/// bytes and every span starts on a span boundary, so a block is 16-aligned;
/// a request aligned more is rounded up to a class that is a multiple of its
/// alignment (`requestBytes`).
pub const natural_alignment: usize = 16;

/// The bytes a request of `size`/`alignment` is served as: the size rounded
/// up to the alignment, so every slot of its class - a multiple of the
/// rounded size's class, which quantum16 makes a multiple of any alignment
/// up to 4 KiB - is aligned. At least 1.
pub fn requestBytes(size: usize, alignment: usize) usize {
    const a = @max(alignment, 1);
    return @max(1, std.mem.alignForward(usize, size, if (a > natural_alignment) a else 1));
}

/// The class of a request, or null when it is past the largest class (a
/// large block: a run of whole spans).
pub fn classOf(size: usize, alignment: usize) ?usize {
    const n = requestBytes(size, alignment);
    if (n > Classes.max_size) return null;
    const class = Classes.of(n);
    std.debug.assert(alignment <= natural_alignment or Classes.bytes(class) % alignment == 0);
    return class;
}

test "every class is a multiple of 16 and holds its requests" {
    var size: usize = 1;
    while (size <= Classes.max_size) : (size += 7) {
        const class = Classes.of(size);
        try std.testing.expect(Classes.bytes(class) >= size);
        try std.testing.expectEqual(@as(usize, 0), Classes.bytes(class) % 16);
    }
}
