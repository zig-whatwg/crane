//! Generated from: webmidi.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MIDIInputImpl = @import("../impls/MIDIInput.zig");
const MIDIPort = @import("MIDIPort.zig");

pub const MIDIInput = struct {
    pub const Meta = struct {
        pub const name = "MIDIInput";
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
        struct {
            onmidimessage: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MIDIInput, .{
        .deinit_fn = &deinit_wrapper,

        .get_connection = &get_connection,
        .get_id = &get_id,
        .get_manufacturer = &get_manufacturer,
        .get_name = &get_name,
        .get_onmidimessage = &get_onmidimessage,
        .get_onstatechange = &get_onstatechange,
        .get_state = &get_state,
        .get_type = &get_type,
        .get_version = &get_version,

        .set_onmidimessage = &set_onmidimessage,
        .set_onstatechange = &set_onstatechange,

        .call_addEventListener = &call_addEventListener,
        .call_close = &call_close,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_open = &call_open,
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
        MIDIInputImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        MIDIInputImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return MIDIInputImpl.get_id(state);
    }

    pub fn get_manufacturer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MIDIInputImpl.get_manufacturer(state);
    }

    pub fn get_name(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MIDIInputImpl.get_name(state);
    }

    pub fn get_type(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MIDIInputImpl.get_type(state);
    }

    pub fn get_version(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MIDIInputImpl.get_version(state);
    }

    pub fn get_state(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MIDIInputImpl.get_state(state);
    }

    pub fn get_connection(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MIDIInputImpl.get_connection(state);
    }

    pub fn get_onstatechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MIDIInputImpl.get_onstatechange(state);
    }

    pub fn set_onstatechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        MIDIInputImpl.set_onstatechange(state, value);
    }

    pub fn get_onmidimessage(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MIDIInputImpl.get_onmidimessage(state);
    }

    pub fn set_onmidimessage(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        MIDIInputImpl.set_onmidimessage(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return MIDIInputImpl.call_dispatchEvent(state, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MIDIInputImpl.call_when(state, type_, options);
    }

    pub fn call_open(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MIDIInputImpl.call_open(state);
    }

    pub fn call_close(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MIDIInputImpl.call_close(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MIDIInputImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MIDIInputImpl.call_removeEventListener(state, type_, callback, options);
    }

};
