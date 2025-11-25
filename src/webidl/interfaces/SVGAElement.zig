//! Generated from: SVG.idl
//! Generated at: 2025-11-25T14:21:40Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SVGAElementImpl = @import("impls").SVGAElement;
const SVGGraphicsElement = @import("interfaces").SVGGraphicsElement;
const SVGURIReference = @import("interfaces").SVGURIReference;
const HTMLHyperlinkElementUtils = @import("interfaces").HTMLHyperlinkElementUtils;
const DOMStringMap = @import("interfaces").DOMStringMap;
const CSSOMString = @import("typedefs").CSSOMString;
const HTMLCollection = @import("interfaces").HTMLCollection;
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
const DOMMatrix = @import("interfaces").DOMMatrix;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const FocusableAreasOption = @import("dictionaries").FocusableAreasOption;
const EventListener = @import("interfaces").EventListener;
const CSSStyleProperties = @import("interfaces").CSSStyleProperties;
const CSSPseudoElement = @import("interfaces").CSSPseudoElement;
const SVGStringList = @import("interfaces").SVGStringList;
const ViewTransitionUpdateCallback = @import("callbacks").ViewTransitionUpdateCallback;
const Node = @import("interfaces").Node;
const CustomElementRegistry = @import("interfaces").CustomElementRegistry;
const Animation = @import("interfaces").Animation;
const Range = @import("interfaces").Range;
const Event = @import("interfaces").Event;
const FocusOptions = @import("dictionaries").FocusOptions;
const SVGBoundingBoxOptions = @import("dictionaries").SVGBoundingBoxOptions;
const SVGAnimatedTransformList = @import("interfaces").SVGAnimatedTransformList;
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
const SVGUseElement = @import("interfaces").SVGUseElement;
const KeyframeAnimationOptions = @import("dictionaries").KeyframeAnimationOptions;
const StylePropertyMapReadOnly = @import("interfaces").StylePropertyMapReadOnly;
const DOMTokenList = @import("interfaces").DOMTokenList;
const StartViewTransitionOptions = @import("dictionaries").StartViewTransitionOptions;
const DOMRect = @import("interfaces").DOMRect;
const ViewTransition = @import("interfaces").ViewTransition;
const SpatialNavigationSearchOptions = @import("dictionaries").SpatialNavigationSearchOptions;
const GetAnimationsOptions = @import("dictionaries").GetAnimationsOptions;
const SVGAnimatedString = @import("interfaces").SVGAnimatedString;
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
const SVGSVGElement = @import("interfaces").SVGSVGElement;
const SVGElement = @import("interfaces").SVGElement;

pub const SVGAElement = struct {
    pub const Meta = struct {
        pub const name = "SVGAElement";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *SVGGraphicsElement;
        pub const MixinTypes = &.{
            SVGURIReference,
            HTMLHyperlinkElementUtils,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "target", "get_target", null },
            .{ "download", "get_download", "set_download" },
            .{ "ping", "get_ping", "set_ping" },
            .{ "rel", "get_rel", "set_rel" },
            .{ "relList", "get_relList", null },
            .{ "hreflang", "get_hreflang", "set_hreflang" },
            .{ "type", "get_type", "set_type" },
            .{ "referrerPolicy", "get_referrerPolicy", "set_referrerPolicy" },
            .{ "href", "get_href", null },
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
            "focus",
            "blur",
            "getBBox",
            "getCTM",
            "getScreenCTM",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "target", "get_target", null },
            .{ "download", "get_download", "set_download" },
            .{ "ping", "get_ping", "set_ping" },
            .{ "rel", "get_rel", "set_rel" },
            .{ "relList", "get_relList", null },
            .{ "hreflang", "get_hreflang", "set_hreflang" },
            .{ "type", "get_type", "set_type" },
            .{ "referrerPolicy", "get_referrerPolicy", "set_referrerPolicy" },
            .{ "href", "get_href", null },
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
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            target: *runtime.Instance = undefined,
            download: runtime.DOMString = undefined,
            ping: runtime.USVString = undefined,
            rel: runtime.DOMString = undefined,
            relList: *runtime.Instance = undefined,
            hreflang: runtime.DOMString = undefined,
            @"type": runtime.DOMString = undefined,
            referrerPolicy: runtime.DOMString = undefined,
            href: *runtime.Instance = undefined,
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
            cached_target: ?*runtime.Instance = null,
            cached_relList: ?*runtime.Instance = null,
            cached_href: ?*runtime.Instance = null,
            _internal: ?*SVGAElementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_download = &get_download,
        .get_hash = &get_hash,
        .get_host = &get_host,
        .get_hostname = &get_hostname,
        .get_href = &get_href,
        .get_hreflang = &get_hreflang,
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
        .get_target = &get_target,
        .get_type = &get_type,
        .get_username = &get_username,

        .set_download = &set_download,
        .set_hash = &set_hash,
        .set_host = &set_host,
        .set_hostname = &set_hostname,
        .set_hreflang = &set_hreflang,
        .set_password = &set_password,
        .set_pathname = &set_pathname,
        .set_ping = &set_ping,
        .set_port = &set_port,
        .set_protocol = &set_protocol,
        .set_referrerPolicy = &set_referrerPolicy,
        .set_rel = &set_rel,
        .set_search = &set_search,
        .set_type = &set_type,
        .set_username = &set_username,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SVGAElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SVGAElementImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_target(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_target) |cached| {
            return cached;
        }
        const value = try SVGAElementImpl.get_target(instance);
        state.own.cached_target = value;
        return value;
    }

    pub fn get_download(instance: *runtime.Instance) anyerror!DOMString {
        return try SVGAElementImpl.get_download(instance);
    }

    pub fn set_download(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try SVGAElementImpl.set_download(instance, value);
    }

    pub fn get_ping(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try SVGAElementImpl.get_ping(instance);
    }

    pub fn set_ping(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try SVGAElementImpl.set_ping(instance, value);
    }

    pub fn get_rel(instance: *runtime.Instance) anyerror!DOMString {
        return try SVGAElementImpl.get_rel(instance);
    }

    pub fn set_rel(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try SVGAElementImpl.set_rel(instance, value);
    }

    /// Extended attributes: [SameObject], [PutForwards=value]
    pub fn get_relList(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_relList) |cached| {
            return cached;
        }
        const value = try SVGAElementImpl.get_relList(instance);
        state.own.cached_relList = value;
        return value;
    }

    pub fn get_hreflang(instance: *runtime.Instance) anyerror!DOMString {
        return try SVGAElementImpl.get_hreflang(instance);
    }

    pub fn set_hreflang(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try SVGAElementImpl.set_hreflang(instance, value);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try SVGAElementImpl.get_type(instance);
    }

    pub fn set_type(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try SVGAElementImpl.set_type(instance, value);
    }

    pub fn get_referrerPolicy(instance: *runtime.Instance) anyerror!DOMString {
        return try SVGAElementImpl.get_referrerPolicy(instance);
    }

    pub fn set_referrerPolicy(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try SVGAElementImpl.set_referrerPolicy(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_href(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_href) |cached| {
            return cached;
        }
        const value = try SVGAElementImpl.get_href(instance);
        state.own.cached_href = value;
        return value;
    }

    pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try SVGAElementImpl.get_origin(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try SVGAElementImpl.get_protocol(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_protocol(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGAElementImpl.set_protocol(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_username(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try SVGAElementImpl.get_username(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_username(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGAElementImpl.set_username(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_password(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try SVGAElementImpl.get_password(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_password(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGAElementImpl.set_password(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_host(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try SVGAElementImpl.get_host(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_host(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGAElementImpl.set_host(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_hostname(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try SVGAElementImpl.get_hostname(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_hostname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGAElementImpl.set_hostname(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_port(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try SVGAElementImpl.get_port(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_port(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGAElementImpl.set_port(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_pathname(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try SVGAElementImpl.get_pathname(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_pathname(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGAElementImpl.set_pathname(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_search(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try SVGAElementImpl.get_search(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_search(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGAElementImpl.set_search(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_hash(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try SVGAElementImpl.get_hash(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_hash(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try SVGAElementImpl.set_hash(instance, value);
    }

};
