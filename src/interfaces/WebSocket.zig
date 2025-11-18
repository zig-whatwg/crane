//! Generated from: websockets.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebSocketImpl = @import("../impls/WebSocket.zig");
const EventTarget = @import("EventTarget.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        WebSocketImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WebSocketImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, url: runtime.USVString, protocols: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try WebSocketImpl.constructor(state, url, protocols);
        
        return instance;
    }

    pub fn get_url(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return WebSocketImpl.get_url(state);
    }

    pub fn get_readyState(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return WebSocketImpl.get_readyState(state);
    }

    pub fn get_bufferedAmount(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return WebSocketImpl.get_bufferedAmount(state);
    }

    pub fn get_onopen(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebSocketImpl.get_onopen(state);
    }

    pub fn set_onopen(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WebSocketImpl.set_onopen(state, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebSocketImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WebSocketImpl.set_onerror(state, value);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebSocketImpl.get_onclose(state);
    }

    pub fn set_onclose(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WebSocketImpl.set_onclose(state, value);
    }

    pub fn get_extensions(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return WebSocketImpl.get_extensions(state);
    }

    pub fn get_protocol(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return WebSocketImpl.get_protocol(state);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebSocketImpl.get_onmessage(state);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WebSocketImpl.set_onmessage(state, value);
    }

    pub fn get_binaryType(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebSocketImpl.get_binaryType(state);
    }

    pub fn set_binaryType(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WebSocketImpl.set_binaryType(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return WebSocketImpl.call_dispatchEvent(state, event);
    }

    pub fn call_send(instance: *runtime.Instance, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebSocketImpl.call_send(state, data);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebSocketImpl.call_when(state, type_, options);
    }

    pub fn call_close(instance: *runtime.Instance, code: u16, reason: runtime.USVString) anyopaque {
        const state = instance.getState(State);
        // [Clamp] on code
        const clamped_code = runtime.clamp(code);
        
        return WebSocketImpl.call_close(state, clamped_code, reason);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebSocketImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebSocketImpl.call_removeEventListener(state, type_, callback, options);
    }

};
