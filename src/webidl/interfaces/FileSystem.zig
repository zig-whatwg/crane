//! Generated from: entries-api.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FileSystemImpl = @import("impls").FileSystem;
const FileSystemDirectoryEntry = @import("interfaces").FileSystemDirectoryEntry;
const USVString = @import("interfaces").USVString;

pub const FileSystem = struct {
    pub const Meta = struct {
        pub const name = "FileSystem";
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
            name: runtime.USVString = undefined,
            root: FileSystemDirectoryEntry = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(FileSystem, .{
        .deinit_fn = &deinit_wrapper,

        .get_name = &get_name,
        .get_root = &get_root,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return FileSystemImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileSystemImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FileSystemImpl.get_name(instance);
    }

    pub fn get_root(instance: *runtime.Instance) anyerror!FileSystemDirectoryEntry {
        return try FileSystemImpl.get_root(instance);
    }

};
