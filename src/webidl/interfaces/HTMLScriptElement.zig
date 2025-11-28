//! Generated from: html.idl
//! Generated at: 2025-11-28T03:24:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HTMLScriptElementImpl = @import("impls").HTMLScriptElement;
const HTMLElement = @import("interfaces").HTMLElement;
const HTMLAttributionSrcElementUtils = @import("interfaces").HTMLAttributionSrcElementUtils;
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

pub const HTMLScriptElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLScriptElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *HTMLElement;
        pub const MixinTypes = &.{
            HTMLAttributionSrcElementUtils,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "type", "get_type", "set_type" },
            .{ "src", "get_src", "set_src" },
            .{ "noModule", "get_noModule", "set_noModule" },
            .{ "async", "get_async", "set_async" },
            .{ "defer", "get_defer", "set_defer" },
            .{ "blocking", "get_blocking", null },
            .{ "crossOrigin", "get_crossOrigin", "set_crossOrigin" },
            .{ "referrerPolicy", "get_referrerPolicy", "set_referrerPolicy" },
            .{ "integrity", "get_integrity", "set_integrity" },
            .{ "fetchPriority", "get_fetchPriority", "set_fetchPriority" },
            .{ "text", "get_text", "set_text" },
            .{ "charset", "get_charset", "set_charset" },
            .{ "event", "get_event", "set_event" },
            .{ "htmlFor", "get_htmlFor", "set_htmlFor" },
            .{ "attributionSrc", "get_attributionSrc", "set_attributionSrc" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "supports", "call_supports", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "supports",
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
            .{ "type", "get_type", "set_type" },
            .{ "src", "get_src", "set_src" },
            .{ "noModule", "get_noModule", "set_noModule" },
            .{ "async", "get_async", "set_async" },
            .{ "defer", "get_defer", "set_defer" },
            .{ "blocking", "get_blocking", null },
            .{ "crossOrigin", "get_crossOrigin", "set_crossOrigin" },
            .{ "referrerPolicy", "get_referrerPolicy", "set_referrerPolicy" },
            .{ "integrity", "get_integrity", "set_integrity" },
            .{ "fetchPriority", "get_fetchPriority", "set_fetchPriority" },
            .{ "text", "get_text", "set_text" },
            .{ "charset", "get_charset", "set_charset" },
            .{ "event", "get_event", "set_event" },
            .{ "htmlFor", "get_htmlFor", "set_htmlFor" },
            .{ "attributionSrc", "get_attributionSrc", "set_attributionSrc" },
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
            @"type": runtime.DOMString = undefined,
            src: runtime.USVString = undefined,
            noModule: bool = undefined,
            @"async": bool = undefined,
            @"defer": bool = undefined,
            blocking: *runtime.Instance = undefined,
            crossOrigin: ?runtime.DOMString = null,
            referrerPolicy: runtime.DOMString = undefined,
            integrity: runtime.DOMString = undefined,
            fetchPriority: runtime.DOMString = undefined,
            text: runtime.DOMString = undefined,
            charset: runtime.DOMString = undefined,
            event: runtime.DOMString = undefined,
            htmlFor: runtime.DOMString = undefined,
            attributionSrc: runtime.USVString = undefined,
            cached_blocking: ?*runtime.Instance = null,
            _internal: ?*HTMLScriptElementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_async = &get_async,
        .get_attributionSrc = &get_attributionSrc,
        .get_blocking = &get_blocking,
        .get_charset = &get_charset,
        .get_crossOrigin = &get_crossOrigin,
        .get_defer = &get_defer,
        .get_event = &get_event,
        .get_fetchPriority = &get_fetchPriority,
        .get_htmlFor = &get_htmlFor,
        .get_integrity = &get_integrity,
        .get_noModule = &get_noModule,
        .get_referrerPolicy = &get_referrerPolicy,
        .get_src = &get_src,
        .get_text = &get_text,
        .get_type = &get_type,

        .set_async = &set_async,
        .set_attributionSrc = &set_attributionSrc,
        .set_charset = &set_charset,
        .set_crossOrigin = &set_crossOrigin,
        .set_defer = &set_defer,
        .set_event = &set_event,
        .set_fetchPriority = &set_fetchPriority,
        .set_htmlFor = &set_htmlFor,
        .set_integrity = &set_integrity,
        .set_noModule = &set_noModule,
        .set_referrerPolicy = &set_referrerPolicy,
        .set_src = &set_src,
        .set_text = &set_text,
        .set_type = &set_type,

        .call_supports = &call_supports,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLScriptElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLScriptElementImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLScriptElementImpl.call_constructor(allocator, ctx);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLScriptElementImpl.get_type(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_type(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLScriptElementImpl.set_type(instance, value);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn get_src(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLScriptElementImpl.get_src(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn set_src(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLScriptElementImpl.set_src(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_noModule(instance: *runtime.Instance) anyerror!bool {
        return try HTMLScriptElementImpl.get_noModule(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_noModule(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLScriptElementImpl.set_noModule(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_async(instance: *runtime.Instance) anyerror!bool {
        return try HTMLScriptElementImpl.get_async(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_async(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLScriptElementImpl.set_async(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_defer(instance: *runtime.Instance) anyerror!bool {
        return try HTMLScriptElementImpl.get_defer(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_defer(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLScriptElementImpl.set_defer(instance, value);
    }

    /// Extended attributes: [SameObject], [PutForwards=value], [Reflect]
    pub fn get_blocking(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_blocking) |cached| {
            return cached;
        }
        const value = try HTMLScriptElementImpl.get_blocking(instance);
        state.own.cached_blocking = value;
        return value;
    }

    /// Extended attributes: [CEReactions]
    pub fn get_crossOrigin(instance: *runtime.Instance) anyerror!?DOMString {
        return try HTMLScriptElementImpl.get_crossOrigin(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_crossOrigin(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLScriptElementImpl.set_crossOrigin(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_referrerPolicy(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLScriptElementImpl.get_referrerPolicy(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_referrerPolicy(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLScriptElementImpl.set_referrerPolicy(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_integrity(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLScriptElementImpl.get_integrity(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_integrity(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLScriptElementImpl.set_integrity(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_fetchPriority(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLScriptElementImpl.get_fetchPriority(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_fetchPriority(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLScriptElementImpl.set_fetchPriority(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_text(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLScriptElementImpl.get_text(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_text(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLScriptElementImpl.set_text(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_charset(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLScriptElementImpl.get_charset(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_charset(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLScriptElementImpl.set_charset(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_event(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLScriptElementImpl.get_event(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_event(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLScriptElementImpl.set_event(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="for"]
    pub fn get_htmlFor(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLScriptElementImpl.get_htmlFor(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="for"]
    pub fn set_htmlFor(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLScriptElementImpl.set_htmlFor(instance, value);
    }

    /// Extended attributes: [CEReactions], [SecureContext]
    pub fn get_attributionSrc(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLScriptElementImpl.get_attributionSrc(instance);
    }

    /// Extended attributes: [CEReactions], [SecureContext]
    pub fn set_attributionSrc(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLScriptElementImpl.set_attributionSrc(instance, value);
    }

    pub fn call_supports(instance: *runtime.Instance, @"type": DOMString) anyerror!bool {
        
        return try HTMLScriptElementImpl.call_supports(instance, @"type");
    }

};
