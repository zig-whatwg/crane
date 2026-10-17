//! Generated from: websockets.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WebSocketImpl = @import("impls").WebSocket;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Blob = @import("interfaces").Blob;
const USVString = @import("typedefs").USVString;
const BinaryType = @import("enums").BinaryType;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const BufferSource = @import("typedefs").BufferSource;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const WebSocket = struct {
    pub const Meta = struct {
        pub const name = "WebSocket";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "url", "get_url", null },
            .{ "readyState", "get_readyState", null },
            .{ "bufferedAmount", "get_bufferedAmount", null },
            .{ "onopen", "get_onopen", "set_onopen" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onclose", "get_onclose", "set_onclose" },
            .{ "extensions", "get_extensions", null },
            .{ "protocol", "get_protocol", null },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "binaryType", "get_binaryType", "set_binaryType" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "close", "call_close", 0 },
            .{ "send", "call_send", 1 },
        };

        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "CONNECTING", "get_CONNECTING" },
            .{ "OPEN", "get_OPEN" },
            .{ "CLOSING", "get_CLOSING" },
            .{ "CLOSED", "get_CLOSED" },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "close",
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
            .{ "url", "get_url", null },
            .{ "readyState", "get_readyState", null },
            .{ "bufferedAmount", "get_bufferedAmount", null },
            .{ "onopen", "get_onopen", "set_onopen" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onclose", "get_onclose", "set_onclose" },
            .{ "extensions", "get_extensions", null },
            .{ "protocol", "get_protocol", null },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "binaryType", "get_binaryType", "set_binaryType" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            url: runtime.USVString = undefined,
            readyState: u16 = undefined,
            bufferedAmount: u64 = undefined,
            onopen: typedefs.EventHandler = undefined,
            onerror: typedefs.EventHandler = undefined,
            onclose: typedefs.EventHandler = undefined,
            extensions: runtime.DOMString = undefined,
            protocol: runtime.DOMString = undefined,
            onmessage: typedefs.EventHandler = undefined,
            binaryType: enums.BinaryType = undefined,
            _internal: ?*WebSocketImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short CONNECTING = 0;
    pub fn get_CONNECTING() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short OPEN = 1;
    pub fn get_OPEN() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short CLOSING = 2;
    pub fn get_CLOSING() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short CLOSED = 3;
    pub fn get_CLOSED() u16 {
        return 3;
    }

    const delegates = .{
        .get_CLOSED = &get_CLOSED,
        .get_CLOSING = &get_CLOSING,
        .get_CONNECTING = &get_CONNECTING,
        .get_OPEN = &get_OPEN,
        .get_binaryType = &get_binaryType,
        .get_bufferedAmount = &get_bufferedAmount,
        .get_extensions = &get_extensions,
        .get_onclose = &get_onclose,
        .get_onerror = &get_onerror,
        .get_onmessage = &get_onmessage,
        .get_onopen = &get_onopen,
        .get_protocol = &get_protocol,
        .get_readyState = &get_readyState,
        .get_url = &get_url,

        .set_binaryType = &set_binaryType,
        .set_onclose = &set_onclose,
        .set_onerror = &set_onerror,
        .set_onmessage = &set_onmessage,
        .set_onopen = &set_onopen,

        .call_close = &call_close,
        .call_send = &call_send,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("WebSocket has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(WebSocketImpl, "init") and @hasDecl(WebSocketImpl, "initOwn")) @compileError("WebSocketImpl defines both init and initOwn");
        if (comptime @hasDecl(WebSocketImpl, "init")) return WebSocketImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(WebSocketImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try WebSocketImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(WebSocketImpl, "init")) return false;
        if (comptime @hasDecl(WebSocketImpl, "construction_args")) {
            inline for (WebSocketImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(WebSocketImpl, "deinit") and @hasDecl(WebSocketImpl, "deinitOwn")) @compileError("WebSocketImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(WebSocketImpl, "deinit")) return WebSocketImpl.deinit(instance);
        if (comptime @hasDecl(WebSocketImpl, "deinitOwn")) WebSocketImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "WebSocket")) {
            if (comptime @hasDecl(impls.WebSocket, "installHooks")) impls.WebSocket.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, url: runtime.USVString, protocols: webidl.Opt(runtime.JSValue)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try WebSocketImpl.call_constructor(ctx, url, protocols);
    }

    pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try WebSocketImpl.get_url(instance);
    }

    pub fn get_readyState(instance: *runtime.Instance) anyerror!u16 {
        return try WebSocketImpl.get_readyState(instance);
    }

    pub fn get_bufferedAmount(instance: *runtime.Instance) anyerror!u64 {
        return try WebSocketImpl.get_bufferedAmount(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onopen(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(WebSocketImpl, "get_onopen")) return try WebSocketImpl.get_onopen(instance);
        return event_handlers.value(EventHandler, instance, "onopen");
    }

    pub fn set_onopen(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(WebSocketImpl, "set_onopen")) return try WebSocketImpl.set_onopen(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onopen", value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(WebSocketImpl, "get_onerror")) return try WebSocketImpl.get_onerror(instance);
        return event_handlers.value(EventHandler, instance, "onerror");
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(WebSocketImpl, "set_onerror")) return try WebSocketImpl.set_onerror(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onerror", value);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(WebSocketImpl, "get_onclose")) return try WebSocketImpl.get_onclose(instance);
        return event_handlers.value(EventHandler, instance, "onclose");
    }

    pub fn set_onclose(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(WebSocketImpl, "set_onclose")) return try WebSocketImpl.set_onclose(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onclose", value);
    }

    pub fn get_extensions(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try WebSocketImpl.get_extensions(instance);
    }

    pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try WebSocketImpl.get_protocol(instance);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(WebSocketImpl, "get_onmessage")) return try WebSocketImpl.get_onmessage(instance);
        return event_handlers.value(EventHandler, instance, "onmessage");
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(WebSocketImpl, "set_onmessage")) return try WebSocketImpl.set_onmessage(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onmessage", value);
    }

    pub fn get_binaryType(instance: *runtime.Instance) anyerror!BinaryType {
        return try WebSocketImpl.get_binaryType(instance);
    }

    pub fn set_binaryType(instance: *runtime.Instance, value: BinaryType) anyerror!void {
        try WebSocketImpl.set_binaryType(instance, value);
    }

    pub fn call_send(instance: *runtime.Instance, data: runtime.JSValue) anyerror!void {
        return try WebSocketImpl.call_send(instance, data);
    }

    pub fn call_close(instance: *runtime.Instance, code: webidl.Opt(u16), reason: webidl.Opt(runtime.USVString)) anyerror!void {
        return try WebSocketImpl.call_close(instance, code, reason);
    }

    /// WebIDL [Clamp]: the integer arguments and attribute values
    /// whose conversion takes that branch of ConvertToInt (bit i = argument i;
    /// an attribute setter's value is bit 0).
    pub const clamp = .{
        .{ "call_close", 0b1 },
    };
};
