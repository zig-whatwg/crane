//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NavigationImpl = @import("impls").Navigation;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const NavigationActivation = @import("interfaces").NavigationActivation;
const NavigationTransition = @import("interfaces").NavigationTransition;
const NavigationHistoryEntry = @import("interfaces").NavigationHistoryEntry;
const USVString = @import("typedefs").USVString;
const NavigationUpdateCurrentEntryOptions = @import("dictionaries").NavigationUpdateCurrentEntryOptions;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const NavigationResult = @import("dictionaries").NavigationResult;
const NavigationOptions = @import("dictionaries").NavigationOptions;
const NavigationNavigateOptions = @import("dictionaries").NavigationNavigateOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const NavigationReloadOptions = @import("dictionaries").NavigationReloadOptions;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const Navigation = struct {
    pub const Meta = struct {
        pub const name = "Navigation";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "currentEntry", "get_currentEntry", null },
            .{ "transition", "get_transition", null },
            .{ "activation", "get_activation", null },
            .{ "canGoBack", "get_canGoBack", null },
            .{ "canGoForward", "get_canGoForward", null },
            .{ "onnavigate", "get_onnavigate", "set_onnavigate" },
            .{ "onnavigatesuccess", "get_onnavigatesuccess", "set_onnavigatesuccess" },
            .{ "onnavigateerror", "get_onnavigateerror", "set_onnavigateerror" },
            .{ "oncurrententrychange", "get_oncurrententrychange", "set_oncurrententrychange" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "entries", "call_entries", 0 },
            .{ "updateCurrentEntry", "call_updateCurrentEntry", 1 },
            .{ "navigate", "call_navigate", 1 },
            .{ "reload", "call_reload", 0 },
            .{ "traverseTo", "call_traverseTo", 1 },
            .{ "back", "call_back", 0 },
            .{ "forward", "call_forward", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "entries",
            "updateCurrentEntry",
            "navigate",
            "reload",
            "traverseTo",
            "back",
            "forward",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "currentEntry", "get_currentEntry", null },
            .{ "transition", "get_transition", null },
            .{ "activation", "get_activation", null },
            .{ "canGoBack", "get_canGoBack", null },
            .{ "canGoForward", "get_canGoForward", null },
            .{ "onnavigate", "get_onnavigate", "set_onnavigate" },
            .{ "onnavigatesuccess", "get_onnavigatesuccess", "set_onnavigatesuccess" },
            .{ "onnavigateerror", "get_onnavigateerror", "set_onnavigateerror" },
            .{ "oncurrententrychange", "get_oncurrententrychange", "set_oncurrententrychange" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            currentEntry: ?*runtime.Instance = null,
            transition: ?*runtime.Instance = null,
            activation: ?*runtime.Instance = null,
            canGoBack: bool = undefined,
            canGoForward: bool = undefined,
            onnavigate: typedefs.EventHandler = undefined,
            onnavigatesuccess: typedefs.EventHandler = undefined,
            onnavigateerror: typedefs.EventHandler = undefined,
            oncurrententrychange: typedefs.EventHandler = undefined,
            _internal: ?*NavigationImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_activation = &get_activation,
        .get_canGoBack = &get_canGoBack,
        .get_canGoForward = &get_canGoForward,
        .get_currentEntry = &get_currentEntry,
        .get_oncurrententrychange = &get_oncurrententrychange,
        .get_onnavigate = &get_onnavigate,
        .get_onnavigateerror = &get_onnavigateerror,
        .get_onnavigatesuccess = &get_onnavigatesuccess,
        .get_transition = &get_transition,

        .set_oncurrententrychange = &set_oncurrententrychange,
        .set_onnavigate = &set_onnavigate,
        .set_onnavigateerror = &set_onnavigateerror,
        .set_onnavigatesuccess = &set_onnavigatesuccess,

        .call_back = &call_back,
        .call_entries = &call_entries,
        .call_forward = &call_forward,
        .call_navigate = &call_navigate,
        .call_reload = &call_reload,
        .call_traverseTo = &call_traverseTo,
        .call_updateCurrentEntry = &call_updateCurrentEntry,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("Navigation has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(NavigationImpl, "init") and @hasDecl(NavigationImpl, "initOwn")) @compileError("NavigationImpl defines both init and initOwn");
        if (comptime @hasDecl(NavigationImpl, "init")) return NavigationImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(NavigationImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try NavigationImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(NavigationImpl, "init")) return false;
        if (comptime @hasDecl(NavigationImpl, "construction_args")) {
            inline for (NavigationImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(NavigationImpl, "deinit") and @hasDecl(NavigationImpl, "deinitOwn")) @compileError("NavigationImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(NavigationImpl, "deinit")) return NavigationImpl.deinit(instance);
        if (comptime @hasDecl(NavigationImpl, "deinitOwn")) NavigationImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Navigation")) {
            if (comptime @hasDecl(impls.Navigation, "installHooks")) impls.Navigation.installHooks();
        }
    }

    pub fn get_currentEntry(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try NavigationImpl.get_currentEntry(instance);
    }

    pub fn get_transition(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try NavigationImpl.get_transition(instance);
    }

    pub fn get_activation(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try NavigationImpl.get_activation(instance);
    }

    pub fn get_canGoBack(instance: *runtime.Instance) anyerror!bool {
        return try NavigationImpl.get_canGoBack(instance);
    }

    pub fn get_canGoForward(instance: *runtime.Instance) anyerror!bool {
        return try NavigationImpl.get_canGoForward(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onnavigate(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(NavigationImpl, "get_onnavigate")) return try NavigationImpl.get_onnavigate(instance);
        return event_handlers.value(EventHandler, instance, "onnavigate");
    }

    pub fn set_onnavigate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(NavigationImpl, "set_onnavigate")) return try NavigationImpl.set_onnavigate(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onnavigate", value);
    }

    pub fn get_onnavigatesuccess(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(NavigationImpl, "get_onnavigatesuccess")) return try NavigationImpl.get_onnavigatesuccess(instance);
        return event_handlers.value(EventHandler, instance, "onnavigatesuccess");
    }

    pub fn set_onnavigatesuccess(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(NavigationImpl, "set_onnavigatesuccess")) return try NavigationImpl.set_onnavigatesuccess(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onnavigatesuccess", value);
    }

    pub fn get_onnavigateerror(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(NavigationImpl, "get_onnavigateerror")) return try NavigationImpl.get_onnavigateerror(instance);
        return event_handlers.value(EventHandler, instance, "onnavigateerror");
    }

    pub fn set_onnavigateerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(NavigationImpl, "set_onnavigateerror")) return try NavigationImpl.set_onnavigateerror(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onnavigateerror", value);
    }

    pub fn get_oncurrententrychange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(NavigationImpl, "get_oncurrententrychange")) return try NavigationImpl.get_oncurrententrychange(instance);
        return event_handlers.value(EventHandler, instance, "oncurrententrychange");
    }

    pub fn set_oncurrententrychange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(NavigationImpl, "set_oncurrententrychange")) return try NavigationImpl.set_oncurrententrychange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "oncurrententrychange", value);
    }

    pub fn call_reload(instance: *runtime.Instance, options: webidl.Opt(NavigationReloadOptions)) anyerror!NavigationResult {
        return try NavigationImpl.call_reload(instance, options);
    }

    pub fn call_entries(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try NavigationImpl.call_entries(instance);
    }

    pub fn call_back(instance: *runtime.Instance, options: webidl.Opt(NavigationOptions)) anyerror!NavigationResult {
        return try NavigationImpl.call_back(instance, options);
    }

    pub fn call_updateCurrentEntry(instance: *runtime.Instance, options: NavigationUpdateCurrentEntryOptions) anyerror!void {
        return try NavigationImpl.call_updateCurrentEntry(instance, options);
    }

    pub fn call_navigate(instance: *runtime.Instance, url: runtime.USVString, options: webidl.Opt(NavigationNavigateOptions)) anyerror!NavigationResult {
        return try NavigationImpl.call_navigate(instance, url, options);
    }

    pub fn call_traverseTo(instance: *runtime.Instance, key: runtime.DOMString, options: webidl.Opt(NavigationOptions)) anyerror!NavigationResult {
        return try NavigationImpl.call_traverseTo(instance, key, options);
    }

    pub fn call_forward(instance: *runtime.Instance, options: webidl.Opt(NavigationOptions)) anyerror!NavigationResult {
        return try NavigationImpl.call_forward(instance, options);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{ "set_onnavigate", "set_onnavigatesuccess", "set_onnavigateerror", "set_oncurrententrychange" };
};
