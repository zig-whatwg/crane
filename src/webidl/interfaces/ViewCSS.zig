//! Generated from: DOM-Style.idl
//! Generated at: 2025-11-23T19:57:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ViewCSSImpl = @import("impls").ViewCSS;
const AbstractView = @import("interfaces").AbstractView;
const Element = @import("interfaces").Element;
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const DOMString = @import("typedefs").DOMString;

pub const ViewCSS = struct {
    pub const Meta = struct {
        pub const name = "ViewCSS";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *AbstractView;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "getComputedStyle", "call_getComputedStyle", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getComputedStyle",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {},
    );

    const delegates = .{

        .call_getComputedStyle = &call_getComputedStyle,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ViewCSSImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ViewCSSImpl.deinit(instance);
    }

    pub fn call_getComputedStyle(instance: *runtime.Instance, elt: *runtime.Instance, pseudoElt: DOMString) anyerror!*runtime.Instance {
        
        return try ViewCSSImpl.call_getComputedStyle(instance, elt, pseudoElt);
    }

};
