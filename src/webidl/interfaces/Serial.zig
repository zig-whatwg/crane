//! Generated from: serial.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SerialImpl = @import("impls").Serial;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const SerialPortRequestOptions = @import("dictionaries").SerialPortRequestOptions;
const SerialPort = @import("interfaces").SerialPort;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const Serial = struct {
    pub const Meta = struct {
        pub const name = "Serial";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "DedicatedWorker", "Window" } } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .DedicatedWorker = true,
            .Window = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onconnect", "get_onconnect", "set_onconnect" },
            .{ "ondisconnect", "get_ondisconnect", "set_ondisconnect" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getPorts", "call_getPorts", 0 },
            .{ "requestPort", "call_requestPort", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getPorts",
            "requestPort",
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
            .{ "onconnect", "get_onconnect", "set_onconnect" },
            .{ "ondisconnect", "get_ondisconnect", "set_ondisconnect" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
        /// Member-level [Exposed] overrides; unlisted members inherit the interface.
        pub const exposed_members = .{
            .{ "requestPort", .{"Window"} },
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            onconnect: typedefs.EventHandler = undefined,
            ondisconnect: typedefs.EventHandler = undefined,
            _internal: ?*SerialImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onconnect = &get_onconnect,
        .get_ondisconnect = &get_ondisconnect,

        .set_onconnect = &set_onconnect,
        .set_ondisconnect = &set_ondisconnect,

        .call_getPorts = &call_getPorts,
        .call_requestPort = &call_requestPort,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("Serial has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(SerialImpl, "init") and @hasDecl(SerialImpl, "initOwn")) @compileError("SerialImpl defines both init and initOwn");
        if (comptime @hasDecl(SerialImpl, "init")) return SerialImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(SerialImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try SerialImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SerialImpl, "init")) return false;
        if (comptime @hasDecl(SerialImpl, "construction_args")) {
            inline for (SerialImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(SerialImpl, "deinit") and @hasDecl(SerialImpl, "deinitOwn")) @compileError("SerialImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SerialImpl, "deinit")) return SerialImpl.deinit(instance);
        if (comptime @hasDecl(SerialImpl, "deinitOwn")) SerialImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Serial")) {
            if (comptime @hasDecl(impls.Serial, "installHooks")) impls.Serial.installHooks();
        }
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onconnect(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SerialImpl, "get_onconnect")) return try SerialImpl.get_onconnect(instance);
        return event_handlers.value(EventHandler, instance, "onconnect");
    }

    pub fn set_onconnect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SerialImpl, "set_onconnect")) return try SerialImpl.set_onconnect(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onconnect", value);
    }

    pub fn get_ondisconnect(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SerialImpl, "get_ondisconnect")) return try SerialImpl.get_ondisconnect(instance);
        return event_handlers.value(EventHandler, instance, "ondisconnect");
    }

    pub fn set_ondisconnect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SerialImpl, "set_ondisconnect")) return try SerialImpl.set_ondisconnect(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ondisconnect", value);
    }

    pub fn call_getPorts(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try SerialImpl.call_getPorts(instance);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_requestPort(instance: *runtime.Instance, options: webidl.Opt(SerialPortRequestOptions)) anyerror!runtime.JSValue {
        return try SerialImpl.call_requestPort(instance, options);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{ "set_onconnect", "set_ondisconnect" };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_getPorts",
        "call_requestPort",
    };
};
