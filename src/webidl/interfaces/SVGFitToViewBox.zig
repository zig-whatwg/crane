//! Generated from: SVG.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGFitToViewBoxImpl = @import("impls").SVGFitToViewBox;
const SVGAnimatedRect = @import("interfaces").SVGAnimatedRect;
const SVGAnimatedPreserveAspectRatio = @import("interfaces").SVGAnimatedPreserveAspectRatio;

pub const SVGFitToViewBox = struct {
    pub const Meta = struct {
        pub const name = "SVGFitToViewBox";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            viewBox: SVGAnimatedRect = undefined,
            preserveAspectRatio: SVGAnimatedPreserveAspectRatio = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SVGFitToViewBox, .{
        .deinit_fn = &deinit_wrapper,

        .get_preserveAspectRatio = &get_preserveAspectRatio,
        .get_viewBox = &get_viewBox,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        SVGFitToViewBoxImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGFitToViewBoxImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_viewBox(instance: *runtime.Instance) anyerror!SVGAnimatedRect {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_viewBox) |cached| {
            return cached;
        }
        const value = try SVGFitToViewBoxImpl.get_viewBox(instance);
        state.cached_viewBox = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_preserveAspectRatio(instance: *runtime.Instance) anyerror!SVGAnimatedPreserveAspectRatio {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_preserveAspectRatio) |cached| {
            return cached;
        }
        const value = try SVGFitToViewBoxImpl.get_preserveAspectRatio(instance);
        state.cached_preserveAspectRatio = value;
        return value;
    }

};
