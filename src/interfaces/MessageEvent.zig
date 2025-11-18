//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MessageEventImpl = @import("../impls/MessageEvent.zig");
const Event = @import("Event.zig");

pub const MessageEvent = struct {
    pub const Meta = struct {
        pub const name = "MessageEvent";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker", "AudioWorklet" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
            .AudioWorklet = true,
        };
        
        /// Properties that cannot be shadowed or deleted (configurable: false)
        pub const legacy_unforgeable_properties = .{
            "isTrusted",
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            data: anyopaque = undefined,
            origin: runtime.USVString = undefined,
            lastEventId: runtime.DOMString = undefined,
            source: ?MessageEventSource = null,
            ports: FrozenArray<MessagePort> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MessageEvent, .{
        .deinit_fn = &deinit_wrapper,

        .get_AT_TARGET = &Event.get_AT_TARGET,
        .get_BUBBLING_PHASE = &Event.get_BUBBLING_PHASE,
        .get_CAPTURING_PHASE = &Event.get_CAPTURING_PHASE,
        .get_NONE = &Event.get_NONE,
        .get_bubbles = &get_bubbles,
        .get_cancelBubble = &get_cancelBubble,
        .get_cancelable = &get_cancelable,
        .get_composed = &get_composed,
        .get_currentTarget = &get_currentTarget,
        .get_data = &get_data,
        .get_defaultPrevented = &get_defaultPrevented,
        .get_eventPhase = &get_eventPhase,
        .get_isTrusted = &get_isTrusted,
        .get_lastEventId = &get_lastEventId,
        .get_origin = &get_origin,
        .get_ports = &get_ports,
        .get_returnValue = &get_returnValue,
        .get_source = &get_source,
        .get_srcElement = &get_srcElement,
        .get_target = &get_target,
        .get_timeStamp = &get_timeStamp,
        .get_type = &get_type,

        .set_cancelBubble = &set_cancelBubble,
        .set_returnValue = &set_returnValue,

        .call_composedPath = &call_composedPath,
        .call_initEvent = &call_initEvent,
        .call_initMessageEvent = &call_initMessageEvent,
        .call_preventDefault = &call_preventDefault,
        .call_stopImmediatePropagation = &call_stopImmediatePropagation,
        .call_stopPropagation = &call_stopPropagation,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        MessageEventImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        MessageEventImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, type_: runtime.DOMString, eventInitDict: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try MessageEventImpl.constructor(state, type_, eventInitDict);
        
        return instance;
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return MessageEventImpl.get_type(state);
    }

    pub fn get_target(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MessageEventImpl.get_target(state);
    }

    pub fn get_srcElement(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MessageEventImpl.get_srcElement(state);
    }

    pub fn get_currentTarget(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MessageEventImpl.get_currentTarget(state);
    }

    pub fn get_eventPhase(instance: *runtime.Instance) u16 {
        const state = instance.getState(State);
        return MessageEventImpl.get_eventPhase(state);
    }

    pub fn get_cancelBubble(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return MessageEventImpl.get_cancelBubble(state);
    }

    pub fn set_cancelBubble(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        MessageEventImpl.set_cancelBubble(state, value);
    }

    pub fn get_bubbles(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return MessageEventImpl.get_bubbles(state);
    }

    pub fn get_cancelable(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return MessageEventImpl.get_cancelable(state);
    }

    pub fn get_returnValue(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return MessageEventImpl.get_returnValue(state);
    }

    pub fn set_returnValue(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        MessageEventImpl.set_returnValue(state, value);
    }

    pub fn get_defaultPrevented(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return MessageEventImpl.get_defaultPrevented(state);
    }

    pub fn get_composed(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return MessageEventImpl.get_composed(state);
    }

    /// Extended attributes: [LegacyUnforgeable]
    pub fn get_isTrusted(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return MessageEventImpl.get_isTrusted(state);
    }

    pub fn get_timeStamp(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MessageEventImpl.get_timeStamp(state);
    }

    pub fn get_data(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MessageEventImpl.get_data(state);
    }

    pub fn get_origin(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return MessageEventImpl.get_origin(state);
    }

    pub fn get_lastEventId(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return MessageEventImpl.get_lastEventId(state);
    }

    pub fn get_source(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MessageEventImpl.get_source(state);
    }

    pub fn get_ports(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MessageEventImpl.get_ports(state);
    }

    pub fn call_stopImmediatePropagation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MessageEventImpl.call_stopImmediatePropagation(state);
    }

    pub fn call_initEvent(instance: *runtime.Instance, type_: runtime.DOMString, bubbles: bool, cancelable: bool) anyopaque {
        const state = instance.getState(State);
        
        return MessageEventImpl.call_initEvent(state, type_, bubbles, cancelable);
    }

    pub fn call_composedPath(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MessageEventImpl.call_composedPath(state);
    }

    pub fn call_stopPropagation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MessageEventImpl.call_stopPropagation(state);
    }

    pub fn call_initMessageEvent(instance: *runtime.Instance, type_: runtime.DOMString, bubbles: bool, cancelable: bool, data: anyopaque, origin: runtime.USVString, lastEventId: runtime.DOMString, source: anyopaque, ports: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MessageEventImpl.call_initMessageEvent(state, type_, bubbles, cancelable, data, origin, lastEventId, source, ports);
    }

    pub fn call_preventDefault(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MessageEventImpl.call_preventDefault(state);
    }

};
