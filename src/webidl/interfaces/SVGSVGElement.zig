//! Generated from: SVG.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGSVGElementImpl = @import("impls").SVGSVGElement;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const SVGGraphicsElement = @import("SVGGraphicsElement.zig").SVGGraphicsElement;
const SVGFitToViewBox = @import("mixins").SVGFitToViewBox;
const WindowEventHandlers = @import("mixins").WindowEventHandlers;
const DOMStringMap = @import("DOMStringMap.zig").DOMStringMap;
const CSSOMString = @import("typedefs").CSSOMString;
const HTMLCollection = @import("HTMLCollection.zig").HTMLCollection;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const GeometryNode = @import("typedefs").GeometryNode;
const NamedNodeMap = @import("NamedNodeMap.zig").NamedNodeMap;
const CSSStyleDeclaration = @import("CSSStyleDeclaration.zig").CSSStyleDeclaration;
const USVString = @import("typedefs").USVString;
const TrustedType = @import("typedefs").TrustedType;
const Element = @import("Element.zig").Element;
const CheckVisibilityOptions = @import("dictionaries").CheckVisibilityOptions;
const ScrollIntoViewOptions = @import("dictionaries").ScrollIntoViewOptions;
const DOMMatrix = @import("DOMMatrix.zig").DOMMatrix;
const BoxQuadOptions = @import("dictionaries").BoxQuadOptions;
const SVGLength = @import("SVGLength.zig").SVGLength;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const FocusableAreasOption = @import("dictionaries").FocusableAreasOption;
const EventListener = @import("EventListener.zig").EventListener;
const CSSStyleProperties = @import("CSSStyleProperties.zig").CSSStyleProperties;
const CSSPseudoElement = @import("CSSPseudoElement.zig").CSSPseudoElement;
const SVGStringList = @import("SVGStringList.zig").SVGStringList;
const SVGAngle = @import("SVGAngle.zig").SVGAngle;
const ViewTransitionUpdateCallback = @import("callbacks").ViewTransitionUpdateCallback;
const Node = @import("Node.zig").Node;
const CustomElementRegistry = @import("CustomElementRegistry.zig").CustomElementRegistry;
const SVGNumber = @import("SVGNumber.zig").SVGNumber;
const Animation = @import("Animation.zig").Animation;
const Range = @import("Range.zig").Range;
const Event = @import("Event.zig").Event;
const SVGAnimatedRect = @import("SVGAnimatedRect.zig").SVGAnimatedRect;
const FocusOptions = @import("dictionaries").FocusOptions;
const SVGBoundingBoxOptions = @import("dictionaries").SVGBoundingBoxOptions;
const SVGTransform = @import("SVGTransform.zig").SVGTransform;
const SVGAnimatedTransformList = @import("SVGAnimatedTransformList.zig").SVGAnimatedTransformList;
const DOMString = @import("typedefs").DOMString;
const KeyframeAnimationOptions = @import("dictionaries").KeyframeAnimationOptions;
const Document = @import("Document.zig").Document;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const DOMMatrix2DInit = @import("dictionaries").DOMMatrix2DInit;
const DOMRectList = @import("DOMRectList.zig").DOMRectList;
const DOMRectReadOnly = @import("DOMRectReadOnly.zig").DOMRectReadOnly;
const ScrollToOptions = @import("dictionaries").ScrollToOptions;
const HTMLSlotElement = @import("HTMLSlotElement.zig").HTMLSlotElement;
const DOMQuad = @import("DOMQuad.zig").DOMQuad;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const SVGUseElement = @import("SVGUseElement.zig").SVGUseElement;
const StylePropertyMapReadOnly = @import("StylePropertyMapReadOnly.zig").StylePropertyMapReadOnly;
const DOMTokenList = @import("DOMTokenList.zig").DOMTokenList;
const DOMPointReadOnly = @import("DOMPointReadOnly.zig").DOMPointReadOnly;
const StartViewTransitionOptions = @import("dictionaries").StartViewTransitionOptions;
const DOMRect = @import("DOMRect.zig").DOMRect;
const ViewTransition = @import("ViewTransition.zig").ViewTransition;
const SpatialNavigationSearchOptions = @import("dictionaries").SpatialNavigationSearchOptions;
const EventHandler = @import("typedefs").EventHandler;
const GetAnimationsOptions = @import("dictionaries").GetAnimationsOptions;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;
const OnBeforeUnloadEventHandler = @import("typedefs").OnBeforeUnloadEventHandler;
const SVGAnimatedLength = @import("SVGAnimatedLength.zig").SVGAnimatedLength;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const SVGAnimatedString = @import("SVGAnimatedString.zig").SVGAnimatedString;
const SVGAnimatedPreserveAspectRatio = @import("SVGAnimatedPreserveAspectRatio.zig").SVGAnimatedPreserveAspectRatio;
const SpatialNavigationDirection = @import("enums").SpatialNavigationDirection;
const StylePropertyMap = @import("StylePropertyMap.zig").StylePropertyMap;
const ShadowRoot = @import("ShadowRoot.zig").ShadowRoot;
const Attr = @import("Attr.zig").Attr;
const TrustedHTML = @import("TrustedHTML.zig").TrustedHTML;
const NodeList = @import("NodeList.zig").NodeList;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const FullscreenOptions = @import("dictionaries").FullscreenOptions;
const Observable = @import("Observable.zig").Observable;
const DOMPoint = @import("DOMPoint.zig").DOMPoint;
const PointerLockOptions = @import("dictionaries").PointerLockOptions;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const ShadowRootInit = @import("dictionaries").ShadowRootInit;
const SVGElement = @import("SVGElement.zig").SVGElement;

pub const SVGSVGElement = struct {
    pub const Meta = struct {
        pub const name = "SVGSVGElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = SVGGraphicsElement.State;
        pub const ParentInterface = SVGGraphicsElement;
        pub const MixinTypes = &.{
            SVGFitToViewBox,
            WindowEventHandlers,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "x", "get_x", null },
            .{ "y", "get_y", null },
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "currentScale", "get_currentScale", "set_currentScale" },
            .{ "currentTranslate", "get_currentTranslate", null },
            .{ "viewBox", "get_viewBox", null },
            .{ "preserveAspectRatio", "get_preserveAspectRatio", null },
            .{ "onafterprint", "get_onafterprint", "set_onafterprint" },
            .{ "onbeforeprint", "get_onbeforeprint", "set_onbeforeprint" },
            .{ "onbeforeunload", "get_onbeforeunload", "set_onbeforeunload" },
            .{ "onhashchange", "get_onhashchange", "set_onhashchange" },
            .{ "onlanguagechange", "get_onlanguagechange", "set_onlanguagechange" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onmessageerror", "get_onmessageerror", "set_onmessageerror" },
            .{ "onoffline", "get_onoffline", "set_onoffline" },
            .{ "ononline", "get_ononline", "set_ononline" },
            .{ "onpagehide", "get_onpagehide", "set_onpagehide" },
            .{ "onpagereveal", "get_onpagereveal", "set_onpagereveal" },
            .{ "onpageshow", "get_onpageshow", "set_onpageshow" },
            .{ "onpageswap", "get_onpageswap", "set_onpageswap" },
            .{ "onpopstate", "get_onpopstate", "set_onpopstate" },
            .{ "onrejectionhandled", "get_onrejectionhandled", "set_onrejectionhandled" },
            .{ "onstorage", "get_onstorage", "set_onstorage" },
            .{ "onunhandledrejection", "get_onunhandledrejection", "set_onunhandledrejection" },
            .{ "onunload", "get_onunload", "set_onunload" },
            .{ "ongamepadconnected", "get_ongamepadconnected", "set_ongamepadconnected" },
            .{ "ongamepaddisconnected", "get_ongamepaddisconnected", "set_ongamepaddisconnected" },
            .{ "onportalactivate", "get_onportalactivate", "set_onportalactivate" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getIntersectionList", "call_getIntersectionList", 2 },
            .{ "getEnclosureList", "call_getEnclosureList", 2 },
            .{ "checkIntersection", "call_checkIntersection", 2 },
            .{ "checkEnclosure", "call_checkEnclosure", 2 },
            .{ "deselectAll", "call_deselectAll", 0 },
            .{ "createSVGNumber", "call_createSVGNumber", 0 },
            .{ "createSVGLength", "call_createSVGLength", 0 },
            .{ "createSVGAngle", "call_createSVGAngle", 0 },
            .{ "createSVGPoint", "call_createSVGPoint", 0 },
            .{ "createSVGMatrix", "call_createSVGMatrix", 0 },
            .{ "createSVGRect", "call_createSVGRect", 0 },
            .{ "createSVGTransform", "call_createSVGTransform", 0 },
            .{ "createSVGTransformFromMatrix", "call_createSVGTransformFromMatrix", 0 },
            .{ "getElementById", "call_getElementById", 1 },
            .{ "suspendRedraw", "call_suspendRedraw", 1 },
            .{ "unsuspendRedraw", "call_unsuspendRedraw", 1 },
            .{ "unsuspendRedrawAll", "call_unsuspendRedrawAll", 0 },
            .{ "forceRedraw", "call_forceRedraw", 0 },
            .{ "pauseAnimations", "call_pauseAnimations", 0 },
            .{ "unpauseAnimations", "call_unpauseAnimations", 0 },
            .{ "animationsPaused", "call_animationsPaused", 0 },
            .{ "getCurrentTime", "call_getCurrentTime", 0 },
            .{ "setCurrentTime", "call_setCurrentTime", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getIntersectionList",
            "getEnclosureList",
            "checkIntersection",
            "checkEnclosure",
            "deselectAll",
            "createSVGNumber",
            "createSVGLength",
            "createSVGAngle",
            "createSVGPoint",
            "createSVGMatrix",
            "createSVGRect",
            "createSVGTransform",
            "createSVGTransformFromMatrix",
            "getElementById",
            "suspendRedraw",
            "unsuspendRedraw",
            "unsuspendRedrawAll",
            "forceRedraw",
            "pauseAnimations",
            "unpauseAnimations",
            "animationsPaused",
            "getCurrentTime",
            "setCurrentTime",
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
            "scrollTo",
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
            "getBBox",
            "getCTM",
            "getScreenCTM",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "x", "get_x", null },
            .{ "y", "get_y", null },
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "currentScale", "get_currentScale", "set_currentScale" },
            .{ "currentTranslate", "get_currentTranslate", null },
            .{ "viewBox", "get_viewBox", null },
            .{ "preserveAspectRatio", "get_preserveAspectRatio", null },
            .{ "onafterprint", "get_onafterprint", "set_onafterprint" },
            .{ "onbeforeprint", "get_onbeforeprint", "set_onbeforeprint" },
            .{ "onbeforeunload", "get_onbeforeunload", "set_onbeforeunload" },
            .{ "onhashchange", "get_onhashchange", "set_onhashchange" },
            .{ "onlanguagechange", "get_onlanguagechange", "set_onlanguagechange" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onmessageerror", "get_onmessageerror", "set_onmessageerror" },
            .{ "onoffline", "get_onoffline", "set_onoffline" },
            .{ "ononline", "get_ononline", "set_ononline" },
            .{ "onpagehide", "get_onpagehide", "set_onpagehide" },
            .{ "onpagereveal", "get_onpagereveal", "set_onpagereveal" },
            .{ "onpageshow", "get_onpageshow", "set_onpageshow" },
            .{ "onpageswap", "get_onpageswap", "set_onpageswap" },
            .{ "onpopstate", "get_onpopstate", "set_onpopstate" },
            .{ "onrejectionhandled", "get_onrejectionhandled", "set_onrejectionhandled" },
            .{ "onstorage", "get_onstorage", "set_onstorage" },
            .{ "onunhandledrejection", "get_onunhandledrejection", "set_onunhandledrejection" },
            .{ "onunload", "get_onunload", "set_onunload" },
            .{ "ongamepadconnected", "get_ongamepadconnected", "set_ongamepadconnected" },
            .{ "ongamepaddisconnected", "get_ongamepaddisconnected", "set_ongamepaddisconnected" },
            .{ "onportalactivate", "get_onportalactivate", "set_onportalactivate" },
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
            x: *runtime.Instance = undefined,
            y: *runtime.Instance = undefined,
            width: *runtime.Instance = undefined,
            height: *runtime.Instance = undefined,
            currentScale: f32 = undefined,
            currentTranslate: *runtime.Instance = undefined,
            viewBox: *runtime.Instance = undefined,
            preserveAspectRatio: *runtime.Instance = undefined,
            onafterprint: typedefs.EventHandler = undefined,
            onbeforeprint: typedefs.EventHandler = undefined,
            onbeforeunload: typedefs.OnBeforeUnloadEventHandler = undefined,
            onhashchange: typedefs.EventHandler = undefined,
            onlanguagechange: typedefs.EventHandler = undefined,
            onmessage: typedefs.EventHandler = undefined,
            onmessageerror: typedefs.EventHandler = undefined,
            onoffline: typedefs.EventHandler = undefined,
            ononline: typedefs.EventHandler = undefined,
            onpagehide: typedefs.EventHandler = undefined,
            onpagereveal: typedefs.EventHandler = undefined,
            onpageshow: typedefs.EventHandler = undefined,
            onpageswap: typedefs.EventHandler = undefined,
            onpopstate: typedefs.EventHandler = undefined,
            onrejectionhandled: typedefs.EventHandler = undefined,
            onstorage: typedefs.EventHandler = undefined,
            onunhandledrejection: typedefs.EventHandler = undefined,
            onunload: typedefs.EventHandler = undefined,
            ongamepadconnected: typedefs.EventHandler = undefined,
            ongamepaddisconnected: typedefs.EventHandler = undefined,
            onportalactivate: typedefs.EventHandler = undefined,
            cached_x: ?*runtime.Instance = null,
            cached_y: ?*runtime.Instance = null,
            cached_width: ?*runtime.Instance = null,
            cached_height: ?*runtime.Instance = null,
            cached_currentTranslate: ?*runtime.Instance = null,
            cached_viewBox: ?*runtime.Instance = null,
            cached_preserveAspectRatio: ?*runtime.Instance = null,
            _internal: ?*SVGSVGElementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_currentScale = &get_currentScale,
        .get_currentTranslate = &get_currentTranslate,
        .get_height = &get_height,
        .get_onafterprint = &get_onafterprint,
        .get_onbeforeprint = &get_onbeforeprint,
        .get_onbeforeunload = &get_onbeforeunload,
        .get_ongamepadconnected = &get_ongamepadconnected,
        .get_ongamepaddisconnected = &get_ongamepaddisconnected,
        .get_onhashchange = &get_onhashchange,
        .get_onlanguagechange = &get_onlanguagechange,
        .get_onmessage = &get_onmessage,
        .get_onmessageerror = &get_onmessageerror,
        .get_onoffline = &get_onoffline,
        .get_ononline = &get_ononline,
        .get_onpagehide = &get_onpagehide,
        .get_onpagereveal = &get_onpagereveal,
        .get_onpageshow = &get_onpageshow,
        .get_onpageswap = &get_onpageswap,
        .get_onpopstate = &get_onpopstate,
        .get_onportalactivate = &get_onportalactivate,
        .get_onrejectionhandled = &get_onrejectionhandled,
        .get_onstorage = &get_onstorage,
        .get_onunhandledrejection = &get_onunhandledrejection,
        .get_onunload = &get_onunload,
        .get_preserveAspectRatio = &get_preserveAspectRatio,
        .get_viewBox = &get_viewBox,
        .get_width = &get_width,
        .get_x = &get_x,
        .get_y = &get_y,

        .set_currentScale = &set_currentScale,
        .set_onafterprint = &set_onafterprint,
        .set_onbeforeprint = &set_onbeforeprint,
        .set_onbeforeunload = &set_onbeforeunload,
        .set_ongamepadconnected = &set_ongamepadconnected,
        .set_ongamepaddisconnected = &set_ongamepaddisconnected,
        .set_onhashchange = &set_onhashchange,
        .set_onlanguagechange = &set_onlanguagechange,
        .set_onmessage = &set_onmessage,
        .set_onmessageerror = &set_onmessageerror,
        .set_onoffline = &set_onoffline,
        .set_ononline = &set_ononline,
        .set_onpagehide = &set_onpagehide,
        .set_onpagereveal = &set_onpagereveal,
        .set_onpageshow = &set_onpageshow,
        .set_onpageswap = &set_onpageswap,
        .set_onpopstate = &set_onpopstate,
        .set_onportalactivate = &set_onportalactivate,
        .set_onrejectionhandled = &set_onrejectionhandled,
        .set_onstorage = &set_onstorage,
        .set_onunhandledrejection = &set_onunhandledrejection,
        .set_onunload = &set_onunload,

        .call_animationsPaused = &call_animationsPaused,
        .call_checkEnclosure = &call_checkEnclosure,
        .call_checkIntersection = &call_checkIntersection,
        .call_createSVGAngle = &call_createSVGAngle,
        .call_createSVGLength = &call_createSVGLength,
        .call_createSVGMatrix = &call_createSVGMatrix,
        .call_createSVGNumber = &call_createSVGNumber,
        .call_createSVGPoint = &call_createSVGPoint,
        .call_createSVGRect = &call_createSVGRect,
        .call_createSVGTransform = &call_createSVGTransform,
        .call_createSVGTransformFromMatrix = &call_createSVGTransformFromMatrix,
        .call_deselectAll = &call_deselectAll,
        .call_forceRedraw = &call_forceRedraw,
        .call_getCurrentTime = &call_getCurrentTime,
        .call_getElementById = &call_getElementById,
        .call_getEnclosureList = &call_getEnclosureList,
        .call_getIntersectionList = &call_getIntersectionList,
        .call_pauseAnimations = &call_pauseAnimations,
        .call_setCurrentTime = &call_setCurrentTime,
        .call_suspendRedraw = &call_suspendRedraw,
        .call_unpauseAnimations = &call_unpauseAnimations,
        .call_unsuspendRedraw = &call_unsuspendRedraw,
        .call_unsuspendRedrawAll = &call_unsuspendRedrawAll,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SVGSVGElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return SVGSVGElementImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGSVGElementImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_x(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_x) |cached| {
            return cached;
        }
        const value = try SVGSVGElementImpl.get_x(instance);
        state.own.cached_x = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_y(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_y) |cached| {
            return cached;
        }
        const value = try SVGSVGElementImpl.get_y(instance);
        state.own.cached_y = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_width(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_width) |cached| {
            return cached;
        }
        const value = try SVGSVGElementImpl.get_width(instance);
        state.own.cached_width = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_height(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_height) |cached| {
            return cached;
        }
        const value = try SVGSVGElementImpl.get_height(instance);
        state.own.cached_height = value;
        return value;
    }

    pub fn get_currentScale(instance: *runtime.Instance) anyerror!f32 {
        return try SVGSVGElementImpl.get_currentScale(instance);
    }

    pub fn set_currentScale(instance: *runtime.Instance, value: f32) anyerror!void {
        try SVGSVGElementImpl.set_currentScale(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_currentTranslate(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_currentTranslate) |cached| {
            return cached;
        }
        const value = try SVGSVGElementImpl.get_currentTranslate(instance);
        state.own.cached_currentTranslate = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_viewBox(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_viewBox) |cached| {
            return cached;
        }
        const value = try SVGSVGElementImpl.get_viewBox(instance);
        state.own.cached_viewBox = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_preserveAspectRatio(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_preserveAspectRatio) |cached| {
            return cached;
        }
        const value = try SVGSVGElementImpl.get_preserveAspectRatio(instance);
        state.own.cached_preserveAspectRatio = value;
        return value;
    }

    pub fn get_onafterprint(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGSVGElementImpl.get_onafterprint(instance);
    }

    pub fn set_onafterprint(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGSVGElementImpl.set_onafterprint(instance, value);
    }

    pub fn get_onbeforeprint(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGSVGElementImpl.get_onbeforeprint(instance);
    }

    pub fn set_onbeforeprint(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGSVGElementImpl.set_onbeforeprint(instance, value);
    }

    pub fn get_onbeforeunload(instance: *runtime.Instance) anyerror!OnBeforeUnloadEventHandler {
        return try SVGSVGElementImpl.get_onbeforeunload(instance);
    }

    pub fn set_onbeforeunload(instance: *runtime.Instance, value: OnBeforeUnloadEventHandler) anyerror!void {
        try SVGSVGElementImpl.set_onbeforeunload(instance, value);
    }

    pub fn get_onhashchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGSVGElementImpl.get_onhashchange(instance);
    }

    pub fn set_onhashchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGSVGElementImpl.set_onhashchange(instance, value);
    }

    pub fn get_onlanguagechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGSVGElementImpl.get_onlanguagechange(instance);
    }

    pub fn set_onlanguagechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGSVGElementImpl.set_onlanguagechange(instance, value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGSVGElementImpl.get_onmessage(instance);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGSVGElementImpl.set_onmessage(instance, value);
    }

    pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGSVGElementImpl.get_onmessageerror(instance);
    }

    pub fn set_onmessageerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGSVGElementImpl.set_onmessageerror(instance, value);
    }

    pub fn get_onoffline(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGSVGElementImpl.get_onoffline(instance);
    }

    pub fn set_onoffline(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGSVGElementImpl.set_onoffline(instance, value);
    }

    pub fn get_ononline(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGSVGElementImpl.get_ononline(instance);
    }

    pub fn set_ononline(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGSVGElementImpl.set_ononline(instance, value);
    }

    pub fn get_onpagehide(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGSVGElementImpl.get_onpagehide(instance);
    }

    pub fn set_onpagehide(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGSVGElementImpl.set_onpagehide(instance, value);
    }

    pub fn get_onpagereveal(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGSVGElementImpl.get_onpagereveal(instance);
    }

    pub fn set_onpagereveal(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGSVGElementImpl.set_onpagereveal(instance, value);
    }

    pub fn get_onpageshow(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGSVGElementImpl.get_onpageshow(instance);
    }

    pub fn set_onpageshow(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGSVGElementImpl.set_onpageshow(instance, value);
    }

    pub fn get_onpageswap(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGSVGElementImpl.get_onpageswap(instance);
    }

    pub fn set_onpageswap(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGSVGElementImpl.set_onpageswap(instance, value);
    }

    pub fn get_onpopstate(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGSVGElementImpl.get_onpopstate(instance);
    }

    pub fn set_onpopstate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGSVGElementImpl.set_onpopstate(instance, value);
    }

    pub fn get_onrejectionhandled(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGSVGElementImpl.get_onrejectionhandled(instance);
    }

    pub fn set_onrejectionhandled(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGSVGElementImpl.set_onrejectionhandled(instance, value);
    }

    pub fn get_onstorage(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGSVGElementImpl.get_onstorage(instance);
    }

    pub fn set_onstorage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGSVGElementImpl.set_onstorage(instance, value);
    }

    pub fn get_onunhandledrejection(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGSVGElementImpl.get_onunhandledrejection(instance);
    }

    pub fn set_onunhandledrejection(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGSVGElementImpl.set_onunhandledrejection(instance, value);
    }

    pub fn get_onunload(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGSVGElementImpl.get_onunload(instance);
    }

    pub fn set_onunload(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGSVGElementImpl.set_onunload(instance, value);
    }

    pub fn get_ongamepadconnected(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGSVGElementImpl.get_ongamepadconnected(instance);
    }

    pub fn set_ongamepadconnected(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGSVGElementImpl.set_ongamepadconnected(instance, value);
    }

    pub fn get_ongamepaddisconnected(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGSVGElementImpl.get_ongamepaddisconnected(instance);
    }

    pub fn set_ongamepaddisconnected(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGSVGElementImpl.set_ongamepaddisconnected(instance, value);
    }

    pub fn get_onportalactivate(instance: *runtime.Instance) anyerror!EventHandler {
        return try SVGSVGElementImpl.get_onportalactivate(instance);
    }

    pub fn set_onportalactivate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SVGSVGElementImpl.set_onportalactivate(instance, value);
    }

    pub fn call_getEnclosureList(instance: *runtime.Instance, rect: *runtime.Instance, referenceElement: ?*runtime.Instance) anyerror!*runtime.Instance {
        
        return try SVGSVGElementImpl.call_getEnclosureList(instance, rect, referenceElement);
    }

    pub fn call_getElementById(instance: *runtime.Instance, elementId: DOMString) anyerror!?*runtime.Instance {
        
        return try SVGSVGElementImpl.call_getElementById(instance, elementId);
    }

    pub fn call_setCurrentTime(instance: *runtime.Instance, seconds: f32) anyerror!void {
        
        return try SVGSVGElementImpl.call_setCurrentTime(instance, seconds);
    }

    pub fn call_suspendRedraw(instance: *runtime.Instance, maxWaitMilliseconds: u32) anyerror!u32 {
        
        return try SVGSVGElementImpl.call_suspendRedraw(instance, maxWaitMilliseconds);
    }

    pub fn call_checkEnclosure(instance: *runtime.Instance, element: *runtime.Instance, rect: *runtime.Instance) anyerror!bool {
        
        return try SVGSVGElementImpl.call_checkEnclosure(instance, element, rect);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createSVGAngle(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try SVGSVGElementImpl.call_createSVGAngle(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createSVGMatrix(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try SVGSVGElementImpl.call_createSVGMatrix(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createSVGTransformFromMatrix(instance: *runtime.Instance, matrix: webidl.Opt(DOMMatrix2DInit)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try SVGSVGElementImpl.call_createSVGTransformFromMatrix(instance, matrix);
    }

    pub fn call_forceRedraw(instance: *runtime.Instance) anyerror!void {
        return try SVGSVGElementImpl.call_forceRedraw(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createSVGTransform(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try SVGSVGElementImpl.call_createSVGTransform(instance);
    }

    pub fn call_getCurrentTime(instance: *runtime.Instance) anyerror!f32 {
        return try SVGSVGElementImpl.call_getCurrentTime(instance);
    }

    pub fn call_pauseAnimations(instance: *runtime.Instance) anyerror!void {
        return try SVGSVGElementImpl.call_pauseAnimations(instance);
    }

    pub fn call_unsuspendRedraw(instance: *runtime.Instance, suspendHandleID: u32) anyerror!void {
        
        return try SVGSVGElementImpl.call_unsuspendRedraw(instance, suspendHandleID);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createSVGLength(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try SVGSVGElementImpl.call_createSVGLength(instance);
    }

    pub fn call_getIntersectionList(instance: *runtime.Instance, rect: *runtime.Instance, referenceElement: ?*runtime.Instance) anyerror!*runtime.Instance {
        
        return try SVGSVGElementImpl.call_getIntersectionList(instance, rect, referenceElement);
    }

    pub fn call_unsuspendRedrawAll(instance: *runtime.Instance) anyerror!void {
        return try SVGSVGElementImpl.call_unsuspendRedrawAll(instance);
    }

    pub fn call_deselectAll(instance: *runtime.Instance) anyerror!void {
        return try SVGSVGElementImpl.call_deselectAll(instance);
    }

    pub fn call_unpauseAnimations(instance: *runtime.Instance) anyerror!void {
        return try SVGSVGElementImpl.call_unpauseAnimations(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createSVGNumber(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try SVGSVGElementImpl.call_createSVGNumber(instance);
    }

    pub fn call_animationsPaused(instance: *runtime.Instance) anyerror!bool {
        return try SVGSVGElementImpl.call_animationsPaused(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createSVGRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try SVGSVGElementImpl.call_createSVGRect(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_createSVGPoint(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try SVGSVGElementImpl.call_createSVGPoint(instance);
    }

    pub fn call_checkIntersection(instance: *runtime.Instance, element: *runtime.Instance, rect: *runtime.Instance) anyerror!bool {
        
        return try SVGSVGElementImpl.call_checkIntersection(instance, element, rect);
    }

};
