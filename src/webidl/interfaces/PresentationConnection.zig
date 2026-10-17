//! Generated from: presentation-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const PresentationConnectionImpl = @import("impls").PresentationConnection;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const PresentationConnectionState = @import("enums").PresentationConnectionState;
const Blob = @import("interfaces").Blob;
const ArrayBufferView = @import("typedefs").ArrayBufferView;
const USVString = @import("typedefs").USVString;
const BinaryType = @import("enums").BinaryType;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const PresentationConnection = struct {
    pub const Meta = struct {
        pub const name = "PresentationConnection";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "id", "get_id", null },
            .{ "url", "get_url", null },
            .{ "state", "get_state", null },
            .{ "onconnect", "get_onconnect", "set_onconnect" },
            .{ "onclose", "get_onclose", "set_onclose" },
            .{ "onterminate", "get_onterminate", "set_onterminate" },
            .{ "binaryType", "get_binaryType", "set_binaryType" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "close", "call_close", 0 },
            .{ "terminate", "call_terminate", 0 },
            .{ "send", "call_send", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "close",
            "terminate",
            "send",
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
            .{ "url", "get_url", null },
            .{ "state", "get_state", null },
            .{ "onconnect", "get_onconnect", "set_onconnect" },
            .{ "onclose", "get_onclose", "set_onclose" },
            .{ "onterminate", "get_onterminate", "set_onterminate" },
            .{ "binaryType", "get_binaryType", "set_binaryType" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            id: runtime.USVString = undefined,
            url: runtime.USVString = undefined,
            state: enums.PresentationConnectionState = undefined,
            onconnect: typedefs.EventHandler = undefined,
            onclose: typedefs.EventHandler = undefined,
            onterminate: typedefs.EventHandler = undefined,
            binaryType: enums.BinaryType = undefined,
            onmessage: typedefs.EventHandler = undefined,
            _internal: ?*PresentationConnectionImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_binaryType = &get_binaryType,
        .get_id = &get_id,
        .get_onclose = &get_onclose,
        .get_onconnect = &get_onconnect,
        .get_onmessage = &get_onmessage,
        .get_onterminate = &get_onterminate,
        .get_state = &get_state,
        .get_url = &get_url,

        .set_binaryType = &set_binaryType,
        .set_onclose = &set_onclose,
        .set_onconnect = &set_onconnect,
        .set_onmessage = &set_onmessage,
        .set_onterminate = &set_onterminate,

        .call_close = &call_close,
        .call_send = &call_send,
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
            if (comptime !takesConstructionArg(field.name)) @compileError("PresentationConnection has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(PresentationConnectionImpl, "init") and @hasDecl(PresentationConnectionImpl, "initOwn")) @compileError("PresentationConnectionImpl defines both init and initOwn");
        if (comptime @hasDecl(PresentationConnectionImpl, "init")) return PresentationConnectionImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(PresentationConnectionImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try PresentationConnectionImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(PresentationConnectionImpl, "init")) return false;
        if (comptime @hasDecl(PresentationConnectionImpl, "construction_args")) {
            inline for (PresentationConnectionImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(PresentationConnectionImpl, "deinit") and @hasDecl(PresentationConnectionImpl, "deinitOwn")) @compileError("PresentationConnectionImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(PresentationConnectionImpl, "deinit")) return PresentationConnectionImpl.deinit(instance);
        if (comptime @hasDecl(PresentationConnectionImpl, "deinitOwn")) PresentationConnectionImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "PresentationConnection")) {
            if (comptime @hasDecl(impls.PresentationConnection, "installHooks")) impls.PresentationConnection.installHooks();
        }
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PresentationConnectionImpl.get_id(instance);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try PresentationConnectionImpl.get_url(instance);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!PresentationConnectionState {
        return try PresentationConnectionImpl.get_state(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onconnect(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(PresentationConnectionImpl, "get_onconnect")) return try PresentationConnectionImpl.get_onconnect(instance);
        return event_handlers.value(EventHandler, instance, "onconnect");
    }

    pub fn set_onconnect(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(PresentationConnectionImpl, "set_onconnect")) return try PresentationConnectionImpl.set_onconnect(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onconnect", value);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(PresentationConnectionImpl, "get_onclose")) return try PresentationConnectionImpl.get_onclose(instance);
        return event_handlers.value(EventHandler, instance, "onclose");
    }

    pub fn set_onclose(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(PresentationConnectionImpl, "set_onclose")) return try PresentationConnectionImpl.set_onclose(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onclose", value);
    }

    pub fn get_onterminate(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(PresentationConnectionImpl, "get_onterminate")) return try PresentationConnectionImpl.get_onterminate(instance);
        return event_handlers.value(EventHandler, instance, "onterminate");
    }

    pub fn set_onterminate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(PresentationConnectionImpl, "set_onterminate")) return try PresentationConnectionImpl.set_onterminate(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onterminate", value);
    }

    pub fn get_binaryType(instance: *runtime.Instance) anyerror!BinaryType {
        return try PresentationConnectionImpl.get_binaryType(instance);
    }

    pub fn set_binaryType(instance: *runtime.Instance, value: BinaryType) anyerror!void {
        try PresentationConnectionImpl.set_binaryType(instance, value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(PresentationConnectionImpl, "get_onmessage")) return try PresentationConnectionImpl.get_onmessage(instance);
        return event_handlers.value(EventHandler, instance, "onmessage");
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(PresentationConnectionImpl, "set_onmessage")) return try PresentationConnectionImpl.set_onmessage(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onmessage", value);
    }

    pub fn call_send(instance: *runtime.Instance, message: runtime.DOMString) anyerror!void {
        return try PresentationConnectionImpl.call_send(instance, message);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try PresentationConnectionImpl.call_close(instance);
    }

    pub fn call_terminate(instance: *runtime.Instance) anyerror!void {
        return try PresentationConnectionImpl.call_terminate(instance);
    }

    pub fn call_send__1(instance: *runtime.Instance, data: *runtime.Instance) anyerror!void {
        if (comptime @hasDecl(PresentationConnectionImpl, "call_send__1")) {
            return try PresentationConnectionImpl.call_send__1(instance, data);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_send__2(instance: *runtime.Instance, data: runtime.JSValue) anyerror!void {
        if (comptime @hasDecl(PresentationConnectionImpl, "call_send__2")) {
            return try PresentationConnectionImpl.call_send__2(instance, data);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_send__3(instance: *runtime.Instance, data: ArrayBufferView) anyerror!void {
        if (comptime @hasDecl(PresentationConnectionImpl, "call_send__3")) {
            return try PresentationConnectionImpl.call_send__3(instance, data);
        } else {
            return error.NotImplemented;
        }
    }

    /// WebIDL overload sets: every overload of each overloaded operation,
    /// in IDL order, for the overload resolution algorithm
    /// (webidl.overload_resolution). The binding is installed for the first
    /// overload and forwards to the one the arguments select.
    pub const overloads = .{
        .{ "send", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_send", .args = &.{.{ .kinds = &.{.string} }} },
            .{ .function = "call_send__1", .implemented = @hasDecl(PresentationConnectionImpl, "call_send__1"), .args = &.{.{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "Blob")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").Blob.State) } else .other)} }} },
            .{ .function = "call_send__2", .implemented = @hasDecl(PresentationConnectionImpl, "call_send__2"), .args = &.{.{ .kinds = &.{.array_buffer} }} },
            .{ .function = "call_send__3", .implemented = @hasDecl(PresentationConnectionImpl, "call_send__3"), .args = &.{.{ .kinds = &.{ .{ .typed_array = "Int8Array" }, .{ .typed_array = "Int16Array" }, .{ .typed_array = "Int32Array" }, .{ .typed_array = "Uint8Array" }, .{ .typed_array = "Uint16Array" }, .{ .typed_array = "Uint32Array" }, .{ .typed_array = "Uint8ClampedArray" }, .{ .typed_array = "BigInt64Array" }, .{ .typed_array = "BigUint64Array" }, .{ .typed_array = "Float16Array" }, .{ .typed_array = "Float32Array" }, .{ .typed_array = "Float64Array" }, .data_view } }} },
        } },
    };
};
