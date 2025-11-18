//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioTrackListImpl = @import("impls").AudioTrackList;
const EventTarget = @import("interfaces").EventTarget;
const EventHandler = @import("typedefs").EventHandler;
const AudioTrack = @import("interfaces").AudioTrack;

pub const AudioTrackList = struct {
    pub const Meta = struct {
        pub const name = "AudioTrackList";
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
            onchange: EventHandler = undefined,
            onaddtrack: EventHandler = undefined,
            onremovetrack: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(AudioTrackList, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,
        .get_onaddtrack = &get_onaddtrack,
        .get_onchange = &get_onchange,
        .get_onremovetrack = &get_onremovetrack,

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
        
        // Initialize the instance (Impl receives full instance)
        AudioTrackListImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioTrackListImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try AudioTrackListImpl.get_length(instance);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try AudioTrackListImpl.get_onchange(instance);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try AudioTrackListImpl.set_onchange(instance, value);
    }

    pub fn get_onaddtrack(instance: *runtime.Instance) anyerror!EventHandler {
        return try AudioTrackListImpl.get_onaddtrack(instance);
    }

    pub fn set_onaddtrack(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try AudioTrackListImpl.set_onaddtrack(instance, value);
    }

    pub fn get_onremovetrack(instance: *runtime.Instance) anyerror!EventHandler {
        return try AudioTrackListImpl.get_onremovetrack(instance);
    }

    pub fn set_onremovetrack(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try AudioTrackListImpl.set_onremovetrack(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try AudioTrackListImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_getTrackById(instance: *runtime.Instance, id: DOMString) anyerror!anyopaque {
        
        return try AudioTrackListImpl.call_getTrackById(instance, id);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try AudioTrackListImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try AudioTrackListImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try AudioTrackListImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
