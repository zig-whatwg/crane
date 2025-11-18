//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TextTrackImpl = @import("../impls/TextTrack.zig");
const EventTarget = @import("EventTarget.zig");

pub const TextTrack = struct {
    pub const Meta = struct {
        pub const name = "TextTrack";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            kind: TextTrackKind = undefined,
            label: runtime.DOMString = undefined,
            language: runtime.DOMString = undefined,
            id: runtime.DOMString = undefined,
            inBandMetadataTrackDispatchType: runtime.DOMString = undefined,
            mode: TextTrackMode = undefined,
            cues: ?TextTrackCueList = null,
            activeCues: ?TextTrackCueList = null,
            oncuechange: EventHandler = undefined,
            sourceBuffer: ?SourceBuffer = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(TextTrack, .{
        .deinit_fn = &deinit_wrapper,

        .get_activeCues = &get_activeCues,
        .get_cues = &get_cues,
        .get_id = &get_id,
        .get_inBandMetadataTrackDispatchType = &get_inBandMetadataTrackDispatchType,
        .get_kind = &get_kind,
        .get_label = &get_label,
        .get_language = &get_language,
        .get_mode = &get_mode,
        .get_oncuechange = &get_oncuechange,
        .get_sourceBuffer = &get_sourceBuffer,

        .set_mode = &set_mode,
        .set_oncuechange = &set_oncuechange,

        .call_addCue = &call_addCue,
        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeCue = &call_removeCue,
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
        TextTrackImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        TextTrackImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_kind(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TextTrackImpl.get_kind(state);
    }

    pub fn get_label(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return TextTrackImpl.get_label(state);
    }

    pub fn get_language(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return TextTrackImpl.get_language(state);
    }

    pub fn get_id(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return TextTrackImpl.get_id(state);
    }

    pub fn get_inBandMetadataTrackDispatchType(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return TextTrackImpl.get_inBandMetadataTrackDispatchType(state);
    }

    pub fn get_mode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TextTrackImpl.get_mode(state);
    }

    pub fn set_mode(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        TextTrackImpl.set_mode(state, value);
    }

    pub fn get_cues(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TextTrackImpl.get_cues(state);
    }

    pub fn get_activeCues(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TextTrackImpl.get_activeCues(state);
    }

    pub fn get_oncuechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TextTrackImpl.get_oncuechange(state);
    }

    pub fn set_oncuechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        TextTrackImpl.set_oncuechange(state, value);
    }

    pub fn get_sourceBuffer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TextTrackImpl.get_sourceBuffer(state);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return TextTrackImpl.call_dispatchEvent(state, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TextTrackImpl.call_when(state, type_, options);
    }

    pub fn call_addCue(instance: *runtime.Instance, cue: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TextTrackImpl.call_addCue(state, cue);
    }

    pub fn call_removeCue(instance: *runtime.Instance, cue: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TextTrackImpl.call_removeCue(state, cue);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TextTrackImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return TextTrackImpl.call_removeEventListener(state, type_, callback, options);
    }

};
