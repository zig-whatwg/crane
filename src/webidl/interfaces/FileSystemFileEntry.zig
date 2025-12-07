//! Generated from: entries-api.idl
//! Generated at: 2025-12-07T20:02:43Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const FileSystemFileEntryImpl = @import("impls").FileSystemFileEntry;
const mixins = @import("mixins");
const FileSystemEntry = @import("interfaces").FileSystemEntry;
const FileSystem = @import("interfaces").FileSystem;
const ErrorCallback = @import("callbacks").ErrorCallback;
const FileCallback = @import("callbacks").FileCallback;
const FileSystemEntryCallback = @import("callbacks").FileSystemEntryCallback;
const USVString = @import("interfaces").USVString;

pub const FileSystemFileEntry = struct {
    pub const Meta = struct {
        pub const name = "FileSystemFileEntry";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = FileSystemEntry.State;
        pub const ParentInterface = FileSystemEntry;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "file", "call_file", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "file",
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
        struct {
            _internal: ?*FileSystemFileEntryImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_file = &call_file,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FileSystemFileEntryImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileSystemFileEntryImpl.deinit(instance);
    }

    pub fn call_file(instance: *runtime.Instance, successCallback: FileCallback, errorCallback: webidl.Opt(ErrorCallback)) anyerror!void {
        
        return try FileSystemFileEntryImpl.call_file(instance, successCallback, errorCallback);
    }

};
