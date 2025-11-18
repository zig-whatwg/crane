//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSSkewXImpl = @import("impls").CSSSkewX;
const CSSTransformComponent = @import("interfaces").CSSTransformComponent;
const CSSNumericValue = @import("interfaces").CSSNumericValue;

pub const CSSSkewX = struct {
    pub const Meta = struct {
        pub const name = "CSSSkewX";
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
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSSkewX, .{
        .deinit_fn = &deinit_wrapper,

        .get_ax = &get_ax,
        .get_is2D = &get_is2D,

        .set_ax = &set_ax,
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
        CSSSkewXImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSSkewXImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ax: CSSNumericValue) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try CSSSkewXImpl.constructor(instance, ax);
        
        return instance;
    }

    pub fn get_is2D(instance: *runtime.Instance) anyerror!bool {
        return try CSSSkewXImpl.get_is2D(instance);
    }

    pub fn set_is2D(instance: *runtime.Instance, value: bool) anyerror!void {
        try CSSSkewXImpl.set_is2D(instance, value);
    }

    pub fn get_ax(instance: *runtime.Instance) anyerror!CSSNumericValue {
        return try CSSSkewXImpl.get_ax(instance);
    }

    pub fn set_ax(instance: *runtime.Instance, value: CSSNumericValue) anyerror!void {
        try CSSSkewXImpl.set_ax(instance, value);
    }

    pub fn call_toMatrix(instance: *runtime.Instance) anyerror!DOMMatrix {
        return try CSSSkewXImpl.call_toMatrix(instance);
    }

};
