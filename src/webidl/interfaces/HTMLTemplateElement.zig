//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLTemplateElementImpl = @import("impls").HTMLTemplateElement;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const HTMLElement = @import("HTMLElement.zig").HTMLElement;
const DOMStringMap = @import("DOMStringMap.zig").DOMStringMap;
const CSSOMString = @import("typedefs").CSSOMString;
const HTMLCollection = @import("HTMLCollection.zig").HTMLCollection;
const TogglePopoverOptions = @import("dictionaries").TogglePopoverOptions;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const GeometryNode = @import("typedefs").GeometryNode;
const NamedNodeMap = @import("NamedNodeMap.zig").NamedNodeMap;
const CSSStyleDeclaration = @import("CSSStyleDeclaration.zig").CSSStyleDeclaration;
const USVString = @import("typedefs").USVString;
const TrustedType = @import("typedefs").TrustedType;
const Element = @import("Element.zig").Element;
const CheckVisibilityOptions = @import("dictionaries").CheckVisibilityOptions;
const ScrollIntoViewOptions = @import("dictionaries").ScrollIntoViewOptions;
const BoxQuadOptions = @import("dictionaries").BoxQuadOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const FocusableAreasOption = @import("dictionaries").FocusableAreasOption;
const EventListener = @import("EventListener.zig").EventListener;
const CSSStyleProperties = @import("CSSStyleProperties.zig").CSSStyleProperties;
const CSSPseudoElement = @import("CSSPseudoElement.zig").CSSPseudoElement;
const ShowPopoverOptions = @import("dictionaries").ShowPopoverOptions;
const ViewTransitionUpdateCallback = @import("callbacks").ViewTransitionUpdateCallback;
const Node = @import("Node.zig").Node;
const CustomElementRegistry = @import("CustomElementRegistry.zig").CustomElementRegistry;
const Animation = @import("Animation.zig").Animation;
const Range = @import("Range.zig").Range;
const Event = @import("Event.zig").Event;
const FocusOptions = @import("dictionaries").FocusOptions;
const DOMRectList = @import("DOMRectList.zig").DOMRectList;
const DOMString = @import("typedefs").DOMString;
const DocumentFragment = @import("DocumentFragment.zig").DocumentFragment;
const Document = @import("Document.zig").Document;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const ScrollToOptions = @import("dictionaries").ScrollToOptions;
const HTMLSlotElement = @import("HTMLSlotElement.zig").HTMLSlotElement;
const DOMQuad = @import("DOMQuad.zig").DOMQuad;
const DOMRectReadOnly = @import("DOMRectReadOnly.zig").DOMRectReadOnly;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const KeyframeAnimationOptions = @import("dictionaries").KeyframeAnimationOptions;
const StylePropertyMapReadOnly = @import("StylePropertyMapReadOnly.zig").StylePropertyMapReadOnly;
const DOMTokenList = @import("DOMTokenList.zig").DOMTokenList;
const StartViewTransitionOptions = @import("dictionaries").StartViewTransitionOptions;
const EditContext = @import("EditContext.zig").EditContext;
const DOMRect = @import("DOMRect.zig").DOMRect;
const ElementInternals = @import("ElementInternals.zig").ElementInternals;
const ViewTransition = @import("ViewTransition.zig").ViewTransition;
const SpatialNavigationSearchOptions = @import("dictionaries").SpatialNavigationSearchOptions;
const GetAnimationsOptions = @import("dictionaries").GetAnimationsOptions;
const EventHandler = @import("typedefs").EventHandler;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const SpatialNavigationDirection = @import("enums").SpatialNavigationDirection;
const StylePropertyMap = @import("StylePropertyMap.zig").StylePropertyMap;
const ShadowRoot = @import("ShadowRoot.zig").ShadowRoot;
const Attr = @import("Attr.zig").Attr;
const TrustedHTML = @import("TrustedHTML.zig").TrustedHTML;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const NodeList = @import("NodeList.zig").NodeList;
const FullscreenOptions = @import("dictionaries").FullscreenOptions;
const Observable = @import("Observable.zig").Observable;
const DOMPoint = @import("DOMPoint.zig").DOMPoint;
const PointerLockOptions = @import("dictionaries").PointerLockOptions;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const ShadowRootInit = @import("dictionaries").ShadowRootInit;

pub const HTMLTemplateElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLTemplateElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = HTMLElement.State;
        pub const ParentInterface = HTMLElement;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "content", "get_content", null },
            .{ "shadowRootMode", "get_shadowRootMode", "set_shadowRootMode" },
            .{ "shadowRootDelegatesFocus", "get_shadowRootDelegatesFocus", "set_shadowRootDelegatesFocus" },
            .{ "shadowRootClonable", "get_shadowRootClonable", "set_shadowRootClonable" },
            .{ "shadowRootSerializable", "get_shadowRootSerializable", "set_shadowRootSerializable" },
            .{ "shadowRootCustomElementRegistry", "get_shadowRootCustomElementRegistry", "set_shadowRootCustomElementRegistry" },
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
            "hasAttributes",
            "getAttributeNames",
            "getAttribute",
            "getAttributeNS",
            "setAttribute",
            "setAttributeNS",
            "removeAttribute",
            "removeAttributeNS",
            "toggleAttribute",
            "hasAttribute",
            "hasAttributeNS",
            "getAttributeNode",
            "getAttributeNodeNS",
            "setAttributeNode",
            "setAttributeNodeNS",
            "removeAttributeNode",
            "attachShadow",
            "closest",
            "matches",
            "webkitMatchesSelector",
            "getElementsByTagName",
            "getElementsByTagNameNS",
            "getElementsByClassName",
            "insertAdjacentElement",
            "insertAdjacentText",
            "getSpatialNavigationContainer",
            "focusableAreas",
            "spatialNavigationSearch",
            "requestFullscreen",
            "requestPointerLock",
            "setPointerCapture",
            "releasePointerCapture",
            "hasPointerCapture",
            "computedStyleMap",
            "pseudo",
            "startViewTransition",
            "setHTMLUnsafe",
            "getHTML",
            "insertAdjacentHTML",
            "getClientRects",
            "getBoundingClientRect",
            "checkVisibility",
            "scrollIntoView",
            "scroll",
            "scroll",
            "scrollTo",
            "scrollTo",
            "scrollBy",
            "scrollBy",
            "animate",
            "getAnimations",
            "getRegionFlowRanges",
            "prepend",
            "append",
            "replaceChildren",
            "moveBefore",
            "querySelector",
            "querySelectorAll",
            "before",
            "after",
            "replaceWith",
            "remove",
            "getBoxQuads",
            "convertQuadFromNode",
            "convertRectFromNode",
            "convertPointFromNode",
            "click",
            "attachInternals",
            "showPopover",
            "hidePopover",
            "togglePopover",
            "focus",
            "blur",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "content", "get_content", null },
            .{ "shadowRootMode", "get_shadowRootMode", "set_shadowRootMode" },
            .{ "shadowRootDelegatesFocus", "get_shadowRootDelegatesFocus", "set_shadowRootDelegatesFocus" },
            .{ "shadowRootClonable", "get_shadowRootClonable", "set_shadowRootClonable" },
            .{ "shadowRootSerializable", "get_shadowRootSerializable", "set_shadowRootSerializable" },
            .{ "shadowRootCustomElementRegistry", "get_shadowRootCustomElementRegistry", "set_shadowRootCustomElementRegistry" },
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
            content: *runtime.Instance = undefined,
            shadowRootMode: typedefs.DOMString = undefined,
            shadowRootDelegatesFocus: bool = undefined,
            shadowRootClonable: bool = undefined,
            shadowRootSerializable: bool = undefined,
            shadowRootCustomElementRegistry: typedefs.DOMString = undefined,
            _internal: ?*HTMLTemplateElementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_content = &get_content,
        .get_shadowRootClonable = &get_shadowRootClonable,
        .get_shadowRootCustomElementRegistry = &get_shadowRootCustomElementRegistry,
        .get_shadowRootDelegatesFocus = &get_shadowRootDelegatesFocus,
        .get_shadowRootMode = &get_shadowRootMode,
        .get_shadowRootSerializable = &get_shadowRootSerializable,

        .set_shadowRootClonable = &set_shadowRootClonable,
        .set_shadowRootCustomElementRegistry = &set_shadowRootCustomElementRegistry,
        .set_shadowRootDelegatesFocus = &set_shadowRootDelegatesFocus,
        .set_shadowRootMode = &set_shadowRootMode,
        .set_shadowRootSerializable = &set_shadowRootSerializable,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLTemplateElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return HTMLTemplateElementImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLTemplateElementImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLTemplateElementImpl.call_constructor(ctx);
    }

    pub fn get_content(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLTemplateElementImpl.get_content(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_shadowRootMode(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTemplateElementImpl.get_shadowRootMode(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_shadowRootMode(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTemplateElementImpl.set_shadowRootMode(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_shadowRootDelegatesFocus(instance: *runtime.Instance) anyerror!bool {
        return try HTMLTemplateElementImpl.get_shadowRootDelegatesFocus(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_shadowRootDelegatesFocus(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTemplateElementImpl.set_shadowRootDelegatesFocus(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_shadowRootClonable(instance: *runtime.Instance) anyerror!bool {
        return try HTMLTemplateElementImpl.get_shadowRootClonable(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_shadowRootClonable(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTemplateElementImpl.set_shadowRootClonable(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_shadowRootSerializable(instance: *runtime.Instance) anyerror!bool {
        return try HTMLTemplateElementImpl.get_shadowRootSerializable(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_shadowRootSerializable(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTemplateElementImpl.set_shadowRootSerializable(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_shadowRootCustomElementRegistry(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTemplateElementImpl.get_shadowRootCustomElementRegistry(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_shadowRootCustomElementRegistry(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTemplateElementImpl.set_shadowRootCustomElementRegistry(instance, value);
    }

};
