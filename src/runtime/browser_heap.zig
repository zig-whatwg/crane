//! A Browser's heap: one reservation of address space per Browser, made in
//! the Browser's start and released at its end, after everything that names
//! it (phase H1 of tmp/redesign/node-memory-architecture.md, as amended by
//! tmp/redesign/node-memory-plan-v2.md, the user's "yes all" of 2026-11-10).
//! Nothing allocates from it yet: H2 moves node blocks into its cage, H3 the
//! Instance header, H4 the tree links, H6 the general pools.
//!
//! The reservation's shape is a PROFILE chosen at comptime per target, so one
//! `Link` and one `BrowserHeap` serve every target (the integrator, 2026-11-10
//! 15:09 UTC):
//!
//! | profile   | targets                                  | reserves                                                    |
//! |-----------|------------------------------------------|-------------------------------------------------------------|
//! | full      | 64-bit desktop and server                | a window of max(64 GiB, 4 x cage) aligned to itself: the    |
//! |           |                                          | node cage, the objects range (metadata in its first guarded |
//! |           |                                          | super page), the bytes range                                |
//! | small     | 64-bit iOS, tvOS, watchOS, visionOS: no  | the cage (1 GiB, fixed per build: no run-time halving,      |
//! |           | extended-virtual-addressing entitlement, | the deep review's Z6) and its metadata, in a 2 GiB window;  |
//! |           | 11.4-15.4 GiB of address space (oss R11) | general memory stays on the system allocator                |
//! | pointer32 | @sizeOf(usize) == 4: watchOS arm64_32,   | nothing: a Link is the plain pointer (the same 4 bytes, no  |
//! |           | wasm32, 32-bit ARM                       | decode); node memory comes from ordinary allocation         |
//!
//! The full layout, offsets from the window's base (cage 4 GiB at shift 0):
//!
//!     [0, 2 MiB)            the cage's first super page: never committed, so
//!                           Link 0 is none and every link below the first
//!                           node super page decodes to an inaccessible page
//!     [2 MiB, 4 GiB-2 MiB)  node super pages (H2)
//!     [4 GiB-2 MiB, 4 GiB)  the cage's top guard: a field read past a
//!                           decoded block cannot leave the cage (Ladybird)
//!     [4 GiB, +2 MiB)       guard super page
//!     [4 GiB+2 MiB, +1 GiB) METADATA, outside the cage where no link decodes
//!                           (oss review R1, PartitionAlloc's out-of-pool
//!                           slot-span metadata, 4c10aff2ca6a): the heap
//!                           header past its first span, the span table, the
//!                           free bitmaps, the Browser's tables at fixed
//!                           offsets (the deep review's Z11)
//!     [.., 32 GiB)          guard super page, then the OBJECTS pool (H6)
//!     [32 GiB, 64 GiB)      the BYTES pool: page-controlled bytes (H6)
//!
//! Every super page's first span stays inaccessible (oss R19): the layout
//! starts nothing there - the header sits one span into its super page.
//!
//! `heapOf(ptr)` finds the header from an address alone: a CONTRACT, not a
//! classifier (arch 6.4; lesson
//! debugging-a-heuristic-over-pointer-ranges-breaks-when-the-allocators-layout-moves.md).
//! It is called only on a pointer the caller knows a Browser heap issued, and
//! nothing ever decides "is this a heap pointer?" from where an address falls.
//!
//! When the full reservation fails (RLIMIT_AS, a 39-bit kernel, a sanitizer's
//! address map: oss R11) a ladder of smaller reservations follows: the cage
//! alone with its metadata, general memory from the host allocator; then
//! smaller cages at the TOP of the cage window, so the window stays aligned
//! and the masks stay comptime; then a clean error. The small profile has one
//! rung; pointer32 reserves nothing.
//!
//! This file imports only std: the platform's address-space operations are
//! passed in (`Platform.of(@import("platform"))`), as V8 takes its pages from
//! the embedder's v8::PageAllocator, so the file compiles alone for any target
//! (the 32-bit check in tests/runtime/h1_heap_32bit_check.zig).

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const KiB: u64 = 1024;
const MiB: u64 = 1024 * KiB;
const GiB: u64 = 1024 * MiB;

// ============================================================================
// Profiles and geometry
// ============================================================================

pub const Profile = enum(u8) {
    /// 64-bit desktop and server: the whole layout.
    full,
    /// 64-bit with a small address space: a fixed cage and its metadata.
    small,
    /// 32-bit pointers: no cage, no reservation.
    pointer32,
};

/// The profile of `target`.
pub fn profileFor(target: std.Target) Profile {
    if (target.ptrBitWidth() <= 32) return .pointer32;
    return switch (target.os.tag) {
        .ios, .tvos, .watchos, .visionos => .small,
        else => .full,
    };
}

/// The node cage's size and shift: ONE comptime pair per profile. A link is
/// the target's offset in the cage shifted right by `cage_shift`, so 32 bits
/// reach `cage_bytes` = 4 GiB << shift. H4 measures 4 GiB at shift 0 against
/// 32 GiB at shift 3 (plan-v2 C2) and sets it; both compile, and the tests
/// pin both layouts.
pub const Geometry = struct {
    profile: Profile,
    cage_bytes: u64,
    cage_shift: u6,
};

pub fn geometryFor(comptime p: Profile) Geometry {
    return switch (p) {
        .full => .{ .profile = .full, .cage_bytes = 4 * GiB, .cage_shift = 0 },
        .small => .{ .profile = .small, .cage_bytes = 1 * GiB, .cage_shift = 0 },
        .pointer32 => .{ .profile = .pointer32, .cage_bytes = 0, .cage_shift = 0 },
    };
}

pub const profile: Profile = profileFor(builtin.target);
pub const geometry: Geometry = geometryFor(profile);

/// The commit unit and the unit of the layout: PartitionAlloc's super page.
pub const super_page_bytes: u64 = 2 * MiB;

/// The first span of every super page stays inaccessible (oss R19): its size
/// is the largest span any build can have, max(16 KiB, the largest page this
/// target may run with - 64 KiB on aarch64-linux, where the page size is a
/// run-time value: the deep review's Z12). H2's spans are max(16 KiB, page).
pub const super_page_guard_bytes: u64 = @max(16 * KiB, std.heap.page_size_max);

/// Where a part of the window is, as offsets from its base.
pub const Part = struct {
    offset: u64,
    bytes: u64,

    pub fn end(part: Part) u64 {
        return part.offset + part.bytes;
    }
};

/// A table of the Browser's kept at a fixed offset of its metadata, reserved
/// in full and committed as it grows, so an entry's address is arithmetic on
/// the holder's address (the deep review's Z11: 2 loads, nothing to reload).
pub const Table = enum(u8) {
    /// Interned names past the static table (nd2's A2, H5's name ids).
    names,
};

pub const Layout = struct {
    geometry: Geometry,
    /// The aligned window every address of one Browser's heap lies in:
    /// heapOf's mask. Zero for pointer32.
    window_bytes: u64,
    /// The node cage, at the window's base.
    cage: Part,
    /// The first offset a node super page may take: the cage's whole first
    /// super page is a guard.
    first_node_offset: u64,
    /// The cage's top guard super page.
    cage_top_guard: Part,
    /// The metadata window: after the objects range's first (guard) super
    /// page, outside [0, cage).
    metadata: Part,
    /// The heap header: one guard span into the metadata window.
    header_offset: u64,
    /// The span table and free bitmaps of the node and satellite pools
    /// (H2), at fixed offsets of the metadata window.
    span_table: Part,
    bitmaps: Part,
    /// The Browser's tables (Table), each `table_bytes`, after the bitmaps.
    tables: Part,
    table_bytes: u64,
    /// The objects pool and the bytes pool; empty in the small profile.
    objects: Part,
    bytes: Part,
    /// The end of what the cage-alone rung reserves: the cage, its
    /// metadata and the guard after it.
    cage_alone_end: u64,
    /// The smallest cage the ladder tries.
    min_cage_bytes: u64,

    pub fn tablePart(layout_: Layout, table: Table) Part {
        return .{ .offset = layout_.tables.offset + @as(u64, @backingInt(table)) * layout_.table_bytes, .bytes = layout_.table_bytes };
    }
};

/// The layout of a geometry. Pinned for both cage geometries by tests.
pub fn layoutFor(comptime g: Geometry) Layout {
    if (g.profile == .pointer32) return .{
        .geometry = g,
        .window_bytes = 0,
        .cage = .{ .offset = 0, .bytes = 0 },
        .first_node_offset = 0,
        .cage_top_guard = .{ .offset = 0, .bytes = 0 },
        .metadata = .{ .offset = 0, .bytes = 0 },
        .header_offset = 0,
        .span_table = .{ .offset = 0, .bytes = 0 },
        .bitmaps = .{ .offset = 0, .bytes = 0 },
        .tables = .{ .offset = 0, .bytes = 0 },
        .table_bytes = 0,
        .objects = .{ .offset = 0, .bytes = 0 },
        .bytes = .{ .offset = 0, .bytes = 0 },
        .cage_alone_end = 0,
        .min_cage_bytes = 0,
    };
    const c = g.cage_bytes;
    if (!std.math.isPowerOfTwo(c) or c < 256 * MiB) @compileError("a node cage is a power of two of at least 256 MiB");
    if ((@as(u64, 1) << 32) << g.cage_shift < c) @compileError("32-bit links shifted by cage_shift must reach the whole cage");
    const window: u64 = switch (g.profile) {
        .full => @max(64 * GiB, 4 * c),
        .small => 2 * c,
        .pointer32 => unreachable,
    };
    // The metadata window: a quarter of the cage on desktop, an eighth in the
    // small profile - address space only; H2 commits what it uses.
    const metadata_bytes = switch (g.profile) {
        .full => c / 4,
        .small => c / 8,
        .pointer32 => unreachable,
    };
    const metadata_offset = c + super_page_bytes;
    // One span-table entry (32 B) per smallest span (16 KiB) of the cage, and
    // one bit per 16-B slot of it.
    const span_table_bytes = std.mem.alignForward(u64, (c / (16 * KiB)) * 32, super_page_bytes);
    const bitmap_bytes = std.mem.alignForward(u64, c / 16 / 8, super_page_bytes);
    const span_table: Part = .{ .offset = metadata_offset + super_page_bytes, .bytes = span_table_bytes };
    const bitmaps: Part = .{ .offset = span_table.end(), .bytes = bitmap_bytes };
    const table_bytes = metadata_bytes / 16;
    const table_count = @typeInfo(Table).@"enum".field_names.len;
    const tables: Part = .{ .offset = bitmaps.end(), .bytes = table_bytes * table_count };
    if (tables.end() > metadata_offset + metadata_bytes) @compileError("the metadata window is too small for its parts");
    const cage_alone_end = metadata_offset + metadata_bytes + super_page_bytes;
    const objects: Part, const bytes: Part = switch (g.profile) {
        .full => .{
            .{ .offset = cage_alone_end, .bytes = window / 2 - cage_alone_end },
            .{ .offset = window / 2 + super_page_bytes, .bytes = window / 2 - super_page_bytes },
        },
        .small => .{ .{ .offset = cage_alone_end, .bytes = 0 }, .{ .offset = cage_alone_end, .bytes = 0 } },
        .pointer32 => unreachable,
    };
    if (cage_alone_end > window / 2 and g.profile == .full) @compileError("the cage and its metadata must fit below the bytes pool");
    if (cage_alone_end > window) @compileError("the cage and its metadata must fit in the window");
    return .{
        .geometry = g,
        .window_bytes = window,
        .cage = .{ .offset = 0, .bytes = c },
        .first_node_offset = super_page_bytes,
        .cage_top_guard = .{ .offset = c - super_page_bytes, .bytes = super_page_bytes },
        .metadata = .{ .offset = metadata_offset, .bytes = metadata_bytes },
        .header_offset = metadata_offset + super_page_guard_bytes,
        .span_table = span_table,
        .bitmaps = bitmaps,
        .tables = tables,
        .table_bytes = table_bytes,
        .objects = objects,
        .bytes = bytes,
        .cage_alone_end = cage_alone_end,
        .min_cage_bytes = switch (g.profile) {
            .full => 256 * MiB,
            // No halving in the small profile (Z6): one cage size per build.
            .small => c,
            .pointer32 => unreachable,
        },
    };
}

pub const layout: Layout = layoutFor(geometry);

/// The top byte of an address may carry a tag (arm64 top-byte-ignore, x86-64
/// LAM): heapOf ignores bits 56-63 (oss R14).
const address_bits_mask: u64 = (@as(u64, 1) << 56) - 1;

// ============================================================================
// Links
// ============================================================================

/// A compressed reference from a block in a Browser's node cage to another
/// block in the same cage (arch 3.3; H4 puts them in node fields). In the
/// full and small profiles: the target's offset in the cage, shifted right by
/// the cage's shift, 0 for none, decoded from the HOLDER's address - every
/// holder is in the cage - so there is no base to store and no global. In
/// pointer32: the plain pointer, the same 4 bytes, no decode.
pub fn Link(comptime T: type) type {
    return LinkIn(geometry, T);
}

pub fn LinkIn(comptime g: Geometry, comptime T: type) type {
    return enum(u32) {
        none = 0,
        _,

        const Self = @This();

        pub const EncodeError = error{
            /// The target is not in the holder's cage.
            OtherCage,
            /// The target's offset is not a multiple of the shift's unit.
            Misaligned,
        };

        /// Whether a link's 32 bits can name more than the cage (a cage
        /// smaller than 4 GiB << shift: the small profile's 1 GiB): then a
        /// decode checks the value, so a forged high link panics instead of
        /// leaving the cage (arch 3.6's checked offset width).
        const checks_bound = switch (g.profile) {
            .pointer32 => false,
            .full, .small => ((@as(u64, 1) << 32) << g.cage_shift) > g.cage_bytes,
        };

        /// The block `link` names, decoded from `holder`'s cage. A link past
        /// the cage (only possible where `checks_bound`) is a production
        /// check: a `@panic` in every build (the deep review's Z3).
        pub inline fn get(link: Self, holder: *const anyopaque) ?*T {
            return decode(link, holder) catch @panic("Link.get: a link past its node cage");
        }

        /// `get`, returning what `get` panics on: the test hook.
        pub inline fn decode(link: Self, holder: *const anyopaque) error{OutsideCage}!?*T {
            if (link == .none) return null;
            switch (g.profile) {
                .pointer32 => return @ptrFromInt(@backingInt(link)),
                .full, .small => {
                    const offset = @as(usize, @backingInt(link)) << g.cage_shift;
                    if (checks_bound and offset >= g.cage_bytes) return error.OutsideCage;
                    const cage = @intFromPtr(holder) & ~@as(usize, g.cage_bytes - 1);
                    return @ptrFromInt(cage | offset);
                },
            }
        }

        /// The link to `target` from `holder`. A target outside the
        /// holder's cage is a production check (the deep review's Z3: a
        /// `@panic`, in every build), never a Debug assert.
        pub inline fn to(target: ?*const T, holder: *const anyopaque) Self {
            return encode(target, holder) catch |err| switch (err) {
                error.OtherCage => @panic("Link.to: the target is not in the holder's node cage"),
                error.Misaligned => @panic("Link.to: the target is not aligned to the cage's shift"),
            };
        }

        /// `to`, returning what `to` panics on: the test hook.
        pub fn encode(target: ?*const T, holder: *const anyopaque) EncodeError!Self {
            const t = target orelse return .none;
            switch (g.profile) {
                .pointer32 => return @fromBackingInt(@as(u32, @intCast(@intFromPtr(t)))),
                .full, .small => {
                    const mask = ~@as(usize, g.cage_bytes - 1);
                    const address = @intFromPtr(t);
                    if (address & mask != @intFromPtr(holder) & mask) return error.OtherCage;
                    const offset = address & ~mask;
                    if (offset & ((@as(usize, 1) << g.cage_shift) - 1) != 0) return error.Misaligned;
                    return @fromBackingInt(@as(u32, @intCast(offset >> g.cage_shift)));
                },
            }
        }

        pub inline fn isNone(link: Self) bool {
            return link == .none;
        }

        /// Whether `link` names `target`, compared on the compressed value -
        /// no decode (oss R20: Oilpan's Member compares compressed).
        pub inline fn eql(link: Self, target: ?*const T, holder: *const anyopaque) bool {
            const encoded = encode(target, holder) catch return false;
            return link == encoded;
        }
    };
}

// ============================================================================
// The platform's address space, passed in
// ============================================================================

/// The heap's view of the platform's address-space types (platform 6.11).
pub const Range = extern struct { base: usize, size: usize };
pub const Label = enum(u8) { node_cage = 0, objects = 1, bytes = 2, heap_metadata = 3 };
pub const Access = enum(u8) { none = 0, read = 1, read_write = 2 };

pub const PageError = error{ OutOfMemory, NotSupported, AccessDenied, Unexpected };

/// The platform's address-space operations and randomness, bound at comptime
/// to a namespace shaped like `@import("platform")` - the protocol module, or
/// a test's fake - and kept as a table of function pointers in read-only
/// memory: the heap header holds a pointer to it, never the functions
/// themselves.
pub const Platform = struct {
    supported: bool,
    page_size: *const fn () usize,
    reserve: *const fn (size: usize, alignment: usize, alignment_offset: usize, label: Label) PageError!Range,
    label: *const fn (range: Range, offset: usize, length: usize, label: Label) void,
    commit: *const fn (range: Range, offset: usize, length: usize) PageError!void,
    decommit: *const fn (range: Range, offset: usize, length: usize) PageError!void,
    protect: *const fn (range: Range, offset: usize, length: usize, access: Access) PageError!void,
    release: *const fn (range: Range) void,
    /// Cryptographic randomness (platform.fillRandom).
    random: *const fn (bytes: []u8) void,
    /// The Browser's own random stream (platform.fillBrowserRandom): true
    /// with `bytes` filled for a Browser that has one.
    browser_random: *const fn (browser: ?*anyopaque, bytes: []u8) bool,

    /// `P`'s operations. Where `P.capabilities.address_space` is
    /// unsupported, a table whose reservation answers NotSupported - and P's
    /// gated operations are never named, so the build still compiles.
    pub fn of(comptime P: type) *const Platform {
        if (P.capabilities.address_space == .unsupported) return &Unsupported(P).table;
        return &Bound(P).table;
    }
};

fn mapError(err: anyerror) PageError {
    return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.NotSupported => error.NotSupported,
        error.AccessDenied => error.AccessDenied,
        else => error.Unexpected,
    };
}

fn Bound(comptime P: type) type {
    comptime {
        for (@typeInfo(Label).@"enum".field_names) |field| {
            if (@backingInt(@field(P.AddressLabel, field)) != @backingInt(@field(Label, field))) @compileError("platform.AddressLabel." ++ field ++ " differs from the heap's");
        }
        for (@typeInfo(Access).@"enum".field_names) |field| {
            if (@backingInt(@field(P.PageAccess, field)) != @backingInt(@field(Access, field))) @compileError("platform.PageAccess." ++ field ++ " differs from the heap's");
        }
    }
    return struct {
        fn pRange(range: Range) P.AddressRange {
            return .{ .base = range.base, .size = range.size };
        }
        fn pageSize() usize {
            return P.pageSize();
        }
        fn reserve(size: usize, alignment: usize, alignment_offset: usize, label: Label) PageError!Range {
            const got = P.reserveAddressSpace(size, alignment, alignment_offset, @fromBackingInt(@backingInt(label))) catch |err| return mapError(err);
            return .{ .base = got.base, .size = got.size };
        }
        fn labelPart(range: Range, offset: usize, length: usize, label: Label) void {
            P.labelAddressSpace(pRange(range), offset, length, @fromBackingInt(@backingInt(label)));
        }
        fn commit(range: Range, offset: usize, length: usize) PageError!void {
            P.commitPages(pRange(range), offset, length) catch |err| return mapError(err);
        }
        fn decommit(range: Range, offset: usize, length: usize) PageError!void {
            P.decommitPages(pRange(range), offset, length) catch |err| return mapError(err);
        }
        fn protect(range: Range, offset: usize, length: usize, access: Access) PageError!void {
            P.protectPages(pRange(range), offset, length, @fromBackingInt(@backingInt(access))) catch |err| return mapError(err);
        }
        fn release(range: Range) void {
            P.releaseAddressSpace(pRange(range));
        }
        fn random(bytes: []u8) void {
            P.fillRandom(bytes);
        }
        fn browserRandom(browser: ?*anyopaque, bytes: []u8) bool {
            const b = browser orelse return false;
            return P.fillBrowserRandom(@ptrCast(b), bytes);
        }
        const table: Platform = .{
            .supported = true,
            .page_size = pageSize,
            .reserve = reserve,
            .label = labelPart,
            .commit = commit,
            .decommit = decommit,
            .protect = protect,
            .release = release,
            .random = random,
            .browser_random = browserRandom,
        };
    };
}

fn Unsupported(comptime P: type) type {
    return struct {
        fn pageSize() usize {
            return std.heap.page_size_min;
        }
        fn reserve(_: usize, _: usize, _: usize, _: Label) PageError!Range {
            return error.NotSupported;
        }
        fn labelPart(_: Range, _: usize, _: usize, _: Label) void {}
        fn pages(_: Range, _: usize, _: usize) PageError!void {
            return error.NotSupported;
        }
        fn protect(_: Range, _: usize, _: usize, _: Access) PageError!void {
            return error.NotSupported;
        }
        fn release(_: Range) void {}
        fn random(bytes: []u8) void {
            P.fillRandom(bytes);
        }
        fn browserRandom(browser: ?*anyopaque, bytes: []u8) bool {
            const b = browser orelse return false;
            return P.fillBrowserRandom(@ptrCast(b), bytes);
        }
        const table: Platform = .{
            .supported = false,
            .page_size = pageSize,
            .reserve = reserve,
            .label = labelPart,
            .commit = pages,
            .decommit = pages,
            .protect = protect,
            .release = release,
            .random = random,
            .browser_random = browserRandom,
        };
    };
}

// ============================================================================
// The heap
// ============================================================================

/// Which reservation the ladder got.
pub const Rung = enum(u8) {
    /// The full layout: cage, metadata, objects and bytes pools.
    full,
    /// The cage and its metadata; general memory from the host allocator.
    cage_alone,
    /// A cage smaller than the geometry's, at the top of the cage window.
    smaller_cage,
    /// pointer32: nothing reserved.
    unreserved,
};

pub const Error = error{
    /// No rung of the ladder could be reserved.
    OutOfMemory,
    /// The platform has no address space to reserve (kit/headless).
    NotSupported,
};

/// The header of a Browser's heap, at `layout.header_offset` of its window
/// (host-allocated in pointer32). An extern struct: heapOf computes its
/// address, so its layout is fixed (the deep review's Z2).
pub const BrowserHeap = extern struct {
    magic: u64 = magic_value,
    /// The scope this heap is the reservation of (`*runtime.BrowserScope`),
    /// written once the scope's address is final.
    owner: ?*anyopaque = null,
    platform: *const Platform,
    /// The aligned window heapOf masks to; 0 in pointer32.
    window_base: usize,
    /// What this rung reserved: a part of the window.
    reserved: Range,
    rung: Rung,
    /// Whether the objects and bytes pools are this heap's (the full rung)
    /// or the host allocator's.
    general_pools: bool,
    /// The cage's usable bounds in this rung, offsets from the window base:
    /// node super pages lie in [cage_lo + first node offset, cage_hi - top
    /// guard). In a smaller-cage rung `cage_lo` is above 0, and a link below
    /// it would decode to address space this heap does not hold: H4's decode
    /// bound-checks against it there (Z6's first option).
    cage_lo: usize,
    cage_hi: usize,
    /// The first generation this Browser's objects are stamped with (oss
    /// R12), from the Browser's own random stream - a released reservation's
    /// address goes to the next one, so generations must not start at 1 in
    /// every Browser.
    generation_seed: u64,
    /// Bytes this heap has committed and not retired (stats; oss R24).
    committed_bytes: usize,

    pub const magic_value: u64 = 0x4352_414e_4548_5031; // "CRANEHP1"

    /// Generation seeds lie in [1, 2^55): a 56-bit generation counter then
    /// has at least 2^55 issues before it wraps (57 years at 50 ns each).
    pub const generation_seed_limit: u64 = 1 << 55;

    /// Reserve a Browser's heap: the ladder's first rung that fits. The
    /// header is committed and written; nothing else is. `browser` is the
    /// Browser's platform state, whose random stream seeds the generations
    /// (null: the OS's entropy). In pointer32 the header comes from
    /// `allocator` and nothing is reserved.
    pub fn reserve(platform: *const Platform, allocator: Allocator, browser: ?*anyopaque) Error!*BrowserHeap {
        const seed = generationSeed(platform, browser);
        switch (profile) {
            .pointer32 => {
                const heap = allocator.create(BrowserHeap) catch return error.OutOfMemory;
                heap.* = .{
                    .platform = platform,
                    .window_base = 0,
                    .reserved = .{ .base = 0, .size = 0 },
                    .rung = .unreserved,
                    .general_pools = false,
                    .cage_lo = 0,
                    .cage_hi = 0,
                    .generation_seed = seed,
                    .committed_bytes = 0,
                };
                return heap;
            },
            .full, .small => {
                if (!platform.supported) return error.NotSupported;
                return reserveIn(layout, platform, seed);
            },
        }
    }

    /// The ladder, over a layout (tests run it over both geometries).
    pub fn reserveIn(comptime l: Layout, platform: *const Platform, seed: u64) Error!*BrowserHeap {
        const steps = comptime ladderOf(l);
        for (steps) |step| {
            const range = platform.reserve(@intCast(step.end - step.start), @intCast(l.window_bytes), @intCast(step.start), .objects) catch |err| switch (err) {
                error.OutOfMemory => continue,
                error.NotSupported => return error.NotSupported,
                else => continue,
            };
            return place(l, platform, range, step, seed) catch {
                platform.release(range);
                continue;
            };
        }
        return error.OutOfMemory;
    }

    const Step = struct { rung: Rung, start: u64, end: u64, cage_lo: u64 };

    fn ladderOf(comptime l: Layout) []const Step {
        if (l.geometry.profile == .pointer32) @compileError("pointer32 reserves nothing");
        var steps: []const Step = &.{};
        if (l.geometry.profile == .full) steps = steps ++ [_]Step{.{ .rung = .full, .start = 0, .end = l.window_bytes, .cage_lo = 0 }};
        steps = steps ++ [_]Step{.{ .rung = .cage_alone, .start = 0, .end = l.cage_alone_end, .cage_lo = 0 }};
        var smaller = l.cage.bytes / 2;
        while (smaller >= l.min_cage_bytes) : (smaller /= 2) {
            const lo = l.cage.bytes - smaller;
            steps = steps ++ [_]Step{.{ .rung = .smaller_cage, .start = lo, .end = l.cage_alone_end, .cage_lo = lo }};
        }
        return steps;
    }

    /// Label the parts, commit and write the header.
    fn place(comptime l: Layout, platform: *const Platform, range: Range, step: Step, seed: u64) PageError!*BrowserHeap {
        const window_base = range.base - @as(usize, @intCast(step.start));
        // The cage and the metadata, then the bytes pool in the full rung;
        // the rest keeps the reservation's own label, objects.
        platform.label(range, 0, @intCast(l.cage.end() - step.start), .node_cage);
        platform.label(range, @intCast(l.metadata.offset - step.start), @intCast(l.metadata.bytes), .heap_metadata);
        if (step.rung == .full) platform.label(range, @intCast(l.bytes.offset - super_page_bytes), @intCast(l.bytes.bytes + super_page_bytes), .bytes);
        const page = platform.page_size();
        const header_bytes = std.mem.alignForward(usize, @sizeOf(BrowserHeap), page);
        const header_in_range: usize = @intCast(l.header_offset - step.start);
        try platform.commit(range, header_in_range, header_bytes);
        const heap: *BrowserHeap = @ptrFromInt(window_base + @as(usize, @intCast(l.header_offset)));
        heap.* = .{
            .platform = platform,
            .window_base = window_base,
            .reserved = range,
            .rung = step.rung,
            .general_pools = step.rung == .full,
            .cage_lo = @intCast(step.cage_lo),
            .cage_hi = @intCast(l.cage.end()),
            .generation_seed = seed,
            .committed_bytes = header_bytes,
        };
        return heap;
    }

    /// The Browser's random stream, else the OS's entropy, reduced to
    /// [1, generation_seed_limit).
    fn generationSeed(platform: *const Platform, browser: ?*anyopaque) u64 {
        var bytes: [8]u8 = undefined;
        if (!platform.browser_random(browser, &bytes)) platform.random(&bytes);
        return 1 + std.mem.readInt(u64, &bytes, .little) % (generation_seed_limit - 1);
    }

    /// The heap's end: its reservation goes back to the OS. In Debug builds
    /// - the bug-finding run, whose Crane modules are Debug, and the unit
    /// tests - it is kept inaccessible instead, among the process's last few
    /// released reservations, so the next Browser cannot take this address at
    /// once (oss R12, appendix P4: 7 of 7 reservations reused the released
    /// address; Mozilla's aged graveyard, bug 1979830). Called last at the
    /// scope's end, after everything that names the heap.
    pub fn release(heap: *BrowserHeap, allocator: Allocator) void {
        switch (profile) {
            .pointer32 => allocator.destroy(heap),
            .full, .small => heap.releaseReservation(),
        }
    }

    fn releaseReservation(heap: *BrowserHeap) void {
        const platform = heap.platform;
        const range = heap.reserved;
        const header_in_range = @intFromPtr(heap) - range.base;
        const header_bytes = std.mem.alignForward(usize, @sizeOf(BrowserHeap), platform.page_size());
        if (comptime builtin.optimize == .debug) {
            heap.magic = 0;
            // Discard before protecting: darwin's MADV_FREE_REUSABLE fails on
            // an inaccessible page (oss R3).
            platform.decommit(range, header_in_range, header_bytes) catch {};
            if (platform.protect(range, 0, range.size, .none)) |_| {
                graveyard.keep(range, platform);
                return;
            } else |_| {}
        }
        platform.release(range);
    }

    /// The offset in `reserved` of a page range given as window offsets: a
    /// production check that it is page-aligned and inside the reservation.
    fn rangeOffset(heap: *const BrowserHeap, window_offset: usize, length: usize) usize {
        const page = heap.platform.page_size();
        const start = heap.window_base + window_offset;
        if (window_offset % page != 0 or length % page != 0 or length == 0 or start < heap.reserved.base or
            start - heap.reserved.base > heap.reserved.size or length > heap.reserved.size - (start - heap.reserved.base))
            @panic("BrowserHeap: a page range outside the reservation, or not page-aligned");
        return start - heap.reserved.base;
    }

    /// Commit `[window_offset, window_offset + length)` of the window
    /// (platform.commitPages).
    pub fn commit(heap: *BrowserHeap, window_offset: usize, length: usize) PageError!void {
        try heap.platform.commit(heap.reserved, heap.rangeOffset(window_offset, length), length);
        heap.committed_bytes += length;
    }

    /// Give a committed part's memory back, keeping it accessible
    /// (platform.decommitPages). Never across a super page: a decommit that
    /// reaches into a super page that is not committed fails as a whole on
    /// darwin and releases nothing (oss R3) - a production check.
    pub fn decommit(heap: *BrowserHeap, window_offset: usize, length: usize) PageError!void {
        const offset = heap.rangeOffset(window_offset, length);
        if (window_offset / super_page_bytes != (window_offset + length - 1) / super_page_bytes)
            @panic("BrowserHeap.decommit: the range crosses a super page");
        try heap.platform.decommit(heap.reserved, offset, length);
    }

    /// Release a committed part's memory and make it inaccessible, in the
    /// only order that releases it on darwin: discard, then protect (oss R3;
    /// the bug-finding build's freed spans). Not across a super page.
    pub fn retire(heap: *BrowserHeap, window_offset: usize, length: usize) PageError!void {
        try heap.decommit(window_offset, length);
        try heap.platform.protect(heap.reserved, heap.rangeOffset(window_offset, length), length, .none);
        heap.committed_bytes -|= length;
    }

    /// The address of a window offset (no check: the layout's constants).
    pub fn at(heap: *const BrowserHeap, window_offset: u64) usize {
        return heap.window_base + @as(usize, @intCast(window_offset));
    }
};

/// The heap of the Browser whose heap issued `ptr`. A CONTRACT, not a
/// classifier: only for a pointer the caller knows a Browser heap issued (a
/// node block, a satellite, an objects-pool block); it answers by masking,
/// never by asking whether `ptr` is a heap pointer. Debug builds check the
/// header's magic. pointer32: the heap chunk's header names it (H2's chunks,
/// aligned to `pointer32_chunk_bytes`).
pub inline fn heapOf(ptr: *const anyopaque) *BrowserHeap {
    switch (profile) {
        .full, .small => {
            const address: u64 = @intFromPtr(ptr) & address_bits_mask;
            const window = address & ~(layout.window_bytes - 1);
            const heap: *BrowserHeap = @ptrFromInt(@as(usize, @intCast(window + layout.header_offset)));
            if (builtin.optimize == .debug and heap.magic != BrowserHeap.magic_value) @panic("heapOf: not a Browser heap's address");
            return heap;
        },
        .pointer32 => {
            const chunk: *const Chunk = @ptrFromInt(@intFromPtr(ptr) & ~@as(usize, pointer32_chunk_bytes - 1));
            if (builtin.optimize == .debug and chunk.magic != Chunk.magic_value) @panic("heapOf: not a Browser heap's chunk");
            return chunk.heap;
        },
    }
}

/// pointer32: node memory comes in chunks aligned to their size, each opened
/// by this header (H2 makes them; the slab's own rule today,
/// slab_allocator.zig's 8 KiB slabs).
pub const pointer32_chunk_bytes: usize = 64 * 1024;

pub const Chunk = extern struct {
    magic: u32 = magic_value,
    heap: *BrowserHeap,

    pub const magic_value: u32 = 0x43484b31; // "CHK1"
};

// ============================================================================
// The graveyard: the last few released reservations, kept inaccessible
// ============================================================================

const Graveyard = struct {
    const capacity = 4;
    mutex: std.Io.Mutex = .init,
    ranges: [capacity]Range = undefined,
    platforms: [capacity]*const Platform = undefined,
    count: usize = 0,
    next: usize = 0,

    /// Keep `range`; give back the oldest kept one when full.
    fn keep(self: *Graveyard, range: Range, platform: *const Platform) void {
        var evicted: ?struct { Range, *const Platform } = null;
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        if (self.count == capacity) {
            evicted = .{ self.ranges[self.next], self.platforms[self.next] };
        } else {
            self.count += 1;
        }
        self.ranges[self.next] = range;
        self.platforms[self.next] = platform;
        self.next = (self.next + 1) % capacity;
        std.Io.Threaded.mutexUnlock(&self.mutex);
        if (evicted) |e| e[1].release(e[0]);
    }

    /// Give back every kept range (a test that wants the process as it found
    /// it).
    fn drain(self: *Graveyard) void {
        while (true) {
            std.Io.Threaded.mutexLockUncancelable(&self.mutex);
            if (self.count == 0) {
                std.Io.Threaded.mutexUnlock(&self.mutex);
                return;
            }
            const oldest = (self.next + capacity - self.count) % capacity;
            const range = self.ranges[oldest];
            const platform = self.platforms[oldest];
            self.count -= 1;
            std.Io.Threaded.mutexUnlock(&self.mutex);
            platform.release(range);
        }
    }
};

// process-wide: the address space is the process's - a released Browser reservation kept inaccessible (Debug builds only: the bug-finding run and unit tests) must outlive its Browser, so no Browser can own it; at most 4 entries, every read and write under its std.Io.Mutex, from any Browser's thread.
var graveyard: Graveyard = .{};

/// How many released reservations the graveyard keeps now (Debug builds).
pub fn keptReservations() usize {
    std.Io.Threaded.mutexLockUncancelable(&graveyard.mutex);
    defer std.Io.Threaded.mutexUnlock(&graveyard.mutex);
    return graveyard.count;
}

/// Give back every reservation the graveyard keeps.
pub fn releaseKeptReservations() void {
    graveyard.drain();
}
