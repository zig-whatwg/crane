//! Generated from: html.idl
//! Generated at: 2025-12-07T19:33:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const HTMLFormElementImpl = @import("impls").HTMLFormElement;
const mixins = @import("mixins");
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
const Node = @import("interfaces").Node;
const CustomElementRegistry = @import("interfaces").CustomElementRegistry;
const Animation = @import("interfaces").Animation;
const Range = @import("interfaces").Range;
const Event = @import("interfaces").Event;
const FocusOptions = @import("dictionaries").FocusOptions;
const DOMRectList = @import("interfaces").DOMRectList;
const KeyframeAnimationOptions = @import("dictionaries").KeyframeAnimationOptions;
const Document = @import("interfaces").Document;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const RadioNodeList = @import("interfaces").RadioNodeList;
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const ScrollToOptions = @import("dictionaries").ScrollToOptions;
const HTMLSlotElement = @import("interfaces").HTMLSlotElement;
const DOMQuad = @import("interfaces").DOMQuad;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const DOMString = @import("typedefs").DOMString;
const StylePropertyMapReadOnly = @import("interfaces").StylePropertyMapReadOnly;
const DOMTokenList = @import("interfaces").DOMTokenList;
const StartViewTransitionOptions = @import("dictionaries").StartViewTransitionOptions;
const EditContext = @import("interfaces").EditContext;
const HTMLFormControlsCollection = @import("interfaces").HTMLFormControlsCollection;
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

pub const HTMLFormElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLFormElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = HTMLElement.State;
        pub const ParentInterface = HTMLElement;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "LegacyOverrideBuiltIns" },
            .{ .name = "LegacyUnenumerableNamedProperties" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "acceptCharset", "get_acceptCharset", "set_acceptCharset" },
            .{ "action", "get_action", "set_action" },
            .{ "autocomplete", "get_autocomplete", "set_autocomplete" },
            .{ "enctype", "get_enctype", "set_enctype" },
            .{ "encoding", "get_encoding", "set_encoding" },
            .{ "method", "get_method", "set_method" },
            .{ "name", "get_name", "set_name" },
            .{ "noValidate", "get_noValidate", "set_noValidate" },
            .{ "target", "get_target", "set_target" },
            .{ "rel", "get_rel", "set_rel" },
            .{ "relList", "get_relList", null },
            .{ "elements", "get_elements", null },
            .{ "length", "get_length", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "submit", "call_submit", 0 },
            .{ "requestSubmit", "call_requestSubmit", 0 },
            .{ "reset", "call_reset", 0 },
            .{ "checkValidity", "call_checkValidity", 0 },
            .{ "reportValidity", "call_reportValidity", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "submit",
            "requestSubmit",
            "reset",
            "checkValidity",
            "reportValidity",
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
            .{ "acceptCharset", "get_acceptCharset", "set_acceptCharset" },
            .{ "action", "get_action", "set_action" },
            .{ "autocomplete", "get_autocomplete", "set_autocomplete" },
            .{ "enctype", "get_enctype", "set_enctype" },
            .{ "encoding", "get_encoding", "set_encoding" },
            .{ "method", "get_method", "set_method" },
            .{ "name", "get_name", "set_name" },
            .{ "noValidate", "get_noValidate", "set_noValidate" },
            .{ "target", "get_target", "set_target" },
            .{ "rel", "get_rel", "set_rel" },
            .{ "relList", "get_relList", null },
            .{ "elements", "get_elements", null },
            .{ "length", "get_length", null },
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
            acceptCharset: runtime.DOMString = undefined,
            action: runtime.USVString = undefined,
            autocomplete: runtime.DOMString = undefined,
            enctype: runtime.DOMString = undefined,
            encoding: runtime.DOMString = undefined,
            method: runtime.DOMString = undefined,
            name: runtime.DOMString = undefined,
            noValidate: bool = undefined,
            target: runtime.DOMString = undefined,
            rel: runtime.DOMString = undefined,
            relList: *runtime.Instance = undefined,
            elements: *runtime.Instance = undefined,
            length: u32 = undefined,
            cached_relList: ?*runtime.Instance = null,
            cached_elements: ?*runtime.Instance = null,
            _internal: ?*HTMLFormElementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_acceptCharset = &get_acceptCharset,
        .get_action = &get_action,
        .get_autocomplete = &get_autocomplete,
        .get_elements = &get_elements,
        .get_encoding = &get_encoding,
        .get_enctype = &get_enctype,
        .get_length = &get_length,
        .get_method = &get_method,
        .get_name = &get_name,
        .get_noValidate = &get_noValidate,
        .get_rel = &get_rel,
        .get_relList = &get_relList,
        .get_target = &get_target,

        .set_acceptCharset = &set_acceptCharset,
        .set_action = &set_action,
        .set_autocomplete = &set_autocomplete,
        .set_encoding = &set_encoding,
        .set_enctype = &set_enctype,
        .set_method = &set_method,
        .set_name = &set_name,
        .set_noValidate = &set_noValidate,
        .set_rel = &set_rel,
        .set_target = &set_target,

        .call_checkValidity = &call_checkValidity,
        .call_reportValidity = &call_reportValidity,
        .call_requestSubmit = &call_requestSubmit,
        .call_reset = &call_reset,
        .call_submit = &call_submit,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLFormElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLFormElementImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLFormElementImpl.call_constructor(allocator, ctx);
    }

    /// Extended attributes: [CEReactions], [Reflect="accept-charset"]
    pub fn get_acceptCharset(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLFormElementImpl.get_acceptCharset(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="accept-charset"]
    pub fn set_acceptCharset(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLFormElementImpl.set_acceptCharset(instance, value);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn get_action(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLFormElementImpl.get_action(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn set_action(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLFormElementImpl.set_action(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_autocomplete(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLFormElementImpl.get_autocomplete(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_autocomplete(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLFormElementImpl.set_autocomplete(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_enctype(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLFormElementImpl.get_enctype(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_enctype(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLFormElementImpl.set_enctype(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_encoding(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLFormElementImpl.get_encoding(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_encoding(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLFormElementImpl.set_encoding(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_method(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLFormElementImpl.get_method(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_method(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLFormElementImpl.set_method(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLFormElementImpl.get_name(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_name(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLFormElementImpl.set_name(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_noValidate(instance: *runtime.Instance) anyerror!bool {
        return try HTMLFormElementImpl.get_noValidate(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_noValidate(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLFormElementImpl.set_noValidate(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_target(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLFormElementImpl.get_target(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_target(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLFormElementImpl.set_target(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_rel(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLFormElementImpl.get_rel(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_rel(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLFormElementImpl.set_rel(instance, value);
    }

    /// Extended attributes: [SameObject], [PutForwards=value], [Reflect="rel"]
    pub fn get_relList(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_relList) |cached| {
            return cached;
        }
        const value = try HTMLFormElementImpl.get_relList(instance);
        state.own.cached_relList = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_elements(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_elements) |cached| {
            return cached;
        }
        const value = try HTMLFormElementImpl.get_elements(instance);
        state.own.cached_elements = value;
        return value;
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLFormElementImpl.get_length(instance);
    }

    pub fn call_requestSubmit(instance: *runtime.Instance, submitter: webidl.Opt(?*runtime.Instance)) anyerror!void {
        
        return try HTMLFormElementImpl.call_requestSubmit(instance, submitter);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_reset(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return try HTMLFormElementImpl.call_reset(instance);
    }

    pub fn call_checkValidity(instance: *runtime.Instance) anyerror!bool {
        return try HTMLFormElementImpl.call_checkValidity(instance);
    }

    pub fn call_submit(instance: *runtime.Instance) anyerror!void {
        return try HTMLFormElementImpl.call_submit(instance);
    }

    pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
        return try HTMLFormElementImpl.call_reportValidity(instance);
    }

};
