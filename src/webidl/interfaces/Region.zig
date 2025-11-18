//! Generated from: css-regions.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RegionImpl = @import("impls").Region;
const sequence = @import("interfaces").sequence;
const CSSOMString = @import("interfaces").CSSOMString;

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
        
        // Initialize the instance (Impl receives full instance)
        RegionImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RegionImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_regionOverset(instance: *runtime.Instance) anyerror!anyopaque {
        return try RegionImpl.get_regionOverset(instance);
    }

    pub fn call_getRegionFlowRanges(instance: *runtime.Instance) anyerror!anyopaque {
        return try RegionImpl.call_getRegionFlowRanges(instance);
    }

};
