//! Implementation for SharedWorker interface
//!
//! Spec: HTML Standard § 10.2.4 Shared workers and the SharedWorker interface
//! https://html.spec.whatwg.org/#shared-workers-and-the-sharedworker-interface
//!
//! This implementation bridges the WebIDL SharedWorker interface to the underlying
//! SharedWorker implementation in src/html/workers/.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const SharedWorker = interfaces.SharedWorker;

// Import workers infrastructure
const html_core = @import("html_core");
const workers = html_core.workers;
const InternalSharedWorker = workers.SharedWorker;
const SharedWorkerManager = workers.SharedWorkerManager;
const WorkerOptions = workers.WorkerOptions;
const WorkerType = workers.WorkerType;
const RequestCredentials = workers.RequestCredentials;

// Import MessagePort for communication
const MessagePortImpl = @import("MessagePort.zig");
const message_port_internal = @import("streams_internal");
const InternalMessagePort = message_port_internal.MessagePort;
const MessagePort = interfaces.MessagePort;

pub const State = SharedWorker.State;

pub const ImplError = error{
    NotImplemented,
    WorkerCreationFailed,
    InvalidURL,
    OutOfMemory,
    SecurityError,
};

/// Internal state for SharedWorker implementation
///
/// Contains a reference to the backing SharedWorker from src/html/workers/
/// and the MessagePort for communication.
///
/// Note: The actual SharedWorker requires a TimerBackend from the platform.
/// The WebIDL impl stores configuration until platform is available.
pub const InternalState = struct {
    /// Reference to the internal shared worker (created when platform is set)
    shared_worker: ?*InternalSharedWorker = null,

    /// The MessagePort for this connection (exposed via .port)
    message_port: ?*runtime.Instance = null,

    /// Worker configuration
    script_url: []const u8,
    name: []const u8,
    origin: []const u8,

    /// Whether we own the shared worker (first to create it)
    owns_worker: bool = false,

    /// Allocator used for this state
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState) void {
        // Only deinit the shared worker if we own it
        if (self.owns_worker) {
            if (self.shared_worker) |worker| {
                worker.deinit();
            }
        }
        self.allocator.free(self.script_url);
        if (self.name.len > 0) {
            self.allocator.free(self.name);
        }
        self.allocator.free(self.origin);
    }
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
///
/// Spec: HTML Standard § 10.2.4.1 The SharedWorker() constructor
/// https://html.spec.whatwg.org/#dom-sharedworker
///
/// This is called when the interface is constructed from JavaScript:
/// new SharedWorker(scriptURL, options)
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, scriptURL: runtime.DOMString, options: webidl.Opt(*const anyopaque)) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &SharedWorker.vtable, ctx);
    errdefer deinit(instance);

    // Parse options - for now, use defaults since options is opaque
    _ = options; // Options parsing would require dictionary access

    // Copy the script URL
    const url_copy = try allocator.dupe(u8, scriptURL.asSlice());
    errdefer allocator.free(url_copy);

    // Get the origin from context (simplified - use script URL origin)
    const origin = extractOrigin(scriptURL.asSlice());
    const origin_copy = try allocator.dupe(u8, origin);
    errdefer allocator.free(origin_copy);

    // Create MessagePort instance for the outside port
    const internal_port = try InternalMessagePort.init(allocator);
    errdefer internal_port.deinit();

    const port_instance = try MessagePortImpl.initWithInternal(
        allocator,
        MessagePort.State,
        &MessagePort.vtable,
        ctx,
        internal_port,
    );
    errdefer runtime.Instance.deinit(port_instance);

    // Create internal state
    // Note: The actual SharedWorker will be created when platform is available
    const internal_state = try allocator.create(InternalState);
    errdefer allocator.destroy(internal_state);

    internal_state.* = .{
        .shared_worker = null, // Created when platform is set
        .message_port = port_instance,
        .script_url = url_copy,
        .name = "", // Default empty name
        .origin = origin_copy,
        .owns_worker = true, // First creator owns it
        .allocator = allocator,
    };

    // Store internal state
    var state = instance.getState(State);
    state.own._internal = internal_state;

    // Note: Worker will be started when the platform provides a timer backend

    return instance;
}

/// Getter for port
///
/// Spec: HTML Standard § 10.2.4.1
/// "The port attribute must return the SharedWorker object's port."
/// The port is a MessagePort used to communicate with the shared worker.
pub fn get_port(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.message_port) |port| {
            return port;
        }
    }
    return error.NotImplemented;
}

/// Getter for onerror
///
/// Spec: HTML Standard § 10.2.4.1
/// Event handler for error events on the shared worker.
pub fn get_onerror(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    const state = instance.getState(State);
    return state.own.onerror;
}

/// Setter for onerror
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    var state = instance.getState(State);
    state.own.onerror = value;
}

/// Extract origin from a URL string (simplified)
fn extractOrigin(url: []const u8) []const u8 {
    // Find "://" and then the next "/" to get origin
    if (std.mem.indexOf(u8, url, "://")) |proto_end| {
        const after_proto = proto_end + 3;
        if (std.mem.indexOfPos(u8, url, after_proto, "/")) |path_start| {
            return url[0..path_start];
        }
        return url; // No path, entire URL is origin
    }
    return "null"; // Invalid URL
}
