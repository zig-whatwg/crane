//! Hash maps keyed by an object's address, each table with a seed of its own.
//!
//! Not Infra's: the map every instance-keyed table in Crane uses - the V8
//! wrapper cache, the InstanceRegistry and its siblings, the DOM's side tables
//! keyed by `*runtime.Instance` - so that a new one gets the seed by default.
//!
//! ## Why a seed per table
//!
//! `std.AutoHashMap` hashes every key with Wyhash under seed 0, and std's
//! table probes linearly from `hash & (capacity - 1)`. So in every std map of
//! the same capacity a given address has the SAME home slot. Two things then
//! line up (lane v8order1's tests-v8 seed 0x02e77638, lane hashclust1):
//! - a teardown frees objects by walking a map keyed by them - the wrapper
//!   cache's end walks `cache` - so it frees them in that map's slot order,
//!   which is the order of their home slots;
//! - the slab's free list is LIFO, so it hands those addresses out again in
//!   the reverse of that order.
//! The next map keyed by them receives its keys sorted by home slot. When that
//! map is smaller than the one walked, several keys share each home, every
//! insert lands beside the previous one, and the keys, and the tombstones they
//! leave, fill ONE run of contiguous slots: primary clustering. A miss walks
//! the run. tests/v8/engine_pending_activity_test's side map had a run of
//! 1,912 slots and a mean miss of 138-446 slots, against 1 with the same keys
//! issued in any other order. TombstoneGuard bounds how many tombstones there
//! are, not where they are, so it did not help.
//!
//! The engines that met this first break the alignment between tables:
//! - Abseil's SwissTable mixes a per-table seed into each hash and draws a new
//!   one whenever the table gets a new backing array
//!   (absl/container/internal/raw_hash_set.cc: `RandomSeed()` - a counter
//!   advanced per table - and `generate_new_seed` on every resize; the header
//!   calls it the "per table hash salt").
//! - Rust's std gives every HashMap its own SipHash key, the thread's keys
//!   with one of them incremented per map (library/std/src/hash/random.rs,
//!   `RandomState::new`), since rust-lang/rust#36481 showed that one map
//!   inserted into another in iteration order goes quadratic.
//! - WebKit's WTF HashTable keeps one fixed hash per type (PtrHash) but probes
//!   quadratically (`i = (i + probeCount) & sizeMask`, HashTable.h), so keys
//!   with neighbouring homes do not share a probe sequence. std's probe is
//!   linear and not ours to change; the hash is.
//!
//! So each table here hashes with Wyhash under a seed of its own, and the
//! context keeps Wyhash's seeded state, so a hash costs what std's seed-0 one
//! does (two 128-bit multiplies for an 8-byte key) and returns exactly what
//! `std.hash.Wyhash.hash(seed, std.mem.asBytes(&key))` would.
//!
//! ## Which seed, and when
//!
//! A table draws a seed - as Abseil does - whenever it has no live entry and
//! its slots are about to be laid out again: at its first allocation (also
//! after `clearAndFree`), at `clearRetainingCapacity`, and at `rehash`, which
//! re-places every entry under the new seed (std's in-place rehash takes any
//! context; TombstoneGuard calls it). A table that keeps its entries across a
//! grow keeps its seed: std grows inside `put`, with the context it has.
//!
//! The seeds are DETERMINISTIC: `nextSeed` is a counter mixed by SplitMix64,
//! never a clock or the OS's entropy, so a single-threaded sequence of tables
//! draws the same seeds in every run (a seeded test run replays). Keys are
//! addresses, so a table's iteration order already varied between runs with
//! the address-space layout; the seed adds no variation of its own.
//!
//! The types mirror std's API (`put`, `get`, `getOrPut`, `fetchRemove`,
//! `iterator`, ...), keep std's table in a field named `unmanaged`, and have
//! `rehash()`, `capacity()` and `count()`, so `infra.tombstones`
//! (TombstoneGuard, `slotCounts`, `meanMissProbe`) works on them unchanged.

const std = @import("std");

const max_load_percentage = std.hash_map.default_max_load_percentage;

// process-wide: the one seed source for every address-keyed table in the process; it holds no instance's state (each table copies the value it draws), and an atomic fetch-add hands distinct values to any number of Browsers on any number of threads.
var seed_counter: std.atomic.Value(u64) = .init(0);

/// The next table's seed: the counter, mixed by SplitMix64 (a bijection, so
/// no two draws in 2^64 are equal, and consecutive draws share no bits).
pub fn nextSeed() u64 {
    return splitMix64(seed_counter.fetchAdd(1, .monotonic));
}

fn splitMix64(n: u64) u64 {
    var z = n +% 0x9e3779b97f4a7c15;
    z = (z ^ (z >> 30)) *% 0xbf58476d1ce4e5b9;
    z = (z ^ (z >> 27)) *% 0x94d049bb133111eb;
    return z ^ (z >> 31);
}

/// Whether `K` is an address: a single-item pointer, or a `usize` holding one.
fn checkAddressKey(comptime K: type) void {
    const ok = switch (@typeInfo(K)) {
        .pointer => |p| p.size == .one,
        .int => K == usize,
        else => false,
    };
    if (!ok) @compileError("address_map: " ++ @typeName(K) ++ " is not an address (a single-item pointer or a usize)");
}

/// Wyhash's constants (lib/std/hash/wyhash.zig `secret`).
const secret = [_]u64{
    0xa0761d6478bd642f,
    0xe7037ed1a0b428db,
    0x8ebc6af09c88c6e3,
    0x589965cc75374cc3,
};

inline fn mum(a: *u64, b: *u64) void {
    const x = @as(u128, a.*) *% b.*;
    a.* = @truncate(x);
    b.* = @truncate(x >> 64);
}

inline fn mix(a_: u64, b_: u64) u64 {
    var a = a_;
    var b = b_;
    mum(&a, &b);
    return a ^ b;
}

/// The hash context of an address-keyed table: Wyhash under the table's seed.
pub fn AddressContext(comptime K: type) type {
    comptime checkAddressKey(K);
    return struct {
        const Self = @This();

        /// The table's seed (diagnostic; `state` is what the hash reads).
        seed: u64 = 0,
        /// Wyhash's state once `seed` is mixed in (`Wyhash.init`), so each
        /// hash does not mix it again.
        state: u64 = 0,

        pub fn seeded(seed: u64) Self {
            return .{ .seed = seed, .state = seed ^ mix(seed ^ secret[0], secret[1]) };
        }

        /// A context under a seed no other table has drawn.
        pub fn next() Self {
            return seeded(nextSeed());
        }

        /// `std.hash.Wyhash.hash(self.seed, std.mem.asBytes(&key))`, with the
        /// seed's mixing done once per table. For an 8-byte key this is
        /// Wyhash's short-input path (`smallKey`, then `final2`).
        pub fn hash(self: Self, key: K) u64 {
            const bytes = std.mem.asBytes(&key);
            if (bytes.len != 8) return std.hash.Wyhash.hash(self.seed, bytes);
            const lo: u64 = std.mem.readInt(u32, bytes[0..4], .little);
            const hi: u64 = std.mem.readInt(u32, bytes[4..8], .little);
            var a = ((lo << 32) | hi) ^ secret[1];
            var b = ((hi << 32) | lo) ^ self.state;
            mum(&a, &b);
            return mix(a ^ secret[0] ^ 8, b ^ secret[1]);
        }

        pub fn eql(_: Self, a: K, b: K) bool {
            return a == b;
        }
    };
}

/// An unmanaged hash map keyed by an address, with a seed of its own: std's
/// `HashMapUnmanaged` API (an allocator per allocating call).
pub fn AddressHashMapUnmanaged(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();

        pub const Context = AddressContext(K);
        pub const Unmanaged = std.HashMapUnmanaged(K, V, Context, max_load_percentage);
        pub const Size = Unmanaged.Size;
        pub const Entry = Unmanaged.Entry;
        pub const KV = Unmanaged.KV;
        pub const GetOrPutResult = Unmanaged.GetOrPutResult;
        pub const Iterator = Unmanaged.Iterator;
        pub const KeyIterator = Unmanaged.KeyIterator;
        pub const ValueIterator = Unmanaged.ValueIterator;

        /// std's table (the name `infra.tombstones` looks for).
        // tombstones: the table of a map type, not a map; each owner guards its own AddressHashMap (lint-tombstones reads AddressHashMap fields as maps)
        unmanaged: Unmanaged = .empty,
        /// This table's seed; drawn when the table is next laid out.
        ctx: Context = .{},

        pub const empty: Self = .{};

        /// Before a call that may allocate: a table with no slots yet takes
        /// a new seed.
        inline fn seedIfUnallocated(self: *Self) void {
            if (self.unmanaged.metadata == null) self.ctx = Context.next();
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.unmanaged.deinit(allocator);
            self.* = undefined;
        }

        /// Empties the table, keeping its slots, under a new seed.
        pub fn clearRetainingCapacity(self: *Self) void {
            self.unmanaged.clearRetainingCapacity();
            self.ctx = Context.next();
        }

        /// Empties the table and frees its slots; the next insert draws a
        /// new seed.
        pub fn clearAndFree(self: *Self, allocator: std.mem.Allocator) void {
            self.unmanaged.clearAndFree(allocator);
        }

        /// std's in-place rehash, under a new seed: every entry is placed
        /// again and no tombstone is left. Invalidates key and value
        /// pointers, as std's does.
        pub fn rehash(self: *Self) void {
            if (self.unmanaged.metadata == null) return;
            const ctx = Context.next();
            self.unmanaged.rehash(ctx);
            self.ctx = ctx;
        }

        pub fn count(self: Self) Size {
            return self.unmanaged.count();
        }

        pub fn capacity(self: Self) Size {
            return self.unmanaged.capacity();
        }

        pub fn iterator(self: *const Self) Iterator {
            return self.unmanaged.iterator();
        }

        pub fn keyIterator(self: Self) KeyIterator {
            return self.unmanaged.keyIterator();
        }

        pub fn valueIterator(self: Self) ValueIterator {
            return self.unmanaged.valueIterator();
        }

        pub fn ensureTotalCapacity(self: *Self, allocator: std.mem.Allocator, new_size: Size) std.mem.Allocator.Error!void {
            self.seedIfUnallocated();
            return self.unmanaged.ensureTotalCapacityContext(allocator, new_size, self.ctx);
        }

        pub fn ensureUnusedCapacity(self: *Self, allocator: std.mem.Allocator, additional_size: Size) std.mem.Allocator.Error!void {
            self.seedIfUnallocated();
            return self.unmanaged.ensureUnusedCapacityContext(allocator, additional_size, self.ctx);
        }

        pub fn put(self: *Self, allocator: std.mem.Allocator, key: K, value: V) std.mem.Allocator.Error!void {
            self.seedIfUnallocated();
            return self.unmanaged.putContext(allocator, key, value, self.ctx);
        }

        pub fn putNoClobber(self: *Self, allocator: std.mem.Allocator, key: K, value: V) std.mem.Allocator.Error!void {
            self.seedIfUnallocated();
            return self.unmanaged.putNoClobberContext(allocator, key, value, self.ctx);
        }

        pub fn putAssumeCapacity(self: *Self, key: K, value: V) void {
            self.unmanaged.putAssumeCapacityContext(key, value, self.ctx);
        }

        pub fn putAssumeCapacityNoClobber(self: *Self, key: K, value: V) void {
            self.unmanaged.putAssumeCapacityNoClobberContext(key, value, self.ctx);
        }

        pub fn fetchPut(self: *Self, allocator: std.mem.Allocator, key: K, value: V) std.mem.Allocator.Error!?KV {
            self.seedIfUnallocated();
            return self.unmanaged.fetchPutContext(allocator, key, value, self.ctx);
        }

        pub fn getOrPut(self: *Self, allocator: std.mem.Allocator, key: K) std.mem.Allocator.Error!GetOrPutResult {
            self.seedIfUnallocated();
            return self.unmanaged.getOrPutContext(allocator, key, self.ctx);
        }

        pub fn getOrPutAssumeCapacity(self: *Self, key: K) GetOrPutResult {
            return self.unmanaged.getOrPutAssumeCapacityContext(key, self.ctx);
        }

        /// (std's `getOrPutValueContext` calls its context-less
        /// `getOrPutAdapted`, which a context with state cannot use.)
        pub fn getOrPutValue(self: *Self, allocator: std.mem.Allocator, key: K, value: V) std.mem.Allocator.Error!Entry {
            const gop = try self.getOrPut(allocator, key);
            if (!gop.found_existing) gop.value_ptr.* = value;
            return .{ .key_ptr = gop.key_ptr, .value_ptr = gop.value_ptr };
        }

        pub fn get(self: Self, key: K) ?V {
            return self.unmanaged.getContext(key, self.ctx);
        }

        pub fn getPtr(self: Self, key: K) ?*V {
            return self.unmanaged.getPtrContext(key, self.ctx);
        }

        pub fn getKey(self: Self, key: K) ?K {
            return self.unmanaged.getKeyContext(key, self.ctx);
        }

        pub fn getKeyPtr(self: Self, key: K) ?*K {
            return self.unmanaged.getKeyPtrContext(key, self.ctx);
        }

        pub fn getEntry(self: Self, key: K) ?Entry {
            return self.unmanaged.getEntryContext(key, self.ctx);
        }

        pub fn contains(self: Self, key: K) bool {
            return self.unmanaged.containsContext(key, self.ctx);
        }

        pub fn fetchRemove(self: *Self, key: K) ?KV {
            return self.unmanaged.fetchRemoveContext(key, self.ctx);
        }

        pub fn remove(self: *Self, key: K) bool {
            return self.unmanaged.removeContext(key, self.ctx);
        }

        pub fn removeByPtr(self: *Self, key_ptr: *const K) void {
            self.unmanaged.removeByPtr(key_ptr);
        }
    };
}

/// A managed hash map keyed by an address, with a seed of its own: std's
/// `HashMap` API (the allocator kept in the map).
pub fn AddressHashMap(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();

        const Table = AddressHashMapUnmanaged(K, V);
        pub const Context = Table.Context;
        pub const Unmanaged = Table.Unmanaged;
        pub const Size = Table.Size;
        pub const Entry = Table.Entry;
        pub const KV = Table.KV;
        pub const GetOrPutResult = Table.GetOrPutResult;
        pub const Iterator = Table.Iterator;
        pub const KeyIterator = Table.KeyIterator;
        pub const ValueIterator = Table.ValueIterator;

        /// std's table (the name `infra.tombstones` looks for).
        // tombstones: the table of a map type, not a map; each owner guards its own AddressHashMap (lint-tombstones reads AddressHashMap fields as maps)
        unmanaged: Unmanaged,
        allocator: std.mem.Allocator,
        /// This table's seed; drawn when the table is next laid out.
        ctx: Context,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .unmanaged = .empty, .allocator = allocator, .ctx = .{} };
        }

        pub fn deinit(self: *Self) void {
            self.unmanaged.deinit(self.allocator);
            self.* = undefined;
        }

        pub fn clearRetainingCapacity(self: *Self) void {
            self.unmanaged.clearRetainingCapacity();
            self.ctx = Context.next();
        }

        pub fn clearAndFree(self: *Self) void {
            self.unmanaged.clearAndFree(self.allocator);
        }

        pub fn rehash(self: *Self) void {
            if (self.unmanaged.metadata == null) return;
            const ctx = Context.next();
            self.unmanaged.rehash(ctx);
            self.ctx = ctx;
        }

        pub fn count(self: Self) Size {
            return self.unmanaged.count();
        }

        pub fn capacity(self: Self) Size {
            return self.unmanaged.capacity();
        }

        pub fn iterator(self: *const Self) Iterator {
            return self.unmanaged.iterator();
        }

        pub fn keyIterator(self: Self) KeyIterator {
            return self.unmanaged.keyIterator();
        }

        pub fn valueIterator(self: Self) ValueIterator {
            return self.unmanaged.valueIterator();
        }

        inline fn seedIfUnallocated(self: *Self) void {
            if (self.unmanaged.metadata == null) self.ctx = Context.next();
        }

        pub fn ensureTotalCapacity(self: *Self, new_size: Size) std.mem.Allocator.Error!void {
            self.seedIfUnallocated();
            return self.unmanaged.ensureTotalCapacityContext(self.allocator, new_size, self.ctx);
        }

        pub fn ensureUnusedCapacity(self: *Self, additional_size: Size) std.mem.Allocator.Error!void {
            self.seedIfUnallocated();
            return self.unmanaged.ensureUnusedCapacityContext(self.allocator, additional_size, self.ctx);
        }

        pub fn put(self: *Self, key: K, value: V) std.mem.Allocator.Error!void {
            self.seedIfUnallocated();
            return self.unmanaged.putContext(self.allocator, key, value, self.ctx);
        }

        pub fn putNoClobber(self: *Self, key: K, value: V) std.mem.Allocator.Error!void {
            self.seedIfUnallocated();
            return self.unmanaged.putNoClobberContext(self.allocator, key, value, self.ctx);
        }

        pub fn putAssumeCapacity(self: *Self, key: K, value: V) void {
            self.unmanaged.putAssumeCapacityContext(key, value, self.ctx);
        }

        pub fn putAssumeCapacityNoClobber(self: *Self, key: K, value: V) void {
            self.unmanaged.putAssumeCapacityNoClobberContext(key, value, self.ctx);
        }

        pub fn fetchPut(self: *Self, key: K, value: V) std.mem.Allocator.Error!?KV {
            self.seedIfUnallocated();
            return self.unmanaged.fetchPutContext(self.allocator, key, value, self.ctx);
        }

        pub fn getOrPut(self: *Self, key: K) std.mem.Allocator.Error!GetOrPutResult {
            self.seedIfUnallocated();
            return self.unmanaged.getOrPutContext(self.allocator, key, self.ctx);
        }

        pub fn getOrPutAssumeCapacity(self: *Self, key: K) GetOrPutResult {
            return self.unmanaged.getOrPutAssumeCapacityContext(key, self.ctx);
        }

        pub fn getOrPutValue(self: *Self, key: K, value: V) std.mem.Allocator.Error!Entry {
            const gop = try self.getOrPut(key);
            if (!gop.found_existing) gop.value_ptr.* = value;
            return .{ .key_ptr = gop.key_ptr, .value_ptr = gop.value_ptr };
        }

        pub fn get(self: Self, key: K) ?V {
            return self.unmanaged.getContext(key, self.ctx);
        }

        pub fn getPtr(self: Self, key: K) ?*V {
            return self.unmanaged.getPtrContext(key, self.ctx);
        }

        pub fn getKey(self: Self, key: K) ?K {
            return self.unmanaged.getKeyContext(key, self.ctx);
        }

        pub fn getKeyPtr(self: Self, key: K) ?*K {
            return self.unmanaged.getKeyPtrContext(key, self.ctx);
        }

        pub fn getEntry(self: Self, key: K) ?Entry {
            return self.unmanaged.getEntryContext(key, self.ctx);
        }

        pub fn contains(self: Self, key: K) bool {
            return self.unmanaged.containsContext(key, self.ctx);
        }

        pub fn fetchRemove(self: *Self, key: K) ?KV {
            return self.unmanaged.fetchRemoveContext(key, self.ctx);
        }

        pub fn remove(self: *Self, key: K) bool {
            return self.unmanaged.removeContext(key, self.ctx);
        }

        pub fn removeByPtr(self: *Self, key_ptr: *const K) void {
            self.unmanaged.removeByPtr(key_ptr);
        }
    };
}

// Tests. src/infra's test blocks run in `zig build test` (the src-infra
// suite, through root.zig's refAllDecls).

const testing = std.testing;

test "the hash is std's Wyhash under the table's seed, for pointers and usize addresses" {
    var objects: [64]u64 = undefined;
    const seeds = [_]u64{ 0, 1, 0x9e3779b97f4a7c15, std.math.maxInt(u64), nextSeed() };
    for (seeds) |seed| {
        const pointers = AddressContext(*u64).seeded(seed);
        const addresses = AddressContext(usize).seeded(seed);
        for (&objects) |*object| {
            try testing.expectEqual(std.hash.Wyhash.hash(seed, std.mem.asBytes(&object)), pointers.hash(object));
            const address = @intFromPtr(object);
            try testing.expectEqual(std.hash.Wyhash.hash(seed, std.mem.asBytes(&address)), addresses.hash(address));
        }
        // Seed 0 is what std.AutoHashMap hashes with.
        if (seed == 0) try testing.expectEqual(std.hash_map.AutoContext(*u64).hash(.{}, &objects[3]), pointers.hash(&objects[3]));
    }
}

test "seeds come from a counter: the n-th draw is SplitMix64(n), and no clock or OS entropy" {
    // SplitMix64's reference output for state 0 (Vigna's splitmix64.c).
    try testing.expectEqual(@as(u64, 0xe220a8397b1dcdaf), splitMix64(0));
    const n = seed_counter.load(.monotonic);
    try testing.expectEqual(splitMix64(n), nextSeed());
    try testing.expectEqual(splitMix64(n + 1), nextSeed());
}

test "every table draws its own seed when it is first laid out, and again when cleared, freed or rehashed" {
    var objects: [100]u64 = undefined;
    var a: AddressHashMapUnmanaged(*u64, usize) = .empty;
    defer a.deinit(testing.allocator);
    var b: AddressHashMap(*u64, usize) = .init(testing.allocator);
    defer b.deinit();
    for (&objects, 0..) |*object, i| {
        try a.put(testing.allocator, object, i);
        try b.put(object, i);
    }
    try testing.expect(a.ctx.seed != b.ctx.seed);

    // A rehash places every entry again under a new seed.
    const before = a.ctx.seed;
    a.rehash();
    try testing.expect(a.ctx.seed != before);
    for (&objects, 0..) |*object, i| try testing.expectEqual(@as(?usize, i), a.get(object));
    const before_b = b.ctx.seed;
    b.rehash();
    try testing.expect(b.ctx.seed != before_b);
    for (&objects, 0..) |*object, i| try testing.expectEqual(@as(?usize, i), b.get(object));

    // Cleared, keeping its slots: a new seed at once.
    const cleared = a.ctx.seed;
    a.clearRetainingCapacity();
    try testing.expect(a.ctx.seed != cleared);
    try testing.expectEqual(@as(?usize, null), a.get(&objects[0]));
    try a.put(testing.allocator, &objects[0], 7);
    try testing.expectEqual(@as(?usize, 7), a.get(&objects[0]));

    // Freed: the next insert draws one.
    const freed = b.ctx.seed;
    b.clearAndFree();
    try testing.expectEqual(@as(?usize, null), b.get(&objects[0]));
    try b.put(&objects[0], 9);
    try testing.expect(b.ctx.seed != freed);
    try testing.expectEqual(@as(?usize, 9), b.get(&objects[0]));

    // A grow keeps the seed: std re-places the entries with it.
    var c: AddressHashMapUnmanaged(usize, void) = .empty;
    defer c.deinit(testing.allocator);
    try c.put(testing.allocator, 1, {});
    const grown = c.ctx.seed;
    for (2..1000) |k| try c.put(testing.allocator, k, {});
    try testing.expectEqual(grown, c.ctx.seed);
    for (1..1000) |k| try testing.expect(c.contains(k));
}

/// The calls whose signature differs between the managed and the unmanaged
/// map: the unmanaged one takes the allocator.
const Calls = struct {
    fn managed(comptime Map: type) bool {
        return @hasField(Map, "allocator");
    }
    fn put(map: anytype, key: anytype, value: anytype) !void {
        if (comptime managed(@TypeOf(map.*))) try map.put(key, value) else try map.put(testing.allocator, key, value);
    }
    fn putNoClobber(map: anytype, key: anytype, value: anytype) !void {
        if (comptime managed(@TypeOf(map.*))) try map.putNoClobber(key, value) else try map.putNoClobber(testing.allocator, key, value);
    }
    fn getOrPut(map: anytype, key: anytype) !@TypeOf(map.*).GetOrPutResult {
        return if (comptime managed(@TypeOf(map.*))) map.getOrPut(key) else map.getOrPut(testing.allocator, key);
    }
    fn fetchPut(map: anytype, key: anytype, value: anytype) !?@TypeOf(map.*).KV {
        return if (comptime managed(@TypeOf(map.*))) map.fetchPut(key, value) else map.fetchPut(testing.allocator, key, value);
    }
    fn getOrPutValue(map: anytype, key: anytype, value: anytype) !@TypeOf(map.*).Entry {
        return if (comptime managed(@TypeOf(map.*))) map.getOrPutValue(key, value) else map.getOrPutValue(testing.allocator, key, value);
    }
    fn ensureTotalCapacity(map: anytype, size: u32) !void {
        if (comptime managed(@TypeOf(map.*))) try map.ensureTotalCapacity(size) else try map.ensureTotalCapacity(testing.allocator, size);
    }
    fn ensureUnusedCapacity(map: anytype, size: u32) !void {
        if (comptime managed(@TypeOf(map.*))) try map.ensureUnusedCapacity(size) else try map.ensureUnusedCapacity(testing.allocator, size);
    }
    fn deinit(map: anytype) void {
        if (comptime managed(@TypeOf(map.*))) map.deinit() else map.deinit(testing.allocator);
    }
};

fn exerciseApi(map: anytype) !void {
    var objects: [300]u64 = undefined;
    try Calls.ensureTotalCapacity(map, 16);
    for (&objects, 0..) |*object, i| try Calls.put(map, object, i);
    try testing.expectEqual(@as(u32, objects.len), map.count());
    try testing.expect(map.capacity() >= objects.len);

    const gop = try Calls.getOrPut(map, &objects[5]);
    try testing.expect(gop.found_existing);
    try testing.expectEqual(@as(usize, 5), gop.value_ptr.*);
    map.getPtr(&objects[6]).?.* = 600;
    try testing.expectEqual(@as(?usize, 600), map.get(&objects[6]));
    try testing.expectEqual(&objects[7], map.getKey(&objects[7]).?);
    try testing.expectEqual(@as(usize, 8), (try Calls.fetchPut(map, &objects[8], 800)).?.value);
    try testing.expectEqual(@as(usize, 9), (try Calls.getOrPutValue(map, &objects[9], 0)).value_ptr.*);

    try testing.expectEqual(@as(usize, 10), map.fetchRemove(&objects[10]).?.value);
    try testing.expect(map.remove(&objects[11]));
    try testing.expect(!map.remove(&objects[11]));
    map.removeByPtr(map.getKeyPtr(&objects[12]).?);
    try testing.expect(!map.contains(&objects[12]));
    try testing.expectEqual(@as(u32, objects.len - 3), map.count());

    try Calls.ensureUnusedCapacity(map, 1);
    map.putAssumeCapacity(&objects[10], 1000);
    try testing.expectEqual(@as(usize, 1000), map.getEntry(&objects[10]).?.value_ptr.*);
    try Calls.putNoClobber(map, &objects[11], 1100);
    try Calls.ensureUnusedCapacity(map, 2);
    map.putAssumeCapacityNoClobber(&objects[12], 1200);
    try testing.expect(map.getOrPutAssumeCapacity(&objects[13]).found_existing);
    try testing.expectEqual(@as(?usize, 1200), map.get(&objects[12]));

    // Removal while walking, as a teardown sweep does.
    var walked: usize = 0;
    var it = map.iterator();
    while (it.next()) |entry| {
        map.removeByPtr(entry.key_ptr);
        walked += 1;
    }
    try testing.expectEqual(@as(usize, objects.len), walked);
    try testing.expectEqual(@as(u32, 0), map.count());
    var keys = map.keyIterator();
    try testing.expect(keys.next() == null);
    var values = map.valueIterator();
    try testing.expect(values.next() == null);
}

test "std's map API, managed and unmanaged" {
    var managed: AddressHashMap(*u64, usize) = .init(testing.allocator);
    defer Calls.deinit(&managed);
    try exerciseApi(&managed);
    var unmanaged: AddressHashMapUnmanaged(*u64, usize) = .empty;
    defer Calls.deinit(&unmanaged);
    try exerciseApi(&unmanaged);
}

test "TombstoneGuard rehashes an address map in place, and its slot counts read it" {
    const tombstones = @import("tombstones.zig");
    var objects: [4096]u64 = undefined;
    var map: AddressHashMapUnmanaged(*u64, u32) = .empty;
    defer map.deinit(testing.allocator);
    var guard: tombstones.TombstoneGuard = .{};
    const resident = 64;
    for (objects[0..resident], 0..) |*object, i| {
        guard.beforeInsert(&map);
        try map.put(testing.allocator, object, @intCast(i));
    }
    // Keys that come and go: without a rehash their tombstones would take
    // every free slot.
    for (0..20) |_| {
        for (objects[resident..]) |*object| {
            guard.beforeInsert(&map);
            try map.put(testing.allocator, object, 0);
        }
        for (objects[resident..]) |*object| {
            try testing.expect(map.remove(object));
            guard.noteRemoval(&map);
        }
    }
    guard.beforeInsert(&map);
    try testing.expect(tombstones.slotCounts(&map).halfOfUnusedFree());
    try testing.expect(tombstones.meanMissProbe(&map) <= 8);
    for (objects[0..resident], 0..) |*object, i| try testing.expectEqual(@as(?u32, @intCast(i)), map.get(object));
}
