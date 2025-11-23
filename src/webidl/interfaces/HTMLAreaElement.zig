//! Generated from: html.idl
//! Generated at: 2025-11-23T19:57:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HTMLAreaElementImpl = @import("impls").HTMLAreaElement;
const HTMLElement = @import("interfaces").HTMLElement;
const HTMLAttributionSrcElementUtils = @import("interfaces").HTMLAttributionSrcElementUtils;
const HTMLHyperlinkElementUtils = @import("interfaces").HTMLHyperlinkElementUtils;
const DOMStringMap = @import("interfaces").DOMStringMap;
const CSSOMString = @import("typedefs").CSSOMString;
const HTMLCollection = @import("interfaces").HTMLCollection;
const TogglePopoverOptions = @import("dictionaries").TogglePopoverOptions;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const GeometryNode = @import("typedefs").GeometryNode;
const NamedNodeMap = @import("interfaces").NamedNodeMap;
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const USVString = @import("interfaces").USVString;
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
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *HTMLElement;
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
            .{ "relList", "get_relList", null },
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
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
            .{ "relList", "get_relList", null },
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
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            alt: runtime.DOMString = undefined,
            coords: runtime.DOMString = undefined,
            shape: runtime.DOMString = undefined,
            target: runtime.DOMString = undefined,
            download: runtime.DOMString = undefined,
            ping: runtime.USVString = undefined,
            rel: runtime.DOMString = undefined,
            relList: *runtime.Instance = undefined,
            referrerPolicy: runtime.DOMString = undefined,
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
        .set_search = &set_search,
        .set_shape = &set_shape,
        .set_target = &set_target,
        .set_username = &set_username,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLAreaElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLAreaElementImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLAreaElementImpl.call_constructor(allocator, ctx);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_alt(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLAreaElementImpl.get_alt(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_alt(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLAreaElementImpl.set_alt(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_coords(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLAreaElementImpl.get_coords(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_coords(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLAreaElementImpl.set_coords(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_shape(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLAreaElementImpl.get_shape(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_shape(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLAreaElementImpl.set_shape(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_target(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLAreaElementImpl.get_target(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_target(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLAreaElementImpl.set_target(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_download(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLAreaElementImpl.get_download(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_download(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLAreaElementImpl.set_download(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_ping(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLAreaElementImpl.get_ping(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_ping(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLAreaElementImpl.set_ping(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_rel(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLAreaElementImpl.get_rel(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_rel(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLAreaElementImpl.set_rel(instance, value);
    }

    /// Extended attributes: [SameObject], [PutForwards=value], [Reflect="rel"]
    pub fn get_relList(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_relList) |cached| {
            return cached;
        }
        const value = try HTMLAreaElementImpl.get_relList(instance);
        state.own.cached_relList = value;
        return value;
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
        return try HTMLAreaElementImpl.get_noHref(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_noHref(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLAreaElementImpl.set_noHref(instance, value);
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

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLAreaElementImpl.get_href(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn set_href(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLAreaElementImpl.set_href(instance, value);
    }

    pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLAreaElementImpl.get_origin(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLAreaElementImpl.get_protocol(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_protocol(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLAreaElementImpl.set_protocol(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_username(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLAreaElementImpl.get_username(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_username(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLAreaElementImpl.set_username(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_password(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLAreaElementImpl.get_password(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_password(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLAreaElementImpl.set_password(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_host(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLAreaElementImpl.get_host(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_host(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLAreaElementImpl.set_host(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_hostname(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLAreaElementImpl.get_hostname(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_hostname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLAreaElementImpl.set_hostname(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_port(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLAreaElementImpl.get_port(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_port(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLAreaElementImpl.set_port(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_pathname(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLAreaElementImpl.get_pathname(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_pathname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLAreaElementImpl.set_pathname(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_search(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLAreaElementImpl.get_search(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_search(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLAreaElementImpl.set_search(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_hash(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLAreaElementImpl.get_hash(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_hash(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLAreaElementImpl.set_hash(instance, value);
    }

};
