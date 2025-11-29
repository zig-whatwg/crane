//! Generated from: entries-api.idl
//! Generated at: 2025-11-29T05:01:35Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FileSystemEntryImpl = @import("impls").FileSystemEntry;
const mixins = @import("mixins");
const FileSystemEntryCallback = @import("callbacks").FileSystemEntryCallback;
const USVString = @import("interfaces").USVString;
const FileSystem = @import("interfaces").FileSystem;
const ErrorCallback = @import("callbacks").ErrorCallback;

pub const FileSystemEntry = struct {
    pub const Meta = struct {
        pub const name = "FileSystemEntry";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "isFile", "get_isFile", null },
            .{ "isDirectory", "get_isDirectory", null },
            .{ "name", "get_name", null },
            .{ "fullPath", "get_fullPath", null },
            .{ "filesystem", "get_filesystem", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getParent", "call_getParent", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getParent",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "isFile", "get_isFile", null },
            .{ "isDirectory", "get_isDirectory", null },
            .{ "name", "get_name", null },
            .{ "fullPath", "get_fullPath", null },
            .{ "filesystem", "get_filesystem", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            isFile: bool = undefined,
            isDirectory: bool = undefined,
            name: runtime.USVString = undefined,
            fullPath: runtime.USVString = undefined,
            filesystem: *runtime.Instance = undefined,
            _internal: ?*FileSystemEntryImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_filesystem = &get_filesystem,
        .get_fullPath = &get_fullPath,
        .get_isDirectory = &get_isDirectory,
        .get_isFile = &get_isFile,
        .get_name = &get_name,

        .call_getParent = &call_getParent,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FileSystemEntryImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileSystemEntryImpl.deinit(instance);
    }

    pub fn get_isFile(instance: *runtime.Instance) anyerror!bool {
        return try FileSystemEntryImpl.get_isFile(instance);
    }

    pub fn get_isDirectory(instance: *runtime.Instance) anyerror!bool {
        return try FileSystemEntryImpl.get_isDirectory(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FileSystemEntryImpl.get_name(instance);
    }

    pub fn get_fullPath(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FileSystemEntryImpl.get_fullPath(instance);
    }

    pub fn get_filesystem(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try FileSystemEntryImpl.get_filesystem(instance);
    }

    pub fn call_getParent(instance: *runtime.Instance, successCallback: webidl.Opt(FileSystemEntryCallback), errorCallback: webidl.Opt(ErrorCallback)) anyerror!void {
        
        return try FileSystemEntryImpl.call_getParent(instance, successCallback, errorCallback);
    }

};
