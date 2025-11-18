//! Generated from: webcodecs.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ImageTrackListImpl = @import("impls").ImageTrackList;
const ImageTrack = @import("interfaces").ImageTrack;
const Promise<undefined> = @import("interfaces").Promise<undefined>;

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
        
        // Initialize the instance (Impl receives full instance)
        ImageTrackListImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ImageTrackListImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_ready(instance: *runtime.Instance) anyerror!anyopaque {
        return try ImageTrackListImpl.get_ready(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try ImageTrackListImpl.get_length(instance);
    }

    pub fn get_selectedIndex(instance: *runtime.Instance) anyerror!i32 {
        return try ImageTrackListImpl.get_selectedIndex(instance);
    }

    pub fn get_selectedTrack(instance: *runtime.Instance) anyerror!anyopaque {
        return try ImageTrackListImpl.get_selectedTrack(instance);
    }

};
