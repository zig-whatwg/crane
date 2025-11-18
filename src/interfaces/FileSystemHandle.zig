//! Generated from: fs.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FileSystemHandleImpl = @import("../impls/FileSystemHandle.zig");

pub const FileSystemHandle = struct {
    pub const Meta = struct {
        pub const name = "FileSystemHandle";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
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
            kind: FileSystemHandleKind = undefined,
            name: runtime.USVString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(FileSystemHandle, .{
        .deinit_fn = &deinit_wrapper,

        .get_kind = &get_kind,
        .get_name = &get_name,

        .call_isSameEntry = &call_isSameEntry,
        .call_queryPermission = &call_queryPermission,
        .call_requestPermission = &call_requestPermission,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        FileSystemHandleImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        FileSystemHandleImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_kind(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FileSystemHandleImpl.get_kind(state);
    }

    pub fn get_name(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return FileSystemHandleImpl.get_name(state);
    }

    pub fn call_isSameEntry(instance: *runtime.Instance, other: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FileSystemHandleImpl.call_isSameEntry(state, other);
    }

    pub fn call_queryPermission(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FileSystemHandleImpl.call_queryPermission(state, descriptor);
    }

    pub fn call_requestPermission(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FileSystemHandleImpl.call_requestPermission(state, descriptor);
    }

};
