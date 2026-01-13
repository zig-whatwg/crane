//! Generated from: SVG.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGUseElementShadowRootImpl = @import("impls").SVGUseElementShadowRoot;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ShadowRoot = @import("ShadowRoot.zig").ShadowRoot;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Document = @import("Document.zig").Document;
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const CSSStyleSheet = @import("CSSStyleSheet.zig").CSSStyleSheet;
const HTMLCollection = @import("HTMLCollection.zig").HTMLCollection;
const SlotAssignmentMode = @import("enums").SlotAssignmentMode;
const TrustedHTML = @import("TrustedHTML.zig").TrustedHTML;
const Node = @import("Node.zig").Node;
const NodeList = @import("NodeList.zig").NodeList;
const USVString = @import("typedefs").USVString;
const CustomElementRegistry = @import("CustomElementRegistry.zig").CustomElementRegistry;
const Observable = @import("Observable.zig").Observable;
const Event = @import("Event.zig").Event;
const Element = @import("Element.zig").Element;
const Animation = @import("Animation.zig").Animation;
const ShadowRootMode = @import("enums").ShadowRootMode;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("EventListener.zig").EventListener;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const StyleSheetList = @import("StyleSheetList.zig").StyleSheetList;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const SVGUseElementShadowRoot = struct {
    pub const Meta = struct {
        pub const name = "SVGUseElementShadowRoot";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ShadowRoot.State;
        pub const ParentInterface = ShadowRoot;
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
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
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

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SVGUseElementShadowRootImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return SVGUseElementShadowRootImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGUseElementShadowRootImpl.deinit(instance);
    }

};
