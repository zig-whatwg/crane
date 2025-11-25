//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-25T13:07:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSSkewImpl = @import("impls").CSSSkew;
const CSSTransformComponent = @import("interfaces").CSSTransformComponent;
const CSSNumericValue = @import("interfaces").CSSNumericValue;
const DOMMatrix = @import("interfaces").DOMMatrix;
const DOMString = @import("typedefs").DOMString;

pub const CSSSkew = struct {
    pub const Meta = struct {
        pub const name = "CSSSkew";
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
            .{ "ax", "get_ax", "set_ax" },
            .{ "ay", "get_ay", "set_ay" },
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
            .{ "ax", "get_ax", "set_ax" },
            .{ "ay", "get_ay", "set_ay" },
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
            ax: *runtime.Instance = undefined,
            ay: *runtime.Instance = undefined,
            _internal: ?*CSSSkewImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_ax = &get_ax,
        .get_ay = &get_ay,

        .set_ax = &set_ax,
        .set_ay = &set_ay,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSSkewImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSSkewImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, ax: *runtime.Instance, ay: *runtime.Instance) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSSkewImpl.call_constructor(allocator, ctx, ax, ay);
    }

    pub fn get_ax(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSSkewImpl.get_ax(instance);
    }

    pub fn set_ax(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try CSSSkewImpl.set_ax(instance, value);
    }

    pub fn get_ay(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSSkewImpl.get_ay(instance);
    }

    pub fn set_ay(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try CSSSkewImpl.set_ay(instance, value);
    }

};
