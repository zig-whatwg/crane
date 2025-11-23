//! Generated from: html.idl
//! Generated at: 2025-11-23T19:47:43Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HTMLTableRowElementImpl = @import("impls").HTMLTableRowElement;
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
const ViewTransitionUpdateCallback = @import("callbacks").ViewTransitionUpdateCallback;
const HTMLTableCellElement = @import("interfaces").HTMLTableCellElement;
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

pub const HTMLTableRowElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLTableRowElement";
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
            .{ "rowIndex", "get_rowIndex", null },
            .{ "sectionRowIndex", "get_sectionRowIndex", null },
            .{ "cells", "get_cells", null },
            .{ "align", "get_align", "set_align" },
            .{ "ch", "get_ch", "set_ch" },
            .{ "chOff", "get_chOff", "set_chOff" },
            .{ "vAlign", "get_vAlign", "set_vAlign" },
            .{ "bgColor", "get_bgColor", "set_bgColor" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "insertCell", "call_insertCell", 0 },
            .{ "deleteCell", "call_deleteCell", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "insertCell",
            "deleteCell",
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
            .{ "rowIndex", "get_rowIndex", null },
            .{ "sectionRowIndex", "get_sectionRowIndex", null },
            .{ "cells", "get_cells", null },
            .{ "align", "get_align", "set_align" },
            .{ "ch", "get_ch", "set_ch" },
            .{ "chOff", "get_chOff", "set_chOff" },
            .{ "vAlign", "get_vAlign", "set_vAlign" },
            .{ "bgColor", "get_bgColor", "set_bgColor" },
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
            rowIndex: i32 = undefined,
            sectionRowIndex: i32 = undefined,
            cells: *runtime.Instance = undefined,
            @"align": runtime.DOMString = undefined,
            ch: runtime.DOMString = undefined,
            chOff: runtime.DOMString = undefined,
            vAlign: runtime.DOMString = undefined,
            bgColor: runtime.DOMString = undefined,
            cached_cells: ?*runtime.Instance = null,
            _internal: ?*HTMLTableRowElementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_align = &get_align,
        .get_bgColor = &get_bgColor,
        .get_cells = &get_cells,
        .get_ch = &get_ch,
        .get_chOff = &get_chOff,
        .get_rowIndex = &get_rowIndex,
        .get_sectionRowIndex = &get_sectionRowIndex,
        .get_vAlign = &get_vAlign,

        .set_align = &set_align,
        .set_bgColor = &set_bgColor,
        .set_ch = &set_ch,
        .set_chOff = &set_chOff,
        .set_vAlign = &set_vAlign,

        .call_deleteCell = &call_deleteCell,
        .call_insertCell = &call_insertCell,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLTableRowElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLTableRowElementImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLTableRowElementImpl.call_constructor(allocator, ctx);
    }

    pub fn get_rowIndex(instance: *runtime.Instance) anyerror!i32 {
        return try HTMLTableRowElementImpl.get_rowIndex(instance);
    }

    pub fn get_sectionRowIndex(instance: *runtime.Instance) anyerror!i32 {
        return try HTMLTableRowElementImpl.get_sectionRowIndex(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_cells(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_cells) |cached| {
            return cached;
        }
        const value = try HTMLTableRowElementImpl.get_cells(instance);
        state.own.cached_cells = value;
        return value;
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_align(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTableRowElementImpl.get_align(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_align(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableRowElementImpl.set_align(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="char"]
    pub fn get_ch(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTableRowElementImpl.get_ch(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="char"]
    pub fn set_ch(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableRowElementImpl.set_ch(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="charoff"]
    pub fn get_chOff(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTableRowElementImpl.get_chOff(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="charoff"]
    pub fn set_chOff(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableRowElementImpl.set_chOff(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_vAlign(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTableRowElementImpl.get_vAlign(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_vAlign(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableRowElementImpl.set_vAlign(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect], [LegacyNullToEmptyString]
    pub fn get_bgColor(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTableRowElementImpl.get_bgColor(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect], [LegacyNullToEmptyString]
    pub fn set_bgColor(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableRowElementImpl.set_bgColor(instance, value);
    }

    pub fn call_insertCell(instance: *runtime.Instance, index: i32) anyerror!*runtime.Instance {
        
        return try HTMLTableRowElementImpl.call_insertCell(instance, index);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_deleteCell(instance: *runtime.Instance, index: i32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try HTMLTableRowElementImpl.call_deleteCell(instance, index);
    }

};
