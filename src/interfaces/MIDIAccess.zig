//! Generated from: webmidi.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MIDIAccessImpl = @import("../impls/MIDIAccess.zig");
const EventTarget = @import("EventTarget.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        MIDIAccessImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        MIDIAccessImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_inputs(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MIDIAccessImpl.get_inputs(state);
    }

    pub fn get_outputs(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MIDIAccessImpl.get_outputs(state);
    }

    pub fn get_onstatechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MIDIAccessImpl.get_onstatechange(state);
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        MIDIAccessImpl.set_onstatechange(state, value);
    }

    pub fn get_sysexEnabled(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return MIDIAccessImpl.get_sysexEnabled(state);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return MIDIAccessImpl.call_dispatchEvent(state, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MIDIAccessImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MIDIAccessImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MIDIAccessImpl.call_removeEventListener(state, type_, callback, options);
    }

};
