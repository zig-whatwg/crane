//! Generated from: filter-effects.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGFEColorMatrixElementImpl = @import("impls").SVGFEColorMatrixElement;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const SVGElement = @import("interfaces").SVGElement;
const SVGFilterPrimitiveStandardAttributes = @import("mixins").SVGFilterPrimitiveStandardAttributes;
const DOMStringMap = @import("interfaces").DOMStringMap;
const CSSOMString = @import("typedefs").CSSOMString;
const HTMLCollection = @import("interfaces").HTMLCollection;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const GeometryNode = @import("typedefs").GeometryNode;
const NamedNodeMap = @import("interfaces").NamedNodeMap;
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const USVString = @import("typedefs").USVString;
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
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
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
const SVGAnimatedNumberList = @import("interfaces").SVGAnimatedNumberList;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const ShadowRootInit = @import("dictionaries").ShadowRootInit;
const SVGSVGElement = @import("interfaces").SVGSVGElement;

pub const SVGFEColorMatrixElement = struct {
    pub const Meta = struct {
        pub const name = "SVGFEColorMatrixElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = SVGElement.State;
        pub const ParentInterface = SVGElement;
        pub const MixinTypes = &.{
            SVGFilterPrimitiveStandardAttributes,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "in1", "get_in1", null },
            .{ "type", "get_type", null },
            .{ "values", "get_values", null },
            .{ "x", "get_x", null },
            .{ "y", "get_y", null },
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "result", "get_result", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "SVG_FECOLORMATRIX_TYPE_UNKNOWN", "get_SVG_FECOLORMATRIX_TYPE_UNKNOWN" },
            .{ "SVG_FECOLORMATRIX_TYPE_MATRIX", "get_SVG_FECOLORMATRIX_TYPE_MATRIX" },
            .{ "SVG_FECOLORMATRIX_TYPE_SATURATE", "get_SVG_FECOLORMATRIX_TYPE_SATURATE" },
            .{ "SVG_FECOLORMATRIX_TYPE_HUEROTATE", "get_SVG_FECOLORMATRIX_TYPE_HUEROTATE" },
            .{ "SVG_FECOLORMATRIX_TYPE_LUMINANCETOALPHA", "get_SVG_FECOLORMATRIX_TYPE_LUMINANCETOALPHA" },
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
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "in1", "get_in1", null },
            .{ "type", "get_type", null },
            .{ "values", "get_values", null },
            .{ "x", "get_x", null },
            .{ "y", "get_y", null },
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "result", "get_result", null },
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
            in1: *runtime.Instance = undefined,
            @"type": *runtime.Instance = undefined,
            values: *runtime.Instance = undefined,
            x: *runtime.Instance = undefined,
            y: *runtime.Instance = undefined,
            width: *runtime.Instance = undefined,
            height: *runtime.Instance = undefined,
            result: *runtime.Instance = undefined,
            _internal: ?*SVGFEColorMatrixElementImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short SVG_FECOLORMATRIX_TYPE_UNKNOWN = 0;
    pub fn get_SVG_FECOLORMATRIX_TYPE_UNKNOWN() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short SVG_FECOLORMATRIX_TYPE_MATRIX = 1;
    pub fn get_SVG_FECOLORMATRIX_TYPE_MATRIX() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short SVG_FECOLORMATRIX_TYPE_SATURATE = 2;
    pub fn get_SVG_FECOLORMATRIX_TYPE_SATURATE() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short SVG_FECOLORMATRIX_TYPE_HUEROTATE = 3;
    pub fn get_SVG_FECOLORMATRIX_TYPE_HUEROTATE() u16 {
        return 3;
    }

    /// WebIDL constant: const unsigned short SVG_FECOLORMATRIX_TYPE_LUMINANCETOALPHA = 4;
    pub fn get_SVG_FECOLORMATRIX_TYPE_LUMINANCETOALPHA() u16 {
        return 4;
    }

    const delegates = .{

        .get_SVG_FECOLORMATRIX_TYPE_HUEROTATE = &get_SVG_FECOLORMATRIX_TYPE_HUEROTATE,
        .get_SVG_FECOLORMATRIX_TYPE_LUMINANCETOALPHA = &get_SVG_FECOLORMATRIX_TYPE_LUMINANCETOALPHA,
        .get_SVG_FECOLORMATRIX_TYPE_MATRIX = &get_SVG_FECOLORMATRIX_TYPE_MATRIX,
        .get_SVG_FECOLORMATRIX_TYPE_SATURATE = &get_SVG_FECOLORMATRIX_TYPE_SATURATE,
        .get_SVG_FECOLORMATRIX_TYPE_UNKNOWN = &get_SVG_FECOLORMATRIX_TYPE_UNKNOWN,
        .get_height = &get_height,
        .get_in1 = &get_in1,
        .get_result = &get_result,
        .get_type = &get_type,
        .get_values = &get_values,
        .get_width = &get_width,
        .get_x = &get_x,
        .get_y = &get_y,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SVGFEColorMatrixElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return SVGFEColorMatrixElementImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGFEColorMatrixElementImpl.deinit(instance);
    }

    pub fn get_in1(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEColorMatrixElementImpl.get_in1(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEColorMatrixElementImpl.get_type(instance);
    }

    pub fn get_values(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEColorMatrixElementImpl.get_values(instance);
    }

    pub fn get_x(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEColorMatrixElementImpl.get_x(instance);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEColorMatrixElementImpl.get_y(instance);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEColorMatrixElementImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEColorMatrixElementImpl.get_height(instance);
    }

    pub fn get_result(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEColorMatrixElementImpl.get_result(instance);
    }

};
