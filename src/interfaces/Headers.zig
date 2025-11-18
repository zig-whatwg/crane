//! Generated from: fetch.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HeadersImpl = @import("../impls/Headers.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        HeadersImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        HeadersImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, init: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try HeadersImpl.constructor(state, init);
        
        return instance;
    }

    pub fn call_delete(instance: *runtime.Instance, name: runtime.ByteString) anyopaque {
        const state = instance.getState(State);
        
        return HeadersImpl.call_delete(state, name);
    }

    pub fn call_append(instance: *runtime.Instance, name: runtime.ByteString, value: runtime.ByteString) anyopaque {
        const state = instance.getState(State);
        
        return HeadersImpl.call_append(state, name, value);
    }

    pub fn call_get(instance: *runtime.Instance, name: runtime.ByteString) anyopaque {
        const state = instance.getState(State);
        
        return HeadersImpl.call_get(state, name);
    }

    pub fn call_has(instance: *runtime.Instance, name: runtime.ByteString) bool {
        const state = instance.getState(State);
        
        return HeadersImpl.call_has(state, name);
    }

    pub fn call_getSetCookie(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HeadersImpl.call_getSetCookie(state);
    }

    pub fn call_set(instance: *runtime.Instance, name: runtime.ByteString, value: runtime.ByteString) anyopaque {
        const state = instance.getState(State);
        
        return HeadersImpl.call_set(state, name, value);
    }

};
