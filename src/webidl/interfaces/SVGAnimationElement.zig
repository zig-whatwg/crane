//! Generated from: svg-animations.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGAnimationElementImpl = @import("impls").SVGAnimationElement;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const SVGElement = @import("interfaces").SVGElement;
const SVGTests = @import("mixins").SVGTests;
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
const SVGStringList = @import("interfaces").SVGStringList;
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
const DOMRectList = @import("interfaces").DOMRectList;
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
const SpatialNavigationDirection = @import("enums").SpatialNavigationDirection;
const StylePropertyMap = @import("interfaces").StylePropertyMap;
const ShadowRoot = @import("interfaces").ShadowRoot;
const Attr = @import("interfaces").Attr;
const TrustedHTML = @import("interfaces").TrustedHTML;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const NodeList = @import("interfaces").NodeList;
const FullscreenOptions = @import("dictionaries").FullscreenOptions;
const AriaNotificationOptions = @import("dictionaries").AriaNotificationOptions;
const Observable = @import("interfaces").Observable;
const DOMPoint = @import("interfaces").DOMPoint;
const PointerLockOptions = @import("dictionaries").PointerLockOptions;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const ShadowRootInit = @import("dictionaries").ShadowRootInit;
const SVGSVGElement = @import("interfaces").SVGSVGElement;

pub const SVGAnimationElement = struct {
    pub const Meta = struct {
        pub const name = "SVGAnimationElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = SVGElement.State;
        pub const ParentInterface = SVGElement;
        pub const MixinTypes = &.{
            SVGTests,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "targetElement", "get_targetElement", null },
            .{ "onbegin", "get_onbegin", "set_onbegin" },
            .{ "onend", "get_onend", "set_onend" },
            .{ "onrepeat", "get_onrepeat", "set_onrepeat" },
            .{ "requiredExtensions", "get_requiredExtensions", null },
            .{ "systemLanguage", "get_systemLanguage", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getStartTime", "call_getStartTime", 0 },
            .{ "getCurrentTime", "call_getCurrentTime", 0 },
            .{ "getSimpleDuration", "call_getSimpleDuration", 0 },
            .{ "beginElement", "call_beginElement", 0 },
            .{ "beginElementAt", "call_beginElementAt", 1 },
            .{ "endElement", "call_endElement", 0 },
            .{ "endElementAt", "call_endElementAt", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getStartTime",
            "getCurrentTime",
            "getSimpleDuration",
            "beginElement",
            "beginElementAt",
            "endElement",
            "endElementAt",
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
            "setHTML",
            "setHTMLUnsafe",
            "getHTML",
            "insertAdjacentHTML",
            "setPointerCapture",
            "releasePointerCapture",
            "hasPointerCapture",
            "requestPointerLock",
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
            "ariaNotify",
            "animate",
            "getAnimations",
            "focus",
            "blur",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "targetElement", "get_targetElement", null },
            .{ "onbegin", "get_onbegin", "set_onbegin" },
            .{ "onend", "get_onend", "set_onend" },
            .{ "onrepeat", "get_onrepeat", "set_onrepeat" },
            .{ "requiredExtensions", "get_requiredExtensions", null },
            .{ "systemLanguage", "get_systemLanguage", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            targetElement: ?*runtime.Instance = null,
            onbegin: typedefs.EventHandler = undefined,
            onend: typedefs.EventHandler = undefined,
            onrepeat: typedefs.EventHandler = undefined,
            requiredExtensions: *runtime.Instance = undefined,
            systemLanguage: *runtime.Instance = undefined,
            cached_requiredExtensions: ?*runtime.Instance = null,
            cached_systemLanguage: ?*runtime.Instance = null,
            _internal: ?*SVGAnimationElementImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onbegin = &get_onbegin,
        .get_onend = &get_onend,
        .get_onrepeat = &get_onrepeat,
        .get_requiredExtensions = &get_requiredExtensions,
        .get_systemLanguage = &get_systemLanguage,
        .get_targetElement = &get_targetElement,

        .set_onbegin = &set_onbegin,
        .set_onend = &set_onend,
        .set_onrepeat = &set_onrepeat,

        .call_beginElement = &call_beginElement,
        .call_beginElementAt = &call_beginElementAt,
        .call_endElement = &call_endElement,
        .call_endElementAt = &call_endElementAt,
        .call_getCurrentTime = &call_getCurrentTime,
        .call_getSimpleDuration = &call_getSimpleDuration,
        .call_getStartTime = &call_getStartTime,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("SVGAnimationElement has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(SVGAnimationElementImpl, "init") and @hasDecl(SVGAnimationElementImpl, "initOwn")) @compileError("SVGAnimationElementImpl defines both init and initOwn");
        if (comptime @hasDecl(SVGAnimationElementImpl, "init")) return SVGAnimationElementImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(SVGAnimationElementImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try SVGAnimationElementImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SVGAnimationElementImpl, "init")) return false;
        if (comptime @hasDecl(SVGAnimationElementImpl, "construction_args")) {
            inline for (SVGAnimationElementImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(SVGAnimationElementImpl, "deinit") and @hasDecl(SVGAnimationElementImpl, "deinitOwn")) @compileError("SVGAnimationElementImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(SVGAnimationElementImpl, "deinit")) return SVGAnimationElementImpl.deinit(instance);
        if (comptime @hasDecl(SVGAnimationElementImpl, "deinitOwn")) SVGAnimationElementImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SVGAnimationElement")) {
            if (comptime @hasDecl(impls.SVGAnimationElement, "installHooks")) impls.SVGAnimationElement.installHooks();
        }
    }

    pub fn get_targetElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try SVGAnimationElementImpl.get_targetElement(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onbegin(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SVGAnimationElementImpl, "get_onbegin")) return try SVGAnimationElementImpl.get_onbegin(instance);
        return event_handlers.value(EventHandler, instance, "onbegin");
    }

    pub fn set_onbegin(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SVGAnimationElementImpl, "set_onbegin")) return try SVGAnimationElementImpl.set_onbegin(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onbegin", value);
    }

    pub fn get_onend(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SVGAnimationElementImpl, "get_onend")) return try SVGAnimationElementImpl.get_onend(instance);
        return event_handlers.value(EventHandler, instance, "onend");
    }

    pub fn set_onend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SVGAnimationElementImpl, "set_onend")) return try SVGAnimationElementImpl.set_onend(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onend", value);
    }

    pub fn get_onrepeat(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SVGAnimationElementImpl, "get_onrepeat")) return try SVGAnimationElementImpl.get_onrepeat(instance);
        return event_handlers.value(EventHandler, instance, "onrepeat");
    }

    pub fn set_onrepeat(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SVGAnimationElementImpl, "set_onrepeat")) return try SVGAnimationElementImpl.set_onrepeat(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onrepeat", value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_requiredExtensions(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_requiredExtensions) |cached| {
            return cached;
        }
        const value = try mixins.SVGTests.get_requiredExtensions(instance);
        state.own.cached_requiredExtensions = value;
        @import("dom").same_object_cache.made(instance, value, "requiredExtensions");
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_systemLanguage(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_systemLanguage) |cached| {
            return cached;
        }
        const value = try mixins.SVGTests.get_systemLanguage(instance);
        state.own.cached_systemLanguage = value;
        @import("dom").same_object_cache.made(instance, value, "systemLanguage");
        return value;
    }

    pub fn call_getStartTime(instance: *runtime.Instance) anyerror!f32 {
        return try SVGAnimationElementImpl.call_getStartTime(instance);
    }

    pub fn call_beginElementAt(instance: *runtime.Instance, offset: f32) anyerror!void {
        return try SVGAnimationElementImpl.call_beginElementAt(instance, offset);
    }

    pub fn call_endElementAt(instance: *runtime.Instance, offset: f32) anyerror!void {
        return try SVGAnimationElementImpl.call_endElementAt(instance, offset);
    }

    pub fn call_getCurrentTime(instance: *runtime.Instance) anyerror!f32 {
        return try SVGAnimationElementImpl.call_getCurrentTime(instance);
    }

    pub fn call_getSimpleDuration(instance: *runtime.Instance) anyerror!f32 {
        return try SVGAnimationElementImpl.call_getSimpleDuration(instance);
    }

    pub fn call_endElement(instance: *runtime.Instance) anyerror!void {
        return try SVGAnimationElementImpl.call_endElement(instance);
    }

    pub fn call_beginElement(instance: *runtime.Instance) anyerror!void {
        return try SVGAnimationElementImpl.call_beginElement(instance);
    }

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "call_beginElementAt", 0b1 },
        .{ "call_endElementAt", 0b1 },
    };
};
