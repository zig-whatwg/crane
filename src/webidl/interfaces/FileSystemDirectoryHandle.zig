//! Generated from: fs.idl
//! Generated at: 2025-11-23T19:17:32Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FileSystemDirectoryHandleImpl = @import("impls").FileSystemDirectoryHandle;
const FileSystemHandle = @import("interfaces").FileSystemHandle;
const FileSystemRemoveOptions = @import("dictionaries").FileSystemRemoveOptions;
const PermissionState = @import("enums").PermissionState;
const FileSystemGetFileOptions = @import("dictionaries").FileSystemGetFileOptions;
const FileSystemHandlePermissionDescriptor = @import("dictionaries").FileSystemHandlePermissionDescriptor;
const FileSystemGetDirectoryOptions = @import("dictionaries").FileSystemGetDirectoryOptions;
const FileSystemHandleKind = @import("enums").FileSystemHandleKind;
const USVString = @import("interfaces").USVString;
const FileSystemFileHandle = @import("interfaces").FileSystemFileHandle;

pub const FileSystemDirectoryHandle = struct {
    pub const Meta = struct {
        pub const name = "FileSystemDirectoryHandle";
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
            .{ "getFileHandle", "call_getFileHandle", 1 },
            .{ "getDirectoryHandle", "call_getDirectoryHandle", 1 },
            .{ "removeEntry", "call_removeEntry", 1 },
            .{ "resolve", "call_resolve", 1 },
            .{ "forEach", "call_forEach", 1 },
            .{ "forEach", "call_forEach", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getFileHandle",
            "getDirectoryHandle",
            "removeEntry",
            "resolve",
            "forEach",
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
        
        /// Iterable declaration (for Symbol.iterator support)
        pub const iterable = .{
            .value_type = "runtime.USVString",
            .key_type = "FileSystemHandle",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {},
    );

    const delegates = .{

        .call_forEach = &call_forEach,
        .call_getDirectoryHandle = &call_getDirectoryHandle,
        .call_getFileHandle = &call_getFileHandle,
        .call_removeEntry = &call_removeEntry,
        .call_resolve = &call_resolve,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FileSystemDirectoryHandleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileSystemDirectoryHandleImpl.deinit(instance);
    }

    pub fn call_getFileHandle(instance: *runtime.Instance, name: runtime.USVString, options: FileSystemGetFileOptions) anyerror!*const anyopaque {
        
        return try FileSystemDirectoryHandleImpl.call_getFileHandle(instance, name, options);
    }

    pub fn call_resolve(instance: *runtime.Instance, possibleDescendant: *runtime.Instance) anyerror!*const anyopaque {
        
        return try FileSystemDirectoryHandleImpl.call_resolve(instance, possibleDescendant);
    }

    pub fn call_forEach(instance: *runtime.Instance, callback: *const anyopaque) anyerror!void {
        
        return try FileSystemDirectoryHandleImpl.call_forEach(instance, callback);
    }

    pub fn call_getDirectoryHandle(instance: *runtime.Instance, name: runtime.USVString, options: FileSystemGetDirectoryOptions) anyerror!*const anyopaque {
        
        return try FileSystemDirectoryHandleImpl.call_getDirectoryHandle(instance, name, options);
    }

    pub fn call_removeEntry(instance: *runtime.Instance, name: runtime.USVString, options: FileSystemRemoveOptions) anyerror!*const anyopaque {
        
        return try FileSystemDirectoryHandleImpl.call_removeEntry(instance, name, options);
    }

};
