//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLSelectElementImpl = @import("impls").HTMLSelectElement;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const HTMLElement = @import("interfaces").HTMLElement;
const DOMStringMap = @import("interfaces").DOMStringMap;
const CSSOMString = @import("typedefs").CSSOMString;
const HTMLCollection = @import("interfaces").HTMLCollection;
const TogglePopoverOptions = @import("dictionaries").TogglePopoverOptions;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const HTMLOptionElement = @import("interfaces").HTMLOptionElement;
const GeometryNode = @import("typedefs").GeometryNode;
const NamedNodeMap = @import("interfaces").NamedNodeMap;
const USVString = @import("typedefs").USVString;
const Element = @import("interfaces").Element;
const CheckVisibilityOptions = @import("dictionaries").CheckVisibilityOptions;
const ScrollIntoViewOptions = @import("dictionaries").ScrollIntoViewOptions;
const BoxQuadOptions = @import("dictionaries").BoxQuadOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const FocusableAreasOption = @import("dictionaries").FocusableAreasOption;
const TrustedHTMLOrDOMString = @import("typedefs").TrustedHTMLOrDOMString;
const EventListener = @import("interfaces").EventListener;
const CSSStyleProperties = @import("interfaces").CSSStyleProperties;
const CSSPseudoElement = @import("interfaces").CSSPseudoElement;
const ShowPopoverOptions = @import("dictionaries").ShowPopoverOptions;
const HTMLOptionElementOrHTMLOptGroupElement = @import("typedefs").HTMLOptionElementOrHTMLOptGroupElement;
const SetHTMLOptions = @import("dictionaries").SetHTMLOptions;
const ViewTransitionUpdateCallback = @import("callbacks").ViewTransitionUpdateCallback;
const Node = @import("interfaces").Node;
const CustomElementRegistry = @import("interfaces").CustomElementRegistry;
const SetHTMLUnsafeOptions = @import("dictionaries").SetHTMLUnsafeOptions;
const Range = @import("interfaces").Range;
const Event = @import("interfaces").Event;
const Animation = @import("interfaces").Animation;
const FocusOptions = @import("dictionaries").FocusOptions;
const TrustedTypeOrDOMString = @import("typedefs").TrustedTypeOrDOMString;
const ValidityState = @import("interfaces").ValidityState;
const DOMString = @import("typedefs").DOMString;
const KeyframeAnimationOptions = @import("dictionaries").KeyframeAnimationOptions;
const Document = @import("interfaces").Document;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const ScrollToOptions = @import("dictionaries").ScrollToOptions;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const DOMQuad = @import("interfaces").DOMQuad;
const HTMLSlotElement = @import("interfaces").HTMLSlotElement;
const DOMRectList = @import("interfaces").DOMRectList;
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
const HTMLOptionsCollection = @import("interfaces").HTMLOptionsCollection;
const NodeList = @import("interfaces").NodeList;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const FullscreenOptions = @import("dictionaries").FullscreenOptions;
const AriaNotificationOptions = @import("dictionaries").AriaNotificationOptions;
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
            "pseudo",
            "computedStyleMap",
            "startViewTransition",
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
            "requestFullscreen",
            "setHTML",
            "setHTMLUnsafe",
            "getHTML",
            "insertAdjacentHTML",
            "setPointerCapture",
            "releasePointerCapture",
            "hasPointerCapture",
            "requestPointerLock",
            "getRegionFlowRanges",
            "getBoxQuads",
            "convertQuadFromNode",
            "convertRectFromNode",
            "convertPointFromNode",
            "prepend",
            "append",
            "replaceChildren",
            "moveBefore",
            "querySelector",
            "querySelectorAll",
            "before",
            "after",
            "replaceWith",
            "ariaNotify",
            "animate",
            "getAnimations",
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
        pub const lazy_properties = .{};

        pub const has_constructor = true;

        /// WebIDL 2.5.6 special operations, own or inherited (the derived-most):
        /// the function that runs each. The binding installs indexed and named
        /// property handlers from this table (webidl.SpecialOperations).
        pub const special_operations: webidl.SpecialOperations = .{
            .indexed_getter = .{ .function = "call_item" },
            .indexed_setter = .{ .function = "call_setter", .implemented = @hasDecl(HTMLSelectElementImpl, "call_setter") },
        };
    };

    /// HTML 3.2.3 [HTMLConstructor]: the constructor's steps are HTML's "HTML
    /// element constructors" - the binding runs them with
    /// engine.HostHooks.htmlConstructor.
    pub const html_constructor = true;

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
            type: runtime.DOMString = undefined,
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
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Make a new instance: the construction chain, this interface's State
    /// and vtable.
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return initChain(allocator, State, &vtable, ctx, .{});
    }

    /// Make a new instance with construction arguments: facts given at
    /// construction, as a C++ constructor's parameters. Each field of `args`
    /// must be taken by an impl on the chain (its `construction_args`).
    pub fn initWith(allocator: std.mem.Allocator, ctx: runtime.Context, args: anytype) !*runtime.Instance {
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("HTMLSelectElement has no construction argument '" ++ field_name ++ "'");
        }
        return initChain(allocator, State, &vtable, ctx, args);
    }

    /// The construction chain for a descendant's State and vtable, for an
    /// impl that still chains by hand.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return initChain(allocator, StateType, vtable_ptr, ctx, .{});
    }

    /// The construction chain: the parent interface's, then the impl's own
    /// steps (`initOwn`), whose failure unwinds the parent's part and frees
    /// the slot. An impl that still defines `init` chains by hand.
    pub inline fn initChain(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
        args: anytype,
    ) !*runtime.Instance {
        if (comptime @hasDecl(HTMLSelectElementImpl, "init") and @hasDecl(HTMLSelectElementImpl, "initOwn")) @compileError("HTMLSelectElementImpl defines both init and initOwn");
        if (comptime @hasDecl(HTMLSelectElementImpl, "init")) return HTMLSelectElementImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(HTMLSelectElementImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try HTMLSelectElementImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(HTMLSelectElementImpl, "init")) return false;
        if (comptime @hasDecl(HTMLSelectElementImpl, "construction_args")) {
            inline for (HTMLSelectElementImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return Meta.ParentInterface.takesConstructionArg(name);
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(HTMLSelectElementImpl, "deinit") and @hasDecl(HTMLSelectElementImpl, "deinitOwn")) @compileError("HTMLSelectElementImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(HTMLSelectElementImpl, "deinit")) return HTMLSelectElementImpl.deinit(instance);
        if (comptime @hasDecl(HTMLSelectElementImpl, "deinitOwn")) HTMLSelectElementImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "HTMLSelectElement")) {
            if (comptime @hasDecl(impls.HTMLSelectElement, "installHooks")) impls.HTMLSelectElement.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 0;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLSelectElementImpl.call_constructor(ctx);
    }

    const reflection = @import("dom").reflection;

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn get_autocomplete(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try HTMLSelectElementImpl.get_autocomplete(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn set_autocomplete(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLSelectElementImpl, "set_autocomplete")) return try HTMLSelectElementImpl.set_autocomplete(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "autocomplete" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_disabled(instance: *runtime.Instance) anyerror!bool {
        if (comptime @hasDecl(HTMLSelectElementImpl, "get_disabled")) return try HTMLSelectElementImpl.get_disabled(instance);
        return try reflection.get(bool, instance, .{ .name = "disabled" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_disabled(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLSelectElementImpl, "set_disabled")) return try HTMLSelectElementImpl.set_disabled(instance, value);
        try reflection.set(bool, instance, .{ .name = "disabled" }, value);
    }

    pub fn get_form(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try HTMLSelectElementImpl.get_form(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_multiple(instance: *runtime.Instance) anyerror!bool {
        if (comptime @hasDecl(HTMLSelectElementImpl, "get_multiple")) return try HTMLSelectElementImpl.get_multiple(instance);
        return try reflection.get(bool, instance, .{ .name = "multiple" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_multiple(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLSelectElementImpl, "set_multiple")) return try HTMLSelectElementImpl.set_multiple(instance, value);
        try reflection.set(bool, instance, .{ .name = "multiple" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(HTMLSelectElementImpl, "get_name")) return try HTMLSelectElementImpl.get_name(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "name" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_name(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLSelectElementImpl, "set_name")) return try HTMLSelectElementImpl.set_name(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "name" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_required(instance: *runtime.Instance) anyerror!bool {
        if (comptime @hasDecl(HTMLSelectElementImpl, "get_required")) return try HTMLSelectElementImpl.get_required(instance);
        return try reflection.get(bool, instance, .{ .name = "required" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_required(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLSelectElementImpl, "set_required")) return try HTMLSelectElementImpl.set_required(instance, value);
        try reflection.set(bool, instance, .{ .name = "required" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect], [ReflectDefault=0]
    pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
        if (comptime @hasDecl(HTMLSelectElementImpl, "get_size")) return try HTMLSelectElementImpl.get_size(instance);
        return try reflection.get(u32, instance, .{ .name = "size", .default = 0 });
    }

    /// Extended attributes: [CEReactions], [Reflect], [ReflectDefault=0]
    pub fn set_size(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLSelectElementImpl, "set_size")) return try HTMLSelectElementImpl.set_size(instance, value);
        try reflection.set(u32, instance, .{ .name = "size", .default = 0 }, value);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
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
        @import("dom").same_object_cache.made(instance, value, "options");
        return value;
    }

    /// Extended attributes: [CEReactions]
    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLSelectElementImpl.get_length(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_length(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

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
        @import("dom").same_object_cache.made(instance, value, "selectedOptions");
        return value;
    }

    pub fn get_selectedIndex(instance: *runtime.Instance) anyerror!i32 {
        return try HTMLSelectElementImpl.get_selectedIndex(instance);
    }

    pub fn set_selectedIndex(instance: *runtime.Instance, value: i32) anyerror!void {
        try HTMLSelectElementImpl.set_selectedIndex(instance, value);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try HTMLSelectElementImpl.get_value(instance);
    }

    pub fn set_value(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        try HTMLSelectElementImpl.set_value(instance, value);
    }

    pub fn get_willValidate(instance: *runtime.Instance) anyerror!bool {
        return try HTMLSelectElementImpl.get_willValidate(instance);
    }

    pub fn get_validity(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLSelectElementImpl.get_validity(instance);
    }

    pub fn get_validationMessage(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try HTMLSelectElementImpl.get_validationMessage(instance);
    }

    pub fn get_labels(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try HTMLSelectElementImpl.get_labels(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setter(instance: *runtime.Instance, index: u32, option: ?*runtime.Instance) anyerror!void {
        if (comptime @hasDecl(HTMLSelectElementImpl, "call_setter")) {
            // [CEReactions] - Trigger Custom Element lifecycle callbacks
            const ce_scope = runtime.CEReactions.begin(instance);
            defer runtime.CEReactions.end(ce_scope);

            return try HTMLSelectElementImpl.call_setter(instance, index, option);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
        return try HTMLSelectElementImpl.call_item(instance, index);
    }

    pub fn call_namedItem(instance: *runtime.Instance, name: runtime.DOMString) anyerror!?*runtime.Instance {
        return try HTMLSelectElementImpl.call_namedItem(instance, name);
    }

    pub fn call_setCustomValidity(instance: *runtime.Instance, @"error": runtime.DOMString) anyerror!void {
        return try HTMLSelectElementImpl.call_setCustomValidity(instance, @"error");
    }

    pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
        return try HTMLSelectElementImpl.call_reportValidity(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_remove(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try HTMLSelectElementImpl.call_remove(instance);
    }

    pub fn call_checkValidity(instance: *runtime.Instance) anyerror!bool {
        return try HTMLSelectElementImpl.call_checkValidity(instance);
    }

    pub fn call_showPicker(instance: *runtime.Instance) anyerror!void {
        return try HTMLSelectElementImpl.call_showPicker(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_add(instance: *runtime.Instance, element: HTMLOptionElementOrHTMLOptGroupElement, before: webidl.Opt(?runtime.JSValue)) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try HTMLSelectElementImpl.call_add(instance, element, before);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_remove__1(instance: *runtime.Instance, index: i32) anyerror!void {
        if (comptime @hasDecl(HTMLSelectElementImpl, "call_remove__1")) {
            // [CEReactions] - Trigger Custom Element lifecycle callbacks
            const ce_scope = runtime.CEReactions.begin(instance);
            defer runtime.CEReactions.end(ce_scope);

            return try HTMLSelectElementImpl.call_remove__1(instance, index);
        } else {
            return error.NotImplemented;
        }
    }

    /// WebIDL overload sets: every overload of each overloaded operation,
    /// in IDL order, for the overload resolution algorithm
    /// (webidl.overload_resolution). The binding is installed for the first
    /// overload and forwards to the one the arguments select.
    pub const overloads = .{
        .{ "remove", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_remove", .args = &.{} },
            .{ .function = "call_remove__1", .implemented = @hasDecl(HTMLSelectElementImpl, "call_remove__1"), .args = &.{.{ .kinds = &.{.numeric} }} },
        } },
    };

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_setter", 1, "HTMLOptionElement" },
    };

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "set_autocomplete",
        "set_disabled",
        "set_multiple",
        "set_name",
        "set_required",
        "set_size",
        "set_length",
        "call_setter",
        "call_remove",
        "call_add",
        "call_remove__1",
    };
};
