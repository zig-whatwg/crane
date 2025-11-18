//! Generated from: urlpattern.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const URLPatternImpl = @import("../impls/URLPattern.zig");

pub const URLPattern = struct {
    pub const Meta = struct {
        pub const name = "URLPattern";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            protocol: runtime.USVString = undefined,
            username: runtime.USVString = undefined,
            password: runtime.USVString = undefined,
            hostname: runtime.USVString = undefined,
            port: runtime.USVString = undefined,
            pathname: runtime.USVString = undefined,
            search: runtime.USVString = undefined,
            hash: runtime.USVString = undefined,
            hasRegExpGroups: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(URLPattern, .{
        .deinit_fn = &deinit_wrapper,

        .get_hasRegExpGroups = &get_hasRegExpGroups,
        .get_hash = &get_hash,
        .get_hostname = &get_hostname,
        .get_password = &get_password,
        .get_pathname = &get_pathname,
        .get_port = &get_port,
        .get_protocol = &get_protocol,
        .get_search = &get_search,
        .get_username = &get_username,

        .call_exec = &call_exec,
        .call_test = &call_test,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        URLPatternImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        URLPatternImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, input: anyopaque, baseURL: runtime.USVString, options: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try URLPatternImpl.constructor(state, input, baseURL, options);
        
        return instance;
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, input: anyopaque, options: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try URLPatternImpl.constructor(state, input, options);
        
        return instance;
    }

    pub fn get_protocol(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return URLPatternImpl.get_protocol(state);
    }

    pub fn get_username(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return URLPatternImpl.get_username(state);
    }

    pub fn get_password(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return URLPatternImpl.get_password(state);
    }

    pub fn get_hostname(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return URLPatternImpl.get_hostname(state);
    }

    pub fn get_port(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return URLPatternImpl.get_port(state);
    }

    pub fn get_pathname(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return URLPatternImpl.get_pathname(state);
    }

    pub fn get_search(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return URLPatternImpl.get_search(state);
    }

    pub fn get_hash(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return URLPatternImpl.get_hash(state);
    }

    pub fn get_hasRegExpGroups(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return URLPatternImpl.get_hasRegExpGroups(state);
    }

    pub fn call_test(instance: *runtime.Instance, input: anyopaque, baseURL: runtime.USVString) bool {
        const state = instance.getState(State);
        
        return URLPatternImpl.call_test(state, input, baseURL);
    }

    pub fn call_exec(instance: *runtime.Instance, input: anyopaque, baseURL: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return URLPatternImpl.call_exec(state, input, baseURL);
    }

};
