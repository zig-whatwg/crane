//! Generated from: SVG.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGRadialGradientElementImpl = @import("impls").SVGRadialGradientElement;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const SVGGradientElement = @import("interfaces").SVGGradientElement;
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
const SetHTMLOptions = @import("dictionaries").SetHTMLOptions;
const ViewTransitionUpdateCallback = @import("callbacks").ViewTransitionUpdateCallback;
const Node = @import("interfaces").Node;
const CustomElementRegistry = @import("interfaces").CustomElementRegistry;
const SetHTMLUnsafeOptions = @import("dictionaries").SetHTMLUnsafeOptions;
const Range = @import("interfaces").Range;
const Event = @import("interfaces").Event;
const Animation = @import("interfaces").Animation;
const FocusOptions = @import("dictionaries").FocusOptions;
const TrustedTypeOrDOMString = @import("typedefs").TrustedTypeOrDOMString;
const SVGAnimatedTransformList = @import("interfaces").SVGAnimatedTransformList;
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
const StylePropertyMapReadOnly = @import("interfaces").StylePropertyMapReadOnly;
const DOMTokenList = @import("interfaces").DOMTokenList;
const StartViewTransitionOptions = @import("dictionaries").StartViewTransitionOptions;
const SVGAnimatedEnumeration = @import("interfaces").SVGAnimatedEnumeration;
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

pub const SVGRadialGradientElement = struct {
    pub const Meta = struct {
        pub const name = "SVGRadialGradientElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = SVGGradientElement.State;
        pub const ParentInterface = SVGGradientElement;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "cx", "get_cx", null },
            .{ "cy", "get_cy", null },
            .{ "r", "get_r", null },
            .{ "fx", "get_fx", null },
            .{ "fy", "get_fy", null },
            .{ "fr", "get_fr", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

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
            .{ "cx", "get_cx", null },
            .{ "cy", "get_cy", null },
            .{ "r", "get_r", null },
            .{ "fx", "get_fx", null },
            .{ "fy", "get_fy", null },
            .{ "fr", "get_fr", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            cx: *runtime.Instance = undefined,
            cy: *runtime.Instance = undefined,
            r: *runtime.Instance = undefined,
            fx: *runtime.Instance = undefined,
            fy: *runtime.Instance = undefined,
            fr: *runtime.Instance = undefined,
            cached_cx: ?*runtime.Instance = null,
            cached_cy: ?*runtime.Instance = null,
            cached_r: ?*runtime.Instance = null,
            cached_fx: ?*runtime.Instance = null,
            cached_fy: ?*runtime.Instance = null,
            cached_fr: ?*runtime.Instance = null,
            _internal: ?*SVGRadialGradientElementImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_cx = &get_cx,
        .get_cy = &get_cy,
        .get_fr = &get_fr,
        .get_fx = &get_fx,
        .get_fy = &get_fy,
        .get_r = &get_r,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("SVGRadialGradientElement has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(SVGRadialGradientElementImpl, "init") and @hasDecl(SVGRadialGradientElementImpl, "initOwn")) @compileError("SVGRadialGradientElementImpl defines both init and initOwn");
        if (comptime @hasDecl(SVGRadialGradientElementImpl, "init")) return SVGRadialGradientElementImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(SVGRadialGradientElementImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try SVGRadialGradientElementImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SVGRadialGradientElementImpl, "init")) return false;
        if (comptime @hasDecl(SVGRadialGradientElementImpl, "construction_args")) {
            inline for (SVGRadialGradientElementImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(SVGRadialGradientElementImpl, "deinit") and @hasDecl(SVGRadialGradientElementImpl, "deinitOwn")) @compileError("SVGRadialGradientElementImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(SVGRadialGradientElementImpl, "deinit")) return SVGRadialGradientElementImpl.deinit(instance);
        if (comptime @hasDecl(SVGRadialGradientElementImpl, "deinitOwn")) SVGRadialGradientElementImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SVGRadialGradientElement")) {
            if (comptime @hasDecl(impls.SVGRadialGradientElement, "installHooks")) impls.SVGRadialGradientElement.installHooks();
        }
    }

    /// Extended attributes: [SameObject]
    pub fn get_cx(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_cx) |cached| {
            return cached;
        }
        const value = try SVGRadialGradientElementImpl.get_cx(instance);
        state.own.cached_cx = value;
        @import("dom").same_object_cache.made(instance, value, "cx");
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_cy(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_cy) |cached| {
            return cached;
        }
        const value = try SVGRadialGradientElementImpl.get_cy(instance);
        state.own.cached_cy = value;
        @import("dom").same_object_cache.made(instance, value, "cy");
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_r(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_r) |cached| {
            return cached;
        }
        const value = try SVGRadialGradientElementImpl.get_r(instance);
        state.own.cached_r = value;
        @import("dom").same_object_cache.made(instance, value, "r");
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_fx(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_fx) |cached| {
            return cached;
        }
        const value = try SVGRadialGradientElementImpl.get_fx(instance);
        state.own.cached_fx = value;
        @import("dom").same_object_cache.made(instance, value, "fx");
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_fy(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_fy) |cached| {
            return cached;
        }
        const value = try SVGRadialGradientElementImpl.get_fy(instance);
        state.own.cached_fy = value;
        @import("dom").same_object_cache.made(instance, value, "fy");
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_fr(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_fr) |cached| {
            return cached;
        }
        const value = try SVGRadialGradientElementImpl.get_fr(instance);
        state.own.cached_fr = value;
        @import("dom").same_object_cache.made(instance, value, "fr");
        return value;
    }
};
