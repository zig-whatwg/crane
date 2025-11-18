//! Generated from: picture-in-picture.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PictureInPictureWindowImpl = @import("../impls/PictureInPictureWindow.zig");
const EventTarget = @import("EventTarget.zig");

pub const PictureInPictureWindow = struct {
    pub const Meta = struct {
        pub const name = "PictureInPictureWindow";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            width: i32 = undefined,
            height: i32 = undefined,
            onresize: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(PictureInPictureWindow, .{
        .deinit_fn = &deinit_wrapper,

        .get_height = &get_height,
        .get_onresize = &get_onresize,
        .get_width = &get_width,

        .set_onresize = &set_onresize,

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
        PictureInPictureWindowImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        PictureInPictureWindowImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_width(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return PictureInPictureWindowImpl.get_width(state);
    }

    pub fn get_height(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return PictureInPictureWindowImpl.get_height(state);
    }

    pub fn get_onresize(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return PictureInPictureWindowImpl.get_onresize(state);
    }

    pub fn set_onresize(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        PictureInPictureWindowImpl.set_onresize(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return PictureInPictureWindowImpl.call_dispatchEvent(state, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PictureInPictureWindowImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PictureInPictureWindowImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return PictureInPictureWindowImpl.call_removeEventListener(state, type_, callback, options);
    }

};
