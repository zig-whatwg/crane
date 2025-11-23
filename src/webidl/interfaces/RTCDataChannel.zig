//! Generated from: webrtc.idl
//! Generated at: 2025-11-23T01:22:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const RTCDataChannelImpl = @import("impls").RTCDataChannel;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Blob = @import("interfaces").Blob;
const RTCDataChannelState = @import("enums").RTCDataChannelState;
const ArrayBufferView = @import("typedefs").ArrayBufferView;
const BinaryType = @import("enums").BinaryType;
const USVString = @import("interfaces").USVString;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const RTCPriorityType = @import("enums").RTCPriorityType;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const RTCDataChannel = struct {
    pub const Meta = struct {
        pub const name = "RTCDataChannel";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
            .{ .name = "Transferable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "label", "get_label", null },
            .{ "ordered", "get_ordered", null },
            .{ "maxPacketLifeTime", "get_maxPacketLifeTime", null },
            .{ "maxRetransmits", "get_maxRetransmits", null },
            .{ "protocol", "get_protocol", null },
            .{ "negotiated", "get_negotiated", null },
            .{ "id", "get_id", null },
            .{ "readyState", "get_readyState", null },
            .{ "bufferedAmount", "get_bufferedAmount", null },
            .{ "bufferedAmountLowThreshold", "get_bufferedAmountLowThreshold", "set_bufferedAmountLowThreshold" },
            .{ "onopen", "get_onopen", "set_onopen" },
            .{ "onbufferedamountlow", "get_onbufferedamountlow", "set_onbufferedamountlow" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onclosing", "get_onclosing", "set_onclosing" },
            .{ "onclose", "get_onclose", "set_onclose" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "binaryType", "get_binaryType", "set_binaryType" },
            .{ "priority", "get_priority", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "close", "call_close", 0 },
            .{ "send", "call_send", 1 },
            .{ "send", "call_send", 1 },
            .{ "send", "call_send", 1 },
            .{ "send", "call_send", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "close",
            "send",
            "send",
            "send",
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
            .{ "label", "get_label", null },
            .{ "ordered", "get_ordered", null },
            .{ "maxPacketLifeTime", "get_maxPacketLifeTime", null },
            .{ "maxRetransmits", "get_maxRetransmits", null },
            .{ "protocol", "get_protocol", null },
            .{ "negotiated", "get_negotiated", null },
            .{ "id", "get_id", null },
            .{ "readyState", "get_readyState", null },
            .{ "bufferedAmount", "get_bufferedAmount", null },
            .{ "bufferedAmountLowThreshold", "get_bufferedAmountLowThreshold", "set_bufferedAmountLowThreshold" },
            .{ "onopen", "get_onopen", "set_onopen" },
            .{ "onbufferedamountlow", "get_onbufferedamountlow", "set_onbufferedamountlow" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onclosing", "get_onclosing", "set_onclosing" },
            .{ "onclose", "get_onclose", "set_onclose" },
            .{ "onmessage", "get_onmessage", "set_onmessage" },
            .{ "binaryType", "get_binaryType", "set_binaryType" },
            .{ "priority", "get_priority", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
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
    );

    const delegates = .{

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

        .call_close = &call_close,
        .call_send = &call_send,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RTCDataChannelImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCDataChannelImpl.deinit(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try RTCDataChannelImpl.get_label(instance);
    }

    pub fn get_ordered(instance: *runtime.Instance) anyerror!bool {
        return try RTCDataChannelImpl.get_ordered(instance);
    }

    pub fn get_maxPacketLifeTime(instance: *runtime.Instance) anyerror!u16 {
        return try RTCDataChannelImpl.get_maxPacketLifeTime(instance);
    }

    pub fn get_maxRetransmits(instance: *runtime.Instance) anyerror!u16 {
        return try RTCDataChannelImpl.get_maxRetransmits(instance);
    }

    pub fn get_protocol(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try RTCDataChannelImpl.get_protocol(instance);
    }

    pub fn get_negotiated(instance: *runtime.Instance) anyerror!bool {
        return try RTCDataChannelImpl.get_negotiated(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!u16 {
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

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try RTCDataChannelImpl.call_close(instance);
    }

    pub fn call_send(instance: *runtime.Instance, data: runtime.USVString) anyerror!void {
        
        return try RTCDataChannelImpl.call_send(instance, data);
    }

};
