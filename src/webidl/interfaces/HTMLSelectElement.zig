//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLSelectElementImpl = @import("impls").HTMLSelectElement;
const mixins = @import("mixins");
const HTMLElement = @import("interfaces").HTMLElement;
const DOMStringMap = @import("interfaces").DOMStringMap;
const CSSOMString = @import("typedefs").CSSOMString;
const HTMLCollection = @import("interfaces").HTMLCollection;
const TogglePopoverOptions = @import("dictionaries").TogglePopoverOptions;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const HTMLOptionElement = @import("interfaces").HTMLOptionElement;
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
const HTMLOptGroupElement = @import("interfaces").HTMLOptGroupElement;
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
const HTMLOptionsCollection = @import("interfaces").HTMLOptionsCollection;
const NodeList = @import("interfaces").NodeList;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const FullscreenOptions = @import("dictionaries").FullscreenOptions;
const Observable = @import("interfaces").Observable;
const DOMPoint = @import("interfaces").DOMPoint;
const PointerLockOptions = @import("dictionaries").PointerLockOptions;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const ShadowRootInit = @import("dictionaries").ShadowRootInit;

pub const HTMLSelectElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLSelectElement";
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
            .{ "disabled", "get_disabled", "set_disabled" },
            .{ "form", "get_form", null },
            .{ "multiple", "get_multiple", "set_multiple" },
            .{ "name", "get_name", "set_name" },
            .{ "required", "get_required", "set_required" },
            .{ "size", "get_size", "set_size" },
            .{ "type", "get_type", null },
            .{ "options", "get_options", null },
            .{ "length", "get_length", "set_length" },
            .{ "selectedOptions", "get_selectedOptions", null },
            .{ "selectedIndex", "get_selectedIndex", "set_selectedIndex" },
            .{ "value", "get_value", "set_value" },
            .{ "willValidate", "get_willValidate", null },
            .{ "validity", "get_validity", null },
            .{ "validationMessage", "get_validationMessage", null },
            .{ "labels", "get_labels", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "item", "call_item", 1 },
            .{ "namedItem", "call_namedItem", 1 },
            .{ "add", "call_add", 1 },
            .{ "remove", "call_remove", 0 },
            .{ "remove", "call_remove", 1 },
            .{ "checkValidity", "call_checkValidity", 0 },
            .{ "reportValidity", "call_reportValidity", 0 },
            .{ "setCustomValidity", "call_setCustomValidity", 1 },
            .{ "showPicker", "call_showPicker", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "item",
            "namedItem",
            "add",
            "remove",
            "remove",
            "checkValidity",
            "reportValidity",
            "setCustomValidity",
            "showPicker",
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
            .{ "disabled", "get_disabled", "set_disabled" },
            .{ "form", "get_form", null },
            .{ "multiple", "get_multiple", "set_multiple" },
            .{ "name", "get_name", "set_name" },
            .{ "required", "get_required", "set_required" },
            .{ "size", "get_size", "set_size" },
            .{ "type", "get_type", null },
            .{ "options", "get_options", null },
            .{ "length", "get_length", "set_length" },
            .{ "selectedOptions", "get_selectedOptions", null },
            .{ "selectedIndex", "get_selectedIndex", "set_selectedIndex" },
            .{ "value", "get_value", "set_value" },
            .{ "willValidate", "get_willValidate", null },
            .{ "validity", "get_validity", null },
            .{ "validationMessage", "get_validationMessage", null },
            .{ "labels", "get_labels", null },
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
            disabled: bool = undefined,
            form: ?*runtime.Instance = null,
            multiple: bool = undefined,
            name: runtime.DOMString = undefined,
            required: bool = undefined,
            size: u32 = undefined,
            @"type": runtime.DOMString = undefined,
            options: *runtime.Instance = undefined,
            length: u32 = undefined,
            selectedOptions: *runtime.Instance = undefined,
            selectedIndex: i32 = undefined,
            value: runtime.DOMString = undefined,
            willValidate: bool = undefined,
            validity: *runtime.Instance = undefined,
            validationMessage: runtime.DOMString = undefined,
            labels: *runtime.Instance = undefined,
            cached_options: ?*runtime.Instance = null,
            cached_selectedOptions: ?*runtime.Instance = null,
            _internal: ?*HTMLSelectElementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_autocomplete = &get_autocomplete,
        .get_disabled = &get_disabled,
        .get_form = &get_form,
        .get_labels = &get_labels,
        .get_length = &get_length,
        .get_multiple = &get_multiple,
        .get_name = &get_name,
        .get_options = &get_options,
        .get_required = &get_required,
        .get_selectedIndex = &get_selectedIndex,
        .get_selectedOptions = &get_selectedOptions,
        .get_size = &get_size,
        .get_type = &get_type,
        .get_validationMessage = &get_validationMessage,
        .get_validity = &get_validity,
        .get_value = &get_value,
        .get_willValidate = &get_willValidate,

        .set_autocomplete = &set_autocomplete,
        .set_disabled = &set_disabled,
        .set_length = &set_length,
        .set_multiple = &set_multiple,
        .set_name = &set_name,
        .set_required = &set_required,
        .set_selectedIndex = &set_selectedIndex,
        .set_size = &set_size,
        .set_value = &set_value,

        .call_add = &call_add,
        .call_checkValidity = &call_checkValidity,
        .call_item = &call_item,
        .call_namedItem = &call_namedItem,
        .call_remove = &call_remove,
        .call_reportValidity = &call_reportValidity,
        .call_setCustomValidity = &call_setCustomValidity,
        .call_showPicker = &call_showPicker,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLSelectElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return HTMLSelectElementImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLSelectElementImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLSelectElementImpl.call_constructor(ctx);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn get_autocomplete(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLSelectElementImpl.get_autocomplete(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn set_autocomplete(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLSelectElementImpl.set_autocomplete(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_disabled(instance: *runtime.Instance) anyerror!bool {
        return try HTMLSelectElementImpl.get_disabled(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_disabled(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLSelectElementImpl.set_disabled(instance, value);
    }

    pub fn get_form(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try HTMLSelectElementImpl.get_form(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_multiple(instance: *runtime.Instance) anyerror!bool {
        return try HTMLSelectElementImpl.get_multiple(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_multiple(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLSelectElementImpl.set_multiple(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLSelectElementImpl.get_name(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_name(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLSelectElementImpl.set_name(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_required(instance: *runtime.Instance) anyerror!bool {
        return try HTMLSelectElementImpl.get_required(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_required(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLSelectElementImpl.set_required(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect], [ReflectDefault=0]
    pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLSelectElementImpl.get_size(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect], [ReflectDefault=0]
    pub fn set_size(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLSelectElementImpl.set_size(instance, value);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLSelectElementImpl.get_type(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_options(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_options) |cached| {
            return cached;
        }
        const value = try HTMLSelectElementImpl.get_options(instance);
        state.own.cached_options = value;
        return value;
    }

    /// Extended attributes: [CEReactions]
    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLSelectElementImpl.get_length(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_length(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLSelectElementImpl.set_length(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_selectedOptions(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_selectedOptions) |cached| {
            return cached;
        }
        const value = try HTMLSelectElementImpl.get_selectedOptions(instance);
        state.own.cached_selectedOptions = value;
        return value;
    }

    pub fn get_selectedIndex(instance: *runtime.Instance) anyerror!i32 {
        return try HTMLSelectElementImpl.get_selectedIndex(instance);
    }

    pub fn set_selectedIndex(instance: *runtime.Instance, value: i32) anyerror!void {
        try HTMLSelectElementImpl.set_selectedIndex(instance, value);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLSelectElementImpl.get_value(instance);
    }

    pub fn set_value(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try HTMLSelectElementImpl.set_value(instance, value);
    }

    pub fn get_willValidate(instance: *runtime.Instance) anyerror!bool {
        return try HTMLSelectElementImpl.get_willValidate(instance);
    }

    pub fn get_validity(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLSelectElementImpl.get_validity(instance);
    }

    pub fn get_validationMessage(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLSelectElementImpl.get_validationMessage(instance);
    }

    pub fn get_labels(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLSelectElementImpl.get_labels(instance);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
        
        return try HTMLSelectElementImpl.call_item(instance, index);
    }

    pub fn call_namedItem(instance: *runtime.Instance, name: DOMString) anyerror!?*runtime.Instance {
        
        return try HTMLSelectElementImpl.call_namedItem(instance, name);
    }

    pub fn call_setCustomValidity(instance: *runtime.Instance, @"error": DOMString) anyerror!void {
        
        return try HTMLSelectElementImpl.call_setCustomValidity(instance, @"error");
    }

    pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
        return try HTMLSelectElementImpl.call_reportValidity(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_remove(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return try HTMLSelectElementImpl.call_remove(instance);
    }

    pub fn call_checkValidity(instance: *runtime.Instance) anyerror!bool {
        return try HTMLSelectElementImpl.call_checkValidity(instance);
    }

    pub fn call_showPicker(instance: *runtime.Instance) anyerror!void {
        return try HTMLSelectElementImpl.call_showPicker(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_add(instance: *runtime.Instance, element: runtime.JSValue, before: webidl.Opt(?runtime.JSValue)) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try HTMLSelectElementImpl.call_add(instance, element, before);
    }

};
