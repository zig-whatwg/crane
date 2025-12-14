//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLLinkElementImpl = @import("impls").HTMLLinkElement;
const mixins = @import("mixins");
const HTMLElement = @import("interfaces").HTMLElement;
const LinkStyle = @import("interfaces").LinkStyle;
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
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
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
const StyleSheet = @import("interfaces").StyleSheet;
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

pub const HTMLLinkElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLLinkElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = HTMLElement.State;
        pub const ParentInterface = HTMLElement;
        pub const MixinTypes = &.{
            LinkStyle,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "href", "get_href", "set_href" },
            .{ "crossOrigin", "get_crossOrigin", "set_crossOrigin" },
            .{ "rel", "get_rel", "set_rel" },
            .{ "as", "get_as", "set_as" },
            .{ "relList", "get_relList", "set_relList" },
            .{ "media", "get_media", "set_media" },
            .{ "integrity", "get_integrity", "set_integrity" },
            .{ "hreflang", "get_hreflang", "set_hreflang" },
            .{ "type", "get_type", "set_type" },
            .{ "sizes", "get_sizes", "set_sizes" },
            .{ "imageSrcset", "get_imageSrcset", "set_imageSrcset" },
            .{ "imageSizes", "get_imageSizes", "set_imageSizes" },
            .{ "referrerPolicy", "get_referrerPolicy", "set_referrerPolicy" },
            .{ "blocking", "get_blocking", "set_blocking" },
            .{ "disabled", "get_disabled", "set_disabled" },
            .{ "fetchPriority", "get_fetchPriority", "set_fetchPriority" },
            .{ "charset", "get_charset", "set_charset" },
            .{ "rev", "get_rev", "set_rev" },
            .{ "target", "get_target", "set_target" },
            .{ "sheet", "get_sheet", null },
            .{ "sheet", "get_sheet", null },
        };
        
        /// [PutForwards] attributes: setting the attribute forwards to a property on the value
        /// Format: { "attrName", "forwardedProperty" }
        pub const put_forwards_attributes = .{
            .{ "relList", "value" },
            .{ "sizes", "value" },
            .{ "blocking", "value" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            .{ "href", "get_href", "set_href" },
            .{ "crossOrigin", "get_crossOrigin", "set_crossOrigin" },
            .{ "rel", "get_rel", "set_rel" },
            .{ "as", "get_as", "set_as" },
            .{ "relList", "get_relList", "set_relList" },
            .{ "media", "get_media", "set_media" },
            .{ "integrity", "get_integrity", "set_integrity" },
            .{ "hreflang", "get_hreflang", "set_hreflang" },
            .{ "type", "get_type", "set_type" },
            .{ "sizes", "get_sizes", "set_sizes" },
            .{ "imageSrcset", "get_imageSrcset", "set_imageSrcset" },
            .{ "imageSizes", "get_imageSizes", "set_imageSizes" },
            .{ "referrerPolicy", "get_referrerPolicy", "set_referrerPolicy" },
            .{ "blocking", "get_blocking", "set_blocking" },
            .{ "disabled", "get_disabled", "set_disabled" },
            .{ "fetchPriority", "get_fetchPriority", "set_fetchPriority" },
            .{ "charset", "get_charset", "set_charset" },
            .{ "rev", "get_rev", "set_rev" },
            .{ "target", "get_target", "set_target" },
            .{ "sheet", "get_sheet", null },
            .{ "sheet", "get_sheet", null },
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
            href: runtime.USVString = undefined,
            crossOrigin: ?runtime.DOMString = null,
            rel: runtime.DOMString = undefined,
            as: runtime.DOMString = undefined,
            relList: *runtime.Instance = undefined,
            media: runtime.DOMString = undefined,
            integrity: runtime.DOMString = undefined,
            hreflang: runtime.DOMString = undefined,
            @"type": runtime.DOMString = undefined,
            sizes: *runtime.Instance = undefined,
            imageSrcset: runtime.USVString = undefined,
            imageSizes: runtime.DOMString = undefined,
            referrerPolicy: runtime.DOMString = undefined,
            blocking: *runtime.Instance = undefined,
            disabled: bool = undefined,
            fetchPriority: runtime.DOMString = undefined,
            charset: runtime.DOMString = undefined,
            rev: runtime.DOMString = undefined,
            target: runtime.DOMString = undefined,
            sheet: ?*runtime.Instance = null,
            cached_relList: ?*runtime.Instance = null,
            cached_sizes: ?*runtime.Instance = null,
            cached_blocking: ?*runtime.Instance = null,
            _internal: ?*HTMLLinkElementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_as = &get_as,
        .get_blocking = &get_blocking,
        .get_charset = &get_charset,
        .get_crossOrigin = &get_crossOrigin,
        .get_disabled = &get_disabled,
        .get_fetchPriority = &get_fetchPriority,
        .get_href = &get_href,
        .get_hreflang = &get_hreflang,
        .get_imageSizes = &get_imageSizes,
        .get_imageSrcset = &get_imageSrcset,
        .get_integrity = &get_integrity,
        .get_media = &get_media,
        .get_referrerPolicy = &get_referrerPolicy,
        .get_rel = &get_rel,
        .get_relList = &get_relList,
        .get_rev = &get_rev,
        .get_sheet = &get_sheet,
        .get_sizes = &get_sizes,
        .get_target = &get_target,
        .get_type = &get_type,

        .set_as = &set_as,
        .set_charset = &set_charset,
        .set_crossOrigin = &set_crossOrigin,
        .set_disabled = &set_disabled,
        .set_fetchPriority = &set_fetchPriority,
        .set_href = &set_href,
        .set_hreflang = &set_hreflang,
        .set_imageSizes = &set_imageSizes,
        .set_imageSrcset = &set_imageSrcset,
        .set_integrity = &set_integrity,
        .set_media = &set_media,
        .set_referrerPolicy = &set_referrerPolicy,
        .set_rel = &set_rel,
        .set_rev = &set_rev,
        .set_target = &set_target,
        .set_type = &set_type,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLLinkElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return HTMLLinkElementImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLLinkElementImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLLinkElementImpl.call_constructor(ctx);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLLinkElementImpl.get_href(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn set_href(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLLinkElementImpl.set_href(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_crossOrigin(instance: *runtime.Instance) anyerror!?DOMString {
        return try HTMLLinkElementImpl.get_crossOrigin(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_crossOrigin(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLLinkElementImpl.set_crossOrigin(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_rel(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLLinkElementImpl.get_rel(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_rel(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLLinkElementImpl.set_rel(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_as(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLLinkElementImpl.get_as(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_as(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLLinkElementImpl.set_as(instance, value);
    }

    /// Extended attributes: [SameObject], [PutForwards=value], [Reflect="rel"]
    pub fn get_relList(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_relList) |cached| {
            return cached;
        }
        const value = try HTMLLinkElementImpl.get_relList(instance);
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

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_media(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLLinkElementImpl.get_media(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_media(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLLinkElementImpl.set_media(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_integrity(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLLinkElementImpl.get_integrity(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_integrity(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLLinkElementImpl.set_integrity(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_hreflang(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLLinkElementImpl.get_hreflang(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_hreflang(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLLinkElementImpl.set_hreflang(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLLinkElementImpl.get_type(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_type(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLLinkElementImpl.set_type(instance, value);
    }

    /// Extended attributes: [SameObject], [PutForwards=value], [Reflect]
    pub fn get_sizes(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_sizes) |cached| {
            return cached;
        }
        const value = try HTMLLinkElementImpl.get_sizes(instance);
        state.own.cached_sizes = value;
        return value;
    }

    /// Extended attributes: [SameObject], [PutForwards=value], [Reflect]
    pub fn set_sizes(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [PutForwards] - Get target object and set the forwarded property
        // Per WebIDL spec: setting 'sizes' forwards to 'value' on the attribute's value
        const target = try get_sizes(instance);
        
        // Use JavaScript [[Set]] semantics to set the forwarded property
        // This respects prototype chain and user-defined setters
        try runtime.setPropertyOnInstance(target, "value", value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_imageSrcset(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLLinkElementImpl.get_imageSrcset(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_imageSrcset(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLLinkElementImpl.set_imageSrcset(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_imageSizes(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLLinkElementImpl.get_imageSizes(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_imageSizes(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLLinkElementImpl.set_imageSizes(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_referrerPolicy(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLLinkElementImpl.get_referrerPolicy(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_referrerPolicy(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLLinkElementImpl.set_referrerPolicy(instance, value);
    }

    /// Extended attributes: [SameObject], [PutForwards=value], [Reflect]
    pub fn get_blocking(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_blocking) |cached| {
            return cached;
        }
        const value = try HTMLLinkElementImpl.get_blocking(instance);
        state.own.cached_blocking = value;
        return value;
    }

    /// Extended attributes: [SameObject], [PutForwards=value], [Reflect]
    pub fn set_blocking(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [PutForwards] - Get target object and set the forwarded property
        // Per WebIDL spec: setting 'blocking' forwards to 'value' on the attribute's value
        const target = try get_blocking(instance);
        
        // Use JavaScript [[Set]] semantics to set the forwarded property
        // This respects prototype chain and user-defined setters
        try runtime.setPropertyOnInstance(target, "value", value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_disabled(instance: *runtime.Instance) anyerror!bool {
        return try HTMLLinkElementImpl.get_disabled(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_disabled(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLLinkElementImpl.set_disabled(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_fetchPriority(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLLinkElementImpl.get_fetchPriority(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_fetchPriority(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLLinkElementImpl.set_fetchPriority(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_charset(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLLinkElementImpl.get_charset(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_charset(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLLinkElementImpl.set_charset(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_rev(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLLinkElementImpl.get_rev(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_rev(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLLinkElementImpl.set_rev(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_target(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLLinkElementImpl.get_target(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_target(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLLinkElementImpl.set_target(instance, value);
    }

    pub fn get_sheet(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try HTMLLinkElementImpl.get_sheet(instance);
    }

};
