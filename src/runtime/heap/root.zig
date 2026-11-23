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

const BrowserHeap = browser_heap.BrowserHeap;
const Classes = classes.Classes;
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
    /// random. Decision U2 (design 9.1), asked with batch A's numbers: 2 MiB
    /// proposed, Chrome's shipped 512 KiB the floor.
    quarantine_cap: usize,
    /// Make a State span that has emptied inaccessible (discard, then
    /// PROT_NONE: lesson architecture-macos-recommit-needs-madv-free-reuse),
    /// up to `retired_spans_max` at once (Linux's vm.max_map_count). Never
    /// an Instance-slot span: reading a freed slot's generation is a legal
    /// read (SlabAllocator.generationOf).
    retire_freed_spans: bool,
    /// Keep an allocation site per block for the leak report.
    record_sites: bool,

    pub const production_quarantine_cap: usize = 2 * MiB;
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

pub const PartitionId = enum(u1) { node = 0, objects = 1 };

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
    /// The engine's clock when it last emptied.
    empty_since: u32,
    /// Its sites array in its partition's pool (offset / 256 + 1), or 0.
    sites: u32,

    const no_bucket: u16 = std.math.maxInt(u16);
};

comptime {
    if (@sizeOf(SpanEntry) != browser_heap.span_entry_bytes) @compileError("a span entry is span_entry_bytes");
    if (map_words * 8 != browser_heap.slot_map_bytes) @compileError("a slot map is slot_map_bytes");
}

const SlotState = enum(u2) { free = 0, allocated = 1, quarantined = 2 };

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
    /// Blocks allocated (not quarantined) now, and issued over the heap's
    /// life.
    live: u32 = 0,
    issued: usize = 0,
};

/// The random buckets per (size class, node kind) (design 3.2 step 5,
/// WebKit's TZone, f3f8a5374a00): each node interface goes to one of K, by a
/// per-Browser random assignment, so a stale pointer to one interface meets
/// another interface of its class and kind only if the two drew the same
/// bucket. K = 1 ships (the integrator's call 4, 2026-11-23) unless batch
/// A's measurement of 2 and 4 is within the bar; a variant is this constant.
pub const random_buckets: usize = 1;

/// Buckets: node = 3 kinds x K x classes, then the large runs; objects =
/// classes, the Instance slots, then the large runs.
const node_groups = node_kinds * random_buckets;
const node_bucket_count = node_groups * Classes.count + max_run_spans;
const objects_bucket_count = Classes.count + 1 + max_run_spans;
const instance_bucket: u16 = Classes.count;

fn nodeBucket(kind: NodeKind, k: usize, class: usize) u16 {
    return @intCast((@as(usize, @backingInt(kind)) * random_buckets + k) * Classes.count + class);
}

fn largeBucket(pid: PartitionId, run: usize) u16 {
    const base: usize = switch (pid) {
        .node => node_groups * Classes.count,
        .objects => Classes.count + 1,
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
    /// The objects partition's lock (every agent's thread allocates there).
    mutex: std.Io.Mutex = .init,
    stats: PartitionStats = .{},
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
};

// ============================================================================
// The engine
// ============================================================================

pub const Error = error{OutOfMemory};

pub const Stats = struct {
    node: PartitionStats,
    objects: PartitionStats,
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

pub const Engine = struct {
    magic: u64 = magic_value,
    heap: *BrowserHeap,
    config: Config,
    checks: Checks = .panic,
    last_violation: ?Violation = null,
    page: usize,
    node: Partition,
    objects: Partition,
    node_buckets: [node_bucket_count]Bucket,
    objects_buckets: [objects_bucket_count]Bucket,
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

        engine.* = .{
            .heap = heap,
            .config = config,
            .page = page,
            .node = partitionAt(.node, node_lo, node_hi, pools, pool_bytes, page),
            .objects = partitionAt(.objects, objects_lo, objects_hi, pools + pool_bytes, pool_bytes, page),
            .node_buckets = undefined,
            .objects_buckets = undefined,
            .prng = .init(seed),
        };
        engine.bucket_seed = engine.prng.random().int(u64);
        for (&engine.node_buckets, 0..) |*b, i| b.* = bucketShape(.node, i);
        for (&engine.objects_buckets, 0..) |*b, i| b.* = bucketShape(.objects, i);
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
        const class_end: usize = switch (pid) {
            .node => node_groups * Classes.count,
            .objects => Classes.count,
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
        };
    }

    inline fn buckets(self: *Engine, pid: PartitionId) []Bucket {
        return switch (pid) {
            .node => &self.node_buckets,
            .objects => &self.objects_buckets,
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
        return null;
    }

    inline fn slotGet(map: *const [map_words]u64, slot: usize) SlotState {
        return @fromBackingInt(@intCast(@as(u2, @truncate(map[slot / 32] >> @intCast((slot % 32) * 2)))));
    }

    inline fn slotSet(map: *[map_words]u64, slot: usize, state: SlotState) void {
        const shift: u6 = @intCast((slot % 32) * 2);
        map[slot / 32] = (map[slot / 32] & ~(@as(u64, 3) << shift)) | (@as(u64, @backingInt(state)) << shift);
    }

    /// The lowest free slot at or above `from`, below `slots`.
    fn findFree(map: *const [map_words]u64, from: usize, slots: usize) ?usize {
        var w = from / 32;
        const last = (slots + 31) / 32;
        while (w < last) : (w += 1) {
            const word = map[w];
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

        p.frontier = end;
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

    fn setTier(self: *Engine, p: *const Partition, b: *Bucket, e: *const SpanEntry, tier: Tier, on: bool) void {
        const c = self.chunk(p, e.chunk);
        const bit = @as(u64, 1) << @intCast(e.ordinal);
        const t = @backingInt(tier);
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

    fn allocIn(self: *Engine, p: *Partition, bi: u16, size: usize, site: ?*const Site, return_address: usize) Error![*]u8 {
        const b = &self.buckets(p.id)[bi];
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
        slotSet(map, slot, .allocated);
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
        if (fresh) e.issued_hi = @intCast(slot + 1);
        b.live += 1;
        b.issued += 1;
        p.stats.live_blocks += 1;
        p.stats.live_bytes += b.block_bytes;
        p.stats.requested_bytes += size;
        p.stats.total_allocations += 1;
        p.stats.total_requested_bytes += size;
        if (!fresh) p.stats.total_reissued += 1;

        const address = self.spanAddress(index) + slot * b.block_bytes;
        const block: [*]u8 = @ptrFromInt(address);
        const checked = if (b.kind == .instance) instance_fill_bytes else size;
        self.verifyFreed(block[0..checked], fresh);
        if (e.sites != 0) {
            const sites: [*]usize = @ptrFromInt(self.heap.window_base + p.pool_base + (@as(usize, e.sites) - 1) * @sizeOf(Chunk));
            sites[slot] = if (site) |s| @intFromPtr(s) else return_address | site_return_tag;
        }
        return block;
    }

    /// A block about to be issued: still what its free left (zero, or the
    /// poison; zero for a slot never issued), then zeroed.
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

    fn offsetOf(self: *Engine, address: usize) ?usize {
        const base = self.heap.reserved.base;
        if (address < base or address - base >= self.heap.reserved.size) return null;
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
        @memset(block[0..b.fill_bytes], self.config.fillByte());
        b.live -= 1;
        p.stats.live_blocks -= 1;
        p.stats.live_bytes -= b.block_bytes;
        p.stats.requested_bytes -|= size;

        if (self.holds(thread)) {
            slotSet(map, slot, .quarantined);
            e.quarantined += 1;
            p.stats.quarantined_blocks += 1;
            p.stats.quarantined_bytes += b.block_bytes;
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

    /// The slot is free again: its span may have room, or be empty.
    fn release(self: *Engine, p: *Partition, b: *Bucket, index: usize, slot: usize) void {
        const e = self.entry(index);
        slotSet(self.slotMap(index), slot, .free);
        if (slot < e.hint) e.hint = @intCast(slot);
        const was_full = e.used == e.slots;
        e.used -= 1;
        if (was_full) {
            self.setTier(p, b, e, .room, true);
            if (b.current == no_span or index < b.current) b.current = @intCast(index);
        }
        if (e.used == 0) {
            e.empty_since = self.now_ms.load(.monotonic);
            self.setTier(p, b, e, .empty, true);
            p.stats.spans_empty += 1;
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
        for (entries[0..q.count]) |address| self.releaseHeld(address);
        q.count = 0;
        q.held_bytes = 0;
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

    /// Hold a freed block; past the cap, evict one at random (Chrome's
    /// "swap it with a randomly chosen slot so that the quarantine list
    /// remains shuffled", scheduler_loop_quarantine.cc:462-518). The objects
    /// lock is held when `objects_locked`.
    fn hold(self: *Engine, address: usize, bytes: usize, objects_locked: bool) void {
        const q = &self.quarantine;
        if (q.count == q.committed) {
            // Commit more of the quarantine's part, doubling; with no room
            // left, the block is free at once.
            const base: usize = @intCast(layout.quarantine.offset);
            const have = q.committed * @sizeOf(usize);
            const room: usize = @intCast(layout.quarantine.bytes);
            const want = @min(room, std.mem.alignForward(usize, @max(have * 2, self.page), self.page));
            if (want <= have) return self.releaseHeldLocked(address, objects_locked);
            self.heap.commit(base + have, want - have) catch return self.releaseHeldLocked(address, objects_locked);
            q.committed = want / @sizeOf(usize);
        }
        const entries = self.quarantineEntries();
        entries[q.count] = address;
        q.count += 1;
        q.held_bytes += bytes;
        q.total_held += 1;
        while (q.held_bytes > self.config.quarantine_cap and q.count > 0) {
            const j = self.prng.random().uintLessThan(usize, q.count);
            const evicted = entries[j];
            entries[j] = entries[q.count - 1];
            q.count -= 1;
            q.total_evicted += 1;
            self.releaseHeldLocked(evicted, objects_locked);
        }
    }

    fn releaseHeldLocked(self: *Engine, address: usize, objects_locked: bool) void {
        const offset = address - self.heap.window_base;
        if (self.partitionOfOffset(offset) == .objects and !objects_locked) {
            std.Io.Threaded.mutexLockUncancelable(&self.objects.mutex);
            defer std.Io.Threaded.mutexUnlock(&self.objects.mutex);
            return self.releaseHeld(address);
        }
        self.releaseHeld(address);
    }

    /// A held block leaves the quarantine (the objects lock held, or the
    /// block is the node partition's).
    fn releaseHeld(self: *Engine, address: usize) void {
        const offset = address - self.heap.window_base;
        const pid = self.partitionOfOffset(offset).?;
        const p = self.partition(pid);
        const index = offset / span_bytes;
        const e = self.entry(index);
        const b = &self.buckets(pid)[e.bucket];
        const slot = (offset - index * span_bytes) / b.block_bytes;
        std.debug.assert(slotGet(self.slotMap(index), slot) == .quarantined);
        e.quarantined -= 1;
        self.quarantine.held_bytes -|= b.block_bytes;
        p.stats.quarantined_blocks -= 1;
        p.stats.quarantined_bytes -= b.block_bytes;
        self.release(p, b, index, slot);
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
        const on_owner = if (self.node.owner) |owner| owner == std.Thread.getCurrentId() else true;
        if (on_owner) self.decommitIn(&self.node, now_ms, min_age_ms, budget, &result);
        std.Io.Threaded.mutexLockUncancelable(&self.objects.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.objects.mutex);
        self.decommitIn(&self.objects, now_ms, min_age_ms, budget, &result);
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

    pub fn stats(self: *Engine) Stats {
        std.Io.Threaded.mutexLockUncancelable(&self.objects.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.objects.mutex);
        return .{
            .node = self.node.stats,
            .objects = self.objects.stats,
            .quarantine_blocks = self.quarantine.count,
            .quarantine_bytes = self.quarantine.held_bytes,
            .quarantine_total_held = self.quarantine.total_held,
            .quarantine_total_evicted = self.quarantine.total_evicted,
        };
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
        inline for (.{ PartitionId.node, PartitionId.objects }) |pid| {
            const p = self.partition(pid);
            for (self.buckets(pid)) |*b| {
                if (b.live == 0 or b.kind == .instance) continue;
                total += b.live;
                self.reportBucket(p, b, context, report);
            }
        }
        return total;
    }

    fn reportBucket(self: *Engine, p: *const Partition, b: *Bucket, context: anytype, comptime report: fn (@TypeOf(context), LeakLine) void) void {
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
                .return_address = if (typed) 0 else site & ~site_return_tag,
            });
        }
        if (unsited > 0) report(context, .{ .partition = p.id, .block_bytes = b.block_bytes, .count = unsited, .type_name = null, .return_address = 0 });
    }

    /// Instance slots issued over the heap's life, and alive now.
    pub fn instanceCounts(self: *Engine) struct { issued: usize, live: usize, capacity: usize } {
        std.Io.Threaded.mutexLockUncancelable(&self.objects.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.objects.mutex);
        const b = &self.objects_buckets[instance_bucket];
        return .{ .issued = b.issued, .live = b.live, .capacity = @as(usize, b.spans) * b.slots };
    }

    /// A test's choice of configuration, before the heap issues anything.
    pub fn configureForTest(self: *Engine, config: Config) void {
        if (self.node.stats.total_allocations != 0 or self.objects.stats.total_allocations != 0)
            @panic("heap.Engine.configureForTest: the heap has issued blocks already");
        self.config = config;
    }
};

test {
    _ = classes;
}
