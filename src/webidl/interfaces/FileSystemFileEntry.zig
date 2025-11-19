//! Generated from: entries-api.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FileSystemFileEntryImpl = @import("impls").FileSystemFileEntry;
const FileSystemEntry = @import("interfaces").FileSystemEntry;
const FileSystem = @import("interfaces").FileSystem;
const ErrorCallback = @import("callbacks").ErrorCallback;
const FileCallback = @import("callbacks").FileCallback;
const FileSystemEntryCallback = @import("callbacks").FileSystemEntryCallback;
const USVString = @import("interfaces").USVString;

pub const FileSystemFileEntry = struct {
    pub const Meta = struct {
        pub const name = "FileSystemFileEntry";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *FileSystemEntry;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(FileSystemFileEntry, .{
        .deinit_fn = &deinit_wrapper,

        .get_filesystem = &get_filesystem,
        .get_fullPath = &get_fullPath,
        .get_isDirectory = &get_isDirectory,
        .get_isFile = &get_isFile,
        .get_name = &get_name,

        .call_file = &call_file,
        .call_getParent = &call_getParent,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return FileSystemFileEntryImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileSystemFileEntryImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_isFile(instance: *runtime.Instance) anyerror!bool {
        return try FileSystemFileEntryImpl.get_isFile(instance);
    }

    pub fn get_isDirectory(instance: *runtime.Instance) anyerror!bool {
        return try FileSystemFileEntryImpl.get_isDirectory(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FileSystemFileEntryImpl.get_name(instance);
    }

    pub fn get_fullPath(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FileSystemFileEntryImpl.get_fullPath(instance);
    }

    pub fn get_filesystem(instance: *runtime.Instance) anyerror!FileSystem {
        return try FileSystemFileEntryImpl.get_filesystem(instance);
    }

    pub fn call_file(instance: *runtime.Instance, successCallback: FileCallback, errorCallback: ErrorCallback) anyerror!void {
        
        return try FileSystemFileEntryImpl.call_file(instance, successCallback, errorCallback);
    }

    pub fn call_getParent(instance: *runtime.Instance, successCallback: FileSystemEntryCallback, errorCallback: ErrorCallback) anyerror!void {
        
        return try FileSystemFileEntryImpl.call_getParent(instance, successCallback, errorCallback);
    }

};
