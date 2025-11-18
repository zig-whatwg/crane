//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const StorageImpl = @import("../impls/Storage.zig");

pub const Storage = struct {
    pub const Meta = struct {
        pub const name = "Storage";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            length: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Storage, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,

        .call_clear = &call_clear,
        .call_getItem = &call_getItem,
        .call_key = &call_key,
        .call_removeItem = &call_removeItem,
        .call_setItem = &call_setItem,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        StorageImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        StorageImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return StorageImpl.get_length(state);
    }

    pub fn call_removeItem(instance: *runtime.Instance, key: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return StorageImpl.call_removeItem(state, key);
    }

    pub fn call_clear(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StorageImpl.call_clear(state);
    }

    pub fn call_key(instance: *runtime.Instance, index: u32) anyopaque {
        const state = instance.getState(State);
        
        return StorageImpl.call_key(state, index);
    }

    pub fn call_getItem(instance: *runtime.Instance, key: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return StorageImpl.call_getItem(state, key);
    }

    pub fn call_setItem(instance: *runtime.Instance, key: runtime.DOMString, value: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return StorageImpl.call_setItem(state, key, value);
    }

};
