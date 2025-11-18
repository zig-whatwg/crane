//! Generated from: shared-storage.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SharedStorageWorkletGlobalScopeImpl = @import("impls").SharedStorageWorkletGlobalScope;
const WorkletGlobalScope = @import("interfaces").WorkletGlobalScope;
const Function = @import("callbacks").Function;
const Promise<sequence<StorageInterestGroup>> = @import("interfaces").Promise<sequence<StorageInterestGroup>>;
const SharedStorageWorkletNavigator = @import("interfaces").SharedStorageWorkletNavigator;
const SharedStorage = @import("interfaces").SharedStorage;
const PrivateAggregation = @import("interfaces").PrivateAggregation;

pub const SharedStorageWorkletGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "SharedStorageWorkletGlobalScope";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *WorkletGlobalScope;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "SharedStorageWorklet" } },
            .{ .name = "Global", .value = .{ .identifier = "SharedStorageWorklet" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .SharedStorageWorklet = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            sharedStorage: SharedStorage = undefined,
            privateAggregation: PrivateAggregation = undefined,
            navigator: SharedStorageWorkletNavigator = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SharedStorageWorkletGlobalScope, .{
        .deinit_fn = &deinit_wrapper,

        .get_navigator = &get_navigator,
        .get_privateAggregation = &get_privateAggregation,
        .get_sharedStorage = &get_sharedStorage,

        .call_interestGroups = &call_interestGroups,
        .call_register = &call_register,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        SharedStorageWorkletGlobalScopeImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SharedStorageWorkletGlobalScopeImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_sharedStorage(instance: *runtime.Instance) anyerror!SharedStorage {
        return try SharedStorageWorkletGlobalScopeImpl.get_sharedStorage(instance);
    }

    pub fn get_privateAggregation(instance: *runtime.Instance) anyerror!PrivateAggregation {
        return try SharedStorageWorkletGlobalScopeImpl.get_privateAggregation(instance);
    }

    pub fn get_navigator(instance: *runtime.Instance) anyerror!SharedStorageWorkletNavigator {
        return try SharedStorageWorkletGlobalScopeImpl.get_navigator(instance);
    }

    pub fn call_interestGroups(instance: *runtime.Instance) anyerror!anyopaque {
        return try SharedStorageWorkletGlobalScopeImpl.call_interestGroups(instance);
    }

    pub fn call_register(instance: *runtime.Instance, name: DOMString, operationCtor: Function) anyerror!void {
        
        return try SharedStorageWorkletGlobalScopeImpl.call_register(instance, name, operationCtor);
    }

};
