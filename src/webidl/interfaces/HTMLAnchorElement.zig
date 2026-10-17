//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLAnchorElementImpl = @import("impls").HTMLAnchorElement;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const HTMLElement = @import("interfaces").HTMLElement;
const HyperlinkElementUtils = @import("mixins").HyperlinkElementUtils;
const HTMLHyperlinkElementUtils = @import("mixins").HTMLHyperlinkElementUtils;
const DOMStringMap = @import("interfaces").DOMStringMap;
const CSSOMString = @import("typedefs").CSSOMString;
const HTMLCollection = @import("interfaces").HTMLCollection;
const TogglePopoverOptions = @import("dictionaries").TogglePopoverOptions;
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
const ShowPopoverOptions = @import("dictionaries").ShowPopoverOptions;
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
const EditContext = @import("interfaces").EditContext;
const DOMRect = @import("interfaces").DOMRect;
const ElementInternals = @import("interfaces").ElementInternals;
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

pub const HTMLAnchorElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLAnchorElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = HTMLElement.State;
        pub const ParentInterface = HTMLElement;
        pub const MixinTypes = &.{
            HyperlinkElementUtils,
            HTMLHyperlinkElementUtils,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "download", "get_download", "set_download" },
            .{ "ping", "get_ping", "set_ping" },
            .{ "rel", "get_rel", "set_rel" },
            .{ "relList", "get_relList", "set_relList" },
            .{ "text", "get_text", "set_text" },
            .{ "referrerPolicy", "get_referrerPolicy", "set_referrerPolicy" },
            .{ "coords", "get_coords", "set_coords" },
            .{ "charset", "get_charset", "set_charset" },
            .{ "name", "get_name", "set_name" },
            .{ "rev", "get_rev", "set_rev" },
            .{ "shape", "get_shape", "set_shape" },
            .{ "attributionSourceId", "get_attributionSourceId", "set_attributionSourceId" },
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
            .{ "href", "get_href", "set_href" },
            .{ "target", "get_target", "set_target" },
        };

        /// [PutForwards] attributes: setting the attribute forwards to a property on the value
        /// Format: { "attrName", "forwardedProperty" }
        pub const put_forwards_attributes = .{
            .{ "relList", "value" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "toString", "get_href", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toString",
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
            "click",
            "attachInternals",
            "showPopover",
            "hidePopover",
            "togglePopover",
            "focus",
            "blur",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "download", "get_download", "set_download" },
            .{ "ping", "get_ping", "set_ping" },
            .{ "rel", "get_rel", "set_rel" },
            .{ "relList", "get_relList", "set_relList" },
            .{ "text", "get_text", "set_text" },
            .{ "referrerPolicy", "get_referrerPolicy", "set_referrerPolicy" },
            .{ "coords", "get_coords", "set_coords" },
            .{ "charset", "get_charset", "set_charset" },
            .{ "name", "get_name", "set_name" },
            .{ "rev", "get_rev", "set_rev" },
            .{ "shape", "get_shape", "set_shape" },
            .{ "attributionSourceId", "get_attributionSourceId", "set_attributionSourceId" },
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
            .{ "href", "get_href", "set_href" },
            .{ "target", "get_target", "set_target" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    /// HTML 3.2.3 [HTMLConstructor]: the constructor's steps are HTML's "HTML
    /// element constructors" - the binding runs them with
    /// engine.HostHooks.htmlConstructor.
    pub const html_constructor = true;

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            download: runtime.DOMString = undefined,
            ping: runtime.USVString = undefined,
            rel: runtime.DOMString = undefined,
            relList: *runtime.Instance = undefined,
            text: runtime.DOMString = undefined,
            referrerPolicy: runtime.DOMString = undefined,
            coords: runtime.DOMString = undefined,
            charset: runtime.DOMString = undefined,
            name: runtime.DOMString = undefined,
            rev: runtime.DOMString = undefined,
            shape: runtime.DOMString = undefined,
            attributionSourceId: u32 = undefined,
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
            href: runtime.USVString = undefined,
            target: runtime.DOMString = undefined,
            cached_relList: ?*runtime.Instance = null,
            _internal: ?*HTMLAnchorElementImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_attributionSourceId = &get_attributionSourceId,
        .get_charset = &get_charset,
        .get_coords = &get_coords,
        .get_download = &get_download,
        .get_hash = &get_hash,
        .get_host = &get_host,
        .get_hostname = &get_hostname,
        .get_href = &get_href,
        .get_hreflang = &get_hreflang,
        .get_name = &get_name,
        .get_origin = &get_origin,
        .get_password = &get_password,
        .get_pathname = &get_pathname,
        .get_ping = &get_ping,
        .get_port = &get_port,
        .get_protocol = &get_protocol,
        .get_referrerPolicy = &get_referrerPolicy,
        .get_rel = &get_rel,
        .get_relList = &get_relList,
        .get_rev = &get_rev,
        .get_search = &get_search,
        .get_shape = &get_shape,
        .get_target = &get_target,
        .get_text = &get_text,
        .get_type = &get_type,
        .get_username = &get_username,

        .set_attributionSourceId = &set_attributionSourceId,
        .set_charset = &set_charset,
        .set_coords = &set_coords,
        .set_download = &set_download,
        .set_hash = &set_hash,
        .set_host = &set_host,
        .set_hostname = &set_hostname,
        .set_href = &set_href,
        .set_hreflang = &set_hreflang,
        .set_name = &set_name,
        .set_password = &set_password,
        .set_pathname = &set_pathname,
        .set_ping = &set_ping,
        .set_port = &set_port,
        .set_protocol = &set_protocol,
        .set_referrerPolicy = &set_referrerPolicy,
        .set_rel = &set_rel,
        .set_relList = &set_relList,
        .set_rev = &set_rev,
        .set_search = &set_search,
        .set_shape = &set_shape,
        .set_target = &set_target,
        .set_text = &set_text,
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
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("HTMLAnchorElement has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(HTMLAnchorElementImpl, "init") and @hasDecl(HTMLAnchorElementImpl, "initOwn")) @compileError("HTMLAnchorElementImpl defines both init and initOwn");
        if (comptime @hasDecl(HTMLAnchorElementImpl, "init")) return HTMLAnchorElementImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(HTMLAnchorElementImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try HTMLAnchorElementImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(HTMLAnchorElementImpl, "init")) return false;
        if (comptime @hasDecl(HTMLAnchorElementImpl, "construction_args")) {
            inline for (HTMLAnchorElementImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(HTMLAnchorElementImpl, "deinit") and @hasDecl(HTMLAnchorElementImpl, "deinitOwn")) @compileError("HTMLAnchorElementImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(HTMLAnchorElementImpl, "deinit")) return HTMLAnchorElementImpl.deinit(instance);
        if (comptime @hasDecl(HTMLAnchorElementImpl, "deinitOwn")) HTMLAnchorElementImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "HTMLAnchorElement")) {
            if (comptime @hasDecl(impls.HTMLAnchorElement, "installHooks")) impls.HTMLAnchorElement.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLAnchorElementImpl.call_constructor(ctx);
    }

    const reflection = @import("dom").reflection;

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_download(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(HTMLAnchorElementImpl, "get_download")) return try HTMLAnchorElementImpl.get_download(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "download" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_download(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLAnchorElementImpl, "set_download")) return try HTMLAnchorElementImpl.set_download(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "download" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_ping(instance: *runtime.Instance) anyerror!runtime.USVString {
        if (comptime @hasDecl(HTMLAnchorElementImpl, "get_ping")) return try HTMLAnchorElementImpl.get_ping(instance);
        return try reflection.get(runtime.USVString, instance, .{ .name = "ping" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_ping(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLAnchorElementImpl, "set_ping")) return try HTMLAnchorElementImpl.set_ping(instance, value);
        try reflection.set(runtime.USVString, instance, .{ .name = "ping" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_rel(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(HTMLAnchorElementImpl, "get_rel")) return try HTMLAnchorElementImpl.get_rel(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "rel" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_rel(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLAnchorElementImpl, "set_rel")) return try HTMLAnchorElementImpl.set_rel(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "rel" }, value);
    }

    /// Extended attributes: [SameObject], [PutForwards=value], [Reflect="rel"]
    pub fn get_relList(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_relList) |cached| {
            return cached;
        }
        const value = if (comptime @hasDecl(HTMLAnchorElementImpl, "get_relList")) try HTMLAnchorElementImpl.get_relList(instance) else try reflection.get(*runtime.Instance, instance, .{ .name = "rel" });
        state.own.cached_relList = value;
        @import("dom").same_object_cache.made(instance, value, "relList");
        return value;
    }

    /// Extended attributes: [SameObject], [PutForwards=value], [Reflect="rel"]
    pub fn set_relList(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [PutForwards] - Get target object and set the forwarded property
        // Per WebIDL spec: setting 'relList' forwards to 'value' on the attribute's value
        const target = try get_relList(instance);

        // Use JavaScript [[Set]] semantics to set the forwarded property
        // This respects prototype chain and user-defined setters
        try runtime.setPropertyOnInstance(target, "value", value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_text(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try HTMLAnchorElementImpl.get_text(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_text(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try HTMLAnchorElementImpl.set_text(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_referrerPolicy(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try HTMLAnchorElementImpl.get_referrerPolicy(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_referrerPolicy(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try HTMLAnchorElementImpl.set_referrerPolicy(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_coords(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(HTMLAnchorElementImpl, "get_coords")) return try HTMLAnchorElementImpl.get_coords(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "coords" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_coords(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLAnchorElementImpl, "set_coords")) return try HTMLAnchorElementImpl.set_coords(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "coords" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_charset(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(HTMLAnchorElementImpl, "get_charset")) return try HTMLAnchorElementImpl.get_charset(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "charset" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_charset(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLAnchorElementImpl, "set_charset")) return try HTMLAnchorElementImpl.set_charset(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "charset" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(HTMLAnchorElementImpl, "get_name")) return try HTMLAnchorElementImpl.get_name(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "name" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_name(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLAnchorElementImpl, "set_name")) return try HTMLAnchorElementImpl.set_name(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "name" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_rev(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(HTMLAnchorElementImpl, "get_rev")) return try HTMLAnchorElementImpl.get_rev(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "rev" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_rev(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLAnchorElementImpl, "set_rev")) return try HTMLAnchorElementImpl.set_rev(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "rev" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_shape(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(HTMLAnchorElementImpl, "get_shape")) return try HTMLAnchorElementImpl.get_shape(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "shape" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_shape(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLAnchorElementImpl, "set_shape")) return try HTMLAnchorElementImpl.set_shape(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "shape" }, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_attributionSourceId(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLAnchorElementImpl.get_attributionSourceId(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_attributionSourceId(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try HTMLAnchorElementImpl.set_attributionSourceId(instance, value);
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

    /// Extended attributes: [CEReactions], [ReflectSetter], [Stringifier]
    pub const get_href = mixins.HTMLHyperlinkElementUtils.get_href;
    pub const set_href = mixins.HTMLHyperlinkElementUtils.set_href;

    /// Extended attributes: [CEReactions], [Reflect]
    pub const get_target = mixins.HTMLHyperlinkElementUtils.get_target;
    pub const set_target = mixins.HTMLHyperlinkElementUtils.set_target;

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "set_download",
        "set_ping",
        "set_rel",
        "set_text",
        "set_referrerPolicy",
        "set_coords",
        "set_charset",
        "set_name",
        "set_rev",
        "set_shape",
        "set_attributionSourceId",
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
        "set_href",
        "set_target",
    };
};
