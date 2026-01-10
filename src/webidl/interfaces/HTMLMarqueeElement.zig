//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLMarqueeElementImpl = @import("impls").HTMLMarqueeElement;
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

pub const HTMLMarqueeElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLMarqueeElement";
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
            .{ "behavior", "get_behavior", "set_behavior" },
            .{ "bgColor", "get_bgColor", "set_bgColor" },
            .{ "direction", "get_direction", "set_direction" },
            .{ "height", "get_height", "set_height" },
            .{ "hspace", "get_hspace", "set_hspace" },
            .{ "loop", "get_loop", "set_loop" },
            .{ "scrollAmount", "get_scrollAmount", "set_scrollAmount" },
            .{ "scrollDelay", "get_scrollDelay", "set_scrollDelay" },
            .{ "trueSpeed", "get_trueSpeed", "set_trueSpeed" },
            .{ "vspace", "get_vspace", "set_vspace" },
            .{ "width", "get_width", "set_width" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "start", "call_start", 0 },
            .{ "stop", "call_stop", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "start",
            "stop",
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
            .{ "behavior", "get_behavior", "set_behavior" },
            .{ "bgColor", "get_bgColor", "set_bgColor" },
            .{ "direction", "get_direction", "set_direction" },
            .{ "height", "get_height", "set_height" },
            .{ "hspace", "get_hspace", "set_hspace" },
            .{ "loop", "get_loop", "set_loop" },
            .{ "scrollAmount", "get_scrollAmount", "set_scrollAmount" },
            .{ "scrollDelay", "get_scrollDelay", "set_scrollDelay" },
            .{ "trueSpeed", "get_trueSpeed", "set_trueSpeed" },
            .{ "vspace", "get_vspace", "set_vspace" },
            .{ "width", "get_width", "set_width" },
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
            behavior: typedefs.DOMString = undefined,
            bgColor: typedefs.DOMString = undefined,
            direction: typedefs.DOMString = undefined,
            height: typedefs.DOMString = undefined,
            hspace: u32 = undefined,
            loop: i32 = undefined,
            scrollAmount: u32 = undefined,
            scrollDelay: u32 = undefined,
            trueSpeed: bool = undefined,
            vspace: u32 = undefined,
            width: typedefs.DOMString = undefined,
            _internal: ?*HTMLMarqueeElementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_behavior = &get_behavior,
        .get_bgColor = &get_bgColor,
        .get_direction = &get_direction,
        .get_height = &get_height,
        .get_hspace = &get_hspace,
        .get_loop = &get_loop,
        .get_scrollAmount = &get_scrollAmount,
        .get_scrollDelay = &get_scrollDelay,
        .get_trueSpeed = &get_trueSpeed,
        .get_vspace = &get_vspace,
        .get_width = &get_width,

        .set_behavior = &set_behavior,
        .set_bgColor = &set_bgColor,
        .set_direction = &set_direction,
        .set_height = &set_height,
        .set_hspace = &set_hspace,
        .set_loop = &set_loop,
        .set_scrollAmount = &set_scrollAmount,
        .set_scrollDelay = &set_scrollDelay,
        .set_trueSpeed = &set_trueSpeed,
        .set_vspace = &set_vspace,
        .set_width = &set_width,

        .call_start = &call_start,
        .call_stop = &call_stop,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLMarqueeElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return HTMLMarqueeElementImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLMarqueeElementImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLMarqueeElementImpl.call_constructor(ctx);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_behavior(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLMarqueeElementImpl.get_behavior(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_behavior(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLMarqueeElementImpl.set_behavior(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_bgColor(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLMarqueeElementImpl.get_bgColor(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_bgColor(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLMarqueeElementImpl.set_bgColor(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_direction(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLMarqueeElementImpl.get_direction(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_direction(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLMarqueeElementImpl.set_direction(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_height(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLMarqueeElementImpl.get_height(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_height(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLMarqueeElementImpl.set_height(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_hspace(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLMarqueeElementImpl.get_hspace(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_hspace(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLMarqueeElementImpl.set_hspace(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_loop(instance: *runtime.Instance) anyerror!i32 {
        return try HTMLMarqueeElementImpl.get_loop(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_loop(instance: *runtime.Instance, value: i32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLMarqueeElementImpl.set_loop(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect], [ReflectDefault=6]
    pub fn get_scrollAmount(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLMarqueeElementImpl.get_scrollAmount(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect], [ReflectDefault=6]
    pub fn set_scrollAmount(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLMarqueeElementImpl.set_scrollAmount(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect], [ReflectDefault=85]
    pub fn get_scrollDelay(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLMarqueeElementImpl.get_scrollDelay(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect], [ReflectDefault=85]
    pub fn set_scrollDelay(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLMarqueeElementImpl.set_scrollDelay(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_trueSpeed(instance: *runtime.Instance) anyerror!bool {
        return try HTMLMarqueeElementImpl.get_trueSpeed(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_trueSpeed(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLMarqueeElementImpl.set_trueSpeed(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_vspace(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLMarqueeElementImpl.get_vspace(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_vspace(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLMarqueeElementImpl.set_vspace(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_width(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLMarqueeElementImpl.get_width(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_width(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLMarqueeElementImpl.set_width(instance, value);
    }

    pub fn call_start(instance: *runtime.Instance) anyerror!void {
        return try HTMLMarqueeElementImpl.call_start(instance);
    }

    pub fn call_stop(instance: *runtime.Instance) anyerror!void {
        return try HTMLMarqueeElementImpl.call_stop(instance);
    }

};
