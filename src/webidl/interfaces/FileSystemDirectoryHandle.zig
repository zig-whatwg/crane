//! Generated from: fs.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FileSystemDirectoryHandleImpl = @import("impls").FileSystemDirectoryHandle;
const mixins = @import("mixins");
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
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = FileSystemHandle.State;
        pub const ParentInterface = FileSystemHandle;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getFileHandle", "call_getFileHandle", 1 },
            .{ "getDirectoryHandle", "call_getDirectoryHandle", 1 },
            .{ "removeEntry", "call_removeEntry", 1 },
            .{ "resolve", "call_resolve", 1 },
            .{ "values", "call_values", 0 },
            .{ "getAsyncIterator", "call_getAsyncIterator", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getFileHandle",
            "getDirectoryHandle",
            "removeEntry",
            "resolve",
            "values",
            "getAsyncIterator",
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
        
        /// Async iterable declaration (for Symbol.asyncIterator support)
        pub const async_iterable = .{
            .value_type = "runtime.USVString",
            .key_type = "FileSystemHandle",
            .options_type = null,
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*FileSystemDirectoryHandleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_getAsyncIterator = &call_getAsyncIterator,
        .call_getDirectoryHandle = &call_getDirectoryHandle,
        .call_getFileHandle = &call_getFileHandle,
        .call_removeEntry = &call_removeEntry,
        .call_resolve = &call_resolve,
        .call_values = &call_values,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FileSystemDirectoryHandleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return FileSystemDirectoryHandleImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileSystemDirectoryHandleImpl.deinit(instance);
    }

    pub fn call_removeEntry(instance: *runtime.Instance, name: runtime.USVString, options: webidl.Opt(FileSystemRemoveOptions)) anyerror!runtime.JSValue {
        
        return try FileSystemDirectoryHandleImpl.call_removeEntry(instance, name, options);
    }

    pub fn call_values(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try FileSystemDirectoryHandleImpl.call_values(instance);
    }

    pub fn call_resolve(instance: *runtime.Instance, possibleDescendant: *runtime.Instance) anyerror!runtime.JSValue {
        
        return try FileSystemDirectoryHandleImpl.call_resolve(instance, possibleDescendant);
    }

    pub fn call_getDirectoryHandle(instance: *runtime.Instance, name: runtime.USVString, options: webidl.Opt(FileSystemGetDirectoryOptions)) anyerror!runtime.JSValue {
        
        return try FileSystemDirectoryHandleImpl.call_getDirectoryHandle(instance, name, options);
    }

    pub fn call_getAsyncIterator(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try FileSystemDirectoryHandleImpl.call_getAsyncIterator(instance);
    }

    pub fn call_getFileHandle(instance: *runtime.Instance, name: runtime.USVString, options: webidl.Opt(FileSystemGetFileOptions)) anyerror!runtime.JSValue {
        
        return try FileSystemDirectoryHandleImpl.call_getFileHandle(instance, name, options);
    }

};
