//! Generated from: fetch.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HeadersImpl = @import("impls").Headers;
const ByteString = @import("interfaces").ByteString;
const HeadersInit = @import("typedefs").HeadersInit;

pub const Headers = struct {
    pub const Meta = struct {
        pub const name = "Headers";
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
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Headers, .{
        .deinit_fn = &deinit_wrapper,

        .call_append = &call_append,
        .call_delete = &call_delete,
        .call_get = &call_get,
        .call_getSetCookie = &call_getSetCookie,
        .call_has = &call_has,
        .call_set = &call_set,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        HeadersImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HeadersImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, init: HeadersInit) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try HeadersImpl.constructor(instance, init);
        
        return instance;
    }

    pub fn call_delete(instance: *runtime.Instance, name: runtime.ByteString) anyerror!void {
        
        return try HeadersImpl.call_delete(instance, name);
    }

    pub fn call_append(instance: *runtime.Instance, name: runtime.ByteString, value: runtime.ByteString) anyerror!void {
        
        return try HeadersImpl.call_append(instance, name, value);
    }

    pub fn call_get(instance: *runtime.Instance, name: runtime.ByteString) anyerror!anyopaque {
        
        return try HeadersImpl.call_get(instance, name);
    }

    pub fn call_has(instance: *runtime.Instance, name: runtime.ByteString) anyerror!bool {
        
        return try HeadersImpl.call_has(instance, name);
    }

    pub fn call_getSetCookie(instance: *runtime.Instance) anyerror!anyopaque {
        return try HeadersImpl.call_getSetCookie(instance);
    }

    pub fn call_set(instance: *runtime.Instance, name: runtime.ByteString, value: runtime.ByteString) anyerror!void {
        
        return try HeadersImpl.call_set(instance, name, value);
    }

};
