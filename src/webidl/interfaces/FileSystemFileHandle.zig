//! Generated from: fs.idl
//! Generated at: 2025-11-23T14:26:29Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FileSystemFileHandleImpl = @import("impls").FileSystemFileHandle;
const FileSystemHandle = @import("interfaces").FileSystemHandle;
const PermissionState = @import("enums").PermissionState;
const FileSystemCreateWritableOptions = @import("dictionaries").FileSystemCreateWritableOptions;
const FileSystemHandlePermissionDescriptor = @import("dictionaries").FileSystemHandlePermissionDescriptor;
const File = @import("interfaces").File;
const FileSystemHandleKind = @import("enums").FileSystemHandleKind;
const FileSystemSyncAccessHandle = @import("interfaces").FileSystemSyncAccessHandle;
const FileSystemWritableFileStream = @import("interfaces").FileSystemWritableFileStream;
const USVString = @import("interfaces").USVString;

pub const FileSystemFileHandle = struct {
    pub const Meta = struct {
        pub const name = "FileSystemFileHandle";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *FileSystemHandle;
        pub const MixinTypes = &.{};
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
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "getFile", "call_getFile", 0 },
            .{ "createWritable", "call_createWritable", 0 },
            .{ "createSyncAccessHandle", "call_createSyncAccessHandle", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getFile",
            "createWritable",
            "createSyncAccessHandle",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "isSameEntry",
            "queryPermission",
            "requestPermission",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {},
    );

    const delegates = .{

        .call_createSyncAccessHandle = &call_createSyncAccessHandle,
        .call_createWritable = &call_createWritable,
        .call_getFile = &call_getFile,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FileSystemFileHandleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileSystemFileHandleImpl.deinit(instance);
    }

    pub fn call_getFile(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try FileSystemFileHandleImpl.call_getFile(instance);
    }

    pub fn call_createWritable(instance: *runtime.Instance, options: FileSystemCreateWritableOptions) anyerror!*const anyopaque {
        
        return try FileSystemFileHandleImpl.call_createWritable(instance, options);
    }

    /// Extended attributes: [Exposed=DedicatedWorker]
    pub fn call_createSyncAccessHandle(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try FileSystemFileHandleImpl.call_createSyncAccessHandle(instance);
    }

};
