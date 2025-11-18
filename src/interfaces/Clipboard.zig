//! Generated from: clipboard-apis.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ClipboardImpl = @import("../impls/Clipboard.zig");
const EventTarget = @import("EventTarget.zig");

pub const Clipboard = struct {
    pub const Meta = struct {
        pub const name = "Clipboard";
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
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Clipboard, .{
        .deinit_fn = &deinit_wrapper,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_read = &call_read,
        .call_readText = &call_readText,
        .call_removeEventListener = &call_removeEventListener,
        .call_when = &call_when,
        .call_write = &call_write,
        .call_writeText = &call_writeText,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ClipboardImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ClipboardImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ClipboardImpl.call_removeEventListener(state, type_, callback, options);
    }

    pub fn call_writeText(instance: *runtime.Instance, data: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return ClipboardImpl.call_writeText(state, data);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ClipboardImpl.call_when(state, type_, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return ClipboardImpl.call_dispatchEvent(state, event);
    }

    pub fn call_read(instance: *runtime.Instance, formats: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ClipboardImpl.call_read(state, formats);
    }

    pub fn call_write(instance: *runtime.Instance, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ClipboardImpl.call_write(state, data);
    }

    pub fn call_readText(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ClipboardImpl.call_readText(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return ClipboardImpl.call_addEventListener(state, type_, callback, options);
    }

};
