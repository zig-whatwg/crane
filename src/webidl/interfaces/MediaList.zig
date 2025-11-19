//! Generated from: cssom.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaListImpl = @import("impls").MediaList;
const CSSOMString = @import("interfaces").CSSOMString;
const DOMString = @import("typedefs").DOMString;

pub const MediaList = struct {
    pub const Meta = struct {
        pub const name = "MediaList";
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
            mediaText: CSSOMString = undefined,
            length: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MediaList, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,
        .get_mediaText = &get_mediaText,

        .set_mediaText = &set_mediaText,

        .call_appendMedium = &call_appendMedium,
        .call_deleteMedium = &call_deleteMedium,
        .call_item = &call_item,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return MediaListImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaListImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_mediaText(instance: *runtime.Instance) anyerror!anyopaque {
        return try MediaListImpl.get_mediaText(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_mediaText(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try MediaListImpl.set_mediaText(instance, value);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try MediaListImpl.get_length(instance);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!anyopaque {
        
        return try MediaListImpl.call_item(instance, index);
    }

    pub fn call_deleteMedium(instance: *runtime.Instance, medium: anyopaque) anyerror!void {
        
        return try MediaListImpl.call_deleteMedium(instance, medium);
    }

    pub fn call_appendMedium(instance: *runtime.Instance, medium: anyopaque) anyerror!void {
        
        return try MediaListImpl.call_appendMedium(instance, medium);
    }

};
