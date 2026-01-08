//! Implementation for ExtendableEvent interface
//!
//! Implements the ExtendableEvent interface per the Service Worker spec.
//! https://w3c.github.io/ServiceWorker/#extendableevent-interface
//!
//! ExtendableEvent supports the waitUntil() method which allows extending
//! the lifetime of the event until all promises passed to waitUntil() settle.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const ExtendableEvent = interfaces.ExtendableEvent;

pub const State = ExtendableEvent.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
};

/// Promise handle for waitUntil tracking.
pub const PromiseHandle = struct {
    /// Unique ID for this promise.
    id: u64,
    /// Whether this promise has settled.
    settled: bool = false,
    /// Whether the promise was rejected.
    rejected: bool = false,
};

/// Internal state for ExtendableEvent implementation
/// Manages waitUntil() promise tracking per the Service Worker spec.
pub const InternalState = struct {
    /// Event type (e.g., "install", "activate")
    event_type: []const u8,
    /// Whether extensions are allowed (true during dispatch)
    extensions_allowed: bool = true,
    /// Whether the event is being dispatched
    dispatch_flag: bool = false,
    /// List of promises added via waitUntil()
    extend_lifetime_promises: std.ArrayListUnmanaged(PromiseHandle) = .{},
    /// Count of pending (unsettled) promises
    pending_promises_count: u32 = 0,
    /// Counter for promise IDs
    next_promise_id: u64 = 0,
    /// Allocator used for this state
    allocator: std.mem.Allocator,
    /// The runtime context for promise operations
    ctx: runtime.Context,

    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context, event_type: []const u8) !*InternalState {
        const self = try allocator.create(InternalState);
        errdefer allocator.destroy(self);

        const type_copy = try allocator.dupe(u8, event_type);
        errdefer allocator.free(type_copy);

        self.* = .{
            .event_type = type_copy,
            .allocator = allocator,
            .ctx = ctx,
        };

        return self;
    }

    pub fn deinit(self: *InternalState) void {
        self.extend_lifetime_promises.deinit(self.allocator);
        self.allocator.free(self.event_type);
        self.allocator.destroy(self);
    }

    /// Add a promise to extend the event's lifetime.
    /// Returns a promise_id for tracking settlement.
    pub fn waitUntil(self: *InternalState) !u64 {
        // Step 1: Check if extensions are allowed
        if (!self.extensions_allowed) {
            return error.InvalidStateError;
        }

        // Step 2: Create promise handle
        const promise_id = self.next_promise_id;
        self.next_promise_id += 1;

        const handle = PromiseHandle{
            .id = promise_id,
            .settled = false,
        };

        try self.extend_lifetime_promises.append(self.allocator, handle);

        // Step 3: Increment pending count
        self.pending_promises_count += 1;

        return promise_id;
    }

    /// Resolve a waitUntil promise.
    pub fn resolvePromise(self: *InternalState, promise_id: u64) void {
        for (self.extend_lifetime_promises.items) |*promise| {
            if (promise.id == promise_id and !promise.settled) {
                promise.settled = true;
                promise.rejected = false;
                if (self.pending_promises_count > 0) {
                    self.pending_promises_count -= 1;
                }
                break;
            }
        }
    }

    /// Reject a waitUntil promise.
    pub fn rejectPromise(self: *InternalState, promise_id: u64) void {
        for (self.extend_lifetime_promises.items) |*promise| {
            if (promise.id == promise_id and !promise.settled) {
                promise.settled = true;
                promise.rejected = true;
                if (self.pending_promises_count > 0) {
                    self.pending_promises_count -= 1;
                }
                break;
            }
        }
    }

    /// Begin dispatch phase.
    pub fn startDispatch(self: *InternalState) void {
        self.dispatch_flag = true;
        self.extensions_allowed = true;
    }

    /// End dispatch phase. After this, waitUntil() will throw InvalidStateError.
    pub fn endDispatch(self: *InternalState) void {
        self.dispatch_flag = false;
        self.extensions_allowed = false;
    }

    /// Check if all promises have settled.
    pub fn isComplete(self: *const InternalState) bool {
        return self.pending_promises_count == 0;
    }

    /// Check if any promise was rejected.
    pub fn hasRejection(self: *const InternalState) bool {
        for (self.extend_lifetime_promises.items) |promise| {
            if (promise.rejected) {
                return true;
            }
        }
        return false;
    }

    /// Get the number of pending promises.
    pub fn getPendingCount(self: *const InternalState) u32 {
        return self.pending_promises_count;
    }
};

/// Registry to map runtime instances to internal state
var registry: std.AutoHashMapUnmanaged(*runtime.Instance, *InternalState) = .{};
var registry_allocator: ?std.mem.Allocator = null;

fn getRegistry(allocator: std.mem.Allocator) *std.AutoHashMapUnmanaged(*runtime.Instance, *InternalState) {
    if (registry_allocator == null) {
        registry_allocator = allocator;
    }
    return &registry;
}

/// Get internal state for an instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return registry.get(instance);
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Create internal state with default "extendableevent" type
    const internal = try InternalState.init(allocator, ctx, "extendableevent");
    errdefer internal.deinit();

    // Register the internal state
    const reg = getRegistry(allocator);
    try reg.put(allocator, instance, internal);

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up internal state
    if (registry.fetchRemove(instance)) |kv| {
        kv.value.deinit();
    }
    // Note: GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.ExtendableEventInit)) !*runtime.Instance {
    const allocator = ctx.allocator;

    // Create the runtime instance
    const instance = try runtime.Instance.init(allocator, State, &ExtendableEvent.vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Get the event type string from DOMString union
    const type_slice = @"type".asSlice();
    const event_type = if (type_slice.len > 0) type_slice else "extendableevent";

    // Create internal state
    const internal = try InternalState.init(allocator, ctx, event_type);
    errdefer internal.deinit();

    // Apply eventInitDict options if present
    // Note: bubbles and cancelable are handled by the Event base class
    _ = eventInitDict;

    // Register the internal state
    const reg = getRegistry(allocator);
    try reg.put(allocator, instance, internal);

    return instance;
}

/// Operation: waitUntil
/// https://w3c.github.io/ServiceWorker/#dom-extendableevent-waituntil
///
/// Extends the lifetime of the event until the passed promise settles.
/// If the promise rejects, the service worker is considered to have failed.
///
/// Per spec:
/// 1. If the isTrusted attribute is false, throw InvalidStateError
/// 2. If not active, throw InvalidStateError (extensions_allowed check)
/// 3. Add the promise to extend lifetime promises list
/// 4. Upon fulfillment/rejection, update state accordingly
pub fn call_waitUntil(instance: *runtime.Instance, f: runtime.JSValue) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1-2: Check if extensions are allowed (per spec)
    // This throws InvalidStateError if called after dispatch ends
    _ = internal.waitUntil() catch |err| {
        if (err == error.InvalidStateError) {
            return error.InvalidStateError;
        }
        return err;
    };

    // Step 3-4: Track the promise
    // Store the JS promise value for later settlement tracking
    // The ServiceWorkerManager will poll isComplete() to check when all promises settle
    //
    // Note: Full V8 promise chaining (attaching .then() handlers) requires
    // engine-level integration. For now, we track the promise was added.
    // The event dispatch layer can synchronously wait or poll for completion.
    //
    // TODO: Add proper V8 promise settlement callbacks when engine API is available
    _ = f; // Promise value - stored conceptually in extend_lifetime_promises
}

// ============================================================================
// Public API for ServiceWorkerManager integration
// ============================================================================

/// Create an ExtendableEvent for a specific event type (e.g., "install", "activate")
/// This is used by ServiceWorkerManager to create events for dispatch.
pub fn createForEventType(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    event_type: []const u8,
) !*runtime.Instance {
    // Create the runtime instance
    const instance = try runtime.Instance.init(allocator, State, &ExtendableEvent.vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Create internal state with the specified event type
    const internal = try InternalState.init(allocator, ctx, event_type);
    errdefer internal.deinit();

    // Register the internal state
    const reg = getRegistry(allocator);
    try reg.put(allocator, instance, internal);

    return instance;
}

/// Get the internal state for lifecycle management
/// Used by ServiceWorkerManager to check if all waitUntil promises have settled.
pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return getInternal(instance);
}

/// Start the dispatch phase for this event
/// Must be called before dispatching the event to handlers.
pub fn startDispatch(instance: *runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.startDispatch();
    }
}

/// End the dispatch phase for this event
/// After this, waitUntil() will throw InvalidStateError.
pub fn endDispatch(instance: *runtime.Instance) void {
    if (getInternal(instance)) |internal| {
        internal.endDispatch();
    }
}

/// Check if all waitUntil promises have settled
pub fn isComplete(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return true;
    return internal.isComplete();
}

/// Check if any waitUntil promise was rejected
pub fn hasRejection(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.hasRejection();
}

/// Get the number of pending (unsettled) waitUntil promises
pub fn getPendingCount(instance: *runtime.Instance) u32 {
    const internal = getInternal(instance) orelse return 0;
    return internal.getPendingCount();
}
