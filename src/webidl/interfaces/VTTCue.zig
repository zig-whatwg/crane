//! Generated from: webvtt.idl
//! Generated at: 2025-11-24T18:47:07Z
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
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *TextTrackCue;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "region", "get_region", "set_region" },
            .{ "vertical", "get_vertical", "set_vertical" },
            .{ "snapToLines", "get_snapToLines", "set_snapToLines" },
            .{ "line", "get_line", "set_line" },
            .{ "lineAlign", "get_lineAlign", "set_lineAlign" },
            .{ "position", "get_position", "set_position" },
            .{ "positionAlign", "get_positionAlign", "set_positionAlign" },
            .{ "size", "get_size", "set_size" },
            .{ "align", "get_align", "set_align" },
            .{ "text", "get_text", "set_text" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "getCueAsHTML", "call_getCueAsHTML", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getCueAsHTML",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "region", "get_region", "set_region" },
            .{ "vertical", "get_vertical", "set_vertical" },
            .{ "snapToLines", "get_snapToLines", "set_snapToLines" },
            .{ "line", "get_line", "set_line" },
            .{ "lineAlign", "get_lineAlign", "set_lineAlign" },
            .{ "position", "get_position", "set_position" },
            .{ "positionAlign", "get_positionAlign", "set_positionAlign" },
            .{ "size", "get_size", "set_size" },
            .{ "align", "get_align", "set_align" },
            .{ "text", "get_text", "set_text" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            region: ?*runtime.Instance = null,
            vertical: DirectionSetting = undefined,
            snapToLines: bool = undefined,
            line: LineAndPositionSetting = undefined,
            lineAlign: LineAlignSetting = undefined,
            position: LineAndPositionSetting = undefined,
            positionAlign: PositionAlignSetting = undefined,
            size: f64 = undefined,
            @"align": AlignSetting = undefined,
            text: runtime.DOMString = undefined,
            _internal: ?*VTTCueImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_align = &get_align,
        .get_line = &get_line,
        .get_lineAlign = &get_lineAlign,
        .get_position = &get_position,
        .get_positionAlign = &get_positionAlign,
        .get_region = &get_region,
        .get_size = &get_size,
        .get_snapToLines = &get_snapToLines,
        .get_text = &get_text,
        .get_vertical = &get_vertical,

        .set_align = &set_align,
        .set_line = &set_line,
        .set_lineAlign = &set_lineAlign,
        .set_position = &set_position,
        .set_positionAlign = &set_positionAlign,
        .set_region = &set_region,
        .set_size = &set_size,
        .set_snapToLines = &set_snapToLines,
        .set_text = &set_text,
        .set_vertical = &set_vertical,

        .call_getCueAsHTML = &call_getCueAsHTML,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return VTTCueImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        VTTCueImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, startTime: f64, endTime: f64, text: DOMString) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try VTTCueImpl.call_constructor(allocator, ctx, startTime, endTime, text);
    }

    pub fn get_region(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try VTTCueImpl.get_region(instance);
    }

    pub fn set_region(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
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

    pub fn call_getCueAsHTML(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try VTTCueImpl.call_getCueAsHTML(instance);
    }

};
