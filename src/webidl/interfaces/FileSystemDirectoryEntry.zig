//! Generated from: entries-api.idl
//! Generated at: 2025-11-18T18:28:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FileSystemDirectoryEntryImpl = @import("impls").FileSystemDirectoryEntry;
const FileSystemEntry = @import("interfaces").FileSystemEntry;
const USVString = @import("interfaces").USVString;
const ErrorCallback = @import("callbacks").ErrorCallback;
const FileSystemEntryCallback = @import("callbacks").FileSystemEntryCallback;
const FileSystemFlags = @import("dictionaries").FileSystemFlags;
const FileSystemDirectoryReader = @import("interfaces").FileSystemDirectoryReader;

pub const FileSystemDirectoryEntry = struct {
    pub const Meta = struct {
        pub const name = "FileSystemDirectoryEntry";
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

    pub const vtable = runtime.buildVTable(FileSystemDirectoryEntry, .{
        .deinit_fn = &deinit_wrapper,

        .get_filesystem = &get_filesystem,
        .get_fullPath = &get_fullPath,
        .get_isDirectory = &get_isDirectory,
        .get_isFile = &get_isFile,
        .get_name = &get_name,

        .call_createReader = &call_createReader,
        .call_getDirectory = &call_getDirectory,
        .call_getFile = &call_getFile,
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
        FileSystemDirectoryEntryImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileSystemDirectoryEntryImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_isFile(instance: *runtime.Instance) anyerror!bool {
        return try FileSystemDirectoryEntryImpl.get_isFile(instance);
    }

    pub fn get_isDirectory(instance: *runtime.Instance) anyerror!bool {
        return try FileSystemDirectoryEntryImpl.get_isDirectory(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FileSystemDirectoryEntryImpl.get_name(instance);
    }

    pub fn get_fullPath(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FileSystemDirectoryEntryImpl.get_fullPath(instance);
    }

    pub fn get_filesystem(instance: *runtime.Instance) anyerror!FileSystem {
        return try FileSystemDirectoryEntryImpl.get_filesystem(instance);
    }

    pub fn call_getDirectory(instance: *runtime.Instance, path: anyopaque, options: FileSystemFlags, successCallback: FileSystemEntryCallback, errorCallback: ErrorCallback) anyerror!void {
        
        return try FileSystemDirectoryEntryImpl.call_getDirectory(instance, path, options, successCallback, errorCallback);
    }

    pub fn call_getFile(instance: *runtime.Instance, path: anyopaque, options: FileSystemFlags, successCallback: FileSystemEntryCallback, errorCallback: ErrorCallback) anyerror!void {
        
        return try FileSystemDirectoryEntryImpl.call_getFile(instance, path, options, successCallback, errorCallback);
    }

    pub fn call_createReader(instance: *runtime.Instance) anyerror!FileSystemDirectoryReader {
        return try FileSystemDirectoryEntryImpl.call_createReader(instance);
    }

    pub fn call_getParent(instance: *runtime.Instance, successCallback: FileSystemEntryCallback, errorCallback: ErrorCallback) anyerror!void {
        
        return try FileSystemDirectoryEntryImpl.call_getParent(instance, successCallback, errorCallback);
    }

};
