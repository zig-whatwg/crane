//! Generated from: websockets.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebSocketImpl = @import("impls").WebSocket;
const EventTarget = @import("interfaces").EventTarget;
const (BufferSource or Blob or USVString) = @import("interfaces").(BufferSource or Blob or USVString);
const (DOMString or sequence) = @import("interfaces").(DOMString or sequence);
const EventHandler = @import("typedefs").EventHandler;
const BinaryType = @import("enums").BinaryType;

pub const WebSocket = struct {
    pub const Meta = struct {
        pub const name = "WebSocket";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            url: runtime.USVString = undefined,
            readyState: u16 = undefined,
            bufferedAmount: u64 = undefined,
            onopen: EventHandler = undefined,
            onerror: EventHandler = undefined,
            onclose: EventHandler = undefined,
            extensions: runtime.DOMString = undefined,
            protocol: runtime.DOMString = undefined,
            onmessage: EventHandler = undefined,
            binaryType: BinaryType = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
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

    pub const vtable = runtime.buildVTable(WebSocket, .{
        .deinit_fn = &deinit_wrapper,

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

        .call_addEventListener = &call_addEventListener,
        .call_close = &call_close,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_send = &call_send,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        WebSocketImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WebSocketImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, url: runtime.USVString, protocols: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try WebSocketImpl.constructor(instance, url, protocols);
        
        return instance;
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

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try WebSocketImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_send(instance: *runtime.Instance, data: anyopaque) anyerror!void {
        
        return try WebSocketImpl.call_send(instance, data);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try WebSocketImpl.call_when(instance, type_, options);
    }

    pub fn call_close(instance: *runtime.Instance, code: u16, reason: runtime.USVString) anyerror!void {
        // [Clamp] on code
        const clamped_code = runtime.clamp(code);
        
        return try WebSocketImpl.call_close(instance, clamped_code, reason);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try WebSocketImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try WebSocketImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
