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
const FileSystemHandle = @import("interfaces").FileSystemHandle;
const PermissionState = @import("enums").PermissionState;
const FileSystemCreateWritableOptions = @import("dictionaries").FileSystemCreateWritableOptions;
const FileSystemHandlePermissionDescriptor = @import("dictionaries").FileSystemHandlePermissionDescriptor;
const File = @import("interfaces").File;
const FileSystemHandleKind = @import("enums").FileSystemHandleKind;
const FileSystemSyncAccessHandle = @import("interfaces").FileSystemSyncAccessHandle;
const FileSystemWritableFileStream = @import("interfaces").FileSystemWritableFileStream;
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
        pub const properties = .{};

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
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
        /// Member-level [Exposed] overrides; unlisted members inherit the interface.
        pub const exposed_members = .{
            .{ "createSyncAccessHandle", .{"DedicatedWorker"} },
        };
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
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Make a new instance: the construction chain, this interface's State
    /// and vtable.
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return initChain(allocator, State, &vtable, ctx, .{});
    }

    /// Make a new instance with construction arguments: facts given at
    /// construction, as a C++ constructor's parameters. Each field of `args`
    /// must be taken by an impl on the chain (its `construction_args`).
    pub fn initWith(allocator: std.mem.Allocator, ctx: runtime.Context, args: anytype) !*runtime.Instance {
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("FileSystemFileHandle has no construction argument '" ++ field.name ++ "'");
        }
        return initChain(allocator, State, &vtable, ctx, args);
    }

    /// The construction chain for a descendant's State and vtable, for an
    /// impl that still chains by hand.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return initChain(allocator, StateType, vtable_ptr, ctx, .{});
    }

    /// The construction chain: the parent interface's, then the impl's own
    /// steps (`initOwn`), whose failure unwinds the parent's part and frees
    /// the slot. An impl that still defines `init` chains by hand.
    pub inline fn initChain(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
        args: anytype,
    ) !*runtime.Instance {
        if (comptime @hasDecl(FileSystemFileHandleImpl, "init") and @hasDecl(FileSystemFileHandleImpl, "initOwn")) @compileError("FileSystemFileHandleImpl defines both init and initOwn");
        if (comptime @hasDecl(FileSystemFileHandleImpl, "init")) return FileSystemFileHandleImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(FileSystemFileHandleImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try FileSystemFileHandleImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(FileSystemFileHandleImpl, "init")) return false;
        if (comptime @hasDecl(FileSystemFileHandleImpl, "construction_args")) {
            inline for (FileSystemFileHandleImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return Meta.ParentInterface.takesConstructionArg(name);
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(FileSystemFileHandleImpl, "deinit") and @hasDecl(FileSystemFileHandleImpl, "deinitOwn")) @compileError("FileSystemFileHandleImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(FileSystemFileHandleImpl, "deinit")) return FileSystemFileHandleImpl.deinit(instance);
        if (comptime @hasDecl(FileSystemFileHandleImpl, "deinitOwn")) FileSystemFileHandleImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "FileSystemFileHandle")) {
            if (comptime @hasDecl(impls.FileSystemFileHandle, "installHooks")) impls.FileSystemFileHandle.installHooks();
        }
    }

    // HTML 2.7.1 serializable objects: FileSystemFileHandle is [Serializable].

    /// FileSystemFileHandle's serialization steps, given `value` and `serialized`: its impl's.
    pub fn serializationSteps(value: *runtime.Instance, serialized: *runtime.SerializationRecord) anyerror!void {
        return @import("impls").FileSystemFileHandle.serializationSteps(value, serialized);
    }

    /// FileSystemFileHandle's deserialization steps, given `serialized`, `value` and
    /// `target_realm`: its impl's.
    pub fn deserializationSteps(serialized: *runtime.DeserializationRecord, value: *runtime.Instance, target_realm: runtime.Context) anyerror!void {
        return @import("impls").FileSystemFileHandle.deserializationSteps(serialized, value, target_realm);
    }

    /// HTML StructuredDeserialize steps 22.3 and 24.4: a new instance of
    /// FileSystemFileHandle, created in `target_realm`, set up by its deserialization steps.
    /// Unwrapped: the engine wraps it in `target_realm`.
    fn deserializeNew(serialized: *runtime.DeserializationRecord, target_realm: runtime.Context) anyerror!*runtime.Instance {
        const value = try init(target_realm.allocator, target_realm);
        const generation = runtime.SlabAllocator.generationOf(value);
        errdefer value.releaseIfUnwrapped(generation);
        try deserializationSteps(serialized, value, target_realm);
        return value;
    }

    /// FileSystemFileHandle's serialization and deserialization steps, as an engine finds
    /// them by interface identifier; null while its impl defines none.
    pub const serializable_steps: ?runtime.SerializableSteps = if (has_serializable_steps) .{
        .serialize = &serializationSteps,
        .deserialize = &deserializeNew,
    } else null;

    const has_serializable_steps = blk: {
        const impls = @import("impls");
        if (!@hasDecl(impls, "FileSystemFileHandle")) break :blk false;
        break :blk @hasDecl(impls.FileSystemFileHandle, "serializationSteps") and @hasDecl(impls.FileSystemFileHandle, "deserializationSteps");
    };

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

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_createSyncAccessHandle",
        "call_getFile",
        "call_createWritable",
    };
};
