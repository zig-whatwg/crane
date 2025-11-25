//! Generated from: html.idl
//! Generated at: 2025-11-25T20:02:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HTMLStyleElementImpl = @import("impls").HTMLStyleElement;
const HTMLElement = @import("interfaces").HTMLElement;
const LinkStyle = @import("interfaces").LinkStyle;
const DOMStringMap = @import("interfaces").DOMStringMap;
const CSSOMString = @import("typedefs").CSSOMString;
const HTMLCollection = @import("interfaces").HTMLCollection;
const TogglePopoverOptions = @import("dictionaries").TogglePopoverOptions;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const GeometryNode = @import("typedefs").GeometryNode;
const NamedNodeMap = @import("interfaces").NamedNodeMap;
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const USVString = @import("interfaces").USVString;
const TrustedType = @import("typedefs").TrustedType;
const Element = @import("interfaces").Element;
const CheckVisibilityOptions = @import("dictionaries").CheckVisibilityOptions;
const ScrollIntoViewOptions = @import("dictionaries").ScrollIntoViewOptions;
const BoxQuadOptions = @import("dictionaries").BoxQuadOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const FocusableAreasOption = @import("dictionaries").FocusableAreasOption;
const EventListener = @import("interfaces").EventListener;
const CSSStyleProperties = @import("interfaces").CSSStyleProperties;
const CSSPseudoElement = @import("interfaces").CSSPseudoElement;
const ShowPopoverOptions = @import("dictionaries").ShowPopoverOptions;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const ViewTransitionUpdateCallback = @import("callbacks").ViewTransitionUpdateCallback;
const Node = @import("interfaces").Node;
const CustomElementRegistry = @import("interfaces").CustomElementRegistry;
const Animation = @import("interfaces").Animation;
const Range = @import("interfaces").Range;
const Event = @import("interfaces").Event;
const FocusOptions = @import("dictionaries").FocusOptions;
const DOMRectList = @import("interfaces").DOMRectList;
const DOMString = @import("typedefs").DOMString;
const Document = @import("interfaces").Document;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const ScrollToOptions = @import("dictionaries").ScrollToOptions;
const HTMLSlotElement = @import("interfaces").HTMLSlotElement;
const DOMQuad = @import("interfaces").DOMQuad;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const KeyframeAnimationOptions = @import("dictionaries").KeyframeAnimationOptions;
const StylePropertyMapReadOnly = @import("interfaces").StylePropertyMapReadOnly;
const DOMTokenList = @import("interfaces").DOMTokenList;
const StartViewTransitionOptions = @import("dictionaries").StartViewTransitionOptions;
const EditContext = @import("interfaces").EditContext;
const DOMRect = @import("interfaces").DOMRect;
const ElementInternals = @import("interfaces").ElementInternals;
const ViewTransition = @import("interfaces").ViewTransition;
const StyleSheet = @import("interfaces").StyleSheet;
const SpatialNavigationSearchOptions = @import("dictionaries").SpatialNavigationSearchOptions;
const GetAnimationsOptions = @import("dictionaries").GetAnimationsOptions;
const EventHandler = @import("typedefs").EventHandler;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const SpatialNavigationDirection = @import("enums").SpatialNavigationDirection;
const StylePropertyMap = @import("interfaces").StylePropertyMap;
const ShadowRoot = @import("interfaces").ShadowRoot;
const Attr = @import("interfaces").Attr;
const TrustedHTML = @import("interfaces").TrustedHTML;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const NodeList = @import("interfaces").NodeList;
const FullscreenOptions = @import("dictionaries").FullscreenOptions;
const Observable = @import("interfaces").Observable;
const DOMPoint = @import("interfaces").DOMPoint;
const PointerLockOptions = @import("dictionaries").PointerLockOptions;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const ShadowRootInit = @import("dictionaries").ShadowRootInit;

pub const HTMLStyleElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLStyleElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *HTMLElement;
        pub const MixinTypes = &.{
            LinkStyle,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "disabled", "get_disabled", "set_disabled" },
            .{ "media", "get_media", "set_media" },
            .{ "blocking", "get_blocking", null },
            .{ "type", "get_type", "set_type" },
            .{ "sheet", "get_sheet", null },
            .{ "sheet", "get_sheet", null },
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
            .{ "disabled", "get_disabled", "set_disabled" },
            .{ "media", "get_media", "set_media" },
            .{ "blocking", "get_blocking", null },
            .{ "type", "get_type", "set_type" },
            .{ "sheet", "get_sheet", null },
            .{ "sheet", "get_sheet", null },
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
            disabled: bool = undefined,
            media: runtime.DOMString = undefined,
            blocking: *runtime.Instance = undefined,
            @"type": runtime.DOMString = undefined,
            sheet: ?*runtime.Instance = null,
            cached_blocking: ?*runtime.Instance = null,
            _internal: ?*HTMLStyleElementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_blocking = &get_blocking,
        .get_disabled = &get_disabled,
        .get_media = &get_media,
        .get_sheet = &get_sheet,
        .get_type = &get_type,

        .set_disabled = &set_disabled,
        .set_media = &set_media,
        .set_type = &set_type,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLStyleElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLStyleElementImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLStyleElementImpl.call_constructor(allocator, ctx);
    }

    pub fn get_disabled(instance: *runtime.Instance) anyerror!bool {
        return try HTMLStyleElementImpl.get_disabled(instance);
    }

    pub fn set_disabled(instance: *runtime.Instance, value: bool) anyerror!void {
        try HTMLStyleElementImpl.set_disabled(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_media(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLStyleElementImpl.get_media(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_media(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLStyleElementImpl.set_media(instance, value);
    }

    /// Extended attributes: [SameObject], [PutForwards=value], [Reflect]
    pub fn get_blocking(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_blocking) |cached| {
            return cached;
        }
        const value = try HTMLStyleElementImpl.get_blocking(instance);
        state.own.cached_blocking = value;
        return value;
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLStyleElementImpl.get_type(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_type(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLStyleElementImpl.set_type(instance, value);
    }

    pub fn get_sheet(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try HTMLStyleElementImpl.get_sheet(instance);
    }

};
