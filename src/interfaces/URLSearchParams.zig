//! Generated from: url.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const URLSearchParamsImpl = @import("../impls/URLSearchParams.zig");

pub const URLSearchParams = struct {
    pub const Meta = struct {
        pub const name = "URLSearchParams";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
    };

    pub const State = runtime.FlattenedState(
        struct {
            size: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(URLSearchParams, .{
        .deinit_fn = &deinit_wrapper,

        .get_size = &get_size,

        .call_append = &call_append,
        .call_delete = &call_delete,
        .call_get = &call_get,
        .call_getAll = &call_getAll,
        .call_has = &call_has,
        .call_set = &call_set,
        .call_sort = &call_sort,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        URLSearchParamsImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        URLSearchParamsImpl.deinit(state);
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
        try URLSearchParamsImpl.constructor(state, init);
        
        return instance;
    }

    pub fn get_size(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return URLSearchParamsImpl.get_size(state);
    }

    pub fn call_delete(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return URLSearchParamsImpl.call_delete(state, name, value);
    }

    pub fn call_append(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return URLSearchParamsImpl.call_append(state, name, value);
    }

    pub fn call_getAll(instance: *runtime.Instance, name: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return URLSearchParamsImpl.call_getAll(state, name);
    }

    pub fn call_has(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) bool {
        const state = instance.getState(State);
        
        return URLSearchParamsImpl.call_has(state, name, value);
    }

    pub fn call_set(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return URLSearchParamsImpl.call_set(state, name, value);
    }

    pub fn call_get(instance: *runtime.Instance, name: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        
        return URLSearchParamsImpl.call_get(state, name);
    }

    pub fn call_sort(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return URLSearchParamsImpl.call_sort(state);
    }

};
