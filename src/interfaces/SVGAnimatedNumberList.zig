//! Generated from: SVG.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGAnimatedNumberListImpl = @import("../impls/SVGAnimatedNumberList.zig");

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
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        SVGAnimatedNumberListImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SVGAnimatedNumberListImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_baseVal(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_baseVal) |cached| {
            return cached;
        }
        const value = SVGAnimatedNumberListImpl.get_baseVal(state);
        state.cached_baseVal = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_animVal(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_animVal) |cached| {
            return cached;
        }
        const value = SVGAnimatedNumberListImpl.get_animVal(state);
        state.cached_animVal = value;
        return value;
    }

};
