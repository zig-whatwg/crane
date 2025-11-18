//! Generated from: shared-storage.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SharedStorageImpl = @import("impls").SharedStorage;
const SharedStorageWorkletOptions = @import("dictionaries").SharedStorageWorkletOptions;
const Promise<DOMString> = @import("interfaces").Promise<DOMString>;
const Promise<SharedStorageWorklet> = @import("interfaces").Promise<SharedStorageWorklet>;
const Promise<unsignedlong> = @import("interfaces").Promise<unsignedlong>;
const Promise<double> = @import("interfaces").Promise<double>;
const Promise<any> = @import("interfaces").Promise<any>;
const SharedStorageSetMethodOptions = @import("dictionaries").SharedStorageSetMethodOptions;
const SharedStorageModifierMethodOptions = @import("dictionaries").SharedStorageModifierMethodOptions;
const SharedStorageWorklet = @import("interfaces").SharedStorageWorklet;
const SharedStorageRunOperationMethodOptions = @import("dictionaries").SharedStorageRunOperationMethodOptions;
const Promise<SharedStorageResponse> = @import("interfaces").Promise<SharedStorageResponse>;

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
        
        // Initialize the instance (Impl receives full instance)
        SharedStorageImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SharedStorageImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn get_worklet(instance: *runtime.Instance) anyerror!SharedStorageWorklet {
        return try SharedStorageImpl.get_worklet(instance);
    }

    pub fn call_delete(instance: *runtime.Instance, key: DOMString, options: SharedStorageModifierMethodOptions) anyerror!anyopaque {
        
        return try SharedStorageImpl.call_delete(instance, key, options);
    }

    pub fn call_append(instance: *runtime.Instance, key: DOMString, value: DOMString, options: SharedStorageModifierMethodOptions) anyerror!anyopaque {
        
        return try SharedStorageImpl.call_append(instance, key, value, options);
    }

    pub fn call_batchUpdate(instance: *runtime.Instance, methods: anyopaque, options: SharedStorageModifierMethodOptions) anyerror!anyopaque {
        
        return try SharedStorageImpl.call_batchUpdate(instance, methods, options);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_run(instance: *runtime.Instance, name: DOMString, options: SharedStorageRunOperationMethodOptions) anyerror!anyopaque {
        
        return try SharedStorageImpl.call_run(instance, name, options);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_createWorklet(instance: *runtime.Instance, moduleURL: runtime.USVString, options: SharedStorageWorkletOptions) anyerror!anyopaque {
        
        return try SharedStorageImpl.call_createWorklet(instance, moduleURL, options);
    }

    pub fn call_set(instance: *runtime.Instance, key: DOMString, value: DOMString, options: SharedStorageSetMethodOptions) anyerror!anyopaque {
        
        return try SharedStorageImpl.call_set(instance, key, value, options);
    }

    /// Extended attributes: [Exposed=SharedStorageWorklet]
    pub fn call_length(instance: *runtime.Instance) anyerror!anyopaque {
        return try SharedStorageImpl.call_length(instance);
    }

    /// Extended attributes: [Exposed=SharedStorageWorklet]
    pub fn call_remainingBudget(instance: *runtime.Instance) anyerror!anyopaque {
        return try SharedStorageImpl.call_remainingBudget(instance);
    }

    pub fn call_get(instance: *runtime.Instance, key: DOMString) anyerror!anyopaque {
        
        return try SharedStorageImpl.call_get(instance, key);
    }

    pub fn call_clear(instance: *runtime.Instance, options: SharedStorageModifierMethodOptions) anyerror!anyopaque {
        
        return try SharedStorageImpl.call_clear(instance, options);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_selectURL(instance: *runtime.Instance, name: DOMString, urls: anyopaque, options: SharedStorageRunOperationMethodOptions) anyerror!anyopaque {
        
        return try SharedStorageImpl.call_selectURL(instance, name, urls, options);
    }

};
