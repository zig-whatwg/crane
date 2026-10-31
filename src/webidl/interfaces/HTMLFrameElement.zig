//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLFrameElementImpl = @import("impls").HTMLFrameElement;
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
const SpatialNavigationSearchOptions = @import("dictionaries").SpatialNavigationSearchOptions;
const GetAnimationsOptions = @import("dictionaries").GetAnimationsOptions;
const EventHandler = @import("typedefs").EventHandler;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const WindowProxy = @import("typedefs").WindowProxy;
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

pub const HTMLFrameElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLFrameElement";
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
            .{ "name", "get_name", "set_name" },
            .{ "scrolling", "get_scrolling", "set_scrolling" },
            .{ "src", "get_src", "set_src" },
            .{ "frameBorder", "get_frameBorder", "set_frameBorder" },
            .{ "longDesc", "get_longDesc", "set_longDesc" },
            .{ "noResize", "get_noResize", "set_noResize" },
            .{ "contentDocument", "get_contentDocument", null },
            .{ "contentWindow", "get_contentWindow", null },
            .{ "marginHeight", "get_marginHeight", "set_marginHeight" },
            .{ "marginWidth", "get_marginWidth", "set_marginWidth" },
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
            .{ "name", "get_name", "set_name" },
            .{ "scrolling", "get_scrolling", "set_scrolling" },
            .{ "src", "get_src", "set_src" },
            .{ "frameBorder", "get_frameBorder", "set_frameBorder" },
            .{ "longDesc", "get_longDesc", "set_longDesc" },
            .{ "noResize", "get_noResize", "set_noResize" },
            .{ "contentDocument", "get_contentDocument", null },
            .{ "contentWindow", "get_contentWindow", null },
            .{ "marginHeight", "get_marginHeight", "set_marginHeight" },
            .{ "marginWidth", "get_marginWidth", "set_marginWidth" },
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
            name: runtime.DOMString = undefined,
            scrolling: runtime.DOMString = undefined,
            src: runtime.USVString = undefined,
            frameBorder: runtime.DOMString = undefined,
            longDesc: runtime.USVString = undefined,
            noResize: bool = undefined,
            contentDocument: ?*runtime.Instance = null,
            contentWindow: ?typedefs.WindowProxy = null,
            marginHeight: runtime.DOMString = undefined,
            marginWidth: runtime.DOMString = undefined,
            _internal: ?*HTMLFrameElementImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_contentDocument = &get_contentDocument,
        .get_contentWindow = &get_contentWindow,
        .get_frameBorder = &get_frameBorder,
        .get_longDesc = &get_longDesc,
        .get_marginHeight = &get_marginHeight,
        .get_marginWidth = &get_marginWidth,
        .get_name = &get_name,
        .get_noResize = &get_noResize,
        .get_scrolling = &get_scrolling,
        .get_src = &get_src,

        .set_frameBorder = &set_frameBorder,
        .set_longDesc = &set_longDesc,
        .set_marginHeight = &set_marginHeight,
        .set_marginWidth = &set_marginWidth,
        .set_name = &set_name,
        .set_noResize = &set_noResize,
        .set_scrolling = &set_scrolling,
        .set_src = &set_src,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("HTMLFrameElement has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(HTMLFrameElementImpl, "init") and @hasDecl(HTMLFrameElementImpl, "initOwn")) @compileError("HTMLFrameElementImpl defines both init and initOwn");
        if (comptime @hasDecl(HTMLFrameElementImpl, "init")) return HTMLFrameElementImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(HTMLFrameElementImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try HTMLFrameElementImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(HTMLFrameElementImpl, "init")) return false;
        if (comptime @hasDecl(HTMLFrameElementImpl, "construction_args")) {
            inline for (HTMLFrameElementImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(HTMLFrameElementImpl, "deinit") and @hasDecl(HTMLFrameElementImpl, "deinitOwn")) @compileError("HTMLFrameElementImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(HTMLFrameElementImpl, "deinit")) return HTMLFrameElementImpl.deinit(instance);
        if (comptime @hasDecl(HTMLFrameElementImpl, "deinitOwn")) HTMLFrameElementImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "HTMLFrameElement")) {
            if (comptime @hasDecl(impls.HTMLFrameElement, "installHooks")) impls.HTMLFrameElement.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 0;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLFrameElementImpl.call_constructor(ctx);
    }

    const reflection = @import("dom").reflection;

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(HTMLFrameElementImpl, "get_name")) return try HTMLFrameElementImpl.get_name(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "name" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_name(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLFrameElementImpl, "set_name")) return try HTMLFrameElementImpl.set_name(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "name" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_scrolling(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(HTMLFrameElementImpl, "get_scrolling")) return try HTMLFrameElementImpl.get_scrolling(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "scrolling" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_scrolling(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLFrameElementImpl, "set_scrolling")) return try HTMLFrameElementImpl.set_scrolling(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "scrolling" }, value);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn get_src(instance: *runtime.Instance) anyerror!runtime.USVString {
        if (comptime @hasDecl(HTMLFrameElementImpl, "get_src")) return try HTMLFrameElementImpl.get_src(instance);
        return try reflection.get(runtime.USVString, instance, .{ .name = "src", .url = true });
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn set_src(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLFrameElementImpl, "set_src")) return try HTMLFrameElementImpl.set_src(instance, value);
        try reflection.set(runtime.USVString, instance, .{ .name = "src", .url = true }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_frameBorder(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(HTMLFrameElementImpl, "get_frameBorder")) return try HTMLFrameElementImpl.get_frameBorder(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "frameborder" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_frameBorder(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLFrameElementImpl, "set_frameBorder")) return try HTMLFrameElementImpl.set_frameBorder(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "frameborder" }, value);
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn get_longDesc(instance: *runtime.Instance) anyerror!runtime.USVString {
        if (comptime @hasDecl(HTMLFrameElementImpl, "get_longDesc")) return try HTMLFrameElementImpl.get_longDesc(instance);
        return try reflection.get(runtime.USVString, instance, .{ .name = "longdesc", .url = true });
    }

    /// Extended attributes: [CEReactions], [ReflectURL]
    pub fn set_longDesc(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLFrameElementImpl, "set_longDesc")) return try HTMLFrameElementImpl.set_longDesc(instance, value);
        try reflection.set(runtime.USVString, instance, .{ .name = "longdesc", .url = true }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_noResize(instance: *runtime.Instance) anyerror!bool {
        if (comptime @hasDecl(HTMLFrameElementImpl, "get_noResize")) return try HTMLFrameElementImpl.get_noResize(instance);
        return try reflection.get(bool, instance, .{ .name = "noresize" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_noResize(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLFrameElementImpl, "set_noResize")) return try HTMLFrameElementImpl.set_noResize(instance, value);
        try reflection.set(bool, instance, .{ .name = "noresize" }, value);
    }

    pub fn get_contentDocument(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try HTMLFrameElementImpl.get_contentDocument(instance);
    }

    pub fn get_contentWindow(instance: *runtime.Instance) anyerror!?WindowProxy {
        return try HTMLFrameElementImpl.get_contentWindow(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect], [LegacyNullToEmptyString]
    pub fn get_marginHeight(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(HTMLFrameElementImpl, "get_marginHeight")) return try HTMLFrameElementImpl.get_marginHeight(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "marginheight" });
    }

    /// Extended attributes: [CEReactions], [Reflect], [LegacyNullToEmptyString]
    pub fn set_marginHeight(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLFrameElementImpl, "set_marginHeight")) return try HTMLFrameElementImpl.set_marginHeight(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "marginheight" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect], [LegacyNullToEmptyString]
    pub fn get_marginWidth(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(HTMLFrameElementImpl, "get_marginWidth")) return try HTMLFrameElementImpl.get_marginWidth(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "marginwidth" });
    }

    /// Extended attributes: [CEReactions], [Reflect], [LegacyNullToEmptyString]
    pub fn set_marginWidth(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLFrameElementImpl, "set_marginWidth")) return try HTMLFrameElementImpl.set_marginWidth(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "marginwidth" }, value);
    }

    /// WebIDL [LegacyNullToEmptyString]: the values null converts to "" for
    /// (bit i = argument i; an attribute setter's value is bit 0).
    pub const legacy_null_to_empty = .{
        .{ "set_marginHeight", 0b1 },
        .{ "set_marginWidth", 0b1 },
    };

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "set_name",
        "set_scrolling",
        "set_src",
        "set_frameBorder",
        "set_longDesc",
        "set_noResize",
        "set_marginHeight",
        "set_marginWidth",
    };
};
