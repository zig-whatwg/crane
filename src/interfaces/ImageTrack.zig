//! Generated from: webcodecs.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ImageTrackImpl = @import("../impls/ImageTrack.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        ImageTrackImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ImageTrackImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_animated(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return ImageTrackImpl.get_animated(state);
    }

    pub fn get_frameCount(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return ImageTrackImpl.get_frameCount(state);
    }

    pub fn get_repetitionCount(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return ImageTrackImpl.get_repetitionCount(state);
    }

    pub fn get_selected(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return ImageTrackImpl.get_selected(state);
    }

    pub fn set_selected(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        ImageTrackImpl.set_selected(state, value);
    }

};
