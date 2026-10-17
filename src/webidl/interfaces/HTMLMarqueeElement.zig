//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLMarqueeElementImpl = @import("impls").HTMLMarqueeElement;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const HTMLElement = @import("interfaces").HTMLElement;
const DOMStringMap = @import("interfaces").DOMStringMap;
const CSSOMString = @import("typedefs").CSSOMString;
const TogglePopoverOptions = @import("dictionaries").TogglePopoverOptions;
const HTMLCollection = @import("interfaces").HTMLCollection;
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

pub const HTMLMarqueeElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLMarqueeElement";
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
            .{ "behavior", "get_behavior", "set_behavior" },
            .{ "bgColor", "get_bgColor", "set_bgColor" },
            .{ "direction", "get_direction", "set_direction" },
            .{ "height", "get_height", "set_height" },
            .{ "hspace", "get_hspace", "set_hspace" },
            .{ "loop", "get_loop", "set_loop" },
            .{ "scrollAmount", "get_scrollAmount", "set_scrollAmount" },
            .{ "scrollDelay", "get_scrollDelay", "set_scrollDelay" },
            .{ "trueSpeed", "get_trueSpeed", "set_trueSpeed" },
            .{ "vspace", "get_vspace", "set_vspace" },
            .{ "width", "get_width", "set_width" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "start", "call_start", 0 },
            .{ "stop", "call_stop", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "start",
            "stop",
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
            .{ "behavior", "get_behavior", "set_behavior" },
            .{ "bgColor", "get_bgColor", "set_bgColor" },
            .{ "direction", "get_direction", "set_direction" },
            .{ "height", "get_height", "set_height" },
            .{ "hspace", "get_hspace", "set_hspace" },
            .{ "loop", "get_loop", "set_loop" },
            .{ "scrollAmount", "get_scrollAmount", "set_scrollAmount" },
            .{ "scrollDelay", "get_scrollDelay", "set_scrollDelay" },
            .{ "trueSpeed", "get_trueSpeed", "set_trueSpeed" },
            .{ "vspace", "get_vspace", "set_vspace" },
            .{ "width", "get_width", "set_width" },
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
            behavior: runtime.DOMString = undefined,
            bgColor: runtime.DOMString = undefined,
            direction: runtime.DOMString = undefined,
            height: runtime.DOMString = undefined,
            hspace: u32 = undefined,
            loop: i32 = undefined,
            scrollAmount: u32 = undefined,
            scrollDelay: u32 = undefined,
            trueSpeed: bool = undefined,
            vspace: u32 = undefined,
            width: runtime.DOMString = undefined,
            _internal: ?*HTMLMarqueeElementImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_behavior = &get_behavior,
        .get_bgColor = &get_bgColor,
        .get_direction = &get_direction,
        .get_height = &get_height,
        .get_hspace = &get_hspace,
        .get_loop = &get_loop,
        .get_scrollAmount = &get_scrollAmount,
        .get_scrollDelay = &get_scrollDelay,
        .get_trueSpeed = &get_trueSpeed,
        .get_vspace = &get_vspace,
        .get_width = &get_width,

        .set_behavior = &set_behavior,
        .set_bgColor = &set_bgColor,
        .set_direction = &set_direction,
        .set_height = &set_height,
        .set_hspace = &set_hspace,
        .set_loop = &set_loop,
        .set_scrollAmount = &set_scrollAmount,
        .set_scrollDelay = &set_scrollDelay,
        .set_trueSpeed = &set_trueSpeed,
        .set_vspace = &set_vspace,
        .set_width = &set_width,

        .call_start = &call_start,
        .call_stop = &call_stop,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("HTMLMarqueeElement has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(HTMLMarqueeElementImpl, "init") and @hasDecl(HTMLMarqueeElementImpl, "initOwn")) @compileError("HTMLMarqueeElementImpl defines both init and initOwn");
        if (comptime @hasDecl(HTMLMarqueeElementImpl, "init")) return HTMLMarqueeElementImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(HTMLMarqueeElementImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try HTMLMarqueeElementImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(HTMLMarqueeElementImpl, "init")) return false;
        if (comptime @hasDecl(HTMLMarqueeElementImpl, "construction_args")) {
            inline for (HTMLMarqueeElementImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(HTMLMarqueeElementImpl, "deinit") and @hasDecl(HTMLMarqueeElementImpl, "deinitOwn")) @compileError("HTMLMarqueeElementImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(HTMLMarqueeElementImpl, "deinit")) return HTMLMarqueeElementImpl.deinit(instance);
        if (comptime @hasDecl(HTMLMarqueeElementImpl, "deinitOwn")) HTMLMarqueeElementImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "HTMLMarqueeElement")) {
            if (comptime @hasDecl(impls.HTMLMarqueeElement, "installHooks")) impls.HTMLMarqueeElement.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLMarqueeElementImpl.call_constructor(ctx);
    }

    const reflection = @import("dom").reflection;

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_behavior(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(HTMLMarqueeElementImpl, "get_behavior")) return try HTMLMarqueeElementImpl.get_behavior(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "behavior" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_behavior(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLMarqueeElementImpl, "set_behavior")) return try HTMLMarqueeElementImpl.set_behavior(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "behavior" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_bgColor(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(HTMLMarqueeElementImpl, "get_bgColor")) return try HTMLMarqueeElementImpl.get_bgColor(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "bgcolor" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_bgColor(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLMarqueeElementImpl, "set_bgColor")) return try HTMLMarqueeElementImpl.set_bgColor(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "bgcolor" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_direction(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(HTMLMarqueeElementImpl, "get_direction")) return try HTMLMarqueeElementImpl.get_direction(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "direction" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_direction(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLMarqueeElementImpl, "set_direction")) return try HTMLMarqueeElementImpl.set_direction(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "direction" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_height(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(HTMLMarqueeElementImpl, "get_height")) return try HTMLMarqueeElementImpl.get_height(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "height" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_height(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLMarqueeElementImpl, "set_height")) return try HTMLMarqueeElementImpl.set_height(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "height" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_hspace(instance: *runtime.Instance) anyerror!u32 {
        if (comptime @hasDecl(HTMLMarqueeElementImpl, "get_hspace")) return try HTMLMarqueeElementImpl.get_hspace(instance);
        return try reflection.get(u32, instance, .{ .name = "hspace" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_hspace(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLMarqueeElementImpl, "set_hspace")) return try HTMLMarqueeElementImpl.set_hspace(instance, value);
        try reflection.set(u32, instance, .{ .name = "hspace" }, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_loop(instance: *runtime.Instance) anyerror!i32 {
        return try HTMLMarqueeElementImpl.get_loop(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_loop(instance: *runtime.Instance, value: i32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try HTMLMarqueeElementImpl.set_loop(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect], [ReflectDefault=6]
    pub fn get_scrollAmount(instance: *runtime.Instance) anyerror!u32 {
        if (comptime @hasDecl(HTMLMarqueeElementImpl, "get_scrollAmount")) return try HTMLMarqueeElementImpl.get_scrollAmount(instance);
        return try reflection.get(u32, instance, .{ .name = "scrollamount", .default = 6 });
    }

    /// Extended attributes: [CEReactions], [Reflect], [ReflectDefault=6]
    pub fn set_scrollAmount(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLMarqueeElementImpl, "set_scrollAmount")) return try HTMLMarqueeElementImpl.set_scrollAmount(instance, value);
        try reflection.set(u32, instance, .{ .name = "scrollamount", .default = 6 }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect], [ReflectDefault=85]
    pub fn get_scrollDelay(instance: *runtime.Instance) anyerror!u32 {
        if (comptime @hasDecl(HTMLMarqueeElementImpl, "get_scrollDelay")) return try HTMLMarqueeElementImpl.get_scrollDelay(instance);
        return try reflection.get(u32, instance, .{ .name = "scrolldelay", .default = 85 });
    }

    /// Extended attributes: [CEReactions], [Reflect], [ReflectDefault=85]
    pub fn set_scrollDelay(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLMarqueeElementImpl, "set_scrollDelay")) return try HTMLMarqueeElementImpl.set_scrollDelay(instance, value);
        try reflection.set(u32, instance, .{ .name = "scrolldelay", .default = 85 }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_trueSpeed(instance: *runtime.Instance) anyerror!bool {
        if (comptime @hasDecl(HTMLMarqueeElementImpl, "get_trueSpeed")) return try HTMLMarqueeElementImpl.get_trueSpeed(instance);
        return try reflection.get(bool, instance, .{ .name = "truespeed" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_trueSpeed(instance: *runtime.Instance, value: bool) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLMarqueeElementImpl, "set_trueSpeed")) return try HTMLMarqueeElementImpl.set_trueSpeed(instance, value);
        try reflection.set(bool, instance, .{ .name = "truespeed" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_vspace(instance: *runtime.Instance) anyerror!u32 {
        if (comptime @hasDecl(HTMLMarqueeElementImpl, "get_vspace")) return try HTMLMarqueeElementImpl.get_vspace(instance);
        return try reflection.get(u32, instance, .{ .name = "vspace" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_vspace(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLMarqueeElementImpl, "set_vspace")) return try HTMLMarqueeElementImpl.set_vspace(instance, value);
        try reflection.set(u32, instance, .{ .name = "vspace" }, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_width(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(HTMLMarqueeElementImpl, "get_width")) return try HTMLMarqueeElementImpl.get_width(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "width" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_width(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(HTMLMarqueeElementImpl, "set_width")) return try HTMLMarqueeElementImpl.set_width(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "width" }, value);
    }

    pub fn call_start(instance: *runtime.Instance) anyerror!void {
        return try HTMLMarqueeElementImpl.call_start(instance);
    }

    pub fn call_stop(instance: *runtime.Instance) anyerror!void {
        return try HTMLMarqueeElementImpl.call_stop(instance);
    }

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "set_behavior",
        "set_bgColor",
        "set_direction",
        "set_height",
        "set_hspace",
        "set_loop",
        "set_scrollAmount",
        "set_scrollDelay",
        "set_trueSpeed",
        "set_vspace",
        "set_width",
    };
};
