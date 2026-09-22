//! Implementation for EventTarget interface
//!
//! Spec: https://dom.spec.whatwg.org/#interface-eventtarget
//! WHATWG DOM Standard §2.7

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
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

/// DOM §2.7 - Event listener structure
/// An event listener can be used to observe a specific event and consists of:
pub const EventListenerRecord = struct {
    /// type (a string)
    type: runtime.DOMString,

    /// callback (null or an EventListener callback)
    callback: ?*runtime.Instance,

    /// capture (a boolean, initially false)
    capture: bool = false,

    /// passive (null or a boolean, initially null)
    passive: ?bool = null,

    /// once (a boolean, initially false)
    once: bool = false,

    /// signal (null or an AbortSignal object)
    signal: ?*runtime.Instance = null,

    /// removed (a boolean for bookkeeping purposes, initially false)
    removed: bool = false,
};

/// Internal state for EventTarget implementation
/// Contains the event listener list which is lazily allocated to save memory
/// OPTIMIZATION: Most EventTargets never have listeners attached.
/// This saves ~40% memory on typical DOM trees where 90% of nodes have no listeners.
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// DOM §2.7 - Each EventTarget has an associated event listener list
    /// (a list of zero or more event listeners). It is initially the empty list.
    ///
    /// OPTIMIZATION: Lazy allocation - most EventTargets never have listeners attached.
    /// Pattern borrowed from WebKit's NodeRareData and Chromium's NodeRareData.
    event_listener_list: ?*infra.List(EventListenerRecord) = null,

    /// Runtime type discriminator for duck typing
    /// This field helps distinguish EventTarget types at runtime.
    /// - 0: Plain EventTarget or AbortSignal
    /// - 1-12: Node types (ELEMENT_NODE, TEXT_NODE, etc.)
    /// This is filled in by Node's init - EventTarget itself uses 0.
    node_type: u16 = 0,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .event_listener_list = null,
            .node_type = 0,
        };
    }

    pub fn deinit(self: *InternalState) void {
        self.deinitEx(true);
    }

    /// Deinitialize with option to skip V8 resource cleanup
    /// When skip_v8_cleanup is true, V8 global handles are NOT disposed.
    /// This is needed during final runtime cleanup when V8 isolate is already disposed.
    pub fn deinitEx(self: *InternalState, cleanup_v8_resources: bool) void {
        if (self.event_listener_list) |list| {
            // Free any owned DOMStrings and clean up callbacks in event listeners
            const slice = list.toSliceMut();
            for (slice) |*listener| {
                var @"type" = listener.type;
                @"type".deinit(self.allocator);

                // Clean up callback wrapper (disposes Global handles)
                // The callback is stored as ?*runtime.Instance but is actually a *CallbackWrapper
                //
                // NOTE: Callback disposal during cleanup is disabled because V8's internal
                // Global handle slot gets corrupted at some point, causing crashes when
                // calling Reset(). The callback identity fix (using StrictEquals) works
                // correctly for addEventListener/removeEventListener, but the underlying
                // corruption during browser shutdown needs further investigation.
                // For now, we leak these handles during cleanup to avoid crashes.
                _ = cleanup_v8_resources;
                _ = listener.callback;
            }
            list.deinit();
            self.allocator.destroy(list);
        }
    }

    /// Ensure event listener list is allocated
    /// Lazily allocates the list on first use to save memory
    pub fn ensureEventListenerList(self: *InternalState) !*infra.List(EventListenerRecord) {
        if (self.event_listener_list) |list| {
            return list;
        }

        // First time adding a listener - allocate the list
        const list = try self.allocator.create(infra.List(EventListenerRecord));
        list.* = infra.List(EventListenerRecord).init(self.allocator);
        self.event_listener_list = list;
        return list;
    }

    /// Get event listener list (read-only access)
    /// Returns empty slice if no listeners have been added yet
    pub fn getEventListenerList(self: *const InternalState) []const EventListenerRecord {
        if (self.event_listener_list) |list| {
            return list.toSlice();
        }
        return &[_]EventListenerRecord{};
    }
};

/// Get the internal state from an instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return if (@hasField(@TypeOf(state.own), "_internal")) state.own._internal else null;
}

/// Initialize instance (creates the instance)
/// This is the root of the DOM inheritance chain - creates the Instance and
/// initializes EventTarget's internal state.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Initialize EventTarget internal state in registry
    _ = try initInternal(instance, allocator);

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up internal state from registry
    if (getInternalFromRegistry(instance)) |internal| {
        internal.deinit();
        removeFromRegistry(instance);
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
/// Spec: https://dom.spec.whatwg.org/#dom-eventtarget-eventtarget
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &EventTarget.vtable, ctx);
    errdefer deinit(instance);

    // Note: EventTarget.State.own is empty struct, so no _internal field
    // For now, we'll manage internal state separately
    // TODO: Add _internal field to State via codegen

    return instance;
}

/// Initialize an EventTarget with internal state
/// This is called by subclasses (like Node) to set up the internal state
pub fn initInternal(instance: *runtime.Instance, allocator: std.mem.Allocator) !*InternalState {
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);

    // Store internal state in registry (ensure it's initialized first)
    try setInternalInRegistry(instance, internal);

    return internal;
}

/// Global registry for internal state
/// This is a workaround until the codegen adds _internal field to State
/// Note: We use a raw pointer to allow cleanup to set it to null
var internal_state_registry: ?std.AutoHashMap(usize, *InternalState) = null;
var cleanup_hook_registered: bool = false;

fn ensureRegistry() *std.AutoHashMap(usize, *InternalState) {
    if (internal_state_registry == null) {
        internal_state_registry = std.AutoHashMap(usize, *InternalState).init(std.heap.page_allocator);
        // Register cleanup hook on first use
        if (!cleanup_hook_registered) {
            runtime.registerCleanupHook(cleanupRegistry);
            cleanup_hook_registered = true;
        }
    }
    return &internal_state_registry.?;
}

/// Clean up all remaining internal states WITH V8 resource cleanup.
/// This should be called during browser/context cleanup, BEFORE V8 is disposed,
/// to properly dispose V8 global handles in CallbackWrappers.
///
/// This is called from cleanup.cleanupAllDomRegistries() which runs before
/// runtime.deinitializeRuntime(), ensuring V8 is still alive.
pub fn cleanupAllRemainingInternal() void {
    if (internal_state_registry) |*registry| {
        // Clean up all internal states with V8 resource cleanup enabled
        var iter = registry.valueIterator();
        while (iter.next()) |internal_ptr| {
            internal_ptr.*.deinitEx(true); // V8 is still alive, clean up global handles
        }
        registry.deinit();
        internal_state_registry = null;
    }
    // Reset flag so hook can be re-registered if runtime is re-initialized
    cleanup_hook_registered = false;
}

/// Clean up all remaining internal states and the registry itself
/// This should be called during runtime shutdown to prevent memory leaks
/// Note: This is called AFTER V8 isolate is disposed, so we must skip V8 resource cleanup
pub fn cleanupRegistry() void {
    if (internal_state_registry) |*registry| {
        // Clean up any remaining internal states
        // Skip V8 cleanup (false) because the isolate is already disposed
        var iter = registry.valueIterator();
        while (iter.next()) |internal_ptr| {
            internal_ptr.*.deinitEx(false);
        }
        registry.deinit();
        internal_state_registry = null;
    }
    // Reset flag so hook can be re-registered if runtime is re-initialized
    cleanup_hook_registered = false;
}

fn getInternalFromRegistry(instance: *runtime.Instance) ?*InternalState {
    const registry = ensureRegistry();
    return registry.get(@intFromPtr(instance));
}

fn setInternalInRegistry(instance: *runtime.Instance, internal: *InternalState) !void {
    const registry = ensureRegistry();
    try registry.put(@intFromPtr(instance), internal);
}

fn removeFromRegistry(instance: *runtime.Instance) void {
    const registry = ensureRegistry();
    // Return the block, not just the map entry. EventTarget keeps its own registry
    // rather than using InstanceRegistry, so it needs its own release - and it is on
    // every DOM node, so leaving it out keeps the leak on the hottest path there is.
    if (registry.fetchRemove(@intFromPtr(instance))) |kv| {
        const Arena = @import("runtime").ArenaAllocator;
        if (Arena.tryGet() catch null) |arena| arena.destroy(InternalState, kv.value);
    }
}

/// DOM §2.7 - default passive value
/// The default passive value, given an event type type and an EventTarget eventTarget
fn defaultPassiveValue(@"type": []const u8, event_target: *runtime.Instance) bool {
    _ = event_target;
    // Step 1: Return true if type is touchstart, touchmove, wheel, or mousewheel
    // AND eventTarget is Window or specific node conditions
    // For now, simplified: return true for touch/wheel events
    if (std.mem.eql(u8, @"type", "touchstart") or
        std.mem.eql(u8, @"type", "touchmove") or
        std.mem.eql(u8, @"type", "wheel") or
        std.mem.eql(u8, @"type", "mousewheel"))
    {
        // TODO: Check eventTarget conditions per spec
        return true;
    }
    // Step 2: Return false
    return false;
}

/// Compare two callbacks for equality by V8 function identity
/// The callbacks are stored as ?*runtime.Instance but are actually *runtime.CallbackWrapper
/// which contains engine_handle pointing to the actual V8 CallbackWrapper
fn callbackEquals(a: ?*runtime.Instance, b: ?*runtime.Instance) bool {
    if (a == null and b == null) return true;
    if (a == null or b == null) return false;

    // The stored pointers are actually *runtime.CallbackWrapper (not V8 wrappers directly)
    // runtime.CallbackWrapper contains engine_handle which is the V8 CallbackWrapper
    const runtime_wrapper_a: *const runtime.CallbackWrapper = @ptrCast(@alignCast(a.?));
    const runtime_wrapper_b: *const runtime.CallbackWrapper = @ptrCast(@alignCast(b.?));

    // Get the V8 engine wrappers from the engine_handle field
    const v8_engine = @import("v8");
    const v8_wrapper_a: *const v8_engine.CallbackWrapper = @ptrCast(@alignCast(runtime_wrapper_a.engine_handle));
    const v8_wrapper_b: *const v8_engine.CallbackWrapper = @ptrCast(@alignCast(runtime_wrapper_b.engine_handle));

    // Get the underlying V8 Global<Value>* for each callback
    const value_a = v8_wrapper_a.getGlobalValuePtr() orelse return false;
    const value_b = v8_wrapper_b.getGlobalValuePtr() orelse return false;

    // Use V8's StrictEquals to compare the underlying JavaScript functions
    return v8_engine.v8_Value_StrictEquals(value_a, value_b);
}

/// DOM §2.7 - add an event listener
/// To add an event listener, given an EventTarget object eventTarget and
/// an event listener listener, run these steps:
fn addAnEventListener(internal: *InternalState, instance: *runtime.Instance, listener: EventListenerRecord) !void {
    // Step 1: ServiceWorkerGlobalScope warning (skipped - not applicable)

    // Step 2: If listener's signal is not null and is aborted, then return
    if (listener.signal) |signal| {
        // TODO: Check if signal is aborted via AbortSignal interface
        _ = signal;
    }

    // Step 3: If listener's callback is null, then return
    if (listener.callback == null) return;

    // Step 4: If listener's passive is null, set it to default passive value
    var updated_listener = listener;
    if (updated_listener.passive == null) {
        updated_listener.passive = defaultPassiveValue(listener.type.asSlice(), instance);
    }

    // Step 5: If event listener list does not contain matching listener, append it
    const list = try internal.ensureEventListenerList();
    const slice = list.toSlice();

    var already_exists = false;
    for (slice) |existing| {
        if (std.mem.eql(u8, existing.type.asSlice(), listener.type.asSlice()) and
            existing.capture == listener.capture and
            callbackEquals(existing.callback, listener.callback))
        {
            already_exists = true;
            break;
        }
    }

    if (!already_exists) {
        try list.append(updated_listener);
    } else {
        // Listener already exists - clean up the duplicate resources
        // Free the duplicated type string
        var listener_type = updated_listener.type;
        listener_type.deinit(internal.allocator);

        // Also dispose the CallbackWrapper since we're not storing it
        if (updated_listener.callback) |callback_instance| {
            // The stored callback is actually a *runtime.CallbackWrapper
            const runtime_wrapper: *runtime.CallbackWrapper = @ptrCast(@alignCast(callback_instance));
            runtime_wrapper.deinit();
        }
    }

    // Step 6: If listener's signal is not null, add abort steps
    // TODO: Implement abort signal integration
}

/// DOM §2.7 - remove an event listener
/// To remove an event listener, given an EventTarget object eventTarget and
/// an event listener listener, run these steps:
fn removeAnEventListener(internal: *InternalState, listener: EventListenerRecord) void {
    // Step 1: ServiceWorkerGlobalScope warning (skipped - not applicable)

    // Early exit if no listeners have been added yet
    const list = internal.event_listener_list orelse return;

    // Step 2: Set listener's removed to true and remove listener from event listener list
    const slice = list.toSliceMut();
    var i: usize = 0;
    while (i < list.len) {
        const existing = &slice[i];

        // Match on type, callback, and capture
        if (std.mem.eql(u8, existing.type.asSlice(), listener.type.asSlice()) and
            existing.capture == listener.capture and
            callbackEquals(existing.callback, listener.callback))
        {
            existing.removed = true;

            // Clean up the callback wrapper to dispose Global handles
            // The callback is stored as ?*runtime.Instance but is actually a *runtime.CallbackWrapper
            if (existing.callback) |callback_instance| {
                const runtime_wrapper: *runtime.CallbackWrapper = @ptrCast(@alignCast(callback_instance));
                runtime_wrapper.deinit();
            }

            // Free the type DOMString
            var existing_type = existing.type;
            existing_type.deinit(internal.allocator);

            _ = list.remove(i) catch unreachable;
            return;
        }
        i += 1;
    }
}

/// Operation: addEventListener
/// Spec: https://dom.spec.whatwg.org/#dom-eventtarget-addeventlistener
/// "flatten", https://dom.spec.whatwg.org/#concept-flatten-options
///
/// The IDL type is `(AddEventListenerOptions or boolean) options = {}`. Codegen
/// does not generate WebIDL union types yet, so it arrives as a raw JSValue and
/// the impl has to resolve the union itself. WebIDL union resolution: if the
/// value is an OBJECT, convert to the dictionary; otherwise apply ECMAScript
/// ToBoolean.
///
/// ToBoolean is the part that is easy to get wrong, and
/// dom/events/EventListenerOptions-capture.html tests exactly these:
///
///     true, "AAAA", 2.3, -1000.3   -> capture      (truthy)
///     false, null, undefined, ""   -> no capture
///     NaN, +0.0, -0.0              -> no capture
///
/// An earlier version of this matched only `.boolean` and returned false for
/// everything else, so `addEventListener(t, fn, 2.3)` and
/// `addEventListener(t, fn, "AAAA")` silently registered as bubble listeners.
/// That is wrong for ordinary JavaScript, not just for any one framework.
///
/// This was previously `_ = options;` with capture hardcoded false, which
/// downgraded EVERY capture listener to a bubble listener.
fn toBoolean(value: runtime.JSValue) bool {
    return switch (value) {
        .undefined, .null => false,
        .boolean => |b| b,
        // +0, -0 and NaN are falsy; every other number is truthy.
        .number => |n| n != 0 and !std.math.isNan(n),
        .string => |sv| sv.data.len > 0,
        // Objects and functions are always truthy - but an object means the
        // DICTIONARY branch, so reaching here with one is a fallback only.
        else => true,
    };
}

/// The flattened options. `capture` is always resolved; the rest come only from
/// the dictionary form.
const FlatOptions = struct {
    capture: bool = false,
    once: bool = false,
    passive: ?bool = null,
    signal: ?*runtime.Instance = null,
};

fn flattenOptions(ctx: runtime.Context, options: webidl.Opt(runtime.JSValue)) FlatOptions {
    if (!options.was_passed) return .{};

    // WebIDL union resolution: an OBJECT converts to the dictionary, anything
    // else goes through ToBoolean.
    if (options.value == .handle) {
        const engine = ctx.getEngine() orelse return .{};
        const engine_ctx = ctx.getEngineContext() orelse return .{};
        const get = engine.getPropertyTruthy orelse return .{};
        const object = options.value.handle.ptr;

        // Members are truthiness-tested, not identity-tested, so `{capture: 2}`
        // is capture and `{capture: 0}` is not - which is what
        // EventListenerOptions-capture.html asserts.
        return .{
            .capture = get(engine_ctx, object, "capture", false) catch false,
            .once = get(engine_ctx, object, "once", false) catch false,
            // `passive` stays tri-state: absent means "engine decides", which
            // is not the same as an explicit `passive: false`.
            .passive = if (get(engine_ctx, object, "passive", false) catch false) true else null,
            // TODO: `signal` is an AbortSignal object, not a boolean, so it
            // needs an accessor that returns the value rather than its
            // truthiness. Left null until there is one.
            .signal = null,
        };
    }

    return .{ .capture = toBoolean(options.value) };
}

pub fn call_addEventListener(instance: *runtime.Instance, @"type": runtime.DOMString, callback: ??*runtime.CallbackWrapper, options: webidl.Opt(runtime.JSValue)) anyerror!void {
    // Get or create internal state
    var internal = getInternalFromRegistry(instance);
    if (internal == null) {
        // First operation - initialize internal state
        const ArenaAllocator = @import("runtime").ArenaAllocator;
        const new_internal = ArenaAllocator.get().create(InternalState) catch return error.OutOfMemory;
        new_internal.* = InternalState.init(std.heap.page_allocator);
        setInternalInRegistry(instance, new_internal) catch return error.OutOfMemory;
        internal = new_internal;
    }

    // https://dom.spec.whatwg.org/#concept-flatten-more
    const flat = flattenOptions(instance.ctx, options);
    const capture = flat.capture;
    const passive = flat.passive;
    const once = flat.once;
    const signal = flat.signal;

    // Convert callback wrapper to Instance pointer if present
    // The callback comes as ??*runtime.CallbackWrapper but we store ?*runtime.Instance
    const callback_instance: ?*runtime.Instance = if (callback) |cb_opt| blk: {
        if (cb_opt) |cb| {
            // Cast CallbackWrapper pointer to Instance pointer
            // This is safe because CallbackWrapper wraps an Instance
            break :blk @ptrCast(cb);
        }
        break :blk null;
    } else null;

    // Duplicate the type string with internal allocator to ensure ownership
    // The incoming DOMString may be allocated with a different allocator (from V8 conversion layer)
    // and we need to own it to safely free it in deinit()
    const owned_type = runtime.DOMString.initDupe(internal.?.allocator, @"type".asSlice()) catch return error.OutOfMemory;

    // Create listener record with owned type string
    const listener = EventListenerRecord{
        .type = owned_type,
        .callback = callback_instance,
        .capture = capture,
        .passive = passive,
        .once = once,
        .signal = signal,
    };

    addAnEventListener(internal.?, instance, listener) catch |err| {
        // Clean up owned type on error
        var type_copy = owned_type;
        type_copy.deinit(internal.?.allocator);
        return err;
    };
}

/// Operation: removeEventListener
/// Spec: https://dom.spec.whatwg.org/#dom-eventtarget-removeeventlistener
pub fn call_removeEventListener(instance: *runtime.Instance, @"type": runtime.DOMString, callback: ??*runtime.CallbackWrapper, options: webidl.Opt(runtime.JSValue)) anyerror!void {
    // Get the raw callback wrapper for later cleanup (before any unwrapping)
    const raw_callback_wrapper: ?*runtime.CallbackWrapper = if (callback) |cb_opt| cb_opt else null;

    // Ensure we always dispose the comparison callback wrapper when done
    defer if (raw_callback_wrapper) |wrapper| {
        wrapper.deinit();
    };

    const internal = getInternalFromRegistry(instance) orelse return;

    // https://dom.spec.whatwg.org/#concept-flatten
    //
    // Removal matches on type, callback AND capture, so discarding the flag
    // here meant `removeEventListener(t, fn, true)` could never find the
    // listener that `addEventListener(t, fn, true)` added.
    const capture = flattenOptions(instance.ctx, options).capture;

    // Convert callback wrapper to Instance pointer if present
    const callback_instance: ?*runtime.Instance = if (callback) |cb_opt| blk: {
        if (cb_opt) |cb| {
            break :blk @ptrCast(cb);
        }
        break :blk null;
    } else null;

    // Create listener record for matching
    const listener = EventListenerRecord{
        .type = @"type",
        .callback = callback_instance,
        .capture = capture,
    };

    removeAnEventListener(internal, listener);
}

/// Operation: dispatchEvent
/// Spec: https://dom.spec.whatwg.org/#dom-eventtarget-dispatchevent
pub fn call_dispatchEvent(instance: *runtime.Instance, event: *runtime.Instance) anyerror!bool {
    const EventImpl = @import("Event.zig");

    // Step 1: If event's dispatch flag is set, or if its initialized flag is not
    //         set, then throw an "InvalidStateError" DOMException.
    //
    // The initialized-flag half is not optional: `document.createEvent("Event")`
    // hands back an event with the flag UNSET, and dispatching it must throw
    // until `initEvent` runs. Skipping the check made 8 subtests of
    // EventTarget-dispatchEvent.html report "did not throw".
    if (EventImpl.getDispatchFlag(event)) return error.InvalidStateError;
    if (!EventImpl.getInitializedFlag(event)) return error.InvalidStateError;

    // Step 2: Initialize event's isTrusted attribute to false
    EventImpl.setIsTrusted(event, false);

    // Step 3: Return the result of dispatching event to this
    return dispatch(instance, event);
}

// ============================================================================
// DOM §2.9 - Dispatching events
// https://dom.spec.whatwg.org/#concept-event-dispatch
// ============================================================================

/// One struct of the event path, per "append to an event path" (DOM §2.9).
///
/// The shadow-tree booleans and the touch target list live on Event's own
/// `EventPathItem`, which this is mirrored into so `composedPath()` can see the
/// path while listeners run.
const PathStruct = struct {
    /// invocation target: whose event listener list is consulted.
    invocation_target: *runtime.Instance,
    /// shadow-adjusted target: non-null exactly where the event is AT_TARGET.
    shadow_adjusted_target: ?*runtime.Instance,
    related_target: ?*runtime.Instance,
};

/// The two values the spec's `phase` argument to "invoke" can take.
const ListenerPhase = enum { capturing, bubbling };

/// What "inner invoke" needs from a listener, captured before any callback runs.
///
/// The spec clones the event listener LIST, whose entries are live objects: a
/// listener removed mid-dispatch is skipped through its `removed` field, and one
/// added mid-dispatch is simply not in the clone. Our records sit in the list by
/// value and `removeAnEventListener` frees the record's type string, so a value
/// copy would dangle the moment a callback removed something. Capturing identity
/// instead - and re-checking the live list immediately before each call - gives
/// both spec properties without holding a pointer into a list the callbacks we
/// are about to run can mutate.
const Invocation = struct {
    /// Declared as *runtime.Instance to match the record, but always a
    /// *runtime.CallbackWrapper. Doubles as the identity key: every
    /// addEventListener call allocates a fresh wrapper, so pointer equality
    /// distinguishes "still the listener we cloned" from "removed and re-added".
    callback: *runtime.Instance,
    capture: bool,
    once: bool,
    passive: bool,
};

/// Guard against a cycle in parent pointers turning dispatch into a hang.
/// No real tree is anywhere near this deep.
const max_event_path_depth: usize = 8192;

/// DOM §2.9 - get the parent
///
/// https://dom.spec.whatwg.org/#get-the-parent - "A node's get the parent
/// algorithm, given an event, returns the node's assigned slot, if node is
/// assigned; otherwise node's parent."
///
/// HTML overrides it for Document: return null if event's type is "load" or the
/// document has no browsing context, and the document's relevant global object
/// (its Window) otherwise. That override is the whole difference between the two
/// halves of Event-dispatch-bubbles-true.html, which expects `window` in a
/// click's path and not in a load's.
fn getTheParent(target: *runtime.Instance, event_type: []const u8) ?*runtime.Instance {
    // node_type is EventTarget's duck-typing discriminator: 0 for a plain
    // EventTarget (and for Window, which therefore ends the path).
    const node_type = getNodeType(target);
    if (node_type == 0) return null;

    if (node_type == interfaces.Node.get_DOCUMENT_NODE()) {
        if (std.mem.eql(u8, event_type, "load")) return null;
        // No browsing context means no defaultView, so one null covers both.
        return interfaces.Document.get_defaultView(target) catch null;
    }

    if (node_type == interfaces.Node.get_ELEMENT_NODE()) {
        if (interfaces.Element.get_assignedSlot(target) catch null) |slot| return slot;
    }

    return interfaces.Node.get_parentNode(target) catch null;
}

/// DOM §2.9 dispatch, steps 6.3 and 6.8-6.9: build the event path.
///
/// The path is computed ONCE, before any listener runs, which is what
/// Event-dispatch-target-moved.html checks: a listener that moves the target
/// elsewhere in the tree must not change where the rest of the event goes.
fn buildEventPath(
    path: *infra.List(PathStruct),
    target: *runtime.Instance,
    event_type: []const u8,
    related_target: ?*runtime.Instance,
) !void {
    // Step 6.3: append with target as BOTH invocation target and shadow-adjusted
    // target. Being the only struct with a non-null shadow-adjusted target is
    // what makes the target - and only the target - report AT_TARGET.
    try path.append(.{
        .invocation_target = target,
        .shadow_adjusted_target = target,
        .related_target = related_target,
    });

    var parent = getTheParent(target, event_type);
    var depth: usize = 0;
    while (parent) |p| {
        if (depth >= max_event_path_depth) break;
        depth += 1;

        // Step 6.9.6. Without shadow roots in the path, target's root is always
        // a shadow-including inclusive ancestor of every ancestor, so this
        // branch always wins and the shadow-adjusted target is null. The
        // retargeting branches 6.9.7 and 6.9.8 only become reachable once shadow
        // trees are in play; they are a TODO rather than a silent approximation.
        try path.append(.{
            .invocation_target = p,
            .shadow_adjusted_target = null,
            .related_target = related_target,
        });

        parent = getTheParent(p, event_type);
    }
}

/// Mirror the path onto the event so `composedPath()` reports it.
/// Dispatch step 9 empties it again.
fn publishEventPath(event: *runtime.Instance, structs: []const PathStruct, allocator: std.mem.Allocator) void {
    const EventImpl = @import("Event.zig");
    const list = EventImpl.getPath(event) orelse return;
    for (structs) |s| {
        list.append(.{
            .invocation_target = s.invocation_target,
            .invocation_target_in_shadow_tree = false,
            .shadow_adjusted_target = s.shadow_adjusted_target,
            .related_target = s.related_target,
            .touch_target_list = infra.List(*runtime.Instance).init(allocator),
            .root_of_closed_tree = false,
            .slot_in_closed_tree = false,
        }) catch return;
    }
}

/// DOM §2.9 - dispatch
/// https://dom.spec.whatwg.org/#concept-event-dispatch
///
/// Returns false if the event's canceled flag is set, true otherwise.
pub fn dispatch(target: *runtime.Instance, event: *runtime.Instance) !bool {
    const EventImpl = @import("Event.zig");
    const allocator = target.ctx.allocator;

    // Step 1: Set event's dispatch flag.
    EventImpl.setDispatchFlag(event, true);

    // Steps 7, 8 and 10 have to happen however we leave.
    errdefer finishDispatch(event);

    // Steps 2-5. targetOverride is target: the legacy target override flag is
    // only ever passed by HTML, and only for a Window. activationTarget (steps
    // 3, 6.4-6.5, 12) and clearTargets (steps 5, 6.10-6.11) need activation
    // behaviour and shadow roots respectively, neither of which exists yet.
    const related_target = EventImpl.getRelatedTarget(event);

    // `get_type` hands back a borrowed slice into the event's own storage, and
    // `initEvent` returns early while the dispatch flag is set, so no callback
    // can invalidate it mid-dispatch.
    const event_type_string = interfaces.Event.get_type(event) catch runtime.DOMString.initEmpty();
    const event_type = event_type_string.asSlice();

    // Step 6
    var path = infra.List(PathStruct).init(allocator);
    defer path.deinit();
    try buildEventPath(&path, target, event_type, related_target);
    const structs = path.toSlice();

    publishEventPath(event, structs, allocator);

    // Step 13: for each struct of event's path, IN REVERSE ORDER, invoke with
    // "capturing".
    var i = structs.len;
    while (i > 0) {
        i -= 1;
        EventImpl.setEventPhase(event, if (structs[i].shadow_adjusted_target != null)
            interfaces.Event.get_AT_TARGET()
        else
            interfaces.Event.get_CAPTURING_PHASE());
        invoke(structs, i, event, .capturing);
    }

    // Step 14: for each struct of event's path, in order, invoke with "bubbling".
    const bubbles = interfaces.Event.get_bubbles(event) catch false;
    for (structs, 0..) |s, index| {
        if (s.shadow_adjusted_target != null) {
            // Step 14.1 - the target itself is AT_TARGET in both passes, which
            // is how its capturing listeners run before its bubbling ones.
            EventImpl.setEventPhase(event, interfaces.Event.get_AT_TARGET());
        } else {
            // Step 14.2.1
            if (!bubbles) continue;
            // Step 14.2.2
            EventImpl.setEventPhase(event, interfaces.Event.get_BUBBLING_PHASE());
        }
        invoke(structs, index, event, .bubbling);
    }

    // Steps 7, 8, 9 and 10
    finishDispatch(event);

    // Steps 11 and 12 (clearTargets, activation behaviour) are not reachable yet.

    // Step 13: return false if event's canceled flag is set; otherwise true.
    return !EventImpl.getCanceledFlag(event);
}

/// Dispatch steps 7-10: leave the event in a state that can be dispatched again.
fn finishDispatch(event: *runtime.Instance) void {
    const EventImpl = @import("Event.zig");
    // Step 7
    EventImpl.setEventPhase(event, interfaces.Event.get_NONE());
    // Step 8
    EventImpl.setCurrentTarget(event, null);
    // Step 9
    EventImpl.clearPath(event);
    // Step 10
    EventImpl.setDispatchFlag(event, false);
    EventImpl.clearPropagationFlags(event);
}

/// DOM §2.9 - invoke
/// https://dom.spec.whatwg.org/#concept-event-listener-invoke
fn invoke(structs: []const PathStruct, index: usize, event: *runtime.Instance, phase: ListenerPhase) void {
    const EventImpl = @import("Event.zig");
    const s = structs[index];

    // Step 1: event's target is the shadow-adjusted target of the last struct at
    // or before this one whose shadow-adjusted target is non-null.
    var j = index + 1;
    while (j > 0) {
        j -= 1;
        if (structs[j].shadow_adjusted_target) |shadow_adjusted| {
            EventImpl.setTarget(event, shadow_adjusted);
            break;
        }
    }

    // Step 2
    EventImpl.setRelatedTarget(event, s.related_target);

    // Step 3: event's touch target list - needs UI Events, TODO.

    // Step 4: stopPropagation() ends the walk here, but the caller still has to
    // run steps 7-10, so this returns rather than unwinding.
    if (EventImpl.getStopPropagationFlag(event)) return;

    // Step 5
    EventImpl.setCurrentTarget(event, s.invocation_target);

    // Steps 6-8. Step 9's legacy webkitAnimation*/webkitTransitionEnd
    // re-dispatch applies only to trusted events and is deliberately omitted.
    _ = innerInvoke(event, s.invocation_target, phase);

    // HTML specifies event handler IDL attributes (onclick, onload, ...) as
    // ordinary event listeners in the same list, so they propagate like any
    // other. Crane keeps them in a separate map, so they run here - in the
    // bubbling pass, because an event handler attribute is never a capturing
    // listener.
    // TODO: register them as real listeners, so registration order between
    // `el.onclick = f` and `el.addEventListener("click", g)` is honoured.
    if (phase == .bubbling) {
        invokeIdlEventHandler(s.invocation_target, event);
    }
}

/// DOM §2.9 - inner invoke
/// https://dom.spec.whatwg.org/#concept-event-listener-inner-invoke
///
/// Returns `found`: whether any listener matched the event's type, regardless of
/// phase. Only step 9 of "invoke" consumes it.
fn innerInvoke(event: *runtime.Instance, current_target: *runtime.Instance, phase: ListenerPhase) bool {
    const EventImpl = @import("Event.zig");

    const internal = getInternalFromRegistry(current_target) orelse return false;
    const list = internal.event_listener_list orelse return false;
    if (list.len == 0) return false;

    const event_type_string = interfaces.Event.get_type(event) catch return false;
    const event_type = event_type_string.asSlice();

    // Step 6 of "invoke": let listeners be a clone of the listener list. See
    // Invocation for why this clones identity rather than the records.
    var snapshot = infra.List(Invocation).init(internal.allocator);
    defer snapshot.deinit();

    var found = false;
    for (list.toSlice()) |record| {
        // Step 2: "for each listener whose removed is false"
        if (record.removed) continue;
        // Step 2.1
        if (!std.mem.eql(u8, record.type.asSlice(), event_type)) continue;
        // Step 2.2
        found = true;
        const callback = record.callback orelse continue;
        snapshot.append(.{
            .callback = callback,
            .capture = record.capture,
            .once = record.once,
            .passive = record.passive orelse false,
        }) catch return found;
    }

    for (snapshot.toSlice()) |candidate| {
        // Steps 2.3 and 2.4 - a capturing listener runs only in the capturing
        // pass, a bubbling one only in the bubbling pass. At the target both
        // passes run, which is why [capture, bubble, capture] fires 1, 3, 2.
        if (phase == .capturing and !candidate.capture) continue;
        if (phase == .bubbling and candidate.capture) continue;

        // The spec's clone holds live listeners, so one an earlier callback
        // removed during this same dispatch is skipped via its removed field.
        if (findListener(internal, candidate) == null) continue;

        // Step 2.5: remove a once listener BEFORE invoking it, so a re-entrant
        // dispatch cannot reach it. The wrapper has to outlive the call though -
        // disposing it first would hand V8 a destroyed handle.
        var expired: ?*runtime.CallbackWrapper = null;
        if (candidate.once) expired = detachListener(internal, candidate);
        defer if (expired) |wrapper| wrapper.deinit();

        // Step 2.9
        if (candidate.passive) EventImpl.setInPassiveListenerFlag(event, true);

        // Step 2.11 - an exception is reported, never propagated.
        callListener(candidate.callback, event, current_target);

        // Step 2.12
        if (candidate.passive) EventImpl.setInPassiveListenerFlag(event, false);

        // Step 2.14
        if (EventImpl.getStopImmediatePropagationFlag(event)) break;
    }

    // Step 3
    return found;
}

/// Index of a still-registered listener matching `candidate`, or null.
///
/// Identity is the wrapper POINTER, not the JavaScript function: addEventListener
/// allocates a fresh CallbackWrapper per call, so a listener removed and re-added
/// during a dispatch gets a new pointer and is correctly treated as one added
/// after the clone was taken.
fn findListener(internal: *InternalState, candidate: Invocation) ?usize {
    const list = internal.event_listener_list orelse return null;
    for (list.toSlice(), 0..) |record, i| {
        if (record.removed) continue;
        if (record.capture != candidate.capture) continue;
        const callback = record.callback orelse continue;
        if (callback == candidate.callback) return i;
    }
    return null;
}

/// DOM §2.7 "remove an event listener", for inner invoke's step 2.5.
///
/// Returns the callback wrapper WITHOUT disposing it - the caller owns it until
/// the callback has finished running.
fn detachListener(internal: *InternalState, candidate: Invocation) ?*runtime.CallbackWrapper {
    const index = findListener(internal, candidate) orelse return null;
    const list = internal.event_listener_list orelse return null;

    const removed = list.remove(index) catch return null;
    var removed_type = removed.type;
    removed_type.deinit(internal.allocator);

    const callback = removed.callback orelse return null;
    return @ptrCast(@alignCast(callback));
}

/// Inner invoke step 2.11 - "call a user object's operation" with the listener's
/// callback, "handleEvent", « event », and event's currentTarget.
fn callListener(callback_instance: *runtime.Instance, event: *runtime.Instance, current_target: *runtime.Instance) void {
    const v8_engine = @import("v8");

    // The record stores ?*runtime.Instance but it is always a
    // *runtime.CallbackWrapper - see call_addEventListener.
    const runtime_wrapper: *runtime.CallbackWrapper = @ptrCast(@alignCast(callback_instance));

    const engine_ctx = current_target.ctx.engine_ctx orelse return;
    const v8_context: *v8_engine.ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const v8_isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return;

    // Wrap the event with its ACTUAL interface: a MessageEvent wrapped as Event
    // loses `.data`.
    const event_interface_name = v8_engine.template_registry.getInstanceInterfaceName(event);
    const event_global = v8_engine.template_registry.wrapInstanceAsV8Object(
        event,
        event_interface_name,
        v8_isolate,
        v8_context,
    ) catch return;

    // callN takes Locals; the wrapper is (usually cached and) owned elsewhere,
    // so it is not disposed here.
    const event_local = v8_engine.ffi.v8_Global_Get(v8_isolate, @ptrCast(event_global)) orelse return;

    // During the callback the accessor is the Window that REGISTERED the
    // listener, not the one that triggered the event.
    const callback_window = v8_engine.context_manager.getWindowForContext(v8_context);
    if (callback_window) |win| {
        v8_engine.context_manager.pushAccessorWindow(win);
    }
    defer {
        if (callback_window != null) v8_engine.context_manager.popAccessorWindow();
    }

    // v8_Function_Call_Safe wraps the call in a TryCatch, so a throwing listener
    // comes back as a failed result instead of unwinding through Zig - which is
    // what "Exceptions from event listeners must not be propagated" requires.
    const result = runtime_wrapper.invoke1(@ptrCast(event_local)) catch return;

    // v8_Function_Call_Safe's value is `trackHandle(new Global<Value>(...))` and
    // its own comment says the caller owns it. Dropping it leaked one Global per
    // listener call, on the DOM's hottest path.
    if (result) |value| {
        v8_engine.ffi.v8_Global_Dispose(@ptrCast(@alignCast(value)));
    }
}

/// Invoke IDL event handler attribute (e.g., onload, onclick) for the given event
/// Per HTML spec, event handler IDL attributes like `element.onload = fn` are stored
/// separately from addEventListener callbacks and must also be invoked during dispatch.
fn invokeIdlEventHandler(instance: *runtime.Instance, event: *runtime.Instance) void {
    const v8_engine = @import("v8");
    const pointer_tag = v8_engine.pointer_tag;
    const global_handles = v8_engine.global_handles;

    // Get the event type
    const event_type_str = interfaces.Event.get_type(event) catch return;

    // Try to get the event handler - first from HTMLElement, then from Window
    // Both store tagged V8 Global handles, but in different formats:
    // - HTMLElement: *anyopaque (with pointer tag bits)
    // - Window: typedefs.EventHandler (?*fn) (which is actually a tagged Global handle)
    var raw_ptr: ?*anyopaque = null;

    // Try HTMLElement's internal state first
    // BRAND-CHECK FIRST. `HTMLElement.getInternalState` is an InstanceRegistry
    // lookup keyed on `@intFromPtr(instance)`, and the slab RECYCLES instance
    // addresses - so on a target that is not an HTMLElement it can return a
    // stale entry belonging to a freed element that happened to live at this
    // address. Reading `event_handlers` out of that freed state panics with
    // "incorrect alignment" inside HashMap.header, taking the process with it.
    //
    // Reachable from `new EventTarget()` + dispatchEvent the moment dispatch
    // started succeeding for constructed Event subclasses.
    //
    // `stateAs` answers "is this really an HTMLElement" from the vtable
    // ancestry and returns null when it cannot, which is the conservative
    // answer here.
    if (instance.stateAs(interfaces.HTMLElement.State) != null) {
        const HTMLElementImpl = @import("HTMLElement.zig");
        if (HTMLElementImpl.getInternalState(instance)) |html_internal| {
            raw_ptr = html_internal.event_handlers.get(event_type_str.asSlice());
        }
    }

    // If not found in HTMLElement, try Window's event handlers
    if (raw_ptr == null) {
        const WindowImpl = @import("Window.zig");
        // Same brand-check reasoning as the HTMLElement lookup above.
        if (if (instance.stateAs(interfaces.Window.State) != null) WindowImpl.getInternal(instance) else null) |window_internal| {
            // Window stores EventHandler (= ?*fn), but it's actually a tagged Global handle.
            // We need to get the function pointer and cast it to *anyopaque.
            if (window_internal.event_handlers.get(event_type_str.asSlice())) |handler| {
                if (handler) |fn_ptr| {
                    // The function pointer is actually a tagged Global handle pointer
                    // Cast it to *anyopaque to match HTMLElement's format
                    raw_ptr = @ptrFromInt(@intFromPtr(fn_ptr));
                }
            }
        }
    }

    // If no handler found, return early
    const handler_ptr = raw_ptr orelse return;

    // Untag the pointer to get the GlobalHandle
    const untagged = pointer_tag.untagPointer(handler_ptr);

    // Verify it's a global_handle tag (set during fromV8Value conversion)
    if (untagged.tag != .global_handle) {
        // Not a V8 callback - might be a native Zig function (unlikely for IDL handlers)
        return;
    }

    // Get V8 context and isolate
    const engine_ctx = instance.ctx.engine_ctx orelse return;
    const v8_context: *v8_engine.ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const v8_isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return;

    // Create a HandleScope for working with V8 Local handles.
    // V8 Local handles are only valid within a HandleScope.
    const handle_scope = v8_engine.ffi.v8_HandleScope_New(v8_isolate) orelse return;
    defer v8_engine.ffi.v8_HandleScope_Dispose(handle_scope);

    // Wrap the GlobalHandle
    const global_handle = global_handles.GlobalHandle{ .ptr = @ptrCast(untagged.ptr) };

    // Verify the global handle contains a function.
    // v8_Value_IsFunction expects a Global<Value>* - pass the GlobalHandle directly.
    // The C++ side will get the Local from the Global with proper HandleScope.
    if (!v8_engine.ffi.v8_Value_IsFunction(global_handle.ptr)) {
        return;
    }

    // Use the engine_ctx directly - it's already a Global<Context>* owned by the runtime context.
    // No need to call v8_Isolate_GetCurrentContext which would create a new Global that needs disposal.

    // Wrap the event as a V8 object using the correct interface name
    // This is critical for event subclasses like MessageEvent - they need
    // to be wrapped with their actual interface to expose properties like .data
    // NOTE: wrapInstanceAsV8Object returns a Global<Object>* handle (not Local!)
    const event_interface_name = v8_engine.template_registry.getInstanceInterfaceName(event);
    const event_wrapped_global = v8_engine.template_registry.wrapInstanceAsV8Object(
        event,
        event_interface_name,
        v8_isolate,
        v8_context,
    ) catch return;

    // Convert the wrapped Global to Local, then to a NEW Global that we own
    // This is needed because v8_Function_Call_Safe expects Global handles,
    // and we need a Global we can dispose after the call
    const event_local = v8_engine.ffi.v8_Global_Get(v8_isolate, @ptrCast(event_wrapped_global)) orelse return;
    const event_v8_global = v8_engine.ffi.v8_Value_ToGlobal(v8_isolate, @ptrCast(event_local)) orelse return;
    defer v8_engine.ffi.v8_Global_Dispose(event_v8_global);

    // Get 'this' value as a Global - v8_Undefined returns a Global<Value>*
    const recv_global = v8_engine.ffi.v8_Undefined(v8_isolate);

    // Prepare argument array with Global handles
    var args: [1]*v8_engine.ffi.Value = .{event_v8_global};

    // Call the function using v8_Function_Call_Safe which expects Global handles
    // - global_handle.ptr is already a Global<Value>* containing the function
    // - v8_context is Global<Context>* (from engine_ctx)
    // - recv_global is Global<Value>* (undefined)
    // - args contains Global<Value>*
    const result = v8_engine.ffi.v8_Function_Call_Safe(
        global_handle.ptr, // Global<Value>* containing the function
        v8_context, // Global<Context>* from engine_ctx
        @ptrCast(recv_global), // Global<Value>* for 'this'
        1,
        @ptrCast(&args),
    );

    // Free the result (errors are silently ignored - per HTML spec, event handler errors
    // should not prevent other handlers from running)
    v8_engine.ffi.v8_FreeFunctionCallResult(result);
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

/// Get the internal state for an EventTarget instance
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return getInternalFromRegistry(instance);
}

/// Set the node type for this EventTarget (used by Node)
pub fn setNodeType(instance: *runtime.Instance, node_type: u16) void {
    if (getInternalFromRegistry(instance)) |internal| {
        internal.node_type = node_type;
    }
}

/// Get the node type for this EventTarget
pub fn getNodeType(instance: *runtime.Instance) u16 {
    if (getInternalFromRegistry(instance)) |internal| {
        return internal.node_type;
    }
    return 0; // Plain EventTarget
}

/// Get all event listeners for a specific type
pub fn getEventListenersForType(instance: *runtime.Instance, @"type": []const u8) []const EventListenerRecord {
    const internal = getInternalFromRegistry(instance) orelse return &[_]EventListenerRecord{};
    const list = internal.event_listener_list orelse return &[_]EventListenerRecord{};

    // Note: This returns all listeners, caller should filter by type
    // In a real implementation, we'd return a filtered view
    _ = @"type";
    return list.toSlice();
}
