//! Generated from: FileAPI.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FileImpl = @import("../impls/File.zig");
const Blob = @import("Blob.zig");

pub const File = struct {
    pub const Meta = struct {
        pub const name = "File";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Blob;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            name: runtime.DOMString = undefined,
            lastModified: i64 = undefined,
            webkitRelativePath: runtime.USVString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(File, .{
        .deinit_fn = &deinit_wrapper,

        .get_lastModified = &get_lastModified,
        .get_name = &get_name,
        .get_size = &get_size,
        .get_type = &get_type,
        .get_webkitRelativePath = &get_webkitRelativePath,

        .call_arrayBuffer = &call_arrayBuffer,
        .call_bytes = &call_bytes,
        .call_slice = &call_slice,
        .call_stream = &call_stream,
        .call_text = &call_text,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        FileImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        FileImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, fileBits: anyopaque, fileName: runtime.USVString, options: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try FileImpl.constructor(state, fileBits, fileName, options);
        
        return instance;
    }

    pub fn get_size(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return FileImpl.get_size(state);
    }

    pub fn get_type(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return FileImpl.get_type(state);
    }

    pub fn get_name(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return FileImpl.get_name(state);
    }

    pub fn get_lastModified(instance: *runtime.Instance) i64 {
        const state = instance.getState(State);
        return FileImpl.get_lastModified(state);
    }

    pub fn get_webkitRelativePath(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return FileImpl.get_webkitRelativePath(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_text(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return FileImpl.call_text(state);
    }

    pub fn call_slice(instance: *runtime.Instance, start: i64, end: i64, contentType: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [Clamp] on start
        const clamped_start = runtime.clamp(start);
        // [Clamp] on end
        const clamped_end = runtime.clamp(end);
        
        return FileImpl.call_slice(state, clamped_start, clamped_end, contentType);
    }

    /// Extended attributes: [NewObject]
    pub fn call_stream(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return FileImpl.call_stream(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_bytes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return FileImpl.call_bytes(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_arrayBuffer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        return FileImpl.call_arrayBuffer(state);
    }

};
