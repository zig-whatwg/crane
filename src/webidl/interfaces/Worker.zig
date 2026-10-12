//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WorkerImpl = @import("impls").Worker;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AbstractWorker = @import("mixins").AbstractWorker;
const MessageEventTarget = @import("mixins").MessageEventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const TrustedScriptURLOrUSVString = @import("typedefs").TrustedScriptURLOrUSVString;
const StructuredSerializeOptions = @import("dictionaries").StructuredSerializeOptions;
const Observable = @import("interfaces").Observable;
const WorkerOptions = @import("dictionaries").WorkerOptions;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const Worker = struct {
    pub const Meta = struct {
        pub const name = "Worker";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{
            AbstractWorker,
            MessageEventTarget,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker", "SharedWorker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
            .SharedWorker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onmessageerror", "get_onmessageerror", "set_onmessageerror" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "terminate", "call_terminate", 0 },
            .{ "postMessage", "call_postMessage", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "terminate",
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
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onmessageerror", "get_onmessageerror", "set_onmessageerror" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            onerror: typedefs.EventHandler = undefined,
            onmessage: typedefs.EventHandler = undefined,
            onmessageerror: typedefs.EventHandler = undefined,
            _internal: ?*WorkerImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onerror = &get_onerror,
        .get_onmessage = &get_onmessage,
        .get_onmessageerror = &get_onmessageerror,

        .set_onerror = &set_onerror,
        .set_onmessage = &set_onmessage,
        .set_onmessageerror = &set_onmessageerror,

        .call_postMessage = &call_postMessage,
        .call_terminate = &call_terminate,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("Worker has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(WorkerImpl, "init") and @hasDecl(WorkerImpl, "initOwn")) @compileError("WorkerImpl defines both init and initOwn");
        if (comptime @hasDecl(WorkerImpl, "init")) return WorkerImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(WorkerImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try WorkerImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(WorkerImpl, "init")) return false;
        if (comptime @hasDecl(WorkerImpl, "construction_args")) {
            inline for (WorkerImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(WorkerImpl, "deinit") and @hasDecl(WorkerImpl, "deinitOwn")) @compileError("WorkerImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(WorkerImpl, "deinit")) return WorkerImpl.deinit(instance);
        if (comptime @hasDecl(WorkerImpl, "deinitOwn")) WorkerImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Worker")) {
            if (comptime @hasDecl(impls.Worker, "installHooks")) impls.Worker.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, scriptURL: TrustedScriptURLOrUSVString, options: webidl.Opt(WorkerOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try WorkerImpl.call_constructor(ctx, scriptURL, options);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(WorkerImpl, "get_onerror")) return try WorkerImpl.get_onerror(instance);
        return event_handlers.value(EventHandler, instance, "onerror");
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(WorkerImpl, "set_onerror")) return try WorkerImpl.set_onerror(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onerror", value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(WorkerImpl, "get_onmessage")) return try WorkerImpl.get_onmessage(instance);
        return event_handlers.value(EventHandler, instance, "onmessage");
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(WorkerImpl, "set_onmessage")) return try WorkerImpl.set_onmessage(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onmessage", value);
    }

    pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(WorkerImpl, "get_onmessageerror")) return try WorkerImpl.get_onmessageerror(instance);
        return event_handlers.value(EventHandler, instance, "onmessageerror");
    }

    pub fn set_onmessageerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(WorkerImpl, "set_onmessageerror")) return try WorkerImpl.set_onmessageerror(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onmessageerror", value);
    }

    pub fn call_postMessage(instance: *runtime.Instance, message: runtime.JSValue, transfer: runtime.JSValue) anyerror!void {
        return try WorkerImpl.call_postMessage(instance, message, transfer);
    }

    pub fn call_terminate(instance: *runtime.Instance) anyerror!void {
        return try WorkerImpl.call_terminate(instance);
    }

    pub fn call_postMessage__1(instance: *runtime.Instance, message: runtime.JSValue, options: webidl.Opt(StructuredSerializeOptions)) anyerror!void {
        if (comptime @hasDecl(WorkerImpl, "call_postMessage__1")) {
            return try WorkerImpl.call_postMessage__1(instance, message, options);
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
            .{ .function = "call_postMessage__1", .implemented = @hasDecl(WorkerImpl, "call_postMessage__1"), .args = &.{ .{ .kinds = &.{.any} }, .{ .kinds = &.{.dictionary}, .optionality = .optional } } },
        } },
    };
};
