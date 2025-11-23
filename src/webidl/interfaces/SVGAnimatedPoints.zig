//! Generated from: SVG.idl
//! Generated at: 2025-11-23T14:26:30Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGAnimatedPointsImpl = @import("impls").SVGAnimatedPoints;
const SVGPointList = @import("interfaces").SVGPointList;

pub const SVGAnimatedPoints = struct {
    pub const Meta = struct {
        pub const name = "SVGAnimatedPoints";
        pub const is_mixin = true;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "points", "get_points", null },
            .{ "animatedPoints", "get_animatedPoints", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "points", "get_points", null },
            .{ "animatedPoints", "get_animatedPoints", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            points: SVGPointList = undefined,
            animatedPoints: SVGPointList = undefined,
            cached_points: ?SVGPointList = null,
            cached_animatedPoints: ?SVGPointList = null,
            _internal: ?*SVGAnimatedPointsImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_animatedPoints = &get_animatedPoints,
        .get_points = &get_points,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SVGAnimatedPointsImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGAnimatedPointsImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_points(instance: *runtime.Instance) anyerror!SVGPointList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_points) |cached| {
            return cached;
        }
        const value = try SVGAnimatedPointsImpl.get_points(instance);
        state.own.cached_points = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_animatedPoints(instance: *runtime.Instance) anyerror!SVGPointList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_animatedPoints) |cached| {
            return cached;
        }
        const value = try SVGAnimatedPointsImpl.get_animatedPoints(instance);
        state.own.cached_animatedPoints = value;
        return value;
    }

};
