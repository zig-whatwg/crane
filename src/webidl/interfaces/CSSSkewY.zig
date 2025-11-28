//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-28T18:57:54Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSSkewYImpl = @import("impls").CSSSkewY;
const mixins = @import("mixins");
const CSSTransformComponent = @import("interfaces").CSSTransformComponent;
const CSSNumericValue = @import("interfaces").CSSNumericValue;
const DOMMatrix = @import("interfaces").DOMMatrix;
const DOMString = @import("typedefs").DOMString;

pub const CSSSkewY = struct {
    pub const Meta = struct {
        pub const name = "CSSSkewY";
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
            .{ "ay", "get_ay", "set_ay" },
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
            ay: *runtime.Instance = undefined,
            _internal: ?*CSSSkewYImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_ay = &get_ay,

        .set_ay = &set_ay,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSSkewYImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSSkewYImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, ay: *runtime.Instance) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSSkewYImpl.call_constructor(allocator, ctx, ay);
    }

    pub fn get_ay(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSSkewYImpl.get_ay(instance);
    }

    pub fn set_ay(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try CSSSkewYImpl.set_ay(instance, value);
    }

};
