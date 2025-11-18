//! Generated from: webrtc.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCDataChannelImpl = @import("../impls/RTCDataChannel.zig");
const EventTarget = @import("EventTarget.zig");

pub const RTCDataChannel = struct {
    pub const Meta = struct {
        pub const name = "RTCDataChannel";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
            .{ .name = "Transferable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            label: runtime.USVString = undefined,
            ordered: bool = undefined,
            maxPacketLifeTime: ?u16 = null,
            maxRetransmits: ?u16 = null,
            protocol: runtime.USVString = undefined,
            negotiated: bool = undefined,
            id: ?u16 = null,
            readyState: RTCDataChannelState = undefined,
            bufferedAmount: u32 = undefined,
            bufferedAmountLowThreshold: u32 = undefined,
            onopen: EventHandler = undefined,
            onbufferedamountlow: EventHandler = undefined,
            onerror: EventHandler = undefined,
            onclosing: EventHandler = undefined,
            onclose: EventHandler = undefined,
            onmessage: EventHandler = undefined,
            binaryType: BinaryType = undefined,
            priority: RTCPriorityType = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(RTCDataChannel, .{
        .deinit_fn = &deinit_wrapper,

        .get_binaryType = &get_binaryType,
        .get_bufferedAmount = &get_bufferedAmount,
        .get_bufferedAmountLowThreshold = &get_bufferedAmountLowThreshold,
        .get_id = &get_id,
        .get_label = &get_label,
        .get_maxPacketLifeTime = &get_maxPacketLifeTime,
        .get_maxRetransmits = &get_maxRetransmits,
        .get_negotiated = &get_negotiated,
        .get_onbufferedamountlow = &get_onbufferedamountlow,
        .get_onclose = &get_onclose,
        .get_onclosing = &get_onclosing,
        .get_onerror = &get_onerror,
        .get_onmessage = &get_onmessage,
        .get_onopen = &get_onopen,
        .get_ordered = &get_ordered,
        .get_priority = &get_priority,
        .get_protocol = &get_protocol,
        .get_readyState = &get_readyState,

        .set_binaryType = &set_binaryType,
        .set_bufferedAmountLowThreshold = &set_bufferedAmountLowThreshold,
        .set_onbufferedamountlow = &set_onbufferedamountlow,
        .set_onclose = &set_onclose,
        .set_onclosing = &set_onclosing,
        .set_onerror = &set_onerror,
        .set_onmessage = &set_onmessage,
        .set_onopen = &set_onopen,

        .call_addEventListener = &call_addEventListener,
        .call_close = &call_close,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_send = &call_send,
        .call_send = &call_send,
        .call_send = &call_send,
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
        RTCDataChannelImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        RTCDataChannelImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_label(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return RTCDataChannelImpl.get_label(state);
    }

    pub fn get_ordered(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return RTCDataChannelImpl.get_ordered(state);
    }

    pub fn get_maxPacketLifeTime(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCDataChannelImpl.get_maxPacketLifeTime(state);
    }

    pub fn get_maxRetransmits(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCDataChannelImpl.get_maxRetransmits(state);
    }

    pub fn get_protocol(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return RTCDataChannelImpl.get_protocol(state);
    }

    pub fn get_negotiated(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return RTCDataChannelImpl.get_negotiated(state);
    }

    pub fn get_id(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCDataChannelImpl.get_id(state);
    }

    pub fn get_readyState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCDataChannelImpl.get_readyState(state);
    }

    pub fn get_bufferedAmount(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return RTCDataChannelImpl.get_bufferedAmount(state);
    }

    /// Extended attributes: [EnforceRange]
    pub fn get_bufferedAmountLowThreshold(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return RTCDataChannelImpl.get_bufferedAmountLowThreshold(state);
    }

    /// Extended attributes: [EnforceRange]
    pub fn set_bufferedAmountLowThreshold(instance: *runtime.Instance, value: u32) void {
        const state = instance.getState(State);
        RTCDataChannelImpl.set_bufferedAmountLowThreshold(state, value);
    }

    pub fn get_onopen(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCDataChannelImpl.get_onopen(state);
    }

    pub fn set_onopen(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCDataChannelImpl.set_onopen(state, value);
    }

    pub fn get_onbufferedamountlow(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCDataChannelImpl.get_onbufferedamountlow(state);
    }

    pub fn set_onbufferedamountlow(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCDataChannelImpl.set_onbufferedamountlow(state, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCDataChannelImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCDataChannelImpl.set_onerror(state, value);
    }

    pub fn get_onclosing(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCDataChannelImpl.get_onclosing(state);
    }

    pub fn set_onclosing(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCDataChannelImpl.set_onclosing(state, value);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCDataChannelImpl.get_onclose(state);
    }

    pub fn set_onclose(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCDataChannelImpl.set_onclose(state, value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCDataChannelImpl.get_onmessage(state);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCDataChannelImpl.set_onmessage(state, value);
    }

    pub fn get_binaryType(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCDataChannelImpl.get_binaryType(state);
    }

    pub fn set_binaryType(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        RTCDataChannelImpl.set_binaryType(state, value);
    }

    pub fn get_priority(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCDataChannelImpl.get_priority(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCDataChannelImpl.call_when(state, type_, options);
    }

    /// Arguments for send (WebIDL overloading)
    pub const SendArgs = union(enum) {
        /// send(data)
        USVString: runtime.USVString,
        /// send(data)
        Blob: anyopaque,
        /// send(data)
        ArrayBuffer: anyopaque,
        /// send(data)
        ArrayBufferView: anyopaque,
    };

    pub fn call_send(instance: *runtime.Instance, args: SendArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .USVString => |arg| return RTCDataChannelImpl.USVString(state, arg),
            .Blob => |arg| return RTCDataChannelImpl.Blob(state, arg),
            .ArrayBuffer => |arg| return RTCDataChannelImpl.ArrayBuffer(state, arg),
            .ArrayBufferView => |arg| return RTCDataChannelImpl.ArrayBufferView(state, arg),
        }
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return RTCDataChannelImpl.call_dispatchEvent(state, event);
    }

    pub fn call_close(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return RTCDataChannelImpl.call_close(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCDataChannelImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return RTCDataChannelImpl.call_removeEventListener(state, type_, callback, options);
    }

};
