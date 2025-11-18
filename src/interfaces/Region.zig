//! Generated from: css-regions.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RegionImpl = @import("../impls/Region.zig");

pub const Region = struct {
    pub const Meta = struct {
        pub const name = "Region";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            regionOverset: CSSOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Region, .{
        .deinit_fn = &deinit_wrapper,

        .get_regionOverset = &get_regionOverset,

        .call_getRegionFlowRanges = &call_getRegionFlowRanges,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        RegionImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        RegionImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_regionOverset(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RegionImpl.get_regionOverset(state);
    }

    pub fn call_getRegionFlowRanges(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RegionImpl.call_getRegionFlowRanges(state);
    }

};
