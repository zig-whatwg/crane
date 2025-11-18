//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSTranslateImpl = @import("impls").CSSTranslate;
const CSSTransformComponent = @import("interfaces").CSSTransformComponent;
const CSSNumericValue = @import("interfaces").CSSNumericValue;

pub const CSSTranslate = struct {
    pub const Meta = struct {
        pub const name = "CSSTranslate";
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
            x: CSSNumericValue = undefined,
            y: CSSNumericValue = undefined,
            z: CSSNumericValue = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSTranslate, .{
        .deinit_fn = &deinit_wrapper,

        .get_is2D = &get_is2D,
        .get_x = &get_x,
        .get_y = &get_y,
        .get_z = &get_z,

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
        CSSTranslateImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSTranslateImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, x: CSSNumericValue, y: CSSNumericValue, z: CSSNumericValue) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try CSSTranslateImpl.constructor(instance, x, y, z);
        
        return instance;
    }

    pub fn get_is2D(instance: *runtime.Instance) anyerror!bool {
        return try CSSTranslateImpl.get_is2D(instance);
    }

    pub fn set_is2D(instance: *runtime.Instance, value: bool) anyerror!void {
        try CSSTranslateImpl.set_is2D(instance, value);
    }

    pub fn get_x(instance: *runtime.Instance) anyerror!CSSNumericValue {
        return try CSSTranslateImpl.get_x(instance);
    }

    pub fn set_x(instance: *runtime.Instance, value: CSSNumericValue) anyerror!void {
        try CSSTranslateImpl.set_x(instance, value);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!CSSNumericValue {
        return try CSSTranslateImpl.get_y(instance);
    }

    pub fn set_y(instance: *runtime.Instance, value: CSSNumericValue) anyerror!void {
        try CSSTranslateImpl.set_y(instance, value);
    }

    pub fn get_z(instance: *runtime.Instance) anyerror!CSSNumericValue {
        return try CSSTranslateImpl.get_z(instance);
    }

    pub fn set_z(instance: *runtime.Instance, value: CSSNumericValue) anyerror!void {
        try CSSTranslateImpl.set_z(instance, value);
    }

    pub fn call_toMatrix(instance: *runtime.Instance) anyerror!DOMMatrix {
        return try CSSTranslateImpl.call_toMatrix(instance);
    }

};
