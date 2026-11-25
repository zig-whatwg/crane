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
const browser_heap = @import("../browser_heap.zig");
pub const classes = @import("classes.zig");
/// The general allocator over the objects and bytes partitions (batch B).
pub const general = @import("general.zig");

const BrowserHeap = browser_heap.BrowserHeap;
const Classes = classes.Classes;
/// The classes general blocks take (batch B, M6): PartitionAlloc's quarters
/// scheme - 16-byte steps to 128 B, then four per doubling to 16 KiB, 36
/// classes (allocator-hardening design 3.3 & 6.3) - half the classes of
/// eighths (72), halving partly filled spans committed per Browser.
pub const GeneralClasses = classes.SizeClasses(.quarters);

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

/// Fast general class lookup from `std.mem.Alignment` (batch B, M4): 99%+ of
/// calls have `alignment <= 16` (`align_log2 <= 4`) and 70-92% have
/// `size <= 128`, avoiding `toByteUnits()`, `alignForward` and runtime modulo.
inline fn generalClassOfAlign(size: usize, alignment: std.mem.Alignment) ?usize {
    if (@backingInt(alignment) <= 4) {
        if (size <= 128) return if (size == 0) 0 else (size - 1) >> 4;
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

/// How long an emptied span stays committed before an idle loop decommits
/// it (design 5.1: libpas's 1.5 s on Mac, 750 ms elsewhere; 1 s here).
pub const decommit_age_ms: u32 = 1000;

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
            .wrong_thread => "a node block made or freed off the window agent's thread",
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

/// The partitions of a Browser's heap. `bytes` (allocator-hardening batch B):
/// the page's bytes, made through the general allocator (heap.general) -
/// its own range, its own buckets, validated frees, no quarantine and no
/// zeroing (design 1.2, 3.1).
pub const PartitionId = enum(u2) { node = 0, objects = 1, bytes = 2 };

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
};

/// A span's entry in the span table (one per `span_bytes` of the window's
/// lower half, in the metadata window).
pub const SpanEntry = extern struct {
    /// Its bucket, in its partition; `no_bucket` while unopened.
    bucket: u16,
    state: SpanState,
    _pad0: u8 = 0,
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
    /// Its sites array in its partition's pool (offset / 256 + 1), or 0.
    sites: u32,

    const no_bucket: u16 = std.math.maxInt(u16);
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

/// Buckets: node = 3 kinds x K x classes, then the large runs; objects =
/// the State blocks' classes, the Instance slots, the State blocks' large
/// runs, then the GENERAL objects blocks' classes and large runs (batch B:
/// a freed general block never becomes a State block, nor the reverse); bytes
/// = classes, then the large runs.
const node_groups = node_kinds * random_buckets;
const node_bucket_count = node_groups * Classes.count + max_run_spans;
const objects_state_count = Classes.count + 1 + max_run_spans;
const objects_bucket_count = objects_state_count + GeneralClasses.count + max_run_spans;
/// The first general objects bucket (batch B).
const general_objects_base: usize = objects_state_count;

/// The general allocator's bucket of `pid` (objects or bytes) for a block
/// of `class`, or of a large run of `run` spans (`class` null).
fn generalBucket(pid: PartitionId, class: ?usize, run: usize) u16 {
    return switch (pid) {
        .node => unreachable,
        .objects => @intCast(if (class) |c| general_objects_base + c else general_objects_base + GeneralClasses.count + run - 1),
        .bytes => if (class) |c| @intCast(c) else largeBucket(.bytes, run),
    };
}

/// Whether `pid`'s bucket `index` serves general memory (batch B).
fn isGeneralBucket(pid: PartitionId, index: usize) bool {
    return switch (pid) {
        .node => false,
        .objects => index >= general_objects_base,
        .bytes => true,
    };
}
const bytes_bucket_count = GeneralClasses.count + max_run_spans;
const instance_bucket: u16 = Classes.count;

fn nodeBucket(kind: NodeKind, k: usize, class: usize) u16 {
    return @intCast((@as(usize, @backingInt(kind)) * random_buckets + k) * Classes.count + class);
}

fn largeBucket(pid: PartitionId, run: usize) u16 {
    const base: usize = switch (pid) {
        .node => node_groups * Classes.count,
        .objects => Classes.count + 1,
        .bytes => GeneralClasses.count,
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
    /// Metadata committed up to here: span table, slot maps, pool.
    table_hi: usize,
    map_hi: usize,
    pool_base: usize,
    pool_bytes: usize,
    pool_used: usize,
    pool_hi: usize,
    /// The node partition's thread: the first that made a block in it.
    owner: ?std.Thread.Id = null,
    /// The objects and bytes partitions' lock (every agent's thread
    /// allocates there).
    mutex: std.Io.Mutex = .init,
    /// Huge blocks' regions (batch B): a table in the metadata pool, and how
    /// many it holds.
    huge_table: u32 = no_chunk,
    huge_count: u32 = 0,
    /// Committed bytes of general large runs currently in the empty tier
    /// (maintained by `setTier`, bounded by `empty_large_budget_bytes`: M5).
    empty_large_bytes: usize = 0,
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
/// (2.5-16 KiB) go straight to the shared path so large spans are never
/// pinned `.cached` in a thread cache.
pub const cache_max_bytes: usize = 2048;
const cache_class_count: usize = GeneralClasses.of(cache_max_bytes) + 1;

/// M5 (bounded empty large-run retention): a general large run at or below
/// `large_keep_max_bytes` keeps at most one empty run per bucket while the
/// partition's empty large-run total stays within `empty_large_budget_bytes`;
/// larger runs and anything past the budget decommit immediately at free.
const large_keep_max_bytes: usize = 128 * KiB;
const empty_large_budget_bytes: usize = 256 * KiB;

/// An agent's general-memory cache (design 3.7): per small class (<= 2 KiB)
/// of the objects and bytes partitions, a stack of released blocks' offsets -
/// an array, no link in any block (libpas's thread-local cache,
/// pas_thread_local_cache.h) - which its agent's thread takes from and gives
/// back to without the partition's lock. Its blocks are `.cached` in their
/// slot maps, so a double free of one is caught. Reached through its allocator
/// (heap.general), never a threadlocal; in the objects partition's metadata pool.
pub const AgentCache = struct {
    engine: *Engine,
    /// The agent's thread: the one whose calls take the cache unlocked. 0
    /// once detached.
    owner: std.atomic.Value(std.Thread.Id),
    stacks: [2][cache_class_count]Stack = @splat(@splat(.{})),
    /// Owner-thread shadow of `held`: mutated without atomic RMW and mirrored
    /// to `held` via plain monotonic stores for `Engine.stats()` (M4).
    held_local: [2]usize = .{ 0, 0 },
    /// Blocks the stacks hold now (objects, bytes): out of their spans and
    /// counted live in their buckets, but no one's - the stats subtract them.
    held: [2]std.atomic.Value(usize) = .{ .init(0), .init(0) },
    /// Owner-thread cached partition frontiers (objects, bytes): avoids an
    /// `.acquire` load of `p.frontier` on 99.999% of `cacheFree` calls (M4).
    seen_frontier: [2]usize = .{ 0, 0 },
    next: ?*AgentCache = null,

    pub const Stack = struct {
        count: u16 = 0,
        at: [cache_depth]u32 = undefined,
    };

    /// The agent's general allocator: this cache on its thread, the shared
    /// path elsewhere.
    pub fn allocator(self: *AgentCache) std.mem.Allocator {
        return general.agentAllocator(self);
    }
};

// ============================================================================
// The quarantine
// ============================================================================

const Quarantine = struct {
    /// Whether frees on `thread` are held now: while the window agent's
    /// event loop runs a turn (`beginTask` .. `endTask`). Read by every
    /// thread that frees an objects block.
    active: std.atomic.Value(bool) = .init(false),
    /// The window agent's thread; read by every thread that frees.
    thread: std.atomic.Value(std.Thread.Id) = .init(0),
    count: usize = 0,
    held_bytes: usize = 0,
    /// Entries committed so far.
    committed: usize = 0,
    /// Over the heap's life: blocks held, and of those evicted early.
    total_held: usize = 0,
    total_evicted: usize = 0,
    /// The next eviction's entry, drawn by the hold before, and the address
    /// it held then (`Engine.hold`).
    next_slot: usize = std.math.maxInt(usize),
    next_entry: usize = 0,
};

// ============================================================================
// The engine
// ============================================================================

pub const Error = error{OutOfMemory};

pub const Stats = struct {
    node: PartitionStats,
    /// The objects partition: its span figures, and its State blocks' and
    /// Instance slots' live and total figures.
    objects: PartitionStats,
    /// The objects partition's general blocks (batch B): live and total
    /// figures only - their spans are counted in `objects`.
    general_objects: PartitionStats = .{},
    bytes: PartitionStats,
    quarantine_blocks: usize,
    quarantine_bytes: usize,
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
    objects: Partition,
    /// The page's bytes (batch B): empty (lo == hi) in a rung without
    /// general pools, where general memory stays on the host's allocator.
    bytes: Partition,
    node_buckets: [node_bucket_count]Bucket,
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
    /// The agents' general-memory caches (batch B): those attached now, and
    /// those detached for reuse. Under the objects partition's lock.
    caches: ?*AgentCache = null,
    free_caches: ?*AgentCache = null,

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

        // The partitions' address space: the cage's usable span for nodes,
        // the objects range for the rest - or, in a rung without one, the
        // cage's upper half (the integrator's ruling, 2026-11-23: one
        // hardened path, the rung logged by Browser.init).
        const cage_lo = heap.cage_lo + super_page;
        const cage_hi = heap.cage_hi - super_page;
        const node_lo = cage_lo;
        var node_hi = cage_hi;
        var objects_lo: usize = @intCast(layout.objects.offset);
        var objects_hi: usize = @intCast(layout.objects.end());
        if (!heap.general_pools or layout.objects.bytes == 0) {
            const mid = cage_lo + std.mem.alignBackward(usize, (cage_hi - cage_lo) / 2, super_page);
            node_hi = mid;
            objects_lo = mid;
            objects_hi = cage_hi;
        }
        const pools: usize = @intCast(layout.meta_pools.offset);
        const pool_bytes: usize = @intCast(layout.meta_pool_bytes);
        // The bytes range, in the full rung only (batch B).
        const bytes_lo: usize = if (heap.general_pools) @intCast(layout.bytes.offset) else 0;
        const bytes_hi: usize = if (heap.general_pools) @intCast(layout.bytes.end()) else 0;

        engine.* = .{
            .heap = heap,
            .config = config,
            .page = page,
            .node = partitionAt(.node, node_lo, node_hi, pools, pool_bytes, page),
            .objects = partitionAt(.objects, objects_lo, objects_hi, pools + pool_bytes, pool_bytes, page),
            .bytes = partitionAt(.bytes, bytes_lo, bytes_hi, pools + 2 * pool_bytes, pool_bytes, page),
            .node_buckets = undefined,
            .objects_buckets = undefined,
            .bytes_buckets = undefined,
            .prng = .init(seed),
        };
        engine.bucket_seed = engine.prng.random().int(u64);
        for (&engine.node_buckets, 0..) |*b, i| b.* = bucketShape(.node, i);
        for (&engine.objects_buckets, 0..) |*b, i| b.* = bucketShape(.objects, i);
        for (&engine.bytes_buckets, 0..) |*b, i| b.* = bucketShape(.bytes, i);
        return engine;
    }

    fn partitionAt(id: PartitionId, lo: usize, hi: usize, pool: usize, pool_bytes: usize, page: usize) Partition {
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
            .pool_base = pool,
            .pool_bytes = pool_bytes,
            .pool_used = 0,
            .pool_hi = 0,
        };
    }

    fn bucketShape(pid: PartitionId, index: usize) Bucket {
        // General buckets (the bytes partition's, and the objects
        // partition's past its State buckets): the general classes, then
        // the large runs.
        if (pid == .bytes or (pid == .objects and index >= general_objects_base)) {
            const local = if (pid == .bytes) index else index - general_objects_base;
            if (local < GeneralClasses.count) {
                const bytes = GeneralClasses.bytes(local);
                return .{ .block_bytes = @intCast(bytes), .fill_bytes = @intCast(bytes), .slots = @intCast(span_bytes / bytes), .kind = .class, .general = true };
            }
            const run = local - GeneralClasses.count + 1;
            return .{ .block_bytes = @intCast(run * span_bytes), .fill_bytes = @intCast(run * span_bytes), .slots = 1, .run = @intCast(run), .kind = .large, .general = true };
        }
        const class_end: usize = switch (pid) {
            .node => node_groups * Classes.count,
            .objects, .bytes => Classes.count,
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
            .objects => &self.objects,
            .bytes => &self.bytes,
        };
    }

    inline fn buckets(self: *Engine, pid: PartitionId) []Bucket {
        return switch (pid) {
            .node => &self.node_buckets,
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

    inline fn chunk(self: *Engine, p: *const Partition, id: u32) *Chunk {
        return @ptrFromInt(self.heap.window_base + p.pool_base + @as(usize, id) * @sizeOf(Chunk));
    }

    inline fn spanAddress(self: *Engine, index: usize) usize {
        return self.heap.window_base + index * span_bytes;
    }

    fn partitionOfOffset(self: *Engine, offset: usize) ?PartitionId {
        if (offset >= self.node.lo and offset < self.node.hi) return .node;
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
    inline fn onNodeThread(self: *Engine, address: usize, now: std.Thread.Id) bool {
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

    fn poolAlloc(self: *Engine, p: *Partition, bytes: usize) Error!u32 {
        const at = std.mem.alignForward(usize, p.pool_used, @sizeOf(Chunk));
        if (at + bytes > p.pool_bytes) return error.OutOfMemory;
        const end = p.pool_base + at + bytes;
        if (p.pool_hi == 0) p.pool_hi = p.pool_base;
        try self.commitMeta(&p.pool_hi, end);
        p.pool_used = at + bytes;
        return @intCast(at / @sizeOf(Chunk));
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
            if (std.mem.alignForward(usize, p.pool_used, @sizeOf(Chunk)) + want + reserve <= p.pool_bytes) {
                if (self.poolAlloc(p, want)) |id| {
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
                if (b.general and b.kind == .large) p.empty_large_bytes += b.block_bytes;
            } else {
                b.empty_count -= 1;
                if (b.general and b.kind == .large) p.empty_large_bytes -= b.block_bytes;
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
        self.heap.recommit(index * span_bytes, bytes, was_retired) catch return error.OutOfMemory;
        // A poisoning heap's freed slots read poison, and a span the OS
        // took back reads zero, or (darwin, REUSABLE) its old bytes: start
        // it over as zero.
        if (self.config.fill == .poison) @memset(@as([*]u8, @ptrFromInt(self.spanAddress(index)))[0..bytes], 0);
        e.issued_hi = 0;
        e.hint = 0;
        e.state = .active;
        e.empty_since = self.now_ms.load(.monotonic);
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
                if (!self.onNodeThread(0, std.Thread.getCurrentId())) return error.OutOfMemory;
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
                const thread = std.Thread.getCurrentId();
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
        slotSet(map, slot, .allocated, p.id != .node);
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
        if (self.fills(p)) self.verifyFreed(block[0..checked], fresh);
        if (e.sites != 0) {
            const sites: [*]usize = @ptrFromInt(self.heap.window_base + p.pool_base + (@as(usize, e.sites) - 1) * @sizeOf(Chunk));
            sites[slot] = if (site) |s| @intFromPtr(s) else return_address | site_return_tag;
        }
        return block;
    }

    /// A block about to be issued: still what its free left (zero, or the
    /// poison; zero for a slot never issued), then zeroed.
    /// Whether `p`'s freed blocks are filled (and checked on issue): every
    /// partition's but the bytes', which only a poisoning heap fills.
    inline fn fills(self: *const Engine, p: *const Partition) bool {
        return p.id != .bytes or self.config.fill == .poison;
    }

    fn verifyFreed(self: *Engine, block: []u8, fresh: bool) void {
        const expected: u8 = if (fresh) 0 else self.config.fillByte();
        if (!allBytes(block, expected)) {
            self.violation(.write_after_free, @intFromPtr(block.ptr));
            @memset(block, 0);
            return;
        }
        if (expected != 0) @memset(block, 0);
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
    // General memory (allocator-hardening batch B)
    // ------------------------------------------------------------------

    /// A general block of `size`/`alignment` from `pid` (objects or bytes):
    /// the shared path, under the partition's lock - what heap.general's
    /// allocator takes on a thread that is not its agent's, and what an
    /// agent's cache refills from. An objects block is issued zero, as every
    /// objects block is; a bytes block is not (std's allocator fills it on
    /// issue). Past a large run, a huge block (`allocHuge`).
    pub fn allocGeneral(self: *Engine, pid: PartitionId, size: usize, alignment: usize, return_address: usize) Error![*]u8 {
        std.debug.assert(pid != .node);
        if (alignment > span_bytes) @panic("heap: an alignment past a span");
        const p = self.partition(pid);
        if (p.lo == p.hi) return error.OutOfMemory;
        const bytes = classes.requestBytes(size, alignment);
        std.Io.Threaded.mutexLockUncancelable(&p.mutex);
        defer std.Io.Threaded.mutexUnlock(&p.mutex);
        if (bytes > huge_threshold_bytes) return self.allocHuge(p, bytes);
        const bi = generalBucket(pid, generalClassOf(size, alignment), runOf(bytes));
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
        if (pid == .node) return self.violation(.invalid_free, address);
        const p = self.partition(pid);
        const bytes = classes.requestBytes(size, alignment);
        std.Io.Threaded.mutexLockUncancelable(&p.mutex);
        defer std.Io.Threaded.mutexUnlock(&p.mutex);
        if (offset >= p.frontier) return self.violation(.invalid_free, address);
        const e = self.entry(offset / span_bytes);
        if (e.bucket == huge_bucket and e.state != .run_tail and e.state != .unopened) return self.freeHuge(p, offset, bytes);
        if (bytes > huge_threshold_bytes) return self.violation(if (e.state == .active) .wrong_size else .invalid_free, address);
        const want = generalBucket(pid, generalClassOf(size, alignment), runOf(bytes));
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
            break :made @ptrFromInt(self.heap.window_base + self.objects.pool_base + @as(usize, id) * @sizeOf(Chunk));
        };
        cache.* = .{ .engine = self, .owner = .init(std.Thread.getCurrentId()) };
        cache.next = self.caches;
        self.caches = cache;
        return cache;
    }

    /// The agent ended: every block its cache holds goes back to its span,
    /// and the cache to the engine's reuse list. Its allocator stays valid:
    /// an operation through it after this takes the shared path.
    pub fn detachAgent(self: *Engine, cache: *AgentCache) void {
        self.flushCache(cache);
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
        while (at) |cache| : (at = cache.next) self.flushCache(cache);
    }

    /// The caches whose agent runs on this thread give their blocks back
    /// (idle decommit's first step: a span only a cache keeps open would be
    /// kept committed).
    fn flushCachesOfThisThread(self: *Engine) void {
        const thread = std.Thread.getCurrentId();
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
        for (found[0..n]) |cache| self.flushCache(cache);
    }

    fn flushCache(self: *Engine, cache: *AgentCache) void {
        inline for (.{ PartitionId.objects, PartitionId.bytes }, 0..) |pid, pi| {
            const p = self.partition(pid);
            std.Io.Threaded.mutexLockUncancelable(&p.mutex);
            defer std.Io.Threaded.mutexUnlock(&p.mutex);
            for (&cache.stacks[pi], 0..) |*stack, class| {
                if (stack.count == 0) continue;
                self.giveBack(p, generalBucket(pid, class, 0), stack.at[0..stack.count]);
                stack.count = 0;
            }
            cache.held_local[pi] = 0;
            cache.held[pi].store(0, .monotonic);
        }
    }

    /// Blocks a cache held (`at`: offsets / 16, state `.cached`) back to
    /// their spans. The partition's lock held.
    fn giveBack(self: *Engine, p: *Partition, bi: u16, at: []const u32) void {
        const b = &self.buckets(p.id)[bi];
        const now = self.now_ms.load(.monotonic);
        for (at) |a| {
            const offset = @as(usize, a) * 16;
            const index = offset / span_bytes;
            const slot = (offset - index * span_bytes) / b.block_bytes;
            b.live -= 1;
            self.releaseSlot(p, b, index, slot, now);
        }
    }

    /// A general class block from `cache`, on its agent's thread: the top of
    /// its stack for the class, refilled from the spans under the lock when
    /// empty. Classes past `cache_max_bytes`, large runs and huge blocks take
    /// the shared path.
    pub fn cacheAlloc(self: *Engine, cache: *AgentCache, pid: PartitionId, size: usize, alignment: std.mem.Alignment, return_address: usize) Error![*]u8 {
        const class = generalClassOfAlign(size, alignment) orelse
            return self.allocGeneral(pid, size, alignment.toByteUnits(), return_address);
        if (class >= cache_class_count)
            return self.allocGeneral(pid, size, alignment.toByteUnits(), return_address);
        const pi = cacheIndex(pid);
        const stack = &cache.stacks[pi][class];
        if (stack.count == 0) try self.refill(cache, pid, class);
        stack.count -= 1;
        const offset = @as(usize, stack.at[stack.count]) * 16;
        cache.held_local[pi] -= 1;
        cache.held[pi].store(cache.held_local[pi], .monotonic);
        const index = offset / span_bytes;
        const within = offset & (span_bytes - 1);
        const slot = ((within >> 4) * general_slot_div[class].magic) >> 20;
        if (!slotClaimCached(self.slotMap(index), slot)) @panic("heap: a cached block left its cache's state (allocator-hardening design 3.3)");
        const block: [*]u8 = @ptrFromInt(self.heap.window_base + offset);
        if (pid != .bytes or self.config.fill == .poison) self.verifyFreed(block[0..size], false);
        if (self.config.record_sites) {
            const e = self.entry(index);
            if (e.sites != 0) {
                const p = self.partition(pid);
                const sites: [*]usize = @ptrFromInt(self.heap.window_base + p.pool_base + (@as(usize, e.sites) - 1) * @sizeOf(Chunk));
                sites[slot] = return_address | site_return_tag | site_general_tag;
            }
        }
        return block;
    }

    /// Free a general block through `cache`, on its agent's thread:
    /// validated as `freeGeneral` validates (its partition, a block's start,
    /// its class, allocated - the last in one atomic step), filled, and onto
    /// the cache's stack, half of which goes back to the spans when it is
    /// full. An objects block freed while the window agent runs a task here
    /// goes directly to `freeIn` under the objects lock (no duplicate checks
    /// or `getCurrentId` calls); classes past `cache_max_bytes`, large runs
    /// and huge blocks take the shared path.
    pub fn cacheFree(self: *Engine, cache: *AgentCache, ptr: [*]u8, size: usize, alignment: std.mem.Alignment, thread: std.Thread.Id) void {
        const class = generalClassOfAlign(size, alignment) orelse
            return self.freeGeneral(ptr, size, alignment.toByteUnits());
        if (class >= cache_class_count)
            return self.freeGeneral(ptr, size, alignment.toByteUnits());
        const address = @intFromPtr(ptr);
        const offset = self.offsetOf(address) orelse return self.violation(.other_heap, address);
        // Fast path: check the alignment's expected partition first (one
        // unsigned range test); fall back to full partition lookup on mismatch
        // so cross-partition invalid frees still get exact diagnostics.
        const expected = general.partitionFor(alignment);
        const ep = self.partition(expected);
        const pid: PartitionId = if (offset -% ep.lo < ep.hi - ep.lo)
            expected
        else
            self.partitionOfOffset(offset) orelse return self.violation(.invalid_free, address);
        if (pid == .node) return self.violation(.invalid_free, address);
        const want = generalBucket(pid, class, 0);
        if (pid == .objects and self.holds(thread)) {
            std.Io.Threaded.mutexLockUncancelable(&self.objects.mutex);
            defer std.Io.Threaded.mutexUnlock(&self.objects.mutex);
            self.freeIn(&self.objects, offset, want, false, size, thread);
            return;
        }
        const p = self.partition(pid);
        const pi = cacheIndex(pid);
        if (offset >= cache.seen_frontier[pi]) {
            const f = @atomicLoad(usize, &p.frontier, .acquire);
            cache.seen_frontier[pi] = f;
            if (offset >= f) return self.violation(.invalid_free, address);
        }
        const index = offset / span_bytes;
        const e = self.entry(index);
        if (e.state != .active) {
            return self.violation(if (e.state == .unopened or e.state == .run_tail) .invalid_free else .double_free, address);
        }
        if (e.bucket != want) {
            @branchHint(.cold);
            return self.violation(if (e.bucket >= self.buckets(pid).len or self.buckets(pid)[e.bucket].kind == .instance) .invalid_free else .wrong_size, address);
        }
        const div = general_slot_div[class];
        const within = offset & (span_bytes - 1);
        const slot = ((within >> 4) * div.magic) >> 20;
        if (slot * div.block_bytes != within) return self.violation(.invalid_free, address);
        if (!slotSwap(self.slotMap(index), slot, .allocated, .cached)) return self.violation(.double_free, address);
        if (pid != .bytes or self.config.fill == .poison) @memset(ptr[0..div.block_bytes], self.config.fillByte());
        const stack = &cache.stacks[pi][class];
        if (stack.count == cache_depth) {
            // Full: the older half goes back to its spans.
            const half = cache_depth / 2;
            {
                std.Io.Threaded.mutexLockUncancelable(&p.mutex);
                defer std.Io.Threaded.mutexUnlock(&p.mutex);
                self.giveBack(p, want, stack.at[0..half]);
            }
            std.mem.copyForwards(u32, stack.at[0 .. cache_depth - half], stack.at[half..cache_depth]);
            stack.count = cache_depth - half;
            cache.held_local[pi] -= half;
        }
        stack.at[stack.count] = @intCast(offset / 16);
        stack.count += 1;
        cache.held_local[pi] += 1;
        cache.held[pi].store(cache.held_local[pi], .monotonic);
    }

    /// Fill `cache`'s stack for `class` of `pid` with up to `want` blocks
    /// (at most `cache_depth / 2` and at most ~1 KiB), lowest address first,
    /// under the partition's lock. Past the first block, only already-committed
    /// spans with room are drawn from (`takeSlotExisting`): refill never opens
    /// or recommits an extra span just to top up a cache (M3).
    fn refill(self: *Engine, cache: *AgentCache, pid: PartitionId, class: usize) Error!void {
        const p = self.partition(pid);
        if (p.lo == p.hi) return error.OutOfMemory;
        const bi = generalBucket(pid, class, 0);
        const b = &self.buckets(pid)[bi];
        const pi = cacheIndex(pid);
        const stack = &cache.stacks[pi][class];
        const want: usize = @min(cache_depth / 2, @max(@as(usize, 1), 1024 / general_slot_div[class].block_bytes));
        std.Io.Threaded.mutexLockUncancelable(&p.mutex);
        defer std.Io.Threaded.mutexUnlock(&p.mutex);
        var got: [cache_depth / 2]u32 = undefined;
        const first = try self.takeSlot(p, b, bi);
        got[0] = @intCast(first / 16);
        var n: usize = 1;
        while (n < want) : (n += 1) {
            const offset = self.takeSlotExisting(p, b) orelse break;
            got[n] = @intCast(offset / 16);
        }
        // Lowest address on top: the stack pops from the end.
        for (0..n) |i| stack.at[i] = got[n - 1 - i];
        stack.count = @intCast(n);
        cache.held_local[pi] += n;
        cache.held[pi].store(cache.held_local[pi], .monotonic);
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
            .node => unreachable,
        };
    }

    /// Whether a general block of `old_size` may become `new_size` in place:
    /// the same class (or, huge, the same spans committed). No change is made
    /// to the block's bytes; its request is the caller's.
    pub fn resizesInPlace(self: *Engine, ptr: [*]u8, old_size: usize, new_size: usize, alignment: usize) bool {
        _ = self;
        _ = ptr;
        const old_bytes = classes.requestBytes(old_size, alignment);
        const new_bytes = classes.requestBytes(new_size, alignment);
        if (old_bytes > huge_threshold_bytes or new_bytes > huge_threshold_bytes)
            return old_bytes > huge_threshold_bytes and new_bytes > huge_threshold_bytes and runOf(old_bytes) == runOf(new_bytes);
        const old_class = generalClassOf(old_size, alignment);
        const new_class = generalClassOf(new_size, alignment);
        if (old_class) |o| return if (new_class) |n| o == n else false;
        return new_class == null and runOf(old_bytes) == runOf(new_bytes);
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
            if (self.config.fill == .poison) @memset(@as([*]u8, @ptrFromInt(self.spanAddress(r.first)))[0 .. need * span_bytes], 0);
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
        return @ptrFromInt(self.spanAddress(index));
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

    /// `p`'s huge regions: a table in its metadata pool, made at its first
    /// huge block.
    fn hugeRegions(self: *Engine, p: *Partition) Error![*]HugeRegion {
        if (p.huge_table == no_chunk) p.huge_table = try self.poolAlloc(p, huge_regions_max * @sizeOf(HugeRegion));
        return @ptrFromInt(self.heap.window_base + p.pool_base + @as(usize, p.huge_table) * @sizeOf(Chunk));
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
            // A State block is never the page's bytes.
            .bytes => return self.violation(.invalid_free, address),
        };
        switch (pid) {
            .node => {
                const thread = std.Thread.getCurrentId();
                if (!self.onNodeThread(address, thread)) return;
                self.freeIn(&self.node, offset, want, false, size, thread);
            },
            .objects => {
                std.Io.Threaded.mutexLockUncancelable(&self.objects.mutex);
                defer std.Io.Threaded.mutexUnlock(&self.objects.mutex);
                self.freeIn(&self.objects, offset, want, false, size, null);
            },
            .bytes => unreachable,
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
        const thread = std.Thread.getCurrentId();
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
    fn freeIn(self: *Engine, p: *Partition, offset: usize, want: u16, instance: bool, size: usize, thread: ?std.Thread.Id) void {
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

        const block: [*]u8 = @ptrFromInt(address);
        // The page's bytes are neither zeroed nor held (design 1.2: the
        // bytes partition's traffic is the census's tiny, short-lived
        // strings, and its blocks hold no pointer to stale); a poisoning heap
        // poisons them, to find a read after free.
        if (self.fills(p)) @memset(block[0..b.fill_bytes], self.config.fillByte());
        b.live -= 1;
        b.requested -|= size;

        if (p.id != .bytes and self.holds(thread)) {
            slotSet(map, slot, .quarantined, p.id != .node);
            e.quarantined += 1;
            self.hold(address, b.block_bytes, p.id == .objects);
            return;
        }
        self.release(p, b, index, slot);
    }

    /// Whether a free on this thread now is held: the window agent's loop
    /// runs a task, on this thread.
    inline fn holds(self: *Engine, thread: ?std.Thread.Id) bool {
        if (!self.quarantine.active.load(.monotonic)) return false;
        if (self.config.quarantine_cap == 0) return false;
        return self.quarantine.thread.load(.monotonic) == (thread orelse std.Thread.getCurrentId());
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

    inline fn magazineOf(self: *Engine, p: *const Partition, b: *const Bucket) [*]u32 {
        return @ptrFromInt(self.heap.window_base + p.pool_base + @as(usize, b.mag) * @sizeOf(Chunk));
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
        slotSet(self.slotMap(index), slot, .cached, p.id != .node);
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
        slotSet(map, slot, .allocated, p.id != .node);
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
            const sites: [*]usize = @ptrFromInt(self.heap.window_base + p.pool_base + (@as(usize, e.sites) - 1) * @sizeOf(Chunk));
            sites[slot] = if (site) |s| @intFromPtr(s) else return_address | site_return_tag;
        }
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
        slotSet(self.slotMap(index), slot, .free, p.id != .node);
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
            // M5 (batch B): bounded empty-span retention for general buckets
            // (PartitionAlloc's bounded empty slot-span ring):
            // - class buckets keep at most 1 empty span committed for hot reuse
            //   and decommit additional empty spans immediately at free (fixes
            //   the 35-118 MB bursts held across settles in streams/qSA/observers);
            // - large runs keep 1 empty run only when <= 128 KiB and the
            //   partition's empty large-run total is <= 256 KiB; larger runs
            //   (e.g. 1-2 MiB gzip/br buffers) and excess runs decommit at once.
            if (b.general) {
                const decommit_now = if (b.kind == .large)
                    b.empty_count > 1 or b.block_bytes > large_keep_max_bytes or p.empty_large_bytes > empty_large_budget_bytes
                else
                    b.empty_count > 1;
                if (decommit_now) {
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
        self.quarantine.thread.store(std.Thread.getCurrentId(), .monotonic);
        self.quarantine.active.store(true, .monotonic);
    }

    /// A task (or a teardown slice) ended: everything held is free again
    /// (design 3.5: "when stack memory is likely empty").
    pub fn purge(self: *Engine) void {
        const q = &self.quarantine;
        if (q.count == 0) return;
        const entries = self.quarantineEntries();
        std.Io.Threaded.mutexLockUncancelable(&self.objects.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.objects.mutex);
        for (entries[0..q.count]) |address| _ = self.releaseHeld(address);
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
        for (entries[0..self.quarantine.count]) |address| if (address == @intFromPtr(ptr)) return true;
        return false;
    }

    inline fn quarantineEntries(self: *Engine) [*]usize {
        return @ptrFromInt(self.heap.at(layout.quarantine.offset));
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
    fn hold(self: *Engine, address: usize, bytes: usize, objects_locked: bool) void {
        const q = &self.quarantine;
        const cap = self.config.quarantine_cap;
        if (bytes > cap) {
            _ = self.releaseHeldLocked(address, objects_locked);
            return;
        }
        if (q.count == q.committed) {
            // Commit more of the quarantine's part, doubling; with no room
            // left, the block is free at once.
            const base: usize = @intCast(layout.quarantine.offset);
            const have = q.committed * @sizeOf(usize);
            const room: usize = @intCast(layout.quarantine.bytes);
            const want = @min(room, std.mem.alignForward(usize, @max(have * 2, self.page), self.page));
            if (want <= have) {
                _ = self.releaseHeldLocked(address, objects_locked);
                return;
            }
            self.heap.commit(base + have, want - have) catch {
                _ = self.releaseHeldLocked(address, objects_locked);
                return;
            };
            q.committed = want / @sizeOf(usize);
        }
        const entries = self.quarantineEntries();
        entries[q.count] = address;
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

    /// `releaseHeld`, taking the objects lock for an objects block unless
    /// the caller holds it. Returns the block's bytes.
    fn releaseHeldLocked(self: *Engine, address: usize, objects_locked: bool) usize {
        const offset = address - self.heap.window_base;
        if (self.partitionOfOffset(offset) == .objects and !objects_locked) {
            std.Io.Threaded.mutexLockUncancelable(&self.objects.mutex);
            defer std.Io.Threaded.mutexUnlock(&self.objects.mutex);
            return self.releaseHeld(address);
        }
        return self.releaseHeld(address);
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
        const slot = (offset - index * span_bytes) / b.block_bytes;
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
        // thread's agents give their blocks back first.
        self.flushCachesOfThisThread();
        const on_owner = if (self.node.owner) |owner| owner == std.Thread.getCurrentId() else true;
        if (on_owner) {
            self.drainMagazines(&self.node);
            self.decommitIn(&self.node, now_ms, min_age_ms, budget, &result);
        }
        {
            std.Io.Threaded.mutexLockUncancelable(&self.objects.mutex);
            defer std.Io.Threaded.mutexUnlock(&self.objects.mutex);
            self.drainMagazines(&self.objects);
            self.decommitIn(&self.objects, now_ms, min_age_ms, budget, &result);
        }
        if (self.bytes.lo != self.bytes.hi) {
            std.Io.Threaded.mutexLockUncancelable(&self.bytes.mutex);
            defer std.Io.Threaded.mutexUnlock(&self.bytes.mutex);
            self.drainMagazines(&self.bytes);
            self.decommitIn(&self.bytes, now_ms, min_age_ms, budget, &result);
        }
        return result;
    }

    fn decommitIn(self: *Engine, p: *Partition, now_ms: u32, min_age_ms: u32, budget: usize, result: *DecommitResult) void {
        if (p.stats.spans_empty == 0) return;
        for (self.buckets(p.id)) |*b| {
            var id = b.hints[@backingInt(Tier.empty)];
            while (id != no_chunk) : (id = self.chunk(p, id).next) {
                const c = self.chunk(p, id);
                var mask = c.masks[@backingInt(Tier.empty)];
                while (mask != 0) : (mask &= mask - 1) {
                    const index = c.spans[@ctz(mask)];
                    const e = self.entry(index);
                    const age = now_ms -% e.empty_since;
                    if (age < min_age_ms) {
                        const due = e.empty_since +% min_age_ms;
                        result.next_due_ms = if (result.next_due_ms) |d| @min(d, due) else due;
                        continue;
                    }
                    if (result.decommitted >= budget) {
                        result.more = true;
                        return;
                    }
                    self.releaseSpan(p, b, index, false);
                    result.decommitted += 1;
                }
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
            .objects = self.objects.stats,
            .bytes = self.bytes.stats,
            .quarantine_blocks = self.quarantine.count,
            .quarantine_bytes = self.quarantine.held_bytes,
            .quarantine_total_held = self.quarantine.total_held,
            .quarantine_total_evicted = self.quarantine.total_evicted,
        };
        sumBuckets(&s.node, &self.node_buckets);
        sumBuckets(&s.objects, self.objects_buckets[0..general_objects_base]);
        sumBuckets(&s.general_objects, self.objects_buckets[general_objects_base..]);
        sumBuckets(&s.bytes, &self.bytes_buckets);
        // Huge blocks are general memory's.
        s.general_objects.live_blocks += s.objects.huge_blocks;
        s.general_objects.live_bytes += s.objects.huge_bytes;
        s.bytes.live_blocks += s.bytes.huge_blocks;
        s.bytes.live_bytes += s.bytes.huge_bytes;
        // What the agents' caches hold is counted live in its bucket and is
        // no one's (the objects lock, held, guards the cache list).
        var at = self.caches;
        while (at) |cache| : (at = cache.next) {
            s.general_objects.live_blocks -|= cache.held[0].load(.monotonic);
            s.bytes.live_blocks -|= cache.held[1].load(.monotonic);
        }
        const entries = self.quarantineEntries();
        for (entries[0..self.quarantine.count]) |address| {
            const offset = address - self.heap.window_base;
            const pid = self.partitionOfOffset(offset).?;
            const ps = switch (pid) {
                .node => &s.node,
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
        inline for (.{ PartitionId.node, PartitionId.objects, PartitionId.bytes }) |pid| {
            const p = self.partition(pid);
            for (self.buckets(pid)) |*b| {
                if (b.live == 0 or b.kind == .instance) continue;
                total += b.live;
                self.reportBucket(p, b, context, report);
            }
            // Huge blocks (batch B): one line per partition, by count.
            if (p.stats.huge_blocks != 0) {
                total += p.stats.huge_blocks;
                report(context, .{ .partition = pid, .block_bytes = p.stats.huge_bytes / p.stats.huge_blocks, .count = p.stats.huge_blocks, .type_name = null, .return_address = 0, .general = true });
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
                    const site_array: [*]const usize = @ptrFromInt(self.heap.window_base + p.pool_base + (@as(usize, e.sites) - 1) * @sizeOf(Chunk));
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
