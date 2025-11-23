//! Generated from: html.idl
//! Generated at: 2025-11-23T01:22:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HTMLObjectElementImpl = @import("impls").HTMLObjectElement;
const HTMLElement = @import("interfaces").HTMLElement;
const DOMStringMap = @import("interfaces").DOMStringMap;
const CSSOMString = @import("interfaces").CSSOMString;
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
const ValidityState = @import("interfaces").ValidityState;
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
const HTMLFormElement = @import("interfaces").HTMLFormElement;
const SpatialNavigationSearchOptions = @import("dictionaries").SpatialNavigationSearchOptions;
const GetAnimationsOptions = @import("dictionaries").GetAnimationsOptions;
const EventHandler = @import("typedefs").EventHandler;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const WindowProxy = @import("interfaces").WindowProxy;
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

pub const HTMLObjectElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLObjectElement";
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
            .{ "data", "get_data", "set_data" },
            .{ "type", "get_type", "set_type" },
            .{ "name", "get_name", "set_name" },
            .{ "form", "get_form", null },
            .{ "width", "get_width", "set_width" },
            .{ "height", "get_height", "set_height" },
            .{ "contentDocument", "get_contentDocument", null },
            .{ "contentWindow", "get_contentWindow", null },
            .{ "willValidate", "get_willValidate", null },
            .{ "validity", "get_validity", null },
            .{ "validationMessage", "get_validationMessage", null },
            .{ "align", "get_align", "set_align" },
            .{ "archive", "get_archive", "set_archive" },
            .{ "code", "get_code", "set_code" },
            .{ "declare", "get_declare", "set_declare" },
            .{ "hspace", "get_hspace", "set_hspace" },
            .{ "standby", "get_standby", "set_standby" },
            .{ "vspace", "get_vspace", "set_vspace" },
            .{ "codeBase", "get_codeBase", "set_codeBase" },
            .{ "codeType", "get_codeType", "set_codeType" },
            .{ "useMap", "get_useMap", "set_useMap" },
            .{ "border", "get_border", "set_border" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "getSVGDocument", "call_getSVGDocument", 0 },
            .{ "checkValidity", "call_checkValidity", 0 },
            .{ "reportValidity", "call_reportValidity", 0 },
            .{ "setCustomValidity", "call_setCustomValidity", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getSVGDocument",
            "checkValidity",
            "reportValidity",
            "setCustomValidity",
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
            .{ "data", "get_data", "set_data" },
            .{ "type", "get_type", "set_type" },
            .{ "name", "get_name", "set_name" },
            .{ "form", "get_form", null },
            .{ "width", "get_width", "set_width" },
            .{ "height", "get_height", "set_height" },
            .{ "contentDocument", "get_contentDocument", null },
            .{ "contentWindow", "get_contentWindow", null },
            .{ "willValidate", "get_willValidate", null },
            .{ "validity", "get_validity", null },
            .{ "validationMessage", "get_validationMessage", null },
            .{ "align", "get_align", "set_align" },
            .{ "archive", "get_archive", "set_archive" },
            .{ "code", "get_code", "set_code" },
            .{ "declare", "get_declare", "set_declare" },
            .{ "hspace", "get_hspace", "set_hspace" },
            .{ "standby", "get_standby", "set_standby" },
            .{ "vspace", "get_vspace", "set_vspace" },
            .{ "codeBase", "get_codeBase", "set_codeBase" },
            .{ "codeType", "get_codeType", "set_codeType" },
            .{ "useMap", "get_useMap", "set_useMap" },
            .{ "border", "get_border", "set_border" },
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
            data: runtime.USVString = undefined,
            @"type": runtime.DOMString = undefined,
            name: runtime.DOMString = undefined,
            form: ?HTMLFormElement = null,
            width: runtime.DOMString = undefined,
            height: runtime.DOMString = undefined,
            contentDocument: ?Document = null,
            contentWindow: ?WindowProxy = null,
            willValidate: bool = undefined,
            validity: ValidityState = undefined,
            validationMessage: runtime.DOMString = undefined,
            @"align": runtime.DOMString = undefined,
            archive: runtime.DOMString = undefined,
            code: runtime.DOMString = undefined,
            declare: bool = undefined,
            hspace: u32 = undefined,
            standby: runtime.DOMString = undefined,
            vspace: u32 = undefined,
            codeBase: runtime.DOMString = undefined,
            codeType: runtime.DOMString = undefined,
            useMap: runtime.DOMString = undefined,
            border: runtime.DOMString = undefined,
        },
    );

    const delegates = .{

        .get_align = &get_align,
        .get_archive = &get_archive,
        .get_border = &get_border,
        .get_code = &get_code,
        .get_codeBase = &get_codeBase,
        .get_codeType = &get_codeType,
        .get_contentDocument = &get_contentDocument,
        .get_contentWindow = &get_contentWindow,
        .get_data = &get_data,
        .get_declare = &get_declare,
        .get_form = &get_form,
        .get_height = &get_height,
        .get_hspace = &get_hspace,
        .get_name = &get_name,
        .get_standby = &get_standby,
        .get_type = &get_type,
        .get_useMap = &get_useMap,
        .get_validationMessage = &get_validationMessage,
        .get_validity = &get_validity,
        .get_vspace = &get_vspace,
        .get_width = &get_width,
        .get_willValidate = &get_willValidate,

        .set_align = &set_align,
        .set_archive = &set_archive,
        .set_border = &set_border,
        .set_code = &set_code,
        .set_codeBase = &set_codeBase,
        .set_codeType = &set_codeType,
        .set_data = &set_data,
        .set_declare = &set_declare,
        .set_height = &set_height,
        .set_hspace = &set_hspace,
        .set_name = &set_name,
        .set_standby = &set_standby,
        .set_type = &set_type,
        .set_useMap = &set_useMap,
        .set_vspace = &set_vspace,
        .set_width = &set_width,

        .call_checkValidity = &call_checkValidity,
        .call_getSVGDocument = &call_getSVGDocument,
        .call_reportValidity = &call_reportValidity,
        .call_setCustomValidity = &call_setCustomValidity,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLObjectElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLObjectElementImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLObjectElementImpl.call_constructor(allocator, ctx);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn get_data(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLObjectElementImpl.get_data(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn set_data(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLObjectElementImpl.set_data(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLObjectElementImpl.get_type(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_type(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLObjectElementImpl.set_type(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLObjectElementImpl.get_name(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_name(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLObjectElementImpl.set_name(instance, value);
    }

    pub fn get_form(instance: *runtime.Instance) anyerror!HTMLFormElement {
        return try HTMLObjectElementImpl.get_form(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_width(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLObjectElementImpl.get_width(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_width(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLObjectElementImpl.set_width(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_height(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLObjectElementImpl.get_height(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_height(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLObjectElementImpl.set_height(instance, value);
    }

    pub fn get_contentDocument(instance: *runtime.Instance) anyerror!Document {
        return try HTMLObjectElementImpl.get_contentDocument(instance);
    }

    pub fn get_contentWindow(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try HTMLObjectElementImpl.get_contentWindow(instance);
    }

    pub fn get_willValidate(instance: *runtime.Instance) anyerror!bool {
        return try HTMLObjectElementImpl.get_willValidate(instance);
    }

    pub fn get_validity(instance: *runtime.Instance) anyerror!ValidityState {
        return try HTMLObjectElementImpl.get_validity(instance);
    }

    pub fn get_validationMessage(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLObjectElementImpl.get_validationMessage(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_align(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLObjectElementImpl.get_align(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_align(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLObjectElementImpl.set_align(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_archive(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLObjectElementImpl.get_archive(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_archive(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLObjectElementImpl.set_archive(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_code(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLObjectElementImpl.get_code(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_code(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLObjectElementImpl.set_code(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_declare(instance: *runtime.Instance) anyerror!bool {
        return try HTMLObjectElementImpl.get_declare(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_declare(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLObjectElementImpl.set_declare(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_hspace(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLObjectElementImpl.get_hspace(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_hspace(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLObjectElementImpl.set_hspace(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_standby(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLObjectElementImpl.get_standby(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_standby(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLObjectElementImpl.set_standby(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_vspace(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLObjectElementImpl.get_vspace(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_vspace(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLObjectElementImpl.set_vspace(instance, value);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn get_codeBase(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLObjectElementImpl.get_codeBase(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn set_codeBase(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLObjectElementImpl.set_codeBase(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_codeType(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLObjectElementImpl.get_codeType(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_codeType(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLObjectElementImpl.set_codeType(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_useMap(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLObjectElementImpl.get_useMap(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_useMap(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLObjectElementImpl.set_useMap(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect], [LegacyNullToEmptyString]
    pub fn get_border(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLObjectElementImpl.get_border(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect], [LegacyNullToEmptyString]
    pub fn set_border(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLObjectElementImpl.set_border(instance, value);
    }

    pub fn call_setCustomValidity(instance: *runtime.Instance, @"error": DOMString) anyerror!void {
        
        return try HTMLObjectElementImpl.call_setCustomValidity(instance, @"error");
    }

    pub fn call_checkValidity(instance: *runtime.Instance) anyerror!bool {
        return try HTMLObjectElementImpl.call_checkValidity(instance);
    }

    pub fn call_getSVGDocument(instance: *runtime.Instance) anyerror!Document {
        return try HTMLObjectElementImpl.call_getSVGDocument(instance);
    }

    pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
        return try HTMLObjectElementImpl.call_reportValidity(instance);
    }

};
