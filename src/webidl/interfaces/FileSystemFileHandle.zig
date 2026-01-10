//! Generated from: fs.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FileSystemFileHandleImpl = @import("impls").FileSystemFileHandle;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const FileSystemHandle = @import("FileSystemHandle.zig").FileSystemHandle;
const PermissionState = @import("enums").PermissionState;
const FileSystemCreateWritableOptions = @import("dictionaries").FileSystemCreateWritableOptions;
const FileSystemHandlePermissionDescriptor = @import("dictionaries").FileSystemHandlePermissionDescriptor;
const File = @import("File.zig").File;
const FileSystemHandleKind = @import("enums").FileSystemHandleKind;
const FileSystemSyncAccessHandle = @import("FileSystemSyncAccessHandle.zig").FileSystemSyncAccessHandle;
const FileSystemWritableFileStream = @import("FileSystemWritableFileStream.zig").FileSystemWritableFileStream;
const USVString = @import("typedefs").USVString;

pub const FileSystemFileHandle = struct {
    pub const Meta = struct {
        pub const name = "FileSystemFileHandle";
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
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*FileSystemFileHandleImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_createSyncAccessHandle = &call_createSyncAccessHandle,
        .call_createWritable = &call_createWritable,
        .call_getFile = &call_getFile,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FileSystemFileHandleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return FileSystemFileHandleImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileSystemFileHandleImpl.deinit(instance);
    }

    /// Extended attributes: [Exposed=DedicatedWorker]
    pub fn call_createSyncAccessHandle(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try FileSystemFileHandleImpl.call_createSyncAccessHandle(instance);
    }

    pub fn call_getFile(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try FileSystemFileHandleImpl.call_getFile(instance);
    }

    pub fn call_createWritable(instance: *runtime.Instance, options: webidl.Opt(FileSystemCreateWritableOptions)) anyerror!runtime.JSValue {
        
        return try FileSystemFileHandleImpl.call_createWritable(instance, options);
    }

};
