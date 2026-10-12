//! Generated from: service-workers.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ServiceWorkerImpl = @import("impls").ServiceWorker;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AbstractWorker = @import("mixins").AbstractWorker;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const StructuredSerializeOptions = @import("dictionaries").StructuredSerializeOptions;
const USVString = @import("typedefs").USVString;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const ServiceWorkerState = @import("enums").ServiceWorkerState;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const ServiceWorker = struct {
    pub const Meta = struct {
        pub const name = "ServiceWorker";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{
            AbstractWorker,
        };
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
            .{ "scriptURL", "get_scriptURL", null },
            .{ "state", "get_state", null },
            .{ "onstatechange", "get_onstatechange", "set_onstatechange" },
            .{ "onerror", "get_onerror", "set_onerror" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "postMessage", "call_postMessage", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "postMessage",
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
            .{ "scriptURL", "get_scriptURL", null },
            .{ "state", "get_state", null },
            .{ "onstatechange", "get_onstatechange", "set_onstatechange" },
            .{ "onerror", "get_onerror", "set_onerror" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            scriptURL: runtime.USVString = undefined,
            state: enums.ServiceWorkerState = undefined,
            onstatechange: typedefs.EventHandler = undefined,
            onerror: typedefs.EventHandler = undefined,
            _internal: ?*ServiceWorkerImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onerror = &get_onerror,
        .get_onstatechange = &get_onstatechange,
        .get_scriptURL = &get_scriptURL,
        .get_state = &get_state,

        .set_onerror = &set_onerror,
        .set_onstatechange = &set_onstatechange,

        .call_postMessage = &call_postMessage,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("ServiceWorker has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(ServiceWorkerImpl, "init") and @hasDecl(ServiceWorkerImpl, "initOwn")) @compileError("ServiceWorkerImpl defines both init and initOwn");
        if (comptime @hasDecl(ServiceWorkerImpl, "init")) return ServiceWorkerImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(ServiceWorkerImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try ServiceWorkerImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ServiceWorkerImpl, "init")) return false;
        if (comptime @hasDecl(ServiceWorkerImpl, "construction_args")) {
            inline for (ServiceWorkerImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ServiceWorkerImpl, "deinit") and @hasDecl(ServiceWorkerImpl, "deinitOwn")) @compileError("ServiceWorkerImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ServiceWorkerImpl, "deinit")) return ServiceWorkerImpl.deinit(instance);
        if (comptime @hasDecl(ServiceWorkerImpl, "deinitOwn")) ServiceWorkerImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ServiceWorker")) {
            if (comptime @hasDecl(impls.ServiceWorker, "installHooks")) impls.ServiceWorker.installHooks();
        }
    }

    pub fn get_scriptURL(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try ServiceWorkerImpl.get_scriptURL(instance);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!ServiceWorkerState {
        return try ServiceWorkerImpl.get_state(instance);
    }

    pub fn get_onstatechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerImpl.get_onstatechange(instance);
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerImpl.set_onstatechange(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try ServiceWorkerImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ServiceWorkerImpl.set_onerror(instance, value);
    }

    pub fn call_postMessage(instance: *runtime.Instance, message: runtime.JSValue, transfer: runtime.JSValue) anyerror!void {
        return try ServiceWorkerImpl.call_postMessage(instance, message, transfer);
    }

    pub fn call_postMessage__1(instance: *runtime.Instance, message: runtime.JSValue, options: webidl.Opt(StructuredSerializeOptions)) anyerror!void {
        if (comptime @hasDecl(ServiceWorkerImpl, "call_postMessage__1")) {
            return try ServiceWorkerImpl.call_postMessage__1(instance, message, options);
        } else {
            return error.NotImplemented;
        }
    }

    /// WebIDL overload sets: every overload of each overloaded operation,
    /// in IDL order, for the overload resolution algorithm
    /// (webidl.overload_resolution). The binding is installed for the first
    /// overload and forwards to the one the arguments select.
    pub const overloads = .{
        .{ "postMessage", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_postMessage", .args = &.{ .{ .kinds = &.{.any} }, .{ .kinds = &.{.sequence} } } },
            .{ .function = "call_postMessage__1", .implemented = @hasDecl(ServiceWorkerImpl, "call_postMessage__1"), .args = &.{ .{ .kinds = &.{.any} }, .{ .kinds = &.{.dictionary}, .optionality = .optional } } },
        } },
    };
};
