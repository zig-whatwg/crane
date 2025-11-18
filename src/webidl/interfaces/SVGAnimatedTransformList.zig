//! Generated from: SVG.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGAnimatedTransformListImpl = @import("impls").SVGAnimatedTransformList;
const SVGTransformList = @import("interfaces").SVGTransformList;

pub const SVGAnimatedTransformList = struct {
    pub const Meta = struct {
        pub const name = "SVGAnimatedTransformList";
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
            baseVal: SVGTransformList = undefined,
            animVal: SVGTransformList = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SVGAnimatedTransformList, .{
        .deinit_fn = &deinit_wrapper,

        .get_animVal = &get_animVal,
        .get_baseVal = &get_baseVal,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        SVGAnimatedTransformListImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGAnimatedTransformListImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_baseVal(instance: *runtime.Instance) anyerror!SVGTransformList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_baseVal) |cached| {
            return cached;
        }
        const value = try SVGAnimatedTransformListImpl.get_baseVal(instance);
        state.cached_baseVal = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_animVal(instance: *runtime.Instance) anyerror!SVGTransformList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_animVal) |cached| {
            return cached;
        }
        const value = try SVGAnimatedTransformListImpl.get_animVal(instance);
        state.cached_animVal = value;
        return value;
    }

};
