//! Generated from: service-workers.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CacheImpl = @import("../impls/Cache.zig");

pub const Cache = struct {
    pub const Meta = struct {
        pub const name = "Cache";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
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

    pub const vtable = runtime.buildVTable(Cache, .{
        .deinit_fn = &deinit_wrapper,

        .call_add = &call_add,
        .call_addAll = &call_addAll,
        .call_delete = &call_delete,
        .call_keys = &call_keys,
        .call_match = &call_match,
        .call_matchAll = &call_matchAll,
        .call_put = &call_put,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CacheImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CacheImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_delete(instance: *runtime.Instance, request: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return CacheImpl.call_delete(state, request, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_match(instance: *runtime.Instance, request: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return CacheImpl.call_match(state, request, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_keys(instance: *runtime.Instance, request: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return CacheImpl.call_keys(state, request, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_matchAll(instance: *runtime.Instance, request: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return CacheImpl.call_matchAll(state, request, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_add(instance: *runtime.Instance, request: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return CacheImpl.call_add(state, request);
    }

    /// Extended attributes: [NewObject]
    pub fn call_addAll(instance: *runtime.Instance, requests: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return CacheImpl.call_addAll(state, requests);
    }

    /// Extended attributes: [NewObject]
    pub fn call_put(instance: *runtime.Instance, request: anyopaque, response: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return CacheImpl.call_put(state, request, response);
    }

};
