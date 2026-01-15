//! Generated from: filter-effects.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGFEBlendElementImpl = @import("impls").SVGFEBlendElement;
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
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const NamedNodeMap = @import("interfaces").NamedNodeMap;
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
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const ShadowRootInit = @import("dictionaries").ShadowRootInit;
const SVGSVGElement = @import("interfaces").SVGSVGElement;

pub const SVGFEBlendElement = struct {
    pub const Meta = struct {
        pub const name = "SVGFEBlendElement";
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
            .{ "in2", "get_in2", null },
            .{ "mode", "get_mode", null },
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
            .{ "SVG_FEBLEND_MODE_UNKNOWN", "get_SVG_FEBLEND_MODE_UNKNOWN" },
            .{ "SVG_FEBLEND_MODE_NORMAL", "get_SVG_FEBLEND_MODE_NORMAL" },
            .{ "SVG_FEBLEND_MODE_MULTIPLY", "get_SVG_FEBLEND_MODE_MULTIPLY" },
            .{ "SVG_FEBLEND_MODE_SCREEN", "get_SVG_FEBLEND_MODE_SCREEN" },
            .{ "SVG_FEBLEND_MODE_DARKEN", "get_SVG_FEBLEND_MODE_DARKEN" },
            .{ "SVG_FEBLEND_MODE_LIGHTEN", "get_SVG_FEBLEND_MODE_LIGHTEN" },
            .{ "SVG_FEBLEND_MODE_OVERLAY", "get_SVG_FEBLEND_MODE_OVERLAY" },
            .{ "SVG_FEBLEND_MODE_COLOR_DODGE", "get_SVG_FEBLEND_MODE_COLOR_DODGE" },
            .{ "SVG_FEBLEND_MODE_COLOR_BURN", "get_SVG_FEBLEND_MODE_COLOR_BURN" },
            .{ "SVG_FEBLEND_MODE_HARD_LIGHT", "get_SVG_FEBLEND_MODE_HARD_LIGHT" },
            .{ "SVG_FEBLEND_MODE_SOFT_LIGHT", "get_SVG_FEBLEND_MODE_SOFT_LIGHT" },
            .{ "SVG_FEBLEND_MODE_DIFFERENCE", "get_SVG_FEBLEND_MODE_DIFFERENCE" },
            .{ "SVG_FEBLEND_MODE_EXCLUSION", "get_SVG_FEBLEND_MODE_EXCLUSION" },
            .{ "SVG_FEBLEND_MODE_HUE", "get_SVG_FEBLEND_MODE_HUE" },
            .{ "SVG_FEBLEND_MODE_SATURATION", "get_SVG_FEBLEND_MODE_SATURATION" },
            .{ "SVG_FEBLEND_MODE_COLOR", "get_SVG_FEBLEND_MODE_COLOR" },
            .{ "SVG_FEBLEND_MODE_LUMINOSITY", "get_SVG_FEBLEND_MODE_LUMINOSITY" },
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
            .{ "in2", "get_in2", null },
            .{ "mode", "get_mode", null },
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
            in2: *runtime.Instance = undefined,
            mode: *runtime.Instance = undefined,
            x: *runtime.Instance = undefined,
            y: *runtime.Instance = undefined,
            width: *runtime.Instance = undefined,
            height: *runtime.Instance = undefined,
            result: *runtime.Instance = undefined,
            _internal: ?*SVGFEBlendElementImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short SVG_FEBLEND_MODE_UNKNOWN = 0;
    pub fn get_SVG_FEBLEND_MODE_UNKNOWN() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short SVG_FEBLEND_MODE_NORMAL = 1;
    pub fn get_SVG_FEBLEND_MODE_NORMAL() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short SVG_FEBLEND_MODE_MULTIPLY = 2;
    pub fn get_SVG_FEBLEND_MODE_MULTIPLY() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short SVG_FEBLEND_MODE_SCREEN = 3;
    pub fn get_SVG_FEBLEND_MODE_SCREEN() u16 {
        return 3;
    }

    /// WebIDL constant: const unsigned short SVG_FEBLEND_MODE_DARKEN = 4;
    pub fn get_SVG_FEBLEND_MODE_DARKEN() u16 {
        return 4;
    }

    /// WebIDL constant: const unsigned short SVG_FEBLEND_MODE_LIGHTEN = 5;
    pub fn get_SVG_FEBLEND_MODE_LIGHTEN() u16 {
        return 5;
    }

    /// WebIDL constant: const unsigned short SVG_FEBLEND_MODE_OVERLAY = 6;
    pub fn get_SVG_FEBLEND_MODE_OVERLAY() u16 {
        return 6;
    }

    /// WebIDL constant: const unsigned short SVG_FEBLEND_MODE_COLOR_DODGE = 7;
    pub fn get_SVG_FEBLEND_MODE_COLOR_DODGE() u16 {
        return 7;
    }

    /// WebIDL constant: const unsigned short SVG_FEBLEND_MODE_COLOR_BURN = 8;
    pub fn get_SVG_FEBLEND_MODE_COLOR_BURN() u16 {
        return 8;
    }

    /// WebIDL constant: const unsigned short SVG_FEBLEND_MODE_HARD_LIGHT = 9;
    pub fn get_SVG_FEBLEND_MODE_HARD_LIGHT() u16 {
        return 9;
    }

    /// WebIDL constant: const unsigned short SVG_FEBLEND_MODE_SOFT_LIGHT = 10;
    pub fn get_SVG_FEBLEND_MODE_SOFT_LIGHT() u16 {
        return 10;
    }

    /// WebIDL constant: const unsigned short SVG_FEBLEND_MODE_DIFFERENCE = 11;
    pub fn get_SVG_FEBLEND_MODE_DIFFERENCE() u16 {
        return 11;
    }

    /// WebIDL constant: const unsigned short SVG_FEBLEND_MODE_EXCLUSION = 12;
    pub fn get_SVG_FEBLEND_MODE_EXCLUSION() u16 {
        return 12;
    }

    /// WebIDL constant: const unsigned short SVG_FEBLEND_MODE_HUE = 13;
    pub fn get_SVG_FEBLEND_MODE_HUE() u16 {
        return 13;
    }

    /// WebIDL constant: const unsigned short SVG_FEBLEND_MODE_SATURATION = 14;
    pub fn get_SVG_FEBLEND_MODE_SATURATION() u16 {
        return 14;
    }

    /// WebIDL constant: const unsigned short SVG_FEBLEND_MODE_COLOR = 15;
    pub fn get_SVG_FEBLEND_MODE_COLOR() u16 {
        return 15;
    }

    /// WebIDL constant: const unsigned short SVG_FEBLEND_MODE_LUMINOSITY = 16;
    pub fn get_SVG_FEBLEND_MODE_LUMINOSITY() u16 {
        return 16;
    }

    const delegates = .{

        .get_SVG_FEBLEND_MODE_COLOR = &get_SVG_FEBLEND_MODE_COLOR,
        .get_SVG_FEBLEND_MODE_COLOR_BURN = &get_SVG_FEBLEND_MODE_COLOR_BURN,
        .get_SVG_FEBLEND_MODE_COLOR_DODGE = &get_SVG_FEBLEND_MODE_COLOR_DODGE,
        .get_SVG_FEBLEND_MODE_DARKEN = &get_SVG_FEBLEND_MODE_DARKEN,
        .get_SVG_FEBLEND_MODE_DIFFERENCE = &get_SVG_FEBLEND_MODE_DIFFERENCE,
        .get_SVG_FEBLEND_MODE_EXCLUSION = &get_SVG_FEBLEND_MODE_EXCLUSION,
        .get_SVG_FEBLEND_MODE_HARD_LIGHT = &get_SVG_FEBLEND_MODE_HARD_LIGHT,
        .get_SVG_FEBLEND_MODE_HUE = &get_SVG_FEBLEND_MODE_HUE,
        .get_SVG_FEBLEND_MODE_LIGHTEN = &get_SVG_FEBLEND_MODE_LIGHTEN,
        .get_SVG_FEBLEND_MODE_LUMINOSITY = &get_SVG_FEBLEND_MODE_LUMINOSITY,
        .get_SVG_FEBLEND_MODE_MULTIPLY = &get_SVG_FEBLEND_MODE_MULTIPLY,
        .get_SVG_FEBLEND_MODE_NORMAL = &get_SVG_FEBLEND_MODE_NORMAL,
        .get_SVG_FEBLEND_MODE_OVERLAY = &get_SVG_FEBLEND_MODE_OVERLAY,
        .get_SVG_FEBLEND_MODE_SATURATION = &get_SVG_FEBLEND_MODE_SATURATION,
        .get_SVG_FEBLEND_MODE_SCREEN = &get_SVG_FEBLEND_MODE_SCREEN,
        .get_SVG_FEBLEND_MODE_SOFT_LIGHT = &get_SVG_FEBLEND_MODE_SOFT_LIGHT,
        .get_SVG_FEBLEND_MODE_UNKNOWN = &get_SVG_FEBLEND_MODE_UNKNOWN,
        .get_height = &get_height,
        .get_in1 = &get_in1,
        .get_in2 = &get_in2,
        .get_mode = &get_mode,
        .get_result = &get_result,
        .get_width = &get_width,
        .get_x = &get_x,
        .get_y = &get_y,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SVGFEBlendElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return SVGFEBlendElementImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGFEBlendElementImpl.deinit(instance);
    }

    pub fn get_in1(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEBlendElementImpl.get_in1(instance);
    }

    pub fn get_in2(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEBlendElementImpl.get_in2(instance);
    }

    pub fn get_mode(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEBlendElementImpl.get_mode(instance);
    }

    pub fn get_x(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEBlendElementImpl.get_x(instance);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEBlendElementImpl.get_y(instance);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEBlendElementImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEBlendElementImpl.get_height(instance);
    }

    pub fn get_result(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEBlendElementImpl.get_result(instance);
    }

};
