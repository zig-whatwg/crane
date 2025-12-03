//! Implementation for WorkerLocation interface
//!
//! Spec: HTML Standard § 10.1.2 The WorkerLocation interface
//! https://html.spec.whatwg.org/#workerlocation
//!
//! The WorkerLocation interface provides URL information about the worker's
//! script location, similar to the Location object for windows but read-only.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const WorkerLocation = interfaces.WorkerLocation;

// Import workers infrastructure
const html_core = @import("html_core");
const workers = html_core.workers;
const InternalWorkerLocation = workers.WorkerLocation;

pub const State = WorkerLocation.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for WorkerLocation implementation
///
/// Contains a reference to the backing WorkerLocation from src/html/workers/.
pub const InternalState = struct {
    /// Backing implementation from workers module
    internal_location: *InternalWorkerLocation,

    /// Allocator used for this state
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState) void {
        self.internal_location.deinit();
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

/// Initialize with a URL
pub fn initWithUrl(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
    url: []const u8,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Create internal WorkerLocation
    const internal_location = try InternalWorkerLocation.init(allocator, url);
    errdefer internal_location.deinit();

    // Create internal state
    const internal_state = try allocator.create(InternalState);
    internal_state.* = .{
        .internal_location = internal_location,
        .allocator = allocator,
    };

    // Store internal state
    var state = instance.getState(State);
    state.own._internal = internal_state;

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

/// Getter for href
///
/// Spec: HTML Standard § 10.1.2
/// "The href attribute must return the WorkerLocation object's associated
/// WorkerGlobalScope object's url, serialized."
pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return internal.internal_location.getHref();
    }
    return error.NotImplemented;
}

/// Getter for origin
///
/// Spec: HTML Standard § 10.1.2
/// "The origin attribute must return the serialization of the WorkerLocation
/// object's url's origin."
pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return internal.internal_location.getOrigin();
    }
    return error.NotImplemented;
}

/// Getter for protocol
///
/// Spec: HTML Standard § 10.1.2
/// "The protocol attribute must return the WorkerLocation object's url's scheme,
/// followed by ':'."
pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return internal.internal_location.getProtocol();
    }
    return error.NotImplemented;
}

/// Getter for host
///
/// Spec: HTML Standard § 10.1.2
/// "The host attribute must return the WorkerLocation object's url's host,
/// serialized, followed by ':' and the url's port, serialized."
pub fn get_host(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return internal.internal_location.getHost();
    }
    return error.NotImplemented;
}

/// Getter for hostname
///
/// Spec: HTML Standard § 10.1.2
/// "The hostname attribute must return the WorkerLocation object's url's host,
/// serialized."
pub fn get_hostname(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return internal.internal_location.getHostname();
    }
    return error.NotImplemented;
}

/// Getter for port
///
/// Spec: HTML Standard § 10.1.2
/// "The port attribute must return the WorkerLocation object's url's port,
/// serialized."
pub fn get_port(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return internal.internal_location.getPort();
    }
    return error.NotImplemented;
}

/// Getter for pathname
///
/// Spec: HTML Standard § 10.1.2
/// "The pathname attribute must return the result of URL path serializing the
/// WorkerLocation object's url."
pub fn get_pathname(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return internal.internal_location.getPathname();
    }
    return error.NotImplemented;
}

/// Getter for search
///
/// Spec: HTML Standard § 10.1.2
/// "The search attribute must return '?' followed by the WorkerLocation object's
/// url's query, or the empty string if query is null."
pub fn get_search(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return internal.internal_location.getSearch();
    }
    return error.NotImplemented;
}

/// Getter for hash
///
/// Spec: HTML Standard § 10.1.2
/// "The hash attribute must return '#' followed by the WorkerLocation object's
/// url's fragment, or the empty string if fragment is null."
pub fn get_hash(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return internal.internal_location.getHash();
    }
    return error.NotImplemented;
}
