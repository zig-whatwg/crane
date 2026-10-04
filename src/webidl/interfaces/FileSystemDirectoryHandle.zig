//! Generated from: fs.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FileSystemDirectoryHandleImpl = @import("impls").FileSystemDirectoryHandle;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const FileSystemHandle = @import("interfaces").FileSystemHandle;
const FileSystemRemoveOptions = @import("dictionaries").FileSystemRemoveOptions;
const PermissionState = @import("enums").PermissionState;
const FileSystemGetFileOptions = @import("dictionaries").FileSystemGetFileOptions;
const FileSystemHandlePermissionDescriptor = @import("dictionaries").FileSystemHandlePermissionDescriptor;
const FileSystemGetDirectoryOptions = @import("dictionaries").FileSystemGetDirectoryOptions;
const FileSystemHandleKind = @import("enums").FileSystemHandleKind;
const USVString = @import("typedefs").USVString;
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
        pub const properties = .{};

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
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

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
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

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

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "FileSystemDirectoryHandle")) {
            if (comptime @hasDecl(impls.FileSystemDirectoryHandle, "installHooks")) impls.FileSystemDirectoryHandle.installHooks();
        }
    }

    // HTML 2.7.1 serializable objects: FileSystemDirectoryHandle is [Serializable].

    /// FileSystemDirectoryHandle's serialization steps, given `value` and `serialized`: its impl's.
    pub fn serializationSteps(value: *runtime.Instance, serialized: *runtime.SerializationRecord) anyerror!void {
        return @import("impls").FileSystemDirectoryHandle.serializationSteps(value, serialized);
    }

    /// FileSystemDirectoryHandle's deserialization steps, given `serialized`, `value` and
    /// `target_realm`: its impl's.
    pub fn deserializationSteps(serialized: *runtime.DeserializationRecord, value: *runtime.Instance, target_realm: runtime.Context) anyerror!void {
        return @import("impls").FileSystemDirectoryHandle.deserializationSteps(serialized, value, target_realm);
    }

    /// HTML StructuredDeserialize steps 22.3 and 24.4: a new instance of
    /// FileSystemDirectoryHandle, created in `target_realm`, set up by its deserialization steps.
    /// Unwrapped: the engine wraps it in `target_realm`.
    fn deserializeNew(serialized: *runtime.DeserializationRecord, target_realm: runtime.Context) anyerror!*runtime.Instance {
        const value = try init(target_realm.allocator, target_realm);
        const generation = runtime.SlabAllocator.generationOf(value);
        errdefer value.releaseIfUnwrapped(generation);
        try deserializationSteps(serialized, value, target_realm);
        return value;
    }

    /// FileSystemDirectoryHandle's serialization and deserialization steps, as an engine finds
    /// them by interface identifier; null while its impl defines none.
    pub const serializable_steps: ?runtime.SerializableSteps = if (has_serializable_steps) .{
        .serialize = &serializationSteps,
        .deserialize = &deserializeNew,
    } else null;

    const has_serializable_steps = blk: {
        const impls = @import("impls");
        if (!@hasDecl(impls, "FileSystemDirectoryHandle")) break :blk false;
        break :blk @hasDecl(impls.FileSystemDirectoryHandle, "serializationSteps") and @hasDecl(impls.FileSystemDirectoryHandle, "deserializationSteps");
    };

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

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_removeEntry",
        "call_resolve",
        "call_getDirectoryHandle",
        "call_getFileHandle",
    };
};
