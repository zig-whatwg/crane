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
        pub const lazy_properties = .{
        };
        
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
            extensions: typedefs.DOMString = undefined,
            protocol: typedefs.DOMString = undefined,
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
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WebSocketImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return WebSocketImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WebSocketImpl.deinit(instance);
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

    pub fn get_onopen(instance: *runtime.Instance) anyerror!EventHandler {
        return try WebSocketImpl.get_onopen(instance);
    }

    pub fn set_onopen(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WebSocketImpl.set_onopen(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try WebSocketImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WebSocketImpl.set_onerror(instance, value);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyerror!EventHandler {
        return try WebSocketImpl.get_onclose(instance);
    }

    pub fn set_onclose(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WebSocketImpl.set_onclose(instance, value);
    }

    pub fn get_extensions(instance: *runtime.Instance) anyerror!DOMString {
        return try WebSocketImpl.get_extensions(instance);
    }

    pub fn get_protocol(instance: *runtime.Instance) anyerror!DOMString {
        return try WebSocketImpl.get_protocol(instance);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
        return try WebSocketImpl.get_onmessage(instance);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try WebSocketImpl.set_onmessage(instance, value);
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
        // [Clamp] on code
        const clamped_code = if (code.wasPassed()) webidl.Opt(u16).passed(runtime.clamp(u16, code.value)) else webidl.Opt(u16).notPassed();
        
        return try WebSocketImpl.call_close(instance, clamped_code, reason);
    }

};
