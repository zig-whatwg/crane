//! Generated from: web-nfc.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NDEFReaderImpl = @import("../impls/NDEFReader.zig");
const EventTarget = @import("EventTarget.zig");

pub const NDEFReader = struct {
    pub const Meta = struct {
        pub const name = "NDEFReader";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            onreading: EventHandler = undefined,
            onreadingerror: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NDEFReader, .{
        .deinit_fn = &deinit_wrapper,

        .get_onreading = &get_onreading,
        .get_onreadingerror = &get_onreadingerror,

        .set_onreading = &set_onreading,
        .set_onreadingerror = &set_onreadingerror,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_makeReadOnly = &call_makeReadOnly,
        .call_removeEventListener = &call_removeEventListener,
        .call_scan = &call_scan,
        .call_when = &call_when,
        .call_write = &call_write,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        NDEFReaderImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        NDEFReaderImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try NDEFReaderImpl.constructor(state);
        
        return instance;
    }

    pub fn get_onreading(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NDEFReaderImpl.get_onreading(state);
    }

    pub fn set_onreading(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        NDEFReaderImpl.set_onreading(state, value);
    }

    pub fn get_onreadingerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NDEFReaderImpl.get_onreadingerror(state);
    }

    pub fn set_onreadingerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        NDEFReaderImpl.set_onreadingerror(state, value);
    }

    pub fn call_scan(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NDEFReaderImpl.call_scan(state, options);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NDEFReaderImpl.call_when(state, type_, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return NDEFReaderImpl.call_dispatchEvent(state, event);
    }

    pub fn call_makeReadOnly(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NDEFReaderImpl.call_makeReadOnly(state, options);
    }

    pub fn call_write(instance: *runtime.Instance, message: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NDEFReaderImpl.call_write(state, message, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NDEFReaderImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return NDEFReaderImpl.call_removeEventListener(state, type_, callback, options);
    }

};
