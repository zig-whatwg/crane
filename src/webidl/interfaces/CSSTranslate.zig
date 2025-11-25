//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-25T14:21:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSTranslateImpl = @import("impls").CSSTranslate;
const CSSTransformComponent = @import("interfaces").CSSTransformComponent;
const CSSNumericValue = @import("interfaces").CSSNumericValue;
const DOMMatrix = @import("interfaces").DOMMatrix;
const DOMString = @import("typedefs").DOMString;

pub const CSSTranslate = struct {
    pub const Meta = struct {
        pub const name = "CSSTranslate";
        pub const is_mixin = false;
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
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
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
            x: *runtime.Instance = undefined,
            y: *runtime.Instance = undefined,
            z: *runtime.Instance = undefined,
            _internal: ?*CSSTranslateImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_x = &get_x,
        .get_y = &get_y,
        .get_z = &get_z,

        .set_x = &set_x,
        .set_y = &set_y,
        .set_z = &set_z,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSTranslateImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSTranslateImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, x: *runtime.Instance, y: *runtime.Instance, z: *runtime.Instance) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSTranslateImpl.call_constructor(allocator, ctx, x, y, z);
    }

    pub fn get_x(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSTranslateImpl.get_x(instance);
    }

    pub fn set_x(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try CSSTranslateImpl.set_x(instance, value);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSTranslateImpl.get_y(instance);
    }

    pub fn set_y(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try CSSTranslateImpl.set_y(instance, value);
    }

    pub fn get_z(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSTranslateImpl.get_z(instance);
    }

    pub fn set_z(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try CSSTranslateImpl.set_z(instance, value);
    }

};
