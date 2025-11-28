//! Generated from: DOM-Style.idl
//! Generated at: 2025-11-28T22:33:20Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DOMImplementationCSSImpl = @import("impls").DOMImplementationCSS;
const mixins = @import("mixins");
const DOMImplementation = @import("interfaces").DOMImplementation;
const Document = @import("interfaces").Document;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const DocumentType = @import("interfaces").DocumentType;
const XMLDocument = @import("interfaces").XMLDocument;
const DOMString = @import("typedefs").DOMString;

pub const DOMImplementationCSS = struct {
    pub const Meta = struct {
        pub const name = "DOMImplementationCSS";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *DOMImplementation;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "createCSSStyleSheet", "call_createCSSStyleSheet", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createCSSStyleSheet",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "createDocumentType",
            "createDocument",
            "createHTMLDocument",
            "hasFeature",
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
            _internal: ?*DOMImplementationCSSImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_createCSSStyleSheet = &call_createCSSStyleSheet,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DOMImplementationCSSImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DOMImplementationCSSImpl.deinit(instance);
    }

    pub fn call_createCSSStyleSheet(instance: *runtime.Instance, title: DOMString, media: DOMString) anyerror!*runtime.Instance {
        
        return try DOMImplementationCSSImpl.call_createCSSStyleSheet(instance, title, media);
    }

};
