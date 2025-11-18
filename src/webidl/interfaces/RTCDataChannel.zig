//! Generated from: webrtc.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCDataChannelImpl = @import("impls").RTCDataChannel;
const EventTarget = @import("interfaces").EventTarget;
const ArrayBuffer = @import("interfaces").ArrayBuffer;
const unsigned short = @import("interfaces").unsigned short;
const Blob = @import("interfaces").Blob;
const RTCPriorityType = @import("enums").RTCPriorityType;
const RTCDataChannelState = @import("enums").RTCDataChannelState;
const ArrayBufferView = @import("typedefs").ArrayBufferView;
const BinaryType = @import("enums").BinaryType;
const EventHandler = @import("typedefs").EventHandler;

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
        RTCDataChannelImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCDataChannelImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try RTCDataChannelImpl.get_label(instance);
    }

    pub fn get_ordered(instance: *runtime.Instance) anyerror!bool {
        return try RTCDataChannelImpl.get_ordered(instance);
    }

    pub fn get_maxPacketLifeTime(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCDataChannelImpl.get_maxPacketLifeTime(instance);
    }

    pub fn get_maxRetransmits(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCDataChannelImpl.get_maxRetransmits(instance);
    }

    pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try RTCDataChannelImpl.get_protocol(instance);
    }

    pub fn get_negotiated(instance: *runtime.Instance) anyerror!bool {
        return try RTCDataChannelImpl.get_negotiated(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!anyopaque {
        return try RTCDataChannelImpl.get_id(instance);
    }

    pub fn get_readyState(instance: *runtime.Instance) anyerror!RTCDataChannelState {
        return try RTCDataChannelImpl.get_readyState(instance);
    }

    pub fn get_bufferedAmount(instance: *runtime.Instance) anyerror!u32 {
        return try RTCDataChannelImpl.get_bufferedAmount(instance);
    }

    /// Extended attributes: [EnforceRange]
    pub fn get_bufferedAmountLowThreshold(instance: *runtime.Instance) anyerror!u32 {
        return try RTCDataChannelImpl.get_bufferedAmountLowThreshold(instance);
    }

    /// Extended attributes: [EnforceRange]
    pub fn set_bufferedAmountLowThreshold(instance: *runtime.Instance, value: u32) anyerror!void {
        try RTCDataChannelImpl.set_bufferedAmountLowThreshold(instance, value);
    }

    pub fn get_onopen(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCDataChannelImpl.get_onopen(instance);
    }

    pub fn set_onopen(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCDataChannelImpl.set_onopen(instance, value);
    }

    pub fn get_onbufferedamountlow(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCDataChannelImpl.get_onbufferedamountlow(instance);
    }

    pub fn set_onbufferedamountlow(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCDataChannelImpl.set_onbufferedamountlow(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCDataChannelImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCDataChannelImpl.set_onerror(instance, value);
    }

    pub fn get_onclosing(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCDataChannelImpl.get_onclosing(instance);
    }

    pub fn set_onclosing(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCDataChannelImpl.set_onclosing(instance, value);
    }

    pub fn get_onclose(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCDataChannelImpl.get_onclose(instance);
    }

    pub fn set_onclose(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCDataChannelImpl.set_onclose(instance, value);
    }

    pub fn get_onmessage(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCDataChannelImpl.get_onmessage(instance);
    }

    pub fn set_onmessage(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCDataChannelImpl.set_onmessage(instance, value);
    }

    pub fn get_binaryType(instance: *runtime.Instance) anyerror!BinaryType {
        return try RTCDataChannelImpl.get_binaryType(instance);
    }

    pub fn set_binaryType(instance: *runtime.Instance, value: BinaryType) anyerror!void {
        try RTCDataChannelImpl.set_binaryType(instance, value);
    }

    pub fn get_priority(instance: *runtime.Instance) anyerror!RTCPriorityType {
        return try RTCDataChannelImpl.get_priority(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try RTCDataChannelImpl.call_when(instance, type_, options);
    }

    /// Arguments for send (WebIDL overloading)
    pub const SendArgs = union(enum) {
        /// send(data)
        USVString: runtime.USVString,
        /// send(data)
        Blob: Blob,
        /// send(data)
        ArrayBuffer: anyopaque,
        /// send(data)
        ArrayBufferView: ArrayBufferView,
    };

    pub fn call_send(instance: *runtime.Instance, args: SendArgs) anyerror!void {
        switch (args) {
            .USVString => |arg| return try RTCDataChannelImpl.USVString(instance, arg),
            .Blob => |arg| return try RTCDataChannelImpl.Blob(instance, arg),
            .ArrayBuffer => |arg| return try RTCDataChannelImpl.ArrayBuffer(instance, arg),
            .ArrayBufferView => |arg| return try RTCDataChannelImpl.ArrayBufferView(instance, arg),
        }
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try RTCDataChannelImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try RTCDataChannelImpl.call_close(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try RTCDataChannelImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try RTCDataChannelImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
