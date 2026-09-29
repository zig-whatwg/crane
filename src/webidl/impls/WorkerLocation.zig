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

// The URL Standard: the worker's URL as a URL record, and its getters'
// serializations (the same ones URL's getters use).
const URLRecord = @import("url_record").URLRecord;
const api_parser = @import("api_parser");
const url_serializer = @import("url_serializer");
const host_serializer = @import("host_serializer");
const path_serializer = @import("path_serializer");

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

    /// Whether this object owns `internal_location`. A WorkerGlobalScope lends its own:
    /// the global scope owns it and outlives every object in its realm.
    owned: bool = true,

    pub fn deinit(self: *InternalState) void {
        if (self.owned) self.internal_location.deinit();
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

// Every getter returns memory the binding frees with the instance's context
// allocator: a fresh serialization of the worker's URL record.
//
// Each reads the URL record, as HTML's WorkerLocation getters do - the
// worker's global scope's url, parsed by the URL Standard. The internal
// location split the string by hand and found a scheme only after "://", so
// a data: worker's protocol was "" and its pathname "/".

/// The worker's URL, as a URL record. OWNED (`deinit`).
fn recordOf(instance: *runtime.Instance) !URLRecord {
    const internal = instance.getState(State).own._internal orelse return error.NotImplemented;
    return api_parser.parseURL(instance.ctx.allocator, internal.internal_location.getHref(), null) catch error.NotImplemented;
}

/// HTML: "The href getter steps are to return this's WorkerGlobalScope
/// object's url, serialized."
pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
    var record = try recordOf(instance);
    defer record.deinit();
    return url_serializer.serialize(instance.ctx.allocator, &record, false);
}

/// Getter for origin
///
/// Spec: HTML Standard § 10.1.2
/// "The origin attribute must return the serialization of the WorkerLocation
/// object's url's origin."
pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return instance.ctx.allocator.dupe(u8, internal.internal_location.getOrigin());
    }
    return error.NotImplemented;
}

/// HTML: "return this's WorkerGlobalScope object's url's scheme, followed by
/// ":"."
pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.USVString {
    var record = try recordOf(instance);
    defer record.deinit();
    const scheme = record.scheme();
    const result = try instance.ctx.allocator.alloc(u8, scheme.len + 1);
    @memcpy(result[0..scheme.len], scheme);
    result[scheme.len] = ':';
    return result;
}

/// HTML: "1. Let url be this's WorkerGlobalScope object's url. 2. If url's
/// host is null, return the empty string. 3. If url's port is null, return
/// url's host, serialized. 4. Return url's host, serialized, followed by ":"
/// and url's port, serialized."
pub fn get_host(instance: *runtime.Instance) anyerror!runtime.USVString {
    const allocator = instance.ctx.allocator;
    var record = try recordOf(instance);
    defer record.deinit();
    const host = record.host orelse return allocator.dupe(u8, "");
    const port = record.port orelse return host_serializer.serializeHost(allocator, host);
    const serialized = try host_serializer.serializeHost(allocator, host);
    defer allocator.free(serialized);
    return std.fmt.allocPrint(allocator, "{s}:{d}", .{ serialized, port });
}

/// HTML: "1. Let host be this's WorkerGlobalScope object's url's host. 2. If
/// host is null, return the empty string. 3. Return host, serialized."
pub fn get_hostname(instance: *runtime.Instance) anyerror!runtime.USVString {
    const allocator = instance.ctx.allocator;
    var record = try recordOf(instance);
    defer record.deinit();
    const host = record.host orelse return allocator.dupe(u8, "");
    return host_serializer.serializeHost(allocator, host);
}

/// HTML: "1. Let port be this's WorkerGlobalScope object's url's port. 2. If
/// port is null, return the empty string. 3. Return port, serialized."
pub fn get_port(instance: *runtime.Instance) anyerror!runtime.USVString {
    const allocator = instance.ctx.allocator;
    var record = try recordOf(instance);
    defer record.deinit();
    const port = record.port orelse return allocator.dupe(u8, "");
    return std.fmt.allocPrint(allocator, "{d}", .{port});
}

/// HTML: "return the result of URL path serializing this's WorkerGlobalScope
/// object's url."
pub fn get_pathname(instance: *runtime.Instance) anyerror!runtime.USVString {
    var record = try recordOf(instance);
    defer record.deinit();
    return path_serializer.serializePath(instance.ctx.allocator, &record);
}

/// HTML: "1. Let query be this's WorkerGlobalScope object's url's query. 2. If
/// query is either null or the empty string, return the empty string.
/// 3. Return "?", followed by query."
pub fn get_search(instance: *runtime.Instance) anyerror!runtime.USVString {
    const allocator = instance.ctx.allocator;
    var record = try recordOf(instance);
    defer record.deinit();
    const query = record.query() orelse return allocator.dupe(u8, "");
    if (query.len == 0) return allocator.dupe(u8, "");
    return std.fmt.allocPrint(allocator, "?{s}", .{query});
}

/// HTML: "1. Let fragment be this's WorkerGlobalScope object's url's fragment.
/// 2. If fragment is either null or the empty string, return the empty
/// string. 3. Return "#", followed by fragment."
pub fn get_hash(instance: *runtime.Instance) anyerror!runtime.USVString {
    const allocator = instance.ctx.allocator;
    var record = try recordOf(instance);
    defer record.deinit();
    const fragment = record.fragment() orelse return allocator.dupe(u8, "");
    if (fragment.len == 0) return allocator.dupe(u8, "");
    return std.fmt.allocPrint(allocator, "#{s}", .{fragment});
}
