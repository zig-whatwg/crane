//! Generated from: SVG.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGTextContentElementImpl = @import("impls").SVGTextContentElement;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const SVGGraphicsElement = @import("SVGGraphicsElement.zig").SVGGraphicsElement;
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
const BoxQuadOptions = @import("dictionaries").BoxQuadOptions;
const DOMMatrix = @import("DOMMatrix.zig").DOMMatrix;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const FocusableAreasOption = @import("dictionaries").FocusableAreasOption;
const EventListener = @import("EventListener.zig").EventListener;
const CSSStyleProperties = @import("CSSStyleProperties.zig").CSSStyleProperties;
const CSSPseudoElement = @import("CSSPseudoElement.zig").CSSPseudoElement;
const SVGStringList = @import("SVGStringList.zig").SVGStringList;
const ViewTransitionUpdateCallback = @import("callbacks").ViewTransitionUpdateCallback;
const Node = @import("Node.zig").Node;
const CustomElementRegistry = @import("CustomElementRegistry.zig").CustomElementRegistry;
const Animation = @import("Animation.zig").Animation;
const Range = @import("Range.zig").Range;
const Event = @import("Event.zig").Event;
const FocusOptions = @import("dictionaries").FocusOptions;
const SVGBoundingBoxOptions = @import("dictionaries").SVGBoundingBoxOptions;
const SVGAnimatedTransformList = @import("SVGAnimatedTransformList.zig").SVGAnimatedTransformList;
const DOMRectList = @import("DOMRectList.zig").DOMRectList;
const DOMString = @import("typedefs").DOMString;
const Document = @import("Document.zig").Document;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const ScrollToOptions = @import("dictionaries").ScrollToOptions;
const HTMLSlotElement = @import("HTMLSlotElement.zig").HTMLSlotElement;
const DOMQuad = @import("DOMQuad.zig").DOMQuad;
const DOMRectReadOnly = @import("DOMRectReadOnly.zig").DOMRectReadOnly;
const SVGUseElement = @import("SVGUseElement.zig").SVGUseElement;
const KeyframeAnimationOptions = @import("dictionaries").KeyframeAnimationOptions;
const SVGAnimatedEnumeration = @import("SVGAnimatedEnumeration.zig").SVGAnimatedEnumeration;
const StylePropertyMapReadOnly = @import("StylePropertyMapReadOnly.zig").StylePropertyMapReadOnly;
const DOMTokenList = @import("DOMTokenList.zig").DOMTokenList;
const StartViewTransitionOptions = @import("dictionaries").StartViewTransitionOptions;
const DOMRect = @import("DOMRect.zig").DOMRect;
const ViewTransition = @import("ViewTransition.zig").ViewTransition;
const SpatialNavigationSearchOptions = @import("dictionaries").SpatialNavigationSearchOptions;
const GetAnimationsOptions = @import("dictionaries").GetAnimationsOptions;
const EventHandler = @import("typedefs").EventHandler;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const SVGAnimatedString = @import("SVGAnimatedString.zig").SVGAnimatedString;
const SVGAnimatedLength = @import("SVGAnimatedLength.zig").SVGAnimatedLength;
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
const SVGSVGElement = @import("SVGSVGElement.zig").SVGSVGElement;
const SVGElement = @import("SVGElement.zig").SVGElement;

pub const SVGTextContentElement = struct {
    pub const Meta = struct {
        pub const name = "SVGTextContentElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = SVGGraphicsElement.State;
        pub const ParentInterface = SVGGraphicsElement;
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
            .{ "textLength", "get_textLength", null },
            .{ "lengthAdjust", "get_lengthAdjust", null },
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

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SVGTextContentElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return SVGTextContentElementImpl.init(allocator, StateType, vtable_ptr, ctx);
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

    pub fn call_getComputedTextLength(instance: *runtime.Instance) anyerror!f32 {
        return try SVGTextContentElementImpl.call_getComputedTextLength(instance);
    }

    pub fn call_getCharNumAtPosition(instance: *runtime.Instance, point: webidl.Opt(DOMPointInit)) anyerror!i32 {
        
        return try SVGTextContentElementImpl.call_getCharNumAtPosition(instance, point);
    }

    pub fn call_getEndPositionOfChar(instance: *runtime.Instance, charnum: u32) anyerror!*runtime.Instance {
        
        return try SVGTextContentElementImpl.call_getEndPositionOfChar(instance, charnum);
    }

    pub fn call_getExtentOfChar(instance: *runtime.Instance, charnum: u32) anyerror!*runtime.Instance {
        
        return try SVGTextContentElementImpl.call_getExtentOfChar(instance, charnum);
    }

    pub fn call_getNumberOfChars(instance: *runtime.Instance) anyerror!i32 {
        return try SVGTextContentElementImpl.call_getNumberOfChars(instance);
    }

    pub fn call_getSubStringLength(instance: *runtime.Instance, charnum: u32, nchars: u32) anyerror!f32 {
        
        return try SVGTextContentElementImpl.call_getSubStringLength(instance, charnum, nchars);
    }

    pub fn call_getRotationOfChar(instance: *runtime.Instance, charnum: u32) anyerror!f32 {
        
        return try SVGTextContentElementImpl.call_getRotationOfChar(instance, charnum);
    }

    pub fn call_getStartPositionOfChar(instance: *runtime.Instance, charnum: u32) anyerror!*runtime.Instance {
        
        return try SVGTextContentElementImpl.call_getStartPositionOfChar(instance, charnum);
    }

    pub fn call_selectSubString(instance: *runtime.Instance, charnum: u32, nchars: u32) anyerror!void {
        
        return try SVGTextContentElementImpl.call_selectSubString(instance, charnum, nchars);
    }

};
