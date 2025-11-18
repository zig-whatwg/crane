//! Generated from: virtual-keyboard.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const VirtualKeyboardImpl = @import("../impls/VirtualKeyboard.zig");
const EventTarget = @import("EventTarget.zig");

pub const VirtualKeyboard = struct {
    pub const Meta = struct {
        pub const name = "VirtualKeyboard";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            boundingRect: DOMRect = undefined,
            overlaysContent: bool = undefined,
            ongeometrychange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(VirtualKeyboard, .{
        .deinit_fn = &deinit_wrapper,

        .get_boundingRect = &get_boundingRect,
        .get_ongeometrychange = &get_ongeometrychange,
        .get_overlaysContent = &get_overlaysContent,

        .set_ongeometrychange = &set_ongeometrychange,
        .set_overlaysContent = &set_overlaysContent,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_hide = &call_hide,
        .call_removeEventListener = &call_removeEventListener,
        .call_show = &call_show,
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
        VirtualKeyboardImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        VirtualKeyboardImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_boundingRect(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VirtualKeyboardImpl.get_boundingRect(state);
    }

    pub fn get_overlaysContent(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return VirtualKeyboardImpl.get_overlaysContent(state);
    }

    pub fn set_overlaysContent(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        VirtualKeyboardImpl.set_overlaysContent(state, value);
    }

    pub fn get_ongeometrychange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VirtualKeyboardImpl.get_ongeometrychange(state);
    }

    pub fn set_ongeometrychange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        VirtualKeyboardImpl.set_ongeometrychange(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return VirtualKeyboardImpl.call_dispatchEvent(state, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return VirtualKeyboardImpl.call_when(state, type_, options);
    }

    pub fn call_show(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VirtualKeyboardImpl.call_show(state);
    }

    pub fn call_hide(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VirtualKeyboardImpl.call_hide(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return VirtualKeyboardImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return VirtualKeyboardImpl.call_removeEventListener(state, type_, callback, options);
    }

};
