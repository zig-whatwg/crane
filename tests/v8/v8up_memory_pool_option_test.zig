//! V8's page pool is a V8 BUILD option, `-Dv8-memory-pool-timeout-s`
//! (src/runtime/engines/v8/memory_pool.zig; declared by engine_build.zig).
//!
//! V8 15.7 keeps the heap pages its collections free in a pool shared by every
//! isolate of the process and returns them to the operating system 8 to 16
//! seconds later (src/heap/memory-pool.cc; flags memory_pool and
//! memory_pool_timeout). Chrome ships that. The option lets a build say
//! otherwise, and THE DEFAULT IS V8'S OWN (the user, 2026-11-13: "Option,
//! Chrome default"): a build that does not give the option starts V8 with no
//! pool flag at all, so nothing a default build measures can move because the
//! option exists. That is what these tests hold:
//!
//!   - the default is "not given", and not given is no flag;
//!   - each value is exactly one flag, spelled as V8 15.7.112.43 spells it:
//!     0 is `--no-memory-pool`, n is `--memory-pool-timeout=<n>`;
//!   - what the build was given is what V8 is started with - once, at run
//!     time and at snapshot generation alike.
//!
//! A value that is not a number of seconds never reaches these tests: the
//! option is a u32, and `zig build` refuses anything else at configure time
//! ("expected -Dv8-memory-pool-timeout-s to be an integer").
//!
//! These are string-level tests, as tests/v8/v8_flags_test.zig's are. What
//! the two flags DO was measured, not asserted (lane v8up b8, the perf suite
//! x7: memory_pool.zig has the table).

const std = @import("std");
const v8 = @import("v8");
const loader = v8.snapshot_loader;

/// How often `needle` occurs in `text`.
fn occurrences(text: []const u8, needle: []const u8) usize {
    var count: usize = 0;
    var from: usize = 0;
    while (std.mem.indexOfPos(u8, text, from, needle)) |at| {
        count += 1;
        from = at + needle.len;
    }
    return count;
}

test "the page pool's default is V8's own: a build that does not say starts V8 with no pool flag" {
    if (!@hasDecl(v8, "memory_pool")) return error.TheAdapterHasNoMemoryPoolOption;
    if (@hasDecl(v8, "memory_pool")) {
        const memory_pool = v8.memory_pool;
        // ONE constant decides what a build that does not say gets, and it is
        // "not given": V8's own pool, as Chrome ships it.
        try std.testing.expectEqual(@as(?u32, null), memory_pool.default_timeout_s);
        try std.testing.expectEqualStrings("", memory_pool.flagFor(null));
        if (memory_pool.requested_timeout_s != null) return error.SkipZigTest; // a build given the option: the next test is its
        try std.testing.expectEqualStrings("", memory_pool.flag);
        // A measurement build (-Dv8-extra-flags) may name the pool itself: its
        // flags are not the product's, and the default build pins the default.
        if (loader.measurement_v8_flags.len != 0) return error.SkipZigTest;
        for ([_][]const u8{ loader.RUNTIME_V8_FLAGS, loader.SNAPSHOT_V8_FLAGS }) |flags| {
            try std.testing.expect(std.mem.indexOf(u8, flags, "memory-pool") == null);
            try std.testing.expect(std.mem.indexOf(u8, flags, "memory_pool") == null);
        }
    }
}

test "each value of -Dv8-memory-pool-timeout-s is exactly one V8 flag" {
    if (!@hasDecl(v8, "memory_pool")) return error.TheAdapterHasNoMemoryPoolOption;
    if (@hasDecl(v8, "memory_pool")) {
        const flagFor = v8.memory_pool.flagFor;
        // 0 seconds: nothing is pooled. V8's flag for that is the pool's own
        // switch, not a timeout of 0 (which V8 reads as "empty the pool when a
        // full collection starts", heap.cc:968-980 - the pool stays).
        try std.testing.expectEqualStrings(" --no-memory-pool", flagFor(0));
        // n seconds: V8's timeout, in its unit.
        try std.testing.expectEqualStrings(" --memory-pool-timeout=1", flagFor(1));
        try std.testing.expectEqualStrings(" --memory-pool-timeout=8", flagFor(8));
        try std.testing.expectEqualStrings(" --memory-pool-timeout=600", flagFor(600));
        // Every u32 is a number of seconds V8 takes (the flag is a size_t).
        try std.testing.expectEqualStrings(" --memory-pool-timeout=4294967295", flagFor(std.math.maxInt(u32)));
        // One flag each, led by the one space that joins it to the set.
        inline for ([_]?u32{ 0, 1, 8, 600 }) |seconds| {
            const flag = comptime flagFor(seconds);
            try std.testing.expect(std.mem.startsWith(u8, flag, " --"));
            try std.testing.expectEqual(@as(usize, 1), occurrences(flag, " "));
            try std.testing.expectEqual(@as(usize, 1), occurrences(flag, "--"));
        }
    }
}

test "what the build was given is what V8 starts with, once, at run time and at snapshot generation" {
    if (!@hasDecl(v8, "memory_pool")) return error.TheAdapterHasNoMemoryPoolOption;
    if (@hasDecl(v8, "memory_pool")) {
        const memory_pool = v8.memory_pool;
        // The build's flag is the value's flag: the build's value, or the
        // default where it gave none.
        try std.testing.expectEqualStrings(comptime memory_pool.flagFor(memory_pool.requested_timeout_s orelse memory_pool.default_timeout_s), memory_pool.flag);
        if (memory_pool.flag.len == 0) return; // the default build: the first test holds it to no flag
        const measurement = loader.measurement_v8_flags;
        for ([_][]const u8{ loader.RUNTIME_V8_FLAGS, loader.SNAPSHOT_V8_FLAGS }) |flags| {
            // The product's part of the set: the measurement flags are last
            // (V8::SetFlagsFromString stops at the first flag it does not
            // know, flags.cc:771, so the product's are parsed before them).
            const product = if (measurement.len != 0) flags[0..std.mem.lastIndexOf(u8, flags, measurement).?] else flags;
            try std.testing.expectEqual(@as(usize, 1), occurrences(product, memory_pool.flag));
            // Nothing else of the product's names the pool: V8 takes the last
            // of two spellings, and a second one would be a second owner.
            try std.testing.expectEqual(@as(usize, 1), occurrences(product, "memory-pool"));
        }
    }
}
