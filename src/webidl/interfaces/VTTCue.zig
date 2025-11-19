//! Generated from: webvtt.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const VTTCueImpl = @import("impls").VTTCue;
const TextTrackCue = @import("interfaces").TextTrackCue;
const VTTRegion = @import("interfaces").VTTRegion;
const DocumentFragment = @import("interfaces").DocumentFragment;
const PositionAlignSetting = @import("enums").PositionAlignSetting;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const LineAlignSetting = @import("enums").LineAlignSetting;
const EventHandler = @import("typedefs").EventHandler;
const AlignSetting = @import("enums").AlignSetting;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const TextTrack = @import("interfaces").TextTrack;
const EventListener = @import("interfaces").EventListener;
const DirectionSetting = @import("enums").DirectionSetting;
const LineAndPositionSetting = @import("typedefs").LineAndPositionSetting;
const DOMString = @import("typedefs").DOMString;

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
            @"align": AlignSetting = undefined,
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
        return VTTCueImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        VTTCueImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, startTime: f64, endTime: f64, text: DOMString) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try VTTCueImpl.constructor(instance, startTime, endTime, text);
        
        return instance;
    }

    pub fn get_track(instance: *runtime.Instance) anyerror!TextTrack {
        return try VTTCueImpl.get_track(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try VTTCueImpl.get_id(instance);
    }

    pub fn set_id(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try VTTCueImpl.set_id(instance, value);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!f64 {
        return try VTTCueImpl.get_startTime(instance);
    }

    pub fn set_startTime(instance: *runtime.Instance, value: f64) anyerror!void {
        try VTTCueImpl.set_startTime(instance, value);
    }

    pub fn get_endTime(instance: *runtime.Instance) anyerror!f64 {
        return try VTTCueImpl.get_endTime(instance);
    }

    pub fn set_endTime(instance: *runtime.Instance, value: f64) anyerror!void {
        try VTTCueImpl.set_endTime(instance, value);
    }

    pub fn get_pauseOnExit(instance: *runtime.Instance) anyerror!bool {
        return try VTTCueImpl.get_pauseOnExit(instance);
    }

    pub fn set_pauseOnExit(instance: *runtime.Instance, value: bool) anyerror!void {
        try VTTCueImpl.set_pauseOnExit(instance, value);
    }

    pub fn get_onenter(instance: *runtime.Instance) anyerror!EventHandler {
        return try VTTCueImpl.get_onenter(instance);
    }

    pub fn set_onenter(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try VTTCueImpl.set_onenter(instance, value);
    }

    pub fn get_onexit(instance: *runtime.Instance) anyerror!EventHandler {
        return try VTTCueImpl.get_onexit(instance);
    }

    pub fn set_onexit(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try VTTCueImpl.set_onexit(instance, value);
    }

    pub fn get_region(instance: *runtime.Instance) anyerror!VTTRegion {
        return try VTTCueImpl.get_region(instance);
    }

    pub fn set_region(instance: *runtime.Instance, value: VTTRegion) anyerror!void {
        try VTTCueImpl.set_region(instance, value);
    }

    pub fn get_vertical(instance: *runtime.Instance) anyerror!DirectionSetting {
        return try VTTCueImpl.get_vertical(instance);
    }

    pub fn set_vertical(instance: *runtime.Instance, value: DirectionSetting) anyerror!void {
        try VTTCueImpl.set_vertical(instance, value);
    }

    pub fn get_snapToLines(instance: *runtime.Instance) anyerror!bool {
        return try VTTCueImpl.get_snapToLines(instance);
    }

    pub fn set_snapToLines(instance: *runtime.Instance, value: bool) anyerror!void {
        try VTTCueImpl.set_snapToLines(instance, value);
    }

    pub fn get_line(instance: *runtime.Instance) anyerror!LineAndPositionSetting {
        return try VTTCueImpl.get_line(instance);
    }

    pub fn set_line(instance: *runtime.Instance, value: LineAndPositionSetting) anyerror!void {
        try VTTCueImpl.set_line(instance, value);
    }

    pub fn get_lineAlign(instance: *runtime.Instance) anyerror!LineAlignSetting {
        return try VTTCueImpl.get_lineAlign(instance);
    }

    pub fn set_lineAlign(instance: *runtime.Instance, value: LineAlignSetting) anyerror!void {
        try VTTCueImpl.set_lineAlign(instance, value);
    }

    pub fn get_position(instance: *runtime.Instance) anyerror!LineAndPositionSetting {
        return try VTTCueImpl.get_position(instance);
    }

    pub fn set_position(instance: *runtime.Instance, value: LineAndPositionSetting) anyerror!void {
        try VTTCueImpl.set_position(instance, value);
    }

    pub fn get_positionAlign(instance: *runtime.Instance) anyerror!PositionAlignSetting {
        return try VTTCueImpl.get_positionAlign(instance);
    }

    pub fn set_positionAlign(instance: *runtime.Instance, value: PositionAlignSetting) anyerror!void {
        try VTTCueImpl.set_positionAlign(instance, value);
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!f64 {
        return try VTTCueImpl.get_size(instance);
    }

    pub fn set_size(instance: *runtime.Instance, value: f64) anyerror!void {
        try VTTCueImpl.set_size(instance, value);
    }

    pub fn get_align(instance: *runtime.Instance) anyerror!AlignSetting {
        return try VTTCueImpl.get_align(instance);
    }

    pub fn set_align(instance: *runtime.Instance, value: AlignSetting) anyerror!void {
        try VTTCueImpl.set_align(instance, value);
    }

    pub fn get_text(instance: *runtime.Instance) anyerror!DOMString {
        return try VTTCueImpl.get_text(instance);
    }

    pub fn set_text(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try VTTCueImpl.set_text(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try VTTCueImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, @"type": DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try VTTCueImpl.call_when(instance, @"type", options);
    }

    pub fn call_getCueAsHTML(instance: *runtime.Instance) anyerror!DocumentFragment {
        return try VTTCueImpl.call_getCueAsHTML(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try VTTCueImpl.call_addEventListener(instance, @"type", callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, @"type": DOMString, callback: EventListener, options: anyopaque) anyerror!void {
        
        return try VTTCueImpl.call_removeEventListener(instance, @"type", callback, options);
    }

};
