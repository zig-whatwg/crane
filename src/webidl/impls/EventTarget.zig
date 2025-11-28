//! ============================================================================
//! DO NOT COMPILE THIS FILE - REFERENCE STUB ONLY
//! ============================================================================
//!
//! Implementation stub for EventTarget interface
//!
//! This file is AUTO-GENERATED into impls_tmp/ directory.
//! The impls_tmp/ directory is gitignored and NOT part of the build.
//!
//! TO USE THIS STUB:
//!   1. Copy this file to src/webidl/impls/
//!   2. Remove this header comment block
//!   3. Add your implementation logic
//!   4. The impls/ directory is the canonical location for implementations
//!
//! If updating an existing implementation:
//!   1. Diff this stub against the existing file in impls/
//!   2. Manually merge new signatures while preserving custom code
//!
//! ============================================================================

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const mixins = @import("mixins");
const EventTarget = interfaces.EventTarget;
const infra = @import("infra");

pub const State = EventTarget.State;

pub const ImplError = error{
    NotImplemented,
};

/// Event listener record per DOM spec
const EventListenerRecord = struct {
    event_type: runtime.DOMString,
    callback: ?*runtime.Instance,
    capture: bool,
    passive: ?bool,
    once: bool,
    signal: ?*runtime.Instance,
};

/// Internal state for EventTarget implementation
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    event_listener_list: ?*infra.List(EventListenerRecord) = null,
    node_type: u16 = 0,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .allocator = allocator,
            .event_listener_list = null,
            .node_type = 0,
        };
    }

    pub fn deinit(self: *InternalState) void {
        if (self.event_listener_list) |list| {
            const slice = list.toSliceMut();
            for (slice) |*listener| {
                var event_type = listener.event_type;
                event_type.deinit(self.allocator);
            }
            list.deinit();
            self.allocator.destroy(list);
        }
    }

    pub fn ensureEventListenerList(self: *InternalState) !*infra.List(EventListenerRecord) {
        if (self.event_listener_list) |list| {
            return list;
        }
        const list = try self.allocator.create(infra.List(EventListenerRecord));
        list.* = infra.List(EventListenerRecord).init(self.allocator);
        self.event_listener_list = list;
        return list;
    }
};

var internal_state_registry: std.AutoHashMap(usize, *InternalState) = undefined;
var registry_initialized: bool = false;

fn ensureRegistry() void {
    if (!registry_initialized) {
        internal_state_registry = std.AutoHashMap(usize, *InternalState).init(std.heap.page_allocator);
        registry_initialized = true;
    }
}

fn getInternalFromRegistry(instance: *runtime.Instance) ?*InternalState {
    ensureRegistry();
    return internal_state_registry.get(@intFromPtr(instance));
}

fn setInternalInRegistry(instance: *runtime.Instance, internal: *InternalState) !void {
    ensureRegistry();
    try internal_state_registry.put(@intFromPtr(instance), internal);
}

fn removeFromRegistry(instance: *runtime.Instance) void {
    ensureRegistry();
    _ = internal_state_registry.remove(@intFromPtr(instance));
}

pub fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    return getInternalFromRegistry(instance);
}

pub fn setNodeType(instance: *runtime.Instance, node_type: u16) void {
    if (getInternalFromRegistry(instance)) |internal| {
        internal.node_type = node_type;
    }
}

pub fn getNodeType(instance: *runtime.Instance) u16 {
    if (getInternalFromRegistry(instance)) |internal| {
        return internal.node_type;
    }
    return 0;
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

    const ArenaAllocator = @import("runtime").ArenaAllocator;
    const internal = try ArenaAllocator.get().create(InternalState);
    internal.* = InternalState.init(allocator);
    try setInternalInRegistry(instance, internal);

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    if (getInternalFromRegistry(instance)) |internal| {
        internal.deinit();
        removeFromRegistry(instance);
    }
    runtime.Instance.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &EventTarget.vtable, ctx);
    errdefer deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// Operation: dispatchEvent
pub fn call_dispatchEvent(instance: *runtime.Instance, event: *runtime.Instance) ImplError!bool {
    _ = instance;
    _ = event;
    return error.NotImplemented;
}

/// Operation: when
pub fn call_when(instance: *runtime.Instance, @"type": runtime.DOMString, options: dictionaries.ObservableEventListenerOptions) ImplError!*runtime.Instance {
    _ = instance;
    _ = @"type";
    _ = options;
    return error.NotImplemented;
}

/// Operation: addEventListener
pub fn call_addEventListener(instance: *runtime.Instance, @"type": runtime.DOMString, callback: ??*runtime.CallbackWrapper, options: *const anyopaque) ImplError!void {
    _ = instance;
    _ = @"type";
    _ = callback;
    _ = options;
    return error.NotImplemented;
}

/// Operation: removeEventListener
pub fn call_removeEventListener(instance: *runtime.Instance, @"type": runtime.DOMString, callback: ??*runtime.CallbackWrapper, options: *const anyopaque) ImplError!void {
    _ = instance;
    _ = @"type";
    _ = callback;
    _ = options;
    return error.NotImplemented;
}
