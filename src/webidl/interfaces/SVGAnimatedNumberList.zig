//! Generated from: SVG.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGAnimatedNumberListImpl = @import("impls").SVGAnimatedNumberList;
const SVGNumberList = @import("interfaces").SVGNumberList;

pub const SVGAnimatedNumberList = struct {
    pub const Meta = struct {
        pub const name = "SVGAnimatedNumberList";
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
            baseVal: SVGNumberList = undefined,
            animVal: SVGNumberList = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SVGAnimatedNumberList, .{
        .deinit_fn = &deinit_wrapper,

        .get_animVal = &get_animVal,
        .get_baseVal = &get_baseVal,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return SVGAnimatedNumberListImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGAnimatedNumberListImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_baseVal(instance: *runtime.Instance) anyerror!SVGNumberList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_baseVal) |cached| {
            return cached;
        }
        const value = try SVGAnimatedNumberListImpl.get_baseVal(instance);
        state.cached_baseVal = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_animVal(instance: *runtime.Instance) anyerror!SVGNumberList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_animVal) |cached| {
            return cached;
        }
        const value = try SVGAnimatedNumberListImpl.get_animVal(instance);
        state.cached_animVal = value;
        return value;
    }

};
