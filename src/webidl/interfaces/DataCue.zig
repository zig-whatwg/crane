//! Generated from: datacue.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DataCueImpl = @import("impls").DataCue;
const TextTrackCue = @import("interfaces").TextTrackCue;

pub const DataCue = struct {
    pub const Meta = struct {
        pub const name = "DataCue";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *TextTrackCue;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            value: anyopaque = undefined,
            type: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DataCue, .{
        .deinit_fn = &deinit_wrapper,

        .get_endTime = &get_endTime,
        .get_id = &get_id,
        .get_onenter = &get_onenter,
        .get_onexit = &get_onexit,
        .get_pauseOnExit = &get_pauseOnExit,
        .get_startTime = &get_startTime,
        .get_track = &get_track,
        .get_type = &get_type,
        .get_value = &get_value,

        .set_endTime = &set_endTime,
        .set_id = &set_id,
        .set_onenter = &set_onenter,
        .set_onexit = &set_onexit,
        .set_pauseOnExit = &set_pauseOnExit,
        .set_startTime = &set_startTime,
        .set_value = &set_value,

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
        DataCueImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DataCueImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, startTime: f64, endTime: f64, value: anyopaque, type_: DOMString) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try DataCueImpl.constructor(instance, startTime, endTime, value, type_);
        
        return instance;
    }

    pub fn get_track(instance: *runtime.Instance) anyerror!anyopaque {
        return try DataCueImpl.get_track(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try DataCueImpl.get_id(instance);
    }

    pub fn set_id(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try DataCueImpl.set_id(instance, value);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!f64 {
        return try DataCueImpl.get_startTime(instance);
    }

    pub fn set_startTime(instance: *runtime.Instance, value: f64) anyerror!void {
        try DataCueImpl.set_startTime(instance, value);
    }

    pub fn get_endTime(instance: *runtime.Instance) anyerror!f64 {
        return try DataCueImpl.get_endTime(instance);
    }

    pub fn set_endTime(instance: *runtime.Instance, value: f64) anyerror!void {
        try DataCueImpl.set_endTime(instance, value);
    }

    pub fn get_pauseOnExit(instance: *runtime.Instance) anyerror!bool {
        return try DataCueImpl.get_pauseOnExit(instance);
    }

    pub fn set_pauseOnExit(instance: *runtime.Instance, value: bool) anyerror!void {
        try DataCueImpl.set_pauseOnExit(instance, value);
    }

    pub fn get_onenter(instance: *runtime.Instance) anyerror!EventHandler {
        return try DataCueImpl.get_onenter(instance);
    }

    pub fn set_onenter(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DataCueImpl.set_onenter(instance, value);
    }

    pub fn get_onexit(instance: *runtime.Instance) anyerror!EventHandler {
        return try DataCueImpl.get_onexit(instance);
    }

    pub fn set_onexit(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try DataCueImpl.set_onexit(instance, value);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!anyopaque {
        return try DataCueImpl.get_value(instance);
    }

    pub fn set_value(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try DataCueImpl.set_value(instance, value);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try DataCueImpl.get_type(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try DataCueImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try DataCueImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try DataCueImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try DataCueImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
