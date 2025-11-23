//! Generated from: html.idl
//! Generated at: 2025-11-23T19:47:41Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HTMLButtonElementImpl = @import("impls").HTMLButtonElement;
const HTMLElement = @import("interfaces").HTMLElement;
const PopoverTargetAttributes = @import("interfaces").PopoverTargetAttributes;
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

pub const HTMLButtonElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLButtonElement";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *HTMLElement;
        pub const MixinTypes = &.{
            PopoverTargetAttributes,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "command", "get_command", "set_command" },
            .{ "commandForElement", "get_commandForElement", "set_commandForElement" },
            .{ "disabled", "get_disabled", "set_disabled" },
            .{ "form", "get_form", null },
            .{ "formAction", "get_formAction", "set_formAction" },
            .{ "formEnctype", "get_formEnctype", "set_formEnctype" },
            .{ "formMethod", "get_formMethod", "set_formMethod" },
            .{ "formNoValidate", "get_formNoValidate", "set_formNoValidate" },
            .{ "formTarget", "get_formTarget", "set_formTarget" },
            .{ "name", "get_name", "set_name" },
            .{ "type", "get_type", "set_type" },
            .{ "value", "get_value", "set_value" },
            .{ "willValidate", "get_willValidate", null },
            .{ "validity", "get_validity", null },
            .{ "validationMessage", "get_validationMessage", null },
            .{ "labels", "get_labels", null },
            .{ "popoverTargetElement", "get_popoverTargetElement", "set_popoverTargetElement" },
            .{ "popoverTargetAction", "get_popoverTargetAction", "set_popoverTargetAction" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "checkValidity", "call_checkValidity", 0 },
            .{ "reportValidity", "call_reportValidity", 0 },
            .{ "setCustomValidity", "call_setCustomValidity", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
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
            .{ "command", "get_command", "set_command" },
            .{ "commandForElement", "get_commandForElement", "set_commandForElement" },
            .{ "disabled", "get_disabled", "set_disabled" },
            .{ "form", "get_form", null },
            .{ "formAction", "get_formAction", "set_formAction" },
            .{ "formEnctype", "get_formEnctype", "set_formEnctype" },
            .{ "formMethod", "get_formMethod", "set_formMethod" },
            .{ "formNoValidate", "get_formNoValidate", "set_formNoValidate" },
            .{ "formTarget", "get_formTarget", "set_formTarget" },
            .{ "name", "get_name", "set_name" },
            .{ "type", "get_type", "set_type" },
            .{ "value", "get_value", "set_value" },
            .{ "willValidate", "get_willValidate", null },
            .{ "validity", "get_validity", null },
            .{ "validationMessage", "get_validationMessage", null },
            .{ "labels", "get_labels", null },
            .{ "popoverTargetElement", "get_popoverTargetElement", "set_popoverTargetElement" },
            .{ "popoverTargetAction", "get_popoverTargetAction", "set_popoverTargetAction" },
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
            command: runtime.DOMString = undefined,
            commandForElement: ?*runtime.Instance = null,
            disabled: bool = undefined,
            form: ?*runtime.Instance = null,
            formAction: runtime.USVString = undefined,
            formEnctype: runtime.DOMString = undefined,
            formMethod: runtime.DOMString = undefined,
            formNoValidate: bool = undefined,
            formTarget: runtime.DOMString = undefined,
            name: runtime.DOMString = undefined,
            @"type": runtime.DOMString = undefined,
            value: runtime.DOMString = undefined,
            willValidate: bool = undefined,
            validity: *runtime.Instance = undefined,
            validationMessage: runtime.DOMString = undefined,
            labels: *runtime.Instance = undefined,
            popoverTargetElement: ?*runtime.Instance = null,
            popoverTargetAction: runtime.DOMString = undefined,
            _internal: ?*HTMLButtonElementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_command = &get_command,
        .get_commandForElement = &get_commandForElement,
        .get_disabled = &get_disabled,
        .get_form = &get_form,
        .get_formAction = &get_formAction,
        .get_formEnctype = &get_formEnctype,
        .get_formMethod = &get_formMethod,
        .get_formNoValidate = &get_formNoValidate,
        .get_formTarget = &get_formTarget,
        .get_labels = &get_labels,
        .get_name = &get_name,
        .get_popoverTargetAction = &get_popoverTargetAction,
        .get_popoverTargetElement = &get_popoverTargetElement,
        .get_type = &get_type,
        .get_validationMessage = &get_validationMessage,
        .get_validity = &get_validity,
        .get_value = &get_value,
        .get_willValidate = &get_willValidate,

        .set_command = &set_command,
        .set_commandForElement = &set_commandForElement,
        .set_disabled = &set_disabled,
        .set_formAction = &set_formAction,
        .set_formEnctype = &set_formEnctype,
        .set_formMethod = &set_formMethod,
        .set_formNoValidate = &set_formNoValidate,
        .set_formTarget = &set_formTarget,
        .set_name = &set_name,
        .set_popoverTargetAction = &set_popoverTargetAction,
        .set_popoverTargetElement = &set_popoverTargetElement,
        .set_type = &set_type,
        .set_value = &set_value,

        .call_checkValidity = &call_checkValidity,
        .call_reportValidity = &call_reportValidity,
        .call_setCustomValidity = &call_setCustomValidity,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLButtonElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLButtonElementImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLButtonElementImpl.call_constructor(allocator, ctx);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn get_command(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLButtonElementImpl.get_command(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn set_command(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLButtonElementImpl.set_command(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_commandForElement(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLButtonElementImpl.get_commandForElement(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_commandForElement(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLButtonElementImpl.set_commandForElement(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_disabled(instance: *runtime.Instance) anyerror!bool {
        return try HTMLButtonElementImpl.get_disabled(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_disabled(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLButtonElementImpl.set_disabled(instance, value);
    }

    pub fn get_form(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLButtonElementImpl.get_form(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn get_formAction(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLButtonElementImpl.get_formAction(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn set_formAction(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLButtonElementImpl.set_formAction(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_formEnctype(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLButtonElementImpl.get_formEnctype(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_formEnctype(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLButtonElementImpl.set_formEnctype(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_formMethod(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLButtonElementImpl.get_formMethod(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_formMethod(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLButtonElementImpl.set_formMethod(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_formNoValidate(instance: *runtime.Instance) anyerror!bool {
        return try HTMLButtonElementImpl.get_formNoValidate(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_formNoValidate(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLButtonElementImpl.set_formNoValidate(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_formTarget(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLButtonElementImpl.get_formTarget(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_formTarget(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLButtonElementImpl.set_formTarget(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLButtonElementImpl.get_name(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_name(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLButtonElementImpl.set_name(instance, value);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLButtonElementImpl.get_type(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn set_type(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLButtonElementImpl.set_type(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_value(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLButtonElementImpl.get_value(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_value(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLButtonElementImpl.set_value(instance, value);
    }

    pub fn get_willValidate(instance: *runtime.Instance) anyerror!bool {
        return try HTMLButtonElementImpl.get_willValidate(instance);
    }

    pub fn get_validity(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLButtonElementImpl.get_validity(instance);
    }

    pub fn get_validationMessage(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLButtonElementImpl.get_validationMessage(instance);
    }

    pub fn get_labels(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLButtonElementImpl.get_labels(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_popoverTargetElement(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLButtonElementImpl.get_popoverTargetElement(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_popoverTargetElement(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLButtonElementImpl.set_popoverTargetElement(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_popoverTargetAction(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLButtonElementImpl.get_popoverTargetAction(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_popoverTargetAction(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLButtonElementImpl.set_popoverTargetAction(instance, value);
    }

    pub fn call_checkValidity(instance: *runtime.Instance) anyerror!bool {
        return try HTMLButtonElementImpl.call_checkValidity(instance);
    }

    pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
        return try HTMLButtonElementImpl.call_reportValidity(instance);
    }

    pub fn call_setCustomValidity(instance: *runtime.Instance, @"error": DOMString) anyerror!void {
        
        return try HTMLButtonElementImpl.call_setCustomValidity(instance, @"error");
    }

};
