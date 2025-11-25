//! Generated from: html.idl
//! Generated at: 2025-11-25T19:42:24Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HTMLTextAreaElementImpl = @import("impls").HTMLTextAreaElement;
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
const SelectionMode = @import("enums").SelectionMode;
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
const SpatialNavigationDirection = @import("enums").SpatialNavigationDirection;
const StylePropertyMap = @import("interfaces").StylePropertyMap;
const ShadowRoot = @import("interfaces").ShadowRoot;
const Attr = @import("interfaces").Attr;
const TrustedHTML = @import("interfaces").TrustedHTML;
const NodeList = @import("interfaces").NodeList;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const FullscreenOptions = @import("dictionaries").FullscreenOptions;
const Observable = @import("interfaces").Observable;
const DOMPoint = @import("interfaces").DOMPoint;
const PointerLockOptions = @import("dictionaries").PointerLockOptions;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const ShadowRootInit = @import("dictionaries").ShadowRootInit;

pub const HTMLTextAreaElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLTextAreaElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
            .{ "autocomplete", "get_autocomplete", "set_autocomplete" },
            .{ "cols", "get_cols", "set_cols" },
            .{ "dirName", "get_dirName", "set_dirName" },
            .{ "disabled", "get_disabled", "set_disabled" },
            .{ "form", "get_form", null },
            .{ "maxLength", "get_maxLength", "set_maxLength" },
            .{ "minLength", "get_minLength", "set_minLength" },
            .{ "name", "get_name", "set_name" },
            .{ "placeholder", "get_placeholder", "set_placeholder" },
            .{ "readOnly", "get_readOnly", "set_readOnly" },
            .{ "required", "get_required", "set_required" },
            .{ "rows", "get_rows", "set_rows" },
            .{ "wrap", "get_wrap", "set_wrap" },
            .{ "type", "get_type", null },
            .{ "defaultValue", "get_defaultValue", "set_defaultValue" },
            .{ "value", "get_value", "set_value" },
            .{ "textLength", "get_textLength", null },
            .{ "willValidate", "get_willValidate", null },
            .{ "validity", "get_validity", null },
            .{ "validationMessage", "get_validationMessage", null },
            .{ "labels", "get_labels", null },
            .{ "selectionStart", "get_selectionStart", "set_selectionStart" },
            .{ "selectionEnd", "get_selectionEnd", "set_selectionEnd" },
            .{ "selectionDirection", "get_selectionDirection", "set_selectionDirection" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "checkValidity", "call_checkValidity", 0 },
            .{ "reportValidity", "call_reportValidity", 0 },
            .{ "setCustomValidity", "call_setCustomValidity", 1 },
            .{ "select", "call_select", 0 },
            .{ "setRangeText", "call_setRangeText", 1 },
            .{ "setRangeText", "call_setRangeText", 3 },
            .{ "setSelectionRange", "call_setSelectionRange", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "checkValidity",
            "reportValidity",
            "setCustomValidity",
            "select",
            "setRangeText",
            "setRangeText",
            "setSelectionRange",
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
            .{ "autocomplete", "get_autocomplete", "set_autocomplete" },
            .{ "cols", "get_cols", "set_cols" },
            .{ "dirName", "get_dirName", "set_dirName" },
            .{ "disabled", "get_disabled", "set_disabled" },
            .{ "form", "get_form", null },
            .{ "maxLength", "get_maxLength", "set_maxLength" },
            .{ "minLength", "get_minLength", "set_minLength" },
            .{ "name", "get_name", "set_name" },
            .{ "placeholder", "get_placeholder", "set_placeholder" },
            .{ "readOnly", "get_readOnly", "set_readOnly" },
            .{ "required", "get_required", "set_required" },
            .{ "rows", "get_rows", "set_rows" },
            .{ "wrap", "get_wrap", "set_wrap" },
            .{ "type", "get_type", null },
            .{ "defaultValue", "get_defaultValue", "set_defaultValue" },
            .{ "value", "get_value", "set_value" },
            .{ "textLength", "get_textLength", null },
            .{ "willValidate", "get_willValidate", null },
            .{ "validity", "get_validity", null },
            .{ "validationMessage", "get_validationMessage", null },
            .{ "labels", "get_labels", null },
            .{ "selectionStart", "get_selectionStart", "set_selectionStart" },
            .{ "selectionEnd", "get_selectionEnd", "set_selectionEnd" },
            .{ "selectionDirection", "get_selectionDirection", "set_selectionDirection" },
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
            autocomplete: runtime.DOMString = undefined,
            cols: u32 = undefined,
            dirName: runtime.DOMString = undefined,
            disabled: bool = undefined,
            form: ?*runtime.Instance = null,
            maxLength: i32 = undefined,
            minLength: i32 = undefined,
            name: runtime.DOMString = undefined,
            placeholder: runtime.DOMString = undefined,
            readOnly: bool = undefined,
            required: bool = undefined,
            rows: u32 = undefined,
            wrap: runtime.DOMString = undefined,
            @"type": runtime.DOMString = undefined,
            defaultValue: runtime.DOMString = undefined,
            value: runtime.DOMString = undefined,
            textLength: u32 = undefined,
            willValidate: bool = undefined,
            validity: *runtime.Instance = undefined,
            validationMessage: runtime.DOMString = undefined,
            labels: *runtime.Instance = undefined,
            selectionStart: u32 = undefined,
            selectionEnd: u32 = undefined,
            selectionDirection: runtime.DOMString = undefined,
            _internal: ?*HTMLTextAreaElementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_autocomplete = &get_autocomplete,
        .get_cols = &get_cols,
        .get_defaultValue = &get_defaultValue,
        .get_dirName = &get_dirName,
        .get_disabled = &get_disabled,
        .get_form = &get_form,
        .get_labels = &get_labels,
        .get_maxLength = &get_maxLength,
        .get_minLength = &get_minLength,
        .get_name = &get_name,
        .get_placeholder = &get_placeholder,
        .get_readOnly = &get_readOnly,
        .get_required = &get_required,
        .get_rows = &get_rows,
        .get_selectionDirection = &get_selectionDirection,
        .get_selectionEnd = &get_selectionEnd,
        .get_selectionStart = &get_selectionStart,
        .get_textLength = &get_textLength,
        .get_type = &get_type,
        .get_validationMessage = &get_validationMessage,
        .get_validity = &get_validity,
        .get_value = &get_value,
        .get_willValidate = &get_willValidate,
        .get_wrap = &get_wrap,

        .set_autocomplete = &set_autocomplete,
        .set_cols = &set_cols,
        .set_defaultValue = &set_defaultValue,
        .set_dirName = &set_dirName,
        .set_disabled = &set_disabled,
        .set_maxLength = &set_maxLength,
        .set_minLength = &set_minLength,
        .set_name = &set_name,
        .set_placeholder = &set_placeholder,
        .set_readOnly = &set_readOnly,
        .set_required = &set_required,
        .set_rows = &set_rows,
        .set_selectionDirection = &set_selectionDirection,
        .set_selectionEnd = &set_selectionEnd,
        .set_selectionStart = &set_selectionStart,
        .set_value = &set_value,
        .set_wrap = &set_wrap,

        .call_checkValidity = &call_checkValidity,
        .call_reportValidity = &call_reportValidity,
        .call_select = &call_select,
        .call_setCustomValidity = &call_setCustomValidity,
        .call_setRangeText = &call_setRangeText,
        .call_setSelectionRange = &call_setSelectionRange,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLTextAreaElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLTextAreaElementImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLTextAreaElementImpl.call_constructor(allocator, ctx);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn get_autocomplete(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTextAreaElementImpl.get_autocomplete(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn set_autocomplete(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTextAreaElementImpl.set_autocomplete(instance, value);
    }

    /// Extended attributes: [CEReactions], [ReflectPositiveWithFallback], [ReflectDefault=20]
    pub fn get_cols(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLTextAreaElementImpl.get_cols(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectPositiveWithFallback], [ReflectDefault=20]
    pub fn set_cols(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTextAreaElementImpl.set_cols(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_dirName(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTextAreaElementImpl.get_dirName(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_dirName(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTextAreaElementImpl.set_dirName(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_disabled(instance: *runtime.Instance) anyerror!bool {
        return try HTMLTextAreaElementImpl.get_disabled(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_disabled(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTextAreaElementImpl.set_disabled(instance, value);
    }

    pub fn get_form(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try HTMLTextAreaElementImpl.get_form(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectNonNegative]
    pub fn get_maxLength(instance: *runtime.Instance) anyerror!i32 {
        return try HTMLTextAreaElementImpl.get_maxLength(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectNonNegative]
    pub fn set_maxLength(instance: *runtime.Instance, value: i32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTextAreaElementImpl.set_maxLength(instance, value);
    }

    /// Extended attributes: [CEReactions], [ReflectNonNegative]
    pub fn get_minLength(instance: *runtime.Instance) anyerror!i32 {
        return try HTMLTextAreaElementImpl.get_minLength(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectNonNegative]
    pub fn set_minLength(instance: *runtime.Instance, value: i32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTextAreaElementImpl.set_minLength(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTextAreaElementImpl.get_name(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_name(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTextAreaElementImpl.set_name(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_placeholder(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTextAreaElementImpl.get_placeholder(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_placeholder(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTextAreaElementImpl.set_placeholder(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_readOnly(instance: *runtime.Instance) anyerror!bool {
        return try HTMLTextAreaElementImpl.get_readOnly(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_readOnly(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTextAreaElementImpl.set_readOnly(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_required(instance: *runtime.Instance) anyerror!bool {
        return try HTMLTextAreaElementImpl.get_required(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_required(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTextAreaElementImpl.set_required(instance, value);
    }

    /// Extended attributes: [CEReactions], [ReflectPositiveWithFallback], [ReflectDefault=2]
    pub fn get_rows(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLTextAreaElementImpl.get_rows(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectPositiveWithFallback], [ReflectDefault=2]
    pub fn set_rows(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTextAreaElementImpl.set_rows(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_wrap(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTextAreaElementImpl.get_wrap(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_wrap(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTextAreaElementImpl.set_wrap(instance, value);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTextAreaElementImpl.get_type(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_defaultValue(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTextAreaElementImpl.get_defaultValue(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_defaultValue(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLTextAreaElementImpl.set_defaultValue(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_value(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTextAreaElementImpl.get_value(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_value(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try HTMLTextAreaElementImpl.set_value(instance, value);
    }

    pub fn get_textLength(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLTextAreaElementImpl.get_textLength(instance);
    }

    pub fn get_willValidate(instance: *runtime.Instance) anyerror!bool {
        return try HTMLTextAreaElementImpl.get_willValidate(instance);
    }

    pub fn get_validity(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLTextAreaElementImpl.get_validity(instance);
    }

    pub fn get_validationMessage(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTextAreaElementImpl.get_validationMessage(instance);
    }

    pub fn get_labels(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLTextAreaElementImpl.get_labels(instance);
    }

    pub fn get_selectionStart(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLTextAreaElementImpl.get_selectionStart(instance);
    }

    pub fn set_selectionStart(instance: *runtime.Instance, value: u32) anyerror!void {
        try HTMLTextAreaElementImpl.set_selectionStart(instance, value);
    }

    pub fn get_selectionEnd(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLTextAreaElementImpl.get_selectionEnd(instance);
    }

    pub fn set_selectionEnd(instance: *runtime.Instance, value: u32) anyerror!void {
        try HTMLTextAreaElementImpl.set_selectionEnd(instance, value);
    }

    pub fn get_selectionDirection(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLTextAreaElementImpl.get_selectionDirection(instance);
    }

    pub fn set_selectionDirection(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try HTMLTextAreaElementImpl.set_selectionDirection(instance, value);
    }

    pub fn call_select(instance: *runtime.Instance) anyerror!void {
        return try HTMLTextAreaElementImpl.call_select(instance);
    }

    pub fn call_setRangeText(instance: *runtime.Instance, replacement: DOMString) anyerror!void {
        
        return try HTMLTextAreaElementImpl.call_setRangeText(instance, replacement);
    }

    pub fn call_checkValidity(instance: *runtime.Instance) anyerror!bool {
        return try HTMLTextAreaElementImpl.call_checkValidity(instance);
    }

    pub fn call_setSelectionRange(instance: *runtime.Instance, start: u32, end: u32, direction: DOMString) anyerror!void {
        
        return try HTMLTextAreaElementImpl.call_setSelectionRange(instance, start, end, direction);
    }

    pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
        return try HTMLTextAreaElementImpl.call_reportValidity(instance);
    }

    pub fn call_setCustomValidity(instance: *runtime.Instance, @"error": DOMString) anyerror!void {
        
        return try HTMLTextAreaElementImpl.call_setCustomValidity(instance, @"error");
    }

};
