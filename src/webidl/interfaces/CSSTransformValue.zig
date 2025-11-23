//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-23T20:06:15Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSTransformValueImpl = @import("impls").CSSTransformValue;
const CSSStyleValue = @import("interfaces").CSSStyleValue;
const CSSTransformComponent = @import("interfaces").CSSTransformComponent;
const DOMMatrix = @import("interfaces").DOMMatrix;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const CSSTransformValue = struct {
    pub const Meta = struct {
        pub const name = "CSSTransformValue";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CSSStyleValue;
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
            .{ "length", "get_length", null },
            .{ "is2D", "get_is2D", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "toMatrix", "call_toMatrix", 0 },
            .{ "forEach", "call_forEach", 1 },
            .{ "forEach", "call_forEach", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toMatrix",
            "forEach",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "parse",
            "parseAll",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "length", "get_length", null },
            .{ "is2D", "get_is2D", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
        
        /// Iterable declaration (for Symbol.iterator support)
        pub const iterable = .{
            .value_type = "CSSTransformComponent",
            .key_type = null,
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            length: u32 = undefined,
            is2D: bool = undefined,
            _internal: ?*CSSTransformValueImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_is2D = &get_is2D,
        .get_length = &get_length,

        .call_forEach = &call_forEach,
        .call_toMatrix = &call_toMatrix,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSTransformValueImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSTransformValueImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, transforms: *const anyopaque) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSTransformValueImpl.call_constructor(allocator, ctx, transforms);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try CSSTransformValueImpl.get_length(instance);
    }

    pub fn get_is2D(instance: *runtime.Instance) anyerror!bool {
        return try CSSTransformValueImpl.get_is2D(instance);
    }

    pub fn call_forEach(instance: *runtime.Instance, callback: *const anyopaque) anyerror!void {
        
        return try CSSTransformValueImpl.call_forEach(instance, callback);
    }

    pub fn call_toMatrix(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSTransformValueImpl.call_toMatrix(instance);
    }

};
