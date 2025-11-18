//! Generated from: entries-api.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FileSystemDirectoryReaderImpl = @import("impls").FileSystemDirectoryReader;
const FileSystemEntriesCallback = @import("callbacks").FileSystemEntriesCallback;
const ErrorCallback = @import("callbacks").ErrorCallback;

pub const FileSystemDirectoryReader = struct {
    pub const Meta = struct {
        pub const name = "FileSystemDirectoryReader";
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
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(FileSystemDirectoryReader, .{
        .deinit_fn = &deinit_wrapper,

        .call_readEntries = &call_readEntries,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        FileSystemDirectoryReaderImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileSystemDirectoryReaderImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_readEntries(instance: *runtime.Instance, successCallback: FileSystemEntriesCallback, errorCallback: ErrorCallback) anyerror!void {
        
        return try FileSystemDirectoryReaderImpl.call_readEntries(instance, successCallback, errorCallback);
    }

};
