//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSSkewImpl = @import("../impls/CSSSkew.zig");
const CSSTransformComponent = @import("CSSTransformComponent.zig");

pub const CSSSkew = struct {
    pub const Meta = struct {
        pub const name = "CSSSkew";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSTransformComponent;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker", "PaintWorklet", "LayoutWorklet" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
            .PaintWorklet = true,
            .LayoutWorklet = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            ax: CSSNumericValue = undefined,
            ay: CSSNumericValue = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSSkew, .{
        .deinit_fn = &deinit_wrapper,

        .get_ax = &get_ax,
        .get_ay = &get_ay,
        .get_is2D = &get_is2D,

        .set_ax = &set_ax,
        .set_ay = &set_ay,
        .set_is2D = &set_is2D,

        .call_toMatrix = &call_toMatrix,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CSSSkewImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CSSSkewImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ax: anyopaque, ay: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try CSSSkewImpl.constructor(state, ax, ay);
        
        return instance;
    }

    pub fn get_is2D(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return CSSSkewImpl.get_is2D(state);
    }

    pub fn set_is2D(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        CSSSkewImpl.set_is2D(state, value);
    }

    pub fn get_ax(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSSkewImpl.get_ax(state);
    }

    pub fn set_ax(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSSkewImpl.set_ax(state, value);
    }

    pub fn get_ay(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSSkewImpl.get_ay(state);
    }

    pub fn set_ay(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CSSSkewImpl.set_ay(state, value);
    }

    pub fn call_toMatrix(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CSSSkewImpl.call_toMatrix(state);
    }

};
