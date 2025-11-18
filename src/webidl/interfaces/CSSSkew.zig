//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSSkewImpl = @import("impls").CSSSkew;
const CSSTransformComponent = @import("interfaces").CSSTransformComponent;
const CSSNumericValue = @import("interfaces").CSSNumericValue;

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
        
        // Initialize the instance (Impl receives full instance)
        CSSSkewImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSSkewImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ax: CSSNumericValue, ay: CSSNumericValue) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try CSSSkewImpl.constructor(instance, ax, ay);
        
        return instance;
    }

    pub fn get_is2D(instance: *runtime.Instance) anyerror!bool {
        return try CSSSkewImpl.get_is2D(instance);
    }

    pub fn set_is2D(instance: *runtime.Instance, value: bool) anyerror!void {
        try CSSSkewImpl.set_is2D(instance, value);
    }

    pub fn get_ax(instance: *runtime.Instance) anyerror!CSSNumericValue {
        return try CSSSkewImpl.get_ax(instance);
    }

    pub fn set_ax(instance: *runtime.Instance, value: CSSNumericValue) anyerror!void {
        try CSSSkewImpl.set_ax(instance, value);
    }

    pub fn get_ay(instance: *runtime.Instance) anyerror!CSSNumericValue {
        return try CSSSkewImpl.get_ay(instance);
    }

    pub fn set_ay(instance: *runtime.Instance, value: CSSNumericValue) anyerror!void {
        try CSSSkewImpl.set_ay(instance, value);
    }

    pub fn call_toMatrix(instance: *runtime.Instance) anyerror!DOMMatrix {
        return try CSSSkewImpl.call_toMatrix(instance);
    }

};
