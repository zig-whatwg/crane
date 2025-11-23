//! Generated from: media-source.idl
//! Generated at: 2025-11-23T14:26:30Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SourceBufferImpl = @import("impls").SourceBuffer;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const EventHandler = @import("typedefs").EventHandler;
const AudioTrackList = @import("interfaces").AudioTrackList;
const TextTrackList = @import("interfaces").TextTrackList;
const TimeRanges = @import("interfaces").TimeRanges;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const BufferSource = @import("typedefs").BufferSource;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const VideoTrackList = @import("interfaces").VideoTrackList;
const DOMString = @import("typedefs").DOMString;
const AppendMode = @import("enums").AppendMode;

pub const SourceBuffer = struct {
    pub const Meta = struct {
        pub const name = "SourceBuffer";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "mode", "get_mode", "set_mode" },
            .{ "updating", "get_updating", null },
            .{ "buffered", "get_buffered", null },
            .{ "timestampOffset", "get_timestampOffset", "set_timestampOffset" },
            .{ "audioTracks", "get_audioTracks", null },
            .{ "videoTracks", "get_videoTracks", null },
            .{ "textTracks", "get_textTracks", null },
            .{ "appendWindowStart", "get_appendWindowStart", "set_appendWindowStart" },
            .{ "appendWindowEnd", "get_appendWindowEnd", "set_appendWindowEnd" },
            .{ "onupdatestart", "get_onupdatestart", "set_onupdatestart" },
            .{ "onupdate", "get_onupdate", "set_onupdate" },
            .{ "onupdateend", "get_onupdateend", "set_onupdateend" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onabort", "get_onabort", "set_onabort" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "appendBuffer", "call_appendBuffer", 1 },
            .{ "abort", "call_abort", 0 },
            .{ "changeType", "call_changeType", 1 },
            .{ "remove", "call_remove", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "appendBuffer",
            "abort",
            "changeType",
            "remove",
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
            .{ "mode", "get_mode", "set_mode" },
            .{ "updating", "get_updating", null },
            .{ "buffered", "get_buffered", null },
            .{ "timestampOffset", "get_timestampOffset", "set_timestampOffset" },
            .{ "audioTracks", "get_audioTracks", null },
            .{ "videoTracks", "get_videoTracks", null },
            .{ "textTracks", "get_textTracks", null },
            .{ "appendWindowStart", "get_appendWindowStart", "set_appendWindowStart" },
            .{ "appendWindowEnd", "get_appendWindowEnd", "set_appendWindowEnd" },
            .{ "onupdatestart", "get_onupdatestart", "set_onupdatestart" },
            .{ "onupdate", "get_onupdate", "set_onupdate" },
            .{ "onupdateend", "get_onupdateend", "set_onupdateend" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onabort", "get_onabort", "set_onabort" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            mode: AppendMode = undefined,
            updating: bool = undefined,
            buffered: TimeRanges = undefined,
            timestampOffset: f64 = undefined,
            audioTracks: AudioTrackList = undefined,
            videoTracks: VideoTrackList = undefined,
            textTracks: TextTrackList = undefined,
            appendWindowStart: f64 = undefined,
            appendWindowEnd: f64 = undefined,
            onupdatestart: EventHandler = undefined,
            onupdate: EventHandler = undefined,
            onupdateend: EventHandler = undefined,
            onerror: EventHandler = undefined,
            onabort: EventHandler = undefined,
            _internal: ?*SourceBufferImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_appendWindowEnd = &get_appendWindowEnd,
        .get_appendWindowStart = &get_appendWindowStart,
        .get_audioTracks = &get_audioTracks,
        .get_buffered = &get_buffered,
        .get_mode = &get_mode,
        .get_onabort = &get_onabort,
        .get_onerror = &get_onerror,
        .get_onupdate = &get_onupdate,
        .get_onupdateend = &get_onupdateend,
        .get_onupdatestart = &get_onupdatestart,
        .get_textTracks = &get_textTracks,
        .get_timestampOffset = &get_timestampOffset,
        .get_updating = &get_updating,
        .get_videoTracks = &get_videoTracks,

        .set_appendWindowEnd = &set_appendWindowEnd,
        .set_appendWindowStart = &set_appendWindowStart,
        .set_mode = &set_mode,
        .set_onabort = &set_onabort,
        .set_onerror = &set_onerror,
        .set_onupdate = &set_onupdate,
        .set_onupdateend = &set_onupdateend,
        .set_onupdatestart = &set_onupdatestart,
        .set_timestampOffset = &set_timestampOffset,

        .call_abort = &call_abort,
        .call_appendBuffer = &call_appendBuffer,
        .call_changeType = &call_changeType,
        .call_remove = &call_remove,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SourceBufferImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SourceBufferImpl.deinit(instance);
    }

    pub fn get_mode(instance: *runtime.Instance) anyerror!AppendMode {
        return try SourceBufferImpl.get_mode(instance);
    }

    pub fn set_mode(instance: *runtime.Instance, value: AppendMode) anyerror!void {
        try SourceBufferImpl.set_mode(instance, value);
    }

    pub fn get_updating(instance: *runtime.Instance) anyerror!bool {
        return try SourceBufferImpl.get_updating(instance);
    }

    pub fn get_buffered(instance: *runtime.Instance) anyerror!TimeRanges {
        return try SourceBufferImpl.get_buffered(instance);
    }

    pub fn get_timestampOffset(instance: *runtime.Instance) anyerror!f64 {
        return try SourceBufferImpl.get_timestampOffset(instance);
    }

    pub fn set_timestampOffset(instance: *runtime.Instance, value: f64) anyerror!void {
        try SourceBufferImpl.set_timestampOffset(instance, value);
    }

    pub fn get_audioTracks(instance: *runtime.Instance) anyerror!AudioTrackList {
        return try SourceBufferImpl.get_audioTracks(instance);
    }

    pub fn get_videoTracks(instance: *runtime.Instance) anyerror!VideoTrackList {
        return try SourceBufferImpl.get_videoTracks(instance);
    }

    pub fn get_textTracks(instance: *runtime.Instance) anyerror!TextTrackList {
        return try SourceBufferImpl.get_textTracks(instance);
    }

    pub fn get_appendWindowStart(instance: *runtime.Instance) anyerror!f64 {
        return try SourceBufferImpl.get_appendWindowStart(instance);
    }

    pub fn set_appendWindowStart(instance: *runtime.Instance, value: f64) anyerror!void {
        try SourceBufferImpl.set_appendWindowStart(instance, value);
    }

    pub fn get_appendWindowEnd(instance: *runtime.Instance) anyerror!f64 {
        return try SourceBufferImpl.get_appendWindowEnd(instance);
    }

    pub fn set_appendWindowEnd(instance: *runtime.Instance, value: f64) anyerror!void {
        try SourceBufferImpl.set_appendWindowEnd(instance, value);
    }

    pub fn get_onupdatestart(instance: *runtime.Instance) anyerror!EventHandler {
        return try SourceBufferImpl.get_onupdatestart(instance);
    }

    pub fn set_onupdatestart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SourceBufferImpl.set_onupdatestart(instance, value);
    }

    pub fn get_onupdate(instance: *runtime.Instance) anyerror!EventHandler {
        return try SourceBufferImpl.get_onupdate(instance);
    }

    pub fn set_onupdate(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SourceBufferImpl.set_onupdate(instance, value);
    }

    pub fn get_onupdateend(instance: *runtime.Instance) anyerror!EventHandler {
        return try SourceBufferImpl.get_onupdateend(instance);
    }

    pub fn set_onupdateend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SourceBufferImpl.set_onupdateend(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try SourceBufferImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SourceBufferImpl.set_onerror(instance, value);
    }

    pub fn get_onabort(instance: *runtime.Instance) anyerror!EventHandler {
        return try SourceBufferImpl.get_onabort(instance);
    }

    pub fn set_onabort(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SourceBufferImpl.set_onabort(instance, value);
    }

    pub fn call_appendBuffer(instance: *runtime.Instance, data: BufferSource) anyerror!void {
        
        return try SourceBufferImpl.call_appendBuffer(instance, data);
    }

    pub fn call_abort(instance: *runtime.Instance) anyerror!void {
        return try SourceBufferImpl.call_abort(instance);
    }

    pub fn call_remove(instance: *runtime.Instance, start: f64, end: f64) anyerror!void {
        
        return try SourceBufferImpl.call_remove(instance, start, end);
    }

    pub fn call_changeType(instance: *runtime.Instance, @"type": DOMString) anyerror!void {
        
        return try SourceBufferImpl.call_changeType(instance, @"type");
    }

};
