//! Generated from: html.idl
//! Generated at: 2025-11-23T19:17:35Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HTMLTableElementImpl = @import("impls").HTMLTableElement;
const HTMLElement = @import("interfaces").HTMLElement;
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
const HTMLTableSectionElement = @import("interfaces").HTMLTableSectionElement;
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
const HTMLTableCaptionElement = @import("interfaces").HTMLTableCaptionElement;
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const ScrollToOptions = @import("dictionaries").ScrollToOptions;
const HTMLSlotElement = @import("interfaces").HTMLSlotElement;
const DOMQuad = @import("interfaces").DOMQuad;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const KeyframeAnimationOptions = @import("dictionaries").KeyframeAnimationOptions;
const StylePropertyMapReadOnly = @import("interfaces").StylePropertyMapReadOnly;
const DOMTokenList = @import("interfaces").DOMTokenList;
const StartViewTransitionOptions = @import("dictionaries").StartViewTransitionOptions;
const EditContext = @import("interfaces").EditContext;
const HTMLTableRowElement = @import("interfaces").HTMLTableRowElement;
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

pub const HTMLTableElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLTableElement";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *HTMLElement;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "caption", "get_caption", "set_caption" },
            .{ "tHead", "get_tHead", "set_tHead" },
            .{ "tFoot", "get_tFoot", "set_tFoot" },
            .{ "tBodies", "get_tBodies", null },
            .{ "rows", "get_rows", null },
            .{ "align", "get_align", "set_align" },
            .{ "border", "get_border", "set_border" },
            .{ "frame", "get_frame", "set_frame" },
            .{ "rules", "get_rules", "set_rules" },
            .{ "summary", "get_summary", "set_summary" },
            .{ "width", "get_width", "set_width" },
            .{ "bgColor", "get_bgColor", "set_bgColor" },
            .{ "cellPadding", "get_cellPadding", "set_cellPadding" },
            .{ "cellSpacing", "get_cellSpacing", "set_cellSpacing" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "createCaption", "call_createCaption", 0 },
            .{ "deleteCaption", "call_deleteCaption", 0 },
            .{ "createTHead", "call_createTHead", 0 },
            .{ "deleteTHead", "call_deleteTHead", 0 },
            .{ "createTFoot", "call_createTFoot", 0 },
            .{ "deleteTFoot", "call_deleteTFoot", 0 },
            .{ "createTBody", "call_createTBody", 0 },
            .{ "insertRow", "call_insertRow", 0 },
            .{ "deleteRow", "call_deleteRow", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createCaption",
            "deleteCaption",
            "createTHead",
            "deleteTHead",
            "createTFoot",
            "deleteTFoot",
            "createTBody",
            "insertRow",
            "deleteRow",
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
            .{ "caption", "get_caption", "set_caption" },
            .{ "tHead", "get_tHead", "set_tHead" },
            .{ "tFoot", "get_tFoot", "set_tFoot" },
            .{ "tBodies", "get_tBodies", null },
            .{ "rows", "get_rows", null },
            .{ "align", "get_align", "set_align" },
            .{ "border", "get_border", "set_border" },
            .{ "frame", "get_frame", "set_frame" },
            .{ "rules", "get_rules", "set_rules" },
            .{ "summary", "get_summary", "set_summary" },
            .{ "width", "get_width", "set_width" },
            .{ "bgColor", "get_bgColor", "set_bgColor" },
            .{ "cellPadding", "get_cellPadding", "set_cellPadding" },
            .{ "cellSpacing", "get_cellSpacing", "set_cellSpacing" },
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
            caption: ?HTMLTableCaptionElement = null,
            tHead: ?HTMLTableSectionElement = null,
            tFoot: ?HTMLTableSectionElement = null,
            tBodies: HTMLCollection = undefined,
            rows: HTMLCollection = undefined,
            @"align": runtime.DOMString = undefined,
            border: runtime.DOMString = undefined,
            frame: runtime.DOMString = undefined,
            rules: runtime.DOMString = undefined,
            summary: runtime.DOMString = undefined,
            width: runtime.DOMString = undefined,
            bgColor: runtime.DOMString = undefined,
            cellPadding: runtime.DOMString = undefined,
            cellSpacing: runtime.DOMString = undefined,
            cached_tBodies: ?HTMLCollection = null,
            cached_rows: ?HTMLCollection = null,
            _internal: ?*HTMLTableElementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_align = &get_align,
        .get_bgColor = &get_bgColor,
        .get_border = &get_border,
        .get_caption = &get_caption,
        .get_cellPadding = &get_cellPadding,
        .get_cellSpacing = &get_cellSpacing,
        .get_frame = &get_frame,
        .get_rows = &get_rows,
        .get_rules = &get_rules,
        .get_summary = &get_summary,
        .get_tBodies = &get_tBodies,
        .get_tFoot = &get_tFoot,
        .get_tHead = &get_tHead,
        .get_width = &get_width,

        .set_align = &set_align,
        .set_bgColor = &set_bgColor,
        .set_border = &set_border,
        .set_caption = &set_caption,
        .set_cellPadding = &set_cellPadding,
        .set_cellSpacing = &set_cellSpacing,
        .set_frame = &set_frame,
        .set_rules = &set_rules,
        .set_summary = &set_summary,
        .set_tFoot = &set_tFoot,
        .set_tHead = &set_tHead,
        .set_width = &set_width,

        .call_createCaption = &call_createCaption,
        .call_createTBody = &call_createTBody,
        .call_createTFoot = &call_createTFoot,
        .call_createTHead = &call_createTHead,
        .call_deleteCaption = &call_deleteCaption,
        .call_deleteRow = &call_deleteRow,
        .call_deleteTFoot = &call_deleteTFoot,
        .call_deleteTHead = &call_deleteTHead,
        .call_insertRow = &call_insertRow,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLTableElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLTableElementImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLTableElementImpl.call_constructor(allocator, ctx);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_caption(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLTableElementImpl.get_caption(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_caption(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableElementImpl.set_caption(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_tHead(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLTableElementImpl.get_tHead(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_tHead(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableElementImpl.set_tHead(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_tFoot(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLTableElementImpl.get_tFoot(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_tFoot(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableElementImpl.set_tFoot(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_tBodies(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_tBodies) |cached| {
            return cached;
        }
        const value = try HTMLTableElementImpl.get_tBodies(instance);
        state.own.cached_tBodies = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_rows(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_rows) |cached| {
            return cached;
        }
        const value = try HTMLTableElementImpl.get_rows(instance);
        state.own.cached_rows = value;
        return value;
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_align(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTableElementImpl.get_align(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_align(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableElementImpl.set_align(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_border(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTableElementImpl.get_border(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_border(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableElementImpl.set_border(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_frame(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTableElementImpl.get_frame(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_frame(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableElementImpl.set_frame(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_rules(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTableElementImpl.get_rules(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_rules(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableElementImpl.set_rules(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_summary(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTableElementImpl.get_summary(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_summary(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableElementImpl.set_summary(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_width(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTableElementImpl.get_width(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_width(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableElementImpl.set_width(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect], [LegacyNullToEmptyString]
    pub fn get_bgColor(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTableElementImpl.get_bgColor(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect], [LegacyNullToEmptyString]
    pub fn set_bgColor(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableElementImpl.set_bgColor(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect], [LegacyNullToEmptyString]
    pub fn get_cellPadding(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTableElementImpl.get_cellPadding(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect], [LegacyNullToEmptyString]
    pub fn set_cellPadding(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableElementImpl.set_cellPadding(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect], [LegacyNullToEmptyString]
    pub fn get_cellSpacing(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTableElementImpl.get_cellSpacing(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect], [LegacyNullToEmptyString]
    pub fn set_cellSpacing(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableElementImpl.set_cellSpacing(instance, value);
    }

    pub fn call_createTFoot(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLTableElementImpl.call_createTFoot(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_deleteTHead(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return try HTMLTableElementImpl.call_deleteTHead(instance);
    }

    pub fn call_createCaption(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLTableElementImpl.call_createCaption(instance);
    }

    pub fn call_insertRow(instance: *runtime.Instance, index: i32) anyerror!*runtime.Instance {
        
        return try HTMLTableElementImpl.call_insertRow(instance, index);
    }

    pub fn call_createTBody(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLTableElementImpl.call_createTBody(instance);
    }

    pub fn call_createTHead(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLTableElementImpl.call_createTHead(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_deleteRow(instance: *runtime.Instance, index: i32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try HTMLTableElementImpl.call_deleteRow(instance, index);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_deleteCaption(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return try HTMLTableElementImpl.call_deleteCaption(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_deleteTFoot(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return try HTMLTableElementImpl.call_deleteTFoot(instance);
    }

};
