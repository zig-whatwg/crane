//! Generated from: service-workers.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ServiceWorkerContainerImpl = @import("impls").ServiceWorkerContainer;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const ServiceWorker = @import("interfaces").ServiceWorker;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const TrustedScriptURLOrUSVString = @import("typedefs").TrustedScriptURLOrUSVString;
const USVString = @import("typedefs").USVString;
const Observable = @import("interfaces").Observable;
const ServiceWorkerRegistration = @import("interfaces").ServiceWorkerRegistration;
const Event = @import("interfaces").Event;
const RegistrationOptions = @import("dictionaries").RegistrationOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const ServiceWorkerContainer = struct {
    pub const Meta = struct {
        pub const name = "ServiceWorkerContainer";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "controller", "get_controller", null },
            .{ "ready", "get_ready", null },
            .{ "oncontrollerchange", "get_oncontrollerchange", "set_oncontrollerchange" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onmessageerror", "get_onmessageerror", "set_onmessageerror" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "register", "call_register", 1 },
            .{ "getRegistration", "call_getRegistration", 0 },
            .{ "getRegistrations", "call_getRegistrations", 0 },
            .{ "startMessages", "call_startMessages", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "register",
            "getRegistration",
            "getRegistrations",
            "startMessages",
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
            .{ "controller", "get_controller", null },
            .{ "ready", "get_ready", null },
            .{ "oncontrollerchange", "get_oncontrollerchange", "set_oncontrollerchange" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onmessageerror", "get_onmessageerror", "set_onmessageerror" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            controller: ?*runtime.Instance = null,
            ready: runtime.JSValue = undefined,
            oncontrollerchange: typedefs.EventHandler = undefined,
            onmessage: typedefs.EventHandler = undefined,
            onmessageerror: typedefs.EventHandler = undefined,
            _internal: ?*ServiceWorkerContainerImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_controller = &get_controller,
        .get_oncontrollerchange = &get_oncontrollerchange,
        .get_onmessage = &get_onmessage,
        .get_onmessageerror = &get_onmessageerror,
        .get_ready = &get_ready,

        .set_oncontrollerchange = &set_oncontrollerchange,
        .set_onmessage = &set_onmessage,
        .set_onmessageerror = &set_onmessageerror,

        .call_getRegistration = &call_getRegistration,
        .call_getRegistrations = &call_getRegistrations,
        .call_register = &call_register,
        .call_startMessages = &call_startMessages,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("ServiceWorkerContainer has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(ServiceWorkerContainerImpl, "init") and @hasDecl(ServiceWorkerContainerImpl, "initOwn")) @compileError("ServiceWorkerContainerImpl defines both init and initOwn");
        if (comptime @hasDecl(ServiceWorkerContainerImpl, "init")) return ServiceWorkerContainerImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(ServiceWorkerContainerImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try ServiceWorkerContainerImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ServiceWorkerContainerImpl, "init")) return false;
        if (comptime @hasDecl(ServiceWorkerContainerImpl, "construction_args")) {
            inline for (ServiceWorkerContainerImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ServiceWorkerContainerImpl, "deinit") and @hasDecl(ServiceWorkerContainerImpl, "deinitOwn")) @compileError("ServiceWorkerContainerImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ServiceWorkerContainerImpl, "deinit")) return ServiceWorkerContainerImpl.deinit(instance);
        if (comptime @hasDecl(ServiceWorkerContainerImpl, "deinitOwn")) ServiceWorkerContainerImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ServiceWorkerContainer")) {
            if (comptime @hasDecl(impls.ServiceWorkerContainer, "installHooks")) impls.ServiceWorkerContainer.installHooks();
        }
    }

    pub fn get_controller(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ServiceWorkerContainerImpl.get_controller(instance);
    }

    pub fn get_ready(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ServiceWorkerContainerImpl.get_ready(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_oncontrollerchange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(ServiceWorkerContainerImpl, "get_oncontrollerchange")) return try ServiceWorkerContainerImpl.get_oncontrollerchange(instance);
        return event_handlers.value(EventHandler, instance, "oncontrollerchange");
    }

    pub fn set_oncontrollerchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(ServiceWorkerContainerImpl, "set_oncontrollerchange")) return try ServiceWorkerContainerImpl.set_oncontrollerchange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "oncontrollerchange", value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(ServiceWorkerContainerImpl, "get_onmessage")) return try ServiceWorkerContainerImpl.get_onmessage(instance);
        return event_handlers.value(EventHandler, instance, "onmessage");
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(ServiceWorkerContainerImpl, "set_onmessage")) return try ServiceWorkerContainerImpl.set_onmessage(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onmessage", value);
    }

    pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(ServiceWorkerContainerImpl, "get_onmessageerror")) return try ServiceWorkerContainerImpl.get_onmessageerror(instance);
        return event_handlers.value(EventHandler, instance, "onmessageerror");
    }

    pub fn set_onmessageerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(ServiceWorkerContainerImpl, "set_onmessageerror")) return try ServiceWorkerContainerImpl.set_onmessageerror(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onmessageerror", value);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getRegistration(instance: *runtime.Instance, clientURL: webidl.Opt(runtime.USVString)) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object

        return try ServiceWorkerContainerImpl.call_getRegistration(instance, clientURL);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getRegistrations(instance: *runtime.Instance) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object
        return try ServiceWorkerContainerImpl.call_getRegistrations(instance);
    }

    pub fn call_startMessages(instance: *runtime.Instance) anyerror!void {
        return try ServiceWorkerContainerImpl.call_startMessages(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_register(instance: *runtime.Instance, scriptURL: TrustedScriptURLOrUSVString, options: webidl.Opt(RegistrationOptions)) anyerror!runtime.JSValue {
        // [NewObject] - Caller owns the returned object

        return try ServiceWorkerContainerImpl.call_register(instance, scriptURL, options);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{ "set_oncontrollerchange", "set_onmessage", "set_onmessageerror" };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_getRegistration",
        "call_getRegistrations",
        "call_register",
    };
};
