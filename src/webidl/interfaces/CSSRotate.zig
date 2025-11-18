//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSRotateImpl = @import("impls").CSSRotate;
const CSSTransformComponent = @import("interfaces").CSSTransformComponent;
const CSSNumericValue = @import("interfaces").CSSNumericValue;
const CSSNumberish = @import("typedefs").CSSNumberish;

pub const CSSRotate = struct {
    pub const Meta = struct {
        pub const name = "CSSRotate";
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
            x: CSSNumberish = undefined,
            y: CSSNumberish = undefined,
            z: CSSNumberish = undefined,
            angle: CSSNumericValue = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSRotate, .{
        .deinit_fn = &deinit_wrapper,

        .get_angle = &get_angle,
        .get_is2D = &get_is2D,
        .get_x = &get_x,
        .get_y = &get_y,
        .get_z = &get_z,

        .set_angle = &set_angle,
        .set_is2D = &set_is2D,
        .set_x = &set_x,
        .set_y = &set_y,
        .set_z = &set_z,

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
        CSSRotateImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSRotateImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, angle: CSSNumericValue) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try CSSRotateImpl.constructor(instance, angle);
        
        return instance;
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, x: CSSNumberish, y: CSSNumberish, z: CSSNumberish, angle: CSSNumericValue) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try CSSRotateImpl.constructor(instance, x, y, z, angle);
        
        return instance;
    }

    pub fn get_is2D(instance: *runtime.Instance) anyerror!bool {
        return try CSSRotateImpl.get_is2D(instance);
    }

    pub fn set_is2D(instance: *runtime.Instance, value: bool) anyerror!void {
        try CSSRotateImpl.set_is2D(instance, value);
    }

    pub fn get_x(instance: *runtime.Instance) anyerror!CSSNumberish {
        return try CSSRotateImpl.get_x(instance);
    }

    pub fn set_x(instance: *runtime.Instance, value: CSSNumberish) anyerror!void {
        try CSSRotateImpl.set_x(instance, value);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!CSSNumberish {
        return try CSSRotateImpl.get_y(instance);
    }

    pub fn set_y(instance: *runtime.Instance, value: CSSNumberish) anyerror!void {
        try CSSRotateImpl.set_y(instance, value);
    }

    pub fn get_z(instance: *runtime.Instance) anyerror!CSSNumberish {
        return try CSSRotateImpl.get_z(instance);
    }

    pub fn set_z(instance: *runtime.Instance, value: CSSNumberish) anyerror!void {
        try CSSRotateImpl.set_z(instance, value);
    }

    pub fn get_angle(instance: *runtime.Instance) anyerror!CSSNumericValue {
        return try CSSRotateImpl.get_angle(instance);
    }

    pub fn set_angle(instance: *runtime.Instance, value: CSSNumericValue) anyerror!void {
        try CSSRotateImpl.set_angle(instance, value);
    }

    pub fn call_toMatrix(instance: *runtime.Instance) anyerror!DOMMatrix {
        return try CSSRotateImpl.call_toMatrix(instance);
    }

};
