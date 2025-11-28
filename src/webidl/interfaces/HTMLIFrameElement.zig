//! Generated from: html.idl
//! Generated at: 2025-11-28T19:51:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLIFrameElementImpl = @import("impls").HTMLIFrameElement;
const mixins = @import("mixins");
const HTMLElement = @import("interfaces").HTMLElement;
const HTMLSharedStorageWritableElementUtils = @import("interfaces").HTMLSharedStorageWritableElementUtils;
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
const PermissionsPolicy = @import("interfaces").PermissionsPolicy;
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
const WindowProxy = @import("typedefs").WindowProxy;
const SpatialNavigationDirection = @import("enums").SpatialNavigationDirection;
const StylePropertyMap = @import("interfaces").StylePropertyMap;
const TrustedHTML = @import("interfaces").TrustedHTML;
const ShadowRoot = @import("interfaces").ShadowRoot;
const Attr = @import("interfaces").Attr;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const NodeList = @import("interfaces").NodeList;
const FullscreenOptions = @import("dictionaries").FullscreenOptions;
const Observable = @import("interfaces").Observable;
const DOMPoint = @import("interfaces").DOMPoint;
const PointerLockOptions = @import("dictionaries").PointerLockOptions;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const ShadowRootInit = @import("dictionaries").ShadowRootInit;

pub const HTMLIFrameElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLIFrameElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *HTMLElement;
        pub const MixinTypes = &.{
            HTMLSharedStorageWritableElementUtils,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "src", "get_src", "set_src" },
            .{ "srcdoc", "get_srcdoc", "set_srcdoc" },
            .{ "name", "get_name", "set_name" },
            .{ "sandbox", "get_sandbox", null },
            .{ "allow", "get_allow", "set_allow" },
            .{ "allowFullscreen", "get_allowFullscreen", "set_allowFullscreen" },
            .{ "width", "get_width", "set_width" },
            .{ "height", "get_height", "set_height" },
            .{ "referrerPolicy", "get_referrerPolicy", "set_referrerPolicy" },
            .{ "loading", "get_loading", "set_loading" },
            .{ "contentDocument", "get_contentDocument", null },
            .{ "contentWindow", "get_contentWindow", null },
            .{ "browsingTopics", "get_browsingTopics", "set_browsingTopics" },
            .{ "csp", "get_csp", "set_csp" },
            .{ "credentialless", "get_credentialless", "set_credentialless" },
            .{ "adAuctionHeaders", "get_adAuctionHeaders", "set_adAuctionHeaders" },
            .{ "align", "get_align", "set_align" },
            .{ "scrolling", "get_scrolling", "set_scrolling" },
            .{ "frameBorder", "get_frameBorder", "set_frameBorder" },
            .{ "longDesc", "get_longDesc", "set_longDesc" },
            .{ "marginHeight", "get_marginHeight", "set_marginHeight" },
            .{ "marginWidth", "get_marginWidth", "set_marginWidth" },
            .{ "privateToken", "get_privateToken", "set_privateToken" },
            .{ "permissionsPolicy", "get_permissionsPolicy", null },
            .{ "sharedStorageWritable", "get_sharedStorageWritable", "set_sharedStorageWritable" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getSVGDocument", "call_getSVGDocument", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getSVGDocument",
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
            .{ "src", "get_src", "set_src" },
            .{ "srcdoc", "get_srcdoc", "set_srcdoc" },
            .{ "name", "get_name", "set_name" },
            .{ "sandbox", "get_sandbox", null },
            .{ "allow", "get_allow", "set_allow" },
            .{ "allowFullscreen", "get_allowFullscreen", "set_allowFullscreen" },
            .{ "width", "get_width", "set_width" },
            .{ "height", "get_height", "set_height" },
            .{ "referrerPolicy", "get_referrerPolicy", "set_referrerPolicy" },
            .{ "loading", "get_loading", "set_loading" },
            .{ "contentDocument", "get_contentDocument", null },
            .{ "contentWindow", "get_contentWindow", null },
            .{ "browsingTopics", "get_browsingTopics", "set_browsingTopics" },
            .{ "csp", "get_csp", "set_csp" },
            .{ "credentialless", "get_credentialless", "set_credentialless" },
            .{ "adAuctionHeaders", "get_adAuctionHeaders", "set_adAuctionHeaders" },
            .{ "align", "get_align", "set_align" },
            .{ "scrolling", "get_scrolling", "set_scrolling" },
            .{ "frameBorder", "get_frameBorder", "set_frameBorder" },
            .{ "longDesc", "get_longDesc", "set_longDesc" },
            .{ "marginHeight", "get_marginHeight", "set_marginHeight" },
            .{ "marginWidth", "get_marginWidth", "set_marginWidth" },
            .{ "privateToken", "get_privateToken", "set_privateToken" },
            .{ "permissionsPolicy", "get_permissionsPolicy", null },
            .{ "sharedStorageWritable", "get_sharedStorageWritable", "set_sharedStorageWritable" },
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
            src: runtime.USVString = undefined,
            srcdoc: union(enum) {
                TrustedHTML: TrustedHTML,
                DOMString: runtime.DOMString,
            } = undefined,
            name: runtime.DOMString = undefined,
            sandbox: *runtime.Instance = undefined,
            allow: runtime.DOMString = undefined,
            allowFullscreen: bool = undefined,
            width: runtime.DOMString = undefined,
            height: runtime.DOMString = undefined,
            referrerPolicy: runtime.DOMString = undefined,
            loading: runtime.DOMString = undefined,
            contentDocument: ?*runtime.Instance = null,
            contentWindow: ?WindowProxy = null,
            browsingTopics: bool = undefined,
            csp: runtime.DOMString = undefined,
            credentialless: bool = undefined,
            adAuctionHeaders: bool = undefined,
            @"align": runtime.DOMString = undefined,
            scrolling: runtime.DOMString = undefined,
            frameBorder: runtime.DOMString = undefined,
            longDesc: runtime.USVString = undefined,
            marginHeight: runtime.DOMString = undefined,
            marginWidth: runtime.DOMString = undefined,
            privateToken: runtime.DOMString = undefined,
            permissionsPolicy: *runtime.Instance = undefined,
            sharedStorageWritable: bool = undefined,
            cached_sandbox: ?*runtime.Instance = null,
            cached_permissionsPolicy: ?*runtime.Instance = null,
            _internal: ?*HTMLIFrameElementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_adAuctionHeaders = &get_adAuctionHeaders,
        .get_align = &get_align,
        .get_allow = &get_allow,
        .get_allowFullscreen = &get_allowFullscreen,
        .get_browsingTopics = &get_browsingTopics,
        .get_contentDocument = &get_contentDocument,
        .get_contentWindow = &get_contentWindow,
        .get_credentialless = &get_credentialless,
        .get_csp = &get_csp,
        .get_frameBorder = &get_frameBorder,
        .get_height = &get_height,
        .get_loading = &get_loading,
        .get_longDesc = &get_longDesc,
        .get_marginHeight = &get_marginHeight,
        .get_marginWidth = &get_marginWidth,
        .get_name = &get_name,
        .get_permissionsPolicy = &get_permissionsPolicy,
        .get_privateToken = &get_privateToken,
        .get_referrerPolicy = &get_referrerPolicy,
        .get_sandbox = &get_sandbox,
        .get_scrolling = &get_scrolling,
        .get_sharedStorageWritable = &get_sharedStorageWritable,
        .get_src = &get_src,
        .get_srcdoc = &get_srcdoc,
        .get_width = &get_width,

        .set_adAuctionHeaders = &set_adAuctionHeaders,
        .set_align = &set_align,
        .set_allow = &set_allow,
        .set_allowFullscreen = &set_allowFullscreen,
        .set_browsingTopics = &set_browsingTopics,
        .set_credentialless = &set_credentialless,
        .set_csp = &set_csp,
        .set_frameBorder = &set_frameBorder,
        .set_height = &set_height,
        .set_loading = &set_loading,
        .set_longDesc = &set_longDesc,
        .set_marginHeight = &set_marginHeight,
        .set_marginWidth = &set_marginWidth,
        .set_name = &set_name,
        .set_privateToken = &set_privateToken,
        .set_referrerPolicy = &set_referrerPolicy,
        .set_scrolling = &set_scrolling,
        .set_sharedStorageWritable = &set_sharedStorageWritable,
        .set_src = &set_src,
        .set_srcdoc = &set_srcdoc,
        .set_width = &set_width,

        .call_getSVGDocument = &call_getSVGDocument,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLIFrameElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLIFrameElementImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLIFrameElementImpl.call_constructor(allocator, ctx);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn get_src(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLIFrameElementImpl.get_src(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn set_src(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLIFrameElementImpl.set_src(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_srcdoc(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLIFrameElementImpl.get_srcdoc(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_srcdoc(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLIFrameElementImpl.set_srcdoc(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLIFrameElementImpl.get_name(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_name(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLIFrameElementImpl.set_name(instance, value);
    }

    /// Extended attributes: [SameObject], [PutForwards=value], [Reflect]
    pub fn get_sandbox(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_sandbox) |cached| {
            return cached;
        }
        const value = try HTMLIFrameElementImpl.get_sandbox(instance);
        state.own.cached_sandbox = value;
        return value;
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_allow(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLIFrameElementImpl.get_allow(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_allow(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLIFrameElementImpl.set_allow(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_allowFullscreen(instance: *runtime.Instance) anyerror!bool {
        return try HTMLIFrameElementImpl.get_allowFullscreen(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_allowFullscreen(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLIFrameElementImpl.set_allowFullscreen(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_width(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLIFrameElementImpl.get_width(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_width(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLIFrameElementImpl.set_width(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_height(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLIFrameElementImpl.get_height(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_height(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLIFrameElementImpl.set_height(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_referrerPolicy(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLIFrameElementImpl.get_referrerPolicy(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_referrerPolicy(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLIFrameElementImpl.set_referrerPolicy(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_loading(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLIFrameElementImpl.get_loading(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_loading(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLIFrameElementImpl.set_loading(instance, value);
    }

    pub fn get_contentDocument(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try HTMLIFrameElementImpl.get_contentDocument(instance);
    }

    pub fn get_contentWindow(instance: *runtime.Instance) anyerror!?WindowProxy {
        return try HTMLIFrameElementImpl.get_contentWindow(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_browsingTopics(instance: *runtime.Instance) anyerror!bool {
        return try HTMLIFrameElementImpl.get_browsingTopics(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_browsingTopics(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLIFrameElementImpl.set_browsingTopics(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_csp(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLIFrameElementImpl.get_csp(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_csp(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLIFrameElementImpl.set_csp(instance, value);
    }

    pub fn get_credentialless(instance: *runtime.Instance) anyerror!bool {
        return try HTMLIFrameElementImpl.get_credentialless(instance);
    }

    pub fn set_credentialless(instance: *runtime.Instance, value: bool) anyerror!void {
        try HTMLIFrameElementImpl.set_credentialless(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_adAuctionHeaders(instance: *runtime.Instance) anyerror!bool {
        return try HTMLIFrameElementImpl.get_adAuctionHeaders(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_adAuctionHeaders(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLIFrameElementImpl.set_adAuctionHeaders(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_align(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLIFrameElementImpl.get_align(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_align(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLIFrameElementImpl.set_align(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_scrolling(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLIFrameElementImpl.get_scrolling(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_scrolling(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLIFrameElementImpl.set_scrolling(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_frameBorder(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLIFrameElementImpl.get_frameBorder(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_frameBorder(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLIFrameElementImpl.set_frameBorder(instance, value);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn get_longDesc(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLIFrameElementImpl.get_longDesc(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn set_longDesc(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLIFrameElementImpl.set_longDesc(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect], [LegacyNullToEmptyString]
    pub fn get_marginHeight(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLIFrameElementImpl.get_marginHeight(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect], [LegacyNullToEmptyString]
    pub fn set_marginHeight(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLIFrameElementImpl.set_marginHeight(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect], [LegacyNullToEmptyString]
    pub fn get_marginWidth(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLIFrameElementImpl.get_marginWidth(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect], [LegacyNullToEmptyString]
    pub fn set_marginWidth(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLIFrameElementImpl.set_marginWidth(instance, value);
    }

    /// Extended attributes: [SecureContext]
    pub fn get_privateToken(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLIFrameElementImpl.get_privateToken(instance);
    }

    /// Extended attributes: [SecureContext]
    pub fn set_privateToken(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try HTMLIFrameElementImpl.set_privateToken(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_permissionsPolicy(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_permissionsPolicy) |cached| {
            return cached;
        }
        const value = try HTMLIFrameElementImpl.get_permissionsPolicy(instance);
        state.own.cached_permissionsPolicy = value;
        return value;
    }

    /// Extended attributes: [CEReactions], [SecureContext]
    pub fn get_sharedStorageWritable(instance: *runtime.Instance) anyerror!bool {
        return try HTMLIFrameElementImpl.get_sharedStorageWritable(instance);
    }

    /// Extended attributes: [CEReactions], [SecureContext]
    pub fn set_sharedStorageWritable(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLIFrameElementImpl.set_sharedStorageWritable(instance, value);
    }

    pub fn call_getSVGDocument(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try HTMLIFrameElementImpl.call_getSVGDocument(instance);
    }

};
