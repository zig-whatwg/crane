//! Generated from: html.idl
//! Generated at: 2025-11-25T20:02:32Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HTMLInputElementImpl = @import("impls").HTMLInputElement;
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
const FileList = @import("interfaces").FileList;
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
const HTMLDataListElement = @import("interfaces").HTMLDataListElement;
const PointerLockOptions = @import("dictionaries").PointerLockOptions;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const ShadowRootInit = @import("dictionaries").ShadowRootInit;
const FileSystemEntry = @import("interfaces").FileSystemEntry;

pub const HTMLInputElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLInputElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
            .{ "accept", "get_accept", "set_accept" },
            .{ "alpha", "get_alpha", "set_alpha" },
            .{ "alt", "get_alt", "set_alt" },
            .{ "autocomplete", "get_autocomplete", "set_autocomplete" },
            .{ "defaultChecked", "get_defaultChecked", "set_defaultChecked" },
            .{ "checked", "get_checked", "set_checked" },
            .{ "colorSpace", "get_colorSpace", "set_colorSpace" },
            .{ "dirName", "get_dirName", "set_dirName" },
            .{ "disabled", "get_disabled", "set_disabled" },
            .{ "form", "get_form", null },
            .{ "files", "get_files", "set_files" },
            .{ "formAction", "get_formAction", "set_formAction" },
            .{ "formEnctype", "get_formEnctype", "set_formEnctype" },
            .{ "formMethod", "get_formMethod", "set_formMethod" },
            .{ "formNoValidate", "get_formNoValidate", "set_formNoValidate" },
            .{ "formTarget", "get_formTarget", "set_formTarget" },
            .{ "height", "get_height", "set_height" },
            .{ "indeterminate", "get_indeterminate", "set_indeterminate" },
            .{ "list", "get_list", null },
            .{ "max", "get_max", "set_max" },
            .{ "maxLength", "get_maxLength", "set_maxLength" },
            .{ "min", "get_min", "set_min" },
            .{ "minLength", "get_minLength", "set_minLength" },
            .{ "multiple", "get_multiple", "set_multiple" },
            .{ "name", "get_name", "set_name" },
            .{ "pattern", "get_pattern", "set_pattern" },
            .{ "placeholder", "get_placeholder", "set_placeholder" },
            .{ "readOnly", "get_readOnly", "set_readOnly" },
            .{ "required", "get_required", "set_required" },
            .{ "size", "get_size", "set_size" },
            .{ "src", "get_src", "set_src" },
            .{ "step", "get_step", "set_step" },
            .{ "type", "get_type", "set_type" },
            .{ "defaultValue", "get_defaultValue", "set_defaultValue" },
            .{ "value", "get_value", "set_value" },
            .{ "valueAsDate", "get_valueAsDate", "set_valueAsDate" },
            .{ "valueAsNumber", "get_valueAsNumber", "set_valueAsNumber" },
            .{ "width", "get_width", "set_width" },
            .{ "willValidate", "get_willValidate", null },
            .{ "validity", "get_validity", null },
            .{ "validationMessage", "get_validationMessage", null },
            .{ "labels", "get_labels", null },
            .{ "selectionStart", "get_selectionStart", "set_selectionStart" },
            .{ "selectionEnd", "get_selectionEnd", "set_selectionEnd" },
            .{ "selectionDirection", "get_selectionDirection", "set_selectionDirection" },
            .{ "capture", "get_capture", "set_capture" },
            .{ "webkitdirectory", "get_webkitdirectory", "set_webkitdirectory" },
            .{ "webkitEntries", "get_webkitEntries", null },
            .{ "align", "get_align", "set_align" },
            .{ "useMap", "get_useMap", "set_useMap" },
            .{ "popoverTargetElement", "get_popoverTargetElement", "set_popoverTargetElement" },
            .{ "popoverTargetAction", "get_popoverTargetAction", "set_popoverTargetAction" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "stepUp", "call_stepUp", 0 },
            .{ "stepDown", "call_stepDown", 0 },
            .{ "checkValidity", "call_checkValidity", 0 },
            .{ "reportValidity", "call_reportValidity", 0 },
            .{ "setCustomValidity", "call_setCustomValidity", 1 },
            .{ "select", "call_select", 0 },
            .{ "setRangeText", "call_setRangeText", 1 },
            .{ "setRangeText", "call_setRangeText", 3 },
            .{ "setSelectionRange", "call_setSelectionRange", 2 },
            .{ "showPicker", "call_showPicker", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "stepUp",
            "stepDown",
            "checkValidity",
            "reportValidity",
            "setCustomValidity",
            "select",
            "setRangeText",
            "setRangeText",
            "setSelectionRange",
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
            .{ "accept", "get_accept", "set_accept" },
            .{ "alpha", "get_alpha", "set_alpha" },
            .{ "alt", "get_alt", "set_alt" },
            .{ "autocomplete", "get_autocomplete", "set_autocomplete" },
            .{ "defaultChecked", "get_defaultChecked", "set_defaultChecked" },
            .{ "checked", "get_checked", "set_checked" },
            .{ "colorSpace", "get_colorSpace", "set_colorSpace" },
            .{ "dirName", "get_dirName", "set_dirName" },
            .{ "disabled", "get_disabled", "set_disabled" },
            .{ "form", "get_form", null },
            .{ "files", "get_files", "set_files" },
            .{ "formAction", "get_formAction", "set_formAction" },
            .{ "formEnctype", "get_formEnctype", "set_formEnctype" },
            .{ "formMethod", "get_formMethod", "set_formMethod" },
            .{ "formNoValidate", "get_formNoValidate", "set_formNoValidate" },
            .{ "formTarget", "get_formTarget", "set_formTarget" },
            .{ "height", "get_height", "set_height" },
            .{ "indeterminate", "get_indeterminate", "set_indeterminate" },
            .{ "list", "get_list", null },
            .{ "max", "get_max", "set_max" },
            .{ "maxLength", "get_maxLength", "set_maxLength" },
            .{ "min", "get_min", "set_min" },
            .{ "minLength", "get_minLength", "set_minLength" },
            .{ "multiple", "get_multiple", "set_multiple" },
            .{ "name", "get_name", "set_name" },
            .{ "pattern", "get_pattern", "set_pattern" },
            .{ "placeholder", "get_placeholder", "set_placeholder" },
            .{ "readOnly", "get_readOnly", "set_readOnly" },
            .{ "required", "get_required", "set_required" },
            .{ "size", "get_size", "set_size" },
            .{ "src", "get_src", "set_src" },
            .{ "step", "get_step", "set_step" },
            .{ "type", "get_type", "set_type" },
            .{ "defaultValue", "get_defaultValue", "set_defaultValue" },
            .{ "value", "get_value", "set_value" },
            .{ "valueAsDate", "get_valueAsDate", "set_valueAsDate" },
            .{ "valueAsNumber", "get_valueAsNumber", "set_valueAsNumber" },
            .{ "width", "get_width", "set_width" },
            .{ "willValidate", "get_willValidate", null },
            .{ "validity", "get_validity", null },
            .{ "validationMessage", "get_validationMessage", null },
            .{ "labels", "get_labels", null },
            .{ "selectionStart", "get_selectionStart", "set_selectionStart" },
            .{ "selectionEnd", "get_selectionEnd", "set_selectionEnd" },
            .{ "selectionDirection", "get_selectionDirection", "set_selectionDirection" },
            .{ "capture", "get_capture", "set_capture" },
            .{ "webkitdirectory", "get_webkitdirectory", "set_webkitdirectory" },
            .{ "webkitEntries", "get_webkitEntries", null },
            .{ "align", "get_align", "set_align" },
            .{ "useMap", "get_useMap", "set_useMap" },
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
            accept: runtime.DOMString = undefined,
            alpha: bool = undefined,
            alt: runtime.DOMString = undefined,
            autocomplete: runtime.DOMString = undefined,
            defaultChecked: bool = undefined,
            checked: bool = undefined,
            colorSpace: runtime.DOMString = undefined,
            dirName: runtime.DOMString = undefined,
            disabled: bool = undefined,
            form: ?*runtime.Instance = null,
            files: ?*runtime.Instance = null,
            formAction: runtime.USVString = undefined,
            formEnctype: runtime.DOMString = undefined,
            formMethod: runtime.DOMString = undefined,
            formNoValidate: bool = undefined,
            formTarget: runtime.DOMString = undefined,
            height: u32 = undefined,
            indeterminate: bool = undefined,
            list: ?*runtime.Instance = null,
            max: runtime.DOMString = undefined,
            maxLength: i32 = undefined,
            min: runtime.DOMString = undefined,
            minLength: i32 = undefined,
            multiple: bool = undefined,
            name: runtime.DOMString = undefined,
            pattern: runtime.DOMString = undefined,
            placeholder: runtime.DOMString = undefined,
            readOnly: bool = undefined,
            required: bool = undefined,
            size: u32 = undefined,
            src: runtime.USVString = undefined,
            step: runtime.DOMString = undefined,
            @"type": runtime.DOMString = undefined,
            defaultValue: runtime.DOMString = undefined,
            value: runtime.DOMString = undefined,
            valueAsDate: ?*const anyopaque = null,
            valueAsNumber: f64 = undefined,
            width: u32 = undefined,
            willValidate: bool = undefined,
            validity: *runtime.Instance = undefined,
            validationMessage: runtime.DOMString = undefined,
            labels: ?*runtime.Instance = null,
            selectionStart: ?u32 = null,
            selectionEnd: ?u32 = null,
            selectionDirection: ?runtime.DOMString = null,
            capture: runtime.DOMString = undefined,
            webkitdirectory: bool = undefined,
            webkitEntries: runtime.FrozenArray(FileSystemEntry) = undefined,
            @"align": runtime.DOMString = undefined,
            useMap: runtime.DOMString = undefined,
            popoverTargetElement: ?*runtime.Instance = null,
            popoverTargetAction: runtime.DOMString = undefined,
            _internal: ?*HTMLInputElementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_accept = &get_accept,
        .get_align = &get_align,
        .get_alpha = &get_alpha,
        .get_alt = &get_alt,
        .get_autocomplete = &get_autocomplete,
        .get_capture = &get_capture,
        .get_checked = &get_checked,
        .get_colorSpace = &get_colorSpace,
        .get_defaultChecked = &get_defaultChecked,
        .get_defaultValue = &get_defaultValue,
        .get_dirName = &get_dirName,
        .get_disabled = &get_disabled,
        .get_files = &get_files,
        .get_form = &get_form,
        .get_formAction = &get_formAction,
        .get_formEnctype = &get_formEnctype,
        .get_formMethod = &get_formMethod,
        .get_formNoValidate = &get_formNoValidate,
        .get_formTarget = &get_formTarget,
        .get_height = &get_height,
        .get_indeterminate = &get_indeterminate,
        .get_labels = &get_labels,
        .get_list = &get_list,
        .get_max = &get_max,
        .get_maxLength = &get_maxLength,
        .get_min = &get_min,
        .get_minLength = &get_minLength,
        .get_multiple = &get_multiple,
        .get_name = &get_name,
        .get_pattern = &get_pattern,
        .get_placeholder = &get_placeholder,
        .get_popoverTargetAction = &get_popoverTargetAction,
        .get_popoverTargetElement = &get_popoverTargetElement,
        .get_readOnly = &get_readOnly,
        .get_required = &get_required,
        .get_selectionDirection = &get_selectionDirection,
        .get_selectionEnd = &get_selectionEnd,
        .get_selectionStart = &get_selectionStart,
        .get_size = &get_size,
        .get_src = &get_src,
        .get_step = &get_step,
        .get_type = &get_type,
        .get_useMap = &get_useMap,
        .get_validationMessage = &get_validationMessage,
        .get_validity = &get_validity,
        .get_value = &get_value,
        .get_valueAsDate = &get_valueAsDate,
        .get_valueAsNumber = &get_valueAsNumber,
        .get_webkitEntries = &get_webkitEntries,
        .get_webkitdirectory = &get_webkitdirectory,
        .get_width = &get_width,
        .get_willValidate = &get_willValidate,

        .set_accept = &set_accept,
        .set_align = &set_align,
        .set_alpha = &set_alpha,
        .set_alt = &set_alt,
        .set_autocomplete = &set_autocomplete,
        .set_capture = &set_capture,
        .set_checked = &set_checked,
        .set_colorSpace = &set_colorSpace,
        .set_defaultChecked = &set_defaultChecked,
        .set_defaultValue = &set_defaultValue,
        .set_dirName = &set_dirName,
        .set_disabled = &set_disabled,
        .set_files = &set_files,
        .set_formAction = &set_formAction,
        .set_formEnctype = &set_formEnctype,
        .set_formMethod = &set_formMethod,
        .set_formNoValidate = &set_formNoValidate,
        .set_formTarget = &set_formTarget,
        .set_height = &set_height,
        .set_indeterminate = &set_indeterminate,
        .set_max = &set_max,
        .set_maxLength = &set_maxLength,
        .set_min = &set_min,
        .set_minLength = &set_minLength,
        .set_multiple = &set_multiple,
        .set_name = &set_name,
        .set_pattern = &set_pattern,
        .set_placeholder = &set_placeholder,
        .set_popoverTargetAction = &set_popoverTargetAction,
        .set_popoverTargetElement = &set_popoverTargetElement,
        .set_readOnly = &set_readOnly,
        .set_required = &set_required,
        .set_selectionDirection = &set_selectionDirection,
        .set_selectionEnd = &set_selectionEnd,
        .set_selectionStart = &set_selectionStart,
        .set_size = &set_size,
        .set_src = &set_src,
        .set_step = &set_step,
        .set_type = &set_type,
        .set_useMap = &set_useMap,
        .set_value = &set_value,
        .set_valueAsDate = &set_valueAsDate,
        .set_valueAsNumber = &set_valueAsNumber,
        .set_webkitdirectory = &set_webkitdirectory,
        .set_width = &set_width,

        .call_checkValidity = &call_checkValidity,
        .call_reportValidity = &call_reportValidity,
        .call_select = &call_select,
        .call_setCustomValidity = &call_setCustomValidity,
        .call_setRangeText = &call_setRangeText,
        .call_setSelectionRange = &call_setSelectionRange,
        .call_showPicker = &call_showPicker,
        .call_stepDown = &call_stepDown,
        .call_stepUp = &call_stepUp,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLInputElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLInputElementImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLInputElementImpl.call_constructor(allocator, ctx);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_accept(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLInputElementImpl.get_accept(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_accept(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_accept(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_alpha(instance: *runtime.Instance) anyerror!bool {
        return try HTMLInputElementImpl.get_alpha(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_alpha(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_alpha(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_alt(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLInputElementImpl.get_alt(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_alt(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_alt(instance, value);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn get_autocomplete(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLInputElementImpl.get_autocomplete(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn set_autocomplete(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_autocomplete(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="checked"]
    pub fn get_defaultChecked(instance: *runtime.Instance) anyerror!bool {
        return try HTMLInputElementImpl.get_defaultChecked(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="checked"]
    pub fn set_defaultChecked(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_defaultChecked(instance, value);
    }

    pub fn get_checked(instance: *runtime.Instance) anyerror!bool {
        return try HTMLInputElementImpl.get_checked(instance);
    }

    pub fn set_checked(instance: *runtime.Instance, value: bool) anyerror!void {
        try HTMLInputElementImpl.set_checked(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_colorSpace(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLInputElementImpl.get_colorSpace(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_colorSpace(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_colorSpace(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_dirName(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLInputElementImpl.get_dirName(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_dirName(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_dirName(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_disabled(instance: *runtime.Instance) anyerror!bool {
        return try HTMLInputElementImpl.get_disabled(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_disabled(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_disabled(instance, value);
    }

    pub fn get_form(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try HTMLInputElementImpl.get_form(instance);
    }

    pub fn get_files(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try HTMLInputElementImpl.get_files(instance);
    }

    pub fn set_files(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try HTMLInputElementImpl.set_files(instance, value);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn get_formAction(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLInputElementImpl.get_formAction(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn set_formAction(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_formAction(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_formEnctype(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLInputElementImpl.get_formEnctype(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_formEnctype(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_formEnctype(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_formMethod(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLInputElementImpl.get_formMethod(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_formMethod(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_formMethod(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_formNoValidate(instance: *runtime.Instance) anyerror!bool {
        return try HTMLInputElementImpl.get_formNoValidate(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_formNoValidate(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_formNoValidate(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_formTarget(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLInputElementImpl.get_formTarget(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_formTarget(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_formTarget(instance, value);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn get_height(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLInputElementImpl.get_height(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn set_height(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_height(instance, value);
    }

    pub fn get_indeterminate(instance: *runtime.Instance) anyerror!bool {
        return try HTMLInputElementImpl.get_indeterminate(instance);
    }

    pub fn set_indeterminate(instance: *runtime.Instance, value: bool) anyerror!void {
        try HTMLInputElementImpl.set_indeterminate(instance, value);
    }

    pub fn get_list(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try HTMLInputElementImpl.get_list(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_max(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLInputElementImpl.get_max(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_max(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_max(instance, value);
    }

    /// Extended attributes: [CEReactions], [ReflectNonNegative]
    pub fn get_maxLength(instance: *runtime.Instance) anyerror!i32 {
        return try HTMLInputElementImpl.get_maxLength(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectNonNegative]
    pub fn set_maxLength(instance: *runtime.Instance, value: i32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_maxLength(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_min(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLInputElementImpl.get_min(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_min(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_min(instance, value);
    }

    /// Extended attributes: [CEReactions], [ReflectNonNegative]
    pub fn get_minLength(instance: *runtime.Instance) anyerror!i32 {
        return try HTMLInputElementImpl.get_minLength(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectNonNegative]
    pub fn set_minLength(instance: *runtime.Instance, value: i32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_minLength(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_multiple(instance: *runtime.Instance) anyerror!bool {
        return try HTMLInputElementImpl.get_multiple(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_multiple(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_multiple(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLInputElementImpl.get_name(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_name(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_name(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_pattern(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLInputElementImpl.get_pattern(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_pattern(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_pattern(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_placeholder(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLInputElementImpl.get_placeholder(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_placeholder(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_placeholder(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_readOnly(instance: *runtime.Instance) anyerror!bool {
        return try HTMLInputElementImpl.get_readOnly(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_readOnly(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_readOnly(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_required(instance: *runtime.Instance) anyerror!bool {
        return try HTMLInputElementImpl.get_required(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_required(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_required(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLInputElementImpl.get_size(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_size(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_size(instance, value);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn get_src(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLInputElementImpl.get_src(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn set_src(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_src(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_step(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLInputElementImpl.get_step(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_step(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_step(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLInputElementImpl.get_type(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_type(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_type(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="value"]
    pub fn get_defaultValue(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLInputElementImpl.get_defaultValue(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="value"]
    pub fn set_defaultValue(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_defaultValue(instance, value);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn get_value(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLInputElementImpl.get_value(instance);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn set_value(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_value(instance, value);
    }

    pub fn get_valueAsDate(instance: *runtime.Instance) anyerror!?*const anyopaque {
        return try HTMLInputElementImpl.get_valueAsDate(instance);
    }

    pub fn set_valueAsDate(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
        try HTMLInputElementImpl.set_valueAsDate(instance, value);
    }

    pub fn get_valueAsNumber(instance: *runtime.Instance) anyerror!f64 {
        return try HTMLInputElementImpl.get_valueAsNumber(instance);
    }

    pub fn set_valueAsNumber(instance: *runtime.Instance, value: f64) anyerror!void {
        try HTMLInputElementImpl.set_valueAsNumber(instance, value);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn get_width(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLInputElementImpl.get_width(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn set_width(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_width(instance, value);
    }

    pub fn get_willValidate(instance: *runtime.Instance) anyerror!bool {
        return try HTMLInputElementImpl.get_willValidate(instance);
    }

    pub fn get_validity(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLInputElementImpl.get_validity(instance);
    }

    pub fn get_validationMessage(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLInputElementImpl.get_validationMessage(instance);
    }

    pub fn get_labels(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try HTMLInputElementImpl.get_labels(instance);
    }

    pub fn get_selectionStart(instance: *runtime.Instance) anyerror!?u32 {
        return try HTMLInputElementImpl.get_selectionStart(instance);
    }

    pub fn set_selectionStart(instance: *runtime.Instance, value: u32) anyerror!void {
        try HTMLInputElementImpl.set_selectionStart(instance, value);
    }

    pub fn get_selectionEnd(instance: *runtime.Instance) anyerror!?u32 {
        return try HTMLInputElementImpl.get_selectionEnd(instance);
    }

    pub fn set_selectionEnd(instance: *runtime.Instance, value: u32) anyerror!void {
        try HTMLInputElementImpl.set_selectionEnd(instance, value);
    }

    pub fn get_selectionDirection(instance: *runtime.Instance) anyerror!?DOMString {
        return try HTMLInputElementImpl.get_selectionDirection(instance);
    }

    pub fn set_selectionDirection(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try HTMLInputElementImpl.set_selectionDirection(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_capture(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLInputElementImpl.get_capture(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_capture(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_capture(instance, value);
    }

    pub fn get_webkitdirectory(instance: *runtime.Instance) anyerror!bool {
        return try HTMLInputElementImpl.get_webkitdirectory(instance);
    }

    pub fn set_webkitdirectory(instance: *runtime.Instance, value: bool) anyerror!void {
        try HTMLInputElementImpl.set_webkitdirectory(instance, value);
    }

    pub fn get_webkitEntries(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try HTMLInputElementImpl.get_webkitEntries(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_align(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLInputElementImpl.get_align(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_align(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_align(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_useMap(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLInputElementImpl.get_useMap(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_useMap(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_useMap(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_popoverTargetElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try HTMLInputElementImpl.get_popoverTargetElement(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_popoverTargetElement(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_popoverTargetElement(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_popoverTargetAction(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLInputElementImpl.get_popoverTargetAction(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_popoverTargetAction(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLInputElementImpl.set_popoverTargetAction(instance, value);
    }

    pub fn call_showPicker(instance: *runtime.Instance) anyerror!void {
        return try HTMLInputElementImpl.call_showPicker(instance);
    }

    pub fn call_setCustomValidity(instance: *runtime.Instance, @"error": DOMString) anyerror!void {
        
        return try HTMLInputElementImpl.call_setCustomValidity(instance, @"error");
    }

    pub fn call_setRangeText(instance: *runtime.Instance, replacement: DOMString) anyerror!void {
        
        return try HTMLInputElementImpl.call_setRangeText(instance, replacement);
    }

    pub fn call_select(instance: *runtime.Instance) anyerror!void {
        return try HTMLInputElementImpl.call_select(instance);
    }

    pub fn call_stepUp(instance: *runtime.Instance, n: i32) anyerror!void {
        
        return try HTMLInputElementImpl.call_stepUp(instance, n);
    }

    pub fn call_checkValidity(instance: *runtime.Instance) anyerror!bool {
        return try HTMLInputElementImpl.call_checkValidity(instance);
    }

    pub fn call_setSelectionRange(instance: *runtime.Instance, start: u32, end: u32, direction: DOMString) anyerror!void {
        
        return try HTMLInputElementImpl.call_setSelectionRange(instance, start, end, direction);
    }

    pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
        return try HTMLInputElementImpl.call_reportValidity(instance);
    }

    pub fn call_stepDown(instance: *runtime.Instance, n: i32) anyerror!void {
        
        return try HTMLInputElementImpl.call_stepDown(instance, n);
    }

};
