//! A Browser's heap (runtime.BrowserScope.Heap, src/runtime/browser_heap.zig;
//! lane h1, phase H1 of tmp/redesign/node-memory-architecture.md as amended
//! by node-memory-plan-v2.md): the per-target profiles and their layouts,
//! the reservation ladder, `Link` and `heapOf`, and BrowserScope.reserveHeap.
//!
//! The platform here is a fake shaped like `@import("platform")` over real
//! pages (mmap, mprotect), which records every call and fails reservations
//! above a size: the ladder and the unsupported path are tested exactly,
//! without depending on what the machine's address space happens to allow.
//! The real platform's behaviour is tests/platform/h1_address_space_test.zig;
//! the two together, with a Browser, are tests/html/h1_browser_heap_test.zig
//! and tests/browser/h1_browser_heap_test.zig.

const std = @import("std");
const builtin = @import("builtin");
const runtime = @import("runtime");

const testing = std.testing;
const BrowserScope = runtime.BrowserScope;
const Heap = BrowserScope.Heap;

const MiB: u64 = 1024 * 1024;
const GiB: u64 = 1024 * MiB;

// ---------------------------------------------------------------------------
// The fake platform
// ---------------------------------------------------------------------------

const Call = struct { size: usize, alignment: usize, offset: usize, label: u8 };

const Fake = struct {
    pub const capabilities = struct {
        pub const address_space: Support = .native;
    };
    pub const Support = enum { native, unsupported };
    pub const AddressLabel = enum(u8) { node_cage = 0, objects = 1, bytes = 2, heap_metadata = 3 };
    pub const PageAccess = enum(u8) { none = 0, read = 1, read_write = 2 };
    pub const AddressRange = extern struct { base: usize, size: usize };
    pub const BrowserPlatform = opaque {};
    pub const Error = error{ OutOfMemory, NotSupported, AccessDenied, Io };

    const State = struct {
        /// Reservations larger than this fail with OutOfMemory.
        limit: usize = std.math.maxInt(usize),
        reserves: [16]Call = undefined,
        reserve_count: usize = 0,
        labels: [16]Call = undefined,
        label_count: usize = 0,
        releases: usize = 0,
        protects_none: usize = 0,
        /// What fillBrowserRandom answers for a Browser, when set.
        browser_stream: ?u64 = null,
        random_counter: u64 = 0x9e37_79b9_7f4a_7c15,
    };
    var state: State = .{};

    fn reset(limit: usize) void {
        state = .{ .limit = limit };
    }

    pub fn pageSize() usize {
        return std.heap.pageSize();
    }

    pub fn reserveAddressSpace(size: usize, alignment: usize, alignment_offset: usize, label: AddressLabel) Error!AddressRange {
        if (state.reserve_count < state.reserves.len) state.reserves[state.reserve_count] = .{ .size = size, .alignment = alignment, .offset = alignment_offset, .label = @backingInt(label) };
        state.reserve_count += 1;
        if (size > state.limit) return error.OutOfMemory;
        const total = size + alignment;
        const flags: std.c.MAP = if (comptime builtin.os.tag == .linux)
            .{ .TYPE = .PRIVATE, .ANONYMOUS = true, .NORESERVE = true }
        else
            .{ .TYPE = .PRIVATE, .ANONYMOUS = true };
        const raw_ptr = std.c.mmap(null, total, .{}, flags, -1, 0);
        if (raw_ptr == std.c.MAP_FAILED) return error.OutOfMemory;
        const raw = @intFromPtr(raw_ptr);
        const base = raw + ((alignment_offset -% raw) & (alignment - 1));
        if (base > raw) _ = std.c.munmap(@ptrFromInt(raw), base - raw);
        if (raw + total > base + size) _ = std.c.munmap(@ptrFromInt(base + size), raw + total - base - size);
        return .{ .base = base, .size = size };
    }

    pub fn labelAddressSpace(range: AddressRange, offset: usize, length: usize, label: AddressLabel) void {
        _ = range;
        if (state.label_count < state.labels.len) state.labels[state.label_count] = .{ .size = length, .alignment = 0, .offset = offset, .label = @backingInt(label) };
        state.label_count += 1;
    }

    pub fn commitPages(range: AddressRange, offset: usize, length: usize) Error!void {
        if (std.c.mprotect(@ptrFromInt(range.base + offset), length, .{ .READ = true, .WRITE = true }) != 0) return error.Io;
    }

    pub fn decommitPages(range: AddressRange, offset: usize, length: usize) Error!void {
        if (std.c.madvise(@ptrFromInt(range.base + offset), length, std.c.MADV.DONTNEED) != 0) return error.Io;
    }

    pub fn protectPages(range: AddressRange, offset: usize, length: usize, access: PageAccess) Error!void {
        const prot: std.c.PROT = switch (access) {
            .none => .{},
            .read => .{ .READ = true },
            .read_write => .{ .READ = true, .WRITE = true },
        };
        if (access == .none) state.protects_none += 1;
        if (std.c.mprotect(@ptrFromInt(range.base + offset), length, prot) != 0) return error.Io;
    }

    pub fn releaseAddressSpace(range: AddressRange) void {
        state.releases += 1;
        _ = std.c.munmap(@ptrFromInt(range.base), range.size);
    }

    pub fn fillRandom(bytes: []u8) void {
        for (bytes) |*b| {
            state.random_counter = state.random_counter *% 6364136223846793005 +% 1442695040888963407;
            b.* = @truncate(state.random_counter >> 56);
        }
    }

    pub fn fillBrowserRandom(browser: *BrowserPlatform, bytes: []u8) bool {
        _ = browser;
        const value = state.browser_stream orelse return false;
        std.mem.writeInt(u64, bytes[0..8], value, .little);
        return true;
    }
};

/// The same, without address space: kit/headless's answer.
const NoAddressSpace = struct {
    pub const capabilities = struct {
        pub const address_space: Fake.Support = .unsupported;
    };
    pub const BrowserPlatform = Fake.BrowserPlatform;
    pub const fillRandom = Fake.fillRandom;
    pub const fillBrowserRandom = Fake.fillBrowserRandom;
};

/// Release what the Debug graveyard keeps, before and after a test that
/// ends heaps: the process as the test found it.
fn emptyGraveyard() void {
    Heap.releaseKeptReservations();
}

// ---------------------------------------------------------------------------
// Profiles and layouts
// ---------------------------------------------------------------------------

fn targetOf(comptime arch: std.Target.Cpu.Arch, comptime os: std.Target.Os.Tag) std.Target {
    return .{
        .cpu = std.Target.Cpu.baseline(arch, .{ .tag = os, .version_range = .default(arch, os, .none) }),
        .os = .{ .tag = os, .version_range = .default(arch, os, .none) },
        .abi = .none,
        .ofmt = .elf,
    };
}

test "profiles: 64-bit desktop is full, 64-bit iOS-family is small, 32-bit pointers have no cage" {
    try testing.expectEqual(Heap.Profile.full, Heap.profileFor(targetOf(.x86_64, .linux)));
    try testing.expectEqual(Heap.Profile.full, Heap.profileFor(targetOf(.aarch64, .macos)));
    try testing.expectEqual(Heap.Profile.full, Heap.profileFor(targetOf(.aarch64, .linux)));
    try testing.expectEqual(Heap.Profile.small, Heap.profileFor(targetOf(.aarch64, .ios)));
    try testing.expectEqual(Heap.Profile.small, Heap.profileFor(targetOf(.aarch64, .watchos)));
    try testing.expectEqual(Heap.Profile.pointer32, Heap.profileFor(targetOf(.arm, .linux)));
    try testing.expectEqual(Heap.Profile.pointer32, Heap.profileFor(targetOf(.wasm32, .freestanding)));
    // This build's.
    try testing.expectEqual(Heap.profileFor(builtin.target), Heap.profile);
}

/// Every property the layout must hold, for one geometry.
fn expectLayoutSound(comptime g: Heap.Geometry) !void {
    const l = comptime Heap.layoutFor(g);
    const super = Heap.super_page_bytes;
    try testing.expect(std.math.isPowerOfTwo(l.window_bytes));
    // The cage is at the window's base, of the geometry's size, its first
    // and last super pages guards.
    try testing.expectEqual(@as(u64, 0), l.cage.offset);
    try testing.expectEqual(g.cage_bytes, l.cage.bytes);
    try testing.expectEqual(super, l.first_node_offset);
    try testing.expectEqual(l.cage.end() - super, l.cage_top_guard.offset);
    // 32-bit links reach the whole cage (exactly, on desktop).
    try testing.expect((@as(u64, 1) << 32) << g.cage_shift >= g.cage_bytes);
    if (g.profile == .full) try testing.expectEqual(g.cage_bytes, (@as(u64, 1) << 32) << g.cage_shift);
    // The metadata is OUTSIDE the cage (oss R1), after a guard super page.
    try testing.expect(l.metadata.offset >= l.cage.end() + super);
    try testing.expect(l.header_offset >= l.metadata.offset + Heap.super_page_guard_bytes);
    try testing.expect(l.span_table.offset >= l.header_offset + 4096);
    try testing.expect(l.span_table.offset >= l.metadata.offset and l.span_table.end() <= l.bitmaps.offset);
    try testing.expect(l.bitmaps.end() <= l.tables.offset);
    try testing.expect(l.tables.end() <= l.metadata.end());
    try testing.expectEqual(l.tables.offset, l.tablePart(.names).offset);
    // The header is not in its super page's first span (oss R19).
    try testing.expect(l.header_offset % super >= Heap.super_page_guard_bytes);
    // A guard super page after the metadata; the cage-alone rung ends there.
    try testing.expectEqual(l.metadata.end() + super, l.cage_alone_end);
    // Everything is super-page aligned and inside the window.
    for ([_]u64{ l.metadata.offset, l.metadata.bytes, l.span_table.offset, l.bitmaps.offset, l.tables.offset, l.objects.offset, l.bytes.offset, l.cage_alone_end }) |v| {
        try testing.expectEqual(@as(u64, 0), v % super);
    }
    try testing.expect(l.cage_alone_end <= l.window_bytes);
    if (g.profile == .full) {
        // Objects after the metadata, bytes in the upper half after a guard,
        // neither overlapping anything.
        try testing.expectEqual(l.cage_alone_end, l.objects.offset);
        try testing.expect(l.objects.bytes > 0);
        try testing.expectEqual(l.window_bytes / 2, l.objects.end());
        try testing.expectEqual(l.window_bytes / 2 + super, l.bytes.offset);
        try testing.expectEqual(l.window_bytes, l.bytes.end());
    } else {
        try testing.expectEqual(@as(u64, 0), l.objects.bytes);
        try testing.expectEqual(@as(u64, 0), l.bytes.bytes);
    }
}

test "the full layout holds for the 4 GiB cage at shift 0 and the 32 GiB cage at shift 3 (H4 decides between them)" {
    try expectLayoutSound(.{ .profile = .full, .cage_bytes = 4 * GiB, .cage_shift = 0 });
    try expectLayoutSound(.{ .profile = .full, .cage_bytes = 32 * GiB, .cage_shift = 3 });
    const four = comptime Heap.layoutFor(.{ .profile = .full, .cage_bytes = 4 * GiB, .cage_shift = 0 });
    // arch 0's map, with the metadata moved out of the cage.
    try testing.expectEqual(64 * GiB, four.window_bytes);
    try testing.expectEqual(4 * GiB + 2 * MiB, four.metadata.offset);
    try testing.expectEqual(32 * GiB + 2 * MiB, four.bytes.offset);
    const thirty_two = comptime Heap.layoutFor(.{ .profile = .full, .cage_bytes = 32 * GiB, .cage_shift = 3 });
    try testing.expectEqual(128 * GiB, thirty_two.window_bytes);
}

test "the small profile: a fixed 1 GiB cage and its metadata in a 2 GiB window, no general pools, no halving" {
    const g = comptime Heap.geometryFor(.small);
    try testing.expectEqual(1 * GiB, g.cage_bytes);
    try expectLayoutSound(g);
    const l = comptime Heap.layoutFor(g);
    try testing.expectEqual(2 * GiB, l.window_bytes);
    try testing.expectEqual(g.cage_bytes, l.min_cage_bytes);
}

test "pointer32: no cage, no reservation, and a Link is 4 bytes" {
    const l = comptime Heap.layoutFor(Heap.geometryFor(.pointer32));
    try testing.expectEqual(@as(u64, 0), l.window_bytes);
    try testing.expectEqual(@as(usize, 4), @sizeOf(Heap.LinkIn(Heap.geometryFor(.pointer32), u64)));
    try testing.expectEqual(@as(usize, 4), @sizeOf(Heap.Link(u64)));
}

// ---------------------------------------------------------------------------
// Links
// ---------------------------------------------------------------------------

test "a link round-trips at 64 KiB and at the cage's end, at shift 0 and at shift 3" {
    inline for ([_]Heap.Geometry{
        .{ .profile = .full, .cage_bytes = 4 * GiB, .cage_shift = 0 },
        .{ .profile = .full, .cage_bytes = 32 * GiB, .cage_shift = 3 },
    }) |g| {
        const L = Heap.LinkIn(g, u64);
        // Addresses only: nothing is read through them.
        const cage: usize = 7 * @as(usize, @intCast(g.cage_bytes));
        const holder: *const u64 = @ptrFromInt(cage + 2 * MiB + 64);
        for ([_]usize{ 64 * 1024, @as(usize, @intCast(g.cage_bytes)) - 16 }) |offset| {
            const target: *const u64 = @ptrFromInt(cage + offset);
            const link = L.to(target, holder);
            try testing.expect(!link.isNone());
            try testing.expectEqual(@intFromPtr(target), @intFromPtr(link.get(holder).?));
            try testing.expect(link.eql(target, holder));
        }
        try testing.expect(L.none.get(holder) == null);
        try testing.expect(L.to(null, holder).isNone());
        // Another cage's block cannot be linked: a production check.
        const elsewhere: *const u64 = @ptrFromInt(cage + @as(usize, @intCast(g.cage_bytes)) + 4096);
        try testing.expectError(error.OtherCage, L.encode(elsewhere, holder));
        try testing.expect(!L.to(@ptrFromInt(cage + 4096), holder).eql(elsewhere, holder));
    }
    // At shift 3 a target must be 8-aligned in the cage.
    const L3 = Heap.LinkIn(.{ .profile = .full, .cage_bytes = 32 * GiB, .cage_shift = 3 }, u8);
    const cage3: usize = 32 * GiB;
    try testing.expectError(error.Misaligned, L3.encode(@ptrFromInt(cage3 + 4097), @ptrFromInt(cage3 + 8)));
}

test "every link below the first node super page decodes into the cage's guard super page" {
    inline for ([_]Heap.Geometry{
        .{ .profile = .full, .cage_bytes = 4 * GiB, .cage_shift = 0 },
        .{ .profile = .full, .cage_bytes = 32 * GiB, .cage_shift = 3 },
        comptime Heap.geometryFor(.small),
    }) |g| {
        const l = comptime Heap.layoutFor(g);
        const L = Heap.LinkIn(g, u8);
        const cage: usize = 3 * @as(usize, @intCast(g.cage_bytes));
        const holder: *const u8 = @ptrFromInt(cage + 5 * MiB);
        const below: u32 = @intCast(l.first_node_offset >> g.cage_shift);
        for ([_]u32{ 1, 0x10, 0xffff, below / 2, below - 1 }) |value| {
            const decoded = @intFromPtr((@as(L, @fromBackingInt(value))).get(holder).?);
            try testing.expect(decoded >= cage and decoded < cage + l.first_node_offset);
        }
        // And no link value at all reaches the metadata, past the cage: the
        // highest decodes inside it; in a cage smaller than 32 bits reach
        // (the small profile's 1 GiB) a higher one is refused, never decoded.
        const highest: u32 = @intCast(@min(std.math.maxInt(u32), (g.cage_bytes >> g.cage_shift) - 1));
        const top = @intFromPtr((@as(L, @fromBackingInt(highest))).get(holder).?);
        try testing.expect(top < cage + l.cage.end() and top < cage + l.metadata.offset);
        if (highest < std.math.maxInt(u32)) {
            try testing.expectError(error.OutsideCage, (@as(L, @fromBackingInt(highest + 1))).decode(holder));
            try testing.expectError(error.OutsideCage, (@as(L, @fromBackingInt(std.math.maxInt(u32)))).decode(holder));
        }
    }
}

// ---------------------------------------------------------------------------
// The ladder
// ---------------------------------------------------------------------------

test "the ladder's first rung is the full window, aligned to itself, its parts labelled" {
    emptyGraveyard();
    defer emptyGraveyard();
    Fake.reset(std.math.maxInt(usize));
    const heap = try Heap.BrowserHeap.reserve(Heap.Platform.of(Fake), testing.allocator, null);
    defer heap.release(testing.allocator);
    const l = Heap.layout;
    try testing.expectEqual(Heap.Rung.full, heap.rung);
    try testing.expect(heap.general_pools);
    try testing.expectEqual(@as(usize, 1), Fake.state.reserve_count);
    try testing.expectEqual(@as(usize, @intCast(l.window_bytes)), Fake.state.reserves[0].size);
    try testing.expectEqual(@as(usize, @intCast(l.window_bytes)), Fake.state.reserves[0].alignment);
    try testing.expectEqual(@as(usize, 0), Fake.state.reserves[0].offset);
    try testing.expectEqual(@as(usize, 0), heap.window_base % @as(usize, @intCast(l.window_bytes)));
    try testing.expectEqual(heap.window_base + @as(usize, @intCast(l.header_offset)), @intFromPtr(heap));
    try testing.expectEqual(Heap.BrowserHeap.magic_value, heap.magic);
    try testing.expectEqual(@as(usize, 0), heap.cage_lo);
    // Labelled: the cage, the metadata, the bytes pool (the rest stays
    // `objects`, the reservation's own label).
    var cage = false;
    var metadata = false;
    var bytes = false;
    for (Fake.state.labels[0..Fake.state.label_count]) |c| {
        if (c.label == 0 and c.offset == 0 and c.size == l.cage.bytes) cage = true;
        if (c.label == 3 and c.offset == l.metadata.offset and c.size == l.metadata.bytes) metadata = true;
        if (c.label == 2 and c.offset == l.window_bytes / 2) bytes = true;
    }
    try testing.expect(cage and metadata and bytes);
}

test "the ladder: the cage alone, then smaller cages at the top of the cage window, then OutOfMemory" {
    if (Heap.profile != .full) return error.SkipZigTest;
    emptyGraveyard();
    defer emptyGraveyard();
    const l = Heap.layout;

    // Too small for the window: the cage and its metadata.
    Fake.reset(@intCast(l.window_bytes - 1));
    {
        const heap = try Heap.BrowserHeap.reserve(Heap.Platform.of(Fake), testing.allocator, null);
        defer heap.release(testing.allocator);
        try testing.expectEqual(Heap.Rung.cage_alone, heap.rung);
        try testing.expect(!heap.general_pools);
        try testing.expectEqual(@as(usize, @intCast(l.cage_alone_end)), heap.reserved.size);
        try testing.expectEqual(heap.window_base, heap.reserved.base);
    }

    // Too small for the cage alone: the largest smaller cage that fits, at
    // the top of the cage window, the window base still aligned.
    const half = l.cage.bytes / 2;
    Fake.reset(@intCast(l.cage_alone_end - half));
    {
        const heap = try Heap.BrowserHeap.reserve(Heap.Platform.of(Fake), testing.allocator, null);
        defer heap.release(testing.allocator);
        try testing.expectEqual(Heap.Rung.smaller_cage, heap.rung);
        try testing.expectEqual(@as(usize, @intCast(half)), heap.cage_lo);
        try testing.expectEqual(heap.window_base + @as(usize, @intCast(half)), heap.reserved.base);
        try testing.expectEqual(@as(usize, 0), heap.window_base % @as(usize, @intCast(l.window_bytes)));
        // heapOf from a node address in the smaller cage finds it.
        try testing.expectEqual(heap, Heap.heapOf(@ptrFromInt(heap.at(half + 3 * MiB))));
        const last = Fake.state.reserves[Fake.state.reserve_count - 1];
        try testing.expectEqual(@as(usize, @intCast(half)), last.offset);
        try testing.expectEqual(@as(usize, @intCast(l.window_bytes)), last.alignment);
    }

    // Too small for the smallest cage: a clean OutOfMemory, nothing left
    // reserved.
    Fake.reset(@intCast(l.cage_alone_end - l.cage.bytes + l.min_cage_bytes - 1));
    try testing.expectError(error.OutOfMemory, Heap.BrowserHeap.reserve(Heap.Platform.of(Fake), testing.allocator, null));
    // full, cage alone, 2 GiB, 1 GiB, 512 MiB, 256 MiB.
    try testing.expectEqual(@as(usize, 6), Fake.state.reserve_count);
}

test "a platform without address space: reserve fails with NotSupported and reserves nothing" {
    Fake.reset(std.math.maxInt(usize));
    try testing.expectError(error.NotSupported, Heap.BrowserHeap.reserve(Heap.Platform.of(NoAddressSpace), testing.allocator, null));
    try testing.expectEqual(@as(usize, 0), Fake.state.reserve_count);
}

// ---------------------------------------------------------------------------
// heapOf
// ---------------------------------------------------------------------------

test "heapOf finds the header from any address of the window, ignoring the top byte" {
    emptyGraveyard();
    defer emptyGraveyard();
    Fake.reset(std.math.maxInt(usize));
    const heap = try Heap.BrowserHeap.reserve(Heap.Platform.of(Fake), testing.allocator, null);
    defer heap.release(testing.allocator);
    const l = Heap.layout;
    const offsets = [_]u64{ l.first_node_offset, l.cage.bytes / 2 + 16, l.cage.end() - 16, l.metadata.offset + 4096, l.objects.offset + 48, l.bytes.offset + 1, l.window_bytes - 8 };
    for (offsets) |offset| {
        if (offset >= heap.reserved.size) continue;
        try testing.expectEqual(heap, Heap.heapOf(@ptrFromInt(heap.at(offset))));
        // A tag in bits 56-63 (top-byte-ignore) does not move it.
        try testing.expectEqual(heap, Heap.heapOf(@ptrFromInt(heap.at(offset) | (@as(usize, 0x5a) << 56))));
    }
}

// ---------------------------------------------------------------------------
// BrowserScope.reserveHeap
// ---------------------------------------------------------------------------

test "reserveHeap names the scope, seeds its generations in [1, 2^55), and the scope's end releases the reservation" {
    emptyGraveyard();
    defer emptyGraveyard();
    Fake.reset(std.math.maxInt(usize));
    var scope = BrowserScope.init(testing.allocator);
    try scope.reserveHeap(Fake, null);
    const heap = scope.heap.?;
    try testing.expectEqual(&scope, BrowserScope.ofHeap(heap));
    try testing.expectEqual(&scope, BrowserScope.ofHeap(Heap.heapOf(@ptrFromInt(heap.at(Heap.layout.first_node_offset)))));
    try testing.expect(heap.generation_seed >= 1 and heap.generation_seed < Heap.BrowserHeap.generation_seed_limit);
    try testing.expect(scope.slab.next_generation >= heap.generation_seed);
    scope.deinit();
    try testing.expect(scope.heap == null);
    if (builtin.optimize == .debug) {
        // Kept inaccessible, not yet released.
        try testing.expectEqual(@as(usize, 0), Fake.state.releases);
        try testing.expectEqual(@as(usize, 1), Heap.keptReservations());
    } else {
        try testing.expectEqual(@as(usize, 1), Fake.state.releases);
    }
}

test "a Browser with a random stream of its own seeds its generations from it, so a seeded run replays them" {
    emptyGraveyard();
    defer emptyGraveyard();
    Fake.reset(std.math.maxInt(usize));
    Fake.state.browser_stream = 0x0123_4567_89ab_cdef;
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    var browser_state: u8 = 0;
    try scope.reserveHeap(Fake, @ptrCast(&browser_state));
    try testing.expectEqual(1 + @as(u64, 0x0123_4567_89ab_cdef) % (Heap.BrowserHeap.generation_seed_limit - 1), scope.heap.?.generation_seed);
}

test "two scopes' heaps are disjoint windows with different generation seeds" {
    emptyGraveyard();
    defer emptyGraveyard();
    Fake.reset(std.math.maxInt(usize));
    var a = BrowserScope.init(testing.allocator);
    defer a.deinit();
    var b = BrowserScope.init(testing.allocator);
    defer b.deinit();
    try a.reserveHeap(Fake, null);
    try b.reserveHeap(Fake, null);
    try testing.expect(a.heap.?.window_base != b.heap.?.window_base);
    try testing.expect(a.heap.?.generation_seed != b.heap.?.generation_seed);
}

test "a scope that cannot reserve keeps no heap and still ends cleanly" {
    Fake.reset(0);
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    try testing.expectError(error.OutOfMemory, scope.reserveHeap(Fake, null));
    try testing.expect(scope.heap == null);
    var unsupported = BrowserScope.init(testing.allocator);
    defer unsupported.deinit();
    try testing.expectError(error.NotSupported, unsupported.reserveHeap(NoAddressSpace, null));
}

test "Debug builds keep the last 4 released reservations inaccessible; the fifth release gives the oldest back" {
    if (builtin.optimize != .debug) return error.SkipZigTest;
    emptyGraveyard();
    defer emptyGraveyard();
    Fake.reset(std.math.maxInt(usize));
    for (0..5) |_| {
        const heap = try Heap.BrowserHeap.reserve(Heap.Platform.of(Fake), testing.allocator, null);
        heap.release(testing.allocator);
    }
    try testing.expectEqual(@as(usize, 4), Heap.keptReservations());
    try testing.expectEqual(@as(usize, 1), Fake.state.releases);
    try testing.expectEqual(@as(usize, 5), Fake.state.protects_none);
}

test "the heap commits only its header: the rest of the window stays reserved" {
    emptyGraveyard();
    defer emptyGraveyard();
    Fake.reset(std.math.maxInt(usize));
    const heap = try Heap.BrowserHeap.reserve(Heap.Platform.of(Fake), testing.allocator, null);
    defer heap.release(testing.allocator);
    try testing.expectEqual(std.mem.alignForward(usize, @sizeOf(Heap.BrowserHeap), std.heap.pageSize()), heap.committed_bytes);
    // Commit and retire a span in the second node super page, as H2 will.
    const span = @max(16 * 1024, std.heap.pageSize());
    const at: usize = @intCast(Heap.layout.first_node_offset + span);
    try heap.commit(at, span);
    const p: *volatile u8 = @ptrFromInt(heap.at(at));
    p.* = 1;
    try heap.retire(at, span);
    try testing.expectEqual(std.mem.alignForward(usize, @sizeOf(Heap.BrowserHeap), std.heap.pageSize()), heap.committed_bytes);
}
