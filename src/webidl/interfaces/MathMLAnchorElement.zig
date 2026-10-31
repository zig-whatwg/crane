//! Generated from: mathml-core.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MathMLAnchorElementImpl = @import("impls").MathMLAnchorElement;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const MathMLElement = @import("interfaces").MathMLElement;
const HyperlinkElementUtils = @import("mixins").HyperlinkElementUtils;
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

pub const MathMLAnchorElement = struct {
    pub const Meta = struct {
        pub const name = "MathMLAnchorElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = MathMLElement.State;
        pub const ParentInterface = MathMLElement;
        pub const MixinTypes = &.{
            HyperlinkElementUtils,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "href", "get_href", "set_href" },
            .{ "target", "get_target", "set_target" },
            .{ "origin", "get_origin", null },
            .{ "protocol", "get_protocol", "set_protocol" },
            .{ "username", "get_username", "set_username" },
            .{ "password", "get_password", "set_password" },
            .{ "host", "get_host", "set_host" },
            .{ "hostname", "get_hostname", "set_hostname" },
            .{ "port", "get_port", "set_port" },
            .{ "pathname", "get_pathname", "set_pathname" },
            .{ "search", "get_search", "set_search" },
            .{ "hash", "get_hash", "set_hash" },
            .{ "hreflang", "get_hreflang", "set_hreflang" },
            .{ "type", "get_type", "set_type" },
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
            .{ "href", "get_href", "set_href" },
            .{ "target", "get_target", "set_target" },
            .{ "origin", "get_origin", null },
            .{ "protocol", "get_protocol", "set_protocol" },
            .{ "username", "get_username", "set_username" },
            .{ "password", "get_password", "set_password" },
            .{ "host", "get_host", "set_host" },
            .{ "hostname", "get_hostname", "set_hostname" },
            .{ "port", "get_port", "set_port" },
            .{ "pathname", "get_pathname", "set_pathname" },
            .{ "search", "get_search", "set_search" },
            .{ "hash", "get_hash", "set_hash" },
            .{ "hreflang", "get_hreflang", "set_hreflang" },
            .{ "type", "get_type", "set_type" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            href: runtime.USVString = undefined,
            target: runtime.DOMString = undefined,
            origin: runtime.USVString = undefined,
            protocol: runtime.USVString = undefined,
            username: runtime.USVString = undefined,
            password: runtime.USVString = undefined,
            host: runtime.USVString = undefined,
            hostname: runtime.USVString = undefined,
            port: runtime.USVString = undefined,
            pathname: runtime.USVString = undefined,
            search: runtime.USVString = undefined,
            hash: runtime.USVString = undefined,
            hreflang: runtime.DOMString = undefined,
            type: runtime.DOMString = undefined,
            _internal: ?*MathMLAnchorElementImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_hash = &get_hash,
        .get_host = &get_host,
        .get_hostname = &get_hostname,
        .get_href = &get_href,
        .get_hreflang = &get_hreflang,
        .get_origin = &get_origin,
        .get_password = &get_password,
        .get_pathname = &get_pathname,
        .get_port = &get_port,
        .get_protocol = &get_protocol,
        .get_search = &get_search,
        .get_target = &get_target,
        .get_type = &get_type,
        .get_username = &get_username,

        .set_hash = &set_hash,
        .set_host = &set_host,
        .set_hostname = &set_hostname,
        .set_href = &set_href,
        .set_hreflang = &set_hreflang,
        .set_password = &set_password,
        .set_pathname = &set_pathname,
        .set_port = &set_port,
        .set_protocol = &set_protocol,
        .set_search = &set_search,
        .set_target = &set_target,
        .set_type = &set_type,
        .set_username = &set_username,

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
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("MathMLAnchorElement has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(MathMLAnchorElementImpl, "init") and @hasDecl(MathMLAnchorElementImpl, "initOwn")) @compileError("MathMLAnchorElementImpl defines both init and initOwn");
        if (comptime @hasDecl(MathMLAnchorElementImpl, "init")) return MathMLAnchorElementImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(MathMLAnchorElementImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try MathMLAnchorElementImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(MathMLAnchorElementImpl, "init")) return false;
        if (comptime @hasDecl(MathMLAnchorElementImpl, "construction_args")) {
            inline for (MathMLAnchorElementImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(MathMLAnchorElementImpl, "deinit") and @hasDecl(MathMLAnchorElementImpl, "deinitOwn")) @compileError("MathMLAnchorElementImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(MathMLAnchorElementImpl, "deinit")) return MathMLAnchorElementImpl.deinit(instance);
        if (comptime @hasDecl(MathMLAnchorElementImpl, "deinitOwn")) MathMLAnchorElementImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "MathMLAnchorElement")) {
            if (comptime @hasDecl(impls.MathMLAnchorElement, "installHooks")) impls.MathMLAnchorElement.installHooks();
        }
    }

    const reflection = @import("dom").reflection;

    /// Extended attributes: [ReflectSetter]
    pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try MathMLAnchorElementImpl.get_href(instance);
    }

    /// Extended attributes: [ReflectSetter]
    pub fn set_href(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        if (comptime @hasDecl(MathMLAnchorElementImpl, "set_href")) return try MathMLAnchorElementImpl.set_href(instance, value);
        try reflection.set(runtime.USVString, instance, .{ .name = "href" }, value);
    }

    /// Extended attributes: [Reflect]
    pub fn get_target(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(MathMLAnchorElementImpl, "get_target")) return try MathMLAnchorElementImpl.get_target(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "target" });
    }

    /// Extended attributes: [Reflect]
    pub fn set_target(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        if (comptime @hasDecl(MathMLAnchorElementImpl, "set_target")) return try MathMLAnchorElementImpl.set_target(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "target" }, value);
    }

    pub const get_origin = mixins.HyperlinkElementUtils.get_origin;

    /// Extended attributes: [CEReactions]
    pub const get_protocol = mixins.HyperlinkElementUtils.get_protocol;
    pub const set_protocol = mixins.HyperlinkElementUtils.set_protocol;

    /// Extended attributes: [CEReactions]
    pub const get_username = mixins.HyperlinkElementUtils.get_username;
    pub const set_username = mixins.HyperlinkElementUtils.set_username;

    /// Extended attributes: [CEReactions]
    pub const get_password = mixins.HyperlinkElementUtils.get_password;
    pub const set_password = mixins.HyperlinkElementUtils.set_password;

    /// Extended attributes: [CEReactions]
    pub const get_host = mixins.HyperlinkElementUtils.get_host;
    pub const set_host = mixins.HyperlinkElementUtils.set_host;

    /// Extended attributes: [CEReactions]
    pub const get_hostname = mixins.HyperlinkElementUtils.get_hostname;
    pub const set_hostname = mixins.HyperlinkElementUtils.set_hostname;

    /// Extended attributes: [CEReactions]
    pub const get_port = mixins.HyperlinkElementUtils.get_port;
    pub const set_port = mixins.HyperlinkElementUtils.set_port;

    /// Extended attributes: [CEReactions]
    pub const get_pathname = mixins.HyperlinkElementUtils.get_pathname;
    pub const set_pathname = mixins.HyperlinkElementUtils.set_pathname;

    /// Extended attributes: [CEReactions]
    pub const get_search = mixins.HyperlinkElementUtils.get_search;
    pub const set_search = mixins.HyperlinkElementUtils.set_search;

    /// Extended attributes: [CEReactions]
    pub const get_hash = mixins.HyperlinkElementUtils.get_hash;
    pub const set_hash = mixins.HyperlinkElementUtils.set_hash;

    /// Extended attributes: [CEReactions], [Reflect]
    pub const get_hreflang = mixins.HyperlinkElementUtils.get_hreflang;
    pub const set_hreflang = mixins.HyperlinkElementUtils.set_hreflang;

    /// Extended attributes: [CEReactions], [Reflect]
    pub const get_type = mixins.HyperlinkElementUtils.get_type;
    pub const set_type = mixins.HyperlinkElementUtils.set_type;

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "set_protocol",
        "set_username",
        "set_password",
        "set_host",
        "set_hostname",
        "set_port",
        "set_pathname",
        "set_search",
        "set_hash",
        "set_hreflang",
        "set_type",
    };
};
