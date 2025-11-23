//! Generated from: SVG.idl
//! Generated at: 2025-11-23T16:59:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGRectElementImpl = @import("impls").SVGRectElement;
const SVGGeometryElement = @import("interfaces").SVGGeometryElement;
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
const DOMMatrix = @import("interfaces").DOMMatrix;
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
const SVGBoundingBoxOptions = @import("dictionaries").SVGBoundingBoxOptions;
const SVGAnimatedTransformList = @import("interfaces").SVGAnimatedTransformList;
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
const SVGAnimatedNumber = @import("interfaces").SVGAnimatedNumber;
const StylePropertyMapReadOnly = @import("interfaces").StylePropertyMapReadOnly;
const DOMTokenList = @import("interfaces").DOMTokenList;
const StartViewTransitionOptions = @import("dictionaries").StartViewTransitionOptions;
const KeyframeAnimationOptions = @import("dictionaries").KeyframeAnimationOptions;
const DOMRect = @import("interfaces").DOMRect;
const ViewTransition = @import("interfaces").ViewTransition;
const SpatialNavigationSearchOptions = @import("dictionaries").SpatialNavigationSearchOptions;
const GetAnimationsOptions = @import("dictionaries").GetAnimationsOptions;
const EventHandler = @import("typedefs").EventHandler;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const SVGAnimatedString = @import("interfaces").SVGAnimatedString;
const SVGAnimatedLength = @import("interfaces").SVGAnimatedLength;
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
const SVGElement = @import("interfaces").SVGElement;

pub const SVGRectElement = struct {
    pub const Meta = struct {
        pub const name = "SVGRectElement";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *SVGGeometryElement;
        pub const MixinTypes = &.{};
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
            .{ "rx", "get_rx", null },
            .{ "ry", "get_ry", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
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
            "focus",
            "blur",
            "getBBox",
            "getCTM",
            "getScreenCTM",
            "isPointInFill",
            "isPointInStroke",
            "getTotalLength",
            "getPointAtLength",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "x", "get_x", null },
            .{ "y", "get_y", null },
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "rx", "get_rx", null },
            .{ "ry", "get_ry", null },
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
            x: SVGAnimatedLength = undefined,
            y: SVGAnimatedLength = undefined,
            width: SVGAnimatedLength = undefined,
            height: SVGAnimatedLength = undefined,
            rx: SVGAnimatedLength = undefined,
            ry: SVGAnimatedLength = undefined,
            cached_x: ?SVGAnimatedLength = null,
            cached_y: ?SVGAnimatedLength = null,
            cached_width: ?SVGAnimatedLength = null,
            cached_height: ?SVGAnimatedLength = null,
            cached_rx: ?SVGAnimatedLength = null,
            cached_ry: ?SVGAnimatedLength = null,
            _internal: ?*SVGRectElementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_height = &get_height,
        .get_rx = &get_rx,
        .get_ry = &get_ry,
        .get_width = &get_width,
        .get_x = &get_x,
        .get_y = &get_y,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SVGRectElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGRectElementImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_x(instance: *runtime.Instance) anyerror!SVGAnimatedLength {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_x) |cached| {
            return cached;
        }
        const value = try SVGRectElementImpl.get_x(instance);
        state.own.cached_x = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_y(instance: *runtime.Instance) anyerror!SVGAnimatedLength {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_y) |cached| {
            return cached;
        }
        const value = try SVGRectElementImpl.get_y(instance);
        state.own.cached_y = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_width(instance: *runtime.Instance) anyerror!SVGAnimatedLength {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_width) |cached| {
            return cached;
        }
        const value = try SVGRectElementImpl.get_width(instance);
        state.own.cached_width = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_height(instance: *runtime.Instance) anyerror!SVGAnimatedLength {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_height) |cached| {
            return cached;
        }
        const value = try SVGRectElementImpl.get_height(instance);
        state.own.cached_height = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_rx(instance: *runtime.Instance) anyerror!SVGAnimatedLength {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_rx) |cached| {
            return cached;
        }
        const value = try SVGRectElementImpl.get_rx(instance);
        state.own.cached_rx = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_ry(instance: *runtime.Instance) anyerror!SVGAnimatedLength {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_ry) |cached| {
            return cached;
        }
        const value = try SVGRectElementImpl.get_ry(instance);
        state.own.cached_ry = value;
        return value;
    }

};
