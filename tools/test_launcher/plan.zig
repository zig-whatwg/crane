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
    /// Tests that need their process to themselves (indexed by test index;
    /// shorter than the test count means "not alone"): each goes in a batch
    /// of its own, after the others, in the shuffled order. Empty: the plan
    /// is exactly what it was without it.
    alone: []const bool = &.{},
    /// Groups that keep their own batching, for one executable that holds
    /// several suites' tests (build.zig's one-binary layout, lane onebin1):
    /// test t is in group `group[t]` (0 when the list is shorter), and group
    /// g > 0 is batched with `group_batch[g - 1]` tests per process (0: the
    /// whole group in one) - never in a batch with another group's tests, so
    /// each suite keeps the processes it had as an executable of its own.
    /// Group 0 is batched with `batch_size`. The groups follow one another in
    /// group order, each in the seed's order. Empty: one group, exactly the
    /// plan without groups.
    group: []const u16 = &.{},
    group_batch: []const u32 = &.{},

    fn groupOf(o: Options, t: u32) u16 {
        return if (t < o.group.len) o.group[t] else 0;
    }

    /// Group `g`'s tests per process.
    fn sizeOf(o: Options, g: u16) u32 {
        return if (g == 0 or g - 1 >= o.group_batch.len) o.batch_size else o.group_batch[g - 1];
    }
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

    // The alone tests to the end, each order kept (a stable partition).
    var shared: usize = order.len;
    if (options.alone.len != 0) {
        const isAlone = struct {
            fn f(alone: []const bool, t: u32) bool {
                return t < alone.len and alone[t];
            }
        }.f;
        const moved = try gpa.alloc(u32, order.len);
        defer gpa.free(moved);
        var n: usize = 0;
        for (order) |t| if (!isAlone(options.alone, t)) {
            moved[n] = t;
            n += 1;
        };
        shared = n;
        for (order) |t| if (isAlone(options.alone, t)) {
            moved[n] = t;
            n += 1;
        };
        @memcpy(order, moved);
    }

    // The shared tests by group, each group's order kept (a stable sort: with
    // no groups, the order is unchanged).
    std.sort.block(u32, order[0..shared], options, struct {
        fn lessThan(o: Options, a: u32, b: u32) bool {
            return o.groupOf(a) < o.groupOf(b);
        }
    }.lessThan);

    var batches: std.ArrayList(Batch) = .empty;
    errdefer batches.deinit(gpa);
    // Each group's run of the shared tests, batched with its own size.
    var start: usize = 0;
    while (start < shared) {
        const g = options.groupOf(order[start]);
        var end = start + 1;
        while (end < shared and options.groupOf(order[end]) == g) end += 1;
        const n = end - start;
        const size: usize = if (options.sizeOf(g) == 0) n else options.sizeOf(g);
        var i: usize = 0;
        while (i < n) : (i += size) {
            try batches.append(gpa, .{ .start = @intCast(start + i), .len = @intCast(@min(size, n - i)) });
        }
        start = end;
    }
    // One alone test per batch.
    for (shared..order.len) |i| try batches.append(gpa, .{ .start = @intCast(i), .len = 1 });
    return .{ .order = order, .batches = try batches.toOwnedSlice(gpa) };
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

test "alone tests each get a batch of their own, after the others; none declared changes nothing" {
    var buf: [10]u32 = undefined;
    const all = iota(&buf);
    var alone: [10]bool = @splat(false);
    alone[3] = true;
    alone[7] = true;
    const p = try make(testing.allocator, all, .{ .seed = 5, .batch_size = 0, .alone = &alone });
    defer p.deinit(testing.allocator);
    // The eight others in one process, then 3 and 7 in one each.
    try testing.expectEqual(@as(usize, 3), p.batches.len);
    try testing.expectEqual(@as(u32, 8), p.batches[0].len);
    for (p.batchTests(0)) |t| try testing.expect(!alone[t]);
    try testing.expectEqual(@as(u32, 1), p.batches[1].len);
    try testing.expectEqual(@as(u32, 1), p.batches[2].len);
    try testing.expect(alone[p.batchTests(1)[0]] and alone[p.batchTests(2)[0]]);
    // Every test exactly once.
    var seen: [10]bool = @splat(false);
    for (0..p.batches.len) |i| for (p.batchTests(i)) |t| {
        try testing.expect(!seen[t]);
        seen[t] = true;
    };
    for (seen) |s| try testing.expect(s);
    // Batches of 4: 8 others make 2, the alone two 1 each.
    const q = try make(testing.allocator, all, .{ .seed = 5, .batch_size = 4, .alone = &alone });
    defer q.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 4), q.batches.len);
    // Nothing declared: the plan the seed made before `alone` existed.
    const none: [10]bool = @splat(false);
    const r = try make(testing.allocator, all, .{ .seed = 5, .batch_size = 4, .alone = &none });
    defer r.deinit(testing.allocator);
    const s = try make(testing.allocator, all, .{ .seed = 5, .batch_size = 4 });
    defer s.deinit(testing.allocator);
    try testing.expectEqualSlices(u32, s.order, r.order);
    try testing.expectEqual(s.batches.len, r.batches.len);
}

/// Every batch of `p` holds tests of one group only, and every selected test
/// is in exactly one batch.
fn expectGroupsKeptApart(p: Plan, group: []const u16, n: usize) !void {
    var seen: [64]bool = @splat(false);
    for (0..p.batches.len) |i| {
        const tests = p.batchTests(i);
        for (tests) |t| {
            try testing.expectEqual(group[tests[0]], group[t]);
            try testing.expect(!seen[t]);
            seen[t] = true;
        }
    }
    for (seen[0..n]) |s| try testing.expect(s);
}

test "groups: each group is batched with its own size, and no batch mixes two groups" {
    var buf: [10]u32 = undefined;
    const all = iota(&buf);
    // Group 0 (no group named): batch_size 2. Group 1: a process per test.
    // Group 2: the whole group in one process.
    const group = [_]u16{ 0, 1, 1, 0, 2, 2, 2, 1, 0, 2 };
    const p = try make(testing.allocator, all, .{ .seed = 5, .batch_size = 2, .group = &group, .group_batch = &.{ 1, 0 } });
    defer p.deinit(testing.allocator);
    // Group 0's three tests in 2 + 1, group 1's three alone, group 2's four in one.
    try testing.expectEqual(@as(usize, 6), p.batches.len);
    try expectGroupsKeptApart(p, &group, all.len);
    var sizes: [3][4]u32 = @splat(@splat(0));
    var count: [3]usize = @splat(0);
    for (0..p.batches.len) |i| {
        const g = group[p.batchTests(i)[0]];
        sizes[g][count[g]] = p.batches[i].len;
        count[g] += 1;
    }
    try testing.expectEqualSlices(u32, &.{ 2, 1 }, sizes[0][0..count[0]]);
    try testing.expectEqualSlices(u32, &.{ 1, 1, 1 }, sizes[1][0..count[1]]);
    try testing.expectEqualSlices(u32, &.{4}, sizes[2][0..count[2]]);
    // The groups follow one another in group order.
    try testing.expectEqual(@as(u16, 0), group[p.batchTests(0)[0]]);
    try testing.expectEqual(@as(u16, 2), group[p.batchTests(p.batches.len - 1)[0]]);
}

test "groups: each group keeps the seed's order, and the same seed gives the same plan" {
    var buf: [40]u32 = undefined;
    const all = iota(&buf);
    var group: [40]u16 = undefined;
    for (&group, 0..) |*g, i| g.* = @intCast(i % 3);
    const a = try make(testing.allocator, all, .{ .seed = 0xC0FFEE, .batch_size = 4, .group = &group, .group_batch = &.{ 1, 10 } });
    defer a.deinit(testing.allocator);
    const b = try make(testing.allocator, all, .{ .seed = 0xC0FFEE, .batch_size = 4, .group = &group, .group_batch = &.{ 1, 10 } });
    defer b.deinit(testing.allocator);
    try testing.expectEqualSlices(u32, a.order, b.order);
    try expectGroupsKeptApart(a, &group, all.len);
    // Within a group, the shuffled order of the plan without groups.
    const plain = try make(testing.allocator, all, .{ .seed = 0xC0FFEE, .batch_size = 4 });
    defer plain.deinit(testing.allocator);
    for (0..3) |g| {
        var mine: [40]u32 = undefined;
        var theirs: [40]u32 = undefined;
        var n: usize = 0;
        var m: usize = 0;
        for (a.order) |t| if (group[t] == g) {
            mine[n] = t;
            n += 1;
        };
        for (plain.order) |t| if (group[t] == g) {
            theirs[m] = t;
            m += 1;
        };
        try testing.expectEqualSlices(u32, theirs[0..m], mine[0..n]);
    }
}

test "groups: every test in group 0 is the plan without groups; alone tests still go last, one a batch" {
    var buf: [23]u32 = undefined;
    const all = iota(&buf);
    const zeros: [23]u16 = @splat(0);
    const with = try make(testing.allocator, all, .{ .seed = 7, .batch_size = 10, .group = &zeros, .group_batch = &.{ 1, 0 } });
    defer with.deinit(testing.allocator);
    const without = try make(testing.allocator, all, .{ .seed = 7, .batch_size = 10 });
    defer without.deinit(testing.allocator);
    try testing.expectEqualSlices(u32, without.order, with.order);
    try testing.expectEqual(without.batches.len, with.batches.len);
    for (without.batches, with.batches) |x, y| try testing.expectEqual(x, y);

    // Alone tests leave their group: each in a batch of its own, after
    // every group's batches.
    var group: [23]u16 = undefined;
    for (&group, 0..) |*g, i| g.* = @intCast(i % 2);
    var alone: [23]bool = @splat(false);
    alone[4] = true;
    alone[9] = true;
    const p = try make(testing.allocator, all, .{ .seed = 7, .batch_size = 0, .group = &group, .group_batch = &.{0}, .alone = &alone });
    defer p.deinit(testing.allocator);
    // Group 0 (11 others) in one, group 1 (10 others) in one, then 4 and 9.
    try testing.expectEqual(@as(usize, 4), p.batches.len);
    try testing.expectEqual(@as(u32, 11), p.batches[0].len);
    try testing.expectEqual(@as(u32, 10), p.batches[1].len);
    try testing.expect(alone[p.batchTests(2)[0]] and alone[p.batchTests(3)[0]]);
    for (0..2) |i| for (p.batchTests(i)) |t| try testing.expect(!alone[t]);
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
