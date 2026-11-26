//! The span engine: every State block and Instance slot a Browser makes, in
//! its own reservation (allocator-hardening design, tmp/plans/allocator-
//! hardening-design.md, batch A; the user's "Build A, B, C", 2026-11-22).
//!
//! Two partitions of the Browser's heap (runtime.BrowserScope.Heap):
//!
//! | partition | holds | where | threads |
//! |-----------|-------|-------|---------|
//! | node      | every node's State block, in buckets keyed by (size class, node kind: element, character data, other) | the cage | the window agent's only: no lock, an owner check on every allocation and free |
//! | objects   | every other State block and side block, and the Instance slots (a 32-byte bucket of their own) | the objects range (in the ladder's smaller rungs, the cage's upper half) | every agent's, under one mutex |
//!
//! In both (design 3.3-3.5, 5.1):
//! - SPANS of `span_bytes`, each serving one bucket for the Browser's life
//!   (class-stable: an emptied span is decommitted and keeps its bucket -
//!   PartitionAlloc's "continues to reserve the region for this very
//!   bucket", PartitionAlloc.md:48-56 @ CR145; Scudo, hardened_malloc);
//! - FREE STATE OUT OF LINE: a span-table entry and a 2-bit slot map per
//!   span in the metadata window (free, allocated, quarantined). Nothing is
//!   ever written into a freed block but its fill (libpas: "Libpas never
//!   puts information about a free object inside that object");
//! - LOWEST ADDRESS FIRST: the lowest span of the bucket with a free slot,
//!   then its lowest free slot - never LIFO (Firefox ca3da38c7757: address
//!   order won back 61-75% of a 10x DOM-mutation regression);
//! - VALIDATED FREES, in every build: the block is this heap's, in a span of
//!   its class, at a slot boundary, allocated (a double free is a panic,
//!   quarantined slots included - PartitionAlloc catches only an immediate
//!   one, partition_page.h:768-777 @ CR145);
//! - ZERO ON FREE, VERIFIED ON ISSUE: a freed block is zeroed (0xdd in a
//!   poisoning heap: Debug and the bug-finding run), and a block is checked
//!   to be still zero (or poison) when it is issued again - a write after
//!   free is a panic (hardened_malloc's CONFIG_ZERO_ON_FREE +
//!   CONFIG_WRITE_AFTER_FREE_CHECK, h_malloc.c:485-503);
//! - THE TASK-SCOPED QUARANTINE: a block freed on the window agent's thread
//!   while its event loop runs a task is held until the task ends, with
//!   random eviction past a cap (Chrome's scheduler-loop quarantine,
//!   scheduler_loop_quarantine.cc:462-518 @ Chromium 5ae98efaacaf; purged at
//!   each task's end, 541ac7163f78);
//! - THE EMPTY-SPAN CACHE AND DECOMMIT: an emptied span stays committed, and
//!   is reused first; one empty for `decommit_age_ms` is decommitted when the
//!   loop is idle (libpas holds small pages 1.5 s on Mac, ad3ad2c6ea70;
//!   PartitionAlloc's empty slot span ring, partition_page.cc:85-130 @ CR145).
//!
//! The bug-finding run (`Config.bug_finding`) adds detection only: 0xdd, an
//! 8 MiB quarantine, inaccessible (PROT_NONE) fully freed State spans, and
//! an allocation site per block.
//!
//! std-only, like browser_heap.zig: the platform's address-space operations
//! come through the heap header's table, as V8's heap takes its pages from
//! the embedder's v8::PageAllocator.

const std = @import("std");
const builtin = @import("builtin");
const debug_options = @import("debug_options");
const platform = @import("platform");
const browser_heap = @import("../browser_heap.zig");
pub const classes = @import("classes.zig");
/// The general allocator over the objects and bytes partitions (batch B).
pub const general = @import("general.zig");
/// The satellite allocator over the cage's satellite partition (batch B2).
pub const satellite = @import("satellite.zig");

/// Whether allocation/free observer callouts (for tooling / Darwin
/// `malloc_logger`, `[V2] D8`, Batch C item 5) are compiled in. False in
/// production release builds so the hot path pays zero instructions.
pub const alloc_log_compiled: bool = builtin.mode == .debug or debug_options.heap_alloc_log;

/// Allocation/free observer hook for tooling builds (`[V2] D8`, Batch C item 5).
pub const AllocObserver = struct {
    context: ?*anyopaque = null,
    on_alloc: *const fn (context: ?*anyopaque, partition: PartitionId, size: usize, address: usize) void,
    on_free: *const fn (context: ?*anyopaque, partition: PartitionId, address: usize) void,
};

const BrowserHeap = browser_heap.BrowserHeap;
const Classes = classes.Classes;
/// The classes general blocks take (batch B, M8-4a): `halves_span` - 16-byte
/// steps to 64 B, halves through 4 KiB, then span-divisor-clean 5,120 B
/// (3 slots/span, replacing 6,144 B which fit 2 and wasted 25%), 8,192 B
/// (2/span), and 16,384 B (1/span, dropping redundant 12,288 B): 19 classes.
pub const GeneralClasses = classes.SizeClasses(.halves_span);
/// Design 3.4 (`production, objects`): general objects blocks zero up to the
/// first 1 KiB on free and verify the zeroed part on issue (zeroing any
/// remainder of the request on reissue so every pointer-bearing block is zero
/// when issued; bug-finding / poisoning builds fill & verify the whole block).
const general_objects_zero_cap: usize = 1024;

/// Comptime magic multiplier for exact `within / block_bytes` over any offset
/// within a 16 KiB span (`within < 16384`, `block_bytes = 16 * m`, `1 <= m <= 1024`):
/// `((within >> 4) * magic) >> 20 == within / block_bytes` with zero runtime
/// `udiv`, and `slot * block_bytes == within` checks exact alignment in one
/// multiply-compare (batch B, M4).
const SlotDiv = struct {
    block_bytes: u32,
    magic: u32,
};
const general_slot_div: [GeneralClasses.count]SlotDiv = blk: {
    var table: [GeneralClasses.count]SlotDiv = undefined;
    for (0..GeneralClasses.count) |c| {
        const bb = GeneralClasses.bytes(c);
        const m = bb / 16;
        table[c] = .{
            .block_bytes = @intCast(bb),
            .magic = @intCast(((@as(usize, 1) << 20) + m - 1) / m),
        };
    }
    break :blk table;
};

comptime {
    // Pin exactness of the magic multiplier for every general class and
    // every 16-byte position in a span (compile-time check, zero runtime cost).
    @setEvalBranchQuota(100_000);
    for (0..GeneralClasses.count) |c| {
        const d = general_slot_div[c];
        const slots_in_span = browser_heap.span_bytes / 16;
        for (0..slots_in_span) |q| {
            const within = q * 16;
            const slot = (q * d.magic) >> 20;
            if (slot != within / d.block_bytes) @compileError("general_slot_div magic mismatch");
        }
    }
}

/// The general class of a request, or null past the largest (a large run).
inline fn generalClassOf(size: usize, alignment: usize) ?usize {
    const n = classes.requestBytes(size, alignment);
    if (n > GeneralClasses.max_size) return null;
    const class = GeneralClasses.of(n);
    std.debug.assert(alignment <= classes.natural_alignment or GeneralClasses.bytes(class) % alignment == 0);
    return class;
}

/// Fast general class lookup from `std.mem.Alignment` (batch B, M4/M7-1):
/// 99%+ of calls have `alignment <= 16` (`align_log2 <= 4`) and most have
/// `size <= 64`, avoiding `toByteUnits()`, `alignForward` and runtime modulo.
inline fn generalClassOfAlign(size: usize, alignment: std.mem.Alignment) ?usize {
    if (@backingInt(alignment) <= 4) {
        if (size <= 64) return if (size == 0) 0 else (size - 1) >> 4;
        if (size <= GeneralClasses.max_size) return GeneralClasses.of(size);
        return null;
    }
    return generalClassOfSlow(size, alignment.toByteUnits());
}

fn generalClassOfSlow(size: usize, alignment: usize) ?usize {
    @branchHint(.cold);
    return generalClassOf(size, alignment);
}
const layout = browser_heap.layout;

const KiB: usize = 1024;
const MiB: usize = 1024 * KiB;

/// A span: whole pages on every host (browser_heap.span_bytes).
pub const span_bytes: usize = @intCast(browser_heap.span_bytes);
const super_page: usize = @intCast(browser_heap.super_page_bytes);
/// The spans of a super page past its guard span: the longest run a large
/// block can take (a run never crosses a super page, so its decommit never
/// does: BrowserHeap.decommit).
pub const max_run_spans: usize = super_page / span_bytes - 1;
/// The most slots a span has: 16-byte blocks.
const max_slots: usize = span_bytes / 16;
/// The words of a slot map: 2 bits per slot.
const map_words: usize = max_slots * 2 / 64;
/// The largest block the engine serves: a run of every span of a super page.
pub const max_block_bytes: usize = max_run_spans * span_bytes;
/// A general block past this is HUGE (batch B, `Engine.allocHuge`): whole
/// super pages of its partition with guard spans, retired on free. A large
/// run below it. At most `max_block_bytes`; measured with time and memory
/// before it is chosen (the design's 1 MiB own-mapping threshold is 2 MiB
/// here: the runs below are batch A's large buckets).
pub const huge_threshold_bytes: usize = max_block_bytes;

/// The byte a poisoning heap fills a freed block with (the state arena's
/// and the test allocators' poison, tests/test_runner/poisoning.zig).
pub const poison_byte: u8 = 0xdd;

/// The bytes of an Instance slot the slab fills on free and checks on issue:
/// the Instance (vtable, state, ctx). The stamp after it is the slab's - a
/// freed slot's generation must read dead, and its lifecycle flags survive
/// the free (runtime.instance_lifecycle).
pub const instance_fill_bytes: usize = 24;
/// An Instance slot: the Instance and its stamp.
pub const instance_slot_bytes: usize = 32;

// ============================================================================
// Configuration
// ============================================================================

pub const Fill = enum(u8) {
    /// Production: a freed block reads zero - a stale pointer read through
    /// it is null, and a decommitted page reads the same whatever the OS
    /// kept (lesson architecture-a-decommitted-page-on-macos-still-reads-
    /// its-old-bytes.md).
    zero,
    /// Debug builds and the bug-finding run: 0xdd, which no pointer, length
    /// or tag reads as valid (lane uaf1).
    poison,
};

/// What a failed check does.
pub const Checks = enum(u8) {
    /// Every build: the process ends, naming the violation.
    panic,
    /// A test's hook (design 7: "an allocator's own corruption checks are
    /// tested through a hook that returns the error where production
    /// panics"): the violation is recorded (`takeViolation`), the free is
    /// not done, and an issue goes on.
    report,
};

pub const Config = struct {
    fill: Fill,
    /// The bytes the window agent's quarantine holds before it evicts at
    /// random. Decision U2 (design 9.1), the user's ruling 2026-11-24 on
    /// batch A's numbers: 512 KiB, over the 2 MiB proposed - about half the
    /// quarantine's memory cost on the rows that free inside one task
    /// (events.dispatch peak 1.110 against 1.213 at 2 MiB; dom.build-tree
    /// 1.108 against 1.182), with random eviction unchanged.
    quarantine_cap: usize,
    /// Make a State span that has emptied inaccessible (discard, then
    /// PROT_NONE: lesson architecture-macos-recommit-needs-madv-free-reuse),
    /// up to `retired_spans_max` at once (Linux's vm.max_map_count). Never
    /// an Instance-slot span: reading a freed slot's generation is a legal
    /// read (SlabAllocator.generationOf).
    retire_freed_spans: bool,
    /// Keep an allocation site per block for the leak report.
    record_sites: bool,

    pub const production_quarantine_cap: usize = 512 * KiB;
    pub const bug_finding_quarantine_cap: usize = 8 * MiB;
    pub const retired_spans_max: usize = 1024;

    /// What every release build ships.
    pub const production: Config = .{ .fill = .zero, .quarantine_cap = production_quarantine_cap, .retire_freed_spans = false, .record_sites = false };
    /// A Debug build's default - the unit tests and the bug-finding runner's
    /// Crane modules: poison, and sites for the leak report.
    pub const debug_default: Config = .{ .fill = .poison, .quarantine_cap = production_quarantine_cap, .retire_freed_spans = false, .record_sites = true };
    /// A Browser that asked for poisoned frees (BrowserConfig.
    /// poison_freed_state: the bug-finding WPT runner).
    pub const bug_finding: Config = .{ .fill = .poison, .quarantine_cap = bug_finding_quarantine_cap, .retire_freed_spans = true, .record_sites = true };

    /// The configuration a heap gets: `poison` (a Debug build, or a Browser
    /// that asked) and `bug_finding` (a Browser that asked). Pinned for
    /// every combination by a test.
    pub fn of(poison: bool, bug_finding_run: bool) Config {
        if (bug_finding_run) return bug_finding;
        if (poison) return debug_default;
        return production;
    }

    fn fillByte(config: Config) u8 {
        return switch (config.fill) {
            .zero => 0,
            .poison => poison_byte,
        };
    }
};

/// How long an emptied State span stays committed before an idle loop
/// decommits it (design 5.1: libpas's 1.5 s on Mac, 750 ms elsewhere; 1 s here).
pub const decommit_age_ms: u32 = 1000;
/// How long an emptied general span or MRU general large run stays committed
/// before an idle loop decommits it (M7-3: matches `memory_release.idle_delay_ns`,
/// 200 ms, so active timed loops keep their hot empty-span cache and 4 MiB MRU
/// large-run ring with zero syscalls while idle pages reclaim to zero beside
/// libc's idle release).
pub const general_decommit_age_ms: u32 = 200;

/// What a heap check found.
pub const Violation = enum(u8) {
    /// The block was freed already (or is held in the quarantine).
    double_free,
    /// Not the start of a block this heap issued: an interior pointer, a
    /// span no block was issued from, a run's tail.
    invalid_free,
    /// The block's span is of another class than the size and alignment
    /// the free gives.
    wrong_size,
    /// Not this Browser's heap.
    other_heap,
    /// A freed block's bytes changed before its reissue: a write through a
    /// pointer kept past the free.
    write_after_free,
    /// A node-partition block made or freed off the window agent's thread.
    wrong_thread,

    pub fn describe(v: Violation) []const u8 {
        return switch (v) {
            .double_free => "a block freed twice (or freed while the quarantine holds it)",
            .invalid_free => "a free of an address that is not the start of a block this heap issued",
            .wrong_size => "a free whose size and alignment are of another class than the block's span",
            .other_heap => "a free of a block another Browser's heap issued, or no heap",
            .write_after_free => "a freed block was WRITTEN after its free: a pointer into it was kept past the free",
            .wrong_thread => "a node or satellite block made or freed off the window agent's thread",
        };
    }
};

/// Which partition a block goes to.
pub const NodeKind = enum(u8) { element = 0, character_data = 1, other = 2 };
const node_kinds = 3;

pub const Target = union(enum) {
    /// A node's State block, of this kind.
    node: NodeKind,
    /// Any other State block or side block.
    objects,
};

/// The partitions of a Browser's heap.
/// - `node`: node State blocks in the cage's lower half (window agent only).
/// - `satellite` (batch B2): node-linked satellite blocks in the cage's upper
///   half (window agent only, segregated from `node`, `objects`, and `bytes`).
/// - `objects`: non-node States, Instance slots, and pointer-bearing general blocks.
/// - `bytes` (batch B1): page-controlled pointer-free bytes (no quarantine, no
///   production zeroing).
pub const PartitionId = enum(u2) { node = 0, satellite = 1, objects = 2, bytes = 3 };

/// Whether `pid` is accessed concurrently by multiple agent threads (requiring
/// its mutex and atomic slot-map updates); `node` and `satellite` are
/// window-agent-only and lock-free.
inline fn isSharedPartition(pid: PartitionId) bool {
    return pid == .objects or pid == .bytes;
}

/// Whether empty spans of `b` in `pid` use adaptive active retention + 200 ms
/// idle decommit (general pools and satellites).
inline fn usesAdaptiveRetention(pid: PartitionId, b: *const Bucket) bool {
    return b.general or pid == .satellite;
}

// ============================================================================
// Out-of-line metadata: span entries, slot maps, chunks
// ============================================================================

pub const SpanState = enum(u8) {
    /// Never opened: no bucket, no committed slots.
    unopened = 0,
    /// Committed and serving its bucket (full, partly used or empty).
    active = 1,
    /// Empty, its pages given back; reused after every committed span.
    decommitted = 2,
    /// Empty and inaccessible (the bug-finding run's freed spans).
    retired = 3,
    /// A span of a large block's run past its first: no block starts here.
    run_tail = 4,
    /// Committed free `bytes` large-run span held in the coalescing pool (M8-3).
    free_run = 5,
};

/// A span's entry in the span table (one per `span_bytes` of the window's
/// lower half, in the metadata window).
pub const SpanEntry = extern struct {
    /// Its bucket, in its partition; `no_bucket` while unopened.
    bucket: u16,
    state: SpanState,
    /// Per-span/page flags (M8-2: `flag_map_decommitted` on the first span of
    /// an OS bitmap page whose slots are all inactive and decommitted).
    flags: u8 = 0,
    /// Blocks it holds.
    slots: u16,
    /// Slots allocated or quarantined.
    used: u16,
    /// Of `used`, the quarantined ones.
    quarantined: u16,
    /// No slot below this one is free.
    hint: u16,
    /// Slots at and above this one were never issued since the span was
    /// (re)committed: they read zero, whatever the fill.
    issued_hi: u16,
    /// Spans of its run: 1, or a large block's count.
    run: u16,
    /// The chunk of its bucket's list it is in; for a run's tail, its first
    /// span's index.
    chunk: u32,
    /// Its place in that chunk.
    ordinal: u32,
    /// The engine's clock at its last release of a slot - to its span or to
    /// its bucket's magazine: once it is empty, when it emptied (what idle
    /// decommit ages it from), however long a magazine held its last block.
    empty_since: u32,
    /// Its sites array in the metadata pool (offset / 256 + 1), or 0.
    sites: u32,

    const no_bucket: u16 = std.math.maxInt(u16);
    const flag_map_decommitted: u8 = 1;
};

comptime {
    if (@sizeOf(SpanEntry) != browser_heap.span_entry_bytes) @compileError("a span entry is span_entry_bytes");
    if (map_words * 8 != browser_heap.slot_map_bytes) @compileError("a slot map is slot_map_bytes");
}

/// A slot's state, two bits in its span's slot map. `cached`: released (past
/// the quarantine, if it went there) and held in its bucket's magazine for
/// the next allocation - still free state, out of the block: a free of it is
/// a double free (`Engine.freeIn`), and the span counts it as used.
const SlotState = enum(u2) { free = 0, allocated = 1, quarantined = 2, cached = 3 };

/// The tiers a bucket's spans are found in, lowest address first.
const Tier = enum(u2) {
    /// Committed, with a free slot.
    room = 0,
    /// Committed and empty (a subset of `room`): what an idle loop ages.
    empty = 1,
    /// Decommitted or retired: reused when no committed span has room.
    released = 2,
};

/// A piece of a bucket's span list, in its partition's pool: its spans in
/// address order (spans open at the partition's frontier and never change
/// bucket, so a bucket's list is in address order by construction), and a
/// mask per tier.
const Chunk = extern struct {
    masks: [3]u64,
    next: u32,
    count: u32,
    spans: [chunk_spans]u32,

    const chunk_spans = 56;
};

comptime {
    if (@sizeOf(Chunk) != 256) @compileError("a chunk is 256 bytes");
}

const no_chunk: u32 = std.math.maxInt(u32);
const no_span: u32 = std.math.maxInt(u32);

const BucketKind = enum(u8) { class, instance, large };

const Bucket = struct {
    first: u32 = no_chunk,
    last: u32 = no_chunk,
    /// The lowest span with a free slot, once found; `no_span` until the
    /// next allocation looks.
    current: u32 = no_span,
    spans: u32 = 0,
    hints: [3]u32 = .{ no_chunk, no_chunk, no_chunk },
    block_bytes: u32 = 0,
    fill_bytes: u32 = 0,
    slots: u16 = 0,
    run: u16 = 1,
    kind: BucketKind = .class,
    /// A general bucket (batch B): the bytes partition's, or one of the
    /// objects partition's past its State buckets.
    general: bool = false,
    /// Its spans in the empty tier now (committed, no block in use).
    empty_count: u32 = 0,
    /// Adaptive active empty-span cap for general class buckets (M8-4b):
    /// starts tight (2 for <= 2 KiB, 1 for > 2 KiB), doubles on fast (< 200 ms)
    /// recommit thrashing up to `empty_class_thrash_cap`, and resets on idle.
    empty_cap: u16 = 0,
    /// Blocks allocated (not quarantined) now, and issued over the heap's
    /// life.
    live: u32 = 0,
    issued: usize = 0,
    /// The most blocks live at once over the heap's life: `live`'s high-water
    /// mark. Not the spans' slots: a slot the quarantine holds or the magazine
    /// caches is no live block, yet keeps its span's slot taken.
    live_peak: u32 = 0,
    /// The live blocks' requests' bytes, and every request's over the
    /// heap's life.
    requested: usize = 0,
    requested_total: usize = 0,
    /// Of `issued`, the slots issued for the first time (the rest were
    /// freed before: reissues).
    fresh: usize = 0,
    /// The magazine: the blocks released last, reissued first (`Engine.
    /// release`, `Engine.allocIn`) - a pool chunk of `magazine_depth` block
    /// offsets (window offset / 16), `no_chunk` until the bucket first
    /// releases one; how many it holds.
    mag: u32 = no_chunk,
    mag_count: u16 = 0,
    // The partition's figures (PartitionStats' live and total counts) are
    // these, summed when asked (`Engine.stats`): one bucket's line is what
    // an allocation and a free touch, never a second line of totals (lane
    // hard1's P1: the totals' updates were 3.3 ns of a 36 ns pair).
};

/// The random buckets per (size class, node kind) (design 3.2 step 5,
/// WebKit's TZone, f3f8a5374a00): each node interface goes to one of K, by a
/// per-Browser random assignment, so a stale pointer to one interface meets
/// another interface of its class and kind only if the two drew the same
/// bucket. K = 2 ships: batch A measured it within the bar against K = 1
/// (time at most 1.024, memory at most 1.021 on the tree and query rows;
/// K = 4 read 1.032 on query-selector's peak), the brief's rule; the
/// integrator's ruling 2026-11-24. A variant is this constant.
pub const random_buckets: usize = 2;

/// A bucket's magazine: the blocks it released last, reissued first, with no
/// span search, tier flip or slot-map scan (lane hard1's P1: those were the
/// core's 26 ns a pair against 8.5 for the old LIFO lists; lowest-address-
/// first itself measured nothing). Chromium's ThreadCache has the same
/// place - after the scheduler-loop quarantine, before the slot spans
/// (partition_alloc/thread_cache.h, ThreadCache::MaybePutInCache, Chromium
/// 461c62b66d7c) - so delayed reuse is the quarantine's as before; unlike
/// it, the magazine keeps the free state out of the block (offsets in a side
/// array, design 3.4). It relaxes lowest-address-first within its depth
/// only, and takes a block only from a span at or below its bucket's lowest
/// span with room (`release`); idle decommit and pressure drain it (`drainMagazines`), and the
/// bug-finding run, which retires a span the moment it empties, bypasses it.
/// 0 turns it off.
pub const magazine_depth: usize = 32;

comptime {
    if (magazine_depth * @sizeOf(u32) > 256) @compileError("a magazine is one pool chunk");
}

/// Buckets: node = 3 kinds x K x classes, then the large runs; satellite =
/// exact 16-B classes (`Classes`), then the large runs; objects = the State
/// blocks' classes, the Instance slots, the State blocks' large runs, then
/// the GENERAL objects blocks' classes and large runs (batch B: a freed
/// general block never becomes a State block, nor the reverse); bytes =
/// classes, then the coalescing large-run sentinel.
const node_groups = node_kinds * random_buckets;
const node_bucket_count = node_groups * Classes.count + max_run_spans;
const satellite_bucket_count = Classes.count + max_run_spans;
const objects_state_count = Classes.count + 1 + max_run_spans;
const objects_bucket_count = objects_state_count + GeneralClasses.count + max_run_spans;
/// The first general objects bucket (batch B).
const general_objects_base: usize = objects_state_count;

/// The general allocator's bucket of `pid` (objects or bytes) for a block
/// of `class`, or of a large run of `run` spans (`class` null).
fn generalBucket(pid: PartitionId, class: ?usize, run: usize) u16 {
    return switch (pid) {
        .node, .satellite => unreachable,
        .objects => @intCast(if (class) |c| general_objects_base + c else general_objects_base + GeneralClasses.count + run - 1),
        .bytes => if (class) |c| @intCast(c) else bytes_large_bucket,
    };
}

/// Whether `pid`'s bucket `index` serves general memory (batch B).
fn isGeneralBucket(pid: PartitionId, index: usize) bool {
    return switch (pid) {
        .node, .satellite => false,
        .objects => index >= general_objects_base,
        .bytes => true,
    };
}
/// Sentinel bucket for `bytes` coalescing large runs (M8-3): `bytes` large
/// runs (`> 16 KiB` up to `huge_threshold_bytes`) are managed by a single
/// per-super-page coalescing free-run pool instead of 127 fixed buckets.
const bytes_large_bucket: u16 = GeneralClasses.count;
const bytes_bucket_count = GeneralClasses.count + 1;
const instance_bucket: u16 = Classes.count;

fn nodeBucket(kind: NodeKind, k: usize, class: usize) u16 {
    return @intCast((@as(usize, @backingInt(kind)) * random_buckets + k) * Classes.count + class);
}

fn largeBucket(pid: PartitionId, run: usize) u16 {
    const base: usize = switch (pid) {
        .node => node_groups * Classes.count,
        .satellite => Classes.count,
        .objects => Classes.count + 1,
        .bytes => return bytes_large_bucket,
    };
    return @intCast(base + run - 1);
}

/// The run a large block of `bytes` takes.
fn runOf(bytes: usize) usize {
    return (bytes + span_bytes - 1) / span_bytes;
}

// ============================================================================
// Partitions
// ============================================================================

pub const PartitionStats = struct {
    /// Spans serving their bucket, committed (full, partly used or empty).
    spans_active: usize = 0,
    /// Of those, the empty ones (the cache).
    spans_empty: usize = 0,
    spans_decommitted: usize = 0,
    spans_retired: usize = 0,
    /// OS pages of `layout.bitmaps` currently decommitted by idle reclaim
    /// because every span in the page is inactive (M8-2).
    bitmap_pages_decommitted: usize = 0,
    // The live, quarantined and total figures below are summed by
    // `Engine.stats` (from the buckets and the quarantine); a partition's
    // own copy keeps them zero.
    live_blocks: usize = 0,
    /// Their classes' bytes.
    live_bytes: usize = 0,
    /// Their requests' bytes.
    requested_bytes: usize = 0,
    quarantined_blocks: usize = 0,
    quarantined_bytes: usize = 0,
    /// Address space assigned to spans so far (design 5.4: class-stable
    /// spans can use up address space with little live memory).
    va_assigned: usize = 0,
    /// Blocks issued over the heap's life, and of those, reissues of a slot
    /// freed before.
    total_allocations: usize = 0,
    total_requested_bytes: usize = 0,
    total_reissued: usize = 0,
    /// Bytes of committed spans (runs counted whole): what the partition
    /// keeps resident at most.
    committed_span_bytes: usize = 0,
    /// Whether the partition passed 90% of its address space (design 5.4).
    pressure_raised: bool = false,
    /// Huge blocks alive (batch B: past a large run) and their committed
    /// bytes. Counted in the live figures by `Engine.stats`.
    huge_blocks: usize = 0,
    huge_bytes: usize = 0,
};

/// A free span run inside the `bytes` partition's coalescing large-run pool
/// (M8-3, Design 3.1: `bytes` spans are pointer-free and not class-stable).
/// Never crosses a `super_page` boundary.
const BytesRun = extern struct {
    first: u32,
    len: u16,
    committed: bool,
    _pad: u8 = 0,
    empty_since: u32,
};

const Partition = struct {
    id: PartitionId,
    /// Window offsets: the partition's address space.
    lo: usize,
    hi: usize,
    /// The address space a test caps it to (A12); `hi` otherwise.
    limit: usize,
    /// The next span to open.
    frontier: usize,
    /// Data committed up to here (whole super pages).
    data_hi: usize,
    /// Metadata committed up to here: span table, slot maps.
    table_hi: usize,
    map_hi: usize,
    /// The node partition's thread token: the first that made a block in it.
    owner: ?usize = null,
    /// The objects and bytes partitions' lock (every agent's thread
    /// allocates there).
    mutex: std.Io.Mutex = .init,
    /// Huge blocks' regions (batch B): a table in the metadata pool, and how
    /// many it holds.
    huge_table: u32 = no_chunk,
    huge_count: u32 = 0,
    /// Committed bytes of general large runs currently in the empty tier
    /// (objects partition: maintained by `setTier`, bounded by
    /// `empty_large_budget_bytes`: M8-4b).
    empty_large_bytes: usize = 0,
    /// MRU ring of committed empty objects large-run span indices (oldest at
    /// index 0, newest at `empty_large_len - 1`): hot 32-96 KiB loops hit
    /// 100% with zero syscalls, evicting oldest past `empty_large_ring_cap`
    /// or `empty_large_budget_bytes` (M8-4b).
    empty_large_ring: [empty_large_ring_cap]u32 = @splat(no_span),
    empty_large_len: u8 = 0,
    /// Committed empty general class spans currently in the empty tier
    /// (maintained by `setTier`, bounded by `empty_class_budget`: M8-4b).
    empty_class_spans: usize = 0,
    /// Adaptive per-partition active empty-class budget (starts tight at
    /// `empty_class_budget_default`, expands up to `empty_class_thrash_cap`
    /// only when buckets actually recommit-thrash, resets on idle: M8-4b).
    empty_class_budget: usize = empty_class_budget_default,
    /// `bytes` coalescing large-run pool (M8-3): sorted by `first`, stored
    /// lazily in `Engine`'s shared metadata pool.
    bytes_runs_chunk: u32 = no_chunk,
    bytes_runs_len: u32 = 0,
    bytes_runs_cap: u32 = 0,
    bytes_free_committed_bytes: usize = 0,
    bytes_large_live_bytes: usize = 0,
    stats: PartitionStats = .{},
};

/// A huge block's region of a partition (`Engine.allocHuge`).
const HugeRegion = extern struct {
    /// Its first data span.
    first: u32,
    data_spans: u32,
    /// The spans committed now: its block's, or 0 when it is free.
    committed: u32,
    used: bool,
    _pad: [3]u8 = .{ 0, 0, 0 },
};
/// The huge regions a partition keeps at most.
const huge_regions_max: usize = 4096;
/// A huge block's span entry's bucket.
const huge_bucket: u16 = std.math.maxInt(u16) - 1;

/// How many blocks an agent's cache keeps per cached class of each general
/// partition (batch B, M3: W2 measured depth 8 equal on time and strictly
/// lower on memory than 32 and 128).
pub const cache_depth: usize = 8;

/// Largest general class cached in `AgentCache` (M3): classes past 2 KiB
/// (3-16 KiB) go straight to the shared path so large spans are never
/// pinned `.cached` in a thread cache.
pub const cache_max_bytes: usize = 2048;
const cache_class_count: usize = GeneralClasses.of(cache_max_bytes) + 1;

comptime {
    if (cache_class_count > 15) @compileError("M8-1 quarantine class tag (class + 1) must fit in low 4 alignment bits");
}

/// M8-4b (tight default + thrash-adaptive active empty-span retention):
/// - Objects large runs: 4-slot / 256 KiB MRU ring (covers 100% of hot
///   32-96 KiB loops on style/fetch/parser while cutting `load.docs` empty
///   objects large runs from 848 KiB to <= 256 KiB).
/// - Bytes coalescing large runs (M8-3): 4 MiB active committed pool so
///   streaming `ArrayList` growth reuses & coalesces with zero recommits,
///   reclaimed to 0 KiB at 200 ms idle.
/// - General class spans: start tight (`2` for <= 2 KiB, `1` for > 2 KiB,
///   `32` spans/partition), and double a `<= 2 KiB` bucket's cap up to
///   `empty_class_thrash_cap` (512 spans = 8 MiB) ONLY when a span is
///   recommitted within `< general_decommit_age_ms` (proven thrashing, e.g.
///   `parser`'s 42k `cls_imm`), resetting to default on idle reclaim.
const empty_large_ring_cap: usize = 4;
const empty_large_budget_bytes: usize = 256 * KiB;
const bytes_free_committed_budget: usize = 4 * MiB;
const empty_class_small_default: u16 = 2;
const empty_class_large_default: u16 = 1;
const empty_class_budget_default: usize = 32;
const empty_class_thrash_cap: u16 = 512;

/// An agent's general-memory cache (design 3.7): per small class (<= 2 KiB)
/// of the objects and bytes partitions, a stack of released blocks' offsets -
/// an array, no link in any block (libpas's thread-local cache,
/// pas_thread_local_cache.h) - which its agent's thread takes from and gives
/// back to without the partition's lock. Its blocks are `.cached` (or, for
/// window-thread `.objects` frees during a task, `.quarantined`: M8-1) in
/// their slot maps, so a double free of one is caught. Reached through its
/// allocator (heap.general), never a threadlocal; in the metadata pool.
pub const AgentCache = struct {
    engine: *Engine,
    /// The agent's thread token: the one whose calls take the cache unlocked. 0
    /// once detached.
    owner: std.atomic.Value(usize),
    /// Hot read-only geometry cached from `engine` + `engine.heap` so
    /// `cacheAlloc` and `cacheFree` never chase `cache -> engine -> heap` on
    /// the fast path (M4).
    window_base: usize = 0,
    reserved_base: usize = 0,
    reserved_size: usize = 0,
    bitmaps_base: usize = 0,
    span_table_base: usize = 0,
    part_lo: [2]usize = .{ 0, 0 },
    part_size: [2]usize = .{ 0, 0 },
    poison: bool = false,
    record_sites: bool = false,
    /// Owner-thread shadow of `held`: mutated without atomic RMW and mirrored
    /// to `held` via plain monotonic stores for `Engine.stats()` (M4).
    held_local: [2]usize = .{ 0, 0 },
    /// Blocks the stacks (and window-thread cached-class quarantine, M8-1)
    /// hold now (objects, bytes): out of their spans and counted live in
    /// their buckets, but no one's - the stats subtract them.
    held: [2]std.atomic.Value(usize) = .{ .init(0), .init(0) },
    held_bytes_local: [2]usize = .{ 0, 0 },
    held_bytes: [2]std.atomic.Value(usize) = .{ .init(0), .init(0) },
    /// Owner-thread cached partition frontiers (objects, bytes): avoids an
    /// `.acquire` load of `p.frontier` on 99.999% of `cacheFree` calls (M4).
    seen_frontier: [2]usize = .{ 0, 0 },
    /// Per-class stack counts (48 bytes total, 1 cache line) and power-of-2
    /// stride offset arrays (32 bytes per class, zero multiply to index: M4).
    counts: [2][cache_class_count]u8 = @splat(@splat(0)),
    slots: [2][cache_class_count][cache_depth]u32 = undefined,
    next: ?*AgentCache = null,

    /// The agent's general allocator: this cache on its thread, the shared
    /// path elsewhere.
    pub fn allocator(self: *AgentCache) std.mem.Allocator {
        return general.agentAllocator(self);
    }
};

// ============================================================================
// The quarantine
// ============================================================================

/// M8-1: low 4 bits of a quarantine entry tag cached-class general `.objects`
/// blocks owned by the window agent's `AgentCache` (`class + 1` in `1..14`;
/// `0` = span-owned node/State/large block). All block addresses are 16-byte
/// aligned, so low 4 bits are always 0 on real addresses.
const quarantine_tag_mask: usize = 0xf;
/// M8-4c: inline quarantine buffer inside `Engine`'s already-committed page so
/// idle/empty Browsers commit 0 external `layout.quarantine` pages (-16 KiB).
const quarantine_inline_cap: usize = 512;

const Quarantine = struct {
    /// Whether frees on `thread` are held now: while the window agent's
    /// event loop runs a turn (`beginTask` .. `endTask`). Read by every
    /// thread that frees an objects block.
    active: std.atomic.Value(bool) = .init(false),
    /// The window agent's thread token; read by every thread that frees.
    thread: std.atomic.Value(usize) = .init(0),
    /// The window agent's cache owning tagged (`entry & 0xf != 0`) entries
    /// (M8-1). Mutated on the window thread (or under `objects.mutex` on
    /// `detachAgent`).
    window_cache: ?*AgentCache = null,
    count: usize = 0,
    held_bytes: usize = 0,
    /// Whether `layout.quarantine` has been committed (false while `count`
    /// fits in `inline_entries`: M8-4c).
    using_external: bool = false,
    /// Entries committed in `layout.quarantine` when `using_external`.
    committed: usize = 0,
    /// Over the heap's life: blocks held, and of those evicted early.
    total_held: usize = 0,
    total_evicted: usize = 0,
    /// The next eviction's entry, drawn by the hold before, and the address
    /// it held then (`Engine.hold`).
    next_slot: usize = std.math.maxInt(usize),
    next_entry: usize = 0,
    inline_entries: [quarantine_inline_cap]usize = undefined,
};

// ============================================================================
// The engine
// ============================================================================

pub const Error = error{OutOfMemory};

pub const Stats = struct {
    node: PartitionStats,
    /// Node-linked satellites in the cage (batch B2).
    satellite: PartitionStats = .{},
    /// The objects partition: its span figures, and its State blocks' and
    /// Instance slots' live and total figures.
    objects: PartitionStats,
    /// The objects partition's general blocks (batch B): live and total
    /// figures only - their spans are counted in `objects`.
    general_objects: PartitionStats = .{},
    bytes: PartitionStats,
    quarantine_blocks: usize,
    quarantine_bytes: usize,
    /// Committed bytes in `layout.quarantine` (0 while inline buffer suffices: M8-4c).
    quarantine_external_bytes: usize = 0,
    quarantine_total_held: usize,
    quarantine_total_evicted: usize,
};

/// One leak report line: blocks alive in a bucket, by allocation site where
/// the heap records sites (a type's name, or a return address).
pub const LeakLine = struct {
    partition: PartitionId,
    block_bytes: usize,
    count: usize,
    /// The State type's name, where the block was made typed.
    type_name: ?[]const u8,
    /// The allocation's return address, where it was made untyped.
    return_address: usize,
    /// General memory (batch B): a bytes block, a huge block, or an objects
    /// block the general allocator made.
    general: bool = false,
};

/// A site: a typed allocation names its type; an untyped one its return
/// address, tagged in the top bit.
pub const Site = struct {
    name: []const u8,

    pub fn of(comptime T: type) *const Site {
        return &struct {
            const site: Site = .{ .name = @typeName(T) };
        }.site;
    }
};
const site_return_tag: usize = @as(usize, 1) << (@bitSizeOf(usize) - 1);
/// An untyped site the general allocator recorded (batch B): its blocks are
/// general memory, whose leak a test build fails on (BrowserScope's end).
const site_general_tag: usize = @as(usize, 1) << (@bitSizeOf(usize) - 2);

pub const Engine = struct {
    magic: u64 = magic_value,
    heap: *BrowserHeap,
    config: Config,
    checks: Checks = .panic,
    last_violation: ?Violation = null,
    page: usize,
    node: Partition,
    /// Node-linked satellites in the cage's upper half (batch B2): window
    /// agent only, no lock.
    satellite: Partition,
    objects: Partition,
    /// The page's bytes (batch B): empty (lo == hi) in a rung without
    /// general pools, where general memory stays on the host's allocator.
    bytes: Partition,
    node_buckets: [node_bucket_count]Bucket,
    satellite_buckets: [satellite_bucket_count]Bucket,
    objects_buckets: [objects_bucket_count]Bucket,
    bytes_buckets: [bytes_bucket_count]Bucket,
    quarantine: Quarantine = .{},
    prng: std.Random.DefaultPrng,
    /// The Browser's seed for `randomBucket`.
    bucket_seed: u64 = 0,
    /// The engine's clock, ms: what the window agent's loop last read
    /// (`setNow`), so a free never reads a clock.
    now_ms: std.atomic.Value(u32) = .init(0),
    /// The bug-finding run's retired spans now.
    retired: std.atomic.Value(usize) = .init(0),
    /// Called once a partition passes 90% of its address space, after the
    /// quarantine is purged and every empty span decommitted (design 5.4).
    pressure_hook: ?PressureHook = null,
    /// A test build's failure injector (design 7 batch A item 1): asked
    /// before a span opens, as the state arena's chunk growth asked its
    /// backing allocator, so a scope made over std.testing's FailingAllocator
    /// still fails its State allocations in checkAllAllocationFailures
    /// sweeps. False fails the allocation with OutOfMemory.
    grow_hook: ?GrowHook = null,
    /// Shared metadata pool across all three partitions (M8-4c: saves 32 KiB
    /// per Browser by placing `node`, `objects`, and `bytes` chunks, caches,
    /// and run tables in one committed OS page instead of three). Guarded by
    /// `meta_pool_mutex` (cold paths only: new chunk every 56 spans or attach).
    meta_pool_mutex: std.Io.Mutex = .init,
    meta_pool_base: usize = 0,
    meta_pool_bytes: usize = 0,
    meta_pool_used: usize = 0,
    meta_pool_hi: usize = 0,
    /// The agents' general-memory caches (batch B): those attached now, and
    /// those detached for reuse. Under the objects partition's lock.
    caches: ?*AgentCache = null,
    free_caches: ?*AgentCache = null,
    /// Allocation/free observer (Batch C item 5, `[V2] D8`), only invoked when
    /// `alloc_log_compiled` is true (Debug or `-Dheap-alloc-log=true`).
    alloc_observer: ?AllocObserver = null,

    pub fn setAllocObserver(self: *Engine, observer: ?AllocObserver) void {
        self.alloc_observer = observer;
    }

    inline fn noteAlloc(self: *const Engine, pid: PartitionId, size: usize, address: usize) void {
        if (comptime !alloc_log_compiled) return;
        if (self.alloc_observer) |obs| obs.on_alloc(obs.context, pid, size, address);
    }

    inline fn noteFree(self: *const Engine, pid: PartitionId, address: usize) void {
        if (comptime !alloc_log_compiled) return;
        if (self.alloc_observer) |obs| obs.on_free(obs.context, pid, address);
    }

    pub const magic_value: u64 = 0x4352_414e_4553_4e31; // "CRANESN1"

    pub const GrowHook = struct {
        context: *anyopaque,
        call: *const fn (context: *anyopaque) bool,
    };

    pub const PressureHook = struct {
        context: *anyopaque,
        call: *const fn (context: *anyopaque, partition: PartitionId) void,
    };

    /// Where a heap's engine is: after its header, in the header's super
    /// page of the metadata window.
    const engine_offset: usize = std.mem.alignForward(usize, @sizeOf(BrowserHeap), 64);

    comptime {
        if (engine_offset + @sizeOf(Engine) + @as(usize, @intCast(layout.header_offset % super_page)) > super_page and layout.window_bytes != 0)
            @compileError("the span engine's state does not fit its header's super page");
    }

    /// `heap`'s engine. Only after `init`.
    pub inline fn of(heap: *BrowserHeap) *Engine {
        const engine: *Engine = @ptrFromInt(@intFromPtr(heap) + engine_offset);
        if (builtin.mode == .debug and engine.magic != magic_value) @panic("heap.Engine.of: a heap whose engine was not started");
        return engine;
    }

    /// Start `heap`'s engine: commit its state and lay out its partitions
    /// by the rung the heap got. `seed` seeds the quarantine's evictions
    /// (the Browser's random stream, so a seeded run replays them).
    pub fn init(heap: *BrowserHeap, config: Config, seed: u64) (Error || error{NotSupported})!*Engine {
        if (browser_heap.profile == .pointer32) return error.NotSupported;
        const page = heap.platform.page_size();
        const header_bytes = std.mem.alignForward(usize, @sizeOf(BrowserHeap), page);
        const state_end = std.mem.alignForward(usize, engine_offset + @sizeOf(Engine), page);
        const header_offset: usize = @intCast(layout.header_offset);
        if (state_end > header_bytes) heap.commit(header_offset + header_bytes, state_end - header_bytes) catch return error.OutOfMemory;
        const engine: *Engine = @ptrFromInt(@intFromPtr(heap) + engine_offset);

        // The partitions' address space: inside the cage, `node` takes the
        // lower half and `satellite` (batch B2) takes the upper half past a
        // guard super page, so N10's future 32-bit links decode to both while
        // the two partitions never share a super page. In a rung without an
        // objects range, the cage splits 1/4 node, 1/4 satellite, 1/2 objects
        // (with guard super pages between).
        const cage_lo = heap.cage_lo + super_page;
        const cage_hi = heap.cage_hi - super_page;
        const node_lo = cage_lo;
        var node_hi: usize = undefined;
        var satellite_lo: usize = undefined;
        var satellite_hi: usize = undefined;
        var objects_lo: usize = @intCast(layout.objects.offset);
        var objects_hi: usize = @intCast(layout.objects.end());
        if (!heap.general_pools or layout.objects.bytes == 0) {
            const q1 = cage_lo + std.mem.alignBackward(usize, (cage_hi - cage_lo) / 4, super_page);
            const q2 = cage_lo + std.mem.alignBackward(usize, (cage_hi - cage_lo) / 2, super_page);
            node_hi = q1;
            satellite_lo = q1 + super_page;
            satellite_hi = q2;
            objects_lo = q2 + super_page;
            objects_hi = cage_hi;
        } else {
            const mid = cage_lo + std.mem.alignBackward(usize, (cage_hi - cage_lo) / 2, super_page);
            node_hi = mid;
            satellite_lo = mid + super_page;
            satellite_hi = cage_hi;
        }
        const pools: usize = @intCast(layout.meta_pools.offset);
        const total_pool_bytes: usize = @intCast(layout.meta_pools.bytes);
        // The bytes range, in the full rung only (batch B).
        const bytes_lo: usize = if (heap.general_pools) @intCast(layout.bytes.offset) else 0;
        const bytes_hi: usize = if (heap.general_pools) @intCast(layout.bytes.end()) else 0;

        engine.* = .{
            .heap = heap,
            .config = config,
            .page = page,
            .node = partitionAt(.node, node_lo, node_hi, page),
            .satellite = partitionAt(.satellite, satellite_lo, satellite_hi, page),
            .objects = partitionAt(.objects, objects_lo, objects_hi, page),
            .bytes = partitionAt(.bytes, bytes_lo, bytes_hi, page),
            .node_buckets = undefined,
            .satellite_buckets = undefined,
            .objects_buckets = undefined,
            .bytes_buckets = undefined,
            .prng = .init(seed),
            .meta_pool_base = pools,
            .meta_pool_bytes = total_pool_bytes,
            .meta_pool_used = 0,
            .meta_pool_hi = 0,
        };
        engine.bucket_seed = engine.prng.random().int(u64);
        for (&engine.node_buckets, 0..) |*b, i| b.* = bucketShape(.node, i);
        for (&engine.satellite_buckets, 0..) |*b, i| b.* = bucketShape(.satellite, i);
        for (&engine.objects_buckets, 0..) |*b, i| b.* = bucketShape(.objects, i);
        for (&engine.bytes_buckets, 0..) |*b, i| b.* = bucketShape(.bytes, i);
        return engine;
    }

    fn partitionAt(id: PartitionId, lo: usize, hi: usize, page: usize) Partition {
        const table = @as(usize, @intCast(layout.span_table.offset)) + lo / span_bytes * @as(usize, @intCast(browser_heap.span_entry_bytes));
        const map = @as(usize, @intCast(layout.bitmaps.offset)) + lo / span_bytes * @as(usize, @intCast(browser_heap.slot_map_bytes));
        return .{
            .id = id,
            .lo = lo,
            .hi = hi,
            .limit = hi,
            .frontier = lo,
            .data_hi = lo,
            .table_hi = std.mem.alignBackward(usize, table, page),
            .map_hi = std.mem.alignBackward(usize, map, page),
        };
    }

    fn bucketShape(pid: PartitionId, index: usize) Bucket {
        // General buckets (the bytes partition's, and the objects
        // partition's past its State buckets): the general classes, then
        // the large runs (bytes uses a single coalescing pool sentinel).
        if (pid == .bytes or (pid == .objects and index >= general_objects_base)) {
            const local = if (pid == .bytes) index else index - general_objects_base;
            if (local < GeneralClasses.count) {
                const bytes = GeneralClasses.bytes(local);
                return .{
                    .block_bytes = @intCast(bytes),
                    .fill_bytes = @intCast(bytes),
                    .slots = @intCast(span_bytes / bytes),
                    .kind = .class,
                    .general = true,
                    .empty_cap = if (bytes <= cache_max_bytes) empty_class_small_default else empty_class_large_default,
                };
            }
            if (pid == .bytes) {
                return .{ .block_bytes = 0, .fill_bytes = 0, .slots = 1, .run = 1, .kind = .large, .general = true, .empty_cap = 0 };
            }
            const run = local - GeneralClasses.count + 1;
            return .{ .block_bytes = @intCast(run * span_bytes), .fill_bytes = @intCast(run * span_bytes), .slots = 1, .run = @intCast(run), .kind = .large, .general = true, .empty_cap = 1 };
        }
        // Satellite buckets (batch B2): exact 16-B classes (`Classes`) up to
        // 4 KiB + 8/16 KiB, then large runs up to 2 MiB, with adaptive empty
        // span retention matching general pools.
        if (pid == .satellite) {
            if (index < Classes.count) {
                const bytes = Classes.bytes(index);
                return .{
                    .block_bytes = @intCast(bytes),
                    .fill_bytes = @intCast(bytes),
                    .slots = @intCast(span_bytes / bytes),
                    .kind = .class,
                    .empty_cap = if (bytes <= cache_max_bytes) empty_class_small_default else empty_class_large_default,
                };
            }
            const run = index - Classes.count + 1;
            return .{ .block_bytes = @intCast(run * span_bytes), .fill_bytes = @intCast(run * span_bytes), .slots = 1, .run = @intCast(run), .kind = .large, .empty_cap = 1 };
        }
        const class_end: usize = switch (pid) {
            .node => node_groups * Classes.count,
            .objects, .bytes => Classes.count,
            .satellite => unreachable,
        };
        if (index < class_end) {
            const bytes = Classes.bytes(index % Classes.count);
            return .{ .block_bytes = @intCast(bytes), .fill_bytes = @intCast(bytes), .slots = @intCast(span_bytes / bytes), .kind = .class };
        }
        if (pid == .objects and index == instance_bucket)
            return .{ .block_bytes = instance_slot_bytes, .fill_bytes = instance_fill_bytes, .slots = @intCast(span_bytes / instance_slot_bytes), .kind = .instance };
        const run = index - class_end - @as(usize, if (pid == .objects) 1 else 0) + 1;
        return .{ .block_bytes = @intCast(run * span_bytes), .fill_bytes = @intCast(run * span_bytes), .slots = 1, .run = @intCast(run), .kind = .large };
    }

    // ------------------------------------------------------------------
    // Addresses
    // ------------------------------------------------------------------

    inline fn partition(self: *Engine, pid: PartitionId) *Partition {
        return switch (pid) {
            .node => &self.node,
            .satellite => &self.satellite,
            .objects => &self.objects,
            .bytes => &self.bytes,
        };
    }

    inline fn buckets(self: *Engine, pid: PartitionId) []Bucket {
        return switch (pid) {
            .node => &self.node_buckets,
            .satellite => &self.satellite_buckets,
            .objects => &self.objects_buckets,
            .bytes => &self.bytes_buckets,
        };
    }

    inline fn entry(self: *Engine, index: usize) *SpanEntry {
        return @ptrFromInt(self.heap.at(layout.span_table.offset) + index * @sizeOf(SpanEntry));
    }

    inline fn slotMap(self: *Engine, index: usize) *[map_words]u64 {
        return @ptrFromInt(self.heap.at(layout.bitmaps.offset) + index * (map_words * 8));
    }

    inline fn chunk(self: *Engine, _: *const Partition, id: u32) *Chunk {
        return @ptrFromInt(self.heap.window_base + self.meta_pool_base + @as(usize, id) * @sizeOf(Chunk));
    }

    inline fn spanAddress(self: *Engine, index: usize) usize {
        return self.heap.window_base + index * span_bytes;
    }

    fn partitionOfOffset(self: *Engine, offset: usize) ?PartitionId {
        if (offset >= self.node.lo and offset < self.node.hi) return .node;
        if (offset >= self.satellite.lo and offset < self.satellite.hi) return .satellite;
        if (offset >= self.objects.lo and offset < self.objects.hi) return .objects;
        if (offset >= self.bytes.lo and offset < self.bytes.hi) return .bytes;
        return null;
    }

    // A slot map's words are read atomically everywhere: the general
    // partitions' agent caches (batch B) move their own blocks' states
    // (allocated <-> cached) without the partition's lock while a holder of
    // it changes another slot of the same word. The node partition is one
    // thread's, and writes its words plainly.

    inline fn slotGet(map: *const [map_words]u64, slot: usize) SlotState {
        const word = @atomicLoad(u64, &map[slot / 32], .monotonic);
        return @fromBackingInt(@intCast(@as(u2, @truncate(word >> @intCast((slot % 32) * 2)))));
    }

    /// Set `slot`'s state; `shared` (a general or objects partition's map):
    /// one atomic step, so a cache's lock-free move of another slot of the
    /// word is never lost and no reader sees an intermediate state.
    inline fn slotSet(map: *[map_words]u64, slot: usize, state: SlotState, shared: bool) void {
        const shift: u6 = @intCast((slot % 32) * 2);
        const mask = @as(u64, 3) << shift;
        const bits = @as(u64, @backingInt(state)) << shift;
        const word = &map[slot / 32];
        if (!shared) {
            word.* = (word.* & ~mask) | bits;
            return;
        }
        var old = @atomicLoad(u64, word, .monotonic);
        while (@cmpxchgWeak(u64, word, old, (old & ~mask) | bits, .monotonic, .monotonic)) |actual| old = actual;
    }

    /// Move `slot` from `.cached` (11) to `.allocated` (01) in one atomic
    /// bit-clear (M4: single arm64 `ldclr` with no CAS loop), returning
    /// whether the slot was `.cached`.
    inline fn slotClaimCached(map: *[map_words]u64, slot: usize) bool {
        const shift: u6 = @intCast((slot % 32) * 2);
        const prev = @atomicRmw(u64, &map[slot / 32], .And, ~(@as(u64, 2) << shift), .monotonic);
        return ((prev >> shift) & 3) == @backingInt(SlotState.cached);
    }

    /// Move `slot` from `.quarantined` (10) to `.cached` (11) in one atomic
    /// bit-set (M8-1: single arm64 `ldset` with no CAS loop).
    inline fn slotReleaseQuarantinedToCached(map: *[map_words]u64, slot: usize) void {
        const shift: u6 = @intCast((slot % 32) * 2);
        const prev = @atomicRmw(u64, &map[slot / 32], .Or, @as(u64, 1) << shift, .monotonic);
        if (((prev >> shift) & 3) != @backingInt(SlotState.quarantined)) {
            @branchHint(.cold);
            @panic("heap: a quarantined block left its quarantine state (allocator-hardening design 3.3)");
        }
    }

    /// Move `slot` from `from` to `to` in one atomic step; false, and no
    /// change, when it was not in `from` (an agent cache's free of a block
    /// not allocated: a double free).
    inline fn slotSwap(map: *[map_words]u64, slot: usize, from: SlotState, to: SlotState) bool {
        const shift: u6 = @intCast((slot % 32) * 2);
        const mask = @as(u64, 3) << shift;
        const word = &map[slot / 32];
        var old = @atomicLoad(u64, word, .monotonic);
        while (true) {
            if ((old & mask) >> shift != @backingInt(from)) return false;
            old = @cmpxchgWeak(u64, word, old, (old & ~mask) | (@as(u64, @backingInt(to)) << shift), .monotonic, .monotonic) orelse return true;
        }
    }

    /// The lowest free slot at or above `from`, below `slots`.
    fn findFree(map: *const [map_words]u64, from: usize, slots: usize) ?usize {
        var w = from / 32;
        const last = (slots + 31) / 32;
        while (w < last) : (w += 1) {
            const word = @atomicLoad(u64, &map[w], .monotonic);
            // A free slot is 00: both bits clear.
            var open = ~(word | (word >> 1)) & 0x5555_5555_5555_5555;
            if (w == from / 32) open &= ~((@as(u64, 1) << @intCast((from % 32) * 2)) - 1);
            if (open == 0) continue;
            const slot = w * 32 + @ctz(open) / 2;
            if (slot >= slots) return null;
            return slot;
        }
        return null;
    }

    // ------------------------------------------------------------------
    // Violations
    // ------------------------------------------------------------------

    fn violation(self: *Engine, v: Violation, address: usize) void {
        @branchHint(.cold);
        switch (self.checks) {
            .panic => std.debug.panic("heap: {s} (block {x}). In production this block would have gone to another owner; the allocator's checks end the process instead (allocator-hardening design 3.3).", .{ v.describe(), address }),
            .report => self.last_violation = v,
        }
    }

    /// The last violation a `report` heap recorded, cleared.
    pub fn takeViolation(self: *Engine) ?Violation {
        defer self.last_violation = null;
        return self.last_violation;
    }

    /// The node partition's owner check: the window agent's thread, the
    /// first that made a node block (design 3.7). False, and recorded, off
    /// it.
    inline fn onNodeThread(self: *Engine, address: usize, now: usize) bool {
        const owner = self.node.owner orelse {
            self.node.owner = now;
            return true;
        };
        if (owner == now) return true;
        self.violation(.wrong_thread, address);
        return false;
    }

    // ------------------------------------------------------------------
    // Committing
    // ------------------------------------------------------------------

    fn commitMeta(self: *Engine, watermark: *usize, end: usize) Error!void {
        if (end <= watermark.*) return;
        const to = std.mem.alignForward(usize, end, self.page);
        self.heap.commit(watermark.*, to - watermark.*) catch return error.OutOfMemory;
        watermark.* = to;
    }

    fn poolAlloc(self: *Engine, _: *Partition, bytes: usize) Error!u32 {
        std.Io.Threaded.mutexLockUncancelable(&self.meta_pool_mutex);
        defer std.Io.Threaded.mutexUnlock(&self.meta_pool_mutex);
        return self.poolAllocLocked(bytes);
    }

    fn poolAllocLocked(self: *Engine, bytes: usize) Error!u32 {
        const at = std.mem.alignForward(usize, self.meta_pool_used, @sizeOf(Chunk));
        if (at + bytes > self.meta_pool_bytes) return error.OutOfMemory;
        const end = self.meta_pool_base + at + bytes;
        if (self.meta_pool_hi == 0) self.meta_pool_hi = self.meta_pool_base;
        try self.commitMeta(&self.meta_pool_hi, end);
        self.meta_pool_used = at + bytes;
        return @intCast(at / @sizeOf(Chunk));
    }

    /// Recommit the OS bitmap page covering `index` if idle reclaim decommitted
    /// it (M8-2). Caller holds `p.mutex` (or is on the window thread for `node`).
    fn ensureBitmapCommitted(self: *Engine, p: *Partition, index: usize) Error!void {
        const spans_per_page = self.page / (map_words * 8);
        const page_first = index & ~(spans_per_page - 1);
        const head = self.entry(page_first);
        if (head.flags & SpanEntry.flag_map_decommitted == 0) return;
        const page_off = @as(usize, @intCast(layout.bitmaps.offset)) + page_first * (map_words * 8);
        self.heap.recommit(page_off, self.page, false) catch return error.OutOfMemory;
        head.flags &= ~SpanEntry.flag_map_decommitted;
        p.stats.bitmap_pages_decommitted -|= 1;
    }

    /// Open a span (a run of `run` spans) for bucket `bi` at the frontier.
    fn openSpan(self: *Engine, p: *Partition, bi: u16) Error!u32 {
        const b = &self.buckets(p.id)[bi];
        const run: usize = b.run;
        var at = p.frontier;
        // A super page's first span is its guard (oss R19), and a run never
        // crosses a super page.
        if (at % super_page == 0) at += span_bytes;
        if (at % super_page + run * span_bytes > super_page) at = std.mem.alignForward(usize, at, super_page) + span_bytes;
        const end = at + run * span_bytes;
        if (end > p.limit) return error.OutOfMemory;
        if (self.grow_hook) |hook| if (!hook.call(hook.context)) return error.OutOfMemory;
        // Data: whole super pages past their guard (Linux: one mprotect per
        // super page, design 5.3).
        while (p.data_hi < end) {
            const super_start = std.mem.alignBackward(usize, p.data_hi, super_page);
            self.heap.commit(super_start + span_bytes, super_page - span_bytes) catch return error.OutOfMemory;
            p.data_hi = super_start + super_page;
        }
        const first = at / span_bytes;
        try self.commitMeta(&p.table_hi, @as(usize, @intCast(layout.span_table.offset)) + (first + run) * @sizeOf(SpanEntry));
        try self.commitMeta(&p.map_hi, @as(usize, @intCast(layout.bitmaps.offset)) + (first + run) * map_words * 8);
        try self.ensureBitmapCommitted(p, first);

        // Its place in the bucket's list.
        if (b.last == no_chunk or self.chunk(p, b.last).count == Chunk.chunk_spans) {
            const id = try self.poolAlloc(p, @sizeOf(Chunk));
            const c = self.chunk(p, id);
            c.* = .{ .masks = .{ 0, 0, 0 }, .next = no_chunk, .count = 0, .spans = undefined };
            if (b.last == no_chunk) b.first = id else self.chunk(p, b.last).next = id;
            b.last = id;
        }
        const c = self.chunk(p, b.last);
        const ordinal = c.count;
        c.spans[ordinal] = @intCast(first);
        c.count += 1;

        var sites: u32 = 0;
        if (self.config.record_sites) {
            // Sites take what the chunks leave: never the room a chunk
            // needs (each span of the partition in a chunk, each bucket's
            // partly filled one).
            const reserve = ((p.hi - p.lo) / span_bytes / Chunk.chunk_spans + self.buckets(p.id).len + 1) * @sizeOf(Chunk);
            const want = @as(usize, b.slots) * @sizeOf(usize);
            std.Io.Threaded.mutexLockUncancelable(&self.meta_pool_mutex);
            defer std.Io.Threaded.mutexUnlock(&self.meta_pool_mutex);
            if (std.mem.alignForward(usize, self.meta_pool_used, @sizeOf(Chunk)) + want + reserve <= self.meta_pool_bytes) {
                if (self.poolAllocLocked(want)) |id| {
                    sites = id + 1;
                } else |_| {}
            }
        }

        // Atomic: an agent cache's lock-free free reads it (batch B).
        @atomicStore(usize, &p.frontier, end, .release);
        self.entry(first).* = .{
            .bucket = bi,
            .state = .active,
            .slots = b.slots,
            .used = 0,
            .quarantined = 0,
            .hint = 0,
            .issued_hi = 0,
            .run = @intCast(run),
            .chunk = b.last,
            .ordinal = ordinal,
            .empty_since = self.now_ms.load(.monotonic),
            .sites = sites,
        };
        for (1..run) |k| self.entry(first + k).* = .{
            .bucket = bi,
            .state = .run_tail,
            .slots = 0,
            .used = 0,
            .quarantined = 0,
            .hint = 0,
            .issued_hi = 0,
            .run = 0,
            .chunk = @intCast(first),
            .ordinal = 0,
            .empty_since = 0,
            .sites = 0,
        };
        @memset(self.slotMap(first), 0);
        b.spans += 1;
        p.stats.spans_active += 1;
        p.stats.spans_empty += 1;
        p.stats.committed_span_bytes += run * span_bytes;
        p.stats.va_assigned = p.frontier - p.lo;
        self.setTier(p, b, self.entry(first), .room, true);
        self.setTier(p, b, self.entry(first), .empty, true);
        if (!p.stats.pressure_raised and (p.frontier - p.lo) * 10 >= (p.limit - p.lo) * 9) self.raisePressure(p);
        return @intCast(first);
    }

    fn setTier(self: *Engine, p: *Partition, b: *Bucket, e: *const SpanEntry, tier: Tier, on: bool) void {
        const c = self.chunk(p, e.chunk);
        const bit = @as(u64, 1) << @intCast(e.ordinal);
        const t = @backingInt(tier);
        const was = c.masks[t] & bit != 0;
        if (tier == .empty and was != on) {
            if (on) {
                b.empty_count += 1;
                if (usesAdaptiveRetention(p.id, b)) {
                    if (b.kind == .large) {
                        p.empty_large_bytes += b.block_bytes;
                    } else if (b.kind == .class) {
                        p.empty_class_spans += 1;
                    }
                }
            } else {
                b.empty_count -= 1;
                if (usesAdaptiveRetention(p.id, b)) {
                    if (b.kind == .large) {
                        p.empty_large_bytes -= b.block_bytes;
                        const span_idx = c.spans[e.ordinal];
                        const len: usize = p.empty_large_len;
                        for (0..len) |i| {
                            if (p.empty_large_ring[i] == span_idx) {
                                var k = i;
                                while (k + 1 < len) : (k += 1) p.empty_large_ring[k] = p.empty_large_ring[k + 1];
                                p.empty_large_ring[len - 1] = no_span;
                                p.empty_large_len -= 1;
                                break;
                            }
                        }
                    } else if (b.kind == .class) {
                        p.empty_class_spans -= 1;
                    }
                }
            }
        }
        if (on) {
            c.masks[t] |= bit;
            if (b.hints[t] == no_chunk or e.chunk < b.hints[t]) b.hints[t] = e.chunk;
        } else {
            c.masks[t] &= ~bit;
        }
    }

    /// The lowest span of `b` in `tier`.
    fn lowest(self: *Engine, p: *const Partition, b: *Bucket, tier: Tier) ?u32 {
        const t = @backingInt(tier);
        var id = b.hints[t];
        while (id != no_chunk) {
            const c = self.chunk(p, id);
            if (c.masks[t] != 0) {
                b.hints[t] = id;
                return c.spans[@ctz(c.masks[t])];
            }
            id = c.next;
        }
        b.hints[t] = no_chunk;
        return null;
    }

    /// Bring a released span back: commit it again and take it into its
    /// bucket's committed tiers, empty.
    fn reuseReleased(self: *Engine, p: *Partition, b: *Bucket, index: u32) Error!void {
        const e = self.entry(index);
        const was_retired = e.state == .retired;
        const bytes = @as(usize, e.run) * span_bytes;
        try self.ensureBitmapCommitted(p, index);
        self.heap.recommit(index * span_bytes, bytes, was_retired) catch return error.OutOfMemory;
        @memset(self.slotMap(index), 0);
        // A poisoning heap's freed slots read poison, and a span the OS
        // took back reads zero, or (darwin, REUSABLE) its old bytes: start
        // it over as zero.
        if (self.config.fill == .poison) @memset(@as([*]u8, @ptrFromInt(self.spanAddress(index)))[0..bytes], 0);
        const now_ms = self.now_ms.load(.monotonic);
        // M8-4b: adaptive thrash detection — if a cached-class general span was
        // just decommitted (< general_decommit_age_ms ago) and is already needed
        // again, expand this bucket's and partition's active empty-span budget
        // up to `empty_class_thrash_cap` (resets on 200 ms idle reclaim).
        if (usesAdaptiveRetention(p.id, b) and b.kind == .class and b.block_bytes <= cache_max_bytes and !was_retired and
            now_ms -% e.empty_since < general_decommit_age_ms)
        {
            const next_cap: u16 = @min(empty_class_thrash_cap, @max(b.empty_cap, empty_class_small_default) *| 2);
            b.empty_cap = next_cap;
            if (p.empty_class_budget < empty_class_thrash_cap) {
                p.empty_class_budget = @min(empty_class_thrash_cap, @max(p.empty_class_budget * 2, @as(usize, next_cap)));
            }
        }
        e.issued_hi = 0;
        e.hint = 0;
        e.state = .active;
        e.empty_since = now_ms;
        if (was_retired) {
            p.stats.spans_retired -= 1;
            _ = self.retired.fetchSub(1, .monotonic);
        } else p.stats.spans_decommitted -= 1;
        p.stats.spans_active += 1;
        p.stats.spans_empty += 1;
        p.stats.committed_span_bytes += bytes;
        self.setTier(p, b, e, .released, false);
        self.setTier(p, b, e, .room, true);
        self.setTier(p, b, e, .empty, true);
    }

    // ------------------------------------------------------------------
    // Allocation
    // ------------------------------------------------------------------

    /// A block of `size`/`alignment` for `target`, ZEROED (its request's
    /// bytes). `site`: the type's site where the caller knows it.
    pub fn alloc(self: *Engine, target: Target, size: usize, alignment: usize, site: ?*const Site, return_address: usize) Error![*]u8 {
        if (alignment > span_bytes) @panic("heap: an alignment past a span");
        const bytes = classes.requestBytes(size, alignment);
        if (bytes > max_block_bytes) return error.OutOfMemory;
        switch (target) {
            .node => |kind| {
                const k: usize = if (random_buckets == 1) 0 else self.randomBucket(site);
                const bi: u16 = if (classes.classOf(size, alignment)) |class| nodeBucket(kind, k, class) else largeBucket(.node, runOf(bytes));
                if (!self.onNodeThread(0, platform.currentThreadToken())) return error.OutOfMemory;
                return self.allocIn(&self.node, bi, size, site, return_address);
            },
            .objects => {
                const bi: u16 = if (classes.classOf(size, alignment)) |class| @intCast(class) else largeBucket(.objects, runOf(bytes));
                std.Io.Threaded.mutexLockUncancelable(&self.objects.mutex);
                defer std.Io.Threaded.mutexUnlock(&self.objects.mutex);
                return self.allocIn(&self.objects, bi, size, site, return_address);
            },
        }
    }

    /// The random bucket of a node interface (its State type's site): a
    /// hash of the type's identity and the Browser's seed.
    fn randomBucket(self: *Engine, site: ?*const Site) usize {
        const key = @as(u64, @intFromPtr(site orelse return 0)) ^ self.bucket_seed;
        // splitmix64's finaliser.
        var z = key +% 0x9e37_79b9_7f4a_7c15;
        z = (z ^ (z >> 30)) *% 0xbf58_476d_1ce4_e5b9;
        z = (z ^ (z >> 27)) *% 0x94d0_49bb_1331_11eb;
        return @intCast((z ^ (z >> 31)) % random_buckets);
    }

    /// An Instance slot (32 bytes), its Instance bytes zero; its stamp is
    /// the slab's.
    pub fn allocInstance(self: *Engine) Error!*[instance_slot_bytes]u8 {
        std.Io.Threaded.mutexLockUncancelable(&self.objects.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.objects.mutex);
        const ptr = try self.allocIn(&self.objects, instance_bucket, instance_fill_bytes, null, 0);
        return @ptrCast(ptr);
    }

    pub const InstanceBlocks = struct {
        slot: *[instance_slot_bytes]u8,
        state: [*]u8,
    };

    /// An Instance slot and its State block in one call, the objects lock
    /// taken once: `allocInstance` and `alloc` (for `target`, `size`,
    /// `alignment`) together, as Instance.init asks for them (lane hard1's
    /// P1, cut 4: two calls and two locks were part of the core's 17 ns a
    /// pair). Both come back as those calls make them. A failure gives back
    /// what was made.
    pub fn allocInstanceWith(self: *Engine, target: Target, size: usize, alignment: usize, site: ?*const Site, return_address: usize) Error!InstanceBlocks {
        if (alignment > span_bytes) @panic("heap: an alignment past a span");
        const bytes = classes.requestBytes(size, alignment);
        if (bytes > max_block_bytes) return error.OutOfMemory;
        switch (target) {
            .node => |kind| {
                const k: usize = if (random_buckets == 1) 0 else self.randomBucket(site);
                const class = classes.classOf(size, alignment);
                const bi: u16 = if (class) |c| nodeBucket(kind, k, c) else largeBucket(.node, runOf(bytes));
                const thread = platform.currentThreadToken();
                if (!self.onNodeThread(0, thread)) return error.OutOfMemory;
                const state = try self.allocIn(&self.node, bi, size, site, return_address);
                std.Io.Threaded.mutexLockUncancelable(&self.objects.mutex);
                defer std.Io.Threaded.mutexUnlock(&self.objects.mutex);
                const slot = self.allocIn(&self.objects, instance_bucket, instance_fill_bytes, null, 0) catch |err| {
                    // `free`'s bucket for a node block: its class, or its run's.
                    const want: u16 = if (class) |c| @intCast(c) else bi;
                    self.freeIn(&self.node, @intFromPtr(state) - self.heap.window_base, want, false, size, thread);
                    return err;
                };
                return .{ .slot = @ptrCast(slot), .state = state };
            },
            .objects => {
                const bi: u16 = if (classes.classOf(size, alignment)) |class| @intCast(class) else largeBucket(.objects, runOf(bytes));
                std.Io.Threaded.mutexLockUncancelable(&self.objects.mutex);
                defer std.Io.Threaded.mutexUnlock(&self.objects.mutex);
                const slot = try self.allocIn(&self.objects, instance_bucket, instance_fill_bytes, null, 0);
                const state = self.allocIn(&self.objects, bi, size, site, return_address) catch |err| {
                    self.freeIn(&self.objects, @intFromPtr(slot) - self.heap.window_base, instance_bucket, true, instance_fill_bytes, null);
                    return err;
                };
                return .{ .slot = @ptrCast(slot), .state = state };
            },
        }
    }

    fn allocIn(self: *Engine, p: *Partition, bi: u16, size: usize, site: ?*const Site, return_address: usize) Error![*]u8 {
        const b = &self.buckets(p.id)[bi];
        if (magazine_depth != 0 and b.mag_count != 0) return self.popMagazine(p, b, size, site, return_address);
        var index = b.current;
        if (index == no_span or self.entry(index).used == self.entry(index).slots) {
            index = self.lowest(p, b, .room) orelse released: {
                const released = self.lowest(p, b, .released) orelse break :released try self.openSpan(p, bi);
                try self.reuseReleased(p, b, released);
                break :released released;
            };
            b.current = index;
        }
        const e = self.entry(index);
        const map = self.slotMap(index);
        const slot = findFree(map, e.hint, e.slots) orelse unreachable;
        slotSet(map, slot, .allocated, isSharedPartition(p.id));
        e.hint = @intCast(slot + 1);
        if (e.used == 0) {
            self.setTier(p, b, e, .empty, false);
            p.stats.spans_empty -= 1;
        }
        e.used += 1;
        if (e.used == e.slots) {
            self.setTier(p, b, e, .room, false);
            b.current = no_span;
        }
        const fresh = slot >= e.issued_hi;
        if (fresh) {
            e.issued_hi = @intCast(slot + 1);
            b.fresh += 1;
        }
        b.live += 1;
        if (b.live > b.live_peak) b.live_peak = b.live;
        b.issued += 1;
        b.requested += size;
        b.requested_total += size;

        const address = self.spanAddress(index) + slot * b.block_bytes;
        const block: [*]u8 = @ptrFromInt(address);
        const checked = if (b.kind == .instance) instance_fill_bytes else size;
        if (self.fills(p)) {
            if (b.general and p.id == .objects and self.config.fill == .zero) {
                // Design 3.4 (`production, objects`): verify the zeroed prefix
                // (up to 1 KiB) and zero any remainder of the request on reissue.
                const cap = @min(checked, general_objects_zero_cap);
                self.verifyZeroSlice(block[0..cap]);
                if (!fresh and checked > general_objects_zero_cap) @memset(block[general_objects_zero_cap..checked], 0);
            } else {
                self.verifyFreed(block[0..checked], fresh);
            }
        }
        if (e.sites != 0) {
            const sites: [*]usize = @ptrFromInt(self.heap.window_base + self.meta_pool_base + (@as(usize, e.sites) - 1) * @sizeOf(Chunk));
            sites[slot] = if (site) |s| @intFromPtr(s) else return_address | site_return_tag;
        }
        self.noteAlloc(p.id, size, address);
        return block;
    }

    /// A block about to be issued: still what its free left (zero, or the
    /// poison; zero for a slot never issued), then zeroed.
    /// Whether `p`'s freed blocks are filled (and checked on issue): every
    /// partition's but the bytes', which only a poisoning heap fills.
    inline fn fills(self: *const Engine, p: *const Partition) bool {
        return p.id != .bytes or self.config.fill == .poison;
    }

    /// Fast production zero-verification (M8-1): skips `^ pattern` XOR and
    /// unrolls 4x16B NEON vector `orr` across 64-byte cache lines.
    inline fn verifyZeroSlice(self: *Engine, block: []u8) void {
        if (!allZero(block)) {
            @branchHint(.cold);
            self.violation(.write_after_free, @intFromPtr(block.ptr));
            @memset(block, 0);
        }
    }

    fn verifyFreed(self: *Engine, block: []u8, fresh: bool) void {
        const expected: u8 = if (fresh) 0 else self.config.fillByte();
        if (expected == 0) {
            self.verifyZeroSlice(block);
            return;
        }
        if (!allBytes(block, expected)) {
            @branchHint(.cold);
            self.violation(.write_after_free, @intFromPtr(block.ptr));
            @memset(block, 0);
            return;
        }
        @memset(block, 0);
    }

    /// Whether every byte of `block` is 0: 4x16B SIMD `orr` unroll with zero
    /// XOR instructions, halving verify instructions on `style.html` (M8-1).
    inline fn allZero(block: []const u8) bool {
        const V = @Vector(16, u8);
        var acc0: V = @splat(0);
        var acc1: V = @splat(0);
        var i: usize = 0;
        while (i + 64 <= block.len) : (i += 64) {
            const v0: V = block[i..][0..16].*;
            const v1: V = block[i + 16 ..][0..16].*;
            const v2: V = block[i + 32 ..][0..16].*;
            const v3: V = block[i + 48 ..][0..16].*;
            acc0 |= v0 | v1;
            acc1 |= v2 | v3;
        }
        var acc: V = acc0 | acc1;
        while (i + 16 <= block.len) : (i += 16) acc |= @as(V, block[i..][0..16].*);
        var rest: u64 = 0;
        if (i + 8 <= block.len) {
            rest |= std.mem.readInt(u64, block[i..][0..8], .little);
            i += 8;
        }
        while (i < block.len) : (i += 1) rest |= block[i];
        return (@as(u64, @reduce(.Or, acc)) | rest) == 0;
    }

    /// Whether every byte of `block` is `byte`: one OR of the differences
    /// over the whole block, then one comparison - no branch per word (lane
    /// hard1's P1: the branch per word was most of verify's 5 ns a pair).
    fn allBytes(block: []const u8, byte: u8) bool {
        const V = @Vector(16, u8);
        const pattern: V = @splat(byte);
        var differ: V = @splat(0);
        var i: usize = 0;
        while (i + 16 <= block.len) : (i += 16) differ |= @as(V, block[i..][0..16].*) ^ pattern;
        const word = @as(u64, byte) * 0x0101_0101_0101_0101;
        var rest: u64 = 0;
        if (i + 8 <= block.len) {
            rest |= std.mem.readInt(u64, block[i..][0..8], .little) ^ word;
            i += 8;
        }
        while (i < block.len) : (i += 1) rest |= block[i] ^ byte;
        return (@as(u64, @reduce(.Or, differ)) | rest) == 0;
    }

    // ------------------------------------------------------------------
    // Satellites (allocator-hardening batch B2, item 3)
    // ------------------------------------------------------------------

    /// A satellite block of `size`/`alignment` in the cage's `.satellite`
    /// partition (window agent's thread only, lock-free), ZEROED (its
    /// request's bytes). Past a large run, a huge block (`allocHuge`).
    pub fn allocSatellite(self: *Engine, size: usize, alignment: usize, return_address: usize) Error![*]u8 {
        if (alignment > span_bytes) @panic("heap: an alignment past a span");
        const thread = platform.currentThreadToken();
        if (!self.onNodeThread(0, thread)) return error.OutOfMemory;
        const p = &self.satellite;
        if (p.lo == p.hi) return error.OutOfMemory;
        const bytes = classes.requestBytes(size, alignment);
        if (bytes > huge_threshold_bytes) return self.allocHuge(p, bytes);
        const bi: u16 = if (classes.classOf(size, alignment)) |class| @intCast(class) else largeBucket(.satellite, runOf(bytes));
        return self.allocIn(p, bi, size, null, return_address);
    }

    /// Free a satellite block: validated (cage `.satellite`, window thread,
    /// class, alignment, allocated), full-block zeroed (0xdd in poisoning
    /// builds), and held in the task-scoped quarantine while a task runs.
    pub fn freeSatellite(self: *Engine, ptr: [*]u8, size: usize, alignment: usize) void {
        const address = @intFromPtr(ptr);
        const offset = self.offsetOf(address) orelse return self.violation(.other_heap, address);
        const pid = self.partitionOfOffset(offset) orelse return self.violation(.invalid_free, address);
        if (pid != .satellite) return self.violation(.invalid_free, address);
        const thread = platform.currentThreadToken();
        if (!self.onNodeThread(address, thread)) return;
        const p = &self.satellite;
        const bytes = classes.requestBytes(size, alignment);
        if (offset >= p.frontier) return self.violation(.invalid_free, address);
        const e = self.entry(offset / span_bytes);
        if (e.bucket == huge_bucket and e.state != .run_tail and e.state != .unopened) return self.freeHuge(p, offset, bytes);
        if (bytes > huge_threshold_bytes) return self.violation(if (e.state == .active) .wrong_size else .invalid_free, address);
        const want: u16 = if (classes.classOf(size, alignment)) |class| @intCast(class) else largeBucket(.satellite, runOf(bytes));
        self.freeIn(p, offset, want, false, size, thread);
    }

    /// Free a satellite block whose caller knows it lives in a Browser's cage
    /// (`browser_heap.heapOf` contract, e.g. `ElementStyle.destroy`).
    pub fn freeSatelliteOf(ptr: *anyopaque, size: usize, alignment: usize) void {
        Engine.of(browser_heap.heapOf(ptr)).freeSatellite(@ptrCast(ptr), size, alignment);
    }

    /// Whether a satellite block of `old_size` may become `new_size` in place:
    /// the same class, large run, or huge span count.
    pub fn resizesSatelliteInPlace(_: *Engine, old_size: usize, new_size: usize, alignment: usize) bool {
        const old_bytes = classes.requestBytes(old_size, alignment);
        const new_bytes = classes.requestBytes(new_size, alignment);
        if (old_bytes > huge_threshold_bytes or new_bytes > huge_threshold_bytes)
            return old_bytes > huge_threshold_bytes and new_bytes > huge_threshold_bytes and runOf(old_bytes) == runOf(new_bytes);
        const old_class = classes.classOf(old_size, alignment);
        const new_class = classes.classOf(new_size, alignment);
        if (old_class) |o| return if (new_class) |n| o == n else false;
        if (new_class != null) return false;
        return runOf(old_bytes) == runOf(new_bytes);
    }

    // ------------------------------------------------------------------
    // General memory (allocator-hardening batch B)
    // ------------------------------------------------------------------

    /// A general block of `size`/`alignment` from `pid` (objects or bytes):
    /// the shared path, under the partition's lock - what heap.general's
    /// allocator takes on a thread that is not its agent's, and what an
    /// agent's cache refills from. An objects block is issued zero, as every
    /// objects block is; a bytes block is not (std's allocator fills it on
    /// issue). Past a large run, a huge block (`allocHuge`).
    pub fn allocGeneral(self: *Engine, pid: PartitionId, size: usize, alignment: usize, return_address: usize) Error![*]u8 {
        std.debug.assert(pid == .objects or pid == .bytes);
        if (alignment > span_bytes) @panic("heap: an alignment past a span");
        const p = self.partition(pid);
        if (p.lo == p.hi) return error.OutOfMemory;
        const bytes = classes.requestBytes(size, alignment);
        std.Io.Threaded.mutexLockUncancelable(&p.mutex);
        defer std.Io.Threaded.mutexUnlock(&p.mutex);
        if (bytes > huge_threshold_bytes) return self.allocHuge(p, bytes);
        const class = generalClassOf(size, alignment);
        if (pid == .bytes and class == null) return self.allocBytesLarge(p, bytes, size);
        const bi = generalBucket(pid, class, runOf(bytes));
        return self.allocIn(p, bi, size, null, return_address | site_general_tag);
    }

    /// Free a general block: validated as a State block's free is (its
    /// partition's, a block's start, its class, allocated), then - an
    /// objects block - zeroed and held while the window agent runs a task on
    /// this thread; a bytes block goes back at once.
    pub fn freeGeneral(self: *Engine, ptr: [*]u8, size: usize, alignment: usize) void {
        const address = @intFromPtr(ptr);
        const offset = self.offsetOf(address) orelse return self.violation(.other_heap, address);
        const pid = self.partitionOfOffset(offset) orelse return self.violation(.invalid_free, address);
        if (pid == .node or pid == .satellite) return self.violation(.invalid_free, address);
        const p = self.partition(pid);
        const bytes = classes.requestBytes(size, alignment);
        std.Io.Threaded.mutexLockUncancelable(&p.mutex);
        defer std.Io.Threaded.mutexUnlock(&p.mutex);
        if (offset >= p.frontier) return self.violation(.invalid_free, address);
        const e = self.entry(offset / span_bytes);
        if (e.bucket == huge_bucket and e.state != .run_tail and e.state != .unopened) return self.freeHuge(p, offset, bytes);
        if (bytes > huge_threshold_bytes) return self.violation(if (e.state == .active) .wrong_size else .invalid_free, address);
        if (pid == .bytes and e.bucket == bytes_large_bucket and e.state != .unopened) {
            return self.freeBytesLarge(p, offset, bytes, size);
        }
        const class = generalClassOf(size, alignment);
        if (pid == .bytes and class == null) return self.violation(if (e.state == .active) .wrong_size else .invalid_free, address);
        const want = generalBucket(pid, class, runOf(bytes));
        self.freeIn(p, offset, want, false, size, null);
    }

    // ------------------------------------------------------------------
    // Agent caches (allocator-hardening batch B, design 3.7)
    // ------------------------------------------------------------------

    /// A cache for the agent whose thread calls this (the window agent's,
    /// or a worker's): its allocator (AgentCache.allocator) takes and gives
    /// back general class blocks without a lock on that thread. Detach it
    /// at the agent's end (`detachAgent`).
    pub fn attachAgent(self: *Engine) Error!*AgentCache {
        std.Io.Threaded.mutexLockUncancelable(&self.objects.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.objects.mutex);
        const cache: *AgentCache = if (self.free_caches) |reused| reused: {
            self.free_caches = reused.next;
            break :reused reused;
        } else made: {
            const id = try self.poolAlloc(&self.objects, @sizeOf(AgentCache));
            break :made @ptrFromInt(self.heap.window_base + self.meta_pool_base + @as(usize, id) * @sizeOf(Chunk));
        };
        cache.* = .{
            .engine = self,
            .owner = .init(platform.currentThreadToken()),
            .window_base = self.heap.window_base,
            .reserved_base = self.heap.reserved.base,
            .reserved_size = self.heap.reserved.size,
            .bitmaps_base = self.heap.at(layout.bitmaps.offset),
            .span_table_base = self.heap.at(layout.span_table.offset),
            .part_lo = .{ self.objects.lo, self.bytes.lo },
            .part_size = .{ self.objects.hi - self.objects.lo, self.bytes.hi - self.bytes.lo },
            .poison = self.config.fill == .poison,
            .record_sites = self.config.record_sites,
        };
        cache.next = self.caches;
        self.caches = cache;
        return cache;
    }

    /// Convert any cache-owned quarantined entries belonging to `cache` into
    /// standard span-owned quarantine entries so `cache` can be safely detached
    /// even mid-task without releasing quarantined blocks early (M8-1).
    /// Caller holds `self.objects.mutex`.
    fn migrateWindowCacheQuarantineLocked(self: *Engine, cache: *AgentCache) void {
        if (self.quarantine.window_cache != cache) return;
        const entries = self.quarantineEntries();
        for (entries[0..self.quarantine.count]) |*slot| {
            const raw = slot.*;
            const tag = raw & quarantine_tag_mask;
            if (tag == 0) continue;
            const class = tag - 1;
            const address = raw & ~quarantine_tag_mask;
            slot.* = address;
            const offset = address - cache.window_base;
            const index = offset / span_bytes;
            const e = self.entry(index);
            const b = &self.objects_buckets[generalBucket(.objects, class, 0)];
            b.live -= 1;
            e.quarantined += 1;
            cache.held_local[0] -|= 1;
            cache.held_bytes_local[0] -|= general_slot_div[class].block_bytes;
        }
        cache.held[0].store(cache.held_local[0], .monotonic);
        cache.held_bytes[0].store(cache.held_bytes_local[0], .monotonic);
        if (self.quarantine.next_slot < self.quarantine.count) {
            self.quarantine.next_entry = entries[self.quarantine.next_slot];
        }
        self.quarantine.window_cache = null;
    }

    /// The agent ended: every block its cache holds goes back to its span,
    /// and the cache to the engine's reuse list. Its allocator stays valid:
    /// an operation through it after this takes the shared path.
    pub fn detachAgent(self: *Engine, cache: *AgentCache) void {
        {
            std.Io.Threaded.mutexLockUncancelable(&self.objects.mutex);
            defer std.Io.Threaded.mutexUnlock(&self.objects.mutex);
            self.migrateWindowCacheQuarantineLocked(cache);
        }
        self.flushCache(cache, null);
        cache.owner.store(0, .monotonic);
        std.Io.Threaded.mutexLockUncancelable(&self.objects.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.objects.mutex);
        var link: *?*AgentCache = &self.caches;
        while (link.*) |current| : (link = &current.next) {
            if (current != cache) continue;
            link.* = current.next;
            break;
        }
        cache.next = self.free_caches;
        self.free_caches = cache;
    }

    /// Every attached cache's blocks back to their spans: the scope's end,
    /// once every agent is gone, before the leak report reads the buckets.
    pub fn flushAllCaches(self: *Engine) void {
        var at = self.caches;
        while (at) |cache| : (at = cache.next) self.flushCache(cache, null);
    }

    /// The caches whose agent runs on this thread give their blocks back
    /// (idle decommit's first step: a span only a cache keeps open would be
    /// kept committed). `empty_since`: the timestamp idle-flushed spans are
    /// aged from (M7-3: preserves the idle delay already waited before
    /// `decommitAged` ran, instead of resetting `empty_since` to `now`).
    fn flushCachesOfThisThread(self: *Engine, empty_since: ?u32) void {
        const thread = platform.currentThreadToken();
        var found: [8]*AgentCache = undefined;
        var n: usize = 0;
        {
            std.Io.Threaded.mutexLockUncancelable(&self.objects.mutex);
            defer std.Io.Threaded.mutexUnlock(&self.objects.mutex);
            var at = self.caches;
            while (at) |cache| : (at = cache.next) {
                if (cache.owner.load(.monotonic) != thread or n == found.len) continue;
                found[n] = cache;
                n += 1;
            }
        }
        for (found[0..n]) |cache| self.flushCache(cache, empty_since);
    }

    fn flushCache(self: *Engine, cache: *AgentCache, empty_since: ?u32) void {
        inline for (.{ PartitionId.objects, PartitionId.bytes }, 0..) |pid, pi| {
            const p = self.partition(pid);
            std.Io.Threaded.mutexLockUncancelable(&p.mutex);
            defer std.Io.Threaded.mutexUnlock(&p.mutex);
            var flushed_n: usize = 0;
            var flushed_b: usize = 0;
            for (0..cache_class_count) |class| {
                const count = cache.counts[pi][class];
                if (count == 0) continue;
                self.giveBack(p, generalBucket(pid, class, 0), cache.slots[pi][class][0..count], empty_since);
                cache.counts[pi][class] = 0;
                flushed_n += count;
                flushed_b += @as(usize, count) * general_slot_div[class].block_bytes;
            }
            cache.held_local[pi] -|= flushed_n;
            cache.held[pi].store(cache.held_local[pi], .monotonic);
            cache.held_bytes_local[pi] -|= flushed_b;
            cache.held_bytes[pi].store(cache.held_bytes_local[pi], .monotonic);
        }
    }

    /// Blocks a cache held (`at`: offsets / 16, state `.cached`) back to
    /// their spans. The partition's lock held.
    fn giveBack(self: *Engine, p: *Partition, bi: u16, at: []const u32, empty_since: ?u32) void {
        const b = &self.buckets(p.id)[bi];
        const since = empty_since orelse self.now_ms.load(.monotonic);
        const class: usize = if (p.id == .bytes) bi else bi - general_objects_base;
        const magic = general_slot_div[class].magic;
        for (at) |a| {
            const offset = @as(usize, a) * 16;
            const index = offset / span_bytes;
            const within = offset & (span_bytes - 1);
            const slot = ((within >> 4) * magic) >> 20;
            b.live -= 1;
            self.releaseSlot(p, b, index, slot, since);
        }
    }

    /// A general class block from `cache`, on its agent's thread: comptime
    /// specialized by partition so the hot `.bytes` path uses constant cache
    /// offsets and drops all `.objects` verify/quarantine checks (M4/M8-1).
    pub inline fn cacheAlloc(self: *Engine, cache: *AgentCache, comptime pid: PartitionId, size: usize, alignment: std.mem.Alignment, return_address: usize) Error![*]u8 {
        const pi = comptime cacheIndex(pid);
        const class = generalClassOfAlign(size, alignment) orelse {
            @branchHint(.cold);
            return self.allocGeneral(pid, size, alignment.toByteUnits(), return_address);
        };
        if (class >= cache_class_count) {
            @branchHint(.cold);
            return self.allocGeneral(pid, size, alignment.toByteUnits(), return_address);
        }
        var count = cache.counts[pi][class];
        if (count == 0) {
            @branchHint(.cold);
            try self.refill(cache, pid, class);
            count = cache.counts[pi][class];
        }
        count -= 1;
        cache.counts[pi][class] = count;
        const offset = @as(usize, cache.slots[pi][class][count]) * 16;
        const div = general_slot_div[class];
        cache.held_local[pi] -= 1;
        cache.held[pi].store(cache.held_local[pi], .monotonic);
        cache.held_bytes_local[pi] -|= div.block_bytes;
        cache.held_bytes[pi].store(cache.held_bytes_local[pi], .monotonic);
        const index = offset / span_bytes;
        const within = offset & (span_bytes - 1);
        const slot = ((within >> 4) * div.magic) >> 20;
        const map: *[map_words]u64 = @ptrFromInt(cache.bitmaps_base + index * (map_words * 8));
        if (!slotClaimCached(map, slot)) {
            @branchHint(.cold);
            @panic("heap: a cached block left its cache's state (allocator-hardening design 3.3)");
        }
        const block: [*]u8 = @ptrFromInt(cache.window_base + offset);
        if (pid != .bytes) {
            if (!cache.poison) {
                const checked = @min(size, general_objects_zero_cap);
                self.verifyZeroSlice(block[0..checked]);
                if (size > general_objects_zero_cap) @memset(block[general_objects_zero_cap..size], 0);
            } else {
                self.verifyFreed(block[0..size], false);
            }
        } else if (cache.poison) {
            self.verifyFreed(block[0..size], false);
        }
        if (cache.record_sites) {
            @branchHint(.cold);
            const e: *SpanEntry = @ptrFromInt(cache.span_table_base + index * @sizeOf(SpanEntry));
            if (e.sites != 0) {
                const sites: [*]usize = @ptrFromInt(cache.window_base + self.meta_pool_base + (@as(usize, e.sites) - 1) * @sizeOf(Chunk));
                sites[slot] = return_address | site_return_tag | site_general_tag;
            }
        }
        self.noteAlloc(pid, size, @intFromPtr(block));
        return block;
    }

    /// Free a general block through `cache`, on its agent's thread: comptime
    /// specialized by the alignment's expected partition so the hot `.bytes`
    /// path skips all `.objects` quarantine/fill checks, and window-thread
    /// `.objects` frees during a task stay lock-free in the per-agent
    /// quarantine branch (M4/M8-1). Cross-partition invalid frees fall back
    /// to `freeGeneral` for full diagnostics.
    pub inline fn cacheFree(self: *Engine, cache: *AgentCache, comptime expected: PartitionId, ptr: [*]u8, size: usize, alignment: std.mem.Alignment, thread: usize) void {
        const pi = comptime cacheIndex(expected);
        const class = generalClassOfAlign(size, alignment) orelse {
            @branchHint(.cold);
            return self.freeGeneral(ptr, size, alignment.toByteUnits());
        };
        if (class >= cache_class_count) {
            @branchHint(.cold);
            return self.freeGeneral(ptr, size, alignment.toByteUnits());
        }
        const address = @intFromPtr(ptr);
        if (address -% cache.reserved_base >= cache.reserved_size) {
            @branchHint(.cold);
            return self.violation(.other_heap, address);
        }
        const offset = address - cache.window_base;
        if (offset -% cache.part_lo[pi] >= cache.part_size[pi]) {
            @branchHint(.cold);
            return self.freeGeneral(ptr, size, alignment.toByteUnits());
        }
        const want = generalBucket(expected, class, 0);
        if (offset >= cache.seen_frontier[pi]) {
            @branchHint(.cold);
            const p = self.partition(expected);
            const f = @atomicLoad(usize, &p.frontier, .acquire);
            cache.seen_frontier[pi] = f;
            if (offset >= f) return self.violation(.invalid_free, address);
        }
        const index = offset / span_bytes;
        const e: *SpanEntry = @ptrFromInt(cache.span_table_base + index * @sizeOf(SpanEntry));
        if (e.state != .active or e.bucket != want) {
            @branchHint(.cold);
            if (e.state != .active) {
                return self.violation(if (e.state == .unopened or e.state == .run_tail) .invalid_free else .double_free, address);
            }
            return self.violation(if (e.bucket >= self.buckets(expected).len or self.buckets(expected)[e.bucket].kind == .instance) .invalid_free else .wrong_size, address);
        }
        const div = general_slot_div[class];
        const within = offset & (span_bytes - 1);
        const slot = ((within >> 4) * div.magic) >> 20;
        if (slot * div.block_bytes != within) {
            @branchHint(.cold);
            return self.violation(.invalid_free, address);
        }
        const map: *[map_words]u64 = @ptrFromInt(cache.bitmaps_base + index * (map_words * 8));
        if (expected == .objects and self.holds(thread)) {
            if (!slotSwap(map, slot, .allocated, .quarantined)) {
                @branchHint(.cold);
                return self.violation(.double_free, address);
            }
            const fill_len = if (cache.poison) div.block_bytes else @min(div.block_bytes, general_objects_zero_cap);
            @memset(ptr[0..fill_len], if (cache.poison) poison_byte else 0);
            // M8-1: lock-free per-agent quarantine branch (non-bug-finding):
            // keep cached-class general `.objects` blocks owned by window's
            // `AgentCache` (`b.live`/`e.used` unchanged, counted in `held`).
            // On random eviction or `endTask` purge, a single arm64 `ldset`
            // moves `.quarantined -> .cached` straight into `cache.slots[0]`,
            // eliminating `objects.mutex` on the hot `.objects` alloc/free path!
            if (!self.config.retire_freed_spans and
                (self.quarantine.window_cache == null or self.quarantine.window_cache == cache))
            {
                self.quarantine.window_cache = cache;
                cache.held_local[0] += 1;
                cache.held[0].store(cache.held_local[0], .monotonic);
                cache.held_bytes_local[0] += div.block_bytes;
                cache.held_bytes[0].store(cache.held_bytes_local[0], .monotonic);
                self.hold(address | (class + 1), div.block_bytes, false);
                self.noteFree(expected, address);
                return;
            }
            std.Io.Threaded.mutexLockUncancelable(&self.objects.mutex);
            defer std.Io.Threaded.mutexUnlock(&self.objects.mutex);
            const b = &self.objects_buckets[want];
            b.live -= 1;
            b.requested -|= size;
            e.quarantined += 1;
            self.hold(address, div.block_bytes, true);
            self.noteFree(expected, address);
            return;
        }
        if (!slotSwap(map, slot, .allocated, .cached)) {
            @branchHint(.cold);
            return self.violation(.double_free, address);
        }
        if (expected != .bytes) {
            const fill_len = if (cache.poison) div.block_bytes else @min(div.block_bytes, general_objects_zero_cap);
            @memset(ptr[0..fill_len], if (cache.poison) poison_byte else 0);
        } else if (cache.poison) {
            @memset(ptr[0..div.block_bytes], poison_byte);
        }
        var count = cache.counts[pi][class];
        if (count == cache_depth) {
            @branchHint(.cold);
            self.spillCacheLocked(cache, expected, want, class, false);
            count = cache.counts[pi][class];
        }
        cache.slots[pi][class][count] = @intCast(offset / 16);
        cache.counts[pi][class] = count + 1;
        cache.held_local[pi] += 1;
        cache.held[pi].store(cache.held_local[pi], .monotonic);
        cache.held_bytes_local[pi] += div.block_bytes;
        cache.held_bytes[pi].store(cache.held_bytes_local[pi], .monotonic);
        self.noteFree(expected, address);
    }

    fn spillCacheLocked(self: *Engine, cache: *AgentCache, pid: PartitionId, want: u16, class: usize, already_locked: bool) void {
        @branchHint(.cold);
        const p = self.partition(pid);
        const pi = cacheIndex(pid);
        const half = cache_depth / 2;
        const arr = &cache.slots[pi][class];
        if (already_locked) {
            self.giveBack(p, want, arr[0..half], null);
        } else {
            std.Io.Threaded.mutexLockUncancelable(&p.mutex);
            defer std.Io.Threaded.mutexUnlock(&p.mutex);
            self.giveBack(p, want, arr[0..half], null);
        }
        std.mem.copyForwards(u32, arr[0 .. cache_depth - half], arr[half..cache_depth]);
        cache.counts[pi][class] = cache_depth - half;
        cache.held_local[pi] -|= half;
        cache.held[pi].store(cache.held_local[pi], .monotonic);
        cache.held_bytes_local[pi] -|= half * general_slot_div[class].block_bytes;
        cache.held_bytes[pi].store(cache.held_bytes_local[pi], .monotonic);
    }

    /// Fill `cache`'s stack for `class` of `pid` with up to `want` blocks
    /// (at most `cache_depth` and at most ~2 KiB), lowest address first, under
    /// the partition's lock. Past the first block, only already-committed spans
    /// with room are drawn from (`takeSlotExisting`): refill never opens or
    /// recommits an extra span just to top up a cache (M3/M7-4).
    fn refill(self: *Engine, cache: *AgentCache, pid: PartitionId, class: usize) Error!void {
        const p = self.partition(pid);
        if (p.lo == p.hi) return error.OutOfMemory;
        const bi = generalBucket(pid, class, 0);
        const b = &self.buckets(pid)[bi];
        const pi = cacheIndex(pid);
        const arr = &cache.slots[pi][class];
        const bb = general_slot_div[class].block_bytes;
        const want: usize = @min(cache_depth, @max(@as(usize, 1), 2048 / bb));
        std.Io.Threaded.mutexLockUncancelable(&p.mutex);
        defer std.Io.Threaded.mutexUnlock(&p.mutex);
        var got: [cache_depth]u32 = undefined;
        const first = try self.takeSlot(p, b, bi);
        got[0] = @intCast(first / 16);
        var n: usize = 1;
        while (n < want) : (n += 1) {
            const offset = self.takeSlotExisting(p, b) orelse break;
            got[n] = @intCast(offset / 16);
        }
        // Lowest address on top: the stack pops from the end.
        for (0..n) |i| arr[i] = got[n - 1 - i];
        cache.counts[pi][class] = @intCast(n);
        cache.held_local[pi] += n;
        cache.held[pi].store(cache.held_local[pi], .monotonic);
        cache.held_bytes_local[pi] += n * bb;
        cache.held_bytes[pi].store(cache.held_bytes_local[pi], .monotonic);
        cache.seen_frontier[pi] = p.frontier;
    }

    /// A block of bucket `b` from an ALREADY-COMMITTED span with room (or its
    /// magazine, if any), without opening or recommitting a span. Null if none
    /// has room. The partition's lock held.
    fn takeSlotExisting(self: *Engine, p: *Partition, b: *Bucket) ?usize {
        if (magazine_depth != 0 and b.mag_count != 0) {
            b.mag_count -= 1;
            const offset = @as(usize, self.magazineOf(p, b)[b.mag_count]) * 16;
            b.live += 1;
            if (b.live > b.live_peak) b.live_peak = b.live;
            b.issued += 1;
            return offset;
        }
        var index = b.current;
        if (index == no_span or self.entry(index).used == self.entry(index).slots) {
            index = self.lowest(p, b, .room) orelse return null;
            b.current = index;
        }
        return self.takeSlotFromSpan(p, b, index);
    }

    /// A block of bucket `b` out of its spans into a cache, state `.cached`:
    /// from an already-committed span first, else a released span or a new
    /// span. The partition's lock held. Its offset.
    fn takeSlot(self: *Engine, p: *Partition, b: *Bucket, bi: u16) Error!usize {
        if (self.takeSlotExisting(p, b)) |offset| return offset;
        const index = released: {
            const released = self.lowest(p, b, .released) orelse break :released try self.openSpan(p, bi);
            try self.reuseReleased(p, b, released);
            break :released released;
        };
        b.current = index;
        return self.takeSlotFromSpan(p, b, index);
    }

    fn takeSlotFromSpan(self: *Engine, p: *Partition, b: *Bucket, index: u32) usize {
        const e = self.entry(index);
        const map = self.slotMap(index);
        const slot = findFree(map, e.hint, e.slots) orelse unreachable;
        slotSet(map, slot, .cached, true);
        e.hint = @intCast(slot + 1);
        if (e.used == 0) {
            self.setTier(p, b, e, .empty, false);
            p.stats.spans_empty -= 1;
        }
        e.used += 1;
        if (e.used == e.slots) {
            self.setTier(p, b, e, .room, false);
            b.current = no_span;
        }
        const offset = @as(usize, index) * span_bytes + slot * b.block_bytes;
        if (slot >= e.issued_hi) {
            e.issued_hi = @intCast(slot + 1);
            b.fresh += 1;
            if (self.config.fill == .poison) @memset(@as([*]u8, @ptrFromInt(self.heap.window_base + offset))[0..b.fill_bytes], poison_byte);
        }
        b.live += 1;
        if (b.live > b.live_peak) b.live_peak = b.live;
        b.issued += 1;
        return offset;
    }

    inline fn cacheIndex(pid: PartitionId) usize {
        return switch (pid) {
            .objects => 0,
            .bytes => 1,
            .node, .satellite => unreachable,
        };
    }

    /// Whether a general block of `old_size` may become `new_size` in place:
    /// the same class (or, huge, the same spans committed), or for `bytes`
    /// large runs (M8-3) shrinking or growing in place into an adjacent free
    /// span run in the same super page.
    pub fn resizesInPlace(self: *Engine, ptr: [*]u8, old_size: usize, new_size: usize, alignment: usize) bool {
        const old_bytes = classes.requestBytes(old_size, alignment);
        const new_bytes = classes.requestBytes(new_size, alignment);
        if (old_bytes > huge_threshold_bytes or new_bytes > huge_threshold_bytes)
            return old_bytes > huge_threshold_bytes and new_bytes > huge_threshold_bytes and runOf(old_bytes) == runOf(new_bytes);
        const old_class = generalClassOf(old_size, alignment);
        const new_class = generalClassOf(new_size, alignment);
        if (old_class) |o| return if (new_class) |n| o == n else false;
        if (new_class != null) return false;
        const old_run = runOf(old_bytes);
        const new_run = runOf(new_bytes);
        if (old_run == new_run) return true;
        // M8-3: `bytes` large runs can shrink or expand in place into adjacent
        // free spans in the same super page (zero-copy `ArrayList(u8)` growth!).
        const offset = self.offsetOf(@intFromPtr(ptr)) orelse return false;
        if (self.partitionOfOffset(offset) != .bytes) return false;
        return self.resizeBytesLarge(offset, old_run, new_run, old_size, new_size);
    }

    // ------------------------------------------------------------------
    // Bytes coalescing large-run allocator (M8-3, Design 3.1)
    // ------------------------------------------------------------------

    const spans_per_super: usize = super_page / span_bytes;

    inline fn sameSuperPage(a: u32, b: u32) bool {
        return (a / spans_per_super) == (b / spans_per_super);
    }

    inline fn bytesRunsPtr(self: *Engine, p: *const Partition) [*]BytesRun {
        return @ptrFromInt(self.heap.window_base + self.meta_pool_base + @as(usize, p.bytes_runs_chunk) * @sizeOf(Chunk));
    }

    fn ensureBytesRunsCap(self: *Engine, p: *Partition, want: u32) Error![*]BytesRun {
        if (p.bytes_runs_cap >= want) return self.bytesRunsPtr(p);
        const new_cap: u32 = @max(@as(u32, 256), p.bytes_runs_cap * 2);
        const id = try self.poolAlloc(p, @as(usize, new_cap) * @sizeOf(BytesRun));
        const new_ptr: [*]BytesRun = @ptrFromInt(self.heap.window_base + self.meta_pool_base + @as(usize, id) * @sizeOf(Chunk));
        if (p.bytes_runs_len > 0) {
            const old_ptr = self.bytesRunsPtr(p);
            @memcpy(new_ptr[0..p.bytes_runs_len], old_ptr[0..p.bytes_runs_len]);
        }
        p.bytes_runs_chunk = id;
        p.bytes_runs_cap = new_cap;
        return new_ptr;
    }

    fn insertBytesFreeRun(self: *Engine, p: *Partition, first: u32, len: u16, committed: bool, since: u32) void {
        const state: SpanState = if (committed) .free_run else .decommitted;
        for (0..len) |k| {
            self.entry(first + k).* = .{
                .bucket = bytes_large_bucket,
                .state = state,
                .slots = 0,
                .used = 0,
                .quarantined = 0,
                .hint = 0,
                .issued_hi = 0,
                .run = 0,
                .chunk = no_chunk,
                .ordinal = 0,
                .empty_since = since,
                .sites = 0,
            };
        }
        const n = p.bytes_runs_len;
        const runs = self.ensureBytesRunsCap(p, n + 1) catch return;
        var pos: u32 = 0;
        while (pos < n and runs[pos].first < first) : (pos += 1) {}
        const merge_left = pos > 0 and runs[pos - 1].committed == committed and
            sameSuperPage(runs[pos - 1].first, first) and runs[pos - 1].first + runs[pos - 1].len == first;
        const merge_right = pos < n and runs[pos].committed == committed and
            sameSuperPage(first, runs[pos].first) and first + len == runs[pos].first;
        if (merge_left and merge_right) {
            runs[pos - 1].len += len + runs[pos].len;
            runs[pos - 1].empty_since = since;
            var k = pos;
            while (k + 1 < n) : (k += 1) runs[k] = runs[k + 1];
            p.bytes_runs_len = n - 1;
        } else if (merge_left) {
            runs[pos - 1].len += len;
            runs[pos - 1].empty_since = since;
        } else if (merge_right) {
            runs[pos].first = first;
            runs[pos].len += len;
            runs[pos].empty_since = since;
        } else {
            var k = n;
            while (k > pos) : (k -= 1) runs[k] = runs[k - 1];
            runs[pos] = .{ .first = first, .len = len, .committed = committed, .empty_since = since };
            p.bytes_runs_len = n + 1;
        }
    }

    fn decommitBytesRunAt(self: *Engine, p: *Partition, idx: u32) bool {
        const runs = self.bytesRunsPtr(p);
        const r = runs[idx];
        std.debug.assert(r.committed);
        const bytes = @as(usize, r.len) * span_bytes;
        self.heap.decommit(@as(usize, r.first) * span_bytes, bytes) catch return false;
        var k = idx;
        while (k + 1 < p.bytes_runs_len) : (k += 1) runs[k] = runs[k + 1];
        p.bytes_runs_len -= 1;
        p.bytes_free_committed_bytes -= bytes;
        p.stats.committed_span_bytes -= bytes;
        p.stats.spans_active -= r.len;
        p.stats.spans_empty -= r.len;
        p.stats.spans_decommitted += r.len;
        self.insertBytesFreeRun(p, r.first, r.len, false, r.empty_since);
        return true;
    }

    fn evictBytesFreeRuns(self: *Engine, p: *Partition, budget: usize) void {
        const now_ms = self.now_ms.load(.monotonic);
        while (p.bytes_free_committed_bytes > budget) {
            const runs = self.bytesRunsPtr(p);
            var oldest_idx: ?u32 = null;
            var oldest_age: u32 = 0;
            for (0..p.bytes_runs_len) |i| {
                if (!runs[i].committed) continue;
                const age = now_ms -% runs[i].empty_since;
                if (oldest_idx == null or age >= oldest_age) {
                    oldest_idx = @intCast(i);
                    oldest_age = age;
                }
            }
            const idx = oldest_idx orelse break;
            if (!self.decommitBytesRunAt(p, idx)) break;
        }
    }

    fn decommitBytesRunsAged(self: *Engine, p: *Partition, now_ms: u32, age_limit: u32, budget: usize, result: *DecommitResult) void {
        if (p.bytes_free_committed_bytes == 0 or p.bytes_runs_len == 0) return;
        var i: u32 = 0;
        while (i < p.bytes_runs_len) {
            const runs = self.bytesRunsPtr(p);
            const r = runs[i];
            if (!r.committed) {
                i += 1;
                continue;
            }
            const age = now_ms -% r.empty_since;
            if (age < age_limit) {
                const due = r.empty_since +% age_limit;
                result.next_due_ms = if (result.next_due_ms) |d| @min(d, due) else due;
                i += 1;
                continue;
            }
            if (result.decommitted >= budget) {
                result.more = true;
                return;
            }
            if (!self.decommitBytesRunAt(p, i)) {
                i += 1;
                continue;
            }
            result.decommitted += 1;
            // Restart from 0 because coalescing into `.decommitted` may have shifted indices.
            i = 0;
        }
    }

    /// Allocate a `bytes` large run (`> 16 KiB` up to `huge_threshold_bytes`)
    /// from the coalescing span-run pool (M8-3). `p.mutex` held.
    fn allocBytesLarge(self: *Engine, p: *Partition, bytes: usize, req_size: usize) Error![*]u8 {
        const need: u16 = @intCast(runOf(bytes));
        const run_bytes = @as(usize, need) * span_bytes;
        var first: u32 = 0;
        var found = false;
        var from_committed_free = false;

        // 1. Best-fit (smallest len, tie-break lowest address) committed free run.
        if (p.bytes_runs_len > 0) {
            const runs = self.bytesRunsPtr(p);
            var best: ?u32 = null;
            for (0..p.bytes_runs_len) |i| {
                const r = runs[i];
                if (!r.committed or r.len < need) continue;
                if (best == null or r.len < runs[best.?].len or (r.len == runs[best.?].len and r.first < runs[best.?].first)) {
                    best = @intCast(i);
                }
            }
            if (best) |idx| {
                first = runs[idx].first;
                if (runs[idx].len == need) {
                    var k = idx;
                    while (k + 1 < p.bytes_runs_len) : (k += 1) runs[k] = runs[k + 1];
                    p.bytes_runs_len -= 1;
                } else {
                    runs[idx].first += need;
                    runs[idx].len -= need;
                }
                p.bytes_free_committed_bytes -= run_bytes;
                p.stats.spans_empty -= need;
                found = true;
                from_committed_free = true;
            }
        }

        // 2. Best-fit decommitted free run (recommit only the needed spans).
        if (!found and p.bytes_runs_len > 0) {
            const runs = self.bytesRunsPtr(p);
            var best: ?u32 = null;
            for (0..p.bytes_runs_len) |i| {
                const r = runs[i];
                if (r.committed or r.len < need) continue;
                if (best == null or r.len < runs[best.?].len or (r.len == runs[best.?].len and r.first < runs[best.?].first)) {
                    best = @intCast(i);
                }
            }
            if (best) |idx| {
                const candidate = runs[idx].first;
                self.heap.recommit(@as(usize, candidate) * span_bytes, run_bytes, false) catch return error.OutOfMemory;
                first = candidate;
                if (runs[idx].len == need) {
                    var k = idx;
                    while (k + 1 < p.bytes_runs_len) : (k += 1) runs[k] = runs[k + 1];
                    p.bytes_runs_len -= 1;
                } else {
                    runs[idx].first += need;
                    runs[idx].len -= need;
                }
                p.stats.spans_decommitted -= need;
                p.stats.spans_active += need;
                p.stats.committed_span_bytes += run_bytes;
                if (self.config.fill == .poison) @memset(@as([*]u8, @ptrFromInt(self.spanAddress(first)))[0..run_bytes], 0);
                found = true;
            }
        }

        // 3. Open fresh spans at `p.frontier` (super-page safe, no bitmap needed).
        if (!found) {
            var at = p.frontier;
            if (at % super_page == 0) at += span_bytes;
            if (at % super_page + run_bytes > super_page) at = std.mem.alignForward(usize, at, super_page) + span_bytes;
            const end = at + run_bytes;
            if (end > p.limit) return error.OutOfMemory;
            if (self.grow_hook) |hook| if (!hook.call(hook.context)) return error.OutOfMemory;
            while (p.data_hi < end) {
                const super_start = std.mem.alignBackward(usize, p.data_hi, super_page);
                self.heap.commit(super_start + span_bytes, super_page - span_bytes) catch return error.OutOfMemory;
                p.data_hi = super_start + super_page;
            }
            first = @intCast(at / span_bytes);
            try self.commitMeta(&p.table_hi, @as(usize, @intCast(layout.span_table.offset)) + (@as(usize, first) + need) * @sizeOf(SpanEntry));
            @atomicStore(usize, &p.frontier, end, .release);
            p.stats.spans_active += need;
            p.stats.committed_span_bytes += run_bytes;
            p.stats.va_assigned = p.frontier - p.lo;
            if (!p.stats.pressure_raised and (p.frontier - p.lo) * 10 >= (p.limit - p.lo) * 9) self.raisePressure(p);
        }

        self.entry(first).* = .{
            .bucket = bytes_large_bucket,
            .state = .active,
            .slots = need,
            .used = 1,
            .quarantined = 0,
            .hint = 0,
            .issued_hi = 1,
            .run = need,
            .chunk = no_chunk,
            .ordinal = 0,
            .empty_since = 0,
            .sites = 0,
        };
        for (1..need) |k| self.entry(first + k).* = .{
            .bucket = bytes_large_bucket,
            .state = .run_tail,
            .slots = 0,
            .used = 0,
            .quarantined = 0,
            .hint = 0,
            .issued_hi = 0,
            .run = 0,
            .chunk = first,
            .ordinal = 0,
            .empty_since = 0,
            .sites = 0,
        };
        const b = &self.bytes_buckets[bytes_large_bucket];
        b.live += 1;
        if (b.live > b.live_peak) b.live_peak = b.live;
        b.issued += 1;
        b.requested += req_size;
        b.requested_total += req_size;
        p.bytes_large_live_bytes += run_bytes;
        const block: [*]u8 = @ptrFromInt(self.spanAddress(first));
        if (self.config.fill == .poison and from_committed_free) {
            self.verifyFreed(block[0..req_size], false);
        }
        self.noteAlloc(p.id, req_size, @intFromPtr(block));
        return block;
    }

    fn freeBytesLarge(self: *Engine, p: *Partition, offset: usize, bytes: usize, req_size: usize) void {
        const address = self.heap.window_base + offset;
        const first: u32 = @intCast(offset / span_bytes);
        const e = self.entry(first);
        if (offset % span_bytes != 0 or e.state == .run_tail or e.state == .unopened) return self.violation(.invalid_free, address);
        if (e.state != .active) return self.violation(.double_free, address);
        if (bytes <= GeneralClasses.max_size or runOf(bytes) != e.run) return self.violation(.wrong_size, address);
        self.noteFree(p.id, address);
        const run: u16 = e.run;
        const run_bytes = @as(usize, run) * span_bytes;
        if (self.config.fill == .poison) @memset(@as([*]u8, @ptrFromInt(address))[0..run_bytes], poison_byte);
        const b = &self.bytes_buckets[bytes_large_bucket];
        b.live -= 1;
        b.requested -|= req_size;
        p.bytes_large_live_bytes -|= run_bytes;
        const now_ms = self.now_ms.load(.monotonic);
        p.bytes_free_committed_bytes += run_bytes;
        p.stats.spans_empty += run;
        self.insertBytesFreeRun(p, first, run, true, now_ms);
        const cap: usize = if (self.config.retire_freed_spans) 0 else bytes_free_committed_budget;
        if (p.bytes_free_committed_bytes > cap) self.evictBytesFreeRuns(p, cap);
    }

    fn resizeBytesLarge(self: *Engine, offset: usize, old_run: usize, new_run: usize, old_size: usize, new_size: usize) bool {
        if (offset % span_bytes != 0) return false;
        const p = &self.bytes;
        std.Io.Threaded.mutexLockUncancelable(&p.mutex);
        defer std.Io.Threaded.mutexUnlock(&p.mutex);
        if (offset >= p.frontier) return false;
        const first: u32 = @intCast(offset / span_bytes);
        const e = self.entry(first);
        if (e.state != .active or e.bucket != bytes_large_bucket or e.run != old_run) return false;
        const b = &self.bytes_buckets[bytes_large_bucket];
        if (new_run < old_run) {
            const drop: u16 = @intCast(old_run - new_run);
            const drop_first: u32 = first + @as(u32, @intCast(new_run));
            const drop_bytes = @as(usize, drop) * span_bytes;
            if (self.config.fill == .poison) @memset(@as([*]u8, @ptrFromInt(self.spanAddress(drop_first)))[0..drop_bytes], poison_byte);
            e.run = @intCast(new_run);
            e.slots = @intCast(new_run);
            p.bytes_large_live_bytes -|= drop_bytes;
            b.requested = b.requested -| old_size + new_size;
            const now_ms = self.now_ms.load(.monotonic);
            p.bytes_free_committed_bytes += drop_bytes;
            p.stats.spans_empty += drop;
            self.insertBytesFreeRun(p, drop_first, drop, true, now_ms);
            const cap: usize = if (self.config.retire_freed_spans) 0 else bytes_free_committed_budget;
            if (p.bytes_free_committed_bytes > cap) self.evictBytesFreeRuns(p, cap);
            return true;
        }
        // Grow in place: check if the immediately trailing run in the same super page is free!
        if (!sameSuperPage(first, first + @as(u32, @intCast(new_run - 1)))) return false;
        if (p.bytes_runs_len == 0) return false;
        const need_extra: u16 = @intCast(new_run - old_run);
        const tail_start: u32 = first + @as(u32, @intCast(old_run));
        const runs = self.bytesRunsPtr(p);
        for (0..p.bytes_runs_len) |i| {
            if (runs[i].first != tail_start) continue;
            if (runs[i].len < need_extra) return false;
            const extra_bytes = @as(usize, need_extra) * span_bytes;
            if (!runs[i].committed) {
                self.heap.recommit(@as(usize, tail_start) * span_bytes, extra_bytes, false) catch return false;
                p.stats.spans_decommitted -= need_extra;
                p.stats.spans_active += need_extra;
                p.stats.committed_span_bytes += extra_bytes;
            } else {
                p.bytes_free_committed_bytes -= extra_bytes;
                p.stats.spans_empty -= need_extra;
            }
            if (runs[i].len == need_extra) {
                var k: u32 = @intCast(i);
                while (k + 1 < p.bytes_runs_len) : (k += 1) runs[k] = runs[k + 1];
                p.bytes_runs_len -= 1;
            } else {
                runs[i].first += need_extra;
                runs[i].len -= need_extra;
            }
            for (0..need_extra) |k| self.entry(tail_start + k).* = .{
                .bucket = bytes_large_bucket,
                .state = .run_tail,
                .slots = 0,
                .used = 0,
                .quarantined = 0,
                .hint = 0,
                .issued_hi = 0,
                .run = 0,
                .chunk = first,
                .ordinal = 0,
                .empty_since = 0,
                .sites = 0,
            };
            e.run = @intCast(new_run);
            e.slots = @intCast(new_run);
            p.bytes_large_live_bytes += extra_bytes;
            b.requested = b.requested -| old_size + new_size;
            if (self.config.fill == .poison) @memset(@as([*]u8, @ptrFromInt(self.spanAddress(tail_start)))[0..extra_bytes], 0);
            return true;
        }
        return false;
    }

    /// A huge block: past a large run, whole super pages of `p`'s range. Its
    /// first span is its super page's guard, its data the spans after it,
    /// and the next super page's first span its trailing guard (oss R19,
    /// design 3.1's "its own mapping ... a guard page on each side"). Its
    /// entry names `huge_bucket`; `slots` the spans its block needs (what its
    /// free's size is checked against), `run` the region's. A freed region is
    /// decommitted and kept: the next huge block that fits it takes it (first
    /// fit, lowest address), so churning large bodies cannot use up the
    /// range. The partition's lock held.
    fn allocHuge(self: *Engine, p: *Partition, bytes: usize) Error![*]u8 {
        const need = runOf(bytes);
        if (need > std.math.maxInt(u16)) return error.OutOfMemory;
        const regions = try self.hugeRegions(p);
        // A kept region it fits, lowest first.
        var best: ?usize = null;
        for (regions[0..p.huge_count], 0..) |r, i| {
            if (r.used or r.data_spans < need) continue;
            if (best == null or r.first < regions[best.?].first) best = i;
        }
        const index: usize = if (best) |i| index: {
            const r = &regions[i];
            // Its freed region was retired (inaccessible): bring the block's
            // spans back, a super page at a time.
            try self.hugeRange(@as(usize, r.first) * span_bytes, need * span_bytes, .recommit);
            if (self.fills(p)) @memset(@as([*]u8, @ptrFromInt(self.spanAddress(r.first)))[0 .. need * span_bytes], 0);
            r.used = true;
            r.committed = @intCast(need);
            break :index r.first;
        } else index: {
            if (p.huge_count == huge_regions_max) return error.OutOfMemory;
            const at = std.mem.alignForward(usize, p.frontier, super_page);
            const supers = (span_bytes + need * span_bytes + super_page - 1) / super_page;
            const end = at + supers * super_page;
            if (end > p.limit) return error.OutOfMemory;
            if (self.grow_hook) |hook| if (!hook.call(hook.context)) return error.OutOfMemory;
            const first = at / span_bytes + 1;
            const data_spans = supers * (super_page / span_bytes) - 1;
            try self.commitMeta(&p.table_hi, @as(usize, @intCast(layout.span_table.offset)) + (first + data_spans) * @sizeOf(SpanEntry));
            try self.hugeRange(first * span_bytes, need * span_bytes, .commit);
            // Class spans open past it: nothing commits over its guards.
            @atomicStore(usize, &p.frontier, end, .release);
            p.data_hi = @max(p.data_hi, end);
            p.stats.va_assigned = p.frontier - p.lo;
            for (1..data_spans) |k| self.entry(first + k).* = .{ .bucket = huge_bucket, .state = .run_tail, .slots = 0, .used = 0, .quarantined = 0, .hint = 0, .issued_hi = 0, .run = 0, .chunk = @intCast(first), .ordinal = 0, .empty_since = 0, .sites = 0 };
            regions[p.huge_count] = .{ .first = @intCast(first), .data_spans = @intCast(data_spans), .committed = @intCast(need), .used = true };
            p.huge_count += 1;
            if (!p.stats.pressure_raised and (p.frontier - p.lo) * 10 >= (p.limit - p.lo) * 9) self.raisePressure(p);
            break :index first;
        };
        self.entry(index).* = .{ .bucket = huge_bucket, .state = .active, .slots = @intCast(need), .used = 1, .quarantined = 0, .hint = 0, .issued_hi = 1, .run = @intCast(need), .chunk = no_chunk, .ordinal = 0, .empty_since = 0, .sites = 0 };
        p.stats.huge_blocks += 1;
        p.stats.huge_bytes += need * span_bytes;
        p.stats.committed_span_bytes += need * span_bytes;
        const address = self.spanAddress(index);
        self.noteAlloc(p.id, need * span_bytes, address);
        return @ptrFromInt(address);
    }

    /// Free a huge block at `offset` (its entry names `huge_bucket`), of
    /// `bytes`: its committed spans are decommitted and its region kept.
    fn freeHuge(self: *Engine, p: *Partition, offset: usize, bytes: usize) void {
        const address = self.heap.window_base + offset;
        const index = offset / span_bytes;
        const e = self.entry(index);
        if (offset % span_bytes != 0) return self.violation(.invalid_free, address);
        if (e.state != .active) return self.violation(.double_free, address);
        if (bytes <= huge_threshold_bytes or runOf(bytes) != e.slots) return self.violation(.wrong_size, address);
        const regions = self.hugeRegions(p) catch unreachable;
        const r = for (regions[0..p.huge_count]) |*r| {
            if (r.first == index) break r;
        } else return self.violation(.invalid_free, address);
        self.noteFree(p.id, address);
        const committed: usize = r.committed;
        // Released and made inaccessible: a read through a pointer kept past
        // the free faults, where a decommitted page would read zero.
        self.hugeRange(index * span_bytes, committed * span_bytes, .retire) catch {};
        e.state = .decommitted;
        r.used = false;
        r.committed = 0;
        p.stats.huge_blocks -= 1;
        p.stats.huge_bytes -= committed * span_bytes;
        p.stats.committed_span_bytes -= committed * span_bytes;
    }

    /// Commit, retire or recommit `[offset, offset + length)` of a huge region, a
    /// super page at a time (BrowserHeap: never across a super page).
    fn hugeRange(self: *Engine, offset: usize, length: usize, comptime op: enum { commit, retire, recommit }) Error!void {
        var at = offset;
        const end = offset + length;
        while (at < end) {
            const piece = @min(end, std.mem.alignForward(usize, at + 1, super_page)) - at;
            switch (op) {
                .commit => self.heap.commit(at, piece) catch return error.OutOfMemory,
                .retire => self.heap.retire(at, piece) catch return error.OutOfMemory,
                .recommit => self.heap.recommit(at, piece, true) catch return error.OutOfMemory,
            }
            at += piece;
        }
    }

    /// `p`'s huge regions: a table in the metadata pool, made at its first
    /// huge block.
    fn hugeRegions(self: *Engine, p: *Partition) Error![*]HugeRegion {
        if (p.huge_table == no_chunk) p.huge_table = try self.poolAlloc(p, huge_regions_max * @sizeOf(HugeRegion));
        return @ptrFromInt(self.heap.window_base + self.meta_pool_base + @as(usize, p.huge_table) * @sizeOf(Chunk));
    }

    // ------------------------------------------------------------------
    // Free
    // ------------------------------------------------------------------

    /// Free a State block: validated (design 3.3), filled, then held in the
    /// quarantine (a window-thread free while a task runs) or released.
    pub fn free(self: *Engine, ptr: [*]u8, size: usize, alignment: usize) void {
        const address = @intFromPtr(ptr);
        const offset = self.offsetOf(address) orelse return self.violation(.other_heap, address);
        const pid = self.partitionOfOffset(offset) orelse return self.violation(.invalid_free, address);
        const bytes = classes.requestBytes(size, alignment);
        const want: u16 = switch (pid) {
            // The free is untyped: any kind of the class is the right one.
            .node => if (classes.classOf(size, alignment)) |class| @intCast(class) else largeBucket(.node, runOf(bytes)),
            .objects => if (classes.classOf(size, alignment)) |class| @intCast(class) else largeBucket(.objects, runOf(bytes)),
            // A State block is never in the page's bytes or satellite partition.
            .bytes, .satellite => return self.violation(.invalid_free, address),
        };
        switch (pid) {
            .node => {
                const thread = platform.currentThreadToken();
                if (!self.onNodeThread(address, thread)) return;
                self.freeIn(&self.node, offset, want, false, size, thread);
            },
            .objects => {
                std.Io.Threaded.mutexLockUncancelable(&self.objects.mutex);
                defer std.Io.Threaded.mutexUnlock(&self.objects.mutex);
                self.freeIn(&self.objects, offset, want, false, size, null);
            },
            .bytes, .satellite => unreachable,
        }
    }

    /// Free an Instance slot whose stamp the slab has set dead.
    pub fn freeInstance(self: *Engine, slot: *[instance_slot_bytes]u8) void {
        const address = @intFromPtr(slot);
        const offset = self.offsetOf(address) orelse return self.violation(.other_heap, address);
        if (self.partitionOfOffset(offset) != .objects) return self.violation(.invalid_free, address);
        std.Io.Threaded.mutexLockUncancelable(&self.objects.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.objects.mutex);
        self.freeIn(&self.objects, offset, instance_bucket, true, instance_fill_bytes, null);
    }

    /// `free` of a State block, then `freeInstance` of its slot, the objects
    /// lock taken once (`allocInstanceWith`'s counterpart). Each is
    /// validated as those calls validate it, in that order.
    pub fn freeInstanceWith(self: *Engine, slot: *[instance_slot_bytes]u8, state: [*]u8, size: usize, alignment: usize) void {
        const thread = platform.currentThreadToken();
        // The State block, validated before anything is freed.
        const address = @intFromPtr(state);
        const state_at: ?struct { pid: PartitionId, offset: usize, want: u16 } = at: {
            const offset = self.offsetOf(address) orelse {
                self.violation(.other_heap, address);
                break :at null;
            };
            const pid = self.partitionOfOffset(offset) orelse {
                self.violation(.invalid_free, address);
                break :at null;
            };
            if (pid == .bytes or pid == .satellite) {
                self.violation(.invalid_free, address);
                break :at null;
            }
            const bytes = classes.requestBytes(size, alignment);
            const want: u16 = if (classes.classOf(size, alignment)) |class| @intCast(class) else largeBucket(pid, runOf(bytes));
            break :at .{ .pid = pid, .offset = offset, .want = want };
        };
        if (state_at) |at| if (at.pid == .node and self.onNodeThread(address, thread))
            self.freeIn(&self.node, at.offset, at.want, false, size, thread);
        const slot_address = @intFromPtr(slot);
        const slot_offset = self.offsetOf(slot_address);
        std.Io.Threaded.mutexLockUncancelable(&self.objects.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.objects.mutex);
        if (state_at) |at| if (at.pid == .objects) self.freeIn(&self.objects, at.offset, at.want, false, size, thread);
        const offset = slot_offset orelse return self.violation(.other_heap, slot_address);
        if (self.partitionOfOffset(offset) != .objects) return self.violation(.invalid_free, slot_address);
        self.freeIn(&self.objects, offset, instance_bucket, true, instance_fill_bytes, thread);
    }

    inline fn offsetOf(self: *Engine, address: usize) ?usize {
        const base = self.heap.reserved.base;
        if (address -% base >= self.heap.reserved.size) return null;
        return address - self.heap.window_base;
    }

    /// `want`: the bucket a node free's class names in kind 0, or the exact
    /// bucket.
    /// `thread`: the freeing thread's id where the caller read it already.
    fn freeIn(self: *Engine, p: *Partition, offset: usize, want: u16, instance: bool, size: usize, thread: ?usize) void {
        const address = self.heap.window_base + offset;
        const index = offset / span_bytes;
        const e = self.entry(index);
        if (offset >= p.frontier or e.state == .unopened or e.state == .run_tail) return self.violation(.invalid_free, address);
        if (e.state != .active) return self.violation(.double_free, address);
        // A huge block's span, freed as a class or a large run.
        if (e.bucket == huge_bucket) return self.violation(.wrong_size, address);
        const b = &self.buckets(p.id)[e.bucket];
        // Not the start of one of the span's blocks: an interior pointer.
        const within = offset - index * span_bytes;
        if (within % b.block_bytes != 0) return self.violation(.invalid_free, address);
        // A block's start, freed as another class.
        const matches = if (p.id == .node and !instance and b.kind == .class)
            e.bucket % Classes.count == want
        else
            e.bucket == want;
        if (!matches) return self.violation(if (instance or b.kind == .instance) .invalid_free else .wrong_size, address);
        const slot = within / b.block_bytes;
        const map = self.slotMap(index);
        if (slotGet(map, slot) != .allocated) return self.violation(.double_free, address);
        self.noteFree(p.id, address);

        const block: [*]u8 = @ptrFromInt(address);
        // The page's bytes are neither zeroed nor held (design 1.2: the
        // bytes partition's traffic is the census's tiny, short-lived
        // strings, and its blocks hold no pointer to stale); a poisoning heap
        // poisons them, to find a read after free. Design 3.4: production
        // general objects zero up to the first 1 KiB on free (remainder zeroed
        // on reissue).
        if (self.fills(p)) {
            const fill_len = if (b.general and p.id == .objects and self.config.fill == .zero)
                @min(b.fill_bytes, general_objects_zero_cap)
            else
                b.fill_bytes;
            @memset(block[0..fill_len], self.config.fillByte());
        }
        b.live -= 1;
        b.requested -|= size;

        if (p.id != .bytes and self.holds(thread)) {
            slotSet(map, slot, .quarantined, isSharedPartition(p.id));
            e.quarantined += 1;
            self.hold(address, b.block_bytes, p.id == .objects);
            return;
        }
        self.release(p, b, index, slot);
    }

    /// Whether a free on this thread now is held: the window agent's loop
    /// runs a task, on this thread.
    inline fn holds(self: *Engine, thread: ?usize) bool {
        if (!self.quarantine.active.load(.monotonic)) return false;
        if (self.config.quarantine_cap == 0) return false;
        return self.quarantine.thread.load(.monotonic) == (thread orelse platform.currentThreadToken());
    }

    /// The slot is free again: into its bucket's magazine, or back to its
    /// span (`releaseSlot`).
    fn release(self: *Engine, p: *Partition, b: *Bucket, index: usize, slot: usize) void {
        // Only a block at or below the bucket's lowest span with room (or any,
        // when none is known to have room): one above it goes back to its
        // span, which lowest-address-first then leaves to empty and age. A
        // magazine that took every block spread a churning page's blocks over
        // more spans than lowest-address-first keeps them in, spans last
        // touched just before idle decommit looked: +0.7 to +1.2 MB steady and
        // collected on the events and tree rows (lane hard1's chat2 runs).
        if (!b.general and magazine_depth != 0 and b.kind != .large and !self.config.retire_freed_spans and
            (b.current == no_span or index <= b.current) and
            self.pushMagazine(p, b, index, slot)) return;
        self.releaseSlot(p, b, index, slot, self.now_ms.load(.monotonic));
    }

    inline fn magazineOf(self: *Engine, _: *const Partition, b: *const Bucket) [*]u32 {
        return @ptrFromInt(self.heap.window_base + self.meta_pool_base + @as(usize, b.mag) * @sizeOf(Chunk));
    }

    /// Hold a released slot in its bucket's magazine, `cached`. False: the
    /// magazine is full, or there is none (its chunk could not be had) - the
    /// caller releases the slot to its span. A full magazine takes nothing
    /// more rather than give its older half back (Chromium's ThreadCache
    /// does that, ClearBucket): a burst of frees - a collection's finalizers,
    /// a task's purge - then pays one span release per block, not a push and
    /// a later release (lane hard1's P1: +7 ns a pair in the batch rows).
    fn pushMagazine(self: *Engine, p: *Partition, b: *Bucket, index: usize, slot: usize) bool {
        if (b.mag_count == magazine_depth) return false;
        if (b.mag == no_chunk) b.mag = self.poolAlloc(p, @sizeOf(Chunk)) catch return false;
        const mag = self.magazineOf(p, b);
        slotSet(self.slotMap(index), slot, .cached, isSharedPartition(p.id));
        // The span's last release: a span only the magazine keeps is aged
        // from it when the magazine gives the block back, as it would have
        // been with no magazine (a bucket-wide time made idle decommit miss
        // spans emptied long before: +1 MB steady and collected on the
        // events rows, lane hard1's chat2 mechanism run).
        self.entry(index).empty_since = self.now_ms.load(.monotonic);
        mag[b.mag_count] = @intCast((index * span_bytes + slot * b.block_bytes) / 16);
        b.mag_count += 1;
        return true;
    }

    /// A cached block back to its span, which was last released at its
    /// `empty_since`.
    fn releaseCached(self: *Engine, p: *Partition, b: *Bucket, at: u32) void {
        const offset = @as(usize, at) * 16;
        const index = offset / span_bytes;
        self.releaseSlot(p, b, index, (offset - index * span_bytes) / b.block_bytes, self.entry(index).empty_since);
    }

    /// The magazine's last block, issued as `allocIn` issues one: verified
    /// against its free's fill, zeroed, counted.
    fn popMagazine(self: *Engine, p: *Partition, b: *Bucket, size: usize, site: ?*const Site, return_address: usize) [*]u8 {
        b.mag_count -= 1;
        const offset = @as(usize, self.magazineOf(p, b)[b.mag_count]) * 16;
        const index = offset / span_bytes;
        const slot = (offset - index * span_bytes) / b.block_bytes;
        const map = self.slotMap(index);
        std.debug.assert(slotGet(map, slot) == .cached);
        slotSet(map, slot, .allocated, isSharedPartition(p.id));
        b.live += 1;
        if (b.live > b.live_peak) b.live_peak = b.live;
        b.issued += 1;
        b.requested += size;
        b.requested_total += size;
        const block: [*]u8 = @ptrFromInt(self.heap.window_base + offset);
        const checked = if (b.kind == .instance) instance_fill_bytes else size;
        if (self.fills(p)) self.verifyFreed(block[0..checked], false);
        const e = self.entry(index);
        if (e.sites != 0) {
            const sites: [*]usize = @ptrFromInt(self.heap.window_base + self.meta_pool_base + (@as(usize, e.sites) - 1) * @sizeOf(Chunk));
            sites[slot] = if (site) |s| @intFromPtr(s) else return_address | site_return_tag;
        }
        self.noteAlloc(p.id, size, @intFromPtr(block));
        return block;
    }

    /// Every magazine of the partition back to its spans: what idle
    /// decommit and pressure ask first, so no span is kept open by blocks
    /// nothing uses. Each span is aged from its bucket's last release.
    fn drainMagazines(self: *Engine, p: *Partition) void {
        if (magazine_depth == 0) return;
        for (self.buckets(p.id)) |*b| {
            if (b.mag_count == 0) continue;
            const mag = self.magazineOf(p, b);
            for (mag[0..b.mag_count]) |at| self.releaseCached(p, b, at);
            b.mag_count = 0;
        }
    }

    /// Whether `ptr` is in its bucket's magazine (a test's question).
    pub fn inMagazine(self: *Engine, ptr: *const anyopaque) bool {
        const offset = (self.offsetOf(@intFromPtr(ptr)) orelse return false);
        const pid = self.partitionOfOffset(offset) orelse return false;
        const p = self.partition(pid);
        const index = offset / span_bytes;
        const e = self.entry(index);
        if (e.state != .active) return false;
        const b = &self.buckets(pid)[e.bucket];
        const mag = if (b.mag == no_chunk) return false else self.magazineOf(p, b);
        for (mag[0..b.mag_count]) |at| if (@as(usize, at) * 16 == offset) return true;
        return false;
    }

    /// The slot is free in its span again: the span may have room, or be
    /// empty (aged from `since`, its last release).
    fn releaseSlot(self: *Engine, p: *Partition, b: *Bucket, index: usize, slot: usize, since: u32) void {
        const e = self.entry(index);
        e.empty_since = since;
        slotSet(self.slotMap(index), slot, .free, isSharedPartition(p.id));
        if (slot < e.hint) e.hint = @intCast(slot);
        const was_full = e.used == e.slots;
        e.used -= 1;
        if (was_full) {
            self.setTier(p, b, e, .room, true);
            if (b.current == no_span or index < b.current) b.current = @intCast(index);
        }
        if (e.used == 0) {
            self.setTier(p, b, e, .empty, true);
            p.stats.spans_empty += 1;
            // M8-4b: tight default + thrash-adaptive active empty-span retention:
            // - objects/satellite large runs keep up to 4 runs / 256 KiB in an MRU ring
            //   (100% hit on hot 32-96 KiB loops, cuts `load.docs` empty large);
            // - general & satellite class spans keep up to `b.empty_cap` (2 for <= 2 KiB,
            //   1 for > 2 KiB, adapting up to 512 only on fast < 200 ms recommit
            //   thrashing) within `p.empty_class_budget`, and all reclaim at
            //   200 ms idle (`general_decommit_age_ms`).
            if (usesAdaptiveRetention(p.id, b)) {
                if (b.kind == .large) {
                    if (b.empty_count > 1) {
                        self.releaseSpan(p, b, @intCast(index), false);
                        return;
                    }
                    while (p.empty_large_len >= empty_large_ring_cap or
                        (p.empty_large_len > 0 and p.empty_large_bytes > empty_large_budget_bytes))
                    {
                        const before_len = p.empty_large_len;
                        const victim = p.empty_large_ring[0];
                        const ve = self.entry(victim);
                        self.releaseSpan(p, &self.buckets(p.id)[ve.bucket], victim, false);
                        if (p.empty_large_len == before_len) break;
                    }
                    if (p.empty_large_len < empty_large_ring_cap and p.empty_large_bytes <= empty_large_budget_bytes) {
                        p.empty_large_ring[p.empty_large_len] = @intCast(index);
                        p.empty_large_len += 1;
                    } else {
                        self.releaseSpan(p, b, @intCast(index), false);
                        return;
                    }
                } else if (b.empty_count > b.empty_cap or p.empty_class_spans > p.empty_class_budget) {
                    self.releaseSpan(p, b, @intCast(index), false);
                    return;
                }
            }
            // The bug-finding run makes it inaccessible at once - unless it
            // is the span the bucket allocates from next (no lower span has
            // room): a block made and freed alone would otherwise retire and
            // recommit its span on every cycle.
            if (self.config.retire_freed_spans and b.kind != .instance and
                b.current != no_span and b.current < index and
                self.retired.load(.monotonic) < Config.retired_spans_max) self.releaseSpan(p, b, @intCast(index), true);
        }
    }

    /// Give an empty span's pages back: decommit it, or (the bug-finding
    /// run) retire it - discard, then make it inaccessible.
    fn releaseSpan(self: *Engine, p: *Partition, b: *Bucket, index: u32, retire: bool) void {
        const e = self.entry(index);
        std.debug.assert(e.used == 0 and e.state == .active);
        const bytes = @as(usize, e.run) * span_bytes;
        if (retire) {
            self.heap.retire(index * span_bytes, bytes) catch return;
        } else {
            self.heap.decommit(index * span_bytes, bytes) catch return;
        }
        e.state = if (retire) .retired else .decommitted;
        self.setTier(p, b, e, .room, false);
        self.setTier(p, b, e, .empty, false);
        self.setTier(p, b, e, .released, true);
        if (b.current == index) b.current = no_span;
        p.stats.spans_active -= 1;
        p.stats.spans_empty -= 1;
        p.stats.committed_span_bytes -= bytes;
        if (retire) {
            p.stats.spans_retired += 1;
            _ = self.retired.fetchAdd(1, .monotonic);
        } else p.stats.spans_decommitted += 1;
    }

    // ------------------------------------------------------------------
    // The quarantine (window agent's thread)
    // ------------------------------------------------------------------

    /// The window agent's event loop begins a turn on this thread: frees on
    /// it are held until `endTask`.
    pub fn beginTask(self: *Engine) void {
        self.quarantine.thread.store(platform.currentThreadToken(), .monotonic);
        self.quarantine.active.store(true, .monotonic);
    }

    /// A task (or a teardown slice) ended: everything held is free again
    /// (design 3.5: "when stack memory is likely empty"). M8-1: cache-owned
    /// general `.objects` entries transition `.quarantined -> .cached` via a
    /// single `ldset` directly into `window_cache` without taking `objects.mutex`
    /// unless a span-owned `.objects` entry is present or a stack spills.
    pub fn purge(self: *Engine) void {
        const q = &self.quarantine;
        if (q.count == 0) return;
        const entries = self.quarantineEntries();
        var objects_locked = false;
        defer if (objects_locked) std.Io.Threaded.mutexUnlock(&self.objects.mutex);
        for (entries[0..q.count]) |raw| {
            const tag = raw & quarantine_tag_mask;
            if (tag != 0) {
                _ = self.recycleCachedQuarantined(raw, objects_locked);
                continue;
            }
            const offset = raw - self.heap.window_base;
            if (self.partitionOfOffset(offset) == .objects and !objects_locked) {
                std.Io.Threaded.mutexLockUncancelable(&self.objects.mutex);
                objects_locked = true;
            }
            _ = self.releaseHeld(raw);
        }
        q.count = 0;
        q.held_bytes = 0;
        q.next_slot = no_slot;
    }

    /// The turn ended: purge, and hold nothing until the next.
    pub fn endTask(self: *Engine) void {
        self.purge();
        self.quarantine.active.store(false, .monotonic);
    }

    /// Whether the quarantine holds `ptr` now (a test's question).
    pub fn isQuarantined(self: *Engine, ptr: *const anyopaque) bool {
        const entries = self.quarantineEntries();
        const target = @intFromPtr(ptr);
        for (entries[0..self.quarantine.count]) |raw| {
            if ((raw & ~quarantine_tag_mask) == target) return true;
        }
        return false;
    }

    inline fn quarantineEntries(self: *Engine) [*]usize {
        if (self.quarantine.using_external) return @ptrFromInt(self.heap.at(layout.quarantine.offset));
        return &self.quarantine.inline_entries;
    }

    /// Hold a freed block; past the cap, evict one at random (Chromium's
    /// scheduler-loop quarantine evicts a uniformly random entry too:
    /// scheduler_loop_quarantine.cc, SchedulerLoopQuarantineBranch::
    /// QuarantineWithSize and PurgeInternal, Chromium 461c62b66d7c). A block
    /// larger than the cap is free at once, as there.
    ///
    /// The entry that leaves takes the last one's place, so the list stays
    /// in the order the blocks came, but for the holes: the task-end purge
    /// then releases them mostly in address order. (Chromium's shuffle on
    /// every push - "swap randomly so that the quarantine list remain
    /// shuffled" - made the purge release them in random order: +2 to 5 ns
    /// a pair in lane hard1's batch rows, more than it saved.)
    ///
    /// The victim of the next eviction is drawn one hold ahead and its entry
    /// read then: the eviction's chain of reads (the entry, the block's span
    /// entry, its slot map) then starts from an address already in hand, and
    /// the read of a random cold entry overlaps the work between two frees.
    /// The draw is among the entries the next hold will have, its own block
    /// included, as a draw then would be; one a purge put out of range is
    /// drawn again.
    fn hold(self: *Engine, entry_raw: usize, bytes: usize, objects_locked: bool) void {
        const q = &self.quarantine;
        const cap = self.config.quarantine_cap;
        if (bytes > cap) {
            _ = self.releaseHeldLocked(entry_raw, objects_locked);
            return;
        }
        const capacity: usize = if (q.using_external) q.committed else quarantine_inline_cap;
        if (q.count == capacity) {
            @branchHint(.cold);
            // Spill from inline buffer to `layout.quarantine` (M8-4c), or
            // double external commitment; with no room left, free at once.
            const base: usize = @intCast(layout.quarantine.offset);
            const have = if (q.using_external) q.committed * @sizeOf(usize) else 0;
            const room: usize = @intCast(layout.quarantine.bytes);
            const min_want = @max(self.page, quarantine_inline_cap * 2 * @sizeOf(usize));
            const want = @min(room, std.mem.alignForward(usize, @max(have * 2, min_want), self.page));
            if (want <= have) {
                _ = self.releaseHeldLocked(entry_raw, objects_locked);
                return;
            }
            self.heap.commit(base + have, want - have) catch {
                _ = self.releaseHeldLocked(entry_raw, objects_locked);
                return;
            };
            if (!q.using_external) {
                const ext: [*]usize = @ptrFromInt(self.heap.at(layout.quarantine.offset));
                @memcpy(ext[0..q.count], q.inline_entries[0..q.count]);
                q.using_external = true;
            }
            q.committed = want / @sizeOf(usize);
        }
        const entries = self.quarantineEntries();
        entries[q.count] = entry_raw;
        q.count += 1;
        q.held_bytes += bytes;
        q.total_held += 1;
        var first = true;
        while (q.held_bytes > cap and q.count > 0) {
            // The first victim: the one drawn (and read) by the last hold,
            // still in range; any other drawn now.
            const ahead = first and q.next_slot < q.count;
            const j = if (ahead) q.next_slot else self.drawBelow(q.count);
            const evicted = if (ahead and j < q.count - 1) q.next_entry else entries[j];
            first = false;
            entries[j] = entries[q.count - 1];
            q.count -= 1;
            q.total_evicted += 1;
            q.held_bytes -|= self.releaseHeldLocked(evicted, objects_locked);
        }
        // At the cap, the next hold's victim, among the entries it will have
        // (under it nothing is drawn: the next hold may evict nothing).
        if (first) {
            q.next_slot = no_slot;
            return;
        }
        q.next_slot = self.drawBelow(q.count + 1);
        if (q.next_slot < q.count) q.next_entry = entries[q.next_slot];
    }

    const no_slot = std.math.maxInt(usize);

    /// A uniform draw in [0, n): the Engine's Xoshiro256 called directly,
    /// bounded by multiply-shift (Lemire), which std.Random.uintLessThan
    /// does too - without its interface call and byte fill, which were 5 to
    /// 8% of a quarantined pair's samples (lane hard1's P1 profile). The
    /// eviction draw is a hardening input, not a statistical one: the bias
    /// of at most n / 2^64 is irrelevant to it.
    inline fn drawBelow(self: *Engine, n: usize) usize {
        return @intCast((@as(u128, self.prng.next()) * n) >> 64);
    }

    /// Recycle a cache-owned quarantined `.objects` block directly back into
    /// `window_cache.slots[0][class]` with a single lock-free `ldset`
    /// (`.quarantined -> .cached`), spilling in batches of 4 only when full (M8-1).
    inline fn recycleCachedQuarantined(self: *Engine, raw: usize, objects_locked: bool) usize {
        const class = (raw & quarantine_tag_mask) - 1;
        const address = raw & ~quarantine_tag_mask;
        const cache = self.quarantine.window_cache.?;
        const offset = address - cache.window_base;
        const index = offset / span_bytes;
        const div = general_slot_div[class];
        const within = offset & (span_bytes - 1);
        const slot = ((within >> 4) * div.magic) >> 20;
        const map: *[map_words]u64 = @ptrFromInt(cache.bitmaps_base + index * (map_words * 8));
        slotReleaseQuarantinedToCached(map, slot);
        var count = cache.counts[0][class];
        if (count == cache_depth) {
            @branchHint(.cold);
            self.spillCacheLocked(cache, .objects, generalBucket(.objects, class, 0), class, objects_locked);
            count = cache.counts[0][class];
        }
        cache.slots[0][class][count] = @intCast(offset / 16);
        cache.counts[0][class] = count + 1;
        return div.block_bytes;
    }

    /// `releaseHeld`, taking the objects lock for an objects block unless
    /// the caller holds it (or recycling lock-free for a cache-owned general
    /// objects entry: M8-1). Returns the block's bytes.
    fn releaseHeldLocked(self: *Engine, entry_raw: usize, objects_locked: bool) usize {
        if ((entry_raw & quarantine_tag_mask) != 0) {
            return self.recycleCachedQuarantined(entry_raw, objects_locked);
        }
        const offset = entry_raw - self.heap.window_base;
        if (self.partitionOfOffset(offset) == .objects and !objects_locked) {
            std.Io.Threaded.mutexLockUncancelable(&self.objects.mutex);
            defer std.Io.Threaded.mutexUnlock(&self.objects.mutex);
            return self.releaseHeld(entry_raw);
        }
        return self.releaseHeld(entry_raw);
    }

    /// A held block leaves the quarantine (the objects lock held, or the
    /// block is the node partition's). Returns its bytes: the caller keeps
    /// the quarantine's count.
    fn releaseHeld(self: *Engine, address: usize) usize {
        const offset = address - self.heap.window_base;
        const pid = self.partitionOfOffset(offset).?;
        const p = self.partition(pid);
        const index = offset / span_bytes;
        const e = self.entry(index);
        const b = &self.buckets(pid)[e.bucket];
        const within = offset & (span_bytes - 1);
        const slot = if (b.general and b.kind == .class) blk: {
            const class: usize = if (pid == .bytes) e.bucket else e.bucket - general_objects_base;
            break :blk ((within >> 4) * general_slot_div[class].magic) >> 20;
        } else within / b.block_bytes;
        std.debug.assert(slotGet(self.slotMap(index), slot) == .quarantined);
        e.quarantined -= 1;
        self.release(p, b, index, slot);
        return b.block_bytes;
    }

    // ------------------------------------------------------------------
    // Idle: decommit, pressure
    // ------------------------------------------------------------------

    /// The window agent's loop's clock reading, ms: what span ages are
    /// measured in.
    pub fn setNow(self: *Engine, now_ms: u32) void {
        self.now_ms.store(now_ms, .monotonic);
    }

    pub const DecommitResult = struct {
        /// Spans decommitted now.
        decommitted: usize = 0,
        /// Empty spans not old enough yet: ask again then.
        next_due_ms: ?u32 = null,
        /// Spans left for a later call: the budget ran out.
        more: bool = false,
    };

    /// Decommit up to `budget` empty spans emptied at least `min_age_ms`
    /// before `now_ms` (design 5.1), lowest first. On the window agent's
    /// thread, from its idle turn; the node partition is skipped off it.
    pub fn decommitAged(self: *Engine, now_ms: u32, min_age_ms: u32, budget: usize) DecommitResult {
        var result: DecommitResult = .{};
        // A span only an agent's cache keeps open would stay committed: this
        // thread's agents give their blocks back first, aged from the idle
        // window already waited (`general_decommit_age_ms`) so idle-flushed
        // spans decommit on this pass instead of waiting another cycle (M7-3).
        const gen_age = @min(min_age_ms, general_decommit_age_ms);
        self.flushCachesOfThisThread(now_ms -% gen_age);
        const on_owner = if (self.node.owner) |owner| owner == platform.currentThreadToken() else true;
        if (on_owner) {
            self.drainMagazines(&self.node);
            self.decommitIn(&self.node, now_ms, min_age_ms, budget, &result);
            self.decommitBitmapPages(&self.node);
            self.drainMagazines(&self.satellite);
            self.decommitIn(&self.satellite, now_ms, gen_age, budget, &result);
            self.decommitBitmapPages(&self.satellite);
        }
        {
            std.Io.Threaded.mutexLockUncancelable(&self.objects.mutex);
            defer std.Io.Threaded.mutexUnlock(&self.objects.mutex);
            self.drainMagazines(&self.objects);
            self.decommitIn(&self.objects, now_ms, min_age_ms, budget, &result);
            self.decommitBitmapPages(&self.objects);
        }
        if (self.bytes.lo != self.bytes.hi) {
            std.Io.Threaded.mutexLockUncancelable(&self.bytes.mutex);
            defer std.Io.Threaded.mutexUnlock(&self.bytes.mutex);
            self.drainMagazines(&self.bytes);
            self.decommitIn(&self.bytes, now_ms, min_age_ms, budget, &result);
            self.decommitBytesRunsAged(&self.bytes, now_ms, gen_age, budget, &result);
            self.decommitBitmapPages(&self.bytes);
        }
        return result;
    }

    fn decommitIn(self: *Engine, p: *Partition, now_ms: u32, min_age_ms: u32, budget: usize, result: *DecommitResult) void {
        if (p.stats.spans_empty == 0) return;
        var reset_budget = false;
        for (self.buckets(p.id)) |*b| {
            const age_limit: u32 = if (usesAdaptiveRetention(p.id, b)) @min(min_age_ms, general_decommit_age_ms) else min_age_ms;
            var id = b.hints[@backingInt(Tier.empty)];
            while (id != no_chunk) : (id = self.chunk(p, id).next) {
                const c = self.chunk(p, id);
                var mask = c.masks[@backingInt(Tier.empty)];
                while (mask != 0) : (mask &= mask - 1) {
                    const index = c.spans[@ctz(mask)];
                    const e = self.entry(index);
                    const age = now_ms -% e.empty_since;
                    if (age < age_limit) {
                        const due = e.empty_since +% age_limit;
                        result.next_due_ms = if (result.next_due_ms) |d| @min(d, due) else due;
                        continue;
                    }
                    if (result.decommitted >= budget) {
                        result.more = true;
                        return;
                    }
                    self.releaseSpan(p, b, index, false);
                    result.decommitted += 1;
                    if (usesAdaptiveRetention(p.id, b) and b.kind == .class) {
                        b.empty_cap = if (b.block_bytes <= cache_max_bytes) empty_class_small_default else empty_class_large_default;
                        reset_budget = true;
                    }
                }
            }
        }
        if (reset_budget and p.empty_class_spans <= empty_class_budget_default) {
            p.empty_class_budget = empty_class_budget_default;
        }
    }

    /// Idle reclaim of `layout.bitmaps` OS pages (M8-2): a 16 KiB bitmap page
    /// on macOS covers 64 spans (4 KiB = 16 spans on Linux). After bursty
    /// workloads (e.g. `streams.html` 10,407 decommitted spans = 3.4 MiB of
    /// zeroed bitmaps), decommit any bitmap page whose spans are ALL inactive
    /// so physical footprint drops immediately; `ensureBitmapCommitted`
    /// recommits on reuse. Caller holds `p.mutex` (or window thread for `node`).
    fn decommitBitmapPages(self: *Engine, p: *Partition) void {
        if (p.lo == p.hi) return;
        const bitmaps_off: usize = @intCast(layout.bitmaps.offset);
        const table_off: usize = @intCast(layout.span_table.offset);
        const map_lo = std.mem.alignBackward(usize, bitmaps_off + (p.lo / span_bytes) * (map_words * 8), self.page);
        if (p.map_hi <= map_lo) return;
        const spans_per_page = self.page / (map_words * 8);
        const max_table_span = if (p.table_hi > table_off) (p.table_hi - table_off) / @sizeOf(SpanEntry) else 0;
        var page_off = map_lo;
        while (page_off < p.map_hi) : (page_off += self.page) {
            const first_span = (page_off - bitmaps_off) / (map_words * 8);
            if (first_span >= max_table_span) break;
            const head = self.entry(first_span);
            if (head.flags & SpanEntry.flag_map_decommitted != 0) continue;
            const end_span = @min(first_span + spans_per_page, max_table_span);
            var any_active = false;
            var sp = first_span;
            while (sp < end_span) : (sp += 1) {
                const e = self.entry(sp);
                // `bytes_large_bucket` (19) is a coalescing-run sentinel ONLY
                // inside `.bytes`; in `.objects` and `.node` bucket 19 is a
                // regular active 320 B State bucket (e.g. HTMLFormElement).
                if (e.state == .active and e.bucket != huge_bucket and !(p.id == .bytes and e.bucket == bytes_large_bucket)) {
                    any_active = true;
                    break;
                }
            }
            if (!any_active) {
                self.heap.decommit(page_off, self.page) catch continue;
                head.flags |= SpanEntry.flag_map_decommitted;
                p.stats.bitmap_pages_decommitted += 1;
            }
        }
    }

    /// Memory pressure (design 5.4): purge the quarantine and decommit every
    /// empty span. From the window agent's thread.
    pub fn relievePressure(self: *Engine) usize {
        self.purge();
        var total: usize = 0;
        while (true) {
            const r = self.decommitAged(self.now_ms.load(.monotonic), 0, std.math.maxInt(usize));
            total += r.decommitted;
            if (!r.more) return total;
        }
    }

    fn raisePressure(self: *Engine, p: *Partition) void {
        p.stats.pressure_raised = true;
        if (self.pressure_hook) |hook| hook.call(hook.context, p.id);
    }

    /// A test's cap on a partition's address space (A12: pressure at 90% of
    /// a small cage without filling 4 GiB).
    pub fn limitForTest(self: *Engine, pid: PartitionId, bytes: usize) void {
        const p = self.partition(pid);
        p.limit = @min(p.hi, p.lo + bytes);
    }

    // ------------------------------------------------------------------
    // Reading the heap
    // ------------------------------------------------------------------

    /// The heap's figures. The live and total counts are summed from the
    /// buckets and the quarantined ones counted from the quarantine, here:
    /// an allocation and a free touch only their bucket's line.
    pub fn stats(self: *Engine) Stats {
        // The objects lock, then the bytes lock: the one order both are
        // ever taken together in.
        std.Io.Threaded.mutexLockUncancelable(&self.objects.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.objects.mutex);
        std.Io.Threaded.mutexLockUncancelable(&self.bytes.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.bytes.mutex);
        var s: Stats = .{
            .node = self.node.stats,
            .satellite = self.satellite.stats,
            .objects = self.objects.stats,
            .bytes = self.bytes.stats,
            .quarantine_blocks = self.quarantine.count,
            .quarantine_bytes = self.quarantine.held_bytes,
            .quarantine_external_bytes = if (self.quarantine.using_external) self.quarantine.committed * @sizeOf(usize) else 0,
            .quarantine_total_held = self.quarantine.total_held,
            .quarantine_total_evicted = self.quarantine.total_evicted,
        };
        sumBuckets(&s.node, &self.node_buckets);
        sumBuckets(&s.satellite, &self.satellite_buckets);
        sumBuckets(&s.objects, self.objects_buckets[0..general_objects_base]);
        sumBuckets(&s.general_objects, self.objects_buckets[general_objects_base..]);
        sumBuckets(&s.bytes, &self.bytes_buckets);
        // `bytes` coalescing large runs (M8-3) track their live bytes on the partition.
        s.bytes.live_bytes += self.bytes.bytes_large_live_bytes;
        // Huge blocks are counted in their partition's live figures.
        s.satellite.live_blocks += s.satellite.huge_blocks;
        s.satellite.live_bytes += s.satellite.huge_bytes;
        s.general_objects.live_blocks += s.objects.huge_blocks;
        s.general_objects.live_bytes += s.objects.huge_bytes;
        s.bytes.live_blocks += s.bytes.huge_blocks;
        s.bytes.live_bytes += s.bytes.huge_bytes;
        // What the agents' caches (and window-thread cached-class quarantine)
        // hold is counted live in its bucket and is no one's (the objects lock,
        // held, guards the cache list).
        var at = self.caches;
        while (at) |cache| : (at = cache.next) {
            s.general_objects.live_blocks -|= cache.held[0].load(.monotonic);
            s.general_objects.live_bytes -|= cache.held_bytes[0].load(.monotonic);
            s.bytes.live_blocks -|= cache.held[1].load(.monotonic);
            s.bytes.live_bytes -|= cache.held_bytes[1].load(.monotonic);
        }
        const entries = self.quarantineEntries();
        for (entries[0..self.quarantine.count]) |raw| {
            const address = raw & ~quarantine_tag_mask;
            const offset = address - self.heap.window_base;
            const pid = self.partitionOfOffset(offset).?;
            const ps = switch (pid) {
                .node => &s.node,
                .satellite => &s.satellite,
                .objects => &s.objects,
                .bytes => &s.bytes,
            };
            ps.quarantined_blocks += 1;
            ps.quarantined_bytes += self.buckets(pid)[self.entry(offset / span_bytes).bucket].block_bytes;
        }
        return s;
    }

    fn sumBuckets(ps: *PartitionStats, bs: []const Bucket) void {
        for (bs) |*b| {
            ps.live_blocks += b.live;
            ps.live_bytes += @as(usize, b.live) * b.block_bytes;
            ps.requested_bytes += b.requested;
            ps.total_allocations += b.issued;
            ps.total_requested_bytes += b.requested_total;
            ps.total_reissued += b.issued - b.fresh;
        }
    }

    /// The address space a bucket's spans take (A12: per class).
    pub fn bucketSpans(self: *Engine, target: Target, size: usize, alignment: usize) usize {
        const class = classes.classOf(size, alignment) orelse return 0;
        return switch (target) {
            .node => |kind| total: {
                var spans: usize = 0;
                for (0..random_buckets) |k| spans += self.node_buckets[nodeBucket(kind, k, class)].spans;
                break :total spans;
            },
            .objects => self.objects_buckets[class].spans,
        };
    }

    /// The partition a block is in (a test's question).
    pub fn partitionOf(self: *Engine, ptr: *const anyopaque) ?PartitionId {
        const offset = self.offsetOf(@intFromPtr(ptr)) orelse return null;
        return self.partitionOfOffset(offset);
    }

    /// The node kind of the span a node block is in.
    pub fn nodeKindOf(self: *Engine, ptr: *const anyopaque) ?NodeKind {
        const offset = self.offsetOf(@intFromPtr(ptr)) orelse return null;
        if (self.partitionOfOffset(offset) != .node) return null;
        const e = self.entry(offset / span_bytes);
        if (self.node_buckets[e.bucket].kind != .class) return null;
        return @fromBackingInt(@intCast(e.bucket / Classes.count / random_buckets));
    }

    /// Every Instance slot allocated now, span by span, lowest first. Only
    /// where no other thread makes or frees objects meanwhile (SlabAllocator.
    /// forEachLive): no lock is held, so the caller may free the slot it was
    /// given, but must make none - a slot issued during the walk may or may
    /// not be visited.
    pub const InstanceSlots = struct {
        engine: *Engine,
        chunk_id: u32,
        at: u32 = 0,
        slot: usize = 0,

        pub fn next(it: *InstanceSlots) ?*[instance_slot_bytes]u8 {
            const e = it.engine;
            const p = &e.objects;
            while (it.chunk_id != no_chunk) {
                const c = e.chunk(p, it.chunk_id);
                while (it.at < c.count) {
                    const index = c.spans[it.at];
                    const span = e.entry(index);
                    if (span.state == .active and span.used != 0) {
                        const map = e.slotMap(index);
                        while (it.slot < span.slots) {
                            const slot = it.slot;
                            it.slot += 1;
                            if (slotGet(map, slot) == .allocated) return @ptrFromInt(e.spanAddress(index) + slot * instance_slot_bytes);
                        }
                    }
                    it.at += 1;
                    it.slot = 0;
                }
                it.chunk_id = c.next;
                it.at = 0;
            }
            return null;
        }
    };

    pub fn instanceSlots(self: *Engine) InstanceSlots {
        return .{ .engine = self, .chunk_id = self.objects_buckets[instance_bucket].first };
    }

    /// The leak report: every block alive now, by bucket - and by site,
    /// where the heap records sites. `report(context, line)` for each.
    pub fn leakReport(self: *Engine, context: anytype, comptime report: fn (@TypeOf(context), LeakLine) void) usize {
        var total: usize = 0;
        inline for (.{ PartitionId.node, PartitionId.satellite, PartitionId.objects, PartitionId.bytes }) |pid| {
            const p = self.partition(pid);
            for (self.buckets(pid)) |*b| {
                if (b.live == 0 or b.kind == .instance) continue;
                total += b.live;
                if (pid == .bytes and b.kind == .large) {
                    report(context, .{ .partition = .bytes, .block_bytes = p.bytes_large_live_bytes / b.live, .count = b.live, .type_name = null, .return_address = 0, .general = true });
                } else {
                    self.reportBucket(p, b, context, report);
                }
            }
            // Huge blocks (batch B): one line per partition, by count.
            if (p.stats.huge_blocks != 0) {
                total += p.stats.huge_blocks;
                report(context, .{ .partition = pid, .block_bytes = p.stats.huge_bytes / p.stats.huge_blocks, .count = p.stats.huge_blocks, .type_name = null, .return_address = 0, .general = pid != .satellite });
            }
        }
        return total;
    }

    fn reportBucket(self: *Engine, p: *const Partition, b: *Bucket, context: anytype, comptime report: fn (@TypeOf(context), LeakLine) void) void {
        const general_memory = isGeneralBucket(p.id, (@intFromPtr(b) - @intFromPtr(self.buckets(p.id).ptr)) / @sizeOf(Bucket));
        // Group by site: a few distinct ones per bucket at most.
        var sites: [16]usize = undefined;
        var counts: [16]usize = undefined;
        var n: usize = 0;
        var unsited: usize = 0;
        var id = b.first;
        while (id != no_chunk) : (id = self.chunk(p, id).next) {
            const c = self.chunk(p, id);
            for (c.spans[0..c.count]) |index| {
                const e = self.entry(index);
                if (e.state != .active) continue;
                const map = self.slotMap(index);
                for (0..e.slots) |slot| {
                    if (slotGet(map, slot) != .allocated) continue;
                    if (e.sites == 0) {
                        unsited += 1;
                        continue;
                    }
                    const site_array: [*]const usize = @ptrFromInt(self.heap.window_base + self.meta_pool_base + (@as(usize, e.sites) - 1) * @sizeOf(Chunk));
                    const site = site_array[slot];
                    const found: ?usize = for (sites[0..n], 0..) |s, k| {
                        if (s == site) break k;
                    } else null;
                    if (found) |k| {
                        counts[k] += 1;
                    } else if (n == sites.len) {
                        unsited += 1;
                    } else {
                        sites[n] = site;
                        counts[n] = 1;
                        n += 1;
                    }
                }
            }
        }
        for (sites[0..n], counts[0..n]) |site, count| {
            const typed = site & site_return_tag == 0;
            report(context, .{
                .partition = p.id,
                .block_bytes = b.block_bytes,
                .count = count,
                .type_name = if (typed) @as(*const Site, @ptrFromInt(site)).name else null,
                .return_address = if (typed) 0 else site & ~(site_return_tag | site_general_tag),
                .general = general_memory,
            });
        }
        if (unsited > 0) report(context, .{ .partition = p.id, .block_bytes = b.block_bytes, .count = unsited, .type_name = null, .return_address = 0, .general = general_memory });
    }

    /// Instance slots issued over the heap's life, and alive now.
    pub fn instanceCounts(self: *Engine) struct { issued: usize, live: usize, peak: usize, capacity: usize } {
        std.Io.Threaded.mutexLockUncancelable(&self.objects.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.objects.mutex);
        const b = &self.objects_buckets[instance_bucket];
        return .{ .issued = b.issued, .live = b.live, .peak = b.live_peak, .capacity = @as(usize, b.spans) * b.slots };
    }

    /// A test's choice of configuration, before the heap issues anything.
    pub fn configureForTest(self: *Engine, config: Config) void {
        const issued = issued: {
            var n: usize = 0;
            for (&self.node_buckets) |*b| n += b.issued;
            for (&self.satellite_buckets) |*b| n += b.issued;
            for (&self.objects_buckets) |*b| n += b.issued;
            break :issued n;
        };
        if (issued != 0)
            @panic("heap.Engine.configureForTest: the heap has issued blocks already");
        self.config = config;
    }
};

test {
    _ = classes;
}
