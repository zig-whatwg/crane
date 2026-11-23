//! A Browser's scope: where its per-Browser state lives, reached through the
//! realm (docs/instances.md, rule 2: "a realm will carry its Browser's scope
//! ... Per-Browser state of a subsystem is a supplement of that scope (Blink's
//! `Supplementable`), made on first use and destroyed with the scope").
//!
//! A Browser runs its window agent on one thread and every worker on a thread
//! of its own, so a supplement is reached from several threads: the scope's
//! mutex guards the supplement list, and a supplement guards its own state.
//!
//! The scope owns the runtime's allocators (instances B1): every platform
//! object of the Browser takes its Instance handle from `slab` and its state
//! from `arena` (`Instance.init`, through the realm's `browser_scope`), and
//! the Browser's end frees exactly its own objects - never another
//! Browser's. Both are views of the Browser's HEAP (`heap`, its span engine
//! `heapEngine`: lane hard1, allocator-hardening batch A), so an object finds
//! its scope from its address alone (`ofInstance`: browser_heap.heapOf).
//! A Browser reserves its heap at its start (`reserveHeap`); any other
//! scope - a unit test's, the standalone one - at its first object
//! (`heapEngine`), with the platform's address space and the OS's entropy.
//!
//! A supplement type `T` has `pub fn init(allocator: Allocator) T` and
//! `pub fn deinit(self: *T) void`. It is keyed by its type: `of(T)` returns
//! the one `T` of this scope, made on first use. Supplements end in the
//! reverse order they were made, with the scope.
//!
//! A side table (`Table`) is a supplement reached on a hot path - an
//! address-keyed table of the objects' own state that runtime and DOM code
//! read on every call: it is keyed by a `Table` tag instead of a type name,
//! so finding it is one load. Same contract (`init`, `deinit`), made on first
//! use, ended with the scope after the supplements.

const std = @import("std");
const Allocator = std.mem.Allocator;
const SlabAllocator = @import("slab_allocator.zig").SlabAllocator;
const ArenaAllocator = @import("arena_allocator.zig").ArenaAllocator;
const Instance = @import("instance.zig").Instance;
const browser_heap = @import("browser_heap.zig");
const heap_engine = @import("heap/root.zig");

/// The scope of objects made with no Browser - unit tests, and a host that
/// starts the runtime itself (runtime.initializeRuntime). A Browser never
/// uses it: every realm a Browser makes carries the Browser's own scope.
// process-wide: the one scope of objects made outside any Browser (unit tests and runtime-only hosts), set by runtime.initializeRuntime before any such object and cleared by its end, both on the host's own thread (init-once per runtime start, no concurrent writer); no Browser reads it.
var standalone_scope: ?*BrowserScope = null;

/// How many scopes are alive - every Browser's and the standalone one -
/// from `init` to `deinit`, for diagnostics (`liveCount`).
// process-wide: a diagnostics count over every Browser in the process (Blink's leak detector's instance counters); every write is an atomic add or sub (std.atomic.Value), so Browsers starting and ending on many threads never race it; the test runner reads it after each test to find a Browser the test left alive
var live_scopes: std.atomic.Value(usize) = .init(0);

pub const BrowserScope = struct {
    /// A Browser's heap: its reservation, profile, layout, `Link` and
    /// `heapOf` (src/runtime/browser_heap.zig).
    pub const Heap = browser_heap;

    /// Thread-safe: supplements are made on whichever thread first asks.
    allocator: Allocator,
    /// The Browser's heap - one reservation of address space (`Heap`) -
    /// once `reserveHeap` made it: a Browser's at its start, any other
    /// scope's at its first object (`heapEngine`).
    heap: ?*browser_heap.BrowserHeap = null,
    /// The heap's span engine (heap.Engine): every State block and Instance
    /// slot of the Browser. Published with a release store once started, so
    /// `heapEngine` reads it without the lock.
    engine: std.atomic.Value(?*heap_engine.Engine) = .init(null),
    /// Whether the scope's end reports the State blocks still alive in its
    /// heap (`reportHeapLeaks`), where the heap records sites (Debug builds,
    /// the bug-finding run): a Browser's scope (Browser.init sets it). Its
    /// end frees every one with the reservation, so a block alive then is a
    /// lifetime the heap took over from the old arena, which hid it.
    report_heap_leaks: bool = false,
    /// Serialises the heap's start (`reserveHeap`, `heapEngine`'s first
    /// call). Not `mutex`: a supplement's `init` may make the scope's first
    /// object, and `of` holds `mutex` across it.
    heap_mutex: std.Io.Mutex = .init,
    /// The Instance handles of every platform object of this Browser. Never
    /// moves once it has issued one (its slabs record its address).
    slab: SlabAllocator,
    /// The state of every platform object of this Browser.
    arena: ArenaAllocator,
    /// The native storage of this Browser's nodes - its DOM - which its
    /// window agent's engine is told about (runtime.gc.ExternalMemory,
    /// engine.AgentOptions.external_memory): dom.instance_bridge counts each
    /// node as it registers and unregisters. Its window agent's thread only.
    dom_memory: @import("gc_integration.zig").ExternalMemory = .{},
    /// Whether a use of one of this Browser's Windows may be reported (HTML
    /// 7.1.3.3, "check if an access between two browsing contexts should be
    /// reported"): the engine's `report_window_access` path reads it first
    /// and asks nothing more while it is false - Chromium's "fast early
    /// return" in DOMWindow::ReportCoopAccess (dom_window.cc:882) on a
    /// window with no CoopAccessMonitor. Set by dom.coop_reporting
    /// (startMonitoring) when a navigation gives a top-level context a new
    /// virtual browsing context group ID, and never cleared.
    window_access_monitored: std.atomic.Value(bool) = .init(false),
    /// Whether one of this Browser's realms has an isolated world realm (the
    /// engine's createWorldRealm; CDP's Page.createIsolatedWorld): until
    /// then a conversion of a platform object asks no world - two loads, no
    /// lookup - as `window_access_monitored` gates its path. Set by the
    /// engine adapter when it makes the Browser's first world realm, never
    /// cleared. Read by every thread of the Browser (a worker's conversions
    /// read their realm's), hence atomic.
    isolated_worlds_active: std.atomic.Value(bool) = .init(false),
    /// The Browser's performance monitor (dom.performance_monitor.Monitor)
    /// while a host is subscribed to a violation, else null: the hot paths
    /// - listener invoke, timer fire - load it and branch, reading no clock
    /// when it is null, as Blink's PerformanceMonitor::enabled_. Set and
    /// cleared on the window thread; read by any thread of the Browser (a
    /// worker's dispatch tests it too), hence atomic.
    performance_monitor: std.atomic.Value(?*anyopaque) = .init(null),
    /// Protects `supplements` and the making of tables. Never held across a
    /// supplement's own steps beyond its `init`.
    mutex: std.Io.Mutex = .init,
    supplements: std.ArrayListUnmanaged(Supplement) = .empty,
    /// The side tables made so far, by `Table`: published with a release
    /// store once made, so `table` reads one without the lock.
    tables: [table_count]std.atomic.Value(?*anyopaque) = @splat(.init(null)),
    /// How each made table ends, and the order they were made in.
    table_ends: [table_count]?*const fn (ptr: *anyopaque, allocator: Allocator) void = @splat(null),
    table_order: [table_count]u8 = undefined,
    tables_made: usize = 0,

    /// The Browser's side tables - per-object state kept beside the objects
    /// (keyed by address) that runtime and DOM code read on every call. One
    /// tag per table; its type is its owner's.
    pub const Table = enum(u8) {
        /// runtime.internal_state: an instance's internal state.
        internal_states,
        /// dom.instance_bridge: a node's NodeBase.
        node_bases,
        /// EventTarget's state: listeners and event handlers.
        event_targets,
        /// StaticRange's boundary points.
        static_ranges,
        /// html.window.Navigables: every browsing context of the Browser,
        /// read by every navigable lookup (dom.browser_state).
        navigables,
        /// HTMLOptionElement's and HTMLTextAreaElement's state, kept by value.
        option_states,
        textarea_states,
        /// runtime.InstanceRegistry's tables, one per impl that keeps one
        /// (its InternalState). The node types read on every DOM call and
        /// enumerated only at their Browser's end keep theirs in their own
        /// State instead (runtime.OwnState: Node, CharacterData, Text,
        /// Comment, DocumentFragment, DocumentType, ShadowRoot, Element,
        /// HTMLElement, HTMLAnchorElement, HTMLAreaElement,
        /// HTMLTemplateElement, SVGScriptElement, HTMLSlotElement).
        document,
        html_form_element,
        html_image_element,
        html_input_element,
        html_script_element,
        // dom.orphan_states (lane orphanleak): the states of these node
        // types, so an orphan's has an exit at its Browser's end.
        attr,
        html_button_element,
        html_field_set_element,
        html_iframe_element,
        html_media_element,
        html_object_element,
        html_output_element,
        html_dialog_element,
        html_select_element,
        html_source_element,
        html_track_element,
        html_video_element,
        canvas_rendering_context_2d,
        css_style_declaration,
        dom_string_map,
        svg_image_element,
        svg_use_element,
        // dom.smil.document_animations (lane dnd1): an animation element's
        // timing state, an outermost svg element's timeline.
        svg_animation_element,
        svg_svg_element,
        font_face,
        font_face_set,
        /// dom.browser_object_lists: the Browser's IntersectionObservers
        /// and ResizeObservers that observe something, its Navigation
        /// objects, and its ProcessingInstructions not yet deinit'd.
        intersection_observers,
        resize_observers,
        navigations,
        processing_instructions,
        /// dom.element_name.Table: the Browser's interned element names -
        /// one COUNTED record per qualified name no static table has that an
        /// element of the Browser names now (lane nd2 N2 and batch 1-fix;
        /// Blink's QualifiedNameCache, Gecko's nsNodeInfoManager). Weak: a
        /// record's last element frees it, to the scope's general allocator;
        /// the table's end frees any left.
        element_names,
        /// dom.attribute_names.Table: the Browser's interned attribute names
        /// outside the static tables, each a COUNTED record with a dense u32
        /// id (lane nd2 batch 2, A2): the same rules as `element_names`.
        attribute_names,
        /// dom.attribute_values.Table: the Browser's attribute values, one
        /// COUNTED record per distinct value an attribute holds now, with a
        /// dense u32 id (lane nd2 batch 2, A1: Blink's and WebKit's
        /// AtomString values). Weak, like `element_names`.
        attribute_values,
    };
    const table_count = @typeInfo(Table).@"enum".field_names.len;

    const Supplement = struct {
        /// `@typeName` of the supplement's type: its key.
        key: []const u8,
        ptr: *anyopaque,
        destroy: *const fn (ptr: *anyopaque, allocator: Allocator) void,
    };

    /// A scope with no object, supplement or table yet. Its slab records the
    /// scope's address once it issues an object: a scope is not moved after
    /// its first platform object. It has no heap until `reserveHeap`.
    pub fn init(allocator: Allocator) BrowserScope {
        _ = live_scopes.fetchAdd(1, .monotonic);
        var scope: BrowserScope = .{
            .allocator = allocator,
            .slab = .{},
            .arena = .{},
        };
        scope.arena.poison_freed = poisonsFreedStateByDefault(@import("builtin").mode);
        return scope;
    }

    /// Whether a scope's arena poisons a freed state block without being
    /// asked (runtime.ArenaAllocator.poison_freed), for a build `mode`: a
    /// Debug build's does - the unit tests and the bug-finding WPT runner's
    /// Crane modules - so a read of a FREED node block finds the poison
    /// there, where it found the bytes its release left (lane uaf1:
    /// NodeBase.freed_owner_word). No release build's does: there only a
    /// Browser that asked (BrowserConfig.poison_freed_state), which also
    /// gets the arena's quarantine (`quarantine_freed`); the default never
    /// does, so a Debug build reuses a freed block as production does.
    /// Pinned for every mode by a test.
    pub fn poisonsFreedStateByDefault(mode: std.builtin.OptimizeMode) bool {
        return mode == .debug;
    }

    /// Reserve this scope's heap through the platform `P` (`@import
    /// ("platform")`, or a test's namespace of the same shape): the ladder's
    /// first rung that fits (Heap.BrowserHeap.reserve), named as this
    /// scope's. Called once, when the scope's address is final - Browser.init
    /// calls it at the Browser's start, so a Browser that cannot reserve
    /// fails Browser.init cleanly (error.OutOfMemory, or NotSupported on a
    /// platform without address space).
    ///
    /// Why an explicit call and not `init` (the deep review's source finding
    /// 12): `init` returns the scope by value and cannot fail - 122 call
    /// sites, and 531 through runtime.initializeRuntime - and a heap header
    /// cannot name a scope whose address is not final yet.
    ///
    /// `browser` is the Browser's platform state: its random stream, when it
    /// has one (the testing platform's seeded Browser), seeds the Browser's
    /// generations, so a seeded run replays them; otherwise the OS's
    /// entropy. Every Browser's generations start at a random value - a
    /// released reservation's address goes to the next one (oss R12,
    /// appendix P4) - so a (pointer, generation) pair held across Browsers
    /// cannot match another Browser's object. Until H3 moves the stamps into
    /// the blocks, the seed goes to this scope's slab.
    pub fn reserveHeap(self: *BrowserScope, comptime P: type, browser: ?*anyopaque) browser_heap.Error!void {
        std.Io.Threaded.mutexLockUncancelable(&self.heap_mutex);
        defer std.Io.Threaded.mutexUnlock(&self.heap_mutex);
        if (self.heap != null) @panic("BrowserScope.reserveHeap: this scope already has its heap");
        _ = try self.startHeap(browser_heap.Platform.of(P), browser);
    }

    /// Reserve the heap and start its engine, under `heap_mutex`.
    fn startHeap(self: *BrowserScope, platform: *const browser_heap.Platform, browser: ?*anyopaque) browser_heap.Error!*heap_engine.Engine {
        const heap = try browser_heap.BrowserHeap.reserve(platform, self.allocator, browser);
        errdefer heap.release(self.allocator);
        // The quarantine's evictions draw from the Browser's stream after
        // the generations' seed, so a seeded run replays both.
        var seed_bytes: [8]u8 = undefined;
        if (!platform.browser_random(browser, &seed_bytes)) platform.random(&seed_bytes);
        const config = heap_engine.Config.of(self.arena.poison_freed, self.arena.quarantine_freed);
        const engine = heap_engine.Engine.init(heap, config, std.mem.readInt(u64, &seed_bytes, .little)) catch |err| return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            error.NotSupported => error.NotSupported,
        };
        heap.owner = self;
        self.heap = heap;
        // A test build's heap asks the scope's allocator before it opens a
        // span, as the state arena's chunk growth did: a scope over a
        // FailingAllocator fails its State allocations there.
        if (@import("builtin").is_test) engine.grow_hook = .{ .context = self, .call = probeAllocator };
        // Never back: generations stay unique within the slab even if an
        // object was made before the heap.
        self.slab.seedGenerations(heap.generation_seed);
        self.engine.store(engine, .release);
        return engine;
    }

    /// The failure injector's question (`heap.Engine.grow_hook`): may the
    /// heap grow? Whether the scope's allocator gives a byte now.
    fn probeAllocator(context: *anyopaque) bool {
        const self: *BrowserScope = @ptrCast(@alignCast(context));
        const byte = self.allocator.alloc(u8, 1) catch return false;
        self.allocator.free(byte);
        return true;
    }

    /// The span engine of this scope's heap, reserving the heap at the
    /// scope's first object when the scope has none (H1's queued follow-up,
    /// tmp/plans/lane-h1-handoff.md: a unit test's scope, the standalone
    /// one): the platform's address space (`@import("platform")`), the OS's
    /// entropy. One atomic load once started. A scope that cannot reserve
    /// fails the allocation (OutOfMemory, NotSupported), which every
    /// Instance.init caller propagates.
    pub inline fn heapEngine(self: *BrowserScope) browser_heap.Error!*heap_engine.Engine {
        if (self.engine.load(.acquire)) |engine| return engine;
        return self.startHeapLazily();
    }

    fn startHeapLazily(self: *BrowserScope) browser_heap.Error!*heap_engine.Engine {
        @branchHint(.cold);
        std.Io.Threaded.mutexLockUncancelable(&self.heap_mutex);
        defer std.Io.Threaded.mutexUnlock(&self.heap_mutex);
        if (self.engine.load(.acquire)) |engine| return engine;
        return self.startHeap(browser_heap.Platform.of(@import("platform")), null);
    }

    /// The span engine if the heap was started; never starts one.
    pub inline fn existingHeapEngine(self: *const BrowserScope) ?*heap_engine.Engine {
        return self.engine.load(.acquire);
    }

    /// The scope whose heap `heap` is.
    pub inline fn ofHeap(heap: *const browser_heap.BrowserHeap) *BrowserScope {
        return @ptrCast(@alignCast(heap.owner orelse @panic("BrowserScope.ofHeap: a heap with no scope")));
    }

    /// The scope's end, with its Browser's: every supplement ends, the last
    /// made first; then every side table, the same way; then the arena and
    /// the slab, with every platform object of the Browser still in them;
    /// then, last, the heap's reservation, after everything that names it.
    pub fn deinit(self: *BrowserScope) void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        var supplements = self.supplements;
        self.supplements = .empty;
        std.Io.Threaded.mutexUnlock(&self.mutex);
        var i = supplements.items.len;
        while (i > 0) {
            i -= 1;
            const supplement = supplements.items[i];
            supplement.destroy(supplement.ptr, self.allocator);
        }
        supplements.deinit(self.allocator);

        var t = self.tables_made;
        while (t > 0) {
            t -= 1;
            const index = self.table_order[t];
            const ptr = self.tables[index].swap(null, .acq_rel) orelse continue;
            if (self.table_ends[index]) |end| end(ptr, self.allocator);
            self.table_ends[index] = null;
        }
        self.tables_made = 0;

        self.arena.deinit();
        self.slab.deinit();
        if (self.heap) |heap| {
            if (self.engine.load(.acquire)) |engine| {
                const swept = self.releaseSweptNodes(engine);
                if (self.report_heap_leaks and engine.config.record_sites) {
                    if (swept != 0) std.log.scoped(.heap).warn("heap swept: {d} node(s) released at the Browser's end, after the final sweep (held past every realm's end: refcount_teardown.agentEnded's count)", .{swept});
                    reportHeapLeaks(engine);
                }
            }
            self.engine.store(null, .release);
            self.heap = null;
            heap.release(self.allocator);
        }
        _ = live_scopes.fetchSub(1, .monotonic);
    }

    /// The final sweep's nodes (dom.teardown_sweeps: the nodes held past
    /// every realm's end, refcount decision D9) - their side tables freed,
    /// their deinit chains run or never needed - have their State block and
    /// slot released explicitly: the final sweep is their reviewed owner (the
    /// integrator, 2026-11-23 6:18 AM ET), and the arena that used to free
    /// them wholesale is gone. Every other live Instance is left for the
    /// leak report. On the scope's thread, after its agent ended and its
    /// tables, so nothing reaches them. The count of nodes released.
    pub fn releaseSweptNodes(self: *BrowserScope, engine: *heap_engine.Engine) usize {
        var released: usize = 0;
        var slots = engine.instanceSlots();
        while (slots.next()) |bytes| {
            const instance: *Instance = @ptrCast(@alignCast(bytes));
            if (SlabAllocator.generationOf(instance) == SlabAllocator.dead_generation) continue;
            if (instance.vtable.counted == null) continue;
            if (instance.vtable.state_size != 0) self.arena.destroyRaw(@ptrCast(instance.state), instance.vtable.state_size, instance.vtable.state_align);
            self.slab.free(instance);
            released += 1;
        }
        return released;
    }

    /// The heap's leak report at the scope's end: one `heap leak:` line per
    /// type (or site) with blocks still alive - the line the bug-finding
    /// gate counts (tests/wpt_runner/build_compare.zig) - and the Instance
    /// slots still issued.
    fn reportHeapLeaks(engine: *heap_engine.Engine) void {
        const log = std.log.scoped(.heap);
        const Report = struct {
            fn line(_: void, l: heap_engine.LeakLine) void {
                if (l.type_name) |name|
                    log.warn("heap leak: {d} block(s) of {d} B alive at the Browser's end: {s}", .{ l.count, l.block_bytes, name })
                else if (l.return_address != 0)
                    log.warn("heap leak: {d} block(s) of {d} B alive at the Browser's end: made at 0x{x}", .{ l.count, l.block_bytes, l.return_address })
                else
                    log.warn("heap leak: {d} block(s) of {d} B alive at the Browser's end (no site recorded)", .{ l.count, l.block_bytes });
            }
        };
        const blocks = engine.leakReport({}, Report.line);
        const slots = engine.instanceCounts().live;
        if (blocks != 0 or slots != 0) {
            reportLiveInstances(engine);
            log.warn("heap leak: {d} State block(s) and {d} Instance slot(s) alive at the Browser's end", .{ blocks, slots });
        }
    }

    /// The Instances alive at the scope's end, by interface and lifecycle
    /// flags (runtime.instance_lifecycle: wrapped, wrapper gone, cleanup
    /// started / complete): what held each - a wrapper that never died, one
    /// whose finalizer never freed it, a native owner. Reads each live
    /// slot's vtable and stamp only (its realm may have ended).
    fn reportLiveInstances(engine: *heap_engine.Engine) void {
        const log = std.log.scoped(.heap);
        const Group = struct { name: []const u8, bits: u8, count: usize };
        var groups: [24]Group = undefined;
        var n: usize = 0;
        var slots = engine.instanceSlots();
        while (slots.next()) |bytes| {
            const instance: *Instance = @ptrCast(@alignCast(bytes));
            if (SlabAllocator.generationOf(instance) == SlabAllocator.dead_generation) continue;
            const name = instance.vtable.name;
            const bits = SlabAllocator.lifecycleBitsOf(instance);
            for (groups[0..n]) |*g| {
                if (g.bits == bits and std.mem.eql(u8, g.name, name)) {
                    g.count += 1;
                    break;
                }
            } else if (n < groups.len) {
                groups[n] = .{ .name = name, .bits = bits, .count = 1 };
                n += 1;
            }
        }
        for (groups[0..n]) |g| log.warn("heap leak: {d} live {s} (lifecycle flags 0b{b:0>8}: cleanup_started, cleanup_complete, attached, weak_pending, wrapped, wrapper_gone from bit 0)", .{ g.count, g.name, g.bits });
    }

    /// How many scopes are alive in the process: every Browser's, and the
    /// standalone one while the runtime runs without a Browser. Diagnostics
    /// only - the Crane test runner (tests/test_runner/) reads it before and
    /// after each test, so a test that leaves a Browser alive fails by name.
    pub fn liveCount() usize {
        return live_scopes.load(.monotonic);
    }

    /// The scope of the Browser that made `instance`: the scope whose heap
    /// issued its slot (browser_heap.heapOf: the address masked to its
    /// window, one load). Read from the address alone, so it answers for a
    /// freed instance too, until its scope ends.
    pub inline fn ofInstance(instance: *const Instance) *BrowserScope {
        return ofHeap(browser_heap.heapOf(instance));
    }

    /// Whether a node released by its teardown has its NodeBase overwritten
    /// with the poison byte (dom: Node's releaseNodeBase): always in Debug
    /// builds - the unit tests' poison-on-free, which the NodeBase had while
    /// it was its own allocation - and in any build whose Browser asked for
    /// poisoned frees (BrowserConfig.poison_freed_state: the WPT correctness
    /// runner). Lane perf2 batch 5 (Z7): the NodeBase is the State block's
    /// now, released at teardown and freed with the block.
    pub fn poisonsReleasedNodes(self: *const BrowserScope) bool {
        return releasedNodePoison(@import("builtin").mode, self.arena.poison_freed);
    }

    /// `poisonsReleasedNodes`'s rule, for a build `mode` and the Browser's
    /// flag: pinned for every mode by a test (off in every release mode by
    /// default).
    pub fn releasedNodePoison(mode: std.builtin.OptimizeMode, poison_freed: bool) bool {
        return mode == .debug or poison_freed;
    }

    /// The standalone scope (runtime.initializeRuntime), if the runtime was
    /// started without a Browser.
    pub fn standalone() ?*BrowserScope {
        return standalone_scope;
    }

    /// runtime.initializeRuntime / deinitializeRuntime's: set or clear the
    /// standalone scope. Not for a Browser.
    pub fn setStandalone(scope: ?*BrowserScope) void {
        standalone_scope = scope;
    }

    /// This scope's `T`, made on first use.
    pub fn of(self: *BrowserScope, comptime T: type) Allocator.Error!*T {
        const key = @typeName(T);
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        if (find(self, key)) |ptr| return @ptrCast(@alignCast(ptr));
        try self.supplements.ensureUnusedCapacity(self.allocator, 1);
        const made = try self.allocator.create(T);
        made.* = T.init(self.allocator);
        self.supplements.appendAssumeCapacity(.{ .key = key, .ptr = made, .destroy = Destroy(T).destroy });
        return made;
    }

    /// This scope's `T` if one was made; never makes one.
    pub fn existing(self: *BrowserScope, comptime T: type) ?*T {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const ptr = find(self, @typeName(T)) orelse return null;
        return @ptrCast(@alignCast(ptr));
    }

    /// This scope's side table `tag`, of type `T`, made on first use. One
    /// atomic load once it exists. Every caller of a tag names the same `T`.
    pub inline fn table(self: *BrowserScope, comptime tag: Table, comptime T: type) Allocator.Error!*T {
        if (self.tables[@backingInt(tag)].load(.acquire)) |ptr| return @ptrCast(@alignCast(ptr));
        return self.makeTable(tag, T);
    }

    /// This scope's side table `tag` if it was made; never makes one.
    pub inline fn existingTable(self: *BrowserScope, comptime tag: Table, comptime T: type) ?*T {
        const ptr = self.tables[@backingInt(tag)].load(.acquire) orelse return null;
        return @ptrCast(@alignCast(ptr));
    }

    fn makeTable(self: *BrowserScope, comptime tag: Table, comptime T: type) Allocator.Error!*T {
        const index = @backingInt(tag);
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        if (self.tables[index].load(.acquire)) |ptr| return @ptrCast(@alignCast(ptr));
        const made = try self.allocator.create(T);
        made.* = T.init(self.allocator);
        self.table_ends[index] = Destroy(T).destroy;
        self.table_order[self.tables_made] = index;
        self.tables_made += 1;
        self.tables[index].store(made, .release);
        return made;
    }

    fn find(self: *BrowserScope, key: []const u8) ?*anyopaque {
        for (self.supplements.items) |supplement| {
            if (std.mem.eql(u8, supplement.key, key)) return supplement.ptr;
        }
        return null;
    }

    fn Destroy(comptime T: type) type {
        return struct {
            fn destroy(ptr: *anyopaque, allocator: Allocator) void {
                const self: *T = @ptrCast(@alignCast(ptr));
                self.deinit();
                allocator.destroy(self);
            }
        };
    }
};
