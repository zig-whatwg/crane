//! Generated from: url.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const URLImpl = @import("../impls/URL.zig");

pub const URL = struct {
    pub const Meta = struct {
        pub const name = "URL";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker", "SharedWorker" } } },
            .{ .name = "LegacyWindowAlias", .value = .{ .identifier = "webkitURL" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
            .SharedWorker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            href: runtime.USVString = undefined,
            origin: runtime.USVString = undefined,
            protocol: runtime.USVString = undefined,
            username: runtime.USVString = undefined,
            password: runtime.USVString = undefined,
            host: runtime.USVString = undefined,
            hostname: runtime.USVString = undefined,
            port: runtime.USVString = undefined,
            pathname: runtime.USVString = undefined,
            search: runtime.USVString = undefined,
            searchParams: URLSearchParams = undefined,
            hash: runtime.USVString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(URL, .{
        .deinit_fn = &deinit_wrapper,

        .get_hash = &get_hash,
        .get_host = &get_host,
        .get_hostname = &get_hostname,
        .get_href = &get_href,
        .get_origin = &get_origin,
        .get_password = &get_password,
        .get_pathname = &get_pathname,
        .get_port = &get_port,
        .get_protocol = &get_protocol,
        .get_search = &get_search,
        .get_searchParams = &get_searchParams,
        .get_username = &get_username,

        .set_hash = &set_hash,
        .set_host = &set_host,
        .set_hostname = &set_hostname,
        .set_href = &set_href,
        .set_password = &set_password,
        .set_pathname = &set_pathname,
        .set_port = &set_port,
        .set_protocol = &set_protocol,
        .set_search = &set_search,
        .set_username = &set_username,

        .call_canParse = &call_canParse,
        .call_createObjectURL = &call_createObjectURL,
        .call_parse = &call_parse,
        .call_revokeObjectURL = &call_revokeObjectURL,
        .call_toJSON = &call_toJSON,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        URLImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        URLImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, url: runtime.USVString, base: runtime.USVString) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try URLImpl.constructor(state, url, base);
        
        return instance;
    }

    pub fn get_href(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return URLImpl.get_href(state);
    }

    pub fn set_href(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        URLImpl.set_href(state, value);
    }

    pub fn get_origin(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return URLImpl.get_origin(state);
    }

    pub fn get_protocol(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return URLImpl.get_protocol(state);
    }

    pub fn set_protocol(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        URLImpl.set_protocol(state, value);
    }

    pub fn get_username(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return URLImpl.get_username(state);
    }

    pub fn set_username(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        URLImpl.set_username(state, value);
    }

    pub fn get_password(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return URLImpl.get_password(state);
    }

    pub fn set_password(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        URLImpl.set_password(state, value);
    }

    pub fn get_host(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return URLImpl.get_host(state);
    }

    pub fn set_host(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        URLImpl.set_host(state, value);
    }

    pub fn get_hostname(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return URLImpl.get_hostname(state);
    }

    pub fn set_hostname(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        URLImpl.set_hostname(state, value);
    }

    pub fn get_port(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return URLImpl.get_port(state);
    }

    pub fn set_port(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        URLImpl.set_port(state, value);
    }

    pub fn get_pathname(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return URLImpl.get_pathname(state);
    }

    pub fn set_pathname(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        URLImpl.set_pathname(state, value);
    }

    pub fn get_search(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return URLImpl.get_search(state);
    }

    pub fn set_search(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        URLImpl.set_search(state, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_searchParams(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_searchParams) |cached| {
            return cached;
        }
        const value = URLImpl.get_searchParams(state);
        state.cached_searchParams = value;
        return value;
    }

    pub fn get_hash(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return URLImpl.get_hash(state);
    }

    pub fn set_hash(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        URLImpl.set_hash(state, value);
    }

    pub fn call_createObjectURL(instance: *runtime.Instance, obj: anyopaque) runtime.DOMString {
        const state = instance.getState(State);
        
        return URLImpl.call_createObjectURL(state, obj);
    }

    pub fn call_toJSON(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return URLImpl.call_toJSON(state);
    }

    pub fn call_canParse(instance: *runtime.Instance, url: runtime.USVString, base: runtime.USVString) bool {
        const state = instance.getState(State);
        
        return URLImpl.call_canParse(state, url, base);
    }

    pub fn call_parse(instance: *runtime.Instance, url: runtime.USVString, base: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return URLImpl.call_parse(state, url, base);
    }

    pub fn call_revokeObjectURL(instance: *runtime.Instance, url: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return URLImpl.call_revokeObjectURL(state, url);
    }

};
