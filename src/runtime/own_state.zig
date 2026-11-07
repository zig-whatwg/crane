//! OwnState - an impl's internal state, kept in its instance's own generated
//! State (lane perf2, batch 2: tmp/plans/perf2b2-design.md).
//!
//! Every interface's generated State has the field, one per level of the
//! chain: `own._internal: ?*XImpl.InternalState` (codegen,
//! src/webidl/codegen/writer.zig). `OwnState(State, T)` keeps the impl's
//! InternalState `T` there - the impl's OWN interface's `State`, never
//! another's - so finding it is reading a field of the object, as Blink and
//! WebKit read a node's rare data and an element's attribute storage from
//! the node itself (Blink core/dom/node.h `Member<NodeRareData> data_`,
//! core/dom/element.h `Member<ElementData> element_data_`; WebKit
//! dom/Node.h `m_rareDataWithBitfields`, dom/Element.h
//! `RefPtr<ElementData> m_elementData`). It replaces runtime.InstanceRegistry,
//! a hash table keyed by the instance's address, for the types whose state is
//! read on every DOM call and enumerated only at their Browser's end; its API
//! is the registry's, so a converted impl changes one line.
//!
//! - `get` reads the slot's stamp first: a freed slot answers null without
//!   its Instance being read (its first word is the slab's free-list pointer
//!   then), as the registry answered null for an address it no longer held.
//!   Then `Instance.stateAs(State)` (one ancestry entry, the brand check) and
//!   the field.
//! - The block is the instance's Browser's arena's (`createIn`), back there
//!   on `remove`, as the registry's was.
//! - An object made after another was freed at its address has a fresh
//!   State block, zeroed by `Instance.init`: it cannot find a dead object's
//!   state, which is what the registry's check at each registration
//!   (`reportStale`) caught for a table keyed by address.
//! - What no deinit reached - an orphan's state at its Browser's end - is
//!   found by walking the Browser's slab (`SlabAllocator.forEachLive`): every
//!   live object whose ancestry holds `State` and whose field is set.
//!
//! Thread safety: the field is its instance's own, read and written on that
//! instance's thread, so there is no table and no lock. The sweeps and
//! counts walk the slab and are for a Browser's end and tests only.

const std = @import("std");
const Instance = @import("instance.zig").Instance;
const BrowserScope = @import("browser_scope.zig").BrowserScope;
const ArenaAllocator = @import("arena_allocator.zig").ArenaAllocator;
const SlabAllocator = @import("slab_allocator.zig").SlabAllocator;
const ExternalMemory = @import("gc_integration.zig").ExternalMemory;

/// The DOM memory a node's arena block counts in: its Browser's
/// (BrowserScope.dom_memory), when `instance` is a node - its vtable's
/// `counted` is runtime.lifetime's node - and null for every other object.
/// Lane perf2 batch 4: V8 is told what a node really holds - its slab slot,
/// its State block and its NodeBase (dom.instance_bridge.storageBytes, at
/// its registration), and every level's InternalState block, added here when
/// the block is made and subtracted when it goes back, at the block's arena
/// class (ArenaAllocator.heldBytes), so a node's total returns to 0 at its
/// teardown. Until then a div was reported as 368-632 B while it held ~2,450
/// (tmp/plans/perf2b4-design.md 1.5), and V8 scheduled DOM-driven
/// collections from that. The figure reaches V8 through the engine
/// protocol's AgentOptions.external_memory (capability `external_memory`):
/// the V8 adapter's external_memory.zig passes the change to
/// Isolate::AdjustAmountOfExternalAllocatedMemory at its safe points, as
/// Blink's V8GCController::reportDOMMemoryUsageToV8 did. Nodes are made and
/// freed on their window agent's thread only, the ExternalMemory's rule.
pub fn nodeDomMemory(instance: *const Instance) ?*ExternalMemory {
    const counted = instance.vtable.counted orelse return null;
    if (counted.kind != .node) return null;
    return &BrowserScope.ofInstance(instance).dom_memory;
}

/// The InternalState `T` of an impl whose interface's generated State is
/// `State`, in that State's `own._internal`.
pub fn OwnState(comptime State: type, comptime T: type) type {
    comptime {
        if (!@hasField(State, "own")) @compileError(@typeName(State) ++ " is not a generated State: it has no `own` fields");
        const Own = @FieldType(State, "own");
        if (!@hasField(Own, "_internal")) @compileError(@typeName(State) ++ " has no `own._internal` field");
        if (@FieldType(Own, "_internal") != ?*T) @compileError(@typeName(State) ++ ".own._internal is not ?*" ++ @typeName(T));
    }
    return struct {
        /// `instance`'s field, or null when its slot is freed or its
        /// ancestry has no `State`.
        inline fn fieldOf(instance: *const Instance) ?*?*T {
            if (SlabAllocator.generationOf(instance) == SlabAllocator.dead_generation) return null;
            const state = instance.stateAs(State) orelse return null;
            return &state.own._internal;
        }

        /// The internal state of `instance`, or null when none is set: never
        /// made, already removed, or `instance` is no `State`.
        pub inline fn get(instance: *const Instance) ?*T {
            const field = fieldOf(instance) orelse return null;
            return field.*;
        }

        /// Whether `instance` has its internal state set.
        pub fn contains(instance: *const Instance) bool {
            return get(instance) != null;
        }

        /// Allocate the internal state from `arena` - the instance's Browser's
        /// (runtime.arenaOf) - and set it, once per instance, in its init. The
        /// block is zeroed, as `ArenaAllocator.create` gives it; `remove`
        /// returns it.
        pub fn createIn(instance: *const Instance, arena: *ArenaAllocator) !*T {
            std.debug.assert(arena == &BrowserScope.ofInstance(instance).arena);
            const field = fieldOf(instance) orelse return error.InvalidStateError;
            // Once per instance: a second state would leak the first.
            std.debug.assert(field.* == null);
            const internal = try arena.create(T);
            field.* = internal;
            if (nodeDomMemory(instance)) |memory| memory.add(ArenaAllocator.heldBytes(@sizeOf(T), @alignOf(T)));
            return internal;
        }

        /// Return the internal state's block to its Browser's arena and clear
        /// the field. The caller has released what the state owns (its
        /// deinit). Does nothing when none is set.
        pub fn remove(instance: *const Instance) void {
            const field = fieldOf(instance) orelse return;
            const internal = field.* orelse return;
            field.* = null;
            if (nodeDomMemory(instance)) |memory| memory.sub(ArenaAllocator.heldBytes(@sizeOf(T), @alignOf(T)));
            BrowserScope.ofInstance(instance).arena.destroy(T, internal);
        }

        /// How many of `scope`'s objects have the state set (a slab walk:
        /// tests and diagnostics).
        pub fn count(scope: *BrowserScope) usize {
            var counted: usize = 0;
            scope.slab.forEachLive(&counted, struct {
                fn visit(total: *usize, instance: *Instance) void {
                    if (get(instance) != null) total.* += 1;
                }
            }.visit);
            return counted;
        }

        /// A teardown sweep's (dom.teardown_sweeps): call
        /// `visit(context, instance, internal)` for every one of `scope`'s
        /// objects whose state no deinit removed, then clear its field. The
        /// blocks are not returned: this runs at the Browser's end, whose
        /// arena ends wholesale. `visit` must not make objects.
        pub fn sweep(scope: *BrowserScope, context: anytype, comptime visit: fn (@TypeOf(context), *Instance, *T) void) void {
            const Walk = struct {
                context: @TypeOf(context),
                fn each(self: *const @This(), instance: *Instance) void {
                    const field = fieldOf(instance) orelse return;
                    const internal = field.* orelse return;
                    visit(self.context, instance, internal);
                    field.* = null;
                }
            };
            const walk: Walk = .{ .context = context };
            scope.slab.forEachLive(&walk, Walk.each);
        }

        /// A teardown sweep's: deinit every one of `scope`'s states no deinit
        /// reached, and clear their fields (`sweep`).
        pub fn deinitAllAndClear(scope: *BrowserScope) void {
            sweep(scope, {}, struct {
                fn visit(_: void, _: *Instance, internal: *T) void {
                    if (@hasDecl(T, "deinit")) internal.deinit();
                }
            }.visit);
        }
    };
}

/// How many of `scope`'s objects have `State.own._internal` set - the count of
/// `OwnState(State, T).count`, for a caller that may not name `T` (a test
/// names the generated State, never the impl). A slab walk.
pub fn countSet(comptime State: type, scope: *BrowserScope) usize {
    const Walk = struct {
        fn visit(total: *usize, instance: *Instance) void {
            const state = instance.stateAs(State) orelse return;
            if (state.own._internal != null) total.* += 1;
        }
    };
    var counted: usize = 0;
    scope.slab.forEachLive(&counted, Walk.visit);
    return counted;
}
