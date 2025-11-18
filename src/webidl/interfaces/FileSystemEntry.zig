//! Generated from: entries-api.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FileSystemEntryImpl = @import("impls").FileSystemEntry;
const FileSystemEntryCallback = @import("callbacks").FileSystemEntryCallback;
const FileSystem = @import("interfaces").FileSystem;
const ErrorCallback = @import("callbacks").ErrorCallback;

pub const FileSystemEntry = struct {
    pub const Meta = struct {
        pub const name = "FileSystemEntry";
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
            isFile: bool = undefined,
            isDirectory: bool = undefined,
            name: runtime.USVString = undefined,
            fullPath: runtime.USVString = undefined,
            filesystem: FileSystem = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(FileSystemEntry, .{
        .deinit_fn = &deinit_wrapper,

        .get_filesystem = &get_filesystem,
        .get_fullPath = &get_fullPath,
        .get_isDirectory = &get_isDirectory,
        .get_isFile = &get_isFile,
        .get_name = &get_name,

        .call_getParent = &call_getParent,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        FileSystemEntryImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileSystemEntryImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_isFile(instance: *runtime.Instance) anyerror!bool {
        return try FileSystemEntryImpl.get_isFile(instance);
    }

    pub fn get_isDirectory(instance: *runtime.Instance) anyerror!bool {
        return try FileSystemEntryImpl.get_isDirectory(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FileSystemEntryImpl.get_name(instance);
    }

    pub fn get_fullPath(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FileSystemEntryImpl.get_fullPath(instance);
    }

    pub fn get_filesystem(instance: *runtime.Instance) anyerror!FileSystem {
        return try FileSystemEntryImpl.get_filesystem(instance);
    }

    pub fn call_getParent(instance: *runtime.Instance, successCallback: FileSystemEntryCallback, errorCallback: ErrorCallback) anyerror!void {
        
        return try FileSystemEntryImpl.call_getParent(instance, successCallback, errorCallback);
    }

};
