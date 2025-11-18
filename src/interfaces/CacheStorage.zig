//! Generated from: service-workers.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CacheStorageImpl = @import("../impls/CacheStorage.zig");

pub const CacheStorage = struct {
    pub const Meta = struct {
        pub const name = "CacheStorage";
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

    pub const vtable = runtime.buildVTable(CacheStorage, .{
        .deinit_fn = &deinit_wrapper,

        .call_delete = &call_delete,
        .call_has = &call_has,
        .call_keys = &call_keys,
        .call_match = &call_match,
        .call_open = &call_open,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CacheStorageImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CacheStorageImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_delete(instance: *runtime.Instance, cacheName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return CacheStorageImpl.call_delete(state, cacheName);
    }

    /// Extended attributes: [NewObject]
    pub fn call_keys(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return CacheStorageImpl.call_keys(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_has(instance: *runtime.Instance, cacheName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return CacheStorageImpl.call_has(state, cacheName);
    }

    /// Extended attributes: [NewObject]
    pub fn call_open(instance: *runtime.Instance, cacheName: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return CacheStorageImpl.call_open(state, cacheName);
    }

    /// Extended attributes: [NewObject]
    pub fn call_match(instance: *runtime.Instance, request: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return CacheStorageImpl.call_match(state, request, options);
    }

};
