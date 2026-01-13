//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLOutputElementImpl = @import("impls").HTMLOutputElement;
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

pub const HTMLOutputElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLOutputElement";
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
            .{ "htmlFor", "get_htmlFor", "set_htmlFor" },
            .{ "form", "get_form", null },
            .{ "name", "get_name", "set_name" },
            .{ "type", "get_type", null },
            .{ "defaultValue", "get_defaultValue", "set_defaultValue" },
            .{ "value", "get_value", "set_value" },
            .{ "willValidate", "get_willValidate", null },
            .{ "validity", "get_validity", null },
            .{ "validationMessage", "get_validationMessage", null },
            .{ "labels", "get_labels", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
            .{ "htmlFor", "get_htmlFor", "set_htmlFor" },
            .{ "form", "get_form", null },
            .{ "name", "get_name", "set_name" },
            .{ "type", "get_type", null },
            .{ "defaultValue", "get_defaultValue", "set_defaultValue" },
            .{ "value", "get_value", "set_value" },
            .{ "willValidate", "get_willValidate", null },
            .{ "validity", "get_validity", null },
            .{ "validationMessage", "get_validationMessage", null },
            .{ "labels", "get_labels", null },
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
            htmlFor: *runtime.Instance = undefined,
            form: ?*runtime.Instance = null,
            name: typedefs.DOMString = undefined,
            @"type": typedefs.DOMString = undefined,
            defaultValue: typedefs.DOMString = undefined,
            value: typedefs.DOMString = undefined,
            willValidate: bool = undefined,
            validity: *runtime.Instance = undefined,
            validationMessage: typedefs.DOMString = undefined,
            labels: *runtime.Instance = undefined,
            cached_htmlFor: ?*runtime.Instance = null,
            _internal: ?*HTMLOutputElementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_defaultValue = &get_defaultValue,
        .get_form = &get_form,
        .get_htmlFor = &get_htmlFor,
        .get_labels = &get_labels,
        .get_name = &get_name,
        .get_type = &get_type,
        .get_validationMessage = &get_validationMessage,
        .get_validity = &get_validity,
        .get_value = &get_value,
        .get_willValidate = &get_willValidate,

        .set_defaultValue = &set_defaultValue,
        .set_htmlFor = &set_htmlFor,
        .set_name = &set_name,
        .set_value = &set_value,

        .call_checkValidity = &call_checkValidity,
        .call_reportValidity = &call_reportValidity,
        .call_setCustomValidity = &call_setCustomValidity,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLOutputElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return HTMLOutputElementImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLOutputElementImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLOutputElementImpl.call_constructor(ctx);
    }

    /// Extended attributes: [SameObject], [PutForwards=value], [Reflect="for"]
    pub fn get_htmlFor(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_htmlFor) |cached| {
            return cached;
        }
        const value = try HTMLOutputElementImpl.get_htmlFor(instance);
        state.own.cached_htmlFor = value;
        return value;
    }

    /// Extended attributes: [SameObject], [PutForwards=value], [Reflect="for"]
    pub fn set_htmlFor(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [PutForwards] - Get target object and set the forwarded property
        // Per WebIDL spec: setting 'htmlFor' forwards to 'value' on the attribute's value
        const target = try get_htmlFor(instance);
        
        // Use JavaScript [[Set]] semantics to set the forwarded property
        // This respects prototype chain and user-defined setters
        // Note: target is a *Instance, use setPropertyOnInstance
        try runtime.setPropertyOnInstance(target, "value", value);
    }

    pub fn get_form(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try HTMLOutputElementImpl.get_form(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLOutputElementImpl.get_name(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_name(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLOutputElementImpl.set_name(instance, value);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLOutputElementImpl.get_type(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_defaultValue(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLOutputElementImpl.get_defaultValue(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_defaultValue(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLOutputElementImpl.set_defaultValue(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_value(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLOutputElementImpl.get_value(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_value(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLOutputElementImpl.set_value(instance, value);
    }

    pub fn get_willValidate(instance: *runtime.Instance) anyerror!bool {
        return try HTMLOutputElementImpl.get_willValidate(instance);
    }

    pub fn get_validity(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLOutputElementImpl.get_validity(instance);
    }

    pub fn get_validationMessage(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLOutputElementImpl.get_validationMessage(instance);
    }

    pub fn get_labels(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLOutputElementImpl.get_labels(instance);
    }

    pub fn call_setCustomValidity(instance: *runtime.Instance, @"error": DOMString) anyerror!void {
        
        return try HTMLOutputElementImpl.call_setCustomValidity(instance, @"error");
    }

    pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
        return try HTMLOutputElementImpl.call_reportValidity(instance);
    }

    pub fn call_checkValidity(instance: *runtime.Instance) anyerror!bool {
        return try HTMLOutputElementImpl.call_checkValidity(instance);
    }

};
