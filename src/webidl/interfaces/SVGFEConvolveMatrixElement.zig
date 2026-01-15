//! Generated from: filter-effects.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGFEConvolveMatrixElementImpl = @import("impls").SVGFEConvolveMatrixElement;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const SVGElement = @import("interfaces").SVGElement;
const SVGFilterPrimitiveStandardAttributes = @import("mixins").SVGFilterPrimitiveStandardAttributes;
const DOMStringMap = @import("interfaces").DOMStringMap;
const CSSOMString = @import("typedefs").CSSOMString;
const HTMLCollection = @import("interfaces").HTMLCollection;
const SVGAnimatedBoolean = @import("interfaces").SVGAnimatedBoolean;
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
const SVGAnimatedNumberList = @import("interfaces").SVGAnimatedNumberList;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const ShadowRootInit = @import("dictionaries").ShadowRootInit;
const SVGSVGElement = @import("interfaces").SVGSVGElement;

pub const SVGFEConvolveMatrixElement = struct {
    pub const Meta = struct {
        pub const name = "SVGFEConvolveMatrixElement";
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
            .{ "orderX", "get_orderX", null },
            .{ "orderY", "get_orderY", null },
            .{ "kernelMatrix", "get_kernelMatrix", null },
            .{ "divisor", "get_divisor", null },
            .{ "bias", "get_bias", null },
            .{ "targetX", "get_targetX", null },
            .{ "targetY", "get_targetY", null },
            .{ "edgeMode", "get_edgeMode", null },
            .{ "kernelUnitLengthX", "get_kernelUnitLengthX", null },
            .{ "kernelUnitLengthY", "get_kernelUnitLengthY", null },
            .{ "preserveAlpha", "get_preserveAlpha", null },
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
            .{ "SVG_EDGEMODE_UNKNOWN", "get_SVG_EDGEMODE_UNKNOWN" },
            .{ "SVG_EDGEMODE_DUPLICATE", "get_SVG_EDGEMODE_DUPLICATE" },
            .{ "SVG_EDGEMODE_WRAP", "get_SVG_EDGEMODE_WRAP" },
            .{ "SVG_EDGEMODE_NONE", "get_SVG_EDGEMODE_NONE" },
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
            .{ "orderX", "get_orderX", null },
            .{ "orderY", "get_orderY", null },
            .{ "kernelMatrix", "get_kernelMatrix", null },
            .{ "divisor", "get_divisor", null },
            .{ "bias", "get_bias", null },
            .{ "targetX", "get_targetX", null },
            .{ "targetY", "get_targetY", null },
            .{ "edgeMode", "get_edgeMode", null },
            .{ "kernelUnitLengthX", "get_kernelUnitLengthX", null },
            .{ "kernelUnitLengthY", "get_kernelUnitLengthY", null },
            .{ "preserveAlpha", "get_preserveAlpha", null },
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
            orderX: *runtime.Instance = undefined,
            orderY: *runtime.Instance = undefined,
            kernelMatrix: *runtime.Instance = undefined,
            divisor: *runtime.Instance = undefined,
            bias: *runtime.Instance = undefined,
            targetX: *runtime.Instance = undefined,
            targetY: *runtime.Instance = undefined,
            edgeMode: *runtime.Instance = undefined,
            kernelUnitLengthX: *runtime.Instance = undefined,
            kernelUnitLengthY: *runtime.Instance = undefined,
            preserveAlpha: *runtime.Instance = undefined,
            x: *runtime.Instance = undefined,
            y: *runtime.Instance = undefined,
            width: *runtime.Instance = undefined,
            height: *runtime.Instance = undefined,
            result: *runtime.Instance = undefined,
            _internal: ?*SVGFEConvolveMatrixElementImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short SVG_EDGEMODE_UNKNOWN = 0;
    pub fn get_SVG_EDGEMODE_UNKNOWN() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short SVG_EDGEMODE_DUPLICATE = 1;
    pub fn get_SVG_EDGEMODE_DUPLICATE() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short SVG_EDGEMODE_WRAP = 2;
    pub fn get_SVG_EDGEMODE_WRAP() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short SVG_EDGEMODE_NONE = 3;
    pub fn get_SVG_EDGEMODE_NONE() u16 {
        return 3;
    }

    const delegates = .{

        .get_SVG_EDGEMODE_DUPLICATE = &get_SVG_EDGEMODE_DUPLICATE,
        .get_SVG_EDGEMODE_NONE = &get_SVG_EDGEMODE_NONE,
        .get_SVG_EDGEMODE_UNKNOWN = &get_SVG_EDGEMODE_UNKNOWN,
        .get_SVG_EDGEMODE_WRAP = &get_SVG_EDGEMODE_WRAP,
        .get_bias = &get_bias,
        .get_divisor = &get_divisor,
        .get_edgeMode = &get_edgeMode,
        .get_height = &get_height,
        .get_in1 = &get_in1,
        .get_kernelMatrix = &get_kernelMatrix,
        .get_kernelUnitLengthX = &get_kernelUnitLengthX,
        .get_kernelUnitLengthY = &get_kernelUnitLengthY,
        .get_orderX = &get_orderX,
        .get_orderY = &get_orderY,
        .get_preserveAlpha = &get_preserveAlpha,
        .get_result = &get_result,
        .get_targetX = &get_targetX,
        .get_targetY = &get_targetY,
        .get_width = &get_width,
        .get_x = &get_x,
        .get_y = &get_y,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SVGFEConvolveMatrixElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return SVGFEConvolveMatrixElementImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGFEConvolveMatrixElementImpl.deinit(instance);
    }

    pub fn get_in1(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEConvolveMatrixElementImpl.get_in1(instance);
    }

    pub fn get_orderX(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEConvolveMatrixElementImpl.get_orderX(instance);
    }

    pub fn get_orderY(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEConvolveMatrixElementImpl.get_orderY(instance);
    }

    pub fn get_kernelMatrix(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEConvolveMatrixElementImpl.get_kernelMatrix(instance);
    }

    pub fn get_divisor(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEConvolveMatrixElementImpl.get_divisor(instance);
    }

    pub fn get_bias(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEConvolveMatrixElementImpl.get_bias(instance);
    }

    pub fn get_targetX(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEConvolveMatrixElementImpl.get_targetX(instance);
    }

    pub fn get_targetY(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEConvolveMatrixElementImpl.get_targetY(instance);
    }

    pub fn get_edgeMode(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEConvolveMatrixElementImpl.get_edgeMode(instance);
    }

    pub fn get_kernelUnitLengthX(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEConvolveMatrixElementImpl.get_kernelUnitLengthX(instance);
    }

    pub fn get_kernelUnitLengthY(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEConvolveMatrixElementImpl.get_kernelUnitLengthY(instance);
    }

    pub fn get_preserveAlpha(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEConvolveMatrixElementImpl.get_preserveAlpha(instance);
    }

    pub fn get_x(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEConvolveMatrixElementImpl.get_x(instance);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEConvolveMatrixElementImpl.get_y(instance);
    }

    pub fn get_width(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEConvolveMatrixElementImpl.get_width(instance);
    }

    pub fn get_height(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEConvolveMatrixElementImpl.get_height(instance);
    }

    pub fn get_result(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SVGFEConvolveMatrixElementImpl.get_result(instance);
    }

};
