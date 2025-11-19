//! Generated from: html.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TextTrackCueListImpl = @import("impls").TextTrackCueList;
const TextTrackCue = @import("interfaces").TextTrackCue;
const DOMString = @import("typedefs").DOMString;

pub const TextTrackCueList = struct {
    pub const Meta = struct {
        pub const name = "TextTrackCueList";
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
            length: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(TextTrackCueList, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,

        .call_getCueById = &call_getCueById,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return TextTrackCueListImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TextTrackCueListImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try TextTrackCueListImpl.get_length(instance);
    }

    pub fn call_getCueById(instance: *runtime.Instance, id: DOMString) anyerror!TextTrackCue {
        
        return try TextTrackCueListImpl.call_getCueById(instance, id);
    }

};
