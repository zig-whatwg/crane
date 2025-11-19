//! Generated from: webmidi.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MIDIOutputImpl = @import("impls").MIDIOutput;
const MIDIPort = @import("interfaces").MIDIPort;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const EventHandler = @import("typedefs").EventHandler;
const MIDIPortType = @import("enums").MIDIPortType;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const Event = @import("interfaces").Event;
const Observable = @import("interfaces").Observable;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const MIDIPortConnectionState = @import("enums").MIDIPortConnectionState;
const MIDIPortDeviceState = @import("enums").MIDIPortDeviceState;
const DOMString = @import("typedefs").DOMString;

pub const MIDIOutput = struct {
    pub const Meta = struct {
        pub const name = "MIDIOutput";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *MIDIPort;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MIDIOutput, .{
        .deinit_fn = &deinit_wrapper,

        .get_connection = &get_connection,
        .get_id = &get_id,
        .get_manufacturer = &get_manufacturer,
        .get_name = &get_name,
        .get_onstatechange = &get_onstatechange,
        .get_state = &get_state,
        .get_type = &get_type,
        .get_version = &get_version,

        .set_onstatechange = &set_onstatechange,

        .call_addEventListener = &call_addEventListener,
        .call_clear = &call_clear,
        .call_close = &call_close,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_open = &call_open,
        .call_removeEventListener = &call_removeEventListener,
        .call_send = &call_send,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return MIDIOutputImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MIDIOutputImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try MIDIOutputImpl.get_id(instance);
    }

    pub fn get_manufacturer(instance: *runtime.Instance) anyerror!DOMString {
        return try MIDIOutputImpl.get_manufacturer(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try MIDIOutputImpl.get_name(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!MIDIPortType {
        return try MIDIOutputImpl.get_type(instance);
    }

    pub fn get_version(instance: *runtime.Instance) anyerror!DOMString {
        return try MIDIOutputImpl.get_version(instance);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!MIDIPortDeviceState {
        return try MIDIOutputImpl.get_state(instance);
    }

    pub fn get_connection(instance: *runtime.Instance) anyerror!MIDIPortConnectionState {
        return try MIDIOutputImpl.get_connection(instance);
    }

    pub fn get_onstatechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try MIDIOutputImpl.get_onstatechange(instance);
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MIDIOutputImpl.set_onstatechange(instance, value);
    }

    pub fn call_when(instance: *runtime.Instance, @"type": DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try MIDIOutputImpl.call_when(instance, @"type", options);
    }

    pub fn call_open(instance: *runtime.Instance) anyerror!anyopaque {
        return try MIDIOutputImpl.call_open(instance);
    }

    pub fn call_send(instance: *runtime.Instance, data: anyopaque, timestamp: DOMHighResTimeStamp) anyerror!void {
        
        return try MIDIOutputImpl.call_send(instance, data, timestamp);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try MIDIOutputImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try MIDIOutputImpl.call_clear(instance);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!anyopaque {
        return try MIDIOutputImpl.call_close(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try MIDIOutputImpl.call_addEventListener(instance, @"type", callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try MIDIOutputImpl.call_removeEventListener(instance, @"type", callback, options);
    }

};
