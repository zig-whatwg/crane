//! Generated from: entries-api.idl
//! Generated at: 2025-11-23T01:22:15Z
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
        pub const is_mixin = false;
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
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "readEntries", "call_readEntries", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "readEntries",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
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

        .call_readEntries = &call_readEntries,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FileSystemDirectoryReaderImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileSystemDirectoryReaderImpl.deinit(instance);
    }

    pub fn call_readEntries(instance: *runtime.Instance, successCallback: FileSystemEntriesCallback, errorCallback: ErrorCallback) anyerror!void {
        
        return try FileSystemDirectoryReaderImpl.call_readEntries(instance, successCallback, errorCallback);
    }

};
