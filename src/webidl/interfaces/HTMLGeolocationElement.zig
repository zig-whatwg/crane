//! Generated from: geolocation-element.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLGeolocationElementImpl = @import("impls").HTMLGeolocationElement;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const HTMLElement = @import("interfaces").HTMLElement;
const ActivationBlockersMixin = @import("mixins").ActivationBlockersMixin;
const PowerfulFeatureObserver = @import("mixins").PowerfulFeatureObserver;
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
const ActivationBlockersMixinBlockerReason = @import("enums").ActivationBlockersMixinBlockerReason;
const SetHTMLUnsafeOptions = @import("dictionaries").SetHTMLUnsafeOptions;
const Range = @import("interfaces").Range;
const Event = @import("interfaces").Event;
const Animation = @import("interfaces").Animation;
const FocusOptions = @import("dictionaries").FocusOptions;
const TrustedTypeOrDOMString = @import("typedefs").TrustedTypeOrDOMString;
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
const GeolocationPositionError = @import("interfaces").GeolocationPositionError;
const EditContext = @import("interfaces").EditContext;
const GeolocationPosition = @import("interfaces").GeolocationPosition;
const PermissionState = @import("enums").PermissionState;
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

pub const HTMLGeolocationElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLGeolocationElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = HTMLElement.State;
        pub const ParentInterface = HTMLElement;
        pub const MixinTypes = &.{
            ActivationBlockersMixin,
            PowerfulFeatureObserver,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "position", "get_position", null },
            .{ "error", "get_error", null },
            .{ "autolocate", "get_autolocate", "set_autolocate" },
            .{ "watch", "get_watch", "set_watch" },
            .{ "onlocation", "get_onlocation", "set_onlocation" },
            .{ "isValid", "get_isValid", null },
            .{ "invalidReason", "get_invalidReason", null },
            .{ "onvalidationstatuschange", "get_onvalidationstatuschange", "set_onvalidationstatuschange" },
            .{ "initialPermissionStatus", "get_initialPermissionStatus", null },
            .{ "permissionStatus", "get_permissionStatus", null },
            .{ "onpromptaction", "get_onpromptaction", "set_onpromptaction" },
            .{ "onpromptdismiss", "get_onpromptdismiss", "set_onpromptdismiss" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

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
            .{ "position", "get_position", null },
            .{ "error", "get_error", null },
            .{ "autolocate", "get_autolocate", "set_autolocate" },
            .{ "watch", "get_watch", "set_watch" },
            .{ "onlocation", "get_onlocation", "set_onlocation" },
            .{ "isValid", "get_isValid", null },
            .{ "invalidReason", "get_invalidReason", null },
            .{ "onvalidationstatuschange", "get_onvalidationstatuschange", "set_onvalidationstatuschange" },
            .{ "initialPermissionStatus", "get_initialPermissionStatus", null },
            .{ "permissionStatus", "get_permissionStatus", null },
            .{ "onpromptaction", "get_onpromptaction", "set_onpromptaction" },
            .{ "onpromptdismiss", "get_onpromptdismiss", "set_onpromptdismiss" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    /// HTML 3.2.3 [HTMLConstructor]: the constructor's steps are HTML's "HTML
    /// element constructors" - the binding runs them with
    /// engine.HostHooks.htmlConstructor.
    pub const html_constructor = true;

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            position: ?*runtime.Instance = null,
            @"error": ?*runtime.Instance = null,
            autolocate: bool = undefined,
            watch: bool = undefined,
            onlocation: typedefs.EventHandler = undefined,
            isValid: bool = undefined,
            invalidReason: enums.ActivationBlockersMixinBlockerReason = undefined,
            onvalidationstatuschange: typedefs.EventHandler = undefined,
            initialPermissionStatus: enums.PermissionState = undefined,
            permissionStatus: enums.PermissionState = undefined,
            onpromptaction: typedefs.EventHandler = undefined,
            onpromptdismiss: typedefs.EventHandler = undefined,
            _internal: ?*HTMLGeolocationElementImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_autolocate = &get_autolocate,
        .get_error = &get_error,
        .get_initialPermissionStatus = &get_initialPermissionStatus,
        .get_invalidReason = &get_invalidReason,
        .get_isValid = &get_isValid,
        .get_onlocation = &get_onlocation,
        .get_onpromptaction = &get_onpromptaction,
        .get_onpromptdismiss = &get_onpromptdismiss,
        .get_onvalidationstatuschange = &get_onvalidationstatuschange,
        .get_permissionStatus = &get_permissionStatus,
        .get_position = &get_position,
        .get_watch = &get_watch,

        .set_autolocate = &set_autolocate,
        .set_onlocation = &set_onlocation,
        .set_onpromptaction = &set_onpromptaction,
        .set_onpromptdismiss = &set_onpromptdismiss,
        .set_onvalidationstatuschange = &set_onvalidationstatuschange,
        .set_watch = &set_watch,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("HTMLGeolocationElement has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(HTMLGeolocationElementImpl, "init") and @hasDecl(HTMLGeolocationElementImpl, "initOwn")) @compileError("HTMLGeolocationElementImpl defines both init and initOwn");
        if (comptime @hasDecl(HTMLGeolocationElementImpl, "init")) return HTMLGeolocationElementImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(HTMLGeolocationElementImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try HTMLGeolocationElementImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(HTMLGeolocationElementImpl, "init")) return false;
        if (comptime @hasDecl(HTMLGeolocationElementImpl, "construction_args")) {
            inline for (HTMLGeolocationElementImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(HTMLGeolocationElementImpl, "deinit") and @hasDecl(HTMLGeolocationElementImpl, "deinitOwn")) @compileError("HTMLGeolocationElementImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(HTMLGeolocationElementImpl, "deinit")) return HTMLGeolocationElementImpl.deinit(instance);
        if (comptime @hasDecl(HTMLGeolocationElementImpl, "deinitOwn")) HTMLGeolocationElementImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "HTMLGeolocationElement")) {
            if (comptime @hasDecl(impls.HTMLGeolocationElement, "installHooks")) impls.HTMLGeolocationElement.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 0;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLGeolocationElementImpl.call_constructor(ctx);
    }

    pub fn get_position(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try HTMLGeolocationElementImpl.get_position(instance);
    }

    pub fn get_error(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try HTMLGeolocationElementImpl.get_error(instance);
    }

    const reflection = @import("dom").reflection;

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_autolocate(instance: *runtime.Instance) anyerror!bool {
        if (comptime @hasDecl(HTMLGeolocationElementImpl, "get_autolocate")) return try HTMLGeolocationElementImpl.get_autolocate(instance);
        return try reflection.get(bool, instance, .{ .name = "autolocate" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_autolocate(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLGeolocationElementImpl, "set_autolocate")) return try HTMLGeolocationElementImpl.set_autolocate(instance, value);
        try reflection.set(bool, instance, .{ .name = "autolocate" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_watch(instance: *runtime.Instance) anyerror!bool {
        if (comptime @hasDecl(HTMLGeolocationElementImpl, "get_watch")) return try HTMLGeolocationElementImpl.get_watch(instance);
        return try reflection.get(bool, instance, .{ .name = "watch" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_watch(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLGeolocationElementImpl, "set_watch")) return try HTMLGeolocationElementImpl.set_watch(instance, value);
        try reflection.set(bool, instance, .{ .name = "watch" }, value);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onlocation(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(HTMLGeolocationElementImpl, "get_onlocation")) return try HTMLGeolocationElementImpl.get_onlocation(instance);
        return event_handlers.value(EventHandler, instance, "onlocation");
    }

    pub fn set_onlocation(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(HTMLGeolocationElementImpl, "set_onlocation")) return try HTMLGeolocationElementImpl.set_onlocation(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onlocation", value);
    }

    pub fn get_isValid(instance: *runtime.Instance) anyerror!bool {
        return try HTMLGeolocationElementImpl.get_isValid(instance);
    }

    pub fn get_invalidReason(instance: *runtime.Instance) anyerror!ActivationBlockersMixinBlockerReason {
        return try HTMLGeolocationElementImpl.get_invalidReason(instance);
    }

    pub fn get_onvalidationstatuschange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(HTMLGeolocationElementImpl, "get_onvalidationstatuschange")) return try HTMLGeolocationElementImpl.get_onvalidationstatuschange(instance);
        return event_handlers.value(EventHandler, instance, "onvalidationstatuschange");
    }

    pub fn set_onvalidationstatuschange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(HTMLGeolocationElementImpl, "set_onvalidationstatuschange")) return try HTMLGeolocationElementImpl.set_onvalidationstatuschange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onvalidationstatuschange", value);
    }

    pub fn get_initialPermissionStatus(instance: *runtime.Instance) anyerror!PermissionState {
        return try HTMLGeolocationElementImpl.get_initialPermissionStatus(instance);
    }

    pub fn get_permissionStatus(instance: *runtime.Instance) anyerror!PermissionState {
        return try HTMLGeolocationElementImpl.get_permissionStatus(instance);
    }

    pub fn get_onpromptaction(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(HTMLGeolocationElementImpl, "get_onpromptaction")) return try HTMLGeolocationElementImpl.get_onpromptaction(instance);
        return event_handlers.value(EventHandler, instance, "onpromptaction");
    }

    pub fn set_onpromptaction(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(HTMLGeolocationElementImpl, "set_onpromptaction")) return try HTMLGeolocationElementImpl.set_onpromptaction(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onpromptaction", value);
    }

    pub fn get_onpromptdismiss(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(HTMLGeolocationElementImpl, "get_onpromptdismiss")) return try HTMLGeolocationElementImpl.get_onpromptdismiss(instance);
        return event_handlers.value(EventHandler, instance, "onpromptdismiss");
    }

    pub fn set_onpromptdismiss(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(HTMLGeolocationElementImpl, "set_onpromptdismiss")) return try HTMLGeolocationElementImpl.set_onpromptdismiss(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onpromptdismiss", value);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{ "set_onlocation", "set_onvalidationstatuschange", "set_onpromptaction", "set_onpromptdismiss" };

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "set_autolocate",
        "set_watch",
    };
};
