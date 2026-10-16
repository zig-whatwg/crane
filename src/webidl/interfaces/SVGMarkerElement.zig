//! Generated from: SVG.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGMarkerElementImpl = @import("impls").SVGMarkerElement;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const SVGElement = @import("interfaces").SVGElement;
const SVGFitToViewBox = @import("mixins").SVGFitToViewBox;
const DOMStringMap = @import("interfaces").DOMStringMap;
const CSSOMString = @import("typedefs").CSSOMString;
const HTMLCollection = @import("interfaces").HTMLCollection;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const GeometryNode = @import("typedefs").GeometryNode;
const NamedNodeMap = @import("interfaces").NamedNodeMap;
const USVString = @import("typedefs").USVString;
const Element = @import("interfaces").Element;
const CheckVisibilityOptions = @import("dictionaries").CheckVisibilityOptions;
const ScrollIntoViewOptions = @import("dictionaries").ScrollIntoViewOptions;
const BoxQuadOptions = @import("dictionaries").BoxQuadOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const FocusableAreasOption = @import("dictionaries").FocusableAreasOption;
const TrustedHTMLOrDOMString = @import("typedefs").TrustedHTMLOrDOMString;
const EventListener = @import("interfaces").EventListener;
const CSSStyleProperties = @import("interfaces").CSSStyleProperties;
const CSSPseudoElement = @import("interfaces").CSSPseudoElement;
const SVGAngle = @import("interfaces").SVGAngle;
const SetHTMLOptions = @import("dictionaries").SetHTMLOptions;
const ViewTransitionUpdateCallback = @import("callbacks").ViewTransitionUpdateCallback;
const Node = @import("interfaces").Node;
const CustomElementRegistry = @import("interfaces").CustomElementRegistry;
const SetHTMLUnsafeOptions = @import("dictionaries").SetHTMLUnsafeOptions;
const Range = @import("interfaces").Range;
const Event = @import("interfaces").Event;
const Animation = @import("interfaces").Animation;
const SVGAnimatedRect = @import("interfaces").SVGAnimatedRect;
const FocusOptions = @import("dictionaries").FocusOptions;
const TrustedTypeOrDOMString = @import("typedefs").TrustedTypeOrDOMString;
const DOMString = @import("typedefs").DOMString;
const KeyframeAnimationOptions = @import("dictionaries").KeyframeAnimationOptions;
const Document = @import("interfaces").Document;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const ScrollToOptions = @import("dictionaries").ScrollToOptions;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const DOMQuad = @import("interfaces").DOMQuad;
const HTMLSlotElement = @import("interfaces").HTMLSlotElement;
const SVGUseElement = @import("interfaces").SVGUseElement;
const DOMRectList = @import("interfaces").DOMRectList;
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
const SVGAnimatedPreserveAspectRatio = @import("interfaces").SVGAnimatedPreserveAspectRatio;
const SVGAnimatedAngle = @import("interfaces").SVGAnimatedAngle;
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

pub const SVGMarkerElement = struct {
    pub const Meta = struct {
        pub const name = "SVGMarkerElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = SVGElement.State;
        pub const ParentInterface = SVGElement;
        pub const MixinTypes = &.{
            SVGFitToViewBox,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "refX", "get_refX", null },
            .{ "refY", "get_refY", null },
            .{ "markerUnits", "get_markerUnits", null },
            .{ "markerWidth", "get_markerWidth", null },
            .{ "markerHeight", "get_markerHeight", null },
            .{ "orientType", "get_orientType", null },
            .{ "orientAngle", "get_orientAngle", null },
            .{ "orient", "get_orient", "set_orient" },
            .{ "viewBox", "get_viewBox", null },
            .{ "preserveAspectRatio", "get_preserveAspectRatio", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setOrientToAuto", "call_setOrientToAuto", 0 },
            .{ "setOrientToAngle", "call_setOrientToAngle", 1 },
        };

        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "SVG_MARKERUNITS_UNKNOWN", "get_SVG_MARKERUNITS_UNKNOWN" },
            .{ "SVG_MARKERUNITS_USERSPACEONUSE", "get_SVG_MARKERUNITS_USERSPACEONUSE" },
            .{ "SVG_MARKERUNITS_STROKEWIDTH", "get_SVG_MARKERUNITS_STROKEWIDTH" },
            .{ "SVG_MARKER_ORIENT_UNKNOWN", "get_SVG_MARKER_ORIENT_UNKNOWN" },
            .{ "SVG_MARKER_ORIENT_AUTO", "get_SVG_MARKER_ORIENT_AUTO" },
            .{ "SVG_MARKER_ORIENT_ANGLE", "get_SVG_MARKER_ORIENT_ANGLE" },
            .{ "SVG_MARKER_ORIENT_AUTO_START_REVERSE", "get_SVG_MARKER_ORIENT_AUTO_START_REVERSE" },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setOrientToAuto",
            "setOrientToAngle",
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
            "pseudo",
            "computedStyleMap",
            "startViewTransition",
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
            "requestFullscreen",
            "setHTMLUnsafe",
            "getHTML",
            "insertAdjacentHTML",
            "setPointerCapture",
            "releasePointerCapture",
            "hasPointerCapture",
            "requestPointerLock",
            "setHTML",
            "getRegionFlowRanges",
            "getBoxQuads",
            "convertQuadFromNode",
            "convertRectFromNode",
            "convertPointFromNode",
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
            "animate",
            "getAnimations",
            "focus",
            "blur",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "refX", "get_refX", null },
            .{ "refY", "get_refY", null },
            .{ "markerUnits", "get_markerUnits", null },
            .{ "markerWidth", "get_markerWidth", null },
            .{ "markerHeight", "get_markerHeight", null },
            .{ "orientType", "get_orientType", null },
            .{ "orientAngle", "get_orientAngle", null },
            .{ "orient", "get_orient", "set_orient" },
            .{ "viewBox", "get_viewBox", null },
            .{ "preserveAspectRatio", "get_preserveAspectRatio", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            refX: *runtime.Instance = undefined,
            refY: *runtime.Instance = undefined,
            markerUnits: *runtime.Instance = undefined,
            markerWidth: *runtime.Instance = undefined,
            markerHeight: *runtime.Instance = undefined,
            orientType: *runtime.Instance = undefined,
            orientAngle: *runtime.Instance = undefined,
            orient: typedefs.DOMString = undefined,
            viewBox: *runtime.Instance = undefined,
            preserveAspectRatio: *runtime.Instance = undefined,
            cached_refX: ?*runtime.Instance = null,
            cached_refY: ?*runtime.Instance = null,
            cached_markerUnits: ?*runtime.Instance = null,
            cached_markerWidth: ?*runtime.Instance = null,
            cached_markerHeight: ?*runtime.Instance = null,
            cached_orientType: ?*runtime.Instance = null,
            cached_orientAngle: ?*runtime.Instance = null,
            cached_viewBox: ?*runtime.Instance = null,
            cached_preserveAspectRatio: ?*runtime.Instance = null,
            _internal: ?*SVGMarkerElementImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short SVG_MARKERUNITS_UNKNOWN = 0;
    pub fn get_SVG_MARKERUNITS_UNKNOWN() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short SVG_MARKERUNITS_USERSPACEONUSE = 1;
    pub fn get_SVG_MARKERUNITS_USERSPACEONUSE() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short SVG_MARKERUNITS_STROKEWIDTH = 2;
    pub fn get_SVG_MARKERUNITS_STROKEWIDTH() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short SVG_MARKER_ORIENT_UNKNOWN = 0;
    pub fn get_SVG_MARKER_ORIENT_UNKNOWN() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short SVG_MARKER_ORIENT_AUTO = 1;
    pub fn get_SVG_MARKER_ORIENT_AUTO() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short SVG_MARKER_ORIENT_ANGLE = 2;
    pub fn get_SVG_MARKER_ORIENT_ANGLE() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short SVG_MARKER_ORIENT_AUTO_START_REVERSE = 3;
    pub fn get_SVG_MARKER_ORIENT_AUTO_START_REVERSE() u16 {
        return 3;
    }

    const delegates = .{
        .get_SVG_MARKERUNITS_STROKEWIDTH = &get_SVG_MARKERUNITS_STROKEWIDTH,
        .get_SVG_MARKERUNITS_UNKNOWN = &get_SVG_MARKERUNITS_UNKNOWN,
        .get_SVG_MARKERUNITS_USERSPACEONUSE = &get_SVG_MARKERUNITS_USERSPACEONUSE,
        .get_SVG_MARKER_ORIENT_ANGLE = &get_SVG_MARKER_ORIENT_ANGLE,
        .get_SVG_MARKER_ORIENT_AUTO = &get_SVG_MARKER_ORIENT_AUTO,
        .get_SVG_MARKER_ORIENT_AUTO_START_REVERSE = &get_SVG_MARKER_ORIENT_AUTO_START_REVERSE,
        .get_SVG_MARKER_ORIENT_UNKNOWN = &get_SVG_MARKER_ORIENT_UNKNOWN,
        .get_markerHeight = &get_markerHeight,
        .get_markerUnits = &get_markerUnits,
        .get_markerWidth = &get_markerWidth,
        .get_orient = &get_orient,
        .get_orientAngle = &get_orientAngle,
        .get_orientType = &get_orientType,
        .get_preserveAspectRatio = &get_preserveAspectRatio,
        .get_refX = &get_refX,
        .get_refY = &get_refY,
        .get_viewBox = &get_viewBox,

        .set_orient = &set_orient,

        .call_setOrientToAngle = &call_setOrientToAngle,
        .call_setOrientToAuto = &call_setOrientToAuto,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Make a new instance: the construction chain, this interface's State
    /// and vtable.
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return initChain(allocator, State, &vtable, ctx, .{});
    }

    /// Make a new instance with construction arguments: facts given at
    /// construction, as a C++ constructor's parameters. Each field of `args`
    /// must be taken by an impl on the chain (its `construction_args`).
    pub fn initWith(allocator: std.mem.Allocator, ctx: runtime.Context, args: anytype) !*runtime.Instance {
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("SVGMarkerElement has no construction argument '" ++ field.name ++ "'");
        }
        return initChain(allocator, State, &vtable, ctx, args);
    }

    /// The construction chain for a descendant's State and vtable, for an
    /// impl that still chains by hand.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return initChain(allocator, StateType, vtable_ptr, ctx, .{});
    }

    /// The construction chain: the parent interface's, then the impl's own
    /// steps (`initOwn`), whose failure unwinds the parent's part and frees
    /// the slot. An impl that still defines `init` chains by hand.
    pub inline fn initChain(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
        args: anytype,
    ) !*runtime.Instance {
        if (comptime @hasDecl(SVGMarkerElementImpl, "init") and @hasDecl(SVGMarkerElementImpl, "initOwn")) @compileError("SVGMarkerElementImpl defines both init and initOwn");
        if (comptime @hasDecl(SVGMarkerElementImpl, "init")) return SVGMarkerElementImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(SVGMarkerElementImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try SVGMarkerElementImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SVGMarkerElementImpl, "init")) return false;
        if (comptime @hasDecl(SVGMarkerElementImpl, "construction_args")) {
            inline for (SVGMarkerElementImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return Meta.ParentInterface.takesConstructionArg(name);
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(SVGMarkerElementImpl, "deinit") and @hasDecl(SVGMarkerElementImpl, "deinitOwn")) @compileError("SVGMarkerElementImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SVGMarkerElementImpl, "deinit")) return SVGMarkerElementImpl.deinit(instance);
        if (comptime @hasDecl(SVGMarkerElementImpl, "deinitOwn")) SVGMarkerElementImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SVGMarkerElement")) {
            if (comptime @hasDecl(impls.SVGMarkerElement, "installHooks")) impls.SVGMarkerElement.installHooks();
        }
    }

    /// Extended attributes: [SameObject]
    pub fn get_refX(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_refX) |cached| {
            return cached;
        }
        const value = try SVGMarkerElementImpl.get_refX(instance);
        state.own.cached_refX = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_refY(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_refY) |cached| {
            return cached;
        }
        const value = try SVGMarkerElementImpl.get_refY(instance);
        state.own.cached_refY = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_markerUnits(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_markerUnits) |cached| {
            return cached;
        }
        const value = try SVGMarkerElementImpl.get_markerUnits(instance);
        state.own.cached_markerUnits = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_markerWidth(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_markerWidth) |cached| {
            return cached;
        }
        const value = try SVGMarkerElementImpl.get_markerWidth(instance);
        state.own.cached_markerWidth = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_markerHeight(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_markerHeight) |cached| {
            return cached;
        }
        const value = try SVGMarkerElementImpl.get_markerHeight(instance);
        state.own.cached_markerHeight = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_orientType(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_orientType) |cached| {
            return cached;
        }
        const value = try SVGMarkerElementImpl.get_orientType(instance);
        state.own.cached_orientType = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_orientAngle(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_orientAngle) |cached| {
            return cached;
        }
        const value = try SVGMarkerElementImpl.get_orientAngle(instance);
        state.own.cached_orientAngle = value;
        return value;
    }

    pub fn get_orient(instance: *runtime.Instance) anyerror!DOMString {
        return try SVGMarkerElementImpl.get_orient(instance);
    }

    pub fn set_orient(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try SVGMarkerElementImpl.set_orient(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_viewBox(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_viewBox) |cached| {
            return cached;
        }
        const value = try mixins.SVGFitToViewBox.get_viewBox(instance);
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
        const value = try mixins.SVGFitToViewBox.get_preserveAspectRatio(instance);
        state.own.cached_preserveAspectRatio = value;
        return value;
    }

    pub fn call_setOrientToAngle(instance: *runtime.Instance, angle: *runtime.Instance) anyerror!void {
        return try SVGMarkerElementImpl.call_setOrientToAngle(instance, angle);
    }

    pub fn call_setOrientToAuto(instance: *runtime.Instance) anyerror!void {
        return try SVGMarkerElementImpl.call_setOrientToAuto(instance);
    }
};
