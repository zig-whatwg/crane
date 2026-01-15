//! Generated from: filter-effects.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGFETurbulenceElementImpl = @import("impls").SVGFETurbulenceElement;
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
const SVGAnimatedInteger = @import("interfaces").SVGAnimatedInteger;
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
const SVGAnimatedNumber = @import("interfaces").SVGAnimatedNumber;
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const ScrollToOptions = @import("dictionaries").ScrollToOptions;
const HTMLSlotElement = @import("interfaces").HTMLSlotElement;
const DOMQuad = @import("interfaces").DOMQuad;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const SVGUseElement = @import("interfaces").SVGUseElement;
const SVGAnimatedEnumeration = @import("interfaces").SVGAnimatedEnumeration;
const StylePropertyMapReadOnly = @import("interfaces").StylePropertyMapReadOnly;
const DOMTokenList = @import("interfaces").DOMTokenList;
const StartViewTransitionOptions = @import("dictionaries").StartViewTransitionOptions;
const KeyframeAnimationOptions = @import("dictionaries").KeyframeAnimationOptions;
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

pub const SVGFETurbulenceElement = struct {
    pub const Meta = struct {
        pub const name = "SVGFETurbulenceElement";
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
            .{ "baseFrequencyX", "get_baseFrequencyX", null },
            .{ "baseFrequencyY", "get_baseFrequencyY", null },
            .{ "numOctaves", "get_numOctaves", null },
            .{ "seed", "get_seed", null },
            .{ "stitchTiles", "get_stitchTiles", null },
            .{ "type", "get_type", null },
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
            .{ "SVG_TURBULENCE_TYPE_UNKNOWN", "get_SVG_TURBULENCE_TYPE_UNKNOWN" },
            .{ "SVG_TURBULENCE_TYPE_FRACTALNOISE", "get_SVG_TURBULENCE_TYPE_FRACTALNOISE" },
            .{ "SVG_TURBULENCE_TYPE_TURBULENCE", "get_SVG_TURBULENCE_TYPE_TURBULENCE" },
            .{ "SVG_STITCHTYPE_UNKNOWN", "get_SVG_STITCHTYPE_UNKNOWN" },
            .{ "SVG_STITCHTYPE_STITCH", "get_SVG_STITCHTYPE_STITCH" },
            .{ "SVG_STITCHTYPE_NOSTITCH", "get_SVG_STITCHTYPE_NOSTITCH" },
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
            .{ "baseFrequencyX", "get_baseFrequencyX", null },
            .{ "baseFrequencyY", "get_baseFrequencyY", null },
            .{ "numOctaves", "get_numOctaves", null },
            .{ "seed", "get_seed", null },
            .{ "stitchTiles", "get_stitchTiles", null },
            .{ "type", "get_type", null },
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
            baseFrequencyX: *runtime.Instance = undefined,
            baseFrequencyY: *runtime.Instance = undefined,
            numOctaves: *runtime.Instance = undefined,
            seed: *runtime.Instance = undefined,
            stitchTiles: *runtime.Instance = undefined,
            @"type": *runtime.Instance = undefined,
            x: *runtime.Instance = undefined,
            y: *runtime.Instance = undefined,
            width: *runtime.Instance = undefined,
            height: *runtime.Instance = undefined,
            result: *runtime.Instance = undefined,
            _internal: ?*SVGFETurbulenceElementImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short SVG_TURBULENCE_TYPE_UNKNOWN = 0;
    pub fn get_SVG_TURBULENCE_TYPE_UNKNOWN() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short SVG_TURBULENCE_TYPE_FRACTALNOISE = 1;
    pub fn get_SVG_TURBULENCE_TYPE_FRACTALNOISE() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short SVG_TURBULENCE_TYPE_TURBULENCE = 2;
    pub fn get_SVG_TURBULENCE_TYPE_TURBULENCE() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short SVG_STITCHTYPE_UNKNOWN = 0;
    pub fn get_SVG_STITCHTYPE_UNKNOWN() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short SVG_STITCHTYPE_STITCH = 1;
    pub fn get_SVG_STITCHTYPE_STITCH() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short SVG_STITCHTYPE_NOSTITCH = 2;
    pub fn get_SVG_STITCHTYPE_NOSTITCH() u16 {
        return 2;
    }

    const delegates = .{

        .get_SVG_STITCHTYPE_NOSTITCH = &get_SVG_STITCHTYPE_NOSTITCH,
        .get_SVG_STITCHTYPE_STITCH = &get_SVG_STITCHTYPE_STITCH,
        .get_SVG_STITCHTYPE_UNKNOWN = &get_SVG_STITCHTYPE_UNKNOWN,
        .get_SVG_TURBULENCE_TYPE_FRACTALNOISE = &get_SVG_TURBULENCE_TYPE_FRACTALNOISE,
        .get_SVG_TURBULENCE_TYPE_TURBULENCE = &get_SVG_TURBULENCE_TYPE_TURBULENCE,
        .get_SVG_TURBULENCE_TYPE_UNKNOWN = &get_SVG_TURBULENCE_TYPE_UNKNOWN,
        .get_baseFrequencyX = &get_baseFrequencyX,
        .get_baseFrequencyY = &get_baseFrequencyY,
        .get_height = &get_height,
        .get_numOctaves = &get_numOctaves,
        .get_result = &get_result,
        .get_seed = &get_seed,
        .get_stitchTiles = &get_stitchTiles,
        .get_type = &get_type,
        .get_width = &get_width,
        .get_x = &get_x,
        .get_y = &get_y,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SVGFETurbulenceElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return SVGFETurbulenceElementImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGFETurbulenceElementImpl.deinit(instance);
    }

    pub fn get_baseFrequencyX(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFETurbulenceElementImpl.get_baseFrequencyX(instance);
    }

    pub fn get_baseFrequencyY(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFETurbulenceElementImpl.get_baseFrequencyY(instance);
    }

    pub fn get_numOctaves(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFETurbulenceElementImpl.get_numOctaves(instance);
    }

    pub fn get_seed(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFETurbulenceElementImpl.get_seed(instance);
    }

    pub fn get_stitchTiles(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFETurbulenceElementImpl.get_stitchTiles(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFETurbulenceElementImpl.get_type(instance);
    }

    pub fn get_x(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFETurbulenceElementImpl.get_x(instance);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFETurbulenceElementImpl.get_y(instance);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFETurbulenceElementImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFETurbulenceElementImpl.get_height(instance);
    }

    pub fn get_result(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFETurbulenceElementImpl.get_result(instance);
    }

};
