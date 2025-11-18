//! Generated from: SVG.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGAnimatedNumberImpl = @import("../impls/SVGAnimatedNumber.zig");

pub const SVGAnimatedNumber = struct {
    pub const Meta = struct {
        pub const name = "SVGAnimatedNumber";
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
            baseVal: f32 = undefined,
            animVal: f32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SVGAnimatedNumber, .{
        .deinit_fn = &deinit_wrapper,

        .get_animVal = &get_animVal,
        .get_baseVal = &get_baseVal,

        .set_baseVal = &set_baseVal,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        SVGAnimatedNumberImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SVGAnimatedNumberImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_baseVal(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return SVGAnimatedNumberImpl.get_baseVal(state);
    }

    pub fn set_baseVal(instance: *runtime.Instance, value: f32) void {
        const state = instance.getState(State);
        SVGAnimatedNumberImpl.set_baseVal(state, value);
    }

    pub fn get_animVal(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return SVGAnimatedNumberImpl.get_animVal(state);
    }

};
