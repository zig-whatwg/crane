//! Generated from: webmidi.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MIDIAccessImpl = @import("impls").MIDIAccess;
const EventTarget = @import("interfaces").EventTarget;
const MIDIInputMap = @import("interfaces").MIDIInputMap;
const EventHandler = @import("typedefs").EventHandler;
const MIDIOutputMap = @import("interfaces").MIDIOutputMap;

pub const MIDIAccess = struct {
    pub const Meta = struct {
        pub const name = "MIDIAccess";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Transferable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            inputs: MIDIInputMap = undefined,
            outputs: MIDIOutputMap = undefined,
            onstatechange: EventHandler = undefined,
            sysexEnabled: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MIDIAccess, .{
        .deinit_fn = &deinit_wrapper,

        .get_inputs = &get_inputs,
        .get_onstatechange = &get_onstatechange,
        .get_outputs = &get_outputs,
        .get_sysexEnabled = &get_sysexEnabled,

        .set_onstatechange = &set_onstatechange,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
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
        MIDIAccessImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MIDIAccessImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_inputs(instance: *runtime.Instance) anyerror!MIDIInputMap {
        return try MIDIAccessImpl.get_inputs(instance);
    }

    pub fn get_outputs(instance: *runtime.Instance) anyerror!MIDIOutputMap {
        return try MIDIAccessImpl.get_outputs(instance);
    }

    pub fn get_onstatechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try MIDIAccessImpl.get_onstatechange(instance);
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MIDIAccessImpl.set_onstatechange(instance, value);
    }

    pub fn get_sysexEnabled(instance: *runtime.Instance) anyerror!bool {
        return try MIDIAccessImpl.get_sysexEnabled(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try MIDIAccessImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try MIDIAccessImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try MIDIAccessImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try MIDIAccessImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
