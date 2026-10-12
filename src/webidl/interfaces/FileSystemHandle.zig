//! Generated from: fs.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FileSystemHandleImpl = @import("impls").FileSystemHandle;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const PermissionState = @import("enums").PermissionState;
const FileSystemHandleKind = @import("enums").FileSystemHandleKind;
const USVString = @import("typedefs").USVString;
const FileSystemHandlePermissionDescriptor = @import("dictionaries").FileSystemHandlePermissionDescriptor;

pub const FileSystemHandle = struct {
    pub const Meta = struct {
        pub const name = "FileSystemHandle";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "kind", "get_kind", null },
            .{ "name", "get_name", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            kind: enums.FileSystemHandleKind = undefined,
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
            if (comptime !takesConstructionArg(field.name)) @compileError("FileSystemHandle has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(FileSystemHandleImpl, "init") and @hasDecl(FileSystemHandleImpl, "initOwn")) @compileError("FileSystemHandleImpl defines both init and initOwn");
        if (comptime @hasDecl(FileSystemHandleImpl, "init")) return FileSystemHandleImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(FileSystemHandleImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try FileSystemHandleImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(FileSystemHandleImpl, "init")) return false;
        if (comptime @hasDecl(FileSystemHandleImpl, "construction_args")) {
            inline for (FileSystemHandleImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return false;
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(FileSystemHandleImpl, "deinit") and @hasDecl(FileSystemHandleImpl, "deinitOwn")) @compileError("FileSystemHandleImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(FileSystemHandleImpl, "deinit")) return FileSystemHandleImpl.deinit(instance);
        if (comptime @hasDecl(FileSystemHandleImpl, "deinitOwn")) FileSystemHandleImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "FileSystemHandle")) {
            if (comptime @hasDecl(impls.FileSystemHandle, "installHooks")) impls.FileSystemHandle.installHooks();
        }
    }

    // HTML 2.7.1 serializable objects: FileSystemHandle is [Serializable].

    /// FileSystemHandle's serialization steps, given `value` and `serialized`: its impl's.
    pub fn serializationSteps(value: *runtime.Instance, serialized: *runtime.SerializationRecord) anyerror!void {
        return @import("impls").FileSystemHandle.serializationSteps(value, serialized);
    }

    /// FileSystemHandle's deserialization steps, given `serialized`, `value` and
    /// `target_realm`: its impl's.
    pub fn deserializationSteps(serialized: *runtime.DeserializationRecord, value: *runtime.Instance, target_realm: runtime.Context) anyerror!void {
        return @import("impls").FileSystemHandle.deserializationSteps(serialized, value, target_realm);
    }

    /// HTML StructuredDeserialize steps 22.3 and 24.4: a new instance of
    /// FileSystemHandle, created in `target_realm`, set up by its deserialization steps.
    /// Unwrapped: the engine wraps it in `target_realm`.
    fn deserializeNew(serialized: *runtime.DeserializationRecord, target_realm: runtime.Context) anyerror!*runtime.Instance {
        const value = try init(target_realm.allocator, target_realm);
        const generation = runtime.SlabAllocator.generationOf(value);
        errdefer value.releaseIfUnwrapped(generation);
        try deserializationSteps(serialized, value, target_realm);
        return value;
    }

    /// FileSystemHandle's serialization and deserialization steps, as an engine finds
    /// them by interface identifier; null while its impl defines none.
    pub const serializable_steps: ?runtime.SerializableSteps = if (has_serializable_steps) .{
        .serialize = &serializationSteps,
        .deserialize = &deserializeNew,
    } else null;

    const has_serializable_steps = blk: {
        const impls = @import("impls");
        if (!@hasDecl(impls, "FileSystemHandle")) break :blk false;
        break :blk @hasDecl(impls.FileSystemHandle, "serializationSteps") and @hasDecl(impls.FileSystemHandle, "deserializationSteps");
    };

    pub fn get_kind(instance: *runtime.Instance) anyerror!FileSystemHandleKind {
        return try FileSystemHandleImpl.get_kind(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FileSystemHandleImpl.get_name(instance);
    }

    pub fn call_queryPermission(instance: *runtime.Instance, descriptor: webidl.Opt(FileSystemHandlePermissionDescriptor)) anyerror!runtime.JSValue {
        return try FileSystemHandleImpl.call_queryPermission(instance, descriptor);
    }

    pub fn call_isSameEntry(instance: *runtime.Instance, other: *runtime.Instance) anyerror!runtime.JSValue {
        return try FileSystemHandleImpl.call_isSameEntry(instance, other);
    }

    pub fn call_requestPermission(instance: *runtime.Instance, descriptor: webidl.Opt(FileSystemHandlePermissionDescriptor)) anyerror!runtime.JSValue {
        return try FileSystemHandleImpl.call_requestPermission(instance, descriptor);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_queryPermission",
        "call_isSameEntry",
        "call_requestPermission",
    };
};
