//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLTableCellElementImpl = @import("impls").HTMLTableCellElement;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const HTMLElement = @import("HTMLElement.zig").HTMLElement;
const DOMStringMap = @import("DOMStringMap.zig").DOMStringMap;
const CSSOMString = @import("typedefs").CSSOMString;
const TogglePopoverOptions = @import("dictionaries").TogglePopoverOptions;
const HTMLCollection = @import("HTMLCollection.zig").HTMLCollection;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const GeometryNode = @import("typedefs").GeometryNode;
const NamedNodeMap = @import("NamedNodeMap.zig").NamedNodeMap;
const CSSStyleDeclaration = @import("CSSStyleDeclaration.zig").CSSStyleDeclaration;
const USVString = @import("typedefs").USVString;
const TrustedType = @import("typedefs").TrustedType;
const Element = @import("Element.zig").Element;
const CheckVisibilityOptions = @import("dictionaries").CheckVisibilityOptions;
const ScrollIntoViewOptions = @import("dictionaries").ScrollIntoViewOptions;
const BoxQuadOptions = @import("dictionaries").BoxQuadOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const FocusableAreasOption = @import("dictionaries").FocusableAreasOption;
const EventListener = @import("EventListener.zig").EventListener;
const CSSStyleProperties = @import("CSSStyleProperties.zig").CSSStyleProperties;
const CSSPseudoElement = @import("CSSPseudoElement.zig").CSSPseudoElement;
const ShowPopoverOptions = @import("dictionaries").ShowPopoverOptions;
const ViewTransitionUpdateCallback = @import("callbacks").ViewTransitionUpdateCallback;
const Node = @import("Node.zig").Node;
const CustomElementRegistry = @import("CustomElementRegistry.zig").CustomElementRegistry;
const Animation = @import("Animation.zig").Animation;
const Range = @import("Range.zig").Range;
const Event = @import("Event.zig").Event;
const FocusOptions = @import("dictionaries").FocusOptions;
const DOMRectList = @import("DOMRectList.zig").DOMRectList;
const DOMString = @import("typedefs").DOMString;
const Document = @import("Document.zig").Document;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const ScrollToOptions = @import("dictionaries").ScrollToOptions;
const HTMLSlotElement = @import("HTMLSlotElement.zig").HTMLSlotElement;
const DOMQuad = @import("DOMQuad.zig").DOMQuad;
const DOMRectReadOnly = @import("DOMRectReadOnly.zig").DOMRectReadOnly;
const KeyframeAnimationOptions = @import("dictionaries").KeyframeAnimationOptions;
const StylePropertyMapReadOnly = @import("StylePropertyMapReadOnly.zig").StylePropertyMapReadOnly;
const DOMTokenList = @import("DOMTokenList.zig").DOMTokenList;
const StartViewTransitionOptions = @import("dictionaries").StartViewTransitionOptions;
const EditContext = @import("EditContext.zig").EditContext;
const DOMRect = @import("DOMRect.zig").DOMRect;
const ElementInternals = @import("ElementInternals.zig").ElementInternals;
const ViewTransition = @import("ViewTransition.zig").ViewTransition;
const SpatialNavigationSearchOptions = @import("dictionaries").SpatialNavigationSearchOptions;
const GetAnimationsOptions = @import("dictionaries").GetAnimationsOptions;
const EventHandler = @import("typedefs").EventHandler;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const SpatialNavigationDirection = @import("enums").SpatialNavigationDirection;
const StylePropertyMap = @import("StylePropertyMap.zig").StylePropertyMap;
const ShadowRoot = @import("ShadowRoot.zig").ShadowRoot;
const Attr = @import("Attr.zig").Attr;
const TrustedHTML = @import("TrustedHTML.zig").TrustedHTML;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const NodeList = @import("NodeList.zig").NodeList;
const FullscreenOptions = @import("dictionaries").FullscreenOptions;
const Observable = @import("Observable.zig").Observable;
const DOMPoint = @import("DOMPoint.zig").DOMPoint;
const PointerLockOptions = @import("dictionaries").PointerLockOptions;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const ShadowRootInit = @import("dictionaries").ShadowRootInit;

pub const HTMLTableCellElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLTableCellElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = HTMLElement.State;
        pub const ParentInterface = HTMLElement;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "colSpan", "get_colSpan", "set_colSpan" },
            .{ "rowSpan", "get_rowSpan", "set_rowSpan" },
            .{ "headers", "get_headers", "set_headers" },
            .{ "cellIndex", "get_cellIndex", null },
            .{ "scope", "get_scope", "set_scope" },
            .{ "abbr", "get_abbr", "set_abbr" },
            .{ "align", "get_align", "set_align" },
            .{ "axis", "get_axis", "set_axis" },
            .{ "height", "get_height", "set_height" },
            .{ "width", "get_width", "set_width" },
            .{ "ch", "get_ch", "set_ch" },
            .{ "chOff", "get_chOff", "set_chOff" },
            .{ "noWrap", "get_noWrap", "set_noWrap" },
            .{ "vAlign", "get_vAlign", "set_vAlign" },
            .{ "bgColor", "get_bgColor", "set_bgColor" },
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
            "scrollTo",
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
            .{ "colSpan", "get_colSpan", "set_colSpan" },
            .{ "rowSpan", "get_rowSpan", "set_rowSpan" },
            .{ "headers", "get_headers", "set_headers" },
            .{ "cellIndex", "get_cellIndex", null },
            .{ "scope", "get_scope", "set_scope" },
            .{ "abbr", "get_abbr", "set_abbr" },
            .{ "align", "get_align", "set_align" },
            .{ "axis", "get_axis", "set_axis" },
            .{ "height", "get_height", "set_height" },
            .{ "width", "get_width", "set_width" },
            .{ "ch", "get_ch", "set_ch" },
            .{ "chOff", "get_chOff", "set_chOff" },
            .{ "noWrap", "get_noWrap", "set_noWrap" },
            .{ "vAlign", "get_vAlign", "set_vAlign" },
            .{ "bgColor", "get_bgColor", "set_bgColor" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            colSpan: u32 = undefined,
            rowSpan: u32 = undefined,
            headers: typedefs.DOMString = undefined,
            cellIndex: i32 = undefined,
            scope: typedefs.DOMString = undefined,
            abbr: typedefs.DOMString = undefined,
            @"align": typedefs.DOMString = undefined,
            axis: typedefs.DOMString = undefined,
            height: typedefs.DOMString = undefined,
            width: typedefs.DOMString = undefined,
            ch: typedefs.DOMString = undefined,
            chOff: typedefs.DOMString = undefined,
            noWrap: bool = undefined,
            vAlign: typedefs.DOMString = undefined,
            bgColor: typedefs.DOMString = undefined,
            _internal: ?*HTMLTableCellElementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_abbr = &get_abbr,
        .get_align = &get_align,
        .get_axis = &get_axis,
        .get_bgColor = &get_bgColor,
        .get_cellIndex = &get_cellIndex,
        .get_ch = &get_ch,
        .get_chOff = &get_chOff,
        .get_colSpan = &get_colSpan,
        .get_headers = &get_headers,
        .get_height = &get_height,
        .get_noWrap = &get_noWrap,
        .get_rowSpan = &get_rowSpan,
        .get_scope = &get_scope,
        .get_vAlign = &get_vAlign,
        .get_width = &get_width,

        .set_abbr = &set_abbr,
        .set_align = &set_align,
        .set_axis = &set_axis,
        .set_bgColor = &set_bgColor,
        .set_ch = &set_ch,
        .set_chOff = &set_chOff,
        .set_colSpan = &set_colSpan,
        .set_headers = &set_headers,
        .set_height = &set_height,
        .set_noWrap = &set_noWrap,
        .set_rowSpan = &set_rowSpan,
        .set_scope = &set_scope,
        .set_vAlign = &set_vAlign,
        .set_width = &set_width,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLTableCellElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return HTMLTableCellElementImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLTableCellElementImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLTableCellElementImpl.call_constructor(ctx);
    }

    /// Extended attributes: [CEReactions], [Reflect], [ReflectDefault=1], [ReflectRange=(1,1000)]
    pub fn get_colSpan(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLTableCellElementImpl.get_colSpan(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect], [ReflectDefault=1], [ReflectRange=(1,1000)]
    pub fn set_colSpan(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableCellElementImpl.set_colSpan(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect], [ReflectDefault=1], [ReflectRange=(0,65534)]
    pub fn get_rowSpan(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLTableCellElementImpl.get_rowSpan(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect], [ReflectDefault=1], [ReflectRange=(0,65534)]
    pub fn set_rowSpan(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableCellElementImpl.set_rowSpan(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_headers(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTableCellElementImpl.get_headers(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_headers(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableCellElementImpl.set_headers(instance, value);
    }

    pub fn get_cellIndex(instance: *runtime.Instance) anyerror!i32 {
        return try HTMLTableCellElementImpl.get_cellIndex(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_scope(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTableCellElementImpl.get_scope(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_scope(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableCellElementImpl.set_scope(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_abbr(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTableCellElementImpl.get_abbr(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_abbr(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableCellElementImpl.set_abbr(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_align(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTableCellElementImpl.get_align(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_align(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableCellElementImpl.set_align(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_axis(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTableCellElementImpl.get_axis(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_axis(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableCellElementImpl.set_axis(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_height(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTableCellElementImpl.get_height(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_height(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableCellElementImpl.set_height(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_width(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTableCellElementImpl.get_width(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_width(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableCellElementImpl.set_width(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="char"]
    pub fn get_ch(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTableCellElementImpl.get_ch(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="char"]
    pub fn set_ch(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableCellElementImpl.set_ch(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="charoff"]
    pub fn get_chOff(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTableCellElementImpl.get_chOff(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="charoff"]
    pub fn set_chOff(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableCellElementImpl.set_chOff(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_noWrap(instance: *runtime.Instance) anyerror!bool {
        return try HTMLTableCellElementImpl.get_noWrap(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_noWrap(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableCellElementImpl.set_noWrap(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_vAlign(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTableCellElementImpl.get_vAlign(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_vAlign(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableCellElementImpl.set_vAlign(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect], [LegacyNullToEmptyString]
    pub fn get_bgColor(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTableCellElementImpl.get_bgColor(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect], [LegacyNullToEmptyString]
    pub fn set_bgColor(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTableCellElementImpl.set_bgColor(instance, value);
    }

};
