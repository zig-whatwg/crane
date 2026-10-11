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
//! Browser's. An object finds its scope from its address alone
//! (`ofInstance`): the slab is aligned so that its header names it.
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

/// The scope of objects made with no Browser - unit tests, and a host that
/// starts the runtime itself (runtime.initializeRuntime). A Browser never
/// uses it: every realm a Browser makes carries the Browser's own scope.
// process-wide: the one scope of objects made outside any Browser (unit tests and runtime-only hosts), set by runtime.initializeRuntime before any such object and cleared by its end; no Browser reads it.
var standalone_scope: ?*BrowserScope = null;

pub const BrowserScope = struct {
    /// Thread-safe: supplements are made on whichever thread first asks.
    allocator: Allocator,
    /// The Instance handles of every platform object of this Browser. Never
    /// moves once it has issued one (its slabs record its address).
    slab: SlabAllocator,
    /// The state of every platform object of this Browser.
    arena: ArenaAllocator,
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
        /// HTMLOptionElement's and HTMLTextAreaElement's state, kept by value.
        option_states,
        textarea_states,
        /// runtime.InstanceRegistry's tables, one per impl that keeps one
        /// (its InternalState).
        node,
        character_data,
        text,
        comment,
        document,
        document_fragment,
        document_type,
        shadow_root,
        element,
        html_element,
        html_anchor_element,
        html_area_element,
        html_form_element,
        html_image_element,
        html_input_element,
        html_script_element,
        html_slot_element,
        html_template_element,
        canvas_rendering_context_2d,
        css_style_declaration,
        dom_string_map,
    };
    const table_count = @typeInfo(Table).@"enum".fields.len;

    const Supplement = struct {
        /// `@typeName` of the supplement's type: its key.
        key: []const u8,
        ptr: *anyopaque,
        destroy: *const fn (ptr: *anyopaque, allocator: Allocator) void,
    };

    /// A scope with no object, supplement or table yet. Its slab records the
    /// scope's address once it issues an object: a scope is not moved after
    /// its first platform object.
    pub fn init(allocator: Allocator) BrowserScope {
        return .{
            .allocator = allocator,
            .slab = SlabAllocator.init(allocator),
            .arena = ArenaAllocator.init(allocator),
        };
    }

    /// The scope's end, with its Browser's: every supplement ends, the last
    /// made first; then every side table, the same way; then the arena and
    /// the slab, with every platform object of the Browser still in them.
    pub fn deinit(self: *BrowserScope) void {
        std.Io.Threaded.mutexLock(&self.mutex);
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
    }

    /// The scope of the Browser that made `instance`: the scope whose slab
    /// issued it. Read from the address alone, so it answers for a freed
    /// instance too, until its scope ends.
    pub fn ofInstance(instance: *const Instance) *BrowserScope {
        return @fieldParentPtr("slab", SlabAllocator.ownerOf(instance));
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
        std.Io.Threaded.mutexLock(&self.mutex);
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
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const ptr = find(self, @typeName(T)) orelse return null;
        return @ptrCast(@alignCast(ptr));
    }

    /// This scope's side table `tag`, of type `T`, made on first use. One
    /// atomic load once it exists. Every caller of a tag names the same `T`.
    pub inline fn table(self: *BrowserScope, comptime tag: Table, comptime T: type) Allocator.Error!*T {
        if (self.tables[@intFromEnum(tag)].load(.acquire)) |ptr| return @ptrCast(@alignCast(ptr));
        return self.makeTable(tag, T);
    }

    /// This scope's side table `tag` if it was made; never makes one.
    pub inline fn existingTable(self: *BrowserScope, comptime tag: Table, comptime T: type) ?*T {
        const ptr = self.tables[@intFromEnum(tag)].load(.acquire) orelse return null;
        return @ptrCast(@alignCast(ptr));
    }

    fn makeTable(self: *BrowserScope, comptime tag: Table, comptime T: type) Allocator.Error!*T {
        const index = @intFromEnum(tag);
        std.Io.Threaded.mutexLock(&self.mutex);
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
