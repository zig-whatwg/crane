//! Generated from: shared-storage.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SharedStorageImpl = @import("../impls/SharedStorage.zig");

pub const SharedStorage = struct {
    pub const Meta = struct {
        pub const name = "SharedStorage";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "SharedStorageWorklet" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .SharedStorageWorklet = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            worklet: SharedStorageWorklet = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SharedStorage, .{
        .deinit_fn = &deinit_wrapper,

        .get_worklet = &get_worklet,

        .call_append = &call_append,
        .call_batchUpdate = &call_batchUpdate,
        .call_clear = &call_clear,
        .call_createWorklet = &call_createWorklet,
        .call_delete = &call_delete,
        .call_get = &call_get,
        .call_length = &call_length,
        .call_remainingBudget = &call_remainingBudget,
        .call_run = &call_run,
        .call_selectURL = &call_selectURL,
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
        SharedStorageImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SharedStorageImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_worklet(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SharedStorageImpl.get_worklet(state);
    }

    pub fn call_delete(instance: *runtime.Instance, key: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SharedStorageImpl.call_delete(state, key, options);
    }

    pub fn call_append(instance: *runtime.Instance, key: runtime.DOMString, value: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SharedStorageImpl.call_append(state, key, value, options);
    }

    pub fn call_batchUpdate(instance: *runtime.Instance, methods: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SharedStorageImpl.call_batchUpdate(state, methods, options);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_run(instance: *runtime.Instance, name: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SharedStorageImpl.call_run(state, name, options);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_createWorklet(instance: *runtime.Instance, moduleURL: runtime.USVString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SharedStorageImpl.call_createWorklet(state, moduleURL, options);
    }

    pub fn call_set(instance: *runtime.Instance, key: runtime.DOMString, value: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SharedStorageImpl.call_set(state, key, value, options);
    }

    /// Extended attributes: [Exposed=SharedStorageWorklet]
    pub fn call_length(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SharedStorageImpl.call_length(state);
    }

    /// Extended attributes: [Exposed=SharedStorageWorklet]
    pub fn call_remainingBudget(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SharedStorageImpl.call_remainingBudget(state);
    }

    pub fn call_get(instance: *runtime.Instance, key: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return SharedStorageImpl.call_get(state, key);
    }

    pub fn call_clear(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SharedStorageImpl.call_clear(state, options);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_selectURL(instance: *runtime.Instance, name: runtime.DOMString, urls: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SharedStorageImpl.call_selectURL(state, name, urls, options);
    }

};
