//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MessagePortImpl = @import("impls").MessagePort;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const MessageEventTarget = @import("mixins").MessageEventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const StructuredSerializeOptions = @import("dictionaries").StructuredSerializeOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const MessagePort = struct {
    pub const Meta = struct {
        pub const name = "MessagePort";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{
            MessageEventTarget,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker", "AudioWorklet" } } },
            .{ .name = "Transferable" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
            .AudioWorklet = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "onclose", "get_onclose", "set_onclose" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "onmessageerror", "get_onmessageerror", "set_onmessageerror" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "postMessage", "call_postMessage", 1 },
            .{ "start", "call_start", 0 },
            .{ "close", "call_close", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "postMessage",
            "start",
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
            .{ "onclose", "get_onclose", "set_onclose" },
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
            onclose: typedefs.EventHandler = undefined,
            onmessage: typedefs.EventHandler = undefined,
            onmessageerror: typedefs.EventHandler = undefined,
            _internal: ?*MessagePortImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_onclose = &get_onclose,
        .get_onmessage = &get_onmessage,
        .get_onmessageerror = &get_onmessageerror,

        .set_onclose = &set_onclose,
        .set_onmessage = &set_onmessage,
        .set_onmessageerror = &set_onmessageerror,

        .call_close = &call_close,
        .call_postMessage = &call_postMessage,
        .call_start = &call_start,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("MessagePort has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(MessagePortImpl, "init") and @hasDecl(MessagePortImpl, "initOwn")) @compileError("MessagePortImpl defines both init and initOwn");
        if (comptime @hasDecl(MessagePortImpl, "init")) return MessagePortImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(MessagePortImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try MessagePortImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(MessagePortImpl, "init")) return false;
        if (comptime @hasDecl(MessagePortImpl, "construction_args")) {
            inline for (MessagePortImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(MessagePortImpl, "deinit") and @hasDecl(MessagePortImpl, "deinitOwn")) @compileError("MessagePortImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(MessagePortImpl, "deinit")) return MessagePortImpl.deinit(instance);
        if (comptime @hasDecl(MessagePortImpl, "deinitOwn")) MessagePortImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "MessagePort")) {
            if (comptime @hasDecl(impls.MessagePort, "installHooks")) impls.MessagePort.installHooks();
        }
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onclose(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(MessagePortImpl, "get_onclose")) return try MessagePortImpl.get_onclose(instance);
        return event_handlers.value(EventHandler, instance, "onclose");
    }

    pub fn set_onclose(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(MessagePortImpl, "set_onclose")) return try MessagePortImpl.set_onclose(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onclose", value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(MessagePortImpl, "get_onmessage")) return try MessagePortImpl.get_onmessage(instance);
        return event_handlers.value(EventHandler, instance, "onmessage");
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(MessagePortImpl, "set_onmessage")) return try MessagePortImpl.set_onmessage(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onmessage", value);
    }

    pub fn get_onmessageerror(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(MessagePortImpl, "get_onmessageerror")) return try MessagePortImpl.get_onmessageerror(instance);
        return event_handlers.value(EventHandler, instance, "onmessageerror");
    }

    pub fn set_onmessageerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(MessagePortImpl, "set_onmessageerror")) return try MessagePortImpl.set_onmessageerror(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onmessageerror", value);
    }

    pub fn call_postMessage(instance: *runtime.Instance, message: runtime.JSValue, transfer: runtime.JSValue) anyerror!void {
        return try MessagePortImpl.call_postMessage(instance, message, transfer);
    }

    pub fn call_start(instance: *runtime.Instance) anyerror!void {
        return try MessagePortImpl.call_start(instance);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try MessagePortImpl.call_close(instance);
    }

    pub fn call_postMessage__1(instance: *runtime.Instance, message: runtime.JSValue, options: webidl.Opt(StructuredSerializeOptions)) anyerror!void {
        if (comptime @hasDecl(MessagePortImpl, "call_postMessage__1")) {
            return try MessagePortImpl.call_postMessage__1(instance, message, options);
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
            .{ .function = "call_postMessage__1", .implemented = @hasDecl(MessagePortImpl, "call_postMessage__1"), .args = &.{ .{ .kinds = &.{.any} }, .{ .kinds = &.{.dictionary}, .optionality = .optional } } },
        } },
    };
};
