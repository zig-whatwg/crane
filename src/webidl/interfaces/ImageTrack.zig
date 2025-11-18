//! Generated from: webcodecs.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ImageTrackImpl = @import("impls").ImageTrack;

pub const ImageTrack = struct {
    pub const Meta = struct {
        pub const name = "ImageTrack";
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
            animated: bool = undefined,
            frameCount: u32 = undefined,
            repetitionCount: f32 = undefined,
            selected: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ImageTrack, .{
        .deinit_fn = &deinit_wrapper,

        .get_animated = &get_animated,
        .get_frameCount = &get_frameCount,
        .get_repetitionCount = &get_repetitionCount,
        .get_selected = &get_selected,

        .set_selected = &set_selected,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        ImageTrackImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ImageTrackImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_animated(instance: *runtime.Instance) anyerror!bool {
        return try ImageTrackImpl.get_animated(instance);
    }

    pub fn get_frameCount(instance: *runtime.Instance) anyerror!u32 {
        return try ImageTrackImpl.get_frameCount(instance);
    }

    pub fn get_repetitionCount(instance: *runtime.Instance) anyerror!f32 {
        return try ImageTrackImpl.get_repetitionCount(instance);
    }

    pub fn get_selected(instance: *runtime.Instance) anyerror!bool {
        return try ImageTrackImpl.get_selected(instance);
    }

    pub fn set_selected(instance: *runtime.Instance, value: bool) anyerror!void {
        try ImageTrackImpl.set_selected(instance, value);
    }

};
