//! Crane's in-sandbox allocator (src/runtime/engines/v8/sandbox_allocator.zig)
//! over a MODEL address space: every page operation the allocator makes is
//! recorded per 1 MiB chunk, and every block it hands out is checked against
//! that record. The rule the allocator exists for is the one the model holds
//! it to: a block never lies on a chunk whose memory was given back to the OS
//! and not recommitted (macOS would leave it out of the process footprint -
//! tests/v8/ab1_array_buffer_footprint_test.zig measures that with the real
//! one), and a block said to be zero was never written since the OS made its
//! memory.
//!
//! The allocator keeps no record inside the memory it hands out, so the model
//! needs no real pages: its base is an address nothing is mapped at.

const std = @import("std");
const v8 = @import("v8");
const sa = v8.sandbox_allocator;

const testing = std.testing;

const chunk = sa.chunk_size;
const granule = sa.alignment;
const granules_per_chunk = chunk / granule;

/// What the OS holds for one chunk of the model.
const PageState = enum {
    /// Reserved, not accessible.
    inaccessible,
    /// Accessible and accounted.
    committed,
    /// Accessible, its memory given back: must be recommitted before use.
    discarded,
};

const Model = struct {
    states: []PageState,
    /// One bit per 16 bytes of the range: written since the OS made the
    /// chunk's memory (a discard keeps it: macOS may keep the old bytes).
    written: std.DynamicBitSetUnmanaged,
    base: usize,
    /// The first rule the allocator broke, if any.
    violation: ?[]const u8 = null,
    fail_set_read_write: bool = false,
    fail_recommit: bool = false,
    fail_discard: bool = false,
    fail_decommit: bool = false,
    set_read_writes: usize = 0,
    recommits: usize = 0,
    discards: usize = 0,
    decommits: usize = 0,

    const model_base: usize = 0x40_0000_0000;

    fn init(chunks: usize) !Model {
        const states = try testing.allocator.alloc(PageState, chunks);
        @memset(states, .inaccessible);
        return .{
            .states = states,
            .written = try std.DynamicBitSetUnmanaged.initEmpty(testing.allocator, chunks * granules_per_chunk),
            .base = model_base,
        };
    }

    fn deinit(self: *Model) void {
        testing.allocator.free(self.states);
        self.written.deinit(testing.allocator);
    }

    fn range(self: *Model, address: usize, size: usize) ?[]PageState {
        if (address < self.base or address % chunk != 0 or size % chunk != 0 or size == 0) {
            self.violate("a page operation is not on whole chunks of the range");
            return null;
        }
        const first = (address - self.base) / chunk;
        const count = size / chunk;
        if (first + count > self.states.len) {
            self.violate("a page operation runs past the reservation");
            return null;
        }
        return self.states[first..][0..count];
    }

    fn violate(self: *Model, what: []const u8) void {
        if (self.violation == null) self.violation = what;
    }

    fn clearWritten(self: *Model, address: usize, size: usize) void {
        const first = (address - self.base) / granule;
        self.written.setRangeValue(.{ .start = first, .end = first + size / granule }, false);
    }

    /// A block the allocator handed out is used: every chunk under it must
    /// be committed, and when it was said to be zero no byte of it may have
    /// been written. Then the caller writes all of it.
    fn use(self: *Model, block: sa.Block, size: usize) !void {
        try testing.expect(block.address >= self.base);
        try testing.expectEqual(@as(usize, 0), block.address % sa.alignment);
        const offset = block.address - self.base;
        const end = offset + @max(size, 1);
        try testing.expect(end <= self.states.len * chunk);
        var index = offset / chunk;
        while (index * chunk < end) : (index += 1) {
            if (self.states[index] != .committed) {
                std.debug.print("a block lies on chunk {d}, which is {s}\n", .{ index, @tagName(self.states[index]) });
                return error.BlockOnMemoryNotCommitted;
            }
        }
        const first = offset / granule;
        const last = (end + granule - 1) / granule;
        if (block.zeroed) {
            var at = first;
            while (at < last) : (at += 1) {
                if (self.written.isSet(at)) return error.BlockSaidZeroWasWritten;
            }
        }
        self.written.setRangeValue(.{ .start = first, .end = last }, true);
    }

    fn check(self: *const Model) !void {
        if (self.violation) |what| {
            std.debug.print("the allocator broke a page rule: {s}\n", .{what});
            return error.PageRuleBroken;
        }
    }

    // sandbox_allocator.zig `Pages`.

    pub fn setReadWrite(self: *Model, address: usize, size: usize) bool {
        const chunks = self.range(address, size) orelse return false;
        if (self.fail_set_read_write) return false;
        for (chunks) |*state| {
            if (state.* != .inaccessible) self.violate("setReadWrite on a chunk that is accessible already");
            state.* = .committed;
        }
        self.clearWritten(address, size);
        self.set_read_writes += 1;
        return true;
    }

    pub fn discard(self: *Model, address: usize, size: usize) bool {
        const chunks = self.range(address, size) orelse return false;
        if (self.fail_discard) return false;
        for (chunks) |*state| {
            if (state.* == .inaccessible) self.violate("discard of an inaccessible chunk");
            state.* = .discarded;
        }
        self.discards += 1;
        return true;
    }

    pub fn recommit(self: *Model, address: usize, size: usize) bool {
        const chunks = self.range(address, size) orelse return false;
        if (self.fail_recommit) return false;
        for (chunks) |*state| {
            if (state.* == .inaccessible) self.violate("recommit of an inaccessible chunk");
            state.* = .committed;
        }
        self.recommits += 1;
        return true;
    }

    pub fn decommit(self: *Model, address: usize, size: usize) bool {
        const chunks = self.range(address, size) orelse return false;
        if (self.fail_decommit) return false;
        for (chunks) |*state| {
            if (state.* == .inaccessible) self.violate("decommit of an inaccessible chunk");
            state.* = .inaccessible;
        }
        self.decommits += 1;
        return true;
    }
};

const Allocator = sa.Allocator(*Model);

const Fixture = struct {
    model: *Model,
    allocator: Allocator,

    fn init(chunks: usize) !Fixture {
        const model = try testing.allocator.create(Model);
        errdefer testing.allocator.destroy(model);
        model.* = try Model.init(chunks);
        errdefer model.deinit();
        return .{ .model = model, .allocator = try Allocator.init(testing.allocator, model, model.base, chunks * chunk) };
    }

    fn deinit(self: *Fixture) void {
        self.allocator.deinit();
        self.model.deinit();
        testing.allocator.destroy(self.model);
    }

    /// A block of `size` bytes, used at once (the model checks it).
    fn take(self: *Fixture, size: usize) !sa.Block {
        const block = self.allocator.allocate(size) orelse return error.NoBlock;
        try self.model.use(block, size);
        try self.model.check();
        return block;
    }

    fn give(self: *Fixture, block: sa.Block) !void {
        try self.allocator.free(block.address);
        try self.model.check();
    }

    fn chunkOf(self: *const Fixture, block: sa.Block) usize {
        return (block.address - self.model.base) / chunk;
    }
};

test "size classes: every size has the smallest class that holds it, at most an eighth larger" {
    try testing.expectEqual(@as(u32, 16), sa.class_sizes[0]);
    try testing.expectEqual(@as(u32, sa.slot_max), sa.class_sizes[sa.class_count - 1]);
    for (sa.class_sizes[0 .. sa.class_count - 1], sa.class_sizes[1..]) |smaller, larger| {
        try testing.expect(smaller < larger);
    }
    for (sa.class_sizes) |size| try testing.expectEqual(@as(u32, 0), size % sa.alignment);

    var size: usize = 1;
    while (size <= sa.slot_max) : (size += if (size < 4096) 1 else 61) {
        const class = sa.classOf(size);
        const slot = sa.class_sizes[class];
        try testing.expect(slot >= size);
        if (class > 0) try testing.expect(sa.class_sizes[class - 1] < size);
        // Multiples of 16 up to 128; above, 8 classes to each power of two.
        if (size > 128) try testing.expect((slot - size) * 8 < size);
    }
    for (sa.class_sizes, 0..) |slot, class| {
        try testing.expectEqual(@as(u8, @intCast(class)), sa.classOf(slot));
        if (slot < sa.slot_max) try testing.expectEqual(@as(u8, @intCast(class + 1)), sa.classOf(slot + 1));
    }
}

test "small blocks: distinct slots of one chunk, aligned, lowest freed slot first" {
    var f = try Fixture.init(16);
    defer f.deinit();

    const a = try f.take(100);
    const b = try f.take(100);
    const c = try f.take(100);
    // 100 bytes is the 112-byte class: three slots of the first chunk.
    try testing.expectEqual(f.model.base, a.address);
    try testing.expectEqual(a.address + 112, b.address);
    try testing.expectEqual(b.address + 112, c.address);
    // Fresh memory from the OS reads zero: no fill is asked for.
    try testing.expect(a.zeroed and b.zeroed and c.zeroed);
    try testing.expectEqual(@as(usize, 1), f.model.set_read_writes);

    // A freed slot is the next one handed out, and it is not zero any more.
    try f.give(a);
    try f.give(b);
    const again = try f.take(97);
    try testing.expectEqual(a.address, again.address);
    try testing.expect(!again.zeroed);
    const again2 = try f.take(112);
    try testing.expectEqual(b.address, again2.address);
    // With no freed slot left, the next never-used one - still zero.
    const d = try f.take(105);
    try testing.expectEqual(c.address + 112, d.address);
    try testing.expect(d.zeroed);

    // Another class is another chunk. A block of zero bytes is a block.
    const other = try f.take(4096);
    try testing.expectEqual(@as(usize, 1), f.chunkOf(other));
    const empty = try f.take(0);
    try testing.expectEqual(@as(usize, 2), f.chunkOf(empty));

    const stats = f.allocator.stats();
    try testing.expectEqual(@as(u64, 6), stats.live_blocks);
    try testing.expectEqual(@as(u64, 4 * 112 + 4096 + 16), stats.live_bytes);
    try testing.expectEqual(@as(u64, 3), stats.high_water_chunks);
}

test "a full chunk: the class takes a second one, and a freed slot of the first is used before it" {
    var f = try Fixture.init(8);
    defer f.deinit();

    // 512 KiB: two slots to a chunk.
    const a = try f.take(sa.slot_max);
    const b = try f.take(sa.slot_max);
    const c = try f.take(sa.slot_max);
    try testing.expectEqual(@as(usize, 0), f.chunkOf(a));
    try testing.expectEqual(@as(usize, 0), f.chunkOf(b));
    try testing.expectEqual(@as(usize, 1), f.chunkOf(c));
    try f.give(a);
    const d = try f.take(sa.slot_max);
    try testing.expectEqual(a.address, d.address);
    const e = try f.take(sa.slot_max);
    try testing.expectEqual(@as(usize, 1), f.chunkOf(e));
    try f.give(b);
    try f.give(c);
    try f.give(d);
    try f.give(e);
}

test "an emptied chunk waits before it goes back, so a free and an allocation make no system call" {
    var f = try Fixture.init(8);
    defer f.deinit();

    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        const block = try f.take(64);
        try f.give(block);
    }
    // One chunk made accessible once; nothing discarded, recommitted or
    // decommitted by a thousand rounds.
    try testing.expectEqual(@as(usize, 1), f.model.set_read_writes);
    try testing.expectEqual(@as(usize, 0), f.model.discards + f.model.recommits + f.model.decommits);
    const stats = f.allocator.stats();
    try testing.expectEqual(@as(u64, 1), stats.retained_chunks);
    try testing.expectEqual(@as(u64, 64), stats.retained_bytes);
    try testing.expectEqual(@as(u64, 0), stats.live_blocks);

    // Asked to, it gives the waiting chunk back: at the top, so decommitted.
    f.allocator.releaseRetained();
    try f.model.check();
    try testing.expectEqual(@as(u64, 0), f.allocator.stats().high_water_chunks);
    try testing.expectEqual(PageState.inaccessible, f.model.states[0]);
}

test "at most 256 KiB of emptied chunks waits: the oldest go back to the OS, and a chunk dirtier than that at once" {
    var f = try Fixture.init(32);
    defer f.deinit();

    // One block in each of four classes - 104, 120, 96 and 320 KiB slots -
    // and a live block above them, so that what goes back is discarded, not
    // trimmed off the top.
    const a = try f.take(100 * 1024);
    const b = try f.take(120 * 1024);
    const c = try f.take(90 * 1024);
    const d = try f.take(300 * 1024);
    const top = try f.take(48);
    try testing.expectEqual(@as(usize, 4), f.chunkOf(top));

    // The first two empty: 104 + 120 KiB wait.
    try f.give(a);
    try f.give(b);
    try testing.expectEqual(@as(u64, 2), f.allocator.stats().retained_chunks);
    try testing.expectEqual(@as(u64, (104 + 120) * 1024), f.allocator.stats().retained_bytes);
    try testing.expectEqual(@as(usize, 0), f.model.discards);
    // The third: 320 KiB would wait, so the oldest goes back.
    try f.give(c);
    try testing.expectEqual(@as(u64, 2), f.allocator.stats().retained_chunks);
    try testing.expectEqual(@as(u64, (120 + 96) * 1024), f.allocator.stats().retained_bytes);
    try testing.expectEqual(@as(usize, 1), f.model.discards);
    try testing.expectEqual(PageState.discarded, f.model.states[0]);
    try testing.expectEqual(PageState.committed, f.model.states[1]);
    try testing.expectEqual(PageState.committed, f.model.states[2]);
    try testing.expectEqual(@as(u64, 1), f.allocator.stats().free_chunks);
    // A chunk with 320 KiB dirty does not wait.
    try f.give(d);
    try testing.expectEqual(@as(u64, 2), f.allocator.stats().retained_chunks);
    try testing.expectEqual(@as(usize, 2), f.model.discards);
    try testing.expectEqual(PageState.discarded, f.model.states[3]);

    try f.give(top);
}

test "the ring holds 16 emptied chunks: a seventeenth sends the oldest back" {
    var f = try Fixture.init(64);
    defer f.deinit();

    // One block in each of 17 classes (16 bytes each time larger), then one
    // above them all that stays.
    var blocks: [sa.ring_len + 1]sa.Block = undefined;
    for (&blocks, 0..) |*block, class| block.* = try f.take(sa.class_sizes[class]);
    const top = try f.take(sa.class_sizes[sa.ring_len + 1]);
    for (blocks[0..sa.ring_len]) |block| try f.give(block);
    try testing.expectEqual(@as(u64, sa.ring_len), f.allocator.stats().retained_chunks);
    try testing.expectEqual(@as(usize, 0), f.model.discards);

    try f.give(blocks[sa.ring_len]);
    try testing.expectEqual(@as(u64, sa.ring_len), f.allocator.stats().retained_chunks);
    try testing.expectEqual(@as(usize, 1), f.model.discards);
    try testing.expectEqual(PageState.discarded, f.model.states[0]);

    // A chunk that waits is used again without any page operation, and
    // leaves the ring.
    const recommits = f.model.recommits;
    const again = try f.take(sa.class_sizes[5]);
    try testing.expectEqual(blocks[5].address, again.address);
    try testing.expect(!again.zeroed);
    try testing.expectEqual(recommits, f.model.recommits);
    try testing.expectEqual(@as(u64, sa.ring_len - 1), f.allocator.stats().retained_chunks);
    try f.give(again);
    try f.give(top);
}

test "THE RULE: a chunk given back to the OS is recommitted before a block lies on it" {
    var f = try Fixture.init(32);
    defer f.deinit();

    // Four 2 MiB runs and a small block above them.
    var runs: [4]sa.Block = undefined;
    for (&runs) |*run| run.* = try f.take(2 * chunk);
    const top = try f.take(1000);
    try testing.expectEqual(@as(usize, 8), f.chunkOf(top));
    for (runs) |run| try testing.expect(run.zeroed);

    // Freed below a live block: discarded at once, not decommitted.
    try f.give(runs[1]);
    try f.give(runs[2]);
    try testing.expectEqual(@as(usize, 2), f.model.discards);
    try testing.expectEqual(@as(usize, 0), f.model.decommits);
    for (f.model.states[2..6]) |state| try testing.expectEqual(PageState.discarded, state);
    try testing.expectEqual(@as(u64, 4), f.allocator.stats().free_chunks);

    // A 3 MiB run takes the lowest three of them: recommitted first (the
    // model fails `take` on a discarded chunk), and not said to be zero.
    const reuse = try f.take(3 * chunk);
    try testing.expectEqual(@as(usize, 2), f.chunkOf(reuse));
    try testing.expect(!reuse.zeroed);
    try testing.expectEqual(@as(usize, 1), f.model.recommits);
    for (f.model.states[2..5]) |state| try testing.expectEqual(PageState.committed, state);
    try testing.expectEqual(PageState.discarded, f.model.states[5]);

    // A slot chunk taken from the free pool is recommitted too.
    const small = try f.take(20_000);
    try testing.expectEqual(@as(usize, 5), f.chunkOf(small));
    try testing.expect(!small.zeroed);
    try testing.expectEqual(@as(usize, 2), f.model.recommits);
    // Its later slots are not said to be zero either: the chunk's memory may
    // hold the bytes of the run that was there.
    const small2 = try f.take(20_000);
    try testing.expect(!small2.zeroed);

    try f.give(reuse);
    try f.give(small);
    try f.give(small2);
    try f.give(runs[0]);
    try f.give(runs[3]);
    try f.give(top);
}

test "free chunks at the top are decommitted, with the free ones under them, and read zero when used again" {
    var f = try Fixture.init(32);
    defer f.deinit();

    const a = try f.take(3 * chunk);
    const b = try f.take(2 * chunk);
    const c = try f.take(4 * chunk);
    try testing.expectEqual(@as(u64, 9), f.allocator.stats().high_water_chunks);

    // b is below c: discarded. Then c, at the top: decommitted in one
    // operation together with b's chunks.
    try f.give(b);
    try testing.expectEqual(@as(usize, 1), f.model.discards);
    try f.give(c);
    try testing.expectEqual(@as(usize, 1), f.model.discards);
    try testing.expectEqual(@as(usize, 1), f.model.decommits);
    try testing.expectEqual(@as(u64, 3), f.allocator.stats().high_water_chunks);
    try testing.expectEqual(@as(u64, 0), f.allocator.stats().free_chunks);
    for (f.model.states[3..9]) |state| try testing.expectEqual(PageState.inaccessible, state);

    // Used again: made accessible, zero.
    const d = try f.take(6 * chunk);
    try testing.expectEqual(@as(usize, 3), f.chunkOf(d));
    try testing.expect(d.zeroed);

    try f.give(d);
    try f.give(a);
    try testing.expectEqual(@as(u64, 0), f.allocator.stats().high_water_chunks);
    for (f.model.states) |state| try testing.expectEqual(PageState.inaccessible, state);
}

test "no room: null, nothing changed, and room again after a free" {
    var f = try Fixture.init(4);
    defer f.deinit();

    try testing.expectEqual(@as(?sa.Block, null), f.allocator.allocate(5 * chunk));
    try testing.expectEqual(@as(?sa.Block, null), f.allocator.allocate(std.math.maxInt(usize)));
    const a = try f.take(3 * chunk);
    try testing.expectEqual(@as(?sa.Block, null), f.allocator.allocate(2 * chunk));
    const small = try f.take(16);
    try testing.expectEqual(@as(?sa.Block, null), f.allocator.allocate(32));
    try testing.expectEqual(@as(?sa.Block, null), f.allocator.allocate(chunk));
    try f.give(a);
    const b = try f.take(2 * chunk);
    try testing.expectEqual(@as(usize, 0), f.chunkOf(b));
    try f.give(b);
    try f.give(small);
    try f.model.check();
}

test "the OS refuses: an allocation fails cleanly, a free keeps the chunks for later" {
    var f = try Fixture.init(16);
    defer f.deinit();

    // Growth refused: no block, no state.
    f.model.fail_set_read_write = true;
    try testing.expectEqual(@as(?sa.Block, null), f.allocator.allocate(100));
    try testing.expectEqual(@as(?sa.Block, null), f.allocator.allocate(2 * chunk));
    try testing.expectEqual(@as(u64, 0), f.allocator.stats().high_water_chunks);
    f.model.fail_set_read_write = false;

    const a = try f.take(2 * chunk);
    const b = try f.take(2 * chunk);
    const c = try f.take(100);

    // Decommit refused: the top chunks stay accessible, in the free pool,
    // discarded - and are recommitted when taken.
    try f.give(c);
    f.model.fail_decommit = true;
    f.allocator.releaseRetained();
    try f.give(b);
    try testing.expectEqual(@as(u64, 5), f.allocator.stats().high_water_chunks);
    try testing.expectEqual(@as(u64, 3), f.allocator.stats().free_chunks);
    f.model.fail_decommit = false;

    // Recommit refused: no block; the chunks stay free.
    f.model.fail_recommit = true;
    try testing.expectEqual(@as(?sa.Block, null), f.allocator.allocate(2 * chunk));
    try testing.expectEqual(@as(u64, 3), f.allocator.stats().free_chunks);
    f.model.fail_recommit = false;
    const d = try f.take(2 * chunk);
    try testing.expectEqual(b.address, d.address);
    try testing.expect(!d.zeroed);

    // Discard refused: the chunks are free all the same, and a block on
    // them is recommitted (which the OS takes as nothing to do).
    const e = try f.take(100);
    f.model.fail_discard = true;
    try f.give(a);
    try testing.expectEqual(@as(u64, 2), f.allocator.stats().free_chunks);
    f.model.fail_discard = false;
    const g = try f.take(2 * chunk);
    try testing.expectEqual(a.address, g.address);

    try f.give(g);
    try f.give(d);
    try f.give(e);
}

test "a pointer that is not a live block is refused" {
    var f = try Fixture.init(8);
    defer f.deinit();

    const small = try f.take(100);
    const run = try f.take(2 * chunk);
    const top = try f.take(5000);

    try testing.expectError(error.InvalidFree, f.allocator.free(f.model.base - 16));
    try testing.expectError(error.InvalidFree, f.allocator.free(f.model.base + 100 * chunk));
    // Inside a slot, and a slot never handed out.
    try testing.expectError(error.InvalidFree, f.allocator.free(small.address + 16));
    try testing.expectError(error.InvalidFree, f.allocator.free(small.address + 112));
    // Inside a run: past its start, and in its second chunk.
    try testing.expectError(error.InvalidFree, f.allocator.free(run.address + 16));
    try testing.expectError(error.InvalidFree, f.allocator.free(run.address + chunk));
    // Twice.
    try f.give(small);
    try testing.expectError(error.InvalidFree, f.allocator.free(small.address));
    try f.give(run);
    try testing.expectError(error.InvalidFree, f.allocator.free(run.address));
    try f.give(top);
    // Twice, in a chunk that waits to go back.
    try testing.expectError(error.InvalidFree, f.allocator.free(top.address));
    try f.model.check();
}

test "ten thousand random allocations and frees: no two live blocks overlap, every block lies on committed memory" {
    var f = try Fixture.init(96);
    defer f.deinit();

    const Live = struct { block: sa.Block, size: usize };
    var live: std.ArrayList(Live) = .empty;
    defer live.deinit(testing.allocator);
    // One bit per 16 bytes: owned by a live block.
    var owned = try std.DynamicBitSetUnmanaged.initEmpty(testing.allocator, 96 * granules_per_chunk);
    defer owned.deinit(testing.allocator);

    var prng = std.Random.DefaultPrng.init(0xab1);
    const random = prng.random();
    var round: usize = 0;
    while (round < 10_000) : (round += 1) {
        const allocate = live.items.len == 0 or random.uintLessThan(u32, 100) < 55;
        if (allocate) {
            // Mostly small, some up to a chunk, a few runs.
            const size: usize = switch (random.uintLessThan(u32, 100)) {
                0...59 => random.uintLessThan(usize, 2048),
                60...89 => random.uintLessThan(usize, 300 * 1024),
                90...96 => sa.slot_max - random.uintLessThan(usize, 64 * 1024),
                else => chunk + random.uintLessThan(usize, 3 * chunk),
            };
            const block = f.allocator.allocate(size) orelse continue;
            try f.model.use(block, size);
            const first = (block.address - f.model.base) / granule;
            const last = (block.address - f.model.base + @max(size, 1) + granule - 1) / granule;
            var at = first;
            while (at < last) : (at += 1) try testing.expect(!owned.isSet(at));
            owned.setRangeValue(.{ .start = first, .end = last }, true);
            try live.append(testing.allocator, .{ .block = block, .size = size });
        } else {
            const victim = live.swapRemove(random.uintLessThan(usize, live.items.len));
            const first = (victim.block.address - f.model.base) / granule;
            const last = (victim.block.address - f.model.base + @max(victim.size, 1) + granule - 1) / granule;
            owned.setRangeValue(.{ .start = first, .end = last }, false);
            try f.allocator.free(victim.block.address);
        }
        try f.model.check();
        try testing.expect(f.allocator.stats().retained_bytes <= sa.retained_max);
        try testing.expectEqual(@as(u64, live.items.len), f.allocator.stats().live_blocks);
    }
    // The page operations really happened in this run.
    try testing.expect(f.model.discards > 0 and f.model.recommits > 0 and f.model.decommits > 0);

    for (live.items) |entry| try f.allocator.free(entry.block.address);
    f.allocator.releaseRetained();
    try f.model.check();
    const stats = f.allocator.stats();
    try testing.expectEqual(@as(u64, 0), stats.live_blocks);
    try testing.expectEqual(@as(u64, 0), stats.live_bytes);
    try testing.expectEqual(@as(u64, 0), stats.high_water_chunks);
    for (f.model.states) |state| try testing.expectEqual(PageState.inaccessible, state);
}
