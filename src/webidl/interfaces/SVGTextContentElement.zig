//! Generated from: SVG.idl
//! Generated at: 2025-11-25T19:42:23Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGTextContentElementImpl = @import("impls").SVGTextContentElement;
const SVGGraphicsElement = @import("interfaces").SVGGraphicsElement;
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

pub const SVGTextContentElement = struct {
    pub const Meta = struct {
        pub const name = "SVGTextContentElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *SVGGraphicsElement;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "textLength", "get_textLength", null },
            .{ "lengthAdjust", "get_lengthAdjust", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getNumberOfChars", "call_getNumberOfChars", 0 },
            .{ "getComputedTextLength", "call_getComputedTextLength", 0 },
            .{ "getSubStringLength", "call_getSubStringLength", 2 },
            .{ "getStartPositionOfChar", "call_getStartPositionOfChar", 1 },
            .{ "getEndPositionOfChar", "call_getEndPositionOfChar", 1 },
            .{ "getExtentOfChar", "call_getExtentOfChar", 1 },
            .{ "getRotationOfChar", "call_getRotationOfChar", 1 },
            .{ "getCharNumAtPosition", "call_getCharNumAtPosition", 0 },
            .{ "selectSubString", "call_selectSubString", 2 },
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "LENGTHADJUST_UNKNOWN", "get_LENGTHADJUST_UNKNOWN" },
            .{ "LENGTHADJUST_SPACING", "get_LENGTHADJUST_SPACING" },
            .{ "LENGTHADJUST_SPACINGANDGLYPHS", "get_LENGTHADJUST_SPACINGANDGLYPHS" },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
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
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "textLength", "get_textLength", null },
            .{ "lengthAdjust", "get_lengthAdjust", null },
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
            textLength: *runtime.Instance = undefined,
            lengthAdjust: *runtime.Instance = undefined,
            cached_textLength: ?*runtime.Instance = null,
            cached_lengthAdjust: ?*runtime.Instance = null,
            _internal: ?*SVGTextContentElementImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short LENGTHADJUST_UNKNOWN = 0;
    pub fn get_LENGTHADJUST_UNKNOWN() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short LENGTHADJUST_SPACING = 1;
    pub fn get_LENGTHADJUST_SPACING() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short LENGTHADJUST_SPACINGANDGLYPHS = 2;
    pub fn get_LENGTHADJUST_SPACINGANDGLYPHS() u16 {
        return 2;
    }

    const delegates = .{

        .get_LENGTHADJUST_SPACING = &get_LENGTHADJUST_SPACING,
        .get_LENGTHADJUST_SPACINGANDGLYPHS = &get_LENGTHADJUST_SPACINGANDGLYPHS,
        .get_LENGTHADJUST_UNKNOWN = &get_LENGTHADJUST_UNKNOWN,
        .get_lengthAdjust = &get_lengthAdjust,
        .get_textLength = &get_textLength,

        .call_getCharNumAtPosition = &call_getCharNumAtPosition,
        .call_getComputedTextLength = &call_getComputedTextLength,
        .call_getEndPositionOfChar = &call_getEndPositionOfChar,
        .call_getExtentOfChar = &call_getExtentOfChar,
        .call_getNumberOfChars = &call_getNumberOfChars,
        .call_getRotationOfChar = &call_getRotationOfChar,
        .call_getStartPositionOfChar = &call_getStartPositionOfChar,
        .call_getSubStringLength = &call_getSubStringLength,
        .call_selectSubString = &call_selectSubString,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SVGTextContentElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGTextContentElementImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_textLength(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_textLength) |cached| {
            return cached;
        }
        const value = try SVGTextContentElementImpl.get_textLength(instance);
        state.own.cached_textLength = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_lengthAdjust(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_lengthAdjust) |cached| {
            return cached;
        }
        const value = try SVGTextContentElementImpl.get_lengthAdjust(instance);
        state.own.cached_lengthAdjust = value;
        return value;
    }

    pub fn call_selectSubString(instance: *runtime.Instance, charnum: u32, nchars: u32) anyerror!void {
        
        return try SVGTextContentElementImpl.call_selectSubString(instance, charnum, nchars);
    }

    pub fn call_getExtentOfChar(instance: *runtime.Instance, charnum: u32) anyerror!*runtime.Instance {
        
        return try SVGTextContentElementImpl.call_getExtentOfChar(instance, charnum);
    }

    pub fn call_getNumberOfChars(instance: *runtime.Instance) anyerror!i32 {
        return try SVGTextContentElementImpl.call_getNumberOfChars(instance);
    }

    pub fn call_getStartPositionOfChar(instance: *runtime.Instance, charnum: u32) anyerror!*runtime.Instance {
        
        return try SVGTextContentElementImpl.call_getStartPositionOfChar(instance, charnum);
    }

    pub fn call_getEndPositionOfChar(instance: *runtime.Instance, charnum: u32) anyerror!*runtime.Instance {
        
        return try SVGTextContentElementImpl.call_getEndPositionOfChar(instance, charnum);
    }

    pub fn call_getRotationOfChar(instance: *runtime.Instance, charnum: u32) anyerror!f32 {
        
        return try SVGTextContentElementImpl.call_getRotationOfChar(instance, charnum);
    }

    pub fn call_getComputedTextLength(instance: *runtime.Instance) anyerror!f32 {
        return try SVGTextContentElementImpl.call_getComputedTextLength(instance);
    }

    pub fn call_getCharNumAtPosition(instance: *runtime.Instance, point: DOMPointInit) anyerror!i32 {
        
        return try SVGTextContentElementImpl.call_getCharNumAtPosition(instance, point);
    }

    pub fn call_getSubStringLength(instance: *runtime.Instance, charnum: u32, nchars: u32) anyerror!f32 {
        
        return try SVGTextContentElementImpl.call_getSubStringLength(instance, charnum, nchars);
    }

};
