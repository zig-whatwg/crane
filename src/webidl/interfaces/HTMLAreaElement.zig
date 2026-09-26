//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLAreaElementImpl = @import("impls").HTMLAreaElement;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const HTMLElement = @import("interfaces").HTMLElement;
const HTMLAttributionSrcElementUtils = @import("mixins").HTMLAttributionSrcElementUtils;
const HTMLHyperlinkElementUtils = @import("mixins").HTMLHyperlinkElementUtils;
const DOMStringMap = @import("interfaces").DOMStringMap;
const CSSOMString = @import("typedefs").CSSOMString;
const HTMLCollection = @import("interfaces").HTMLCollection;
const TogglePopoverOptions = @import("dictionaries").TogglePopoverOptions;
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
const ShowPopoverOptions = @import("dictionaries").ShowPopoverOptions;
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
const KeyframeAnimationOptions = @import("dictionaries").KeyframeAnimationOptions;
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
const Observable = @import("interfaces").Observable;
const DOMPoint = @import("interfaces").DOMPoint;
const PointerLockOptions = @import("dictionaries").PointerLockOptions;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const ShadowRootInit = @import("dictionaries").ShadowRootInit;

pub const HTMLAreaElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLAreaElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = HTMLElement.State;
        pub const ParentInterface = HTMLElement;
        pub const MixinTypes = &.{
            HTMLAttributionSrcElementUtils,
            HTMLHyperlinkElementUtils,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "alt", "get_alt", "set_alt" },
            .{ "coords", "get_coords", "set_coords" },
            .{ "shape", "get_shape", "set_shape" },
            .{ "target", "get_target", "set_target" },
            .{ "download", "get_download", "set_download" },
            .{ "ping", "get_ping", "set_ping" },
            .{ "rel", "get_rel", "set_rel" },
            .{ "relList", "get_relList", "set_relList" },
            .{ "referrerPolicy", "get_referrerPolicy", "set_referrerPolicy" },
            .{ "noHref", "get_noHref", "set_noHref" },
            .{ "attributionSrc", "get_attributionSrc", "set_attributionSrc" },
            .{ "href", "get_href", "set_href" },
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
            .{ "alt", "get_alt", "set_alt" },
            .{ "coords", "get_coords", "set_coords" },
            .{ "shape", "get_shape", "set_shape" },
            .{ "target", "get_target", "set_target" },
            .{ "download", "get_download", "set_download" },
            .{ "ping", "get_ping", "set_ping" },
            .{ "rel", "get_rel", "set_rel" },
            .{ "relList", "get_relList", "set_relList" },
            .{ "referrerPolicy", "get_referrerPolicy", "set_referrerPolicy" },
            .{ "noHref", "get_noHref", "set_noHref" },
            .{ "attributionSrc", "get_attributionSrc", "set_attributionSrc" },
            .{ "href", "get_href", "set_href" },
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
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            alt: typedefs.DOMString = undefined,
            coords: typedefs.DOMString = undefined,
            shape: typedefs.DOMString = undefined,
            target: typedefs.DOMString = undefined,
            download: typedefs.DOMString = undefined,
            ping: runtime.USVString = undefined,
            rel: typedefs.DOMString = undefined,
            relList: *runtime.Instance = undefined,
            referrerPolicy: typedefs.DOMString = undefined,
            noHref: bool = undefined,
            attributionSrc: runtime.USVString = undefined,
            href: runtime.USVString = undefined,
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
            cached_relList: ?*runtime.Instance = null,
            _internal: ?*HTMLAreaElementImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_alt = &get_alt,
        .get_attributionSrc = &get_attributionSrc,
        .get_coords = &get_coords,
        .get_download = &get_download,
        .get_hash = &get_hash,
        .get_host = &get_host,
        .get_hostname = &get_hostname,
        .get_href = &get_href,
        .get_noHref = &get_noHref,
        .get_origin = &get_origin,
        .get_password = &get_password,
        .get_pathname = &get_pathname,
        .get_ping = &get_ping,
        .get_port = &get_port,
        .get_protocol = &get_protocol,
        .get_referrerPolicy = &get_referrerPolicy,
        .get_rel = &get_rel,
        .get_relList = &get_relList,
        .get_search = &get_search,
        .get_shape = &get_shape,
        .get_target = &get_target,
        .get_username = &get_username,

        .set_alt = &set_alt,
        .set_attributionSrc = &set_attributionSrc,
        .set_coords = &set_coords,
        .set_download = &set_download,
        .set_hash = &set_hash,
        .set_host = &set_host,
        .set_hostname = &set_hostname,
        .set_href = &set_href,
        .set_noHref = &set_noHref,
        .set_password = &set_password,
        .set_pathname = &set_pathname,
        .set_ping = &set_ping,
        .set_port = &set_port,
        .set_protocol = &set_protocol,
        .set_referrerPolicy = &set_referrerPolicy,
        .set_rel = &set_rel,
        .set_relList = &set_relList,
        .set_search = &set_search,
        .set_shape = &set_shape,
        .set_target = &set_target,
        .set_username = &set_username,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLAreaElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return HTMLAreaElementImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLAreaElementImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLAreaElementImpl.call_constructor(ctx);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    const reflection = @import("impls").reflection;

    pub fn get_alt(instance: *runtime.Instance) anyerror!DOMString {
        if (comptime @hasDecl(HTMLAreaElementImpl, "get_alt")) return try HTMLAreaElementImpl.get_alt(instance);
        return try reflection.get(DOMString, instance, .{ .name = "alt" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_alt(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        if (comptime @hasDecl(HTMLAreaElementImpl, "set_alt")) return try HTMLAreaElementImpl.set_alt(instance, value);
        try reflection.set(DOMString, instance, .{ .name = "alt" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_coords(instance: *runtime.Instance) anyerror!DOMString {
        if (comptime @hasDecl(HTMLAreaElementImpl, "get_coords")) return try HTMLAreaElementImpl.get_coords(instance);
        return try reflection.get(DOMString, instance, .{ .name = "coords" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_coords(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        if (comptime @hasDecl(HTMLAreaElementImpl, "set_coords")) return try HTMLAreaElementImpl.set_coords(instance, value);
        try reflection.set(DOMString, instance, .{ .name = "coords" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_shape(instance: *runtime.Instance) anyerror!DOMString {
        if (comptime @hasDecl(HTMLAreaElementImpl, "get_shape")) return try HTMLAreaElementImpl.get_shape(instance);
        return try reflection.get(DOMString, instance, .{ .name = "shape" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_shape(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        if (comptime @hasDecl(HTMLAreaElementImpl, "set_shape")) return try HTMLAreaElementImpl.set_shape(instance, value);
        try reflection.set(DOMString, instance, .{ .name = "shape" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_target(instance: *runtime.Instance) anyerror!DOMString {
        if (comptime @hasDecl(HTMLAreaElementImpl, "get_target")) return try HTMLAreaElementImpl.get_target(instance);
        return try reflection.get(DOMString, instance, .{ .name = "target" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_target(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        if (comptime @hasDecl(HTMLAreaElementImpl, "set_target")) return try HTMLAreaElementImpl.set_target(instance, value);
        try reflection.set(DOMString, instance, .{ .name = "target" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_download(instance: *runtime.Instance) anyerror!DOMString {
        if (comptime @hasDecl(HTMLAreaElementImpl, "get_download")) return try HTMLAreaElementImpl.get_download(instance);
        return try reflection.get(DOMString, instance, .{ .name = "download" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_download(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        if (comptime @hasDecl(HTMLAreaElementImpl, "set_download")) return try HTMLAreaElementImpl.set_download(instance, value);
        try reflection.set(DOMString, instance, .{ .name = "download" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_ping(instance: *runtime.Instance) anyerror!runtime.USVString {
        if (comptime @hasDecl(HTMLAreaElementImpl, "get_ping")) return try HTMLAreaElementImpl.get_ping(instance);
        return try reflection.get(runtime.USVString, instance, .{ .name = "ping" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_ping(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        if (comptime @hasDecl(HTMLAreaElementImpl, "set_ping")) return try HTMLAreaElementImpl.set_ping(instance, value);
        try reflection.set(runtime.USVString, instance, .{ .name = "ping" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_rel(instance: *runtime.Instance) anyerror!DOMString {
        if (comptime @hasDecl(HTMLAreaElementImpl, "get_rel")) return try HTMLAreaElementImpl.get_rel(instance);
        return try reflection.get(DOMString, instance, .{ .name = "rel" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_rel(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        if (comptime @hasDecl(HTMLAreaElementImpl, "set_rel")) return try HTMLAreaElementImpl.set_rel(instance, value);
        try reflection.set(DOMString, instance, .{ .name = "rel" }, value);
    }

    /// Extended attributes: [SameObject], [PutForwards=value], [Reflect="rel"]
    pub fn get_relList(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_relList) |cached| {
            return cached;
        }
        const value = if (comptime @hasDecl(HTMLAreaElementImpl, "get_relList")) try HTMLAreaElementImpl.get_relList(instance) else try reflection.get(*runtime.Instance, instance, .{ .name = "rel" });
        state.own.cached_relList = value;
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
    pub fn get_referrerPolicy(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLAreaElementImpl.get_referrerPolicy(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_referrerPolicy(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        try HTMLAreaElementImpl.set_referrerPolicy(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_noHref(instance: *runtime.Instance) anyerror!bool {
        if (comptime @hasDecl(HTMLAreaElementImpl, "get_noHref")) return try HTMLAreaElementImpl.get_noHref(instance);
        return try reflection.get(bool, instance, .{ .name = "nohref" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_noHref(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        if (comptime @hasDecl(HTMLAreaElementImpl, "set_noHref")) return try HTMLAreaElementImpl.set_noHref(instance, value);
        try reflection.set(bool, instance, .{ .name = "nohref" }, value);
    }

    /// Extended attributes: [CEReactions], [SecureContext]
    pub fn get_attributionSrc(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLAreaElementImpl.get_attributionSrc(instance);
    }

    /// Extended attributes: [CEReactions], [SecureContext]
    pub fn set_attributionSrc(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();

        try HTMLAreaElementImpl.set_attributionSrc(instance, value);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter], [Stringifier]
    pub const get_href = mixins.HTMLHyperlinkElementUtils.get_href;
    pub const set_href = mixins.HTMLHyperlinkElementUtils.set_href;

    pub const get_origin = mixins.HTMLHyperlinkElementUtils.get_origin;

    /// Extended attributes: [CEReactions]
    pub const get_protocol = mixins.HTMLHyperlinkElementUtils.get_protocol;
    pub const set_protocol = mixins.HTMLHyperlinkElementUtils.set_protocol;

    /// Extended attributes: [CEReactions]
    pub const get_username = mixins.HTMLHyperlinkElementUtils.get_username;
    pub const set_username = mixins.HTMLHyperlinkElementUtils.set_username;

    /// Extended attributes: [CEReactions]
    pub const get_password = mixins.HTMLHyperlinkElementUtils.get_password;
    pub const set_password = mixins.HTMLHyperlinkElementUtils.set_password;

    /// Extended attributes: [CEReactions]
    pub const get_host = mixins.HTMLHyperlinkElementUtils.get_host;
    pub const set_host = mixins.HTMLHyperlinkElementUtils.set_host;

    /// Extended attributes: [CEReactions]
    pub const get_hostname = mixins.HTMLHyperlinkElementUtils.get_hostname;
    pub const set_hostname = mixins.HTMLHyperlinkElementUtils.set_hostname;

    /// Extended attributes: [CEReactions]
    pub const get_port = mixins.HTMLHyperlinkElementUtils.get_port;
    pub const set_port = mixins.HTMLHyperlinkElementUtils.set_port;

    /// Extended attributes: [CEReactions]
    pub const get_pathname = mixins.HTMLHyperlinkElementUtils.get_pathname;
    pub const set_pathname = mixins.HTMLHyperlinkElementUtils.set_pathname;

    /// Extended attributes: [CEReactions]
    pub const get_search = mixins.HTMLHyperlinkElementUtils.get_search;
    pub const set_search = mixins.HTMLHyperlinkElementUtils.set_search;

    /// Extended attributes: [CEReactions]
    pub const get_hash = mixins.HTMLHyperlinkElementUtils.get_hash;
    pub const set_hash = mixins.HTMLHyperlinkElementUtils.set_hash;
};
