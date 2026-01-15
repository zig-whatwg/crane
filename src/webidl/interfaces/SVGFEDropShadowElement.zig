//! Generated from: filter-effects.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGFEDropShadowElementImpl = @import("impls").SVGFEDropShadowElement;
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
const SVGAnimatedNumber = @import("interfaces").SVGAnimatedNumber;
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const ScrollToOptions = @import("dictionaries").ScrollToOptions;
const HTMLSlotElement = @import("interfaces").HTMLSlotElement;
const DOMQuad = @import("interfaces").DOMQuad;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const SVGUseElement = @import("interfaces").SVGUseElement;
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

pub const SVGFEDropShadowElement = struct {
    pub const Meta = struct {
        pub const name = "SVGFEDropShadowElement";
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
            .{ "dx", "get_dx", null },
            .{ "dy", "get_dy", null },
            .{ "stdDeviationX", "get_stdDeviationX", null },
            .{ "stdDeviationY", "get_stdDeviationY", null },
            .{ "x", "get_x", null },
            .{ "y", "get_y", null },
            .{ "width", "get_width", null },
            .{ "height", "get_height", null },
            .{ "result", "get_result", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setStdDeviation", "call_setStdDeviation", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setStdDeviation",
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
            .{ "dx", "get_dx", null },
            .{ "dy", "get_dy", null },
            .{ "stdDeviationX", "get_stdDeviationX", null },
            .{ "stdDeviationY", "get_stdDeviationY", null },
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
            dx: *runtime.Instance = undefined,
            dy: *runtime.Instance = undefined,
            stdDeviationX: *runtime.Instance = undefined,
            stdDeviationY: *runtime.Instance = undefined,
            x: *runtime.Instance = undefined,
            y: *runtime.Instance = undefined,
            width: *runtime.Instance = undefined,
            height: *runtime.Instance = undefined,
            result: *runtime.Instance = undefined,
            _internal: ?*SVGFEDropShadowElementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_dx = &get_dx,
        .get_dy = &get_dy,
        .get_height = &get_height,
        .get_in1 = &get_in1,
        .get_result = &get_result,
        .get_stdDeviationX = &get_stdDeviationX,
        .get_stdDeviationY = &get_stdDeviationY,
        .get_width = &get_width,
        .get_x = &get_x,
        .get_y = &get_y,

        .call_setStdDeviation = &call_setStdDeviation,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SVGFEDropShadowElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return SVGFEDropShadowElementImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGFEDropShadowElementImpl.deinit(instance);
    }

    pub fn get_in1(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEDropShadowElementImpl.get_in1(instance);
    }

    pub fn get_dx(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEDropShadowElementImpl.get_dx(instance);
    }

    pub fn get_dy(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEDropShadowElementImpl.get_dy(instance);
    }

    pub fn get_stdDeviationX(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEDropShadowElementImpl.get_stdDeviationX(instance);
    }

    pub fn get_stdDeviationY(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEDropShadowElementImpl.get_stdDeviationY(instance);
    }

    pub fn get_x(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEDropShadowElementImpl.get_x(instance);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEDropShadowElementImpl.get_y(instance);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEDropShadowElementImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEDropShadowElementImpl.get_height(instance);
    }

    pub fn get_result(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEDropShadowElementImpl.get_result(instance);
    }

    pub fn call_setStdDeviation(instance: *runtime.Instance, stdDeviationX: f32, stdDeviationY: f32) anyerror!void {
        
        return try SVGFEDropShadowElementImpl.call_setStdDeviation(instance, stdDeviationX, stdDeviationY);
    }

};
