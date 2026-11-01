//! The run plan: which tests run, in what order, and how they are grouped
//! into batches (one child process per batch). Everything here comes from
//! ONE seed, so the same seed over the same test list gives the same plan -
//! the order inside each batch and the composition of every batch - and a
//! failure that depends on what ran before it in its process can be replayed.
//!
//! The shuffle is a Fisher-Yates over `std.Random.Xoshiro256`, written out
//! here rather than taken from `std.Random`'s helpers, so a plan does not
//! change under a Zig upgrade that rewrites them. (WebKit's `--order=random`
//! and Gecko's chaos mode record no seed, so their failures cannot be
//! replayed; Chromium's `--gtest_shuffle` prints its seed and V8 passes one
//! seed to every test: tmp/plans/test-architecture-recommendation.md.)

const std = @import("std");

pub const Options = struct {
    seed: u64,
    /// false keeps the index order the build runner uses (`zig build test`).
    shuffle: bool = true,
    /// Tests per child process; 0 puts every selected test in one batch.
    batch_size: u32 = 10,
};

pub const Batch = struct {
    /// Offset into `Plan.order`.
    start: u32,
    len: u32,
};

pub const Plan = struct {
    /// The selected test indices, in run order.
    order: []u32,
    batches: []Batch,

    pub fn batchTests(plan: Plan, batch: usize) []const u32 {
        const b = plan.batches[batch];
        return plan.order[b.start..][0..b.len];
    }

    pub fn deinit(plan: Plan, gpa: std.mem.Allocator) void {
        gpa.free(plan.order);
        gpa.free(plan.batches);
    }
};

/// `selected` lists the test indices to run, in index order. The plan owns
/// copies; free it with `Plan.deinit`.
pub fn make(gpa: std.mem.Allocator, selected: []const u32, options: Options) !Plan {
    const order = try gpa.dupe(u32, selected);
    errdefer gpa.free(order);
    if (options.shuffle) shuffle(order, options.seed);

    const size: usize = if (options.batch_size == 0) @max(order.len, 1) else options.batch_size;
    const count = (order.len + size - 1) / size;
    const batches = try gpa.alloc(Batch, count);
    for (batches, 0..) |*b, i| {
        const start = i * size;
        b.* = .{ .start = @intCast(start), .len = @intCast(@min(size, order.len - start)) };
    }
    return .{ .order = order, .batches = batches };
}

/// Fisher-Yates, from the last element down: element i swaps with a
/// uniformly chosen j in [0, i].
pub fn shuffle(items: []u32, seed: u64) void {
    var prng = std.Random.Xoshiro256.init(seed);
    var i = items.len;
    while (i > 1) {
        i -= 1;
        const j: usize = @intCast(prng.next() % (i + 1));
        std.mem.swap(u32, &items[i], &items[j]);
    }
}

/// `--seed=` takes decimal or 0x-prefixed hexadecimal.
pub fn parseSeed(text: []const u8) !u64 {
    return std.fmt.parseUnsigned(u64, text, 0);
}

/// The seed the child test runner gets (`--seed=`, std.testing.random_seed),
/// which is a u32: the run seed's low half, so it too follows the one seed.
pub fn childSeed(seed: u64) u32 {
    return @truncate(seed);
}

// ---------------------------------------------------------------------------

const testing = std.testing;

fn iota(buf: []u32) []u32 {
    for (buf, 0..) |*x, i| x.* = @intCast(i);
    return buf;
}

test "the same seed gives the same plan; another seed gives another" {
    var buf: [100]u32 = undefined;
    const all = iota(&buf);

    const a = try make(testing.allocator, all, .{ .seed = 0xC0FFEE, .batch_size = 7 });
    defer a.deinit(testing.allocator);
    const b = try make(testing.allocator, all, .{ .seed = 0xC0FFEE, .batch_size = 7 });
    defer b.deinit(testing.allocator);
    const c = try make(testing.allocator, all, .{ .seed = 0xC0FFEF, .batch_size = 7 });
    defer c.deinit(testing.allocator);

    try testing.expectEqualSlices(u32, a.order, b.order);
    try testing.expectEqual(a.batches.len, b.batches.len);
    for (a.batches, b.batches) |x, y| try testing.expectEqual(x, y);
    try testing.expect(!std.mem.eql(u32, a.order, c.order));
}

test "a shuffle is a permutation and moves the order" {
    var buf: [64]u32 = undefined;
    const all = iota(&buf);
    const p = try make(testing.allocator, all, .{ .seed = 1 });
    defer p.deinit(testing.allocator);

    var seen: [64]bool = @splat(false);
    for (p.order) |t| {
        try testing.expect(!seen[t]);
        seen[t] = true;
    }
    for (seen) |s| try testing.expect(s);
    try testing.expect(!std.mem.eql(u32, p.order, all));
}

test "the shuffle is pinned: a std change must not move a recorded seed's plan" {
    // Recorded from this implementation on Zig 0.17; a failure here means a
    // seed printed in an old report now names a different order.
    var buf: [8]u32 = undefined;
    const items = iota(&buf);
    shuffle(items, 42);
    try testing.expectEqualSlices(u32, &pinned_42, items);
}

const pinned_42 = [8]u32{ 2, 5, 1, 3, 4, 6, 0, 7 };

test "no shuffle keeps the build runner's index order" {
    var buf: [10]u32 = undefined;
    const all = iota(&buf);
    const p = try make(testing.allocator, all, .{ .seed = 99, .shuffle = false, .batch_size = 4 });
    defer p.deinit(testing.allocator);
    try testing.expectEqualSlices(u32, all, p.order);
}

test "batching: size, a short last batch, every test exactly once" {
    var buf: [23]u32 = undefined;
    const all = iota(&buf);
    const p = try make(testing.allocator, all, .{ .seed = 5, .batch_size = 10 });
    defer p.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 3), p.batches.len);
    try testing.expectEqual(@as(u32, 10), p.batches[0].len);
    try testing.expectEqual(@as(u32, 10), p.batches[1].len);
    try testing.expectEqual(@as(u32, 3), p.batches[2].len);
    var total: usize = 0;
    for (0..p.batches.len) |i| total += p.batchTests(i).len;
    try testing.expectEqual(all.len, total);
}

test "batch size 1 is per-test isolation; 0 is the whole suite in one process" {
    var buf: [5]u32 = undefined;
    const all = iota(&buf);
    const one = try make(testing.allocator, all, .{ .seed = 5, .batch_size = 1 });
    defer one.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 5), one.batches.len);
    const whole = try make(testing.allocator, all, .{ .seed = 5, .batch_size = 0 });
    defer whole.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 1), whole.batches.len);
    try testing.expectEqual(@as(u32, 5), whole.batches[0].len);
}

test "an empty selection makes an empty plan" {
    const p = try make(testing.allocator, &.{}, .{ .seed = 5, .batch_size = 0 });
    defer p.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 0), p.batches.len);
}

test "seeds parse as decimal or hex, and the child gets the low half" {
    try testing.expectEqual(@as(u64, 255), try parseSeed("0xff"));
    try testing.expectEqual(@as(u64, 255), try parseSeed("255"));
    try testing.expectError(error.InvalidCharacter, parseSeed("zz"));
    try testing.expectEqual(@as(u32, 0x9abcdef0), childSeed(0x12345678_9abcdef0));
}
