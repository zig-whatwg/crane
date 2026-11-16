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
//!   MADV_FREE_REUSABLE on Apple, MADV_DONTNEED elsewhere). Memory taken from
//!   the free pool is recommitted before a byte of it is handed out:
//!   `takeChunks` for a run, `allocateSlot` for a slot.
//! - **Only what a block uses is recommitted.** MADV_FREE_REUSE counts every
//!   page of its range that still holds its old bytes - written again or not
//!   - and the kernel takes a given-back page only when it needs one, so a
//!   recommit wider than the block puts memory nobody uses back into the
//!   footprint. PartitionAlloc recommits a slot span, which it sizes to its
//!   slots (partition_bucket.cc: a few pages, or one large slot), and a
//!   direct map of the size asked for in whole pages (partition_root.h
//!   GetDirectMapSlotSize); where a span is committed piece by piece
//!   (partition_bucket.cc ProvisionMoreSlotsAndAllocOne, its lazy commit) it
//!   commits from the page after the last slot handed out to the end of the
//!   page the new slot ends on. Crane's span is the 1 MiB chunk, far wider
//!   than most slots, so it commits a chunk that way, slot by slot as
//!   `touched` grows, and a run up to its block's last page. Measured before
//!   this rule, with whole chunks recommitted (chat.local, 2026-11-16,
//!   fetch.loopback-gzip's settled mark, vmmap): each body is one block of
//!   1 MiB and 7 bytes, a run of two chunks; 24 of 39 lay on chunks the row
//!   before had written 880 KiB of, and 20.2 MB that no block used were
//!   counted - a footprint of 142 MB where V8's default held 116.5.
//! - **Decommitted memory is not zero on Apple** (page_allocator.h
//!   DecommittedMemoryIsAlwaysZeroed): a zeroed allocation is zero-filled by
//!   hand unless its memory is known never to have been handed out since the
//!   OS made it (`Block.zeroed`).
//! - **Size classes** (partition_alloc_constants.h, bucket_lookup.h: 8
//!   buckets per power of two): a block of up to 1 MiB is a slot of its
//!   class; a free takes no search and an allocation takes the lowest free
//!   slot of one chunk.
//! - **An emptied span waits before it is given back** (partition_page.cc
//!   SlotSpanMetadata::RegisterEmpty: "providing it a bit of breathing room
//!   to get re-used before we really free it. This reduces the number of
//!   system calls. Otherwise any free() from a single-slot slot span would
//!   lead to a syscall"): `wait_head`. PartitionAlloc bounds what waits
//!   twice: by a ring of 16 spans (128 in a foreground renderer and in d8's
//!   allocator, partition_alloc_constants.h) and by dirty bytes, 1/8 of the
//!   committed bytes. Crane bounds it by dirty bytes alone, `retained_max`
//!   (1 MiB: one whole chunk), oldest first - by bytes because its memory
//!   bar reads the whole process, and by no count because one operation of
//!   the engine can empty chunks of more size classes than a small ring
//!   holds, and then every operation sends chunks back to the OS and fetches
//!   them again. Measured with 16 places (chat.local, 2026-11-16, 4,000
//!   rounds, against V8's default): 40 sizes made and freed in turn - system
//!   time 0.16 s against 0.06 s, instructions 4.6 to 4.9 G against 3.6 G;
//!   12 sizes - 0.01 s against 0.02 s, 1.28 G against 1.85 G; a 19,600-bit
//!   BigInt's decimal string, whose scratch blocks are of many sizes - 0.06 s
//!   against 0.01 s. One chunk's worth is also what a loop needs that frees
//!   a block and takes one of the same size again - a 1 MiB buffer included
//!   - to make no system call per round.
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
//! - **free**: in the free pool, its memory given back to the OS. What a
//!   block uses of it is recommitted when the block is handed out.
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
/// The dirty bytes of emptied slot chunks that may wait before they go back
/// to the OS, in total, counted in whole pages: one whole chunk, so any one
/// emptied chunk can wait.
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
    /// Emptied slot chunks that wait, and their dirty bytes (whole pages).
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
    /// slots: empty, and waiting to be used again or to go back to the OS.
    waiting: bool = false,
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
    /// slots: the list of waiting chunks, while `waiting`.
    wait_next: u32 = none,
    wait_prev: u32 = none,
    /// slots: one bit per slot, set while a touched slot is free. Words at
    /// and above `touched / 64` (rounded up) are not initialised yet.
    bits: []u64 = &.{},
    /// run_head: the bytes from the run's start its block may write - the
    /// size asked for, in whole pages. What is accounted while the run is
    /// live and what goes back to the OS when it is freed; the rest of its
    /// last chunk is as the free pool left it.
    extent: usize = 0,
};

/// The allocator over `Pages`, which gives its four page operations, each
/// answering whether the OS did it. The two that change what is accessible
/// are over whole chunks, the two that do not over whole pages:
///
/// - `setReadWrite(address, size) bool`: inaccessible chunks become
///   accessible and read zero;
/// - `discard(address, size) bool`: accessible pages give their memory back
///   and stay accessible; their contents are then unspecified;
/// - `recommit(address, size) bool`: accessible pages, given back or not,
///   are accounted again before they are used;
/// - `decommit(address, size) bool`: accessible chunks give their memory
///   back and become inaccessible.
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
        /// The OS page size: what a chunk's dirty bytes are counted in.
        page_size: usize,
        /// The empty slot chunks that wait, the one that emptied first at
        /// the head.
        wait_head: u32 = none,
        wait_tail: u32 = none,
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
        /// whole chunks, `page_size` the OS page size (a power of two, at
        /// most a chunk). The range stays the caller's; `deinit` frees the
        /// records only.
        pub fn init(meta: std.mem.Allocator, pages: Pages, base: usize, size: usize, page_size: usize) std.mem.Allocator.Error!Self {
            std.debug.assert(base % chunk_size == 0);
            std.debug.assert(std.math.isPowerOfTwo(page_size) and page_size <= chunk_size);
            const max_chunks: u32 = @intCast(@min(size >> chunk_shift, @as(usize, none - 1)));
            const free_bits = try meta.alloc(u64, (max_chunks + 63) / 64);
            @memset(free_bits, 0);
            return .{ .pages = pages, .meta = meta, .base = base, .max_chunks = max_chunks, .free_bits = free_bits, .page_size = page_size };
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
            const extent = std.mem.alignForward(usize, bytes, self.page_size);
            const taken = self.takeChunks(count, extent) orelse return null;
            const run = self.chunks.items[taken.first..][0..count];
            run[0] = .{ .kind = .run_head, .used = count, .extent = extent };
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
                        self.startWaiting(index);
                    } else if (was_full) {
                        self.linkFirst(index);
                    }
                },
                .run_head => {
                    if (within != 0) return error.InvalidFree;
                    const count = chunk.used;
                    self.live_blocks -= 1;
                    self.live_bytes -= @as(u64, count) << chunk_shift;
                    self.releaseChunks(index, count, chunk.extent);
                },
                .run_body, .free => return error.InvalidFree,
            }
        }

        /// Give back every emptied chunk that waits.
        pub fn releaseRetained(self: *Self) void {
            while (self.wait_head != none) self.evict(self.wait_head);
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
            // A chunk that waits has a freed slot (it was used and emptied),
            // so it takes no page operation below and cannot fail.
            if (chunk.waiting) self.stopWaiting(index);
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
                if (!chunk.fresh) {
                    // THE RULE, for a slot: the chunk came from the free
                    // pool, and the pages this slot adds to those of the
                    // slots before it are recommitted before it is handed
                    // out - no page past the one it ends on.
                    const from = self.dirtyBytes(chunk);
                    const to = @min(chunk_size, std.mem.alignForward(usize, (@as(usize, slot) + 1) * size, self.page_size));
                    if (to > from) {
                        if (!self.pages.recommit(self.addressOf(index) + from, to - from)) {
                            // A chunk with no slot handed out yet was taken
                            // for this block: back to the free pool.
                            if (chunk.touched == 0) self.abandon(index);
                            return null;
                        }
                        self.recommits += 1;
                    }
                }
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

        /// A chunk for `class`, first in its list. From the free pool it is
        /// not accounted yet: `allocateSlot` recommits the pages of each
        /// slot it hands out.
        fn assign(self: *Self, class: u8) ?u32 {
            const bits = self.meta.alloc(u64, (slotsOf(class) + 63) / 64) catch return null;
            const taken = self.takeChunks(1, 0) orelse {
                self.meta.free(bits);
                return null;
            };
            self.chunks.items[taken.first] = .{ .kind = .slots, .class = class, .fresh = taken.fresh, .bits = bits };
            self.linkFirst(taken.first);
            return taken.first;
        }

        const Taken = struct { first: u32, fresh: bool };

        /// `count` chunks in a row, accessible, their first `account` bytes
        /// (whole pages) accounted: the lowest run of the free pool, that
        /// much of it recommitted - or, with none, new ones above
        /// `high_water`, which read zero (`fresh`) and are accounted as they
        /// are written. Their records are the caller's to write.
        fn takeChunks(self: *Self, count: u32, account: usize) ?Taken {
            if (self.findFree(count)) |first| {
                // THE RULE: what was given back is recommitted before a byte
                // of it is used (macOS: MADV_FREE_REUSE; Linux: nothing) -
                // and no more than is used: a recommitted page that still
                // holds its old bytes is counted, written or not.
                if (account > 0) {
                    if (!self.pages.recommit(self.addressOf(first), account)) return null;
                    self.recommits += 1;
                }
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

        /// `count` chunks from `first` go to the free pool and their first
        /// `dirty` bytes (whole pages: all a block could have written, and
        /// all that is accounted) to the OS; free chunks at the top leave the
        /// used range.
        fn releaseChunks(self: *Self, first: u32, count: u32, dirty: usize) void {
            for (first..first + count) |index| {
                self.chunks.items[index] = .{ .kind = .free };
                self.free_bits[index / 64] |= @as(u64, 1) << @intCast(index % 64);
            }
            self.free_count += count;
            if (first / 64 < self.free_hint) self.free_hint = first / 64;
            // At the top: decommitted with whatever free chunks lie under
            // them, in one operation, with no discard first.
            if (first + count == self.high_water and self.trimTop()) return;
            if (dirty > 0 and self.pages.discard(self.addressOf(first), dirty)) self.discards += 1;
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

        /// The bytes of a slot chunk that may be dirty: the pages its
        /// handed-out slots lie on, from its start. In a chunk that came
        /// from the free pool these are also the pages recommitted so far.
        fn dirtyBytes(self: *const Self, chunk: *const Chunk) usize {
            const touched = @as(usize, chunk.touched) * class_sizes[chunk.class];
            return @min(chunk_size, std.mem.alignForward(usize, touched, self.page_size));
        }

        /// The chunk at `index` has just become empty: it waits, the newest
        /// of those that do, and the oldest go back to the OS while more
        /// than `retained_max` dirty bytes wait (never this one: a chunk
        /// holds no more than that). A chunk that empties and fills in a
        /// loop is always the newest, so it does not push itself out, and
        /// what goes back first is what was idle longest.
        fn startWaiting(self: *Self, index: u32) void {
            const chunk = &self.chunks.items[index];
            chunk.waiting = true;
            chunk.wait_next = none;
            chunk.wait_prev = self.wait_tail;
            if (self.wait_tail != none) self.chunks.items[self.wait_tail].wait_next = index else self.wait_head = index;
            self.wait_tail = index;
            self.retained_bytes += self.dirtyBytes(chunk);
            self.retained_chunks += 1;
            while (self.retained_bytes > retained_max and self.wait_head != index) self.evict(self.wait_head);
        }

        /// A waiting chunk is used again, or goes back: it waits no more.
        fn stopWaiting(self: *Self, index: u32) void {
            const chunk = &self.chunks.items[index];
            if (chunk.wait_prev != none) self.chunks.items[chunk.wait_prev].wait_next = chunk.wait_next else self.wait_head = chunk.wait_next;
            if (chunk.wait_next != none) self.chunks.items[chunk.wait_next].wait_prev = chunk.wait_prev else self.wait_tail = chunk.wait_prev;
            chunk.wait_next = none;
            chunk.wait_prev = none;
            chunk.waiting = false;
            self.retained_bytes -= self.dirtyBytes(chunk);
            self.retained_chunks -= 1;
        }

        /// A waiting chunk leaves its class and the used memory: to the free
        /// pool.
        fn evict(self: *Self, index: u32) void {
            self.stopWaiting(index);
            self.unlink(index);
            const dirty = self.dirtyBytes(&self.chunks.items[index]);
            self.meta.free(self.chunks.items[index].bits);
            self.releaseChunks(index, 1, dirty);
        }

        /// A slot chunk no slot was handed out of leaves its class: to the
        /// free pool, with no page of it to give back.
        fn abandon(self: *Self, index: u32) void {
            self.unlink(index);
            self.meta.free(self.chunks.items[index].bits);
            self.releaseChunks(index, 1, 0);
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
