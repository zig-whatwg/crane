//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const VideoTrackListImpl = @import("../impls/VideoTrackList.zig");
const EventTarget = @import("EventTarget.zig");

pub const VideoTrackList = struct {
    pub const Meta = struct {
        pub const name = "VideoTrackList";
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
            length: u32 = undefined,
            selectedIndex: i32 = undefined,
            onchange: EventHandler = undefined,
            onaddtrack: EventHandler = undefined,
            onremovetrack: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(VideoTrackList, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,
        .get_onaddtrack = &get_onaddtrack,
        .get_onchange = &get_onchange,
        .get_onremovetrack = &get_onremovetrack,
        .get_selectedIndex = &get_selectedIndex,

        .set_onaddtrack = &set_onaddtrack,
        .set_onchange = &set_onchange,
        .set_onremovetrack = &set_onremovetrack,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getTrackById = &call_getTrackById,
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
        VideoTrackListImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        VideoTrackListImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return VideoTrackListImpl.get_length(state);
    }

    pub fn get_selectedIndex(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return VideoTrackListImpl.get_selectedIndex(state);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VideoTrackListImpl.get_onchange(state);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        VideoTrackListImpl.set_onchange(state, value);
    }

    pub fn get_onaddtrack(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VideoTrackListImpl.get_onaddtrack(state);
    }

    pub fn set_onaddtrack(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        VideoTrackListImpl.set_onaddtrack(state, value);
    }

    pub fn get_onremovetrack(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VideoTrackListImpl.get_onremovetrack(state);
    }

    pub fn set_onremovetrack(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        VideoTrackListImpl.set_onremovetrack(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return VideoTrackListImpl.call_dispatchEvent(state, event);
    }

    pub fn call_getTrackById(instance: *runtime.Instance, id: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return VideoTrackListImpl.call_getTrackById(state, id);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return VideoTrackListImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return VideoTrackListImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return VideoTrackListImpl.call_removeEventListener(state, type_, callback, options);
    }

};
