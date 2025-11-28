//! Generated from: DOM-Style.idl
//! Generated at: 2025-11-28T19:51:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DocumentCSSImpl = @import("impls").DocumentCSS;
const mixins = @import("mixins");
const DocumentStyle = @import("interfaces").DocumentStyle;
const Element = @import("interfaces").Element;
const StyleSheetList = @import("interfaces").StyleSheetList;
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const DOMString = @import("typedefs").DOMString;

pub const DocumentCSS = struct {
    pub const Meta = struct {
        pub const name = "DocumentCSS";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *DocumentStyle;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getOverrideStyle", "call_getOverrideStyle", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getOverrideStyle",
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
        struct {
            _internal: ?*DocumentCSSImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_getOverrideStyle = &call_getOverrideStyle,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DocumentCSSImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DocumentCSSImpl.deinit(instance);
    }

    pub fn call_getOverrideStyle(instance: *runtime.Instance, elt: *runtime.Instance, pseudoElt: DOMString) anyerror!*runtime.Instance {
        
        return try DocumentCSSImpl.call_getOverrideStyle(instance, elt, pseudoElt);
    }

};
