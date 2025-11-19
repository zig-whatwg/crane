//! Generated from: web-app-launch.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const LaunchParamsImpl = @import("impls").LaunchParams;
const DOMString = @import("typedefs").DOMString;
const FileSystemHandle = @import("interfaces").FileSystemHandle;

pub const LaunchParams = struct {
    pub const Meta = struct {
        pub const name = "LaunchParams";
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
            targetURL: ?runtime.DOMString = null,
            files: runtime.FrozenArray(FileSystemHandle) = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(LaunchParams, .{
        .deinit_fn = &deinit_wrapper,

        .get_files = &get_files,
        .get_targetURL = &get_targetURL,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return LaunchParamsImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        LaunchParamsImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_targetURL(instance: *runtime.Instance) anyerror!DOMString {
        return try LaunchParamsImpl.get_targetURL(instance);
    }

    pub fn get_files(instance: *runtime.Instance) anyerror!anyopaque {
        return try LaunchParamsImpl.get_files(instance);
    }

};
