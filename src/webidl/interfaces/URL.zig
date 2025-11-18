//! Generated from: url.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const URLImpl = @import("impls").URL;
const (Blob or MediaSource) = @import("interfaces").(Blob or MediaSource);
const URLSearchParams = @import("interfaces").URLSearchParams;

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
        
        // Initialize the instance (Impl receives full instance)
        URLImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        URLImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, url: runtime.USVString, base: runtime.USVString) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try URLImpl.constructor(instance, url, base);
        
        return instance;
    }

    pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLImpl.get_href(instance);
    }

    pub fn set_href(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try URLImpl.set_href(instance, value);
    }

    pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLImpl.get_origin(instance);
    }

    pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLImpl.get_protocol(instance);
    }

    pub fn set_protocol(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try URLImpl.set_protocol(instance, value);
    }

    pub fn get_username(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLImpl.get_username(instance);
    }

    pub fn set_username(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try URLImpl.set_username(instance, value);
    }

    pub fn get_password(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLImpl.get_password(instance);
    }

    pub fn set_password(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try URLImpl.set_password(instance, value);
    }

    pub fn get_host(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLImpl.get_host(instance);
    }

    pub fn set_host(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try URLImpl.set_host(instance, value);
    }

    pub fn get_hostname(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLImpl.get_hostname(instance);
    }

    pub fn set_hostname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try URLImpl.set_hostname(instance, value);
    }

    pub fn get_port(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLImpl.get_port(instance);
    }

    pub fn set_port(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try URLImpl.set_port(instance, value);
    }

    pub fn get_pathname(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLImpl.get_pathname(instance);
    }

    pub fn set_pathname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try URLImpl.set_pathname(instance, value);
    }

    pub fn get_search(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLImpl.get_search(instance);
    }

    pub fn set_search(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try URLImpl.set_search(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_searchParams(instance: *runtime.Instance) anyerror!URLSearchParams {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_searchParams) |cached| {
            return cached;
        }
        const value = try URLImpl.get_searchParams(instance);
        state.cached_searchParams = value;
        return value;
    }

    pub fn get_hash(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLImpl.get_hash(instance);
    }

    pub fn set_hash(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try URLImpl.set_hash(instance, value);
    }

    pub fn call_createObjectURL(instance: *runtime.Instance, obj: anyopaque) anyerror!DOMString {
        
        return try URLImpl.call_createObjectURL(instance, obj);
    }

    pub fn call_toJSON(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLImpl.call_toJSON(instance);
    }

    pub fn call_canParse(instance: *runtime.Instance, url: runtime.USVString, base: runtime.USVString) anyerror!bool {
        
        return try URLImpl.call_canParse(instance, url, base);
    }

    pub fn call_parse(instance: *runtime.Instance, url: runtime.USVString, base: runtime.USVString) anyerror!anyopaque {
        
        return try URLImpl.call_parse(instance, url, base);
    }

    pub fn call_revokeObjectURL(instance: *runtime.Instance, url: DOMString) anyerror!void {
        
        return try URLImpl.call_revokeObjectURL(instance, url);
    }

};
