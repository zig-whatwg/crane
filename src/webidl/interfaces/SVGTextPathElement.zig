//! Generated from: SVG.idl
//! Generated at: 2025-11-23T16:59:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGTextPathElementImpl = @import("impls").SVGTextPathElement;
const SVGTextContentElement = @import("interfaces").SVGTextContentElement;
const SVGURIReference = @import("interfaces").SVGURIReference;
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
const KeyframeAnimationOptions = @import("dictionaries").KeyframeAnimationOptions;
const SVGAnimatedEnumeration = @import("interfaces").SVGAnimatedEnumeration;
const StylePropertyMapReadOnly = @import("interfaces").StylePropertyMapReadOnly;
const DOMTokenList = @import("interfaces").DOMTokenList;
const StartViewTransitionOptions = @import("dictionaries").StartViewTransitionOptions;
const DOMRect = @import("interfaces").DOMRect;
const ViewTransition = @import("interfaces").ViewTransition;
const SpatialNavigationSearchOptions = @import("dictionaries").SpatialNavigationSearchOptions;
const GetAnimationsOptions = @import("dictionaries").GetAnimationsOptions;
const SVGAnimatedString = @import("interfaces").SVGAnimatedString;
const EventHandler = @import("typedefs").EventHandler;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;
const SVGAnimatedLength = @import("interfaces").SVGAnimatedLength;
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
const SVGSVGElement = @import("interfaces").SVGSVGElement;
const SVGElement = @import("interfaces").SVGElement;

pub const SVGTextPathElement = struct {
    pub const Meta = struct {
        pub const name = "SVGTextPathElement";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *SVGTextContentElement;
        pub const MixinTypes = &.{
            SVGURIReference,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "startOffset", "get_startOffset", null },
            .{ "method", "get_method", null },
            .{ "spacing", "get_spacing", null },
            .{ "href", "get_href", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "TEXTPATH_METHODTYPE_UNKNOWN", "get_TEXTPATH_METHODTYPE_UNKNOWN" },
            .{ "TEXTPATH_METHODTYPE_ALIGN", "get_TEXTPATH_METHODTYPE_ALIGN" },
            .{ "TEXTPATH_METHODTYPE_STRETCH", "get_TEXTPATH_METHODTYPE_STRETCH" },
            .{ "TEXTPATH_SPACINGTYPE_UNKNOWN", "get_TEXTPATH_SPACINGTYPE_UNKNOWN" },
            .{ "TEXTPATH_SPACINGTYPE_AUTO", "get_TEXTPATH_SPACINGTYPE_AUTO" },
            .{ "TEXTPATH_SPACINGTYPE_EXACT", "get_TEXTPATH_SPACINGTYPE_EXACT" },
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
            "getNumberOfChars",
            "getComputedTextLength",
            "getSubStringLength",
            "getStartPositionOfChar",
            "getEndPositionOfChar",
            "getExtentOfChar",
            "getRotationOfChar",
            "getCharNumAtPosition",
            "selectSubString",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "startOffset", "get_startOffset", null },
            .{ "method", "get_method", null },
            .{ "spacing", "get_spacing", null },
            .{ "href", "get_href", null },
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
            startOffset: SVGAnimatedLength = undefined,
            method: SVGAnimatedEnumeration = undefined,
            spacing: SVGAnimatedEnumeration = undefined,
            href: SVGAnimatedString = undefined,
            cached_startOffset: ?SVGAnimatedLength = null,
            cached_method: ?SVGAnimatedEnumeration = null,
            cached_spacing: ?SVGAnimatedEnumeration = null,
            cached_href: ?SVGAnimatedString = null,
            _internal: ?*SVGTextPathElementImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short TEXTPATH_METHODTYPE_UNKNOWN = 0;
    pub fn get_TEXTPATH_METHODTYPE_UNKNOWN() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short TEXTPATH_METHODTYPE_ALIGN = 1;
    pub fn get_TEXTPATH_METHODTYPE_ALIGN() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short TEXTPATH_METHODTYPE_STRETCH = 2;
    pub fn get_TEXTPATH_METHODTYPE_STRETCH() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short TEXTPATH_SPACINGTYPE_UNKNOWN = 0;
    pub fn get_TEXTPATH_SPACINGTYPE_UNKNOWN() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short TEXTPATH_SPACINGTYPE_AUTO = 1;
    pub fn get_TEXTPATH_SPACINGTYPE_AUTO() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short TEXTPATH_SPACINGTYPE_EXACT = 2;
    pub fn get_TEXTPATH_SPACINGTYPE_EXACT() u16 {
        return 2;
    }

    const delegates = .{

        .get_TEXTPATH_METHODTYPE_ALIGN = &get_TEXTPATH_METHODTYPE_ALIGN,
        .get_TEXTPATH_METHODTYPE_STRETCH = &get_TEXTPATH_METHODTYPE_STRETCH,
        .get_TEXTPATH_METHODTYPE_UNKNOWN = &get_TEXTPATH_METHODTYPE_UNKNOWN,
        .get_TEXTPATH_SPACINGTYPE_AUTO = &get_TEXTPATH_SPACINGTYPE_AUTO,
        .get_TEXTPATH_SPACINGTYPE_EXACT = &get_TEXTPATH_SPACINGTYPE_EXACT,
        .get_TEXTPATH_SPACINGTYPE_UNKNOWN = &get_TEXTPATH_SPACINGTYPE_UNKNOWN,
        .get_href = &get_href,
        .get_method = &get_method,
        .get_spacing = &get_spacing,
        .get_startOffset = &get_startOffset,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SVGTextPathElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGTextPathElementImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_startOffset(instance: *runtime.Instance) anyerror!SVGAnimatedLength {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_startOffset) |cached| {
            return cached;
        }
        const value = try SVGTextPathElementImpl.get_startOffset(instance);
        state.own.cached_startOffset = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_method(instance: *runtime.Instance) anyerror!SVGAnimatedEnumeration {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_method) |cached| {
            return cached;
        }
        const value = try SVGTextPathElementImpl.get_method(instance);
        state.own.cached_method = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_spacing(instance: *runtime.Instance) anyerror!SVGAnimatedEnumeration {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_spacing) |cached| {
            return cached;
        }
        const value = try SVGTextPathElementImpl.get_spacing(instance);
        state.own.cached_spacing = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_href(instance: *runtime.Instance) anyerror!SVGAnimatedString {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_href) |cached| {
            return cached;
        }
        const value = try SVGTextPathElementImpl.get_href(instance);
        state.own.cached_href = value;
        return value;
    }

};
