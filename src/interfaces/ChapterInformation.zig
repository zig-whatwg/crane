//! Generated from: mediasession.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ChapterInformationImpl = @import("../impls/ChapterInformation.zig");

pub const ChapterInformation = struct {
    pub const Meta = struct {
        pub const name = "ChapterInformation";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            title: runtime.DOMString = undefined,
            startTime: f64 = undefined,
            artwork: FrozenArray<MediaImage> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ChapterInformation, .{
        .deinit_fn = &deinit_wrapper,

        .get_artwork = &get_artwork,
        .get_startTime = &get_startTime,
        .get_title = &get_title,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ChapterInformationImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ChapterInformationImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_title(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return ChapterInformationImpl.get_title(state);
    }

    pub fn get_startTime(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return ChapterInformationImpl.get_startTime(state);
    }

    /// Extended attributes: [SameObject]
    pub fn get_artwork(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_artwork) |cached| {
            return cached;
        }
        const value = ChapterInformationImpl.get_artwork(state);
        state.cached_artwork = value;
        return value;
    }

};
