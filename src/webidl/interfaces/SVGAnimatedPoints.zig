//! Generated from: SVG.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGAnimatedPointsImpl = @import("impls").SVGAnimatedPoints;
const SVGPointList = @import("interfaces").SVGPointList;

pub const SVGAnimatedPoints = struct {
    pub const Meta = struct {
        pub const name = "SVGAnimatedPoints";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            points: SVGPointList = undefined,
            animatedPoints: SVGPointList = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SVGAnimatedPoints, .{
        .deinit_fn = &deinit_wrapper,

        .get_animatedPoints = &get_animatedPoints,
        .get_points = &get_points,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        SVGAnimatedPointsImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGAnimatedPointsImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_points(instance: *runtime.Instance) anyerror!SVGPointList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_points) |cached| {
            return cached;
        }
        const value = try SVGAnimatedPointsImpl.get_points(instance);
        state.cached_points = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_animatedPoints(instance: *runtime.Instance) anyerror!SVGPointList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_animatedPoints) |cached| {
            return cached;
        }
        const value = try SVGAnimatedPointsImpl.get_animatedPoints(instance);
        state.cached_animatedPoints = value;
        return value;
    }

};
