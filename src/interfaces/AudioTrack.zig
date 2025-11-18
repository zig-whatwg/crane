//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioTrackImpl = @import("../impls/AudioTrack.zig");

pub const AudioTrack = struct {
    pub const Meta = struct {
        pub const name = "AudioTrack";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
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
            id: runtime.DOMString = undefined,
            kind: runtime.DOMString = undefined,
            label: runtime.DOMString = undefined,
            language: runtime.DOMString = undefined,
            enabled: bool = undefined,
            sourceBuffer: ?SourceBuffer = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(AudioTrack, .{
        .deinit_fn = &deinit_wrapper,

        .get_enabled = &get_enabled,
        .get_id = &get_id,
        .get_kind = &get_kind,
        .get_label = &get_label,
        .get_language = &get_language,
        .get_sourceBuffer = &get_sourceBuffer,

        .set_enabled = &set_enabled,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        AudioTrackImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        AudioTrackImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return AudioTrackImpl.get_id(state);
    }

    pub fn get_kind(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return AudioTrackImpl.get_kind(state);
    }

    pub fn get_label(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return AudioTrackImpl.get_label(state);
    }

    pub fn get_language(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return AudioTrackImpl.get_language(state);
    }

    pub fn get_enabled(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return AudioTrackImpl.get_enabled(state);
    }

    pub fn set_enabled(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        AudioTrackImpl.set_enabled(state, value);
    }

    pub fn get_sourceBuffer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return AudioTrackImpl.get_sourceBuffer(state);
    }

};
