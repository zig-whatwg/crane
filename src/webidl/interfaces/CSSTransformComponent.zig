//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-23T20:06:15Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSTransformComponentImpl = @import("impls").CSSTransformComponent;
const DOMMatrix = @import("interfaces").DOMMatrix;
const DOMString = @import("typedefs").DOMString;

pub const CSSTransformComponent = struct {
    pub const Meta = struct {
        pub const name = "CSSTransformComponent";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
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
            .{ "is2D", "get_is2D", "set_is2D" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "toMatrix", "call_toMatrix", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toMatrix",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "is2D", "get_is2D", "set_is2D" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            is2D: bool = undefined,
            _internal: ?*CSSTransformComponentImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_is2D = &get_is2D,

        .set_is2D = &set_is2D,

        .call_toMatrix = &call_toMatrix,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSTransformComponentImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSTransformComponentImpl.deinit(instance);
    }

    pub fn get_is2D(instance: *runtime.Instance) anyerror!bool {
        return try CSSTransformComponentImpl.get_is2D(instance);
    }

    pub fn set_is2D(instance: *runtime.Instance, value: bool) anyerror!void {
        try CSSTransformComponentImpl.set_is2D(instance, value);
    }

    pub fn call_toMatrix(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSTransformComponentImpl.call_toMatrix(instance);
    }

};
