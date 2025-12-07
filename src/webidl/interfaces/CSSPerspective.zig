//! Generated from: css-typed-om.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSPerspectiveImpl = @import("impls").CSSPerspective;
const mixins = @import("mixins");
const CSSTransformComponent = @import("interfaces").CSSTransformComponent;
const CSSPerspectiveValue = @import("typedefs").CSSPerspectiveValue;
const DOMMatrix = @import("interfaces").DOMMatrix;
const DOMString = @import("typedefs").DOMString;

pub const CSSPerspective = struct {
    pub const Meta = struct {
        pub const name = "CSSPerspective";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = CSSTransformComponent.State;
        pub const ParentInterface = CSSTransformComponent;
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
            .{ "length", "get_length", "set_length" },
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
            .{ "length", "get_length", "set_length" },
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
            length: CSSPerspectiveValue = undefined,
            _internal: ?*CSSPerspectiveImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_length = &get_length,

        .set_length = &set_length,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSPerspectiveImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSPerspectiveImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, length: CSSPerspectiveValue) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSPerspectiveImpl.call_constructor(allocator, ctx, length);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!CSSPerspectiveValue {
        return try CSSPerspectiveImpl.get_length(instance);
    }

    pub fn set_length(instance: *runtime.Instance, value: CSSPerspectiveValue) anyerror!void {
        try CSSPerspectiveImpl.set_length(instance, value);
    }

};
