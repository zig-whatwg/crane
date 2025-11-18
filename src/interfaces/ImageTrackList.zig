//! Generated from: webcodecs.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ImageTrackListImpl = @import("../impls/ImageTrackList.zig");

pub const ImageTrackList = struct {
    pub const Meta = struct {
        pub const name = "ImageTrackList";
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
            ready: Promise<undefined> = undefined,
            length: u32 = undefined,
            selectedIndex: i32 = undefined,
            selectedTrack: ?ImageTrack = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ImageTrackList, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,
        .get_ready = &get_ready,
        .get_selectedIndex = &get_selectedIndex,
        .get_selectedTrack = &get_selectedTrack,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ImageTrackListImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ImageTrackListImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_ready(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ImageTrackListImpl.get_ready(state);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return ImageTrackListImpl.get_length(state);
    }

    pub fn get_selectedIndex(instance: *runtime.Instance) i32 {
        const state = instance.getState(State);
        return ImageTrackListImpl.get_selectedIndex(state);
    }

    pub fn get_selectedTrack(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ImageTrackListImpl.get_selectedTrack(state);
    }

};
