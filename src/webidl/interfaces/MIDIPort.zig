//! Generated from: webmidi.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MIDIPortImpl = @import("impls").MIDIPort;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const MIDIPortType = @import("enums").MIDIPortType;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const MIDIPortConnectionState = @import("enums").MIDIPortConnectionState;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const MIDIPortDeviceState = @import("enums").MIDIPortDeviceState;

pub const MIDIPort = struct {
    pub const Meta = struct {
        pub const name = "MIDIPort";
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
            .{ "id", "get_id", null },
            .{ "manufacturer", "get_manufacturer", null },
            .{ "name", "get_name", null },
            .{ "type", "get_type", null },
            .{ "version", "get_version", null },
            .{ "state", "get_state", null },
            .{ "connection", "get_connection", null },
            .{ "onstatechange", "get_onstatechange", "set_onstatechange" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "open", "call_open", 0 },
            .{ "close", "call_close", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "open",
            "close",
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
            .{ "id", "get_id", null },
            .{ "manufacturer", "get_manufacturer", null },
            .{ "name", "get_name", null },
            .{ "type", "get_type", null },
            .{ "version", "get_version", null },
            .{ "state", "get_state", null },
            .{ "connection", "get_connection", null },
            .{ "onstatechange", "get_onstatechange", "set_onstatechange" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            id: runtime.DOMString = undefined,
            manufacturer: ?runtime.DOMString = null,
            name: ?runtime.DOMString = null,
            type: enums.MIDIPortType = undefined,
            version: ?runtime.DOMString = null,
            state: enums.MIDIPortDeviceState = undefined,
            connection: enums.MIDIPortConnectionState = undefined,
            onstatechange: typedefs.EventHandler = undefined,
            _internal: ?*MIDIPortImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_connection = &get_connection,
        .get_id = &get_id,
        .get_manufacturer = &get_manufacturer,
        .get_name = &get_name,
        .get_onstatechange = &get_onstatechange,
        .get_state = &get_state,
        .get_type = &get_type,
        .get_version = &get_version,

        .set_onstatechange = &set_onstatechange,

        .call_close = &call_close,
        .call_open = &call_open,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("MIDIPort has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(MIDIPortImpl, "init") and @hasDecl(MIDIPortImpl, "initOwn")) @compileError("MIDIPortImpl defines both init and initOwn");
        if (comptime @hasDecl(MIDIPortImpl, "init")) return MIDIPortImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(MIDIPortImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try MIDIPortImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(MIDIPortImpl, "init")) return false;
        if (comptime @hasDecl(MIDIPortImpl, "construction_args")) {
            inline for (MIDIPortImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(MIDIPortImpl, "deinit") and @hasDecl(MIDIPortImpl, "deinitOwn")) @compileError("MIDIPortImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(MIDIPortImpl, "deinit")) return MIDIPortImpl.deinit(instance);
        if (comptime @hasDecl(MIDIPortImpl, "deinitOwn")) MIDIPortImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "MIDIPort")) {
            if (comptime @hasDecl(impls.MIDIPort, "installHooks")) impls.MIDIPort.installHooks();
        }
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try MIDIPortImpl.get_id(instance);
    }

    pub fn get_manufacturer(instance: *runtime.Instance) anyerror!?runtime.DOMString {
        return try MIDIPortImpl.get_manufacturer(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!?runtime.DOMString {
        return try MIDIPortImpl.get_name(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!MIDIPortType {
        return try MIDIPortImpl.get_type(instance);
    }

    pub fn get_version(instance: *runtime.Instance) anyerror!?runtime.DOMString {
        return try MIDIPortImpl.get_version(instance);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!MIDIPortDeviceState {
        return try MIDIPortImpl.get_state(instance);
    }

    pub fn get_connection(instance: *runtime.Instance) anyerror!MIDIPortConnectionState {
        return try MIDIPortImpl.get_connection(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onstatechange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(MIDIPortImpl, "get_onstatechange")) return try MIDIPortImpl.get_onstatechange(instance);
        return event_handlers.value(EventHandler, instance, "onstatechange");
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(MIDIPortImpl, "set_onstatechange")) return try MIDIPortImpl.set_onstatechange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onstatechange", value);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try MIDIPortImpl.call_close(instance);
    }

    pub fn call_open(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try MIDIPortImpl.call_open(instance);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{"set_onstatechange"};

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_close",
        "call_open",
    };
};
