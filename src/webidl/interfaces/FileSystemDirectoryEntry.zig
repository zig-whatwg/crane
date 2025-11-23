//! Generated from: entries-api.idl
//! Generated at: 2025-11-23T01:22:15Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FileSystemDirectoryEntryImpl = @import("impls").FileSystemDirectoryEntry;
const FileSystemEntry = @import("interfaces").FileSystemEntry;
const ErrorCallback = @import("callbacks").ErrorCallback;
const FileSystem = @import("interfaces").FileSystem;
const FileSystemEntryCallback = @import("callbacks").FileSystemEntryCallback;
const USVString = @import("interfaces").USVString;
const FileSystemFlags = @import("dictionaries").FileSystemFlags;
const FileSystemDirectoryReader = @import("interfaces").FileSystemDirectoryReader;

pub const FileSystemDirectoryEntry = struct {
    pub const Meta = struct {
        pub const name = "FileSystemDirectoryEntry";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *FileSystemEntry;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "createReader", "call_createReader", 0 },
            .{ "getFile", "call_getFile", 0 },
            .{ "getDirectory", "call_getDirectory", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "createReader",
            "getFile",
            "getDirectory",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "getParent",
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

        .call_createReader = &call_createReader,
        .call_getDirectory = &call_getDirectory,
        .call_getFile = &call_getFile,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FileSystemDirectoryEntryImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileSystemDirectoryEntryImpl.deinit(instance);
    }

    pub fn call_getDirectory(instance: *runtime.Instance, path: runtime.USVString, options: FileSystemFlags, successCallback: FileSystemEntryCallback, errorCallback: ErrorCallback) anyerror!void {
        
        return try FileSystemDirectoryEntryImpl.call_getDirectory(instance, path, options, successCallback, errorCallback);
    }

    pub fn call_getFile(instance: *runtime.Instance, path: runtime.USVString, options: FileSystemFlags, successCallback: FileSystemEntryCallback, errorCallback: ErrorCallback) anyerror!void {
        
        return try FileSystemDirectoryEntryImpl.call_getFile(instance, path, options, successCallback, errorCallback);
    }

    pub fn call_createReader(instance: *runtime.Instance) anyerror!FileSystemDirectoryReader {
        return try FileSystemDirectoryEntryImpl.call_createReader(instance);
    }

};
