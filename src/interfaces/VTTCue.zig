//! Generated from: webvtt.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const VTTCueImpl = @import("../impls/VTTCue.zig");
const TextTrackCue = @import("TextTrackCue.zig");

pub const VTTCue = struct {
    pub const Meta = struct {
        pub const name = "VTTCue";
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
            region: ?VTTRegion = null,
            vertical: DirectionSetting = undefined,
            snapToLines: bool = undefined,
            line: LineAndPositionSetting = undefined,
            lineAlign: LineAlignSetting = undefined,
            position: LineAndPositionSetting = undefined,
            positionAlign: PositionAlignSetting = undefined,
            size: f64 = undefined,
            align: AlignSetting = undefined,
            text: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(VTTCue, .{
        .deinit_fn = &deinit_wrapper,

        .get_align = &get_align,
        .get_endTime = &get_endTime,
        .get_id = &get_id,
        .get_line = &get_line,
        .get_lineAlign = &get_lineAlign,
        .get_onenter = &get_onenter,
        .get_onexit = &get_onexit,
        .get_pauseOnExit = &get_pauseOnExit,
        .get_position = &get_position,
        .get_positionAlign = &get_positionAlign,
        .get_region = &get_region,
        .get_size = &get_size,
        .get_snapToLines = &get_snapToLines,
        .get_startTime = &get_startTime,
        .get_text = &get_text,
        .get_track = &get_track,
        .get_vertical = &get_vertical,

        .set_align = &set_align,
        .set_endTime = &set_endTime,
        .set_id = &set_id,
        .set_line = &set_line,
        .set_lineAlign = &set_lineAlign,
        .set_onenter = &set_onenter,
        .set_onexit = &set_onexit,
        .set_pauseOnExit = &set_pauseOnExit,
        .set_position = &set_position,
        .set_positionAlign = &set_positionAlign,
        .set_region = &set_region,
        .set_size = &set_size,
        .set_snapToLines = &set_snapToLines,
        .set_startTime = &set_startTime,
        .set_text = &set_text,
        .set_vertical = &set_vertical,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getCueAsHTML = &call_getCueAsHTML,
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
        VTTCueImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        VTTCueImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, startTime: f64, endTime: f64, text: runtime.DOMString) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try VTTCueImpl.constructor(state, startTime, endTime, text);
        
        return instance;
    }

    pub fn get_track(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VTTCueImpl.get_track(state);
    }

    pub fn get_id(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return VTTCueImpl.get_id(state);
    }

    pub fn set_id(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        VTTCueImpl.set_id(state, value);
    }

    pub fn get_startTime(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return VTTCueImpl.get_startTime(state);
    }

    pub fn set_startTime(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        VTTCueImpl.set_startTime(state, value);
    }

    pub fn get_endTime(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return VTTCueImpl.get_endTime(state);
    }

    pub fn set_endTime(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        VTTCueImpl.set_endTime(state, value);
    }

    pub fn get_pauseOnExit(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return VTTCueImpl.get_pauseOnExit(state);
    }

    pub fn set_pauseOnExit(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        VTTCueImpl.set_pauseOnExit(state, value);
    }

    pub fn get_onenter(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VTTCueImpl.get_onenter(state);
    }

    pub fn set_onenter(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        VTTCueImpl.set_onenter(state, value);
    }

    pub fn get_onexit(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VTTCueImpl.get_onexit(state);
    }

    pub fn set_onexit(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        VTTCueImpl.set_onexit(state, value);
    }

    pub fn get_region(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VTTCueImpl.get_region(state);
    }

    pub fn set_region(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        VTTCueImpl.set_region(state, value);
    }

    pub fn get_vertical(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VTTCueImpl.get_vertical(state);
    }

    pub fn set_vertical(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        VTTCueImpl.set_vertical(state, value);
    }

    pub fn get_snapToLines(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return VTTCueImpl.get_snapToLines(state);
    }

    pub fn set_snapToLines(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        VTTCueImpl.set_snapToLines(state, value);
    }

    pub fn get_line(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VTTCueImpl.get_line(state);
    }

    pub fn set_line(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        VTTCueImpl.set_line(state, value);
    }

    pub fn get_lineAlign(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VTTCueImpl.get_lineAlign(state);
    }

    pub fn set_lineAlign(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        VTTCueImpl.set_lineAlign(state, value);
    }

    pub fn get_position(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VTTCueImpl.get_position(state);
    }

    pub fn set_position(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        VTTCueImpl.set_position(state, value);
    }

    pub fn get_positionAlign(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VTTCueImpl.get_positionAlign(state);
    }

    pub fn set_positionAlign(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        VTTCueImpl.set_positionAlign(state, value);
    }

    pub fn get_size(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return VTTCueImpl.get_size(state);
    }

    pub fn set_size(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        VTTCueImpl.set_size(state, value);
    }

    pub fn get_align(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VTTCueImpl.get_align(state);
    }

    pub fn set_align(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        VTTCueImpl.set_align(state, value);
    }

    pub fn get_text(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return VTTCueImpl.get_text(state);
    }

    pub fn set_text(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        VTTCueImpl.set_text(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return VTTCueImpl.call_dispatchEvent(state, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return VTTCueImpl.call_when(state, type_, options);
    }

    pub fn call_getCueAsHTML(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return VTTCueImpl.call_getCueAsHTML(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return VTTCueImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return VTTCueImpl.call_removeEventListener(state, type_, callback, options);
    }

};
