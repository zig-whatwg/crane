//! Generated from: IndexedDB.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const IDBKeyRangeImpl = @import("impls").IDBKeyRange;

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
        
        // Initialize the instance (Impl receives full instance)
        IDBKeyRangeImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IDBKeyRangeImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_lower(instance: *runtime.Instance) anyerror!anyopaque {
        return try IDBKeyRangeImpl.get_lower(instance);
    }

    pub fn get_upper(instance: *runtime.Instance) anyerror!anyopaque {
        return try IDBKeyRangeImpl.get_upper(instance);
    }

    pub fn get_lowerOpen(instance: *runtime.Instance) anyerror!bool {
        return try IDBKeyRangeImpl.get_lowerOpen(instance);
    }

    pub fn get_upperOpen(instance: *runtime.Instance) anyerror!bool {
        return try IDBKeyRangeImpl.get_upperOpen(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_only(instance: *runtime.Instance, value: anyopaque) anyerror!IDBKeyRange {
        // [NewObject] - Caller owns the returned object
        
        return try IDBKeyRangeImpl.call_only(instance, value);
    }

    pub fn call_includes(instance: *runtime.Instance, key: anyopaque) anyerror!bool {
        
        return try IDBKeyRangeImpl.call_includes(instance, key);
    }

    /// Extended attributes: [NewObject]
    pub fn call_bound(instance: *runtime.Instance, lower: anyopaque, upper: anyopaque, lowerOpen: bool, upperOpen: bool) anyerror!IDBKeyRange {
        // [NewObject] - Caller owns the returned object
        
        return try IDBKeyRangeImpl.call_bound(instance, lower, upper, lowerOpen, upperOpen);
    }

    /// Extended attributes: [NewObject]
    pub fn call_upperBound(instance: *runtime.Instance, upper: anyopaque, open: bool) anyerror!IDBKeyRange {
        // [NewObject] - Caller owns the returned object
        
        return try IDBKeyRangeImpl.call_upperBound(instance, upper, open);
    }

    /// Extended attributes: [NewObject]
    pub fn call_lowerBound(instance: *runtime.Instance, lower: anyopaque, open: bool) anyerror!IDBKeyRange {
        // [NewObject] - Caller owns the returned object
        
        return try IDBKeyRangeImpl.call_lowerBound(instance, lower, open);
    }

};
