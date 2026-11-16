//! Crane's in-sandbox allocator: the memory behind every ArrayBuffer, and
//! behind V8's own in-sandbox blocks (BigInt digits, regexp result vectors,
//! number conversions, wasm tiering budgets), in place of V8's default.
//!
//! ## Why Crane has its own
//!
//! V8 15.7.112.43's default (src/sandbox/sandbox.cc DefaultInSandboxAllocator)
//! says of itself "This allocator is not optimized for performance!" and
//! expects an embedder to replace it (v8::V8::SetInSandboxAllocator,
//! v8-initialization.h). It keeps one mutex and a region allocator (two
//! ordered sets per block, 128-byte granularity) and zero-fills under the
//! lock. It gives every fully free 1 MiB chunk back with
//! VirtualAddressSpace::DiscardSystemPages - MADV_FREE_REUSABLE on macOS - and
//! hands the chunk out again with a memset and NO RecommitPages. macOS counts
//! a reusable page in the task's footprint again only after MADV_FREE_REUSE
//! (crbug.com/823915), so Crane's published macOS memory read up to 38 MB low
//! on ArrayBuffer-heavy pages (lane mem2, 2026-11-16).
//!
//! ## The design, and where it comes from
//!
//! Chrome's: gin's ArrayBufferAllocator (chromium gin/array_buffer.cc,
//! BSD) allocates from a PartitionAlloc partition whose pool is reserved
//! inside the V8 sandbox; V8's own reference for an embedder's allocator is
//! d8's (V8 15.7.112.43 src/d8/d8.cc PAInSandboxAllocator). What is reproduced
//! here, in Crane's own code (nothing is copied), from PartitionAlloc at the
//! revision V8 15.7.112.43 pins (third_party/partition_alloc/src/partition_alloc,
//! BSD):
//!
//! - **Recommit before reuse** (page_allocator_internals_posix.h
//!   RecommitSystemPagesInternal: "On macOS, to update accounting, we need to
//!   make another syscall" - MADV_FREE_REUSE; DiscardSystemPagesInternal is
//!   MADV_FREE_REUSABLE on Apple, MADV_DONTNEED elsewhere). Every chunk taken
//!   from the free pool is recommitted before a byte of it is handed out:
//!   `takeChunks`.
//! - **Decommitted memory is not zero on Apple** (page_allocator.h
//!   DecommittedMemoryIsAlwaysZeroed): a zeroed allocation is zero-filled by
//!   hand unless its memory is known never to have been handed out since the
//!   OS made it (`Block.zeroed`).
//! - **Size classes** (partition_alloc_constants.h, bucket_lookup.h: 8
//!   buckets per power of two): a block of up to 1 MiB is a slot of its
//!   class; a free takes no search and an allocation takes the lowest free
//!   slot of one chunk.
//! - **An emptied span waits before it is given back** (partition_page.cc
//!   SlotSpanMetadata::RegisterEmpty: a ring of 16, "providing it a bit of
//!   breathing room to get re-used before we really free it. This reduces
//!   the number of system calls"): `ring`. PartitionAlloc caps the dirty
//!   bytes that wait at 1/8 of the committed bytes; Crane caps them at
//!   `retained_max` (1 MiB: one whole chunk), because its memory bar reads
//!   the whole process. One chunk is what a loop needs that frees a block
//!   and takes one of the same size again - a 1 MiB buffer included - to
//!   make no system call per round.
//! - **A large block is its own mapping, given back when freed**
//!   (partition_root.cc, direct maps): a block over 1 MiB is a run of whole
//!   chunks, discarded at its free.
//! - **Nothing the allocator trusts is inside the sandbox.** PartitionAlloc
//!   hardens the free list of its in-sandbox pool (pool-offset free-list
//!   entries); here every record - a chunk's class, its free bitmap, the free
//!   pool - is ordinary memory outside the sandbox, so a script that can
//!   write anywhere in the sandbox cannot steer an allocation.
//!
//! What V8's default does is kept where it was right: a fully free chunk goes
//! back to the OS, and free chunks at the top of the used range are
//! decommitted (inaccessible again, zero when next used) so the range
//! shrinks.
//!
//! Safari and Firefox, for the record (2026-11-16): bmalloc and libpas
//! (WebKit Source/bmalloc/bmalloc/VMAllocate.h vmAllocatePhysicalPages,
//! libpas pas_page_malloc.c commit_impl; BSD-2) decommit with
//! MADV_FREE_REUSABLE and make no call on reuse ("the kernel will commit
//! pages as they are touched"); mozjemalloc (memory/build/mozjemalloc.cpp)
//! purges with MADV_FREE, never MADV_FREE_REUSABLE, and on macOS maps over
//! the pages to force them out (MALLOC_DOUBLE_PURGE). Only Chrome recommits;
//! Crane follows it, as its platform's commitPages does for the node heap
//! (src/platform/protocol.zig), so that a figure reads what Crane holds.
//!
//! ## Layout
//!
//! The reservation is a row of 1 MiB chunks. `high_water` chunks from its
//! base are accessible; the rest is inaccessible and reads zero when it
//! becomes accessible. An accessible chunk is one of:
//!
//! - **slots**: cut into equal slots of one size class. A slot is found by
//!   the chunk's bitmap of freed slots, lowest first, then by `touched`, the
//!   count of slots handed out at least once.
//! - **run head / run body**: a block of more than 1 MiB, whole chunks.
//! - **free**: in the free pool, its memory given back to the OS. Recommitted
//!   when taken.
//!
//! ## Threads
//!
//! None of this is thread-safe: the caller holds one lock around every call
//! (v8_wrapper.cpp CraneInSandboxAllocator), as V8's default holds its mutex
//! and PartitionAlloc its root's lock. The zero-fill is the caller's, outside
//! the lock.
//!
//! This file has no engine in it: `Allocator` takes its page operations as a
//! type, V8's in sandbox_allocator_exports.zig and a model address space in
//! tests/v8/ab1_sandbox_allocator_test.zig.

const std = @import("std");

/// log2 of the chunk size.
pub const chunk_shift = 20;
/// The unit the reservation is cut into, and the unit memory goes back to
/// the OS in (V8's default: DefaultInSandboxAllocator::kChunkSize).
pub const chunk_size: usize = 1 << chunk_shift;
/// The largest block that is a slot of a size class - a chunk of its own; a
/// larger one is a run of whole chunks.
pub const slot_max: usize = chunk_size;
/// Every block's alignment (PartitionAlloc's on 64-bit; V8's default gives
/// 128). Enough for the widest typed-array element and for malloc's users.
pub const alignment: usize = 16;
/// How many emptied slot chunks may wait before they go back to the OS
/// (PartitionAlloc kDefaultEmptySlotSpanRingSize).
pub const ring_len = 16;
/// The dirty bytes that may wait in the ring, in total: one whole chunk, so
/// any one emptied chunk can wait.
pub const retained_max: usize = chunk_size;

/// The number of size classes: multiples of 16 up to 128, then 8 to each
/// power of two up to `slot_max`.
pub const class_count = 8 + (chunk_shift - 7) * 8;

/// The slot size of each class.
pub const class_sizes: [class_count]u32 = blk: {
    var sizes: [class_count]u32 = undefined;
    for (&sizes, 0..) |*size, class| {
        if (class < 8) {
            size.* = @intCast((class + 1) * 16);
        } else {
            const order = 7 + (class - 8) / 8;
            const step = (class - 8) % 8;
            size.* = @intCast((8 + step + 1) << (order - 3));
        }
    }
    break :blk sizes;
};

/// The class of the smallest slot that holds `size` bytes (1 to `slot_max`).
pub fn classOf(size: usize) u8 {
    std.debug.assert(size >= 1 and size <= slot_max);
    if (size <= 128) return @intCast((size + 15) / 16 - 1);
    const n = size - 1;
    const order: usize = std.math.log2_int(usize, n);
    const shift: std.math.Log2Int(usize) = @intCast(order - 3);
    return @intCast(8 + (order - 7) * 8 + ((n >> shift) - 8));
}

/// How many slots of `class` a chunk holds.
pub fn slotsOf(class: u8) u32 {
    return @intCast(chunk_size / class_sizes[class]);
}

/// What the allocator holds, for tests and diagnostics.
pub const Stats = extern struct {
    /// Chunks in the reservation.
    reserved_chunks: u64 = 0,
    /// Accessible chunks: the used range, from the base.
    high_water_chunks: u64 = 0,
    /// Accessible chunks in the free pool (their memory given back).
    free_chunks: u64 = 0,
    /// Emptied slot chunks waiting in the ring, and their dirty bytes.
    retained_chunks: u64 = 0,
    retained_bytes: u64 = 0,
    /// Live blocks and the bytes of their slots and runs.
    live_blocks: u64 = 0,
    live_bytes: u64 = 0,
    /// Page operations made, by kind.
    grows: u64 = 0,
    recommits: u64 = 0,
    discards: u64 = 0,
    decommits: u64 = 0,
};

/// A block the allocator handed out.
pub const Block = struct {
    address: usize,
    /// Every byte of the block is zero: its memory was never handed out
    /// since the OS made it. Otherwise it holds whatever was there.
    zeroed: bool,
};

pub const FreeError = error{
    /// Not a block of this allocator: outside the used range, inside a
    /// block, in a free chunk, or freed already.
    InvalidFree,
};

const none: u32 = std.math.maxInt(u32);
const not_in_ring: u8 = std.math.maxInt(u8);

const Kind = enum(u8) {
    /// In the free pool: accessible, its memory given back to the OS.
    free,
    /// Cut into slots of `class`.
    slots,
    /// The first chunk of a run of `used` chunks.
    run_head,
    /// A later chunk of a run.
    run_body,
};

const Chunk = struct {
    kind: Kind = .free,
    /// slots: the size class.
    class: u8 = 0,
    /// slots: its place in the ring, taken when it became empty and kept
    /// while it is used again, until a newer chunk takes the place.
    ring_slot: u8 = not_in_ring,
    /// slots: the slots at and above `touched` have read zero since the OS
    /// made the chunk's memory.
    fresh: bool = false,
    /// slots: live slots. run_head: the chunks of the run.
    used: u32 = 0,
    /// slots: how many slots, from the first, were handed out at least once.
    touched: u32 = 0,
    /// slots: how many of the touched slots are free (the set bits).
    freed: u32 = 0,
    /// slots: no bitmap word below this one has a set bit.
    hint: u32 = 0,
    /// slots: the class's list of chunks with a free slot.
    next: u32 = none,
    prev: u32 = none,
    /// slots: one bit per slot, set while a touched slot is free. Words at
    /// and above `touched / 64` (rounded up) are not initialised yet.
    bits: []u64 = &.{},
};

/// The allocator over `Pages`, which gives its four page operations, each
/// over a whole number of chunks and each answering whether the OS did it:
///
/// - `setReadWrite(address, size) bool`: inaccessible pages become
///   accessible and read zero;
/// - `discard(address, size) bool`: accessible pages give their memory back
///   and stay accessible; their contents are then unspecified;
/// - `recommit(address, size) bool`: discarded pages are accounted again
///   before they are used;
/// - `decommit(address, size) bool`: accessible pages give their memory back
///   and become inaccessible.
pub fn Allocator(comptime Pages: type) type {
    return struct {
        const Self = @This();

        pages: Pages,
        /// What the records are made with - never sandbox memory.
        meta: std.mem.Allocator,
        base: usize,
        max_chunks: u32,
        /// Chunks below this are accessible; `chunks[high_water - 1]` is
        /// never free (free chunks at the top are decommitted).
        high_water: u32 = 0,
        /// One record per chunk below the highest `high_water` so far.
        chunks: std.ArrayList(Chunk) = .empty,
        /// The free pool: one bit per chunk, set while it is `.free`.
        free_bits: []u64,
        free_count: u32 = 0,
        /// No word of `free_bits` below this one has a set bit.
        free_hint: u32 = 0,
        /// Per class, the chunks with a free slot; empty ones last.
        heads: [class_count]u32 = @splat(none),
        tails: [class_count]u32 = @splat(none),
        /// The slot chunks that were empty last, oldest at `ring_next`; the
        /// empty ones among them wait (`retained_bytes`).
        ring: [ring_len]u32 = @splat(none),
        ring_next: u8 = 0,
        retained_bytes: usize = 0,
        retained_chunks: u32 = 0,
        live_blocks: u64 = 0,
        live_bytes: u64 = 0,
        grows: u64 = 0,
        recommits: u64 = 0,
        discards: u64 = 0,
        decommits: u64 = 0,

        /// An allocator over the reserved, inaccessible range `[base, base +
        /// size)`: `base` a multiple of `chunk_size`, `size` cut down to
        /// whole chunks. The range stays the caller's; `deinit` frees the
        /// records only.
        pub fn init(meta: std.mem.Allocator, pages: Pages, base: usize, size: usize) std.mem.Allocator.Error!Self {
            std.debug.assert(base % chunk_size == 0);
            const max_chunks: u32 = @intCast(@min(size >> chunk_shift, @as(usize, none - 1)));
            const free_bits = try meta.alloc(u64, (max_chunks + 63) / 64);
            @memset(free_bits, 0);
            return .{ .pages = pages, .meta = meta, .base = base, .max_chunks = max_chunks, .free_bits = free_bits };
        }

        /// Free the records. No page operation: the range is the caller's.
        pub fn deinit(self: *Self) void {
            for (self.chunks.items[0..self.high_water]) |*chunk| {
                if (chunk.kind == .slots) self.meta.free(chunk.bits);
            }
            self.chunks.deinit(self.meta);
            self.meta.free(self.free_bits);
            self.* = undefined;
        }

        /// A block of at least `size` bytes, aligned to `alignment`, or null
        /// when the reservation, the OS or the record memory has no room.
        /// A `size` of zero is a block of one byte.
        pub fn allocate(self: *Self, size: usize) ?Block {
            const bytes = @max(size, 1);
            if (bytes <= slot_max) return self.allocateSlot(classOf(bytes));
            if (bytes > @as(usize, self.max_chunks) << chunk_shift) return null;
            const count: u32 = @intCast((bytes + chunk_size - 1) >> chunk_shift);
            const taken = self.takeChunks(count) orelse return null;
            const run = self.chunks.items[taken.first..][0..count];
            run[0] = .{ .kind = .run_head, .used = count };
            for (run[1..]) |*body| body.* = .{ .kind = .run_body };
            self.live_blocks += 1;
            self.live_bytes += @as(u64, count) << chunk_shift;
            return .{ .address = self.addressOf(taken.first), .zeroed = taken.fresh };
        }

        /// Free the block at `address`, which `allocate` returned and no
        /// free has named since.
        pub fn free(self: *Self, address: usize) FreeError!void {
            if (address < self.base) return error.InvalidFree;
            const offset = address - self.base;
            if (offset >> chunk_shift >= self.high_water) return error.InvalidFree;
            const index: u32 = @intCast(offset >> chunk_shift);
            const within: u32 = @intCast(offset & (chunk_size - 1));
            const chunk = &self.chunks.items[index];
            switch (chunk.kind) {
                .slots => {
                    const size = class_sizes[chunk.class];
                    const slot = within / size;
                    if (within % size != 0 or slot >= chunk.touched) return error.InvalidFree;
                    const word = slot / 64;
                    const mask = @as(u64, 1) << @intCast(slot % 64);
                    if (chunk.bits[word] & mask != 0) return error.InvalidFree;
                    chunk.bits[word] |= mask;
                    if (chunk.freed == 0 or word < chunk.hint) chunk.hint = word;
                    chunk.freed += 1;
                    const was_full = chunk.used == slotsOf(chunk.class);
                    chunk.used -= 1;
                    self.live_blocks -= 1;
                    self.live_bytes -= size;
                    if (chunk.used == 0) {
                        // Empty chunks last, so the class fills its other
                        // chunks first and this one can go back to the OS.
                        if (!was_full) self.unlink(index);
                        self.linkLast(index);
                        self.enterRing(index);
                    } else if (was_full) {
                        self.linkFirst(index);
                    }
                },
                .run_head => {
                    if (within != 0) return error.InvalidFree;
                    const count = chunk.used;
                    self.live_blocks -= 1;
                    self.live_bytes -= @as(u64, count) << chunk_shift;
                    self.releaseChunks(index, count);
                },
                .run_body, .free => return error.InvalidFree,
            }
        }

        /// Give back every emptied chunk that waits in the ring.
        pub fn releaseRetained(self: *Self) void {
            for (self.ring) |index| {
                if (index != none and self.chunks.items[index].used == 0) self.evict(index);
            }
        }

        pub fn stats(self: *const Self) Stats {
            return .{
                .reserved_chunks = self.max_chunks,
                .high_water_chunks = self.high_water,
                .free_chunks = self.free_count,
                .retained_chunks = self.retained_chunks,
                .retained_bytes = self.retained_bytes,
                .live_blocks = self.live_blocks,
                .live_bytes = self.live_bytes,
                .grows = self.grows,
                .recommits = self.recommits,
                .discards = self.discards,
                .decommits = self.decommits,
            };
        }

        fn addressOf(self: *const Self, index: u32) usize {
            return self.base + (@as(usize, index) << chunk_shift);
        }

        fn allocateSlot(self: *Self, class: u8) ?Block {
            var index = self.heads[class];
            if (index == none) index = self.assign(class) orelse return null;
            const chunk = &self.chunks.items[index];
            // Empty and in the ring: it waited (a chunk just assigned is
            // empty too, and is not in the ring yet).
            if (chunk.used == 0 and chunk.ring_slot != not_in_ring) self.reuseWaiting(chunk);
            const size = class_sizes[class];
            var slot: u32 = undefined;
            var zeroed = false;
            if (chunk.freed > 0) {
                // The lowest freed slot: the chunk's dirty pages stay
                // together. `freed > 0` bounds the scan.
                var word = chunk.hint;
                while (chunk.bits[word] == 0) word += 1;
                const bit: u32 = @ctz(chunk.bits[word]);
                chunk.bits[word] &= chunk.bits[word] - 1;
                chunk.freed -= 1;
                chunk.hint = word;
                slot = word * 64 + bit;
            } else {
                slot = chunk.touched;
                if (slot % 64 == 0) chunk.bits[slot / 64] = 0;
                chunk.touched += 1;
                zeroed = chunk.fresh;
            }
            chunk.used += 1;
            if (chunk.used == slotsOf(class)) self.unlink(index);
            self.live_blocks += 1;
            self.live_bytes += size;
            return .{ .address = self.addressOf(index) + @as(usize, slot) * size, .zeroed = zeroed };
        }

        /// A chunk for `class`, first in its list.
        fn assign(self: *Self, class: u8) ?u32 {
            const bits = self.meta.alloc(u64, (slotsOf(class) + 63) / 64) catch return null;
            const taken = self.takeChunks(1) orelse {
                self.meta.free(bits);
                return null;
            };
            self.chunks.items[taken.first] = .{ .kind = .slots, .class = class, .fresh = taken.fresh, .bits = bits };
            self.linkFirst(taken.first);
            return taken.first;
        }

        const Taken = struct { first: u32, fresh: bool };

        /// `count` chunks in a row, accessible and accounted: the lowest run
        /// of the free pool, recommitted - or, with none, new ones above
        /// `high_water`, which read zero (`fresh`). Their records are the
        /// caller's to write.
        fn takeChunks(self: *Self, count: u32) ?Taken {
            if (self.findFree(count)) |first| {
                // THE RULE: what was given back is recommitted before a byte
                // of it is used (macOS: MADV_FREE_REUSE; Linux: nothing).
                if (!self.pages.recommit(self.addressOf(first), @as(usize, count) << chunk_shift)) return null;
                self.recommits += 1;
                for (first..first + count) |index| self.free_bits[index / 64] &= ~(@as(u64, 1) << @intCast(index % 64));
                self.free_count -= count;
                return .{ .first = first, .fresh = false };
            }
            if (count > self.max_chunks - self.high_water) return null;
            const first = self.high_water;
            if (self.chunks.items.len < first + count) self.chunks.resize(self.meta, first + count) catch return null;
            if (!self.pages.setReadWrite(self.addressOf(first), @as(usize, count) << chunk_shift)) return null;
            self.grows += 1;
            self.high_water = first + count;
            return .{ .first = first, .fresh = true };
        }

        /// The lowest `count` free chunks in a row.
        fn findFree(self: *Self, count: u32) ?u32 {
            if (self.free_count < count) return null;
            var index: u32 = self.free_hint * 64;
            var run: u32 = 0;
            var first_set = true;
            while (index < self.high_water) {
                const word = self.free_bits[index / 64];
                if (index % 64 == 0 and word == 0) {
                    run = 0;
                    index += 64;
                    continue;
                }
                if (word & (@as(u64, 1) << @intCast(index % 64)) != 0) {
                    if (first_set) {
                        self.free_hint = index / 64;
                        first_set = false;
                    }
                    run += 1;
                    if (run == count) return index + 1 - count;
                } else {
                    run = 0;
                }
                index += 1;
            }
            return null;
        }

        /// `count` chunks from `first` go to the free pool and their memory
        /// to the OS; free chunks at the top leave the used range.
        fn releaseChunks(self: *Self, first: u32, count: u32) void {
            for (first..first + count) |index| {
                self.chunks.items[index] = .{ .kind = .free };
                self.free_bits[index / 64] |= @as(u64, 1) << @intCast(index % 64);
            }
            self.free_count += count;
            if (first / 64 < self.free_hint) self.free_hint = first / 64;
            // At the top: decommitted with whatever free chunks lie under
            // them, in one operation, with no discard first.
            if (first + count == self.high_water and self.trimTop()) return;
            if (self.pages.discard(self.addressOf(first), @as(usize, count) << chunk_shift)) self.discards += 1;
        }

        /// Decommit the free chunks at the top of the used range and lower
        /// `high_water` under them. False when the OS refused: they stay in
        /// the free pool.
        fn trimTop(self: *Self) bool {
            var top = self.high_water;
            while (top > 0 and self.chunks.items[top - 1].kind == .free) top -= 1;
            if (top == self.high_water) return false;
            const count = self.high_water - top;
            if (!self.pages.decommit(self.addressOf(top), @as(usize, count) << chunk_shift)) return false;
            self.decommits += 1;
            for (top..self.high_water) |index| self.free_bits[index / 64] &= ~(@as(u64, 1) << @intCast(index % 64));
            self.free_count -= count;
            self.high_water = top;
            return true;
        }

        /// The bytes of an empty slot chunk that may be dirty.
        fn dirtyBytes(chunk: *const Chunk) usize {
            return @min(chunk_size, @as(usize, chunk.touched) * class_sizes[chunk.class]);
        }

        /// The chunk at `index` has just become empty: its dirty bytes wait.
        /// A chunk that has a place in the ring keeps it - it took it when
        /// it was empty before, and has been used again since: a chunk that
        /// empties and fills in a loop must not push the others out
        /// (PartitionAlloc RegisterEmpty: "If the slot span is already
        /// registered as empty, don't do anything. This prevents continually
        /// reusing a slot span from decommitting a bunch of other slot
        /// spans"). A chunk new to the ring takes the oldest place: what was
        /// there goes back to the OS if it is empty, and only loses its
        /// place if it is in use. Then the oldest empty ones go back while
        /// more than `retained_max` dirty bytes wait (never this one: a
        /// chunk holds no more than that).
        fn enterRing(self: *Self, index: u32) void {
            if (self.chunks.items[index].ring_slot == not_in_ring) {
                const before = self.ring[self.ring_next];
                if (before != none) {
                    if (self.chunks.items[before].used == 0) self.evict(before) else self.chunks.items[before].ring_slot = not_in_ring;
                }
                self.ring[self.ring_next] = index;
                self.chunks.items[index].ring_slot = self.ring_next;
                self.ring_next = (self.ring_next + 1) % ring_len;
            }
            self.retained_bytes += dirtyBytes(&self.chunks.items[index]);
            self.retained_chunks += 1;
            var at = self.ring_next;
            var seen: usize = 0;
            while (self.retained_bytes > retained_max and seen < ring_len) : ({
                at = (at + 1) % ring_len;
                seen += 1;
            }) {
                const oldest = self.ring[at];
                if (oldest != none and oldest != index and self.chunks.items[oldest].used == 0) self.evict(oldest);
            }
        }

        /// An empty chunk that waits is used again: its bytes wait no more.
        /// It keeps its place in the ring.
        fn reuseWaiting(self: *Self, chunk: *const Chunk) void {
            self.retained_bytes -= dirtyBytes(chunk);
            self.retained_chunks -= 1;
        }

        /// An empty slot chunk leaves the ring, its class and the used
        /// memory: to the free pool.
        fn evict(self: *Self, index: u32) void {
            const chunk = &self.chunks.items[index];
            std.debug.assert(chunk.used == 0);
            self.ring[chunk.ring_slot] = none;
            self.retained_bytes -= dirtyBytes(chunk);
            self.retained_chunks -= 1;
            self.unlink(index);
            self.meta.free(chunk.bits);
            self.releaseChunks(index, 1);
        }

        fn linkFirst(self: *Self, index: u32) void {
            const chunk = &self.chunks.items[index];
            const head = self.heads[chunk.class];
            chunk.prev = none;
            chunk.next = head;
            if (head != none) self.chunks.items[head].prev = index else self.tails[chunk.class] = index;
            self.heads[chunk.class] = index;
        }

        fn linkLast(self: *Self, index: u32) void {
            const chunk = &self.chunks.items[index];
            const tail = self.tails[chunk.class];
            chunk.next = none;
            chunk.prev = tail;
            if (tail != none) self.chunks.items[tail].next = index else self.heads[chunk.class] = index;
            self.tails[chunk.class] = index;
        }

        fn unlink(self: *Self, index: u32) void {
            const chunk = &self.chunks.items[index];
            if (chunk.prev != none) self.chunks.items[chunk.prev].next = chunk.next else self.heads[chunk.class] = chunk.next;
            if (chunk.next != none) self.chunks.items[chunk.next].prev = chunk.prev else self.tails[chunk.class] = chunk.prev;
            chunk.next = none;
            chunk.prev = none;
        }
    };
}
