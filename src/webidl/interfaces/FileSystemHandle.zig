//! Generated from: fs.idl
//! Generated at: 2025-11-18T18:28:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FileSystemHandleImpl = @import("impls").FileSystemHandle;
const FileSystemHandlePermissionDescriptor = @import("dictionaries").FileSystemHandlePermissionDescriptor;
const FileSystemHandleKind = @import("enums").FileSystemHandleKind;
const Promise<boolean> = @import("interfaces").Promise<boolean>;
const Promise<PermissionState> = @import("interfaces").Promise<PermissionState>;

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
        
        // Initialize the instance (Impl receives full instance)
        FileSystemHandleImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileSystemHandleImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_kind(instance: *runtime.Instance) anyerror!FileSystemHandleKind {
        return try FileSystemHandleImpl.get_kind(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FileSystemHandleImpl.get_name(instance);
    }

    pub fn call_isSameEntry(instance: *runtime.Instance, other: FileSystemHandle) anyerror!anyopaque {
        
        return try FileSystemHandleImpl.call_isSameEntry(instance, other);
    }

    pub fn call_queryPermission(instance: *runtime.Instance, descriptor: FileSystemHandlePermissionDescriptor) anyerror!anyopaque {
        
        return try FileSystemHandleImpl.call_queryPermission(instance, descriptor);
    }

    pub fn call_requestPermission(instance: *runtime.Instance, descriptor: FileSystemHandlePermissionDescriptor) anyerror!anyopaque {
        
        return try FileSystemHandleImpl.call_requestPermission(instance, descriptor);
    }

};
