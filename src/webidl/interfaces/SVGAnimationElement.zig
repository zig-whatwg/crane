//! Generated from: svg-animations.idl
//! Generated at: 2025-11-23T20:06:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGAnimationElementImpl = @import("impls").SVGAnimationElement;
const SVGElement = @import("interfaces").SVGElement;
const SVGTests = @import("interfaces").SVGTests;
const DOMStringMap = @import("interfaces").DOMStringMap;
const CSSOMString = @import("typedefs").CSSOMString;
const HTMLCollection = @import("interfaces").HTMLCollection;
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
const SVGStringList = @import("interfaces").SVGStringList;
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
const SVGUseElement = @import("interfaces").SVGUseElement;
const KeyframeAnimationOptions = @import("dictionaries").KeyframeAnimationOptions;
const StylePropertyMapReadOnly = @import("interfaces").StylePropertyMapReadOnly;
const DOMTokenList = @import("interfaces").DOMTokenList;
const StartViewTransitionOptions = @import("dictionaries").StartViewTransitionOptions;
const DOMRect = @import("interfaces").DOMRect;
const ViewTransition = @import("interfaces").ViewTransition;
const SpatialNavigationSearchOptions = @import("dictionaries").SpatialNavigationSearchOptions;
const GetAnimationsOptions = @import("dictionaries").GetAnimationsOptions;
const EventHandler = @import("typedefs").EventHandler;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const SVGAnimatedString = @import("interfaces").SVGAnimatedString;
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
const SVGSVGElement = @import("interfaces").SVGSVGElement;

pub const SVGAnimationElement = struct {
    pub const Meta = struct {
        pub const name = "SVGAnimationElement";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *SVGElement;
        pub const MixinTypes = &.{
            SVGTests,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "targetElement", "get_targetElement", null },
            .{ "onbegin", "get_onbegin", "set_onbegin" },
            .{ "onend", "get_onend", "set_onend" },
            .{ "onrepeat", "get_onrepeat", "set_onrepeat" },
            .{ "requiredExtensions", "get_requiredExtensions", null },
            .{ "systemLanguage", "get_systemLanguage", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "getStartTime", "call_getStartTime", 0 },
            .{ "getCurrentTime", "call_getCurrentTime", 0 },
            .{ "getSimpleDuration", "call_getSimpleDuration", 0 },
            .{ "beginElement", "call_beginElement", 0 },
            .{ "beginElementAt", "call_beginElementAt", 1 },
            .{ "endElement", "call_endElement", 0 },
            .{ "endElementAt", "call_endElementAt", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getStartTime",
            "getCurrentTime",
            "getSimpleDuration",
            "beginElement",
            "beginElementAt",
            "endElement",
            "endElementAt",
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
            "focus",
            "blur",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "targetElement", "get_targetElement", null },
            .{ "onbegin", "get_onbegin", "set_onbegin" },
            .{ "onend", "get_onend", "set_onend" },
            .{ "onrepeat", "get_onrepeat", "set_onrepeat" },
            .{ "requiredExtensions", "get_requiredExtensions", null },
            .{ "systemLanguage", "get_systemLanguage", null },
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
            targetElement: ?*runtime.Instance = null,
            onbegin: EventHandler = undefined,
            onend: EventHandler = undefined,
            onrepeat: EventHandler = undefined,
            requiredExtensions: *runtime.Instance = undefined,
            systemLanguage: *runtime.Instance = undefined,
            cached_requiredExtensions: ?*runtime.Instance = null,
            cached_systemLanguage: ?*runtime.Instance = null,
            _internal: ?*SVGAnimationElementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onbegin = &get_onbegin,
        .get_onend = &get_onend,
        .get_onrepeat = &get_onrepeat,
        .get_requiredExtensions = &get_requiredExtensions,
        .get_systemLanguage = &get_systemLanguage,
        .get_targetElement = &get_targetElement,

        .set_onbegin = &set_onbegin,
        .set_onend = &set_onend,
        .set_onrepeat = &set_onrepeat,

        .call_beginElement = &call_beginElement,
        .call_beginElementAt = &call_beginElementAt,
        .call_endElement = &call_endElement,
        .call_endElementAt = &call_endElementAt,
        .call_getCurrentTime = &call_getCurrentTime,
        .call_getSimpleDuration = &call_getSimpleDuration,
        .call_getStartTime = &call_getStartTime,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SVGAnimationElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGAnimationElementImpl.deinit(instance);
    }

    pub fn get_targetElement(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGAnimationElementImpl.get_targetElement(instance);
    }

    pub fn get_onbegin(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGAnimationElementImpl.get_onbegin(instance);
    }

    pub fn set_onbegin(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGAnimationElementImpl.set_onbegin(instance, value);
    }

    pub fn get_onend(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGAnimationElementImpl.get_onend(instance);
    }

    pub fn set_onend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGAnimationElementImpl.set_onend(instance, value);
    }

    pub fn get_onrepeat(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGAnimationElementImpl.get_onrepeat(instance);
    }

    pub fn set_onrepeat(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGAnimationElementImpl.set_onrepeat(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_requiredExtensions(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_requiredExtensions) |cached| {
            return cached;
        }
        const value = try SVGAnimationElementImpl.get_requiredExtensions(instance);
        state.own.cached_requiredExtensions = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_systemLanguage(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_systemLanguage) |cached| {
            return cached;
        }
        const value = try SVGAnimationElementImpl.get_systemLanguage(instance);
        state.own.cached_systemLanguage = value;
        return value;
    }

    pub fn call_getCurrentTime(instance: *runtime.Instance) anyerror!f32 {
        return try SVGAnimationElementImpl.call_getCurrentTime(instance);
    }

    pub fn call_getStartTime(instance: *runtime.Instance) anyerror!f32 {
        return try SVGAnimationElementImpl.call_getStartTime(instance);
    }

    pub fn call_getSimpleDuration(instance: *runtime.Instance) anyerror!f32 {
        return try SVGAnimationElementImpl.call_getSimpleDuration(instance);
    }

    pub fn call_endElement(instance: *runtime.Instance) anyerror!void {
        return try SVGAnimationElementImpl.call_endElement(instance);
    }

    pub fn call_beginElement(instance: *runtime.Instance) anyerror!void {
        return try SVGAnimationElementImpl.call_beginElement(instance);
    }

    pub fn call_beginElementAt(instance: *runtime.Instance, offset: f32) anyerror!void {
        
        return try SVGAnimationElementImpl.call_beginElementAt(instance, offset);
    }

    pub fn call_endElementAt(instance: *runtime.Instance, offset: f32) anyerror!void {
        
        return try SVGAnimationElementImpl.call_endElementAt(instance, offset);
    }

};
