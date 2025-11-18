//! Generated from: urlpattern.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const URLPatternImpl = @import("impls").URLPattern;
const URLPatternOptions = @import("dictionaries").URLPatternOptions;
const URLPatternResult = @import("dictionaries").URLPatternResult;
const URLPatternInput = @import("typedefs").URLPatternInput;

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
        
        // Initialize the instance (Impl receives full instance)
        URLPatternImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        URLPatternImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, input: URLPatternInput, baseURL: runtime.USVString, options: URLPatternOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try URLPatternImpl.constructor(instance, input, baseURL, options);
        
        return instance;
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, input: URLPatternInput, options: URLPatternOptions) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try URLPatternImpl.constructor(instance, input, options);
        
        return instance;
    }

    pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLPatternImpl.get_protocol(instance);
    }

    pub fn get_username(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLPatternImpl.get_username(instance);
    }

    pub fn get_password(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLPatternImpl.get_password(instance);
    }

    pub fn get_hostname(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLPatternImpl.get_hostname(instance);
    }

    pub fn get_port(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLPatternImpl.get_port(instance);
    }

    pub fn get_pathname(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLPatternImpl.get_pathname(instance);
    }

    pub fn get_search(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLPatternImpl.get_search(instance);
    }

    pub fn get_hash(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try URLPatternImpl.get_hash(instance);
    }

    pub fn get_hasRegExpGroups(instance: *runtime.Instance) anyerror!bool {
        return try URLPatternImpl.get_hasRegExpGroups(instance);
    }

    pub fn call_test(instance: *runtime.Instance, input: URLPatternInput, baseURL: runtime.USVString) anyerror!bool {
        
        return try URLPatternImpl.call_test(instance, input, baseURL);
    }

    pub fn call_exec(instance: *runtime.Instance, input: URLPatternInput, baseURL: runtime.USVString) anyerror!anyopaque {
        
        return try URLPatternImpl.call_exec(instance, input, baseURL);
    }

};
