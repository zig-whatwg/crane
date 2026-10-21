//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLFormElementImpl = @import("impls").HTMLFormElement;
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
const DOMRectList = @import("interfaces").DOMRectList;
const KeyframeAnimationOptions = @import("dictionaries").KeyframeAnimationOptions;
const Document = @import("interfaces").Document;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const RadioNodeList = @import("interfaces").RadioNodeList;
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const ScrollToOptions = @import("dictionaries").ScrollToOptions;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const DOMQuad = @import("interfaces").DOMQuad;
const HTMLSlotElement = @import("interfaces").HTMLSlotElement;
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
const AriaNotificationOptions = @import("dictionaries").AriaNotificationOptions;
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
            .{ "relList", "get_relList", "set_relList" },
            .{ "elements", "get_elements", null },
            .{ "length", "get_length", null },
        };

        /// [PutForwards] attributes: setting the attribute forwards to a property on the value
        /// Format: { "attrName", "forwardedProperty" }
        pub const put_forwards_attributes = .{
            .{ "relList", "value" },
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
            "remove",
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
            .{ "relList", "get_relList", "set_relList" },
            .{ "elements", "get_elements", null },
            .{ "length", "get_length", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;

        /// WebIDL 2.5.6 special operations, own or inherited (the derived-most):
        /// the function that runs each. The binding installs indexed and named
        /// property handlers from this table (webidl.SpecialOperations).
        pub const special_operations: webidl.SpecialOperations = .{
            .indexed_getter = .{ .function = "call_getter", .implemented = @hasDecl(HTMLFormElementImpl, "call_getter") },
            .named_getter = .{ .function = "call_getter__1", .implemented = @hasDecl(HTMLFormElementImpl, "call_getter__1") },
            .supported_property_name = .{ .function = "isSupportedPropertyName", .implemented = @hasDecl(HTMLFormElementImpl, "isSupportedPropertyName") },
            .legacy_override_built_ins = true,
            .legacy_unenumerable_named_properties = true,
            .named_properties_in_own_keys = false,
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
        .set_relList = &set_relList,
        .set_target = &set_target,

        .call_checkValidity = &call_checkValidity,
        .call_reportValidity = &call_reportValidity,
        .call_requestSubmit = &call_requestSubmit,
        .call_reset = &call_reset,
        .call_submit = &call_submit,

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
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("HTMLFormElement has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(HTMLFormElementImpl, "init") and @hasDecl(HTMLFormElementImpl, "initOwn")) @compileError("HTMLFormElementImpl defines both init and initOwn");
        if (comptime @hasDecl(HTMLFormElementImpl, "init")) return HTMLFormElementImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(HTMLFormElementImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try HTMLFormElementImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(HTMLFormElementImpl, "init")) return false;
        if (comptime @hasDecl(HTMLFormElementImpl, "construction_args")) {
            inline for (HTMLFormElementImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(HTMLFormElementImpl, "deinit") and @hasDecl(HTMLFormElementImpl, "deinitOwn")) @compileError("HTMLFormElementImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(HTMLFormElementImpl, "deinit")) return HTMLFormElementImpl.deinit(instance);
        if (comptime @hasDecl(HTMLFormElementImpl, "deinitOwn")) HTMLFormElementImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "HTMLFormElement")) {
            if (comptime @hasDecl(impls.HTMLFormElement, "installHooks")) impls.HTMLFormElement.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 0;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLFormElementImpl.call_constructor(ctx);
    }

    const reflection = @import("dom").reflection;

    /// Extended attributes: [CEReactions], [Reflect="accept-charset"]
    pub fn get_acceptCharset(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(HTMLFormElementImpl, "get_acceptCharset")) return try HTMLFormElementImpl.get_acceptCharset(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "accept-charset" });
    }

    /// Extended attributes: [CEReactions], [Reflect="accept-charset"]
    pub fn set_acceptCharset(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLFormElementImpl, "set_acceptCharset")) return try HTMLFormElementImpl.set_acceptCharset(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "accept-charset" }, value);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn get_action(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try HTMLFormElementImpl.get_action(instance);
    }

    /// Extended attributes: [CEReactions], [ReflectSetter]
    pub fn set_action(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLFormElementImpl, "set_action")) return try HTMLFormElementImpl.set_action(instance, value);
        try reflection.set(runtime.USVString, instance, .{ .name = "action" }, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_autocomplete(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try HTMLFormElementImpl.get_autocomplete(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_autocomplete(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try HTMLFormElementImpl.set_autocomplete(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_enctype(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try HTMLFormElementImpl.get_enctype(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_enctype(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try HTMLFormElementImpl.set_enctype(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_encoding(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try HTMLFormElementImpl.get_encoding(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_encoding(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try HTMLFormElementImpl.set_encoding(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_method(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try HTMLFormElementImpl.get_method(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_method(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try HTMLFormElementImpl.set_method(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(HTMLFormElementImpl, "get_name")) return try HTMLFormElementImpl.get_name(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "name" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_name(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLFormElementImpl, "set_name")) return try HTMLFormElementImpl.set_name(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "name" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_noValidate(instance: *runtime.Instance) anyerror!bool {
        if (comptime @hasDecl(HTMLFormElementImpl, "get_noValidate")) return try HTMLFormElementImpl.get_noValidate(instance);
        return try reflection.get(bool, instance, .{ .name = "novalidate" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_noValidate(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLFormElementImpl, "set_noValidate")) return try HTMLFormElementImpl.set_noValidate(instance, value);
        try reflection.set(bool, instance, .{ .name = "novalidate" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_target(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(HTMLFormElementImpl, "get_target")) return try HTMLFormElementImpl.get_target(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "target" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_target(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLFormElementImpl, "set_target")) return try HTMLFormElementImpl.set_target(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "target" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_rel(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(HTMLFormElementImpl, "get_rel")) return try HTMLFormElementImpl.get_rel(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "rel" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_rel(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLFormElementImpl, "set_rel")) return try HTMLFormElementImpl.set_rel(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "rel" }, value);
    }

    /// Extended attributes: [SameObject], [PutForwards=value], [Reflect="rel"]
    pub fn get_relList(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_relList) |cached| {
            return cached;
        }
        const value = if (comptime @hasDecl(HTMLFormElementImpl, "get_relList")) try HTMLFormElementImpl.get_relList(instance) else try reflection.get(*runtime.Instance, instance, .{ .name = "rel" });
        state.own.cached_relList = value;
        @import("dom").same_object_cache.made(instance, value, "relList");
        return value;
    }

    /// Extended attributes: [SameObject], [PutForwards=value], [Reflect="rel"]
    pub fn set_relList(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [PutForwards] - Get target object and set the forwarded property
        // Per WebIDL spec: setting 'relList' forwards to 'value' on the attribute's value
        const target = try get_relList(instance);

        // Use JavaScript [[Set]] semantics to set the forwarded property
        // This respects prototype chain and user-defined setters
        try runtime.setPropertyOnInstance(target, "value", value);
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
        @import("dom").same_object_cache.made(instance, value, "elements");
        return value;
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLFormElementImpl.get_length(instance);
    }

    pub fn call_getter(instance: *runtime.Instance, index: u32) anyerror!*runtime.Instance {
        if (comptime @hasDecl(HTMLFormElementImpl, "call_getter")) {
            return try HTMLFormElementImpl.call_getter(instance, index);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_getter__1(instance: *runtime.Instance, name: runtime.DOMString) anyerror!runtime.JSValue {
        if (comptime @hasDecl(HTMLFormElementImpl, "call_getter__1")) {
            return try HTMLFormElementImpl.call_getter__1(instance, name);
        } else {
            return error.NotImplemented;
        }
    }

    /// Extended attributes: [CEReactions]
    pub fn call_reset(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try HTMLFormElementImpl.call_reset(instance);
    }

    pub fn call_submit(instance: *runtime.Instance) anyerror!void {
        return try HTMLFormElementImpl.call_submit(instance);
    }

    pub fn call_reportValidity(instance: *runtime.Instance) anyerror!bool {
        return try HTMLFormElementImpl.call_reportValidity(instance);
    }

    pub fn call_requestSubmit(instance: *runtime.Instance, submitter: webidl.Opt(?*runtime.Instance)) anyerror!void {
        return try HTMLFormElementImpl.call_requestSubmit(instance, submitter);
    }

    pub fn call_checkValidity(instance: *runtime.Instance) anyerror!bool {
        return try HTMLFormElementImpl.call_checkValidity(instance);
    }

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_requestSubmit", 0, "HTMLElement" },
    };

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "set_acceptCharset",
        "set_action",
        "set_autocomplete",
        "set_enctype",
        "set_encoding",
        "set_method",
        "set_name",
        "set_noValidate",
        "set_target",
        "set_rel",
        "call_reset",
    };

    /// Get supported property names for named property enumeration (Reflect.ownKeys, etc.)
    /// Per WebIDL spec §3.9.3, returns names in list order for proper enumeration
    pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
        return HTMLFormElementImpl.getSupportedPropertyNames(instance, allocator);
    }

    /// Whether `name` is one of the supported property names (WebIDL 3.9.7
    /// step 1, asked for one name), answered without building the list. Gated:
    /// error.NotImplemented until the impl declares it, and
    /// Meta.special_operations.supported_property_name says whether it does -
    /// without it the binding searches getSupportedPropertyNames' list.
    pub fn isSupportedPropertyName(instance: *runtime.Instance, name: runtime.DOMString) anyerror!bool {
        if (comptime @hasDecl(HTMLFormElementImpl, "isSupportedPropertyName")) {
            return try HTMLFormElementImpl.isSupportedPropertyName(instance, name);
        } else {
            return error.NotImplemented;
        }
    }
};
