//! Generated from: mediasession.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ChapterInformationImpl = @import("impls").ChapterInformation;
const DOMString = @import("typedefs").DOMString;
const MediaImage = @import("dictionaries").MediaImage;

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
            artwork: runtime.FrozenArray(MediaImage) = undefined,
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
        return ChapterInformationImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ChapterInformationImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_title(instance: *runtime.Instance) anyerror!DOMString {
        return try ChapterInformationImpl.get_title(instance);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!f64 {
        return try ChapterInformationImpl.get_startTime(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_artwork(instance: *runtime.Instance) anyerror!anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_artwork) |cached| {
            return cached;
        }
        const value = try ChapterInformationImpl.get_artwork(instance);
        state.cached_artwork = value;
        return value;
    }

};
