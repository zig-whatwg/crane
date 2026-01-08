//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLTextAreaElementImpl = @import("impls").HTMLTextAreaElement;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const HTMLElement = @import("HTMLElement.zig").HTMLElement;
const DOMStringMap = @import("DOMStringMap.zig").DOMStringMap;
const CSSOMString = @import("typedefs").CSSOMString;
const HTMLCollection = @import("HTMLCollection.zig").HTMLCollection;
const TogglePopoverOptions = @import("dictionaries").TogglePopoverOptions;
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
const ValidityState = @import("ValidityState.zig").ValidityState;
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
const SelectionMode = @import("enums").SelectionMode;
const KeyframeAnimationOptions = @import("dictionaries").KeyframeAnimationOptions;
const StylePropertyMapReadOnly = @import("StylePropertyMapReadOnly.zig").StylePropertyMapReadOnly;
const DOMTokenList = @import("DOMTokenList.zig").DOMTokenList;
const StartViewTransitionOptions = @import("dictionaries").StartViewTransitionOptions;
const EditContext = @import("EditContext.zig").EditContext;
const DOMRect = @import("DOMRect.zig").DOMRect;
const ElementInternals = @import("ElementInternals.zig").ElementInternals;
const ViewTransition = @import("ViewTransition.zig").ViewTransition;
const HTMLFormElement = @import("HTMLFormElement.zig").HTMLFormElement;
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
const NodeList = @import("NodeList.zig").NodeList;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const FullscreenOptions = @import("dictionaries").FullscreenOptions;
const Observable = @import("Observable.zig").Observable;
const DOMPoint = @import("DOMPoint.zig").DOMPoint;
const PointerLockOptions = @import("dictionaries").PointerLockOptions;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const ShadowRootInit = @import("dictionaries").ShadowRootInit;

pub const HTMLTextAreaElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLTextAreaElement";
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
            .{ "setSelectionRange", "call_setSelectionRange", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "checkValidity",
            "reportValidity",
            "setCustomValidity",
            "select",
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
            autocomplete: typedefs.DOMString = undefined,
            cols: u32 = undefined,
            dirName: typedefs.DOMString = undefined,
            disabled: bool = undefined,
            form: ?*runtime.Instance = null,
            maxLength: i32 = undefined,
            minLength: i32 = undefined,
            name: typedefs.DOMString = undefined,
            placeholder: typedefs.DOMString = undefined,
            readOnly: bool = undefined,
            required: bool = undefined,
            rows: u32 = undefined,
            wrap: typedefs.DOMString = undefined,
            @"type": typedefs.DOMString = undefined,
            defaultValue: typedefs.DOMString = undefined,
            value: typedefs.DOMString = undefined,
            textLength: u32 = undefined,
            willValidate: bool = undefined,
            validity: *runtime.Instance = undefined,
            validationMessage: typedefs.DOMString = undefined,
            labels: *runtime.Instance = undefined,
            selectionStart: u32 = undefined,
            selectionEnd: u32 = undefined,
            selectionDirection: typedefs.DOMString = undefined,
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

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLTextAreaElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return HTMLTextAreaElementImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLTextAreaElementImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLTextAreaElementImpl.call_constructor(ctx);
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

    pub fn call_setRangeText(instance: *runtime.Instance, replacement: DOMString) anyerror!void {
        
        return try HTMLTextAreaElementImpl.call_setRangeText(instance, replacement);
    }

    pub fn call_select(instance: *runtime.Instance) anyerror!void {
        return try HTMLTextAreaElementImpl.call_select(instance);
    }

    pub fn call_setCustomValidity(instance: *runtime.Instance, @"error": DOMString) anyerror!void {
        
        return try HTMLTextAreaElementImpl.call_setCustomValidity(instance, @"error");
    }

    pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
        return try HTMLTextAreaElementImpl.call_reportValidity(instance);
    }

    pub fn call_setSelectionRange(instance: *runtime.Instance, start: u32, end: u32, direction: webidl.Opt(DOMString)) anyerror!void {
        
        return try HTMLTextAreaElementImpl.call_setSelectionRange(instance, start, end, direction);
    }

    pub fn call_checkValidity(instance: *runtime.Instance) anyerror!bool {
        return try HTMLTextAreaElementImpl.call_checkValidity(instance);
    }

};
