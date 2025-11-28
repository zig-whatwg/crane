//! Generated from: SVG.idl
//! Generated at: 2025-11-28T03:24:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGUseElementShadowRootImpl = @import("impls").SVGUseElementShadowRoot;
const ShadowRoot = @import("interfaces").ShadowRoot;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Document = @import("interfaces").Document;
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const HTMLCollection = @import("interfaces").HTMLCollection;
const SlotAssignmentMode = @import("enums").SlotAssignmentMode;
const TrustedHTML = @import("interfaces").TrustedHTML;
const Node = @import("interfaces").Node;
const NodeList = @import("interfaces").NodeList;
const USVString = @import("interfaces").USVString;
const CustomElementRegistry = @import("interfaces").CustomElementRegistry;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const Element = @import("interfaces").Element;
const Animation = @import("interfaces").Animation;
const ShadowRootMode = @import("enums").ShadowRootMode;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const StyleSheetList = @import("interfaces").StyleSheetList;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const SVGUseElementShadowRoot = struct {
    pub const Meta = struct {
        pub const name = "SVGUseElementShadowRoot";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *ShadowRoot;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "getRootNode",
            "hasChildNodes",
            "normalize",
            "cloneNode",
            "isEqualNode",
            "isSameNode",
            "compareDocumentPosition",
            "contains",
            "lookupPrefix",
            "lookupNamespaceURI",
            "isDefaultNamespace",
            "insertBefore",
            "appendChild",
            "replaceChild",
            "removeChild",
            "getElementById",
            "prepend",
            "append",
            "replaceChildren",
            "moveBefore",
            "querySelector",
            "querySelectorAll",
            "setHTMLUnsafe",
            "getHTML",
            "getAnimations",
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
            _internal: ?*SVGUseElementShadowRootImpl.InternalState = null,
        },
    );

    const delegates = .{
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SVGUseElementShadowRootImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGUseElementShadowRootImpl.deinit(instance);
    }

};
