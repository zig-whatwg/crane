//! Implementation for EventTarget interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-eventtarget
//! WHATWG DOM Standard §2.7

const std = @import("std");
const log = std.log.scoped(.event_target);
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const abort_algorithms = @import("dom").abort_algorithms;
const dom_module = @import("dom");
const event_dispatch = dom_module.event_dispatch;
const EventState = event_dispatch.EventState;
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const infra = @import("infra");
const EventTarget = interfaces.EventTarget;

pub const State = EventTarget.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
};

const listener_list = dom_module.event_listener_list;
const ListenerList = listener_list.List;
const Listener = listener_list.Listener;
const EventTypeKey = listener_list.Key;
const RawHandler = listener_list.RawHandler;

/// Internal state for EventTarget implementation: one pointer.
///
/// DOM 2.7: "Each EventTarget object has an associated event listener list
/// (a list of zero or more event listeners). It is initially the empty
/// list." HTML 8.1.8.1: an EventTarget's "event handler map", whose event
/// handlers are each a value and a listener in that list. Both are ONE block
/// (dom.event_listener_list, lane lis1, plan-v2 N5), made with the first
/// listener or event handler: a handler's value is kept in its listener, as
/// Gecko's `Listener` keeps its handler (`mListenerIsHandler`) and WebKit's
/// attribute listener its function. A target that never has one - nearly
/// every node - allocates nothing (framework-pages.md table D: 60% of a
/// React page's elements, 99.9% of a parsed page's).
pub const InternalState = struct {
    /// Kept by value in this interface's own State (runtime.OwnState, the
    /// State's `_embedded`; lane perf2 batch 5, Z7).
    pub const embedded_in_state = true;

    /// A derived State may leave EventTarget's out (runtime.FlattenedState's
    /// `absent_base`), and Node's does (lane nm3): a node keeps its event
    /// listener list in its rare block, so `Own.get` answers null for a
    /// node and every reader here goes through `Listeners`, which knows
    /// both places.
    pub const may_be_absent = true;

    // No allocator copy (lane perf2 batch 6): what the state owns is
    // allocated from its target's Browser's allocator, runtime.allocatorOf -
    // the allocator a chained target is made with (asserted in initOwn), and
    // the one a lazily made entry uses. On a worker's target that is the
    // worker's scope's: the block assumes no thread.

    /// The event listener list, the event handlers' values in their
    /// listeners, and whether the target's owner watches the list
    /// (dom.event_listener_changes: the flag is the block's, so only a
    /// target whose owner asked pays for it).
    listeners: ListenerList = .{},

    // No current event here (lane perf2 batch 7): DOM 2.3's "current event"
    // is a Window's ("Each Window object has an associated current event"), and
    // only a Window's was ever set - 8 bytes on every target. Window keeps
    // it (as Blink's LocalDOMWindow::current_event_ and Gecko's
    // nsGlobalWindowInner::mEvent), and inner invoke swaps it through
    // dom.window_globals.

    /// VTable.trace_held_nodes (runtime.lifetime.heldNodesOf): what a
    /// chained, non-node target's holder anchor keeps when a collection
    /// reaches its wrapper - its listeners' traced values (`traceOwnListeners`;
    /// refcount step 8). In the atomic pause: read-only.
    pub fn traceHeldNodes(instance: *runtime.Instance, tracer: *engine.Tracer) void {
        traceOwnListeners(instance, tracer);
    }

    /// Deinitialize, releasing the engine values held - the listeners'
    /// callbacks and the event handlers' functions - only when
    /// `release_engine_values`: during final runtime cleanup the engine's
    /// agent is already gone. Native memory (types, raw handlers, the block,
    /// the listeners' signal records in `registry`) is freed either way.
    pub fn deinitEx(self: *InternalState, allocator: std.mem.Allocator, registry: ?*Registry, release_engine_values: bool) void {
        // From the end, each out of the list before it is released.
        while (self.listeners.len() > 0) {
            const listener = self.listeners.removeAt(self.listeners.len() - 1);
            releaseListener(allocator, registry, listener, release_engine_values);
        }
        self.listeners.deinit(allocator);
    }
};

// Every node carried an InternalState: 64 bytes until lane perf2 batch 6
// took out the allocator copy (16) and the lazy entry's record (24), 24
// since batch 7 moved the current event to Window (8), and one pointer since
// lane lis1 made the list, the handler map and the watched flag one block
// made with the first listener (16). Since lane nm3 a node carries none: the
// pointer is a field of its rare block, there only once it has a listener.
comptime {
    if (@sizeOf(InternalState) != 8) @compileError(std.fmt.comptimePrint("EventTarget's InternalState is one pointer, not {d} bytes", .{@sizeOf(InternalState)}));
}

/// Release what a listener taken out of a list owns: its type's copy, its
/// callback or its event handler's value - the engine's values only while
/// `engine_alive` - and the abort steps a signal holds for it, which leave
/// the signal with it (`forgetAbortSteps`; `registry` is its target's
/// Browser's).
fn releaseListener(allocator: std.mem.Allocator, registry: ?*Registry, listener: Listener, engine_alive: bool) void {
    if (listener.bits.abort_steps) forgetAbortSteps(registry, listener.bits.id);
    listener.type.deinit(allocator);
    releaseValue(allocator, listener, engine_alive);
}

/// Release a listener's callback, or an event handler's value.
fn releaseValue(allocator: std.mem.Allocator, listener: Listener, engine_alive: bool) void {
    switch (listener.bits.kind) {
        .listener => if (engine_alive) releaseObject(listener.object, listener.bits.traced),
        .handler => switch (listener.bits.value) {
            .none => {},
            .compiled => if (engine_alive) releaseObject(listener.object, listener.bits.traced),
            .raw => listener.rawHandler().?.destroy(allocator),
        },
    }
}

/// End a listener's hold of its engine value: a traced hold
/// (engine.TracedHold) or a strong one.
fn releaseObject(object: ?*anyopaque, traced: bool) void {
    if (traced) (engine.TracedHold{ .handle = object }).release() else ownedObject(object).release();
}

/// A listener's engine value, BORROWED from its hold: undefined once the
/// collector took a traced one (nothing traced its target), or for none.
fn valueOf(object: ?*anyopaque, traced: bool) runtime.JSValue {
    if (traced) return (engine.TracedHold{ .handle = object }).value();
    return ownedObject(object).value;
}

/// The engine value a list keeps as `object` - a hold of the list's own, as
/// the engine protocol hands it: a callback interface's object or a callback
/// function is an object, whose value is an engine handle. The list keeps
/// the handle alone (8 bytes, not a 32-byte JSValue); the value it stood for
/// is `ownedObject`. Anything else - the undefined value an engine with
/// nothing linked gives - is released and kept as null.
fn packObject(value: engine.Owned) ?*anyopaque {
    return switch (value.value) {
        .handle => |handle| handle.ptr,
        else => {
            value.release();
            return null;
        },
    };
}

/// The owned value `packObject` kept: the same hold, so exactly one of its
/// holders releases it.
fn ownedObject(object: ?*anyopaque) engine.Owned {
    return .{ .value = if (object) |handle| runtime.JSValue.fromHandle(handle) else runtime.JSValue.jsUndefined };
}

/// A listener's callback as the engine protocol takes it - BORROWED from the
/// listener's hold, which its owner (the list, or the caller for a listener
/// just taken out of it) releases.
fn callbackOf(listener: Listener) engine.CallbackInterface {
    return .{ .object = .{ .value = valueOf(listener.object, listener.bits.traced) }, .context = listener.context };
}

// ----------------------------------------------------------------------------
// The list's values, traced from the target at collection time (refcount
// step 8, decision D7; docs/refcount-design.md 3, "event listener closure
// capturing its node"; the trace-time design the integrator approved
// 2026-11-23 6:53 PM ET).
//
// A listener's callback and an event handler's compiled function are TRACED
// holds (engine.TracedHold): no root - the collector keeps one while marking
// reaches it through its target, and takes it when nothing does. A non-node
// target's wrapper is bound to a holder anchor (its type's VTable
// .trace_held_nodes, `InternalState.traceHeldNodes`), in every world, whose
// trace keeps the list's values; a node's list is traced by the walk where it
// visits the node (dom.wrapper_tracing, `traces_held`). So a closure over its
// own target - the commonest listener there is - no longer keeps the target,
// its tree and its realm alive until the realm ends: once script holds none
// of them, they go together; and a listener lives exactly as long as its
// target is reachable, from any world. Adding and removing a listener makes
// no engine call but the hold's own - nothing is rebuilt per change.
//
// - Blink: EventTarget::Trace -> EventListenerMap -> RegisteredEventListener
//   -> JSEventListener's TraceWrapperV8Reference (core/dom/events/,
//   platform/bindings/trace_wrapper_v8_reference.h): traced from the target,
//   rooted nowhere - the same model.
// - WebKit (reference only, LGPL): JSEventListener keeps `JSC::Weak` and the
//   target's wrapper marks it (EventTarget::visitJSEventListeners).
//
// A realm's global (a Window, a worker's global scope) keeps STRONG holds:
// its wrapper is the realm's global object, bound to no holder anchor, and
// lives as long as its realm, whose end weakens what its API kept (the realm
// tag). So does an entry made lazily for an instance that never ran
// EventTarget's init: it lives in its Browser's registry, behind a lock no
// collector's pause may take.
// ----------------------------------------------------------------------------

/// A callback value as a listener keeps it (`Listener.object` and
/// `bits.traced`): a traced hold where its target's list is traced, a strong
/// one otherwise. OWNED until stored.
const Kept = struct {
    object: ?*anyopaque,
    traced: bool,
    context: ?runtime.Context,

    fn release(self: Kept) void {
        releaseObject(self.object, self.traced);
    }

    /// The value, BORROWED.
    fn value(self: Kept) runtime.JSValue {
        return valueOf(self.object, self.traced);
    }

    /// `given` (the binding's, BORROWED for the call) kept for `target`'s
    /// list - traced when `traced`. During the call.
    fn ofInterface(given: runtime.BorrowedCallbackInterface, traced: bool) Kept {
        if (traced) {
            const kept = given.keepTraced();
            return .{ .object = kept.hold.handle, .traced = true, .context = kept.context };
        }
        const kept = given.keep();
        return .{ .object = packObject(kept.object), .traced = false, .context = kept.context };
    }
};

/// Whether `instance`'s list - `listeners` - keeps traced holds: a node's
/// (the walk traces it) and a chained target's own state (its holder anchor
/// does), but not a realm's global or a lazily made entry (`Kept`).
fn tracesValues(listeners: Listeners, instance: *runtime.Instance) bool {
    switch (listeners.place) {
        .node => return true,
        .own => {
            if (Own.get(instance) == null) return false;
            const record = instance.ctx.getRealm() orelse return true;
            const global = record.global_object orelse return true;
            return @intFromPtr(global) != @intFromPtr(instance);
        },
    }
}

/// VTable.trace_held_nodes for every chained, non-node EventTarget
/// (runtime.lifetime.heldNodesOf finds it on this level's state): its holder
/// anchor, reached in a collection's atomic pause, keeps its listeners'
/// traced values. Read-only; no allocation, no lock.
fn traceOwnListeners(instance: *runtime.Instance, tracer: *engine.Tracer) void {
    if (instance.vtable.counted != null) return;
    const internal = Own.get(instance) orelse return;
    for (internal.listeners.view()) |listener| {
        if (listener.bits.traced) engine.traceHeld(tracer, .{ .handle = listener.object });
    }
}

/// A target's event listener list, wherever the target keeps it - what
/// every step below reads and changes the list through.
///
/// - A node keeps its list's address in a slot of its rare block
///   (NodeBase.eventListeners; lane nm3, node-memory plan v2 X2). That block
///   moves when it grows and the list's own block moves when IT grows, so a
///   node's list is never held by address: every call here reads the slot
///   again, and a call that makes or moves the list's block writes the slot
///   back. A handle held across a callback - dispatch's walk - is therefore
///   as good after it as before, whatever the callback added to the node or
///   to its list.
/// - Every other target keeps the list at an address that stays put for the
///   target's life: its own State (a chained target, `Own`) or its lazily
///   made entry (`LazyEntry`).
///
/// WHAT KEEPS A NODE'S HANDLE GOOD ACROSS A CALLBACK (lane lk1, 2026-11-16).
/// `place.node` is a NodeBase's address, and dispatch's walk keeps one
/// across every listener it calls (`innerInvoke`); the items of the path
/// are addresses too. Two things, each enough alone, keep them the nodes
/// they were until the walk ends:
///
/// - NOTHING IS FREED UNDER A CALLBACK. The agent's teardown queue frees no
///   tree and runs no collected wrapper's finalizer while a callback
///   invocation is on its stack (runtime.gc.DeferredTeardown's algorithm
///   depth; engine.callUserObjectOperation counts the invocation): a
///   collection inside a listener only records what it found. The microtask
///   checkpoint after a listener returns runs inside that same invocation
///   (its "clean up after running script"), so a microtask frees nothing
///   either, and between two listeners the walk is native code that queues
///   nothing.
/// - THE PATH HOLDS ITS NODES: one counted reference on every invocation
///   target that is a node, and on every relatedTarget, from before the
///   first listener to dispatch step 9 (dom.event_dispatch
///   `DispatchPath.hold`) - as the three browsers hold every item of the
///   path for the dispatch: WebKit's EventContext keeps `RefPtr<Node>
///   m_node` and `RefPtr<EventTarget> m_currentTarget`
///   (Source/WebCore/dom/EventContext.h), Blink's NodeEventContext
///   `Member<Node> node_` and its WindowEventContext `Member<LocalDOMWindow>
///   window_` (core/dom/events/node_event_context.h,
///   window_event_context.h), Gecko's EventTargetChainItem
///   `nsCOMPtr<EventTarget> mTarget` (dom/events/EventDispatcher.cpp; each
///   read on its main branch, 2026-11-16). A tree with a counted node is
///   never garbage, whenever the queue does run.
///
/// Measured (tests/html/lk1_dispatch_path_holds_test.zig, Debug, lane
/// uaf1's freed-block instrument on): 10 of 10 as the code is; 10 of 10
/// with the path's references taken out; 10 of 10 with the queue made to
/// free at every binding exit; and with BOTH taken out the walk comes back
/// to two freed path nodes whose slots new nodes have taken, and calls the
/// new nodes' listeners. Keep both.
///
/// The one free made whatever the counts say is a realm's end, and that
/// runs from a task of its own, never under a dispatch: a removed frame's
/// realm is detached and ends once the collector has taken it. `stands`
/// (below) is the net for that free; it is not what keeps the node. A path
/// item that is not a node - the Window - has no count: only its realm's
/// end, that same task, frees it.
///
/// 16 bytes, passed by value. `view` is BORROWED as the list's is: valid
/// until the list next changes, so never across a call that can run script.
const Listeners = struct {
    place: Place,

    const Place = union(enum) {
        node: *dom_module.NodeBase,
        own: *ListenerList,
    };

    /// The list as it is now. A node torn down since this handle was made
    /// (a callback of the dispatch that holds it ended the node's realm)
    /// reads as empty: its NodeBase's fields are gone, its bytes are not
    /// (NodeBase.stands) - as a chained target's State reads an empty list
    /// after its teardown.
    inline fn current(self: Listeners) ListenerList {
        return switch (self.place) {
            .node => |node| if (node.stands()) node.eventListeners() else .{},
            .own => |list| list.*,
        };
    }

    inline fn len(self: Listeners) usize {
        return self.current().len();
    }

    inline fn view(self: Listeners) []const Listener {
        return self.current().view();
    }

    inline fn at(self: Listeners, index: usize) Listener {
        return self.current().at(index);
    }

    inline fn watched(self: Listeners) bool {
        return self.current().watched();
    }

    inline fn indexOfId(self: Listeners, id: u56) ?usize {
        return self.current().indexOfId(id);
    }

    inline fn indexOfHandler(self: Listeners, key: EventTypeKey) ?usize {
        return self.current().indexOfHandler(key);
    }

    /// The event handler listener for `key` of `world` (`HandlerWorld`):
    /// with no world scope - every Browser that made no isolated world - the
    /// one handler of the type, as `indexOfHandler`.
    fn indexOfHandlerIn(self: Listeners, key: EventTypeKey, world: HandlerWorld) ?usize {
        const scope = world orelse return self.indexOfHandler(key);
        for (self.view(), 0..) |listener, i| {
            if (listener.bits.kind == .handler and listener.type.matches(key) and handlerListenerWorld(listener) == scope) return i;
        }
        return null;
    }

    inline fn clone(self: Listeners) ?listener_list.Cursor {
        return self.current().clone();
    }

    inline fn next(self: Listeners, cursor: *listener_list.Cursor) ?Listener {
        return self.current().next(cursor);
    }

    // The three below change the list inside its block, which stays where
    // it is: a copy of the list's address is enough.

    fn removeAt(self: Listeners, index: usize) Listener {
        var list = self.current();
        return list.removeAt(index);
    }

    fn replaceAt(self: Listeners, index: usize, listener: Listener) Listener {
        var list = self.current();
        return list.replaceAt(index, listener);
    }

    fn appendAssumeCapacity(self: Listeners, listener: Listener) void {
        var list = self.current();
        list.appendAssumeCapacity(listener);
    }

    // The two below can make the list's block or move it. A node's slot is
    // given its place in the rare block FIRST - the one step of the two that
    // can fail after the other succeeded - so a failure leaves the list as
    // it was, and the write-back cannot fail.

    fn ensureUnusedCapacity(self: Listeners, allocator: std.mem.Allocator, count: usize) error{OutOfMemory}!void {
        switch (self.place) {
            .own => |list| try list.ensureUnusedCapacity(allocator, count),
            .node => |node| {
                // A node torn down under this handle keeps nothing.
                if (!node.stands()) return error.OutOfMemory;
                var list = node.eventListeners();
                // Room already (a node whose listeners come and go keeps
                // its block): nothing moves, nothing to write back.
                if (list.hasUnusedCapacity(count)) return;
                // The rare block may move here; the list's own block, which
                // `list` names, does not.
                const made = !node.hasEventListenerBlock();
                try node.reserveEventListeners();
                try list.ensureUnusedCapacity(node.satelliteAllocator(), count);
                node.setEventListeners(list);
                // Its first block: the walk traces it from here.
                if (made) if (node.registeredInstance()) |instance| dom_module.wrapper_tracing.noteNodeHoldsValues(instance, node);
            },
        }
    }

    fn watch(self: Listeners, allocator: std.mem.Allocator) error{OutOfMemory}!void {
        switch (self.place) {
            .own => |list| try list.watch(allocator),
            .node => |node| {
                if (!node.stands()) return error.OutOfMemory;
                try node.reserveEventListeners();
                var list = node.eventListeners();
                try list.watch(node.satelliteAllocator());
                node.setEventListeners(list);
            },
        }
    }

    /// The target is going: release what every listener owns - its type's
    /// copy, and its callback or event handler value, the engine's only
    /// while `engine_alive` - then free the list's block. The list is empty
    /// after.
    fn release(self: Listeners, allocator: std.mem.Allocator, registry: ?*Registry, engine_alive: bool) void {
        var list = self.current();
        if (list.header == null) return;
        // From the end, each out of the list before it is released.
        while (list.len() > 0) {
            const listener = list.removeAt(list.len() - 1);
            releaseListener(allocator, registry, listener, engine_alive);
        }
        list.deinit(switch (self.place) {
            .own => allocator,
            .node => |node| node.satelliteAllocator(),
        });
        switch (self.place) {
            .own => |own| own.* = list,
            .node => |node| node.setEventListeners(list),
        }
    }
};

/// The NodeBase of `target` when it is a node whose NodeBase still stands -
/// where a node's event listener list is (`Listeners`) - else null: any
/// other target, a freed slot, and a node its teardown has released.
///
/// The vtable says whether it is a node (`counted`: runtime.lifetime's
/// predicate, Node's state on the chain), and a node's NodeBase is at one
/// offset of its State block (dom.node_base.ofLiveNode): two loads and a
/// bit test, no call. A freed slot's first word is the slab's free-list
/// pointer, not a vtable: its stamp is read first.
inline fn nodeOf(target: *runtime.Instance) ?*dom_module.NodeBase {
    if (runtime.SlabAllocator.generationOf(target) == runtime.SlabAllocator.dead_generation) return null;
    if (target.vtable.counted == null) return null;
    return dom_module.node_base.ofLiveNode(target);
}

/// `target`'s event listener list, or null when it keeps none: an instance
/// that never ran EventTarget's init and has no lazy entry yet, or a target
/// torn down. A node with a NodeBase always answers: its list is empty until
/// its first listener, and reading an empty list allocates nothing.
fn listenersOf(target: *runtime.Instance) ?Listeners {
    if (nodeOf(target)) |node| return .{ .place = .{ .node = node } };
    const internal = getInternalFromRegistry(target) orelse return null;
    return .{ .place = .{ .own = &internal.listeners } };
}

/// `target`'s event listener list, made for an instance that never ran
/// EventTarget's init (`lazyInternal`).
fn ensureListeners(target: *runtime.Instance) !Listeners {
    if (nodeOf(target)) |node| return .{ .place = .{ .node = node } };
    const internal = try lazyInternal(target);
    return .{ .place = .{ .own = &internal.listeners } };
}

/// dom.event_handlers.releaseNodeListeners: `node` is being torn down - by
/// its own deinit or by its Browser's final sweep, both while the agent
/// lives - and its rare block goes next (Node's releaseNodeBase).
fn releaseNodeListeners(node: *runtime.Instance) void {
    const base = dom_module.instance_bridge.getNodeBaseUnaudited(node) orelse return;
    const listeners: Listeners = .{ .place = .{ .node = base } };
    listeners.release(runtime.allocatorOf(node), registryOf(node), true);
}

/// What an entry made lazily records about the instance it was made for.
///
/// 236 impls of EventTarget's descendants (EventSource until 2026-10-01,
/// OffscreenCanvas, Performance, the IDB requests, the Audio, Sensor and
/// Bluetooth stubs ...) make their instance with runtime.Instance.init and
/// never chain to EventTarget's init or deinit, so their first
/// addEventListener makes the entry here and nothing removes it when the
/// instance goes. A worker's such entry outlived the worker's agent, and the
/// browser's end released its listener's handle into the disposed isolate
/// (eventsource/format-bom.any.js, at a sweep shard's exit: "Check failed:
/// node->IsInUse()").
///
/// An entry made lazily is its own block of its instance's Browser's arena:
/// the state, then this record (lane perf2 batch 6: the record was a field of
/// every InternalState, 24 bytes on every node, where only these entries use
/// it). Every entry of the Browser's `Registry` is one of these.
const LazyEntry = struct {
    /// The state the registry hands out (`getInternalFromRegistry`).
    state: InternalState = .{},
    /// The instance's realm. Its end releases the entry
    /// (`releaseRealmEntries`, an unloading cleanup step), while the realm's
    /// agent lives: listeners go with their realm.
    realm: runtime.Context,
    /// INTERIM until every EventTarget impl chains init/deinit (queue): the
    /// instance's slab generation. An entry whose instance was freed stays
    /// here until its realm ends, keyed by an address the slab hands out
    /// again; the instance that gets the slot must not inherit the dead
    /// one's listeners (`getInternalFromRegistry`). A chained impl removes
    /// its entry in deinit, and then this goes.
    generation: u64 = 0,

    /// The entry `internal` is the state of: only for a state the
    /// registry's map holds, every one of which was made lazily.
    fn of(internal: *InternalState) *LazyEntry {
        return @fieldParentPtr("state", internal);
    }
};

/// The internal state of an EventTarget whose impl chains EventTarget's
/// init - every node, and every other type whose chain runs `initOwn` - in
/// the instance's own State (`own._internal`, runtime.OwnState): read on
/// every listener call and every dispatch, it is a field of the object, not
/// an entry of a locked table (lane perf2, batch 2). The `Registry` below
/// keeps only the entries made lazily (`LazyEntry`).
const Own = runtime.OwnState(State, InternalState);

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // A lazily made entry's realm end releases it (`lazyInternal`).
    dom_module.unloading_cleanup.install(&releaseRealmEntries);
    // Its Browser's end releases what every entry left holds, first
    // (Browser.deinit; dom.teardown_sweeps).
    dom_module.teardown_sweeps.install(.event_targets, &sweepRemaining);
    // No event can be fired before a target exists.
    @import("dom").fire_event.install(.{
        .dispatch_trusted = dispatchTrusted,
        .dispatch_trusted_legacy_target_override = dispatchTrustedLegacyTargetOverride,
        .dispatch_trusted_with_throws = dispatchTrustedWithThrows,
        .dispatch_trusted_in_world = dispatchTrustedInWorld,
    });
    dom_module.event_handlers.install(.{
        .get = getHandlerValue,
        .set = setHandlerValue,
        .set_raw = setRawEventHandler,
        .deactivate_content_attribute = deactivateContentAttributeHandler,
        .erase = eraseAllEventListenersAndHandlers,
        .has_listeners = hasListeners,
        .release_node_listeners = releaseNodeListeners,
    });
    dom_module.event_listener_types.install(hasListenersOfType);
    dom_module.event_listener_changes.install(watchListeners);
}

/// dom.event_listener_changes.watch: from now on, every change of
/// `target`'s event listener list calls the owners' steps
/// (`listenersChanged`). Its owner calls this from its construction steps.
fn watchListeners(target: *runtime.Instance) error{OutOfMemory}!void {
    const listeners = ensureListeners(target) catch return error.OutOfMemory;
    try listeners.watch(runtime.allocatorOf(target));
}

/// After `target`'s event listener list changed - a listener appended, or
/// one removed - tell its owner, if it asked (dom.event_listener_changes;
/// WebKit's EventTarget::eventListenersDidChange, called after
/// addEventListener, a removeEventListener that removed, and
/// removeAllEventListeners). One bit test in the block for every other
/// target. Never from a teardown: the list goes with the target.
inline fn listenersChanged(listeners: Listeners, target: *runtime.Instance) void {
    if (listeners.watched()) dom_module.event_listener_changes.changed(target);
}

/// EventTarget's own construction steps, the first of every EventTarget's
/// chain: the generated root makes the instance, then this registers
/// EventTarget's internal state.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = args;
    // A node's State nests no EventTarget State (`may_be_absent`): its
    // event listener list is a field of its rare block, made with its first
    // listener. Its Browser's table is still made known here, as for every
    // chained target.
    if (comptime leavesOutOwnState(StateType)) return noteScope(instance, allocator);
    // Its internal state, in its own State.
    _ = try initInternal(instance, allocator);
}

/// Whether `StateType` - the State of the interface being made - is of a
/// chain whose root leaves EventTarget's State out (`absent_base`): a
/// node's.
fn leavesOutOwnState(comptime StateType: type) bool {
    comptime {
        var Level: type = StateType;
        while (true) {
            if (@typeInfo(Level) != .@"struct") return false;
            if (@hasDecl(Level, "absent_base")) {
                if (Level.absent_base) |Absent| return Absent == State;
            }
            if (!@hasField(Level, "base")) return false;
            const Base = @FieldType(Level, "base");
            if (Base == void) return false;
            Level = Base;
        }
    }
}

/// EventTarget's own teardown, the last of every EventTarget's destruction
/// chain. The slot itself is the collector's to free, or the queue's.
pub fn deinitOwn(instance: *runtime.Instance) void {
    if (Own.get(instance)) |internal| {
        internal.deinitEx(runtime.allocatorOf(instance), registryOf(instance), true);
        Own.remove(instance);
        return;
    }
    // A node keeps no state of this level: its listeners went with its
    // NodeBase, in Node's part of the chain, which ran before this
    // (`releaseNodeListeners`). The chain reaches here for every node torn
    // down, so the table below - a lock and a hash lookup - is not asked
    // for one: an entry made lazily for a node after its teardown leaves at
    // its realm's end, as it did when it was made after this ran.
    if (instance.vtable.counted != null) return;
    // An entry made lazily for it after its own state went (a listener added
    // to a torn-down target).
    if (getInternalFromRegistry(instance)) |internal| {
        internal.deinitEx(runtime.allocatorOf(instance), registryOf(instance), true);
        removeFromRegistry(instance);
    }
}

/// Constructor implementation
/// Spec: https://dom.spec.whatwg.org/#dom-eventtarget-eventtarget
pub fn call_constructor(instance: *runtime.Instance) !void {
    _ = instance;
}

/// Initialize an EventTarget's internal state, in its own State: a block of
/// its Browser's arena (runtime.OwnState), returned by `deinitOwn`.
fn initInternal(instance: *runtime.Instance, allocator: std.mem.Allocator) !*InternalState {
    try noteScope(instance, allocator);
    const internal = try Own.create(instance);
    internal.* = .{};
    return internal;
}

/// What every chained target's construction does first, a node's included:
/// its Browser's table exists and knows its scope, and the allocator the
/// target is made with is that Browser's.
fn noteScope(instance: *runtime.Instance, allocator: std.mem.Allocator) !void {
    // The table's end releases what no deinit and no sweep reached - a scope
    // with no Browser (runtime.initializeRuntime's) runs no sweeps - so it
    // must exist, and know its scope, once a state is made here.
    const registry = try registryFor(instance);
    if (registry.scope.load(.monotonic) == null) registry.scope.store(runtime.BrowserScope.ofInstance(instance), .release);
    // What the state owns is allocated from its Browser's allocator
    // (runtime.allocatorOf), found from its address: so the allocator it was
    // made with must BE that one - true in a Browser, whose realms are given
    // its scope's allocator; a test realm is given its scope's too (lane perf2
    // batch 6, docs/lessons/architecture-a-nodes-creation-allocator-is-its-
    // browsers-only-inside-a-browser.md). Workers' targets included: a
    // worker's realm carries its owner's Browser scope
    // (tests/html/perf2b6_worker_target_allocator_test.zig).
    if (std.debug.runtime_safety and !runtime.isScopeAllocator(instance, allocator))
        std.debug.panic("an EventTarget ({s}) made with an allocator that is not its Browser's (runtime.allocatorOf would free through another)", .{instance.vtable.name});
}

/// One Browser's lazily made EventTarget states (`LazyEntry`) - a side table
/// of its runtime.BrowserScope (`.event_targets`, instances B1): a Browser's
/// entries are its own, its end takes them with it, and no other Browser's
/// end reaches them. Every other EventTarget's state is in its own State
/// (`Own`).
///
/// Every lazy entry of every thread of the Browser is here - its window
/// thread and each of its workers' (docs/instances.md) - so the map is
/// reached only under `mutex`. A value is a block its instance's thread
/// allocated and frees, so a pointer read under the lock stays good after it;
/// what an entry holds of the engine (listeners' callbacks, event handlers) is
/// released OUTSIDE the lock, on the entry's own thread (`releaseEntry`).
pub const Registry = struct {
    /// Protects `map` and `guard`; held for one map operation or one sweep
    /// of the map, never across a call that can reach the engine or script.
    mutex: std.Io.Mutex = .init,
    map: ?infra.address_map.AddressHashMap(usize, *InternalState) = null,
    allocator: std.mem.Allocator,
    /// A lazy entry leaves the registry at its realm's end, or when its
    /// instance's state is torn down; the guard rehashes before an insert
    /// once the tombstones those removals leave could take half the free
    /// slots (webidl.utils.tombstones).
    guard: webidl.utils.tombstones.TombstoneGuard = .{},
    /// The scope this table is a side table of, recorded by the first state
    /// made in it (`initInternal`): its end walks the scope's slab for the
    /// chained states left, as it releases the lazy entries left.
    scope: std.atomic.Value(?*runtime.BrowserScope) = .init(null),
    /// The Browser's listeners that a signal holds abort steps for
    /// (`Bits.abort_steps`), by listener id: each one's `SignalRemoval`,
    /// so the record leaves its signal when its listener leaves its list
    /// (`forgetAbortSteps`). Under `mutex`. A record here is still in its
    /// signal's abort algorithms, or in its abort walk; whoever takes it out
    /// of this map decides who frees it (`SignalRemoval`).
    signal_removals: std.AutoHashMapUnmanaged(u64, *SignalRemoval) = .empty,
    removals_guard: webidl.utils.tombstones.TombstoneGuard = .{},

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{ .allocator = allocator };
    }

    /// The Browser's scope ends, after its agent: what entries made since its
    /// sweep (`sweepRemaining`) still hold is released without the engine,
    /// which is gone. Their blocks go with the Browser's arena.
    pub fn deinit(self: *Registry) void {
        // The chained states left (Own): a walk of the scope's slab, which
        // ends after its tables. Without the engine, which is gone.
        if (self.scope.load(.acquire)) |scope| {
            Own.sweep(scope, self, struct {
                fn visit(registry: *Registry, instance: *runtime.Instance, internal: *InternalState) void {
                    internal.deinitEx(runtime.allocatorOf(instance), registry, false);
                }
            }.visit);
            // And the nodes left with a NodeBase (a scope no Browser swept):
            // their lists are fields of their rare blocks.
            releaseNodesListeners(scope, self, false);
        }
        if (self.takeAll()) |taken| {
            var map = taken;
            // Every entry is this scope's: its allocator is this table's.
            var iter = map.valueIterator();
            while (iter.next()) |internal_ptr| internal_ptr.*.deinitEx(self.allocator, self, false);
            map.deinit();
        }
        // Records whose listeners no release reached. Each leaves a signal
        // that still lists it (its slot is still the signal's: the slab ends
        // after the tables) and is freed: no abort walk runs at a Browser's
        // end, and a signal torn down already dropped its records, which
        // took them out of this map.
        var removals = self.signal_removals.valueIterator();
        while (removals.next()) |record| {
            if (record.*.signalStands()) _ = abort_algorithms.removeListed(record.*.signal, record.*);
            self.allocator.destroy(record.*);
        }
        self.signal_removals.deinit(self.allocator);
    }

    /// Index `record` under its listener's id. Locks `mutex`.
    fn putRemoval(self: *Registry, record: *SignalRemoval) error{OutOfMemory}!void {
        self.lock();
        defer self.unlock();
        self.removals_guard.beforeInsert(&self.signal_removals);
        try self.signal_removals.put(self.allocator, record.listener_id, record);
    }

    /// Take the record indexed under listener `id`, if any. Locks `mutex`.
    /// A table that empties after a large one gives its slots back.
    fn takeRemoval(self: *Registry, id: u56) ?*SignalRemoval {
        self.lock();
        defer self.unlock();
        const kv = self.signal_removals.fetchRemove(id) orelse return null;
        self.removals_guard.noteRemoval(&self.signal_removals);
        if (self.signal_removals.count() == 0 and self.signal_removals.capacity() > 64) {
            self.signal_removals.clearAndFree(self.allocator);
            self.removals_guard.reset();
        }
        return kv.value;
    }

    fn lock(self: *Registry) void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
    }

    fn unlock(self: *Registry) void {
        std.Io.Threaded.mutexUnlock(&self.mutex);
    }

    /// The map, made on first use. Called with `mutex` held.
    fn ensure(self: *Registry) *infra.address_map.AddressHashMap(usize, *InternalState) {
        if (self.map == null) self.map = infra.address_map.AddressHashMap(usize, *InternalState).init(self.allocator);
        return &self.map.?;
    }

    /// Take `key`'s entry out of the map. Called with `mutex` held; the
    /// caller releases it (`releaseEntry`) after unlocking.
    fn take(self: *Registry, key: usize) ?*InternalState {
        const map = &(self.map orelse return null);
        const kv = map.fetchRemove(key) orelse return null;
        self.guard.noteRemoval(map);
        return kv.value;
    }

    /// The whole map, taken out for a final sweep. Called with `mutex` held,
    /// or by the table's own end.
    fn takeAll(self: *Registry) ?infra.address_map.AddressHashMap(usize, *InternalState) {
        const map = self.map orelse return null;
        self.map = null;
        self.guard.reset();
        return map;
    }
};

/// `instance`'s Browser's registry, made on first use.
fn registryFor(instance: *runtime.Instance) !*Registry {
    return runtime.BrowserScope.ofInstance(instance).table(.event_targets, Registry);
}

/// `instance`'s Browser's registry, if it has one.
fn registryOf(instance: *runtime.Instance) ?*Registry {
    return runtime.BrowserScope.ofInstance(instance).existingTable(.event_targets, Registry);
}

/// dom.teardown_sweeps, first: at its Browser's end, release what every one
/// of `scope`'s remaining entries holds of the engine (listeners' callbacks,
/// event handlers) - BEFORE its agent ends (Browser.deinit), and after every
/// worker of the Browser has ended, so every entry left is this thread's.
fn sweepRemaining(scope: *runtime.BrowserScope) void {
    // The chained EventTargets no deinit reached: a walk of the Browser's
    // slab (runtime.OwnState.sweep), each field cleared after.
    const registry = scope.existingTable(.event_targets, Registry);
    Own.sweep(scope, registry, struct {
        fn visit(table: ?*Registry, instance: *runtime.Instance, internal: *InternalState) void {
            internal.deinitEx(runtime.allocatorOf(instance), table, true); // the agent is alive: release its values
        }
    }.visit);
    // The nodes no deinit reached: their lists are fields of their rare
    // blocks, which the `.nodes` sweep frees later, with nothing left to
    // release.
    releaseNodesListeners(scope, registry, true);
    // Then the lazy entries.
    const table = registry orelse return;
    table.lock();
    var taken = table.takeAll();
    table.unlock();
    if (taken) |*map| {
        var iter = map.valueIterator();
        while (iter.next()) |internal_ptr| {
            internal_ptr.*.deinitEx(table.allocator, table, true); // the agent is alive: release its values
        }
        map.deinit();
    }
}

/// Release the event listener list of every node of `scope` whose NodeBase
/// still stands - a walk of the Browser's slab, for its end. The engine's
/// values only while `engine_alive`; the listeners' signal records are
/// `registry`'s, the scope's table.
fn releaseNodesListeners(scope: *runtime.BrowserScope, registry: ?*Registry, engine_alive: bool) void {
    const Walk = struct {
        registry: ?*Registry,
        engine_alive: bool,
        fn visit(self: *const @This(), node: *dom_module.NodeBase) void {
            if (!node.hasEventListenerBlock()) return;
            const listeners: Listeners = .{ .place = .{ .node = node } };
            listeners.release(node.allocator(), self.registry, self.engine_alive);
        }
    };
    const walk: Walk = .{ .registry = registry, .engine_alive = engine_alive };
    dom_module.instance_bridge.visitNodes(scope, std.math.maxInt(usize), &walk, Walk.visit);
}

fn getInternalFromRegistry(instance: *runtime.Instance) ?*InternalState {
    // A chained EventTarget's state: a field of the object.
    if (Own.get(instance)) |internal| return internal;
    // Otherwise an entry made lazily, if any.
    const registry = registryOf(instance) orelse return null;
    registry.lock();
    const map = registry.ensure();
    const internal = map.get(@intFromPtr(instance)) orelse {
        registry.unlock();
        return null;
    };
    // INTERIM until every EventTarget impl chains init/deinit (queue): an
    // entry made lazily for an instance that has since been freed, whose slot
    // this instance now has. The listeners are the dead instance's: they go
    // now - its realm still lives, or its end would have released the entry -
    // and this instance has none.
    if (LazyEntry.of(internal).generation != runtime.SlabAllocator.generationOf(instance)) {
        const stale = registry.take(@intFromPtr(instance));
        registry.unlock();
        if (stale) |entry| releaseEntry(@intFromPtr(instance), entry);
        return null;
    }
    registry.unlock();
    return internal;
}

fn setInternalInRegistry(instance: *runtime.Instance, internal: *InternalState) !void {
    const registry = try registryFor(instance);
    var stale: ?*InternalState = null;
    defer if (stale) |entry| releaseEntry(@intFromPtr(instance), entry);
    registry.lock();
    defer registry.unlock();
    const map = registry.ensure();
    // A lazily made entry still under this address is a freed instance's
    // (see `LazyEntry`): it goes before the new one takes its place, rather
    // than being overwritten with its listeners still held.
    if (map.get(@intFromPtr(instance))) |old| {
        if (old != internal) stale = registry.take(@intFromPtr(instance));
    }
    registry.guard.beforeInsert(map);
    try map.put(@intFromPtr(instance), internal);
}

/// The entry for an instance that never ran EventTarget's init (see
/// `LazyEntry`), made on its first addEventListener.
fn lazyInternal(instance: *runtime.Instance) !*InternalState {
    if (getInternalFromRegistry(instance)) |internal| return internal;
    const entry = try runtime.arenaOf(instance).create(LazyEntry);
    errdefer runtime.arenaOf(instance).destroy(LazyEntry, entry);
    entry.* = .{ .realm = instance.ctx, .generation = runtime.SlabAllocator.generationOf(instance) };
    try setInternalInRegistry(instance, &entry.state);
    return &entry.state;
}

/// Release an entry taken out of the registry and what it holds - its
/// listeners' callbacks and its event handlers. Only for an entry whose
/// realm's agent lives, on that agent's thread, with the registry unlocked.
/// `address` is its instance's: the block goes back to that instance's
/// Browser's arena (runtime.arenaOf), where it was made.
fn releaseEntry(address: usize, internal: *InternalState) void {
    const instance: *runtime.Instance = @ptrFromInt(address);
    internal.deinitEx(runtime.allocatorOf(instance), registryOf(instance), true);
    runtime.arenaOf(instance).destroy(LazyEntry, LazyEntry.of(internal));
}

/// EventTarget's unloading cleanup step (dom.unloading_cleanup): the entries
/// made lazily for `environment`'s instances leave with it - nothing else
/// removes them (see `LazyEntry`) - and what they hold is released now,
/// while the realm's agent lives. A worker's agent ends right after its
/// realm, and the browser's end, which releases whatever is left here, is
/// too late for it.
fn releaseRealmEntries(environment: runtime.Context) void {
    // The realm's Browser's entries: its objects are that Browser's.
    const scope = environment.browserScope() orelse return;
    const registry = scope.existingTable(.event_targets, Registry) orelse return;
    // The lists live for this call: the Browser's allocator, as the table's
    // own (allocator mapped pages for them at every realm end).
    const allocator = registry.allocator;
    const Doomed = struct { address: usize, internal: *InternalState };
    var doomed: std.ArrayListUnmanaged(Doomed) = .empty;
    defer doomed.deinit(allocator);
    {
        registry.lock();
        defer registry.unlock();
        const map = &(registry.map orelse return);
        var keys: std.ArrayListUnmanaged(usize) = .empty;
        defer keys.deinit(allocator);
        var it = map.iterator();
        while (it.next()) |entry| {
            if (LazyEntry.of(entry.value_ptr.*).realm == environment) keys.append(allocator, entry.key_ptr.*) catch continue;
        }
        // Room first: an entry taken out must reach `releaseEntry`. Out of
        // memory, the entries stay in the map for the Browser's end.
        doomed.ensureTotalCapacity(allocator, keys.items.len) catch return;
        for (keys.items) |key| {
            const taken = registry.take(key) orelse continue;
            doomed.appendAssumeCapacity(.{ .address = key, .internal = taken });
        }
    }
    for (doomed.items) |entry| releaseEntry(entry.address, entry.internal);
}

fn removeFromRegistry(instance: *runtime.Instance) void {
    const registry = registryOf(instance) orelse return;
    registry.lock();
    const taken = registry.take(@intFromPtr(instance));
    registry.unlock();
    // Return the block, not just the map entry: EventTarget keeps its own
    // registry of lazy entries rather than using InstanceRegistry, so it needs
    // its own release.
    if (taken) |internal| {
        runtime.arenaOf(instance).destroy(LazyEntry, LazyEntry.of(internal));
    }
}

/// DOM §2.7 - default passive value
/// The default passive value, given an event type type and an EventTarget eventTarget
fn defaultPassiveValue(@"type": []const u8, event_target: *runtime.Instance) bool {
    // DOM default passive value step 1: the four types AND the specified
    // targets. Chrome/Safari ship this; Firefox's older target defaults lag.
    // Check the common non-passive type first, without walking any tree.
    if (!std.mem.eql(u8, @"type", "touchstart") and !std.mem.eql(u8, @"type", "touchmove") and
        !std.mem.eql(u8, @"type", "wheel") and !std.mem.eql(u8, @"type", "mousewheel")) return false;
    if (event_target.stateAs(interfaces.Window.State) != null) return true;
    const node_type = interfaces.Node.get_nodeType(event_target) catch return false;
    if (node_type == interfaces.Node.get_DOCUMENT_NODE()) return true;
    const document = (interfaces.Node.get_ownerDocument(event_target) catch null) orelse return false;
    if ((interfaces.Document.get_documentElement(document) catch null) == event_target) return true;
    if ((interfaces.Document.get_body(document) catch null) == event_target) return true;
    // Step 2: all other targets, including plain EventTargets, are false.
    return false;
}

/// DOM "event listener whose callback is callback": two callback interface
/// values are the same listener's when they are the same object (SameValue).
/// `kept` is a listener's (`Listener.object`), `given` the argument's.
fn callbackEquals(realm: runtime.Context, kept: Listener, given: ?runtime.JSValue) bool {
    const y = given orelse return false;
    return engine.sameValue(realm, valueOf(kept.object, kept.bits.traced), y);
}

/// The next listener's id: a listener is found by id only in its own
/// target's list (a signal's removal steps, dispatch's clone), so an id
/// needs no owner - only uniqueness, and that a target's next listener has a
/// greater one than its last: one counter, read with a fetch-add, gives each
/// thread increasing values, and a target's list is changed on its own
/// thread only (dom.event_listener_list `Cursor`).
// process-wide: an id counter whose only property is uniqueness in the process (a listener is found by id only in its target's list); written with an atomic fetch-add from every thread that runs script, it carries no state of any instance.
var next_listener_id: std.atomic.Value(u64) = .init(1);

fn nextListenerId() u56 {
    const id = next_listener_id.fetchAdd(1, .monotonic);
    // 2^56 listeners at one a nanosecond is two years of nothing else.
    return std.math.cast(u56, id) orelse @panic("event listener ids exhausted");
}

/// The abort steps of "add an event listener" step 6, as the signal holds
/// them: a small record of the Browser's allocator (its target's,
/// runtime.allocatorOf), indexed by its listener's id in the Browser's
/// `Registry` while its listener is in a list (`Bits.abort_steps`).
///
/// The target is held by address and slab generation, because it can be
/// collected first - nothing V8 sees keeps it alive for the signal's sake -
/// the listener by id, and the signal by address and generation, for the
/// listener's side to take the steps off it.
///
/// Who frees it is who takes it off the signal's abort algorithms:
/// - the signal: `run` when it aborts (its walk took the list), `drop` when it
///   is torn down unaborted; each takes the index entry first, if still there;
/// - the listener's side, when the listener leaves its list - removed,
///   fired `once`, erased, or torn down with its target (`forgetAbortSteps`):
///   it takes the index entry, then the algorithm off a signal that still
///   lists it (dom.abort_algorithms.removeListed), and frees it only then. A
///   signal whose abort walk holds it (an earlier algorithm of the walk
///   removed the listener) lists it no more: the walk runs it and frees it.
///
/// Before lane leak3 this was one std.heap.page_allocator page per listener
/// (16 KiB on macOS, a mapping on Linux), left on the signal by a listener
/// removed any other way until the signal aborted or died (allocator-
/// hardening design 10.1 item 3; docs/lessons/architecture-std-heap-page-
/// allocator-maps-a-page-per-allocation.md). The design is Gecko's: a
/// listener's ListenerSignalFollower unfollows its signal when the listener
/// is removed (dom/events/EventListenerManager.cpp, `RemoveEventListenerInternal`
/// and `ListenerSignalFollower`; read, not copied - MPL), where WebKit's
/// algorithm stays on the signal until it aborts (EventTarget::addEventListener,
/// `signal->addAlgorithm`). Blink's signal holds its algorithms weakly, by a
/// handle the listener keeps (abort_signal.h `AlgorithmHandle`), which ends
/// the same way: gone with the listener.
const SignalRemoval = struct {
    target: *runtime.Instance,
    target_generation: u64,
    signal: *runtime.Instance,
    signal_generation: u64,
    listener_id: u56,

    /// Whether the signal's slot is still the signal's.
    fn signalStands(self: *const SignalRemoval) bool {
        return runtime.SlabAllocator.generationOf(self.signal) == self.signal_generation;
    }

    /// The signal took it off its abort algorithms to run it or drop it, so
    /// it is the caller's to free: off the index first, if the listener's
    /// side has not taken it (it may have, while the walk held it). Returns
    /// the Browser's table, if it still has one. Its scope is read from the
    /// signal's address, which answers until the Browser ends.
    fn unindex(self: *SignalRemoval) struct { ?*Registry, std.mem.Allocator } {
        const scope = runtime.BrowserScope.ofInstance(self.signal);
        const registry = scope.existingTable(.event_targets, Registry);
        if (registry) |table| _ = table.takeRemoval(self.listener_id);
        return .{ registry, scope.allocator };
    }

    fn run(ctx: *anyopaque) void {
        const self: *SignalRemoval = @ptrCast(@alignCast(ctx));
        // Off the index before the listener goes, so its release below finds
        // nothing to take off the signal (its walk has the list).
        const registry, const allocator = self.unindex();
        defer allocator.destroy(self);
        // "Remove an event listener with eventTarget and listener."
        if (runtime.SlabAllocator.generationOf(self.target) != self.target_generation) return;
        const listeners = listenersOf(self.target) orelse return;
        const index = listeners.indexOfId(self.listener_id) orelse return;
        // "Set listener's removed to true and remove listener from
        // eventTarget's event listener list": out of the list, it is out of
        // every clone a dispatch walks (dom.event_listener_list `Cursor`).
        const removed = listeners.removeAt(index);
        releaseListener(runtime.allocatorOf(self.target), registry, removed, true);
        listenersChanged(listeners, self.target);
    }

    fn drop(ctx: *anyopaque) void {
        const self: *SignalRemoval = @ptrCast(@alignCast(ctx));
        _, const allocator = self.unindex();
        allocator.destroy(self);
    }
};

/// The listener `id` left its target's list and has abort steps on a signal
/// (`Bits.abort_steps`): take its record off the signal and free it - unless
/// the signal's abort walk holds the record, which then runs it and frees it
/// (`SignalRemoval`). `registry` is the target's Browser's.
fn forgetAbortSteps(registry: ?*Registry, id: u56) void {
    const table = registry orelse return;
    // Not indexed: the signal ran or dropped it already, or arming it failed.
    const record = table.takeRemoval(id) orelse return;
    // A signal whose slot was freed without its teardown dropping its
    // algorithms holds nothing any more; one that stands gives it up only if
    // it still lists it.
    if (record.signalStands() and !abort_algorithms.removeListed(record.signal, record)) return;
    table.allocator.destroy(record);
}

/// "Add an event listener" step 6 for the listener `id` just appended to
/// `instance`'s list with `abort_steps` set: give `signal` the abort steps
/// that remove it. Its record is indexed first, so a failure after the
/// listener was stored leaves it registered with no steps, "as an
/// allocation failure anywhere else would" - and its bit finds no record.
fn armAbortSteps(instance: *runtime.Instance, signal: *runtime.Instance, id: u56) !void {
    // "Add an algorithm" step 1: an aborted signal takes none. Step 2 of
    // "add an event listener" returned for one, and nothing since runs
    // script; asked again so that no record is ever indexed that no signal
    // lists.
    if (interfaces.AbortSignal.get_aborted(signal) catch true) return;
    const registry = try registryFor(instance);
    const record = try registry.allocator.create(SignalRemoval);
    record.* = .{
        .target = instance,
        .target_generation = runtime.SlabAllocator.generationOf(instance),
        .signal = signal,
        .signal_generation = runtime.SlabAllocator.generationOf(signal),
        .listener_id = id,
    };
    registry.putRemoval(record) catch |err| {
        registry.allocator.destroy(record);
        return err;
    };
    abort_algorithms.add(signal, .{ .ctx = record, .run = SignalRemoval.run, .drop = SignalRemoval.drop }) catch {
        _ = registry.takeRemoval(id);
        registry.allocator.destroy(record);
    };
}

/// DOM §2.7 - add an event listener
/// To add an event listener, given an EventTarget object eventTarget and
/// an event listener listener - here its type (BORROWED), its callback
/// (OWNED: stored or released on every path) and its flattened options.
fn addAnEventListener(listeners: Listeners, instance: *runtime.Instance, @"type": []const u8, callback: ?Kept, options: FlatOptions) !void {
    // Step 1: ServiceWorkerGlobalScope warning (skipped - not applicable)

    // Step 2: If listener's signal is not null and is aborted, then return
    if (options.signal) |signal| {
        if (interfaces.AbortSignal.get_aborted(signal) catch false) {
            if (callback) |value| value.release();
            return;
        }
    }

    // Step 3: If listener's callback is null, then return
    const callback_value = callback orelse return;

    // Step 4: If listener's passive is null, then set it to the default
    // passive value given listener's type and eventTarget.
    const passive = options.passive orelse defaultPassiveValue(@"type", instance);
    // A host's discouragedAPIUse violation: a listener for a scroll-blocking
    // event left non-passive without saying so (Blink's EventTarget::
    // SetDefaultAddEventListenerOptions). One load while no host listens.
    if (options.passive == null and !passive) if (dom_module.performance_monitor.active(instance.ctx)) |monitor| {
        if (dom_module.performance_monitor.isScrollBlocking(@"type")) {
            var buffer: [256]u8 = undefined;
            if (std.fmt.bufPrint(&buffer, "Added non-passive event listener to a scroll-blocking '{s}' event. Consider marking event handler as 'passive' to make the page more responsive. See https://www.chromestatus.com/feature/5745543795965952", .{@"type"})) |text| {
                monitor.report(instance.ctx, .discouraged_api_use, text, 0);
            } else |_| {}
        }
    };

    // Step 5: If eventTarget's event listener list does not contain an event
    // listener whose type is listener's type, callback is listener's
    // callback, and capture is listener's capture, then append listener to
    // eventTarget's event listener list.
    const key = EventTypeKey.of(@"type");
    for (listeners.view()) |existing| {
        // An event handler's listener has the event handler processing
        // algorithm as its callback, which script never holds.
        if (existing.bits.kind != .listener) continue;
        if (existing.bits.capture == options.capture and existing.type.matches(key) and
            callbackEquals(instance.ctx, existing, callback_value.value()))
        {
            // Already there: its abort steps (step 6) would remove a listener
            // that was never appended, which does nothing, so none are added.
            callback_value.release();
            return;
        }
    }

    const allocator = runtime.allocatorOf(instance);
    const kept_type = listener_list.EventType.init(allocator, @"type") catch {
        callback_value.release();
        return error.OutOfMemory;
    };
    listeners.ensureUnusedCapacity(allocator, 1) catch {
        kept_type.deinit(allocator);
        callback_value.release();
        return error.OutOfMemory;
    };
    const id = nextListenerId();
    // One read of the list for the append and the owner's flag: nothing
    // between here and the end of step 5 can move it.
    var list = listeners.current();
    list.appendAssumeCapacity(.{
        .type = kept_type,
        .object = callback_value.object,
        .context = callback_value.context,
        .bits = .{ .id = id, .capture = options.capture, .passive = passive, .once = options.once, .abort_steps = options.signal != null, .traced = callback_value.traced },
    });
    // Appended: its owner hears of it before step 6 can fail.
    if (list.watched()) dom_module.event_listener_changes.changed(instance);

    // Step 6: If listener's signal is not null, then add the following abort
    // steps to it: remove an event listener with eventTarget and listener.
    // The listener is stored; failing to arm its removal leaves it
    // registered, as an allocation failure anywhere else would.
    if (options.signal) |signal| try armAbortSteps(instance, signal, id);
}

/// DOM §2.7 - remove an event listener, as removeEventListener() runs it
/// ("If this's event listener list contains an event listener whose type is
/// type, callback is callback, and capture is capture, then remove an event
/// listener"). `callback` is BORROWED.
fn removeAnEventListener(listeners: Listeners, instance: *runtime.Instance, @"type": []const u8, callback: ?runtime.BorrowedCallbackInterface, capture: bool) void {
    // Step 1: ServiceWorkerGlobalScope warning (skipped - not applicable)
    const key = EventTypeKey.of(@"type");
    // One read of the list for the scan, the removal and the owner's flag:
    // the comparison runs no script, and a removal moves no block.
    var list = listeners.current();
    const index = for (list.view(), 0..) |existing, i| {
        // An event handler's listener is removed only by deactivating the
        // handler, never by removeEventListener (its callback is internal).
        if (existing.bits.kind != .listener) continue;
        if (existing.bits.capture == capture and existing.type.matches(key) and
            callbackEquals(instance.ctx, existing, if (callback) |given| given.object else null)) break i;
    } else return;

    // Step 2: Set listener's removed to true and remove listener from
    // eventTarget's event listener list. A listener out of the list is out
    // of every clone a dispatch walks (dom.event_listener_list `Cursor`),
    // which is what its removed flag is for; its callback goes with it.
    const removed = list.removeAt(index);
    releaseListener(runtime.allocatorOf(instance), registryOf(instance), removed, true);
    if (list.watched()) dom_module.event_listener_changes.changed(instance);
}

/// An event handler's new value (HTML 8.1.8.1), OWNED until it is stored.
const NewHandlerValue = union(enum) {
    /// A callback function the binding converted, or that compiling a raw
    /// handler made.
    compiled: engine.CallbackFunction,
    /// An internal raw uncompiled handler (a content attribute).
    raw: *RawHandler,

    fn release(self: NewHandlerValue, allocator: std.mem.Allocator) void {
        switch (self) {
            .compiled => |callback| callback.release(),
            .raw => |raw| raw.destroy(allocator),
        }
    }

    /// Hand the value to `listener`, an event handler's: from here on it is
    /// the list's - a compiled function as a traced hold when `traced` (its
    /// target's list is traced: `tracesValues`), the strong one it came as
    /// otherwise.
    fn keepIn(self: NewHandlerValue, listener: *Listener, traced: bool) void {
        switch (self) {
            .compiled => |callback| {
                if (traced) {
                    defer callback.release();
                    const kept = (runtime.BorrowedCallbackFunction{ .function = callback.function.value }).keepTraced();
                    listener.object = kept.hold.handle;
                    listener.bits.traced = kept.hold.handle != null;
                } else {
                    listener.object = packObject(callback.function);
                    listener.bits.traced = false;
                }
                listener.context = callback.context;
                listener.bits.value = if (listener.object == null) .none else .compiled;
            },
            .raw => |raw| {
                listener.object = raw;
                listener.context = null;
                listener.bits.value = .raw;
                listener.bits.traced = false;
            },
        }
    }
};

// ============================================================================
// Event handlers per isolated world
// ============================================================================

/// Which world's event handler a step reads or writes (engine section 4.2a):
/// null - THE FAST PATH, one load (`worldsActive`): the target's Browser
/// made no isolated world, a type has one event handler, and every lookup
/// is the one it always was - or the id of a world. Blink keeps an event
/// handler per world: EventTarget::GetAttributeRegisteredEventListener
/// answers the handler listener that BelongsToTheCurrentWorld, and
/// SetAttributeEventListener replaces or removes that one only
/// (third_party/blink/renderer/core/dom/events/event_target.cc; BSD-3 -
/// reproduced, not copied) - so a world's `onclick = f` never replaces the
/// page's handler, the page's never a world's, and each reads its own.
const HandlerWorld = ?u32;

/// Whether `target`'s Browser made an isolated world.
fn worldsActive(target: *runtime.Instance) bool {
    const scope = target.ctx.browserScope() orelse return false;
    return scope.isolated_worlds_active.load(.monotonic);
}

/// The IDL attribute's world: the world of the script getting or setting it
/// (the current realm's; none running - a host's read - the main world's).
fn currentHandlerWorld(target: *runtime.Instance) HandlerWorld {
    if (!worldsActive(target)) return null;
    const realm = engine.currentRealm() orelse return engine.main_world;
    return realm.world;
}

/// A content attribute's world: the main world's - its handler is compiled
/// in the element's document's realm (HTML 8.1.8.1, "getting the current
/// value of the event handler" step 3), Blink's JSEventHandlerForContent
/// Attribute's main-world assumption.
fn mainHandlerWorld(target: *runtime.Instance) HandlerWorld {
    if (!worldsActive(target)) return null;
    return engine.main_world;
}

/// The world an event handler listener is of: its compiled value's callback
/// context's - the realm of the script that set it (the IDL attribute
/// converts the function with the incumbent realm as its callback context),
/// read from the realm's record so that a world realm that ended keeps its
/// handlers (runtime.ContextData.world) - and the main world for a raw
/// (content attribute) handler or one with no value.
fn handlerListenerWorld(listener: Listener) u32 {
    if (listener.bits.value != .compiled) return engine.main_world;
    const context = listener.context orelse return engine.main_world;
    return context.world;
}

/// HTML 8.1.8.1: "set eventHandler's value to" `value`, "then activate an
/// event handler given eventTarget and name" - the IDL attribute setter's
/// step 4, the content attribute's change steps 5.2-5.6 and "getting the
/// current value" step 3.12. The event handler's value is kept in its
/// listener: on error `value` is still the caller's, on success the
/// list's, and a value it replaces is released.
///
/// "Activate an event handler":
/// https://html.spec.whatwg.org/multipage/webappapis.html#activate-an-event-handler
fn storeEventHandler(target: *runtime.Instance, listeners: Listeners, event_type: []const u8, value: NewHandlerValue, world: HandlerWorld) !void {
    const allocator = runtime.allocatorOf(target);
    // Activate step 3: "If eventHandler's listener is not null, then
    // return": the listener stays where it is - only the value changes,
    // which is how a handler set again keeps its place among the listeners
    // (Gecko's SetEventHandlerInternal, WebKit's setAttributeEventListener
    // and Servo's set_inline_event_listener replace it in place).
    if (listeners.indexOfHandlerIn(EventTypeKey.of(event_type), world)) |index| {
        var updated = listeners.at(index);
        value.keepIn(&updated, tracesValues(listeners, target));
        const old = listeners.replaceAt(index, updated);
        releaseValue(allocator, old, true);
        return;
    }
    // Steps 4-7: "Let callback be the result of creating a Web IDL
    // EventListener instance representing a reference to a function of one
    // argument that executes the steps of the event handler processing
    // algorithm", a listener whose type is the event handler event type and
    // whose callback is that one, added with "add an event listener" (its
    // step 4 gives it the default passive value; it is never capturing and
    // has no signal) - appended AFTER every listener added so far, which is
    // the order "the event listeners registered with addEventListener()
    // before the first time the event handler's value was set to non-null,
    // then the callback, then the ones registered after" depends on.
    const kept_type = try listener_list.EventType.init(allocator, event_type);
    errdefer kept_type.deinit(allocator);
    try listeners.ensureUnusedCapacity(allocator, 1);
    var listener: Listener = .{
        .type = kept_type,
        .object = null,
        .context = null,
        .bits = .{ .id = nextListenerId(), .passive = defaultPassiveValue(event_type, target), .kind = .handler },
    };
    value.keepIn(&listener, tracesValues(listeners, target));
    listeners.appendAssumeCapacity(listener);
    listenersChanged(listeners, target);
}

/// HTML "deactivate an event handler" given `target` and the event handler
/// for `event_type`, steps 3-6: its value becomes null and its listener is
/// removed, so a later non-null value activates a NEW listener, at the end.
/// https://html.spec.whatwg.org/multipage/webappapis.html#deactivate-an-event-handler
fn deactivateEventHandler(target: *runtime.Instance, listeners: Listeners, event_type: []const u8, world: HandlerWorld) void {
    const index = listeners.indexOfHandlerIn(EventTypeKey.of(event_type), world) orelse return;
    // Step 3: "Set eventHandler's value to null." Steps 4-6: "Let listener
    // be eventHandler's listener. If listener is not null, then remove an
    // event listener with eventTarget and listener. Set eventHandler's
    // listener to null."
    const removed = listeners.removeAt(index);
    releaseListener(runtime.allocatorOf(target), registryOf(target), removed, true);
    listenersChanged(listeners, target);
}

/// HTML "erase all event listeners and handlers" given `target` (§8.1.8.1),
/// which document.open() runs over a document's nodes and its window.
/// "1. If eventTarget has an associated event handler map, then for each
/// name -> eventHandler of eventTarget's associated event handler map,
/// deactivate an event handler given eventTarget and name. 2. Remove all
/// event listeners given eventTarget."
pub fn eraseAllEventListenersAndHandlers(target: *runtime.Instance) void {
    const listeners = listenersOf(target) orelse return;
    if (listeners.len() == 0) return;
    const allocator = runtime.allocatorOf(target);
    const registry = registryOf(target);
    // Step 1, each handler's value null and its listener removed, then step
    // 2, DOM "remove all event listeners" - for each listener, "remove an
    // event listener" (its removed flag set, out of the list): every
    // listener leaves, each out of the list before what it owns is released.
    while (listeners.len() > 0) {
        const removed = listeners.removeAt(listeners.len() - 1);
        releaseListener(allocator, registry, removed, true);
    }
    listenersChanged(listeners, target);
}

/// "Getting the current value of the event handler" (HTML §8.1.8.1):
/// compile a raw content-attribute handler on first use, in the target's
/// current document, or return the already compiled value.
pub fn eventHandler(comptime Handler: type, target: *runtime.Instance, event_type: []const u8) Handler {
    comptime std.debug.assert(Handler == dom_module.event_handlers.HandlerValue);
    return getHandlerValue(target, event_type);
}

/// The event handler IDL attribute setter's steps 3 and 4 (HTML §8.1.8.1) on
/// `target`: null deactivates the handler; any other value becomes the
/// handler's value, which is then activated.
pub fn setEventHandler(comptime Handler: type, target: *runtime.Instance, event_type: []const u8, value: Handler) !void {
    // An instance that never ran EventTarget's init (`lazyInternal`: one a
    // platform object makes for itself, as Screen makes its
    // ScreenOrientation) gets its list here, as addEventListener makes it -
    // the setter threw InvalidStateError for one (lane tpg:
    // `screen.orientation.onchange = f`). Deactivating needs none: with no
    // list there is no handler to deactivate.
    const listeners = if (value == null) (listenersOf(target) orelse return) else try ensureListeners(target);
    // The script's world's handler (`HandlerWorld`).
    const world = currentHandlerWorld(target);
    // Step 3: "If the given value is null, then deactivate an event handler
    // given eventTarget and name."
    const handler = value orelse {
        deactivateEventHandler(target, listeners, event_type, world);
        return;
    };
    // Step 4: set eventHandler's value to the given value, then activate it.
    // The binding's value is borrowed for the setter: the list keeps a hold
    // of its own, and the getter hands out that hold - the binding's goes
    // when the setter returns (lane leaks7).
    const callback = handler.keep();
    const new_value: NewHandlerValue = .{ .compiled = callback };
    errdefer new_value.release(runtime.allocatorOf(target));
    try storeEventHandler(target, listeners, event_type, new_value, world);
}

/// The getter's value: the list's own hold, BORROWED.
fn getHandlerValue(target: *runtime.Instance, event_type: []const u8) dom_module.event_handlers.HandlerValue {
    const current = currentHandlerValue(target, event_type, currentHandlerWorld(target)) orelse return null;
    // The getter's value is null for a function the collector took (refcount
    // step 8): a traced hold reads empty once no trace from its target kept
    // it - its target went unreached in a collection and is wrapped again;
    // WebKit's JSEventListener answers null the same way once its JSC::Weak
    // is cleared.
    if (current.callback.function.value.isUndefined()) return null;
    return .{ .function = current.callback.function.value };
}

/// Content attribute change steps 5.2-5.6: store an owned raw body and
/// location and activate the handler, without compiling or running script.
fn setRawEventHandler(target: *runtime.Instance, event_type: []const u8, source: dom_module.event_handlers.RawSource) anyerror!void {
    const listeners = listenersOf(target) orelse return error.InvalidStateError;
    const new_value: NewHandlerValue = .{ .raw = try RawHandler.create(runtime.allocatorOf(target), source) };
    errdefer new_value.release(runtime.allocatorOf(target));
    // A content attribute's handler is the main world's (`mainHandlerWorld`).
    try storeEventHandler(target, listeners, event_type, new_value, mainHandlerWorld(target));
}

/// dom.event_handlers.deactivateForContentAttribute: the content attribute
/// was removed - "deactivate an event handler" for the main world's handler
/// (`mainHandlerWorld`), whatever world's script removed it.
fn deactivateContentAttributeHandler(target: *runtime.Instance, event_type: []const u8) void {
    const listeners = listenersOf(target) orelse return;
    deactivateEventHandler(target, listeners, event_type, mainHandlerWorld(target));
}

/// "Getting the current value of the event handler" (HTML 8.1.8.1) given
/// `target` and `event_type`: the handler's value - or, for an internal raw
/// uncompiled handler, step 3: compile it now (`dom.event_handlers.compileRaw`,
/// which the content attribute's owner installs), which sets the value to the
/// function or - for a body that does not parse - reports the syntax error
/// and leaves it null ("This does not deactivate the event handler"). A
/// handler whose document still has no browsing context stays raw and is
/// null for now (step 3.2: "If scripting is disabled for document, then
/// return null").
///
/// The handler stops being raw BEFORE it is compiled: compiling reports
/// errors, which can run script that reads this handler again, and that read must find it
/// settled rather than compile it a second time.
fn currentHandlerValue(target: *runtime.Instance, event_type: []const u8, world: HandlerWorld) ?HandlerValue {
    const listeners = listenersOf(target) orelse return null;
    const key = EventTypeKey.of(event_type);
    const index = listeners.indexOfHandlerIn(key, world) orelse return null;
    const listener = listeners.at(index);
    switch (listener.bits.value) {
        .none => return null,
        .compiled => return handlerValueOf(listener),
        .raw => {
            // Step 3.7.1: null before compilation can report an error and
            // re-enter the getter. Keep the listener and its position. The
            // source is ours during reentrancy, even if the attribute changes.
            const allocator = runtime.allocatorOf(target);
            const raw = listener.rawHandler().?;
            var cleared = listener;
            cleared.object = null;
            cleared.context = null;
            cleared.bits.value = .none;
            _ = listeners.replaceAt(index, cleared);
            switch (dom_module.event_handlers.compileRaw(target, event_type, raw.source())) {
                .scripting_disabled => {
                    // Step 3.2 runs no script: the listener is where it was,
                    // and stays raw.
                    if (listeners.indexOfId(listener.bits.id)) |at| {
                        _ = listeners.replaceAt(at, listener);
                    } else raw.destroy(allocator);
                    return null;
                },
                .settled => raw.destroy(allocator),
                .compiled => |callback| {
                    raw.destroy(allocator);
                    // HTML getting the current value steps 3.12-3.13. Take
                    // the compiled callback directly: IDL conversion here
                    // would capture the getter's caller as the incumbent.
                    const current = listenersOf(target) orelse {
                        callback.release();
                        return null;
                    };
                    storeEventHandler(target, current, event_type, .{ .compiled = callback }, world) catch {
                        callback.release();
                        return null;
                    };
                },
            }
            // Compilation may have changed the handler (or erased the target).
            return eventHandlerValue(target, event_type, world);
        },
    }
}

fn setHandlerValue(target: *runtime.Instance, event_type: []const u8, value: dom_module.event_handlers.HandlerValue) anyerror!void {
    try setEventHandler(dom_module.event_handlers.HandlerValue, target, event_type, value);
}

/// An event handler's compiled value, BORROWED from its listener: the
/// callback function (the list's hold), which the getter returns. A running
/// handler holds a value of its own (invokeIdlEventHandler), so
/// `this.onclick = null` inside one is safe.
const HandlerValue = struct {
    callback: engine.CallbackFunction,
};

fn handlerValueOf(listener: Listener) HandlerValue {
    return .{
        .callback = .{ .function = .{ .value = valueOf(listener.object, listener.bits.traced) }, .context = listener.context },
    };
}

/// `target`'s event handler's compiled value for `event_type`, for the
/// getter and for dispatch.
fn eventHandlerValue(target: *runtime.Instance, event_type: []const u8, world: HandlerWorld) ?HandlerValue {
    const listeners = listenersOf(target) orelse return null;
    const index = listeners.indexOfHandlerIn(EventTypeKey.of(event_type), world) orelse return null;
    const listener = listeners.at(index);
    if (listener.bits.value != .compiled) return null;
    return handlerValueOf(listener);
}

/// The flattened options. `capture` is always resolved; the rest come only from
/// the dictionary form.
const FlatOptions = struct {
    capture: bool = false,
    once: bool = false,
    passive: ?bool = null,
    signal: ?*runtime.Instance = null,
};

/// DOM "flatten" (https://dom.spec.whatwg.org/#concept-flatten-options)
/// over removeEventListener's `(EventListenerOptions or boolean)` and "flatten
/// more" (#event-flatten-more) over addEventListener's
/// `(AddEventListenerOptions or boolean)`, each as the binding converted it.
/// WebIDL 3.2.25 has already chosen the member - undefined, null and any
/// object are the dictionary, anything else ToBoolean (`true`, "AAAA", 2.3
/// are capture; "", NaN, 0 are not:
/// dom/events/EventListenerOptions-capture.html) - and read the dictionary's
/// members in order, the inherited `capture` first, then `once`, `passive`,
/// `signal`; a throwing getter, or a `signal` that is no AbortSignal (null
/// included), threw there.
fn flatten(options: webidl.Opt(typedefs.EventListenerOptionsOrBoolean)) bool {
    if (!options.wasPassed()) return false;
    return switch (options.getValue()) {
        // 1. "If options is a boolean, then return options."
        .boolean => |capture| capture,
        // 2. "Return options["capture"]."
        .event_listener_options => |dictionary| dictionary.capture orelse false,
    };
}

fn flattenMore(options: webidl.Opt(typedefs.AddEventListenerOptionsOrBoolean)) FlatOptions {
    if (!options.wasPassed()) return .{};
    return switch (options.getValue()) {
        // 1. "Let capture be the result of flattening options."
        .boolean => |capture| .{ .capture = capture },
        // 2-4. once, passive ("if options["passive"] exists": absent leaves
        // the default passive value to decide, which is not `passive:
        // false`) and signal.
        .add_event_listener_options => |dictionary| .{
            .capture = dictionary.base.capture orelse false,
            .once = dictionary.once orelse false,
            .passive = dictionary.passive,
            .signal = dictionary.signal,
        },
    };
}

/// Operation: addEventListener
/// Spec: https://dom.spec.whatwg.org/#dom-eventtarget-addeventlistener
pub fn call_addEventListener(instance: *runtime.Instance, @"type": runtime.DOMString, callback: ?runtime.BorrowedCallbackInterface, options: webidl.Opt(typedefs.AddEventListenerOptionsOrBoolean)) anyerror!void {
    // https://dom.spec.whatwg.org/#concept-flatten-more
    const flat = flattenMore(options);

    // Its event listener list - made, for an instance that never ran
    // EventTarget's init. The options' getters ran in the binding's
    // conversion, before this call: nothing below runs script before the
    // listener is in the list.
    const listeners = ensureListeners(instance) catch return error.OutOfMemory;

    // The callback interface value, kept with the incumbent realm now - the
    // conversion's - as its callback context. The binding's value is
    // BORROWED for the call; the listener keeps a value of its own, traced
    // from this target where its list is traced (`Kept`).
    const callback_value: ?Kept = if (callback) |given| Kept.ofInterface(given, tracesValues(listeners, instance)) else null;

    // "Add an event listener with this and an event listener whose type is
    // type, callback is callback, capture is capture, passive is passive,
    // once is once, and signal is signal." The type is BORROWED from the
    // binding for the call: the list keeps an id for a type the platform
    // fires and a copy of any other. It stores or releases the callback on
    // every path.
    try addAnEventListener(listeners, instance, @"type".asSlice(), callback_value, flat);
}

/// Operation: removeEventListener
/// Spec: https://dom.spec.whatwg.org/#dom-eventtarget-removeeventlistener
///
/// `options` is converted before this runs, whether or not the target has a
/// listener: WebIDL converts the arguments before the method's steps, and
/// Chrome 157, Firefox 159 and Safari 27 all run the options' `capture`
/// getter on a target with no listener and with a null callback (probe
/// tmp/probes/bind1-nullmember/report-g3.txt, 2026-11-24). The hand
/// conversion this replaced ran after the "no listener list" return below, so
/// the getter never ran there (crane/bind1-g3-conversion-order.html).
pub fn call_removeEventListener(instance: *runtime.Instance, @"type": runtime.DOMString, callback: ?runtime.BorrowedCallbackInterface, options: webidl.Opt(typedefs.EventListenerOptionsOrBoolean)) anyerror!void {
    const listeners = listenersOf(instance) orelse return;

    // https://dom.spec.whatwg.org/#concept-flatten
    //
    // Removal matches on type, callback AND capture, so discarding the flag
    // here meant `removeEventListener(t, fn, true)` could never find the
    // listener that `addEventListener(t, fn, true)` added.
    const capture = flatten(options);

    // The callback interface value, BORROWED for the call: only compared,
    // so nothing is kept.
    removeAnEventListener(listeners, instance, @"type".asSlice(), callback, capture);
}

/// Operation: dispatchEvent
/// Spec: https://dom.spec.whatwg.org/#dom-eventtarget-dispatchevent
pub fn call_dispatchEvent(instance: *runtime.Instance, event: *runtime.Instance) anyerror!bool {
    return dispatchEventWithTrust(instance, event, false, null, null, dom_module.event_dispatch.DispatchPath.any_world);
}

/// DOM 2.10 "fire an event", for an event the user agent has already created
/// and initialized: dispatch it with isTrusted true. Script's dispatchEvent()
/// is the only thing that makes an event untrusted. Everything reaches it
/// through `dom.fire_event`, which this installs.
fn dispatchTrusted(target: *runtime.Instance, event: *runtime.Instance) anyerror!bool {
    return dispatchEventWithTrust(target, event, true, null, null, dom_module.event_dispatch.DispatchPath.any_world);
}

/// dom.fire_event.dispatchTrustedInWorld: a trusted dispatch whose listeners
/// are isolated world `world`'s only - an error report's (Blink's
/// ErrorEvent::CanBeDispatchedInWorld).
fn dispatchTrustedInWorld(target: *runtime.Instance, event: *runtime.Instance, world: u32) anyerror!bool {
    return dispatchEventWithTrust(target, event, true, null, null, world);
}

/// "Fire an event" at the Window `window` "with legacy target override flag
/// set" (HTML's Window load, pageshow, pagehide and unload): DOM dispatch
/// step 5's targetOverride is the Window's associated Document. A Window
/// with no Document (gone) dispatches as plain.
fn dispatchTrustedLegacyTargetOverride(window: *runtime.Instance, event: *runtime.Instance) anyerror!bool {
    const document = interfaces.Window.get_document(window) catch null;
    // The path holds its invocation targets, and every other target it
    // records is one of them - but the Document is not on a Window's path:
    // held here for the dispatch, as dispatch holds activationTarget
    // (refcount step 5g; Blink's LocalDOMWindow::DispatchEvent keeps the
    // Document it passes as the target).
    var document_hold: dom_module.node_holds.RefHold = .{};
    defer document_hold.release();
    document_hold.set(document);
    return dispatchEventWithTrust(window, event, true, null, document, dom_module.event_dispatch.DispatchPath.any_world);
}

fn dispatchTrustedWithThrows(target: *runtime.Instance, event: *runtime.Instance, did_throw: *bool) anyerror!bool {
    return dispatchEventWithTrust(target, event, true, did_throw, null, dom_module.event_dispatch.DispatchPath.any_world);
}

/// dispatchEvent()'s steps with isTrusted given: false for script (DOM 2.8
/// step 2), true when the user agent fires the event.
fn dispatchEventWithTrust(instance: *runtime.Instance, event: *runtime.Instance, trusted: bool, did_throw: ?*bool, target_override: ?*runtime.Instance, only_world: u32) anyerror!bool {
    // The event's dispatch state, taken once: every step below works on it.
    // An event with none never ran Event's constructing steps, so its
    // initialized flag is unset.
    const state = event_dispatch.of(event) orelse return error.InvalidStateError;

    // Step 1: If event's dispatch flag is set, or if its initialized flag is not
    //         set, then throw an "InvalidStateError" DOMException.
    //
    // The initialized-flag half is not optional: `document.createEvent("Event")`
    // hands back an event with the flag UNSET, and dispatching it must throw
    // until `initEvent` runs. Skipping the check made 8 subtests of
    // EventTarget-dispatchEvent.html report "did not throw".
    if (state.dispatch_flag or !state.initialized_flag) return error.InvalidStateError;

    // Step 2: Initialize event's isTrusted attribute to false - or, for an
    // event the user agent fires, true.
    state.is_trusted = trusted;

    // Step 3: Return the result of dispatching event to this
    return dispatchWithThrowFlag(instance, event, state, did_throw, target_override, only_world);
}

// ============================================================================
// DOM §2.9 - Dispatching events
// https://dom.spec.whatwg.org/#concept-event-dispatch
// ============================================================================

/// The two values the spec's `phase` argument to "invoke" can take.
const ListenerPhase = enum { capturing, bubbling };

/// DOM §2.9 - dispatch
/// https://dom.spec.whatwg.org/#concept-event-dispatch
///
/// `state` is `event`'s (`dom.event_dispatch.of`), BORROWED for the dispatch.
/// Returns false if the event's canceled flag is set, true otherwise.
///
/// Steps 4-6.11 - the path across shadow trees, activationTarget and
/// clearTargets - are dom.event_path's; the passes over the path and steps
/// 1 and 7-13 are here, beside the listener lists they read.
///
/// The event's path is this dispatch's: a local of this frame, as WebKit's
/// EventPath is a local of
/// EventDispatcher::dispatchEventWithoutDebuggerDeferral and Gecko's target
/// chain a local of EventDispatcher::Dispatch (dom.event_dispatch, "THE PATH
/// IS THE DISPATCH'S"). The event points at it from the build (steps 4-6.11) to
/// step 9, which every exit of `dispatchOnPath` runs; a nested dispatch -
/// another event's, or this one's again from its activation behaviour - has
/// a frame and a path of its own.
fn dispatchWithThrowFlag(target: *runtime.Instance, event: *runtime.Instance, state: *EventState, did_throw: ?*bool, target_override: ?*runtime.Instance, only_world: u32) !bool {
    // Runtime safety off for the declaration only: ReleaseSafe would fill
    // the path's inline items with 0xaa on every dispatch, and `init` writes
    // every field that is read before it is written (the approved form:
    // dom.mutation's `insert`).
    @setRuntimeSafety(false);
    var path: dom_module.event_dispatch.DispatchPath = undefined;
    path.init(runtime.allocatorOf(event));
    path.only_world = only_world;
    defer path.deinit();
    // The path's nodes keep their wrappers - and with them the listeners
    // still to be called - while the dispatch runs (refcount step 8).
    var active: dom_module.event_dispatch.ActiveDispatch = .{ .path = &path };
    active.begin(target);
    defer active.end();
    // Whatever way the dispatch left, the event does not point at this
    // frame once it is gone.
    defer if (state.path == &path) state.clearPath();
    return dispatchOnPath(&path, target, event, state, did_throw, target_override);
}

/// `dispatchWithThrowFlag` with the dispatch's path, `dispatch_path`: empty
/// on entry, the caller's to free.
fn dispatchOnPath(dispatch_path: *dom_module.event_dispatch.DispatchPath, target: *runtime.Instance, event: *runtime.Instance, state: *EventState, did_throw: ?*bool, target_override: ?*runtime.Instance) !bool {
    // Step 1: Set event's dispatch flag.
    state.dispatch_flag = true;

    // Steps 7-10 have to happen however we leave.
    errdefer state.endDispatch(event);

    // `get_type` hands back a borrowed slice into the event's own storage, and
    // `initEvent` returns early while the dispatch flag is set, so no callback
    // can invalidate it mid-dispatch.
    const event_type_string = interfaces.Event.get_type(event) catch runtime.DOMString.initEmpty();
    const event_type = event_type_string.asSlice();
    const bubbles = interfaces.Event.get_bubbles(event) catch false;
    // The type every listener is matched against, looked up once for the
    // whole dispatch (dom.event_listener_list.Key): the event's type cannot
    // change while it is dispatched, but for invoke step 11's rename.
    const type_key = EventTypeKey.of(event_type);
    // Not a DOM step: an element type's own step for this event type at its
    // place on the path, before its listeners (dom.local_event_steps,
    // Blink's HandleLocalEvents) - looked up once; with none for the type,
    // invoke runs none.
    const local_step = dom_module.local_event_steps.forType(type_key);

    // Steps 2-6.11. Step 5: targetOverride is target, or - legacy target
    // override flag set - `target_override`, the Window's associated
    // Document (dispatchTrustedLegacyTargetOverride). Step 6.4:
    // isActivationEvent - "event is a MouseEvent object and
    // event's type attribute is click"; the behaviours are the element
    // types' own (dom.activation).
    const is_activation_event = std.mem.eql(u8, event_type, "click") and event.stateAs(interfaces.MouseEvent.State) != null;
    const built = try dom_module.event_path.build(state, dispatch_path, target, .{
        .event_type = event_type,
        .composed = interfaces.Event.get_composed(event) catch false,
        .bubbles = bubbles,
        .activation_of = if (is_activation_event) &dom_module.activation.of else null,
        .target_override = target_override,
    });
    const activation_target = built.activation_target;
    // Dispatch holds activationTarget across steps 6.12-12: step 9 empties
    // the path, which held it, before step 12 runs its activation behaviour
    // (refcount step 5g; WebKit's EventDispatcher::dispatchEvent holds
    // `Ref protectedNode` and its legacy pre-activation input in a
    // `RefPtr` for the whole dispatch, Source/WebCore/dom/
    // EventDispatcher.cpp). SHADOW MODE: counted only.
    var activation_hold: dom_module.node_holds.RefHold = .{};
    defer activation_hold.release();
    if (activation_target) |at| activation_hold.set(at.target);

    // The path does not change while it runs: nothing appends to it until
    // step 9 empties it, and a listener can neither redispatch this event
    // (step 1 of dispatchEvent) nor reinitialize it (initEvent's step 1).
    const path = dispatch_path.constItems();

    // Step 6.12: legacy-pre-activation behaviour.
    if (activation_target) |at| {
        if (at.behavior.legacy_pre_activation) |pre| pre(at.target);
    }

    // Step 6.13: for each item of event's path, IN REVERSE ORDER, invoke with
    // "capturing".
    var i = path.len;
    while (i > 0) {
        i -= 1;
        // Steps 6.13.1-6.13.2.
        state.phase = if (path[i].has_shadow_adjusted_target)
            event_dispatch.Phase.at_target
        else
            event_dispatch.Phase.capturing;
        // Step 6.13.3.
        invoke(dispatch_path, &path[i], event, state, .capturing, did_throw, type_key, local_step);
    }

    // Step 6.14: for each item of event's path, in order, invoke with "bubbling".
    for (path) |*item| {
        if (item.has_shadow_adjusted_target) {
            // Step 6.14.1 - a target is AT_TARGET in both passes, which is
            // how its capturing listeners run before its bubbling ones.
            state.phase = event_dispatch.Phase.at_target;
        } else {
            // Step 6.14.2.1
            if (!bubbles) continue;
            // Step 6.14.2.2
            state.phase = event_dispatch.Phase.bubbling;
        }
        // Step 6.14.3
        invoke(dispatch_path, item, event, state, .bubbling, did_throw, type_key, local_step);
    }

    // Steps 7-11: eventPhase NONE, currentTarget null, the path empty, the
    // flags unset and - when clearTargets - the target, relatedTarget and
    // touch target list cleared; then the values the event keeps are kept.
    state.finishDispatch(event, built.clear_targets);

    // Step 12: "If activationTarget is non-null: if event's canceled flag is
    // unset, then run activationTarget's activation behavior with event;
    // otherwise, if activationTarget has legacy-canceled-activation behavior,
    // run it."
    // defaultPrevented is the canceled flag ("return true if this's canceled
    // flag is set").
    if (activation_target) |at| {
        if (!state.canceled_flag) {
            at.behavior.run(at.target, event);
        } else if (at.behavior.legacy_canceled_activation) |canceled| {
            canceled(at.target);
        }
    }

    // Step 13: return false if event's canceled flag is set; otherwise true.
    return !state.canceled_flag;
}

/// DOM §2.9 - invoke
/// https://dom.spec.whatwg.org/#concept-event-listener-invoke
///
/// `item` is BORROWED from the event's path, `path`, which outlives the call.
/// `event_type` is the event's type, looked up once per dispatch, and
/// `local_step` the element types' own step for it (dom.local_event_steps),
/// if any.
fn invoke(path: *dom_module.event_dispatch.DispatchPath, item: *const dom_module.event_dispatch.PathItem, event: *runtime.Instance, state: *EventState, phase: ListenerPhase, did_throw: ?*bool, event_type: EventTypeKey, local_step: ?dom_module.local_event_steps.Run) void {
    // Steps 1-3: event's target is the shadow-adjusted target of the last
    // item at or before this one whose shadow-adjusted target is non-null -
    // recorded on the item when the path was built. Written raw: the path
    // holds it, and the end of dispatch keeps the one the event ends with.
    state.target = item.target;

    // Step 4: "Set event's relatedTarget to pathItem's relatedTarget."
    state.related_target = item.related_target;

    // Step 5: "Set event's touch target list to pathItem's touch target
    // list." Both are empty for every event but a TouchEvent's.
    const touch_targets = path.touchTargetsOf(item);
    if (touch_targets.len > 0 or state.touch_target_list.toSlice().len > 0) {
        state.touch_target_list.assign(runtime.allocatorOf(event), touch_targets) catch {};
    }

    // Step 6: stopPropagation() ends the walk here, but the caller still has to
    // run steps 7-10, so this returns rather than unwinding.
    if (state.stop_propagation_flag) return;

    // Not a DOM step: the invocation target's own step for this event, before
    // its listeners (dom.local_event_steps; Blink's
    // NodeEventContext::HandleLocalEvents, which EventDispatcher runs per
    // node in both passes). A stop sets the stop propagation flag - as the
    // step's stopPropagation() does in Blink - and runs none of this item's
    // listeners.
    if (local_step) |step| {
        if (step(item.invocation_target, item.target, state.phase) == .stop) {
            state.stop_propagation_flag = true;
            return;
        }
    }

    // Step 7: the currentTarget attribute's value is the dispatch's to
    // keep (null outside dispatch), with its slab generation.
    path.setCurrentTarget(item.invocation_target);

    // Steps 8-10. Step 8, "let listeners be a clone of event's
    // currentTarget attribute value's event listener list", is innerInvoke's
    // (`List.clone`, which copies nothing).
    //
    // Event handler IDL attributes (onclick, onload, ...) run from inside
    // here too: HTML specifies them as ordinary event listeners in the same
    // list, and "activate an event handler" puts one there, so a handler runs
    // in registration order among the addEventListener listeners - and, being
    // non-capturing, only in the bubbling pass.
    const in_shadow_tree = item.invocation_target_in_shadow_tree;
    const found = innerInvoke(event, state, item.invocation_target, phase, in_shadow_tree, did_throw, event_type);

    // Step 11: "If found is false and event's isTrusted attribute is true:"
    if (found or !state.is_trusted) return;
    const type_string = interfaces.Event.get_type(event) catch return;
    // Step 11.2: rename a legacy-mapped type, "and return otherwise".
    const legacy = dom_module.event_dispatch.legacyEventType(type_string.asSlice()) orelse return;
    // Step 11.1: "Let originalEventType be event's type attribute value" -
    // the value the event held, handed back by the rename.
    const original_event_type = dom_module.event_dispatch.swapType(event, runtime.DOMString.initInterned(legacy)) orelse return;
    // Step 11.3: "Inner invoke with event, listeners, phase,
    // invocationTargetInShadowTree, and legacyOutputDidListenersThrowFlag if
    // given." found was false, so no listener ran and the list is still the
    // one step 8 cloned; innerInvoke's own clone is that clone.
    _ = innerInvoke(event, state, item.invocation_target, phase, in_shadow_tree, did_throw, EventTypeKey.of(legacy));
    // Step 11.4: "Set event's type attribute value to originalEventType."
    _ = dom_module.event_dispatch.swapType(event, original_event_type);
}

/// DOM §2.9 - inner invoke
/// https://dom.spec.whatwg.org/#concept-event-listener-inner-invoke
///
/// Returns `found`: whether any listener matched the event's type, regardless of
/// phase. Only step 11 of "invoke" consumes it. `in_shadow_tree` is the path
/// item's invocation-target-in-shadow-tree; `event_type` is the event's
/// type attribute value now.
fn innerInvoke(event: *runtime.Instance, state: *EventState, current_target: *runtime.Instance, phase: ListenerPhase, in_shadow_tree: bool, did_throw: ?*bool, event_type: EventTypeKey) bool {
    const listeners = listenersOf(current_target) orelse return false;

    // Step 8 of "invoke": "Let listeners be a clone of event's currentTarget
    // attribute value's event listener list." The clone copies nothing: it
    // is the listeners in the list now, walked by id, and every step below
    // reads the list as it is when it reaches them (dom.event_listener_list
    // `List.clone`: Gecko's end-limited walk of the live array, where Blink,
    // WebKit and Servo copy a vector of references per dispatch). A listener
    // the callbacks append is never reached; one they remove has left the
    // list and is never reached either; the list may move while they run, so
    // nothing here holds a pointer into it.
    //
    // `list` is the list's address as last read (a node's is a slot of its
    // rare block: `Listeners`). It is read again after every callback - the
    // only step of the walk that runs script - and not between: a listener
    // skipped by type or phase costs no second read.
    var list = listeners.current();
    var cursor = list.clone() orelse return false;

    // The world an error report is for (`skippedForWorld`), read once for
    // the walk: `any_world` for every other dispatch.
    const only_world: u32 = if (state.path) |path| path.only_world else dom_module.event_dispatch.DispatchPath.any_world;
    // Whether event handlers are per world here (`HandlerWorld`), read once
    // for the walk: false - one load - for a Browser with no isolated world.
    const handlers_per_world = worldsActive(current_target);

    // A host's performance monitor (dom.performance_monitor: handler and
    // blockedEvent violations): one load and a branch while none listens,
    // and no clock read then (Blink's PerformanceMonitor::enabled_).
    const monitor = dom_module.performance_monitor.active(current_target.ctx);
    const blocked_delay: ?i64 = if (monitor) |m| blockedEventDelay(m, event, current_target) else null;

    // Step 1: "Let found be false."
    var found = false;

    // Step 2: "For each listener of listeners, whose removed is false:"
    while (list.next(&cursor)) |listener| {
        // Step 2.1: "If event's type attribute value is not listener's type,
        // then continue."
        if (!listener.type.matches(event_type)) continue;
        // Step 2.2: "Set found to true."
        found = true;
        // Steps 2.3 and 2.4 - a capturing listener runs only in the capturing
        // pass, a bubbling one only in the bubbling pass. At the target both
        // passes run, which is why [capture, bubble, capture] fires 1, 3, 2.
        if (phase == .capturing and !listener.bits.capture) continue;
        if (phase == .bubbling and listener.bits.capture) continue;

        // Step 2.5: "If listener's once is true, then remove an event listener
        // given event's currentTarget attribute value and listener" - BEFORE
        // invoking it, so a re-entrant dispatch cannot reach it. Its callback
        // is then this call's to release, after the call.
        // (Out of the list, a traced callback is traced by nothing: the call
        // retains it before anything can allocate - callListener's first
        // step.)
        var expired: ?Listener = null;
        if (listener.bits.once) expired = detachListener(listeners, current_target, listener.bits.id);
        defer if (expired) |gone| releaseObject(gone.object, gone.bits.traced);

        // Step 2.11 (passive): set event's in passive listener flag.
        if (listener.bits.passive) state.in_passive_listener_flag = true;

        // Step 2.13 - an exception is reported, never propagated. An event
        // handler's listener runs the event handler processing algorithm.
        // Steps 2.9-2.10 and 2.15 (the listener global's current event) are
        // the callers', around the call. A listener's callback is the
        // list's - borrowed until callListener takes a hold of its own, before
        // any script runs - or, for a once listener, this call's.
        const started: ?i64 = if (monitor) |m| m.willCallback(false) else null;
        switch (listener.bits.kind) {
            .listener => callListener(callbackOf(expired orelse listener), event, current_target, in_shadow_tree, did_throw, only_world),
            .handler => invokeIdlEventHandler(current_target, event, in_shadow_tree, did_throw, only_world, if (handlers_per_world) handlerListenerWorld(listener) else null),
        }
        if (monitor) |m| reportListenerViolations(m, event, current_target, listener.bits.id, listener.bits.passive, started, blocked_delay);

        // The callback ran: the list may have moved, grown or gone.
        list = listeners.current();

        // Step 2.14
        if (listener.bits.passive) state.in_passive_listener_flag = false;

        // Step 2.16
        if (state.stop_immediate_propagation_flag) break;
    }

    // Step 3
    return found;
}

/// blockedEvent's delay for this dispatch: how long ago a cancelable
/// scroll-blocking event was made, when that is past the subscribed
/// threshold (Blink's BlockedEventsWarningThreshold and FireEventListeners'
/// `now - event.PlatformTimeStamp() > threshold`); else null.
fn blockedEventDelay(monitor: *dom_module.performance_monitor.Monitor, event: *runtime.Instance, target: *runtime.Instance) ?i64 {
    const limit = monitor.threshold(.blocked_event) orelse return null;
    if (!(interfaces.Event.get_cancelable(event) catch false)) return null;
    var event_type = interfaces.Event.get_type(event) catch return null;
    defer event_type.deinit(event.ctx.allocator);
    if (!dom_module.performance_monitor.isScrollBlocking(event_type.asSlice())) return null;
    const now_ms = dom_module.performance_timeline.now(target.ctx) orelse return null;
    const made_ms = interfaces.Event.get_timeStamp(event) catch return null;
    const delay: i64 = @intFromFloat((now_ms - made_ms) * std.time.ns_per_ms);
    return if (delay > limit) delay else null;
}

/// After a listener ran, with a performance monitor listening: the handler
/// violation when it took the threshold (PerformanceMonitor::Did), and the
/// blockedEvent one for a non-passive listener that did not cancel
/// (FireEventListeners' ReportBlockedEvent).
fn reportListenerViolations(monitor: *dom_module.performance_monitor.Monitor, event: *runtime.Instance, target: *runtime.Instance, listener_id: u64, passive: bool, started: ?i64, blocked_delay: ?i64) void {
    const took = monitor.didCallback(false, started);
    const blocked = if (blocked_delay) |delay| (if (!passive and !(interfaces.Event.get_defaultPrevented(event) catch true)) delay else null) else null;
    if (took == null and blocked == null) return;
    var event_type = interfaces.Event.get_type(event) catch return;
    defer event_type.deinit(event.ctx.allocator);
    if (took) |duration| monitor.reportHandler(target.ctx, event_type.asSlice(), false, duration);
    if (blocked) |delay| monitor.reportBlockedEvent(target.ctx, event_type.asSlice(), listener_id, delay);
}

/// DOM §2.7 "remove an event listener", for inner invoke's step 2.5: the
/// listener whose id is `id`, if it is still in the list.
///
/// Returns the callback WITHOUT releasing it - the caller owns it until the
/// callback has finished running. `target` is the list's: its owner hears
/// of the removal, before the callback runs (WebKit's
/// innerInvokeEventListeners removes a once listener through
/// removeEventListener, which calls eventListenersDidChange).
fn detachListener(listeners: Listeners, target: *runtime.Instance, id: u56) ?Listener {
    const index = listeners.indexOfId(id) orelse return null;
    // "Set listener's removed to true and remove listener from eventTarget's
    // event listener list."
    const removed = listeners.removeAt(index);
    // Its abort steps leave its signal with it (`forgetAbortSteps`).
    if (removed.bits.abort_steps) forgetAbortSteps(registryOf(target), removed.bits.id);
    removed.type.deinit(runtime.allocatorOf(target));
    listenersChanged(listeners, target);
    // Its hold is the caller's from here (`releaseObject` after the call).
    return removed;
}

/// Inner invoke step 2.11 - "call a user object's operation" with the listener's
/// callback, "handleEvent", « event », and event's currentTarget.
///
/// `callback` is BORROWED: the record's, or the detached once listener's. The
/// call holds a value of its own, since the callback can remove its listener
/// and so release the record's.
fn callListener(callback: engine.CallbackInterface, event: *runtime.Instance, current_target: *runtime.Instance, in_shadow_tree: bool, did_throw: ?*bool, only_world: u32) void {
    const realm = current_target.ctx;
    const object = engine.retainValue(realm, callback.object.value) catch |err| {
        log.debug("listener not called: {}", .{err});
        return;
    };
    const held: engine.CallbackInterface = .{ .object = object, .context = callback.context };
    defer held.release();

    // Steps 2.9-2.10: the global of the listener callback's associated realm
    // has the event as its current event for the duration of the call
    // (`window.event`) - unless invocationTargetInShadowTree, when it keeps
    // the one it has - and step 2.15 restores whatever it was before.
    const listener_realm = associatedRealm(held.object.value) orelse held.context orelse realm;
    const listener_window = windowOfRealm(listener_realm);

    // An error report reaches the listeners of its throwing script's world
    // only (`skippedForWorld`).
    if (only_world != dom_module.event_dispatch.DispatchPath.any_world) {
        if (skippedForWorld(only_world, listener_realm)) return;
    }

    // Steps 2.6-2.8: "If targetGlobal or listenerGlobal is a Window object
    // whose associated Document is not fully active, then continue."
    // (whatwg/dom#1084; Chrome and Safari pass
    // dom/events/event-listener-not-fully-active-navigated.html 3/3.) Lane
    // events1 wrote these steps and took them back out (b38b85cb01c) for two
    // defects elsewhere, both fixed with them: an IndexedDB request is made
    // in its receiver's realm (IDBTransaction enqueueRequest), and a frame's
    // navigation API events fire while its document is still fully active
    // (destroy a child navigable step 4 runs before step 5 destroys it).
    if (!globalsFullyActive(current_target, listener_window)) return;

    // The Window keeps its current event (dom.window_globals; DOM 2.3 "Each
    // Window object has an associated current event"), looked up on each
    // swap: a listener can end the window it runs in.
    const current_event_window = if (in_shadow_tree) null else listener_window;
    const previous_event = if (current_event_window) |w| dom_module.window_globals.swapCurrentEvent(w, event) else null;
    defer if (current_event_window) |w| {
        _ = dom_module.window_globals.swapCurrentEvent(w, previous_event);
    };

    // Step 2.11: call a user object's operation with the listener's callback,
    // "handleEvent", « event », and event's currentTarget attribute value -
    // a function listener is called with `this` bound to it
    // (EventTarget-this-of-listener.html). "If this throws an exception
    // exception: report exception for listener's callback's corresponding
    // JavaScript object's associated realm's global object."
    var reporter = DispatchReporter{ .realm = realm, .did_throw = did_throw };
    const completion = engine.callUserObjectOperation(realm, &held, "handleEvent", .{ .value = .{ .instance = current_target } }, &.{.{ .instance = event }}, .{
        .report = .{ .report = DispatchReporter.report, .host = &reporter },
    }) catch |err| {
        log.debug("listener call failed: {}", .{err});
        return;
    };
    switch (completion) {
        .throw => |thrown| {
            if (did_throw) |flag| flag.* = true;
            thrown.release();
        },
        .normal => |value| value.release(),
    }
}

/// Whether a listener whose callback is of `listener_realm` is skipped
/// because the dispatch is an error report of another isolated world
/// (engine section 4.2a; dom.event_dispatch.DispatchPath.only_world):
/// Blink's ErrorEvent keeps the world of the script that threw, and
/// JSBasedEventListener::Invoke returns for a listener of another world
/// (ErrorEvent::CanBeDispatchedInWorld; third_party/blink/renderer/core/
/// events/error_event.h, bindings/core/v8/js_based_event_listener.cc; BSD-3 -
/// reproduced, not copied) - after a once listener was removed, as there.
/// The fast path is the callers': every dispatch but an error report's has
/// `any_world` - one predictable branch at each call, no lookup, the
/// listener's realm not even computed - and engine.worldOf answers the main
/// world with no lookup for a Browser that made no isolated world.
fn skippedForWorld(only_world: u32, listener_realm: runtime.Context) bool {
    return engine.worldOf(listener_realm) != only_world;
}

/// The event handler processing algorithm (HTML §8.1.8.1) for `instance`'s
/// event handler for `event`'s type - the callback of the event handler's
/// listener, run by inner invoke.
fn invokeIdlEventHandler(instance: *runtime.Instance, event: *runtime.Instance, in_shadow_tree: bool, did_throw: ?*bool, only_world: u32, handler_world: HandlerWorld) void {
    const realm = instance.ctx;
    const event_type_str = interfaces.Event.get_type(event) catch return;

    // Step 1: "Let callback be the result of getting the current value of the
    // event handler given eventTarget and name." Run a value of our own: the
    // handler can replace or clear its own attribute, which releases the
    // map's.
    // The invoked listener's world's handler (`HandlerWorld`).
    const value = currentHandlerValue(instance, event_type_str.asSlice(), handler_world) orelse return;
    const function = engine.retainValue(realm, value.callback.function.value) catch return;
    const callback: engine.CallbackFunction = .{ .function = function, .context = value.callback.context };
    defer callback.release();

    // Step 2: "If callback is null, then return." A non-callable object -
    // [LegacyTreatNonObjectAsNull] keeps one - is invoked as nothing (WebIDL
    // "invoke a callback function" step 4).
    if (!engine.isCallable(realm, callback.function.value)) return;

    // An error report reaches the handlers of its throwing script's world
    // only (`skippedForWorld`): a page's onerror never sees an isolated
    // world's error.
    if (only_world != dom_module.event_dispatch.DispatchPath.any_world) {
        if (skippedForWorld(only_world, associatedRealm(callback.function.value) orelse callback.context orelse realm)) return;
    }

    // Step 3: special error event handling - an ErrorEvent named "error" whose
    // currentTarget is a global (WindowOrWorkerGlobalScope). Brand checks go
    // through the vtable ancestry, never through a registry keyed on a
    // recyclable address.
    const special_error_event_handling = std.mem.eql(u8, event_type_str.asSlice(), "error") and
        event.stateAs(interfaces.ErrorEvent.State) != null and
        (instance.stateAs(interfaces.Window.State) != null or
            instance.stateAs(interfaces.WorkerGlobalScope.State) != null);

    // Step 4: invoke callback with the event - or, for special error event
    // handling, with the event's message, filename, lineno, colno and error -
    // with callback this value set to event's currentTarget.
    const event_argument = [_]runtime.JSValue{.{ .instance = event }};
    var error_arguments: ErrorEventArguments = undefined;
    const args: []const runtime.JSValue = if (special_error_event_handling) blk: {
        error_arguments = ErrorEventArguments.of(event) catch return;
        break :blk &error_arguments.values;
    } else &event_argument;
    defer if (special_error_event_handling) error_arguments.deinit(event.ctx.allocator);

    // DOM inner invoke steps 2.9-2.10 and 2.15 for the event handler's
    // listener. Its listenerGlobal is the handler function's realm's global,
    // not the target's: golden rule 2 - Chrome and Safari pass
    // dom/events/event-global-is-still-set-when-reporting-exception-onerror.html
    // (window.onerror set to another frame's function sets THAT frame's
    // window.event), Firefox fails it as Crane did. No current event is set
    // for an invocation target in a shadow tree (step 2.10.2).
    // Steps 2.6-2.8 as callListener runs them.
    const listener_window = windowOfRealm(associatedRealm(callback.function.value) orelse callback.context orelse realm);
    if (!globalsFullyActive(instance, listener_window)) return;
    const handler_window = if (in_shadow_tree) null else listener_window;
    const previous_event = if (handler_window) |w| dom_module.window_globals.swapCurrentEvent(w, event) else null;
    defer if (handler_window) |w| {
        _ = dom_module.window_globals.swapCurrentEvent(w, previous_event);
    };

    // "If an exception gets thrown by the callback, it will be rethrown,
    // ending these steps. The exception will propagate to the DOM event
    // dispatch logic, which will then report it" - for the global of the
    // callback's associated realm (DOM inner invoke step 2.11): reported
    // here, and the completion is then normal undefined, which step 5 ignores.
    var reporter = DispatchReporter{ .realm = realm, .did_throw = did_throw };
    const behavior: engine.ExceptionBehavior = .{
        .report = .{ .report = DispatchReporter.report, .host = &reporter },
    };
    // HTML event handler processing step 4: beforeunload uses DOMString?
    // even for an ordinary Event. WebIDL invoke converts before cleanup of
    // either callback scope; a throwing toString is reported by DOM here.
    const beforeunload = std.mem.eql(u8, event_type_str.asSlice(), "beforeunload");
    if (beforeunload) {
        const completion = callbacks.call.OnBeforeUnloadEventHandlerNonNull.invoke(
            realm,
            &callback,
            .{ .value = .{ .instance = instance } },
            .{ .event = event },
            behavior,
            event.ctx.allocator,
        ) catch |err| {
            log.debug("event handler not invoked: {}", .{err});
            return;
        };
        const held = switch (completion) {
            .normal => |normal| normal,
            .throw => |thrown| {
                if (did_throw) |flag| flag.* = true;
                thrown.release();
                return;
            },
        };
        defer held.release(event.ctx.allocator);

        // Step 5: "If event is a BeforeUnloadEvent object and event's type is
        // beforeunload": return value is already converted to DOMString?.
        // "If return value is not null, then: set event's canceled flag; if
        // event's returnValue attribute's value is the empty string, then set
        // it to return value." (An ordinary Event("beforeunload") never sees
        // boolean false from a DOMString? callback.)
        if (event.stateAs(interfaces.BeforeUnloadEvent.State) != null) {
            const text = held.value orelse return;
            dom_module.event_construction.forceCanceledFlag(event);
            const current = interfaces.BeforeUnloadEvent.get_returnValue(event) catch return;
            if (current.asSlice().len == 0) {
                interfaces.BeforeUnloadEvent.set_returnValue(event, runtime.DOMString.initInterned(text.asSlice())) catch {};
            }
        }
        return;
    }

    const completion = engine.invokeCallbackFunction(realm, &callback, .{ .value = .{ .instance = instance } }, args, behavior) catch |err| {
        log.debug("event handler not invoked: {}", .{err});
        return;
    };
    const return_value = switch (completion) {
        .normal => |normal| normal,
        .throw => |thrown| {
            if (did_throw) |flag| flag.* = true;
            thrown.release();
            return;
        },
    };
    defer return_value.release();

    // Step 5: process the return value.
    // Otherwise only an exact true (special error handling) or an exact
    // false (everything else) cancels - through preventDefault's "set the
    // canceled flag", which respects cancelable and the passive listener
    // flag, as Blink's and WebKit's handlers do.
    if (engine.typeOf(realm, return_value.value) != .boolean) return;
    if (engine.toBoolean(realm, return_value.value) == special_error_event_handling) {
        interfaces.Event.call_preventDefault(event) catch {};
    }
}

/// The five arguments `onerror` on a global is invoked with: the ErrorEvent's
/// message, filename, lineno, colno and error. The strings are the getters'
/// copies and the error is the getter's hold (a getter's result is its
/// caller's - retainValue().take()), all released by `deinit`.
const ErrorEventArguments = struct {
    message: runtime.DOMString,
    filename: []const u8,
    @"error": engine.Owned,
    values: [5]runtime.JSValue,

    fn of(event: *runtime.Instance) !ErrorEventArguments {
        const ErrorEvent = interfaces.ErrorEvent;
        const allocator = event.ctx.allocator;
        // Getters hand ownership of their strings to the caller (AGENTS.md).
        var message = try ErrorEvent.get_message(event);
        errdefer message.deinit(allocator);
        const filename = try ErrorEvent.get_filename(event);
        const @"error": engine.Owned = .{ .value = ErrorEvent.get_error(event) catch runtime.JSValue.jsUndefined };
        return .{
            .message = message,
            .filename = filename,
            .@"error" = @"error",
            .values = .{
                runtime.JSValue.fromStringRef(message.asSlice()),
                runtime.JSValue.fromStringRef(filename),
                runtime.JSValue.fromNumber(@floatFromInt(ErrorEvent.get_lineno(event) catch 0)),
                runtime.JSValue.fromNumber(@floatFromInt(ErrorEvent.get_colno(event) catch 0)),
                @"error".value,
            },
        };
    }

    fn deinit(self: *ErrorEventArguments, allocator: std.mem.Allocator) void {
        self.message.deinit(allocator);
        if (self.filename.len > 0) allocator.free(self.filename);
        self.@"error".release();
    }
};

/// The realm of `value`, a callback's JavaScript object: its function realm
/// where the engine knows it exactly, else null (the caller falls back to
/// the callback context).
fn associatedRealm(value: runtime.JSValue) ?runtime.Context {
    if (comptime engine.capabilities.exact_function_realm == .unsupported) return null;
    return engine.functionRealm(value);
}

/// `realm`'s global object, when it is a Window.
fn windowOfRealm(realm: runtime.Context) ?*runtime.Instance {
    const record = realm.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    if (global.stateAs(interfaces.Window.State) == null) return null;
    return global;
}

/// DOM inner invoke steps 2.6-2.8: false when targetGlobal - the relevant
/// global of `current_target`'s node document, or of `current_target` when
/// it is not a node - or `listener_window` is a Window whose associated
/// Document is not fully active. Asked before every listener call: a
/// listener can adopt the target into another document or remove the frame
/// it lives in.
fn globalsFullyActive(current_target: *runtime.Instance, listener_window: ?*runtime.Instance) bool {
    // Step 2.6: targetGlobal's realm. One that has ended - a removed
    // frame's - has no global left to ask, and its Window's associated
    // Document was destroyed with it: not fully active. A retired realm
    // keeps its agent; a context that never had an engine (native parsing)
    // has none and no realm to end (KeptInstance.get draws the same line).
    const target_realm = targetGlobalRealm(current_target);
    if (!target_realm.hasEngine() and target_realm.agent != null) return false;
    const target_window = windowOfRealm(target_realm);
    if (target_window) |w| {
        if (!windowFullyActive(w)) return false;
    }
    // Steps 2.7-2.8: listenerGlobal.
    if (listener_window) |w| {
        if (w != target_window and !windowFullyActive(w)) return false;
    }
    return true;
}

/// Step 2.6: the realm of targetGlobal - "event's currentTarget's node
/// document's relevant global object if event's currentTarget is a node;
/// otherwise event's currentTarget's relevant global object".
fn targetGlobalRealm(current_target: *runtime.Instance) runtime.Context {
    if (current_target.stateAs(interfaces.Node.State) == null) return current_target.ctx;
    // A document is its own node document (ownerDocument reads null).
    const document = (interfaces.Node.get_ownerDocument(current_target) catch null) orelse current_target;
    return document.ctx;
}

/// Whether `window`'s associated Document is fully active.
///
/// Every Window a navigable makes has an associated Document. A Window made
/// with no navigable - a bare realm's, as unit tests make them - has none,
/// so there is no Document to be inactive and its listeners run.
fn windowFullyActive(window: *runtime.Instance) bool {
    if (dom_module.document_activity.fullyActive(window, runtime.SlabAllocator.generationOf(window))) return true;
    _ = interfaces.Window.get_document(window) catch return true;
    return false;
}

/// The report behavior turns an abrupt completion into normal undefined.
/// Observe it where the engine reports, retaining the exact throw-site info.
const DispatchReporter = struct {
    realm: runtime.Context,
    did_throw: ?*bool,

    fn report(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
        const self: *DispatchReporter = @ptrCast(@alignCast(host.?));
        // DOM inner invoke 2.13.1: report for the callback's associated realm.
        reportException(self.realm, info);
        // DOM inner invoke 2.13.2: set the legacy output flag, if given.
        if (self.did_throw) |flag| flag.* = true;
    }
};

/// DOM inner invoke step 2.11 / the event handler processing algorithm's
/// rethrow: HTML "report an exception" for the global of the realm the engine
/// names - the callback's associated realm - or else the target's (`host`).
fn reportException(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
    const target_realm: runtime.Context = @ptrCast(@alignCast(host orelse return));
    const realm = info.realm orelse target_realm;
    const record = realm.getRealm() orelse return;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return));
    // Step 2's error information is the engine's, extracted where the
    // exception was thrown.
    const extracted: runtime.ErrorInfo = .{
        .message = info.message,
        .filename = info.filename,
        .lineno = info.lineno,
        .colno = info.colno,
        .error_value = if (info.error_value == .undefined) null else info.error_value,
        // The callback's realm: an isolated world's error event is that
        // world's only (report_exception).
        .realm = realm,
    };
    _ = @import("html").report_exception.reportErrorInfo(global, &extracted, .{});
}

/// Operation: when (Observable)
/// Spec: https://wicg.github.io/observable-api/#dom-eventtarget-when
/// This is part of the Observable API proposal
pub fn call_when(instance: *runtime.Instance, @"type": runtime.DOMString, options: webidl.Opt(dictionaries.ObservableEventListenerOptions)) anyerror!*runtime.Instance {
    _ = instance;
    _ = @"type";
    _ = options;
    // TODO: Implement Observable API
    return error.NotImplemented;
}

// ============================================================================
// Helper functions for subclasses (Node, Element, etc.)
// ============================================================================

/// The node type of an EventTarget that is a node, 0 for one that is not:
/// its NodeBase's, which Node's construction sets (no copy is kept here).
pub fn getNodeType(instance: *runtime.Instance) u16 {
    const node_base = dom_module.instance_bridge.getNodeBase(instance) orelse return 0;
    return node_base.node_type;
}

/// dom.event_handlers: whether `instance`'s event listener list holds a
/// listener whose removed is false - an event handler's included. Every
/// listener in the list is one (a removed one has left it).
fn hasListeners(instance: *runtime.Instance) bool {
    const listeners = listenersOf(instance) orelse return false;
    return listeners.len() > 0;
}

/// dom.event_listener_types: whether `instance`'s event listener list holds
/// a listener of `event_type` whose removed is false - an activated event
/// handler's included.
fn hasListenersOfType(instance: *runtime.Instance, event_type: []const u8) bool {
    const listeners = listenersOf(instance) orelse return false;
    const key = EventTypeKey.of(event_type);
    for (listeners.view()) |listener| {
        if (listener.type.matches(key)) return true;
    }
    return false;
}
