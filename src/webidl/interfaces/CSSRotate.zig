//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-28T18:57:54Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSRotateImpl = @import("impls").CSSRotate;
const mixins = @import("mixins");
const CSSTransformComponent = @import("interfaces").CSSTransformComponent;
const CSSNumericValue = @import("interfaces").CSSNumericValue;
const CSSNumberish = @import("typedefs").CSSNumberish;
const DOMMatrix = @import("interfaces").DOMMatrix;
const DOMString = @import("typedefs").DOMString;

pub const CSSRotate = struct {
    pub const Meta = struct {
        pub const name = "CSSRotate";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSTransformComponent;
        pub const MixinTypes = &.{};
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
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "x", "get_x", "set_x" },
            .{ "y", "get_y", "set_y" },
            .{ "z", "get_z", "set_z" },
            .{ "angle", "get_angle", "set_angle" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "toMatrix",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "x", "get_x", "set_x" },
            .{ "y", "get_y", "set_y" },
            .{ "z", "get_z", "set_z" },
            .{ "angle", "get_angle", "set_angle" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            x: CSSNumberish = undefined,
            y: CSSNumberish = undefined,
            z: CSSNumberish = undefined,
            angle: *runtime.Instance = undefined,
            _internal: ?*CSSRotateImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_angle = &get_angle,
        .get_x = &get_x,
        .get_y = &get_y,
        .get_z = &get_z,

        .set_angle = &set_angle,
        .set_x = &set_x,
        .set_y = &set_y,
        .set_z = &set_z,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSRotateImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSRotateImpl.deinit(instance);
    }

    /// Arguments for constructor (WebIDL overloading)
    pub const ConstructorArgs = union(enum) {
        /// constructor(angle)
        CSSNumericValue: CSSNumericValue,
        /// constructor(x, y, z, angle)
        CSSNumberish_CSSNumberish_CSSNumberish_CSSNumericValue: struct {
            x: CSSNumberish,
            y: CSSNumberish,
            z: CSSNumberish,
            angle: CSSNumericValue,
        },
    };

    /// WebIDL constructor (overloaded)
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, args: ConstructorArgs) !*runtime.Instance {
        // Pass args union directly to impl
        return try CSSRotateImpl.call_constructor(allocator, ctx, args);
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

    pub fn get_angle(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSRotateImpl.get_angle(instance);
    }

    pub fn set_angle(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try CSSRotateImpl.set_angle(instance, value);
    }

};
