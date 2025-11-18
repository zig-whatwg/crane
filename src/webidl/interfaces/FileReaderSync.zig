//! Generated from: FileAPI.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FileReaderSyncImpl = @import("impls").FileReaderSync;
const ArrayBuffer = @import("interfaces").ArrayBuffer;
const Blob = @import("interfaces").Blob;

pub const FileReaderSync = struct {
    pub const Meta = struct {
        pub const name = "FileReaderSync";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "DedicatedWorker", "SharedWorker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .DedicatedWorker = true,
            .SharedWorker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(FileReaderSync, .{
        .deinit_fn = &deinit_wrapper,

        .call_readAsArrayBuffer = &call_readAsArrayBuffer,
        .call_readAsBinaryString = &call_readAsBinaryString,
        .call_readAsDataURL = &call_readAsDataURL,
        .call_readAsText = &call_readAsText,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        FileReaderSyncImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileReaderSyncImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try FileReaderSyncImpl.constructor(instance);
        
        return instance;
    }

    pub fn call_readAsArrayBuffer(instance: *runtime.Instance, blob: Blob) anyerror!anyopaque {
        
        return try FileReaderSyncImpl.call_readAsArrayBuffer(instance, blob);
    }

    pub fn call_readAsBinaryString(instance: *runtime.Instance, blob: Blob) anyerror!DOMString {
        
        return try FileReaderSyncImpl.call_readAsBinaryString(instance, blob);
    }

    pub fn call_readAsDataURL(instance: *runtime.Instance, blob: Blob) anyerror!DOMString {
        
        return try FileReaderSyncImpl.call_readAsDataURL(instance, blob);
    }

    pub fn call_readAsText(instance: *runtime.Instance, blob: Blob, encoding: DOMString) anyerror!DOMString {
        
        return try FileReaderSyncImpl.call_readAsText(instance, blob, encoding);
    }

};
