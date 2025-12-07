//! Generated from: html.idl
//! Generated at: 2025-12-07T19:32:59Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const HTMLImageElementImpl = @import("impls").HTMLImageElement;
const mixins = @import("mixins");
const HTMLElement = @import("interfaces").HTMLElement;
const HTMLAttributionSrcElementUtils = @import("interfaces").HTMLAttributionSrcElementUtils;
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

pub const HTMLImageElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLImageElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = HTMLElement.State;
        pub const ParentInterface = HTMLElement;
        pub const MixinTypes = &.{
            HTMLAttributionSrcElementUtils,
            HTMLSharedStorageWritableElementUtils,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "LegacyFactoryFunction", .value = .{ .identifier = "Image" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "alt", "get_alt", "set_alt" },
            .{ "src", "get_src", "set_src" },
            .{ "srcset", "get_srcset", "set_srcset" },
            .{ "sizes", "get_sizes", "set_sizes" },
            .{ "crossOrigin", "get_crossOrigin", "set_crossOrigin" },
            .{ "useMap", "get_useMap", "set_useMap" },
            .{ "isMap", "get_isMap", "set_isMap" },
            .{ "width", "get_width", "set_width" },
            .{ "height", "get_height", "set_height" },
            .{ "naturalWidth", "get_naturalWidth", null },
            .{ "naturalHeight", "get_naturalHeight", null },
            .{ "complete", "get_complete", null },
            .{ "currentSrc", "get_currentSrc", null },
            .{ "referrerPolicy", "get_referrerPolicy", "set_referrerPolicy" },
            .{ "decoding", "get_decoding", "set_decoding" },
            .{ "loading", "get_loading", "set_loading" },
            .{ "fetchPriority", "get_fetchPriority", "set_fetchPriority" },
            .{ "name", "get_name", "set_name" },
            .{ "lowsrc", "get_lowsrc", "set_lowsrc" },
            .{ "align", "get_align", "set_align" },
            .{ "hspace", "get_hspace", "set_hspace" },
            .{ "vspace", "get_vspace", "set_vspace" },
            .{ "longDesc", "get_longDesc", "set_longDesc" },
            .{ "border", "get_border", "set_border" },
            .{ "x", "get_x", null },
            .{ "y", "get_y", null },
            .{ "attributionSrc", "get_attributionSrc", "set_attributionSrc" },
            .{ "sharedStorageWritable", "get_sharedStorageWritable", "set_sharedStorageWritable" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "decode", "call_decode", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "decode",
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
            .{ "src", "get_src", "set_src" },
            .{ "srcset", "get_srcset", "set_srcset" },
            .{ "sizes", "get_sizes", "set_sizes" },
            .{ "crossOrigin", "get_crossOrigin", "set_crossOrigin" },
            .{ "useMap", "get_useMap", "set_useMap" },
            .{ "isMap", "get_isMap", "set_isMap" },
            .{ "width", "get_width", "set_width" },
            .{ "height", "get_height", "set_height" },
            .{ "naturalWidth", "get_naturalWidth", null },
            .{ "naturalHeight", "get_naturalHeight", null },
            .{ "complete", "get_complete", null },
            .{ "currentSrc", "get_currentSrc", null },
            .{ "referrerPolicy", "get_referrerPolicy", "set_referrerPolicy" },
            .{ "decoding", "get_decoding", "set_decoding" },
            .{ "loading", "get_loading", "set_loading" },
            .{ "fetchPriority", "get_fetchPriority", "set_fetchPriority" },
            .{ "name", "get_name", "set_name" },
            .{ "lowsrc", "get_lowsrc", "set_lowsrc" },
            .{ "align", "get_align", "set_align" },
            .{ "hspace", "get_hspace", "set_hspace" },
            .{ "vspace", "get_vspace", "set_vspace" },
            .{ "longDesc", "get_longDesc", "set_longDesc" },
            .{ "border", "get_border", "set_border" },
            .{ "x", "get_x", null },
            .{ "y", "get_y", null },
            .{ "attributionSrc", "get_attributionSrc", "set_attributionSrc" },
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
            alt: runtime.DOMString = undefined,
            src: runtime.USVString = undefined,
            srcset: runtime.USVString = undefined,
            sizes: runtime.DOMString = undefined,
            crossOrigin: ?runtime.DOMString = null,
            useMap: runtime.DOMString = undefined,
            isMap: bool = undefined,
            width: u32 = undefined,
            height: u32 = undefined,
            naturalWidth: u32 = undefined,
            naturalHeight: u32 = undefined,
            complete: bool = undefined,
            currentSrc: runtime.USVString = undefined,
            referrerPolicy: runtime.DOMString = undefined,
            decoding: runtime.DOMString = undefined,
            loading: runtime.DOMString = undefined,
            fetchPriority: runtime.DOMString = undefined,
            name: runtime.DOMString = undefined,
            lowsrc: runtime.USVString = undefined,
            @"align": runtime.DOMString = undefined,
            hspace: u32 = undefined,
            vspace: u32 = undefined,
            longDesc: runtime.USVString = undefined,
            border: runtime.DOMString = undefined,
            x: i32 = undefined,
            y: i32 = undefined,
            attributionSrc: runtime.USVString = undefined,
            sharedStorageWritable: bool = undefined,
            _internal: ?*HTMLImageElementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_align = &get_align,
        .get_alt = &get_alt,
        .get_attributionSrc = &get_attributionSrc,
        .get_border = &get_border,
        .get_complete = &get_complete,
        .get_crossOrigin = &get_crossOrigin,
        .get_currentSrc = &get_currentSrc,
        .get_decoding = &get_decoding,
        .get_fetchPriority = &get_fetchPriority,
        .get_height = &get_height,
        .get_hspace = &get_hspace,
        .get_isMap = &get_isMap,
        .get_loading = &get_loading,
        .get_longDesc = &get_longDesc,
        .get_lowsrc = &get_lowsrc,
        .get_name = &get_name,
        .get_naturalHeight = &get_naturalHeight,
        .get_naturalWidth = &get_naturalWidth,
        .get_referrerPolicy = &get_referrerPolicy,
        .get_sharedStorageWritable = &get_sharedStorageWritable,
        .get_sizes = &get_sizes,
        .get_src = &get_src,
        .get_srcset = &get_srcset,
        .get_useMap = &get_useMap,
        .get_vspace = &get_vspace,
        .get_width = &get_width,
        .get_x = &get_x,
        .get_y = &get_y,

        .set_align = &set_align,
        .set_alt = &set_alt,
        .set_attributionSrc = &set_attributionSrc,
        .set_border = &set_border,
        .set_crossOrigin = &set_crossOrigin,
        .set_decoding = &set_decoding,
        .set_fetchPriority = &set_fetchPriority,
        .set_height = &set_height,
        .set_hspace = &set_hspace,
        .set_isMap = &set_isMap,
        .set_loading = &set_loading,
        .set_longDesc = &set_longDesc,
        .set_lowsrc = &set_lowsrc,
        .set_name = &set_name,
        .set_referrerPolicy = &set_referrerPolicy,
        .set_sharedStorageWritable = &set_sharedStorageWritable,
        .set_sizes = &set_sizes,
        .set_src = &set_src,
        .set_srcset = &set_srcset,
        .set_useMap = &set_useMap,
        .set_vspace = &set_vspace,
        .set_width = &set_width,

        .call_decode = &call_decode,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLImageElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLImageElementImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLImageElementImpl.call_constructor(allocator, ctx);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_alt(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLImageElementImpl.get_alt(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_alt(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLImageElementImpl.set_alt(instance, value);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn get_src(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLImageElementImpl.get_src(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn set_src(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLImageElementImpl.set_src(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_srcset(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLImageElementImpl.get_srcset(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_srcset(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLImageElementImpl.set_srcset(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_sizes(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLImageElementImpl.get_sizes(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_sizes(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLImageElementImpl.set_sizes(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_crossOrigin(instance: *runtime.Instance) anyerror!?DOMString {
        return try HTMLImageElementImpl.get_crossOrigin(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_crossOrigin(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLImageElementImpl.set_crossOrigin(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_useMap(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLImageElementImpl.get_useMap(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_useMap(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLImageElementImpl.set_useMap(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_isMap(instance: *runtime.Instance) anyerror!bool {
        return try HTMLImageElementImpl.get_isMap(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_isMap(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLImageElementImpl.set_isMap(instance, value);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn get_width(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLImageElementImpl.get_width(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn set_width(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLImageElementImpl.set_width(instance, value);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn get_height(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLImageElementImpl.get_height(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn set_height(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLImageElementImpl.set_height(instance, value);
    }

    pub fn get_naturalWidth(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLImageElementImpl.get_naturalWidth(instance);
    }

    pub fn get_naturalHeight(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLImageElementImpl.get_naturalHeight(instance);
    }

    pub fn get_complete(instance: *runtime.Instance) anyerror!bool {
        return try HTMLImageElementImpl.get_complete(instance);
    }

    pub fn get_currentSrc(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLImageElementImpl.get_currentSrc(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_referrerPolicy(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLImageElementImpl.get_referrerPolicy(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_referrerPolicy(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLImageElementImpl.set_referrerPolicy(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_decoding(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLImageElementImpl.get_decoding(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_decoding(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLImageElementImpl.set_decoding(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_loading(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLImageElementImpl.get_loading(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_loading(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLImageElementImpl.set_loading(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_fetchPriority(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLImageElementImpl.get_fetchPriority(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_fetchPriority(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLImageElementImpl.set_fetchPriority(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLImageElementImpl.get_name(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_name(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLImageElementImpl.set_name(instance, value);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn get_lowsrc(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLImageElementImpl.get_lowsrc(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn set_lowsrc(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLImageElementImpl.set_lowsrc(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_align(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLImageElementImpl.get_align(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_align(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLImageElementImpl.set_align(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_hspace(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLImageElementImpl.get_hspace(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_hspace(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLImageElementImpl.set_hspace(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_vspace(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLImageElementImpl.get_vspace(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_vspace(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLImageElementImpl.set_vspace(instance, value);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn get_longDesc(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLImageElementImpl.get_longDesc(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn set_longDesc(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLImageElementImpl.set_longDesc(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect], [LegacyNullToEmptyString]
    pub fn get_border(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLImageElementImpl.get_border(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect], [LegacyNullToEmptyString]
    pub fn set_border(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLImageElementImpl.set_border(instance, value);
    }

    pub fn get_x(instance: *runtime.Instance) anyerror!i32 {
        return try HTMLImageElementImpl.get_x(instance);
    }

    pub fn get_y(instance: *runtime.Instance) anyerror!i32 {
        return try HTMLImageElementImpl.get_y(instance);
    }

    /// Extended attributes: [CEReactions], [SecureContext]
    pub fn get_attributionSrc(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLImageElementImpl.get_attributionSrc(instance);
    }

    /// Extended attributes: [CEReactions], [SecureContext]
    pub fn set_attributionSrc(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLImageElementImpl.set_attributionSrc(instance, value);
    }

    /// Extended attributes: [CEReactions], [SecureContext]
    pub fn get_sharedStorageWritable(instance: *runtime.Instance) anyerror!bool {
        return try HTMLImageElementImpl.get_sharedStorageWritable(instance);
    }

    /// Extended attributes: [CEReactions], [SecureContext]
    pub fn set_sharedStorageWritable(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLImageElementImpl.set_sharedStorageWritable(instance, value);
    }

    pub fn call_decode(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try HTMLImageElementImpl.call_decode(instance);
    }

};
