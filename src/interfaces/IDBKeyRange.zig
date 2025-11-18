//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IDBKeyRangeImpl = @import("../impls/IDBKeyRange.zig");

pub const IDBKeyRange = struct {
    pub const Meta = struct {
        pub const name = "IDBKeyRange";
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
            lower: anyopaque = undefined,
            upper: anyopaque = undefined,
            lowerOpen: bool = undefined,
            upperOpen: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(IDBKeyRange, .{
        .deinit_fn = &deinit_wrapper,

        .get_lower = &get_lower,
        .get_lowerOpen = &get_lowerOpen,
        .get_upper = &get_upper,
        .get_upperOpen = &get_upperOpen,

        .call_bound = &call_bound,
        .call_includes = &call_includes,
        .call_lowerBound = &call_lowerBound,
        .call_only = &call_only,
        .call_upperBound = &call_upperBound,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        IDBKeyRangeImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        IDBKeyRangeImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_lower(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBKeyRangeImpl.get_lower(state);
    }

    pub fn get_upper(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return IDBKeyRangeImpl.get_upper(state);
    }

    pub fn get_lowerOpen(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return IDBKeyRangeImpl.get_lowerOpen(state);
    }

    pub fn get_upperOpen(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return IDBKeyRangeImpl.get_upperOpen(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_only(instance: *runtime.Instance, value: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return IDBKeyRangeImpl.call_only(state, value);
    }

    pub fn call_includes(instance: *runtime.Instance, key: anyopaque) bool {
        const state = instance.getState(State);
        
        return IDBKeyRangeImpl.call_includes(state, key);
    }

    /// Extended attributes: [NewObject]
    pub fn call_bound(instance: *runtime.Instance, lower: anyopaque, upper: anyopaque, lowerOpen: bool, upperOpen: bool) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return IDBKeyRangeImpl.call_bound(state, lower, upper, lowerOpen, upperOpen);
    }

    /// Extended attributes: [NewObject]
    pub fn call_upperBound(instance: *runtime.Instance, upper: anyopaque, open: bool) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return IDBKeyRangeImpl.call_upperBound(state, upper, open);
    }

    /// Extended attributes: [NewObject]
    pub fn call_lowerBound(instance: *runtime.Instance, lower: anyopaque, open: bool) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return IDBKeyRangeImpl.call_lowerBound(state, lower, open);
    }

};
