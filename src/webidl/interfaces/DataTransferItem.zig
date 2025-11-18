//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DataTransferItemImpl = @import("impls").DataTransferItem;
const Promise<FileSystemHandle?> = @import("interfaces").Promise<FileSystemHandle?>;
const FunctionStringCallback = @import("callbacks").FunctionStringCallback;
const File = @import("interfaces").File;
const FileSystemEntry = @import("interfaces").FileSystemEntry;

pub const DataTransferItem = struct {
    pub const Meta = struct {
        pub const name = "DataTransferItem";
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
            kind: runtime.DOMString = undefined,
            type: runtime.DOMString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DataTransferItem, .{
        .deinit_fn = &deinit_wrapper,

        .get_kind = &get_kind,
        .get_type = &get_type,

        .call_getAsFile = &call_getAsFile,
        .call_getAsFileSystemHandle = &call_getAsFileSystemHandle,
        .call_getAsString = &call_getAsString,
        .call_webkitGetAsEntry = &call_webkitGetAsEntry,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        DataTransferItemImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DataTransferItemImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_kind(instance: *runtime.Instance) anyerror!DOMString {
        return try DataTransferItemImpl.get_kind(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!DOMString {
        return try DataTransferItemImpl.get_type(instance);
    }

    pub fn call_getAsString(instance: *runtime.Instance, _callback: anyopaque) anyerror!void {
        
        return try DataTransferItemImpl.call_getAsString(instance, _callback);
    }

    pub fn call_getAsFileSystemHandle(instance: *runtime.Instance) anyerror!anyopaque {
        return try DataTransferItemImpl.call_getAsFileSystemHandle(instance);
    }

    pub fn call_webkitGetAsEntry(instance: *runtime.Instance) anyerror!anyopaque {
        return try DataTransferItemImpl.call_webkitGetAsEntry(instance);
    }

    pub fn call_getAsFile(instance: *runtime.Instance) anyerror!anyopaque {
        return try DataTransferItemImpl.call_getAsFile(instance);
    }

};
