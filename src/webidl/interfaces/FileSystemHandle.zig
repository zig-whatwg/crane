//! Generated from: fs.idl
//! Generated at: 2025-11-25T20:02:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FileSystemHandleImpl = @import("impls").FileSystemHandle;
const PermissionState = @import("enums").PermissionState;
const FileSystemHandleKind = @import("enums").FileSystemHandleKind;
const USVString = @import("interfaces").USVString;
const FileSystemHandlePermissionDescriptor = @import("dictionaries").FileSystemHandlePermissionDescriptor;

pub const FileSystemHandle = struct {
    pub const Meta = struct {
        pub const name = "FileSystemHandle";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
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
            .{ "kind", "get_kind", null },
            .{ "name", "get_name", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "isSameEntry", "call_isSameEntry", 1 },
            .{ "queryPermission", "call_queryPermission", 0 },
            .{ "requestPermission", "call_requestPermission", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "isSameEntry",
            "queryPermission",
            "requestPermission",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "kind", "get_kind", null },
            .{ "name", "get_name", null },
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
            kind: FileSystemHandleKind = undefined,
            name: runtime.USVString = undefined,
            _internal: ?*FileSystemHandleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_kind = &get_kind,
        .get_name = &get_name,

        .call_isSameEntry = &call_isSameEntry,
        .call_queryPermission = &call_queryPermission,
        .call_requestPermission = &call_requestPermission,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FileSystemHandleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileSystemHandleImpl.deinit(instance);
    }

    pub fn get_kind(instance: *runtime.Instance) anyerror!FileSystemHandleKind {
        return try FileSystemHandleImpl.get_kind(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FileSystemHandleImpl.get_name(instance);
    }

    pub fn call_isSameEntry(instance: *runtime.Instance, other: *runtime.Instance) anyerror!*const anyopaque {
        
        return try FileSystemHandleImpl.call_isSameEntry(instance, other);
    }

    pub fn call_queryPermission(instance: *runtime.Instance, descriptor: FileSystemHandlePermissionDescriptor) anyerror!*const anyopaque {
        
        return try FileSystemHandleImpl.call_queryPermission(instance, descriptor);
    }

    pub fn call_requestPermission(instance: *runtime.Instance, descriptor: FileSystemHandlePermissionDescriptor) anyerror!*const anyopaque {
        
        return try FileSystemHandleImpl.call_requestPermission(instance, descriptor);
    }

};
