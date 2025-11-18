//! Generated from: entries-api.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FileSystemEntryImpl = @import("../impls/FileSystemEntry.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        FileSystemEntryImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        FileSystemEntryImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_isFile(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return FileSystemEntryImpl.get_isFile(state);
    }

    pub fn get_isDirectory(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return FileSystemEntryImpl.get_isDirectory(state);
    }

    pub fn get_name(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return FileSystemEntryImpl.get_name(state);
    }

    pub fn get_fullPath(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return FileSystemEntryImpl.get_fullPath(state);
    }

    pub fn get_filesystem(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FileSystemEntryImpl.get_filesystem(state);
    }

    pub fn call_getParent(instance: *runtime.Instance, successCallback: anyopaque, errorCallback: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FileSystemEntryImpl.call_getParent(state, successCallback, errorCallback);
    }

};
