//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioTrackImpl = @import("impls").AudioTrack;
const SourceBuffer = @import("interfaces").SourceBuffer;

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
        
        // Initialize the instance (Impl receives full instance)
        AudioTrackImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioTrackImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try AudioTrackImpl.get_id(instance);
    }

    pub fn get_kind(instance: *runtime.Instance) anyerror!DOMString {
        return try AudioTrackImpl.get_kind(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!DOMString {
        return try AudioTrackImpl.get_label(instance);
    }

    pub fn get_language(instance: *runtime.Instance) anyerror!DOMString {
        return try AudioTrackImpl.get_language(instance);
    }

    pub fn get_enabled(instance: *runtime.Instance) anyerror!bool {
        return try AudioTrackImpl.get_enabled(instance);
    }

    pub fn set_enabled(instance: *runtime.Instance, value: bool) anyerror!void {
        try AudioTrackImpl.set_enabled(instance, value);
    }

    pub fn get_sourceBuffer(instance: *runtime.Instance) anyerror!anyopaque {
        return try AudioTrackImpl.get_sourceBuffer(instance);
    }

};
