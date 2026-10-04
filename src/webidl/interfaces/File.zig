//! Generated from: FileAPI.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FileImpl = @import("impls").File;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Blob = @import("interfaces").Blob;
const FilePropertyBag = @import("dictionaries").FilePropertyBag;
const BlobPart = @import("typedefs").BlobPart;
const ReadableStream = @import("interfaces").ReadableStream;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;
const BlobPropertyBag = @import("dictionaries").BlobPropertyBag;

pub const File = struct {
    pub const Meta = struct {
        pub const name = "File";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Blob.State;
        pub const ParentInterface = Blob;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "Serializable" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", null },
            .{ "lastModified", "get_lastModified", null },
            .{ "webkitRelativePath", "get_webkitRelativePath", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "slice",
            "stream",
            "text",
            "arrayBuffer",
            "bytes",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "name", "get_name", null },
            .{ "lastModified", "get_lastModified", null },
            .{ "webkitRelativePath", "get_webkitRelativePath", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            name: typedefs.DOMString = undefined,
            lastModified: i64 = undefined,
            webkitRelativePath: runtime.USVString = undefined,
            _internal: ?*FileImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_lastModified = &get_lastModified,
        .get_name = &get_name,
        .get_webkitRelativePath = &get_webkitRelativePath,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FileImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return FileImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileImpl.deinit(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "File")) {
            if (comptime @hasDecl(impls.File, "installHooks")) impls.File.installHooks();
        }
    }

    // HTML 2.7.1 serializable objects: File is [Serializable].

    /// File's serialization steps, given `value` and `serialized`: its impl's.
    pub fn serializationSteps(value: *runtime.Instance, serialized: *runtime.SerializationRecord) anyerror!void {
        return @import("impls").File.serializationSteps(value, serialized);
    }

    /// File's deserialization steps, given `serialized`, `value` and
    /// `target_realm`: its impl's.
    pub fn deserializationSteps(serialized: *runtime.DeserializationRecord, value: *runtime.Instance, target_realm: runtime.Context) anyerror!void {
        return @import("impls").File.deserializationSteps(serialized, value, target_realm);
    }

    /// HTML StructuredDeserialize steps 22.3 and 24.4: a new instance of
    /// File, created in `target_realm`, set up by its deserialization steps.
    /// Unwrapped: the engine wraps it in `target_realm`.
    fn deserializeNew(serialized: *runtime.DeserializationRecord, target_realm: runtime.Context) anyerror!*runtime.Instance {
        const value = try init(target_realm.allocator, target_realm);
        const generation = runtime.SlabAllocator.generationOf(value);
        errdefer value.releaseIfUnwrapped(generation);
        try deserializationSteps(serialized, value, target_realm);
        return value;
    }

    /// File's serialization and deserialization steps, as an engine finds
    /// them by interface identifier; null while its impl defines none.
    pub const serializable_steps: ?runtime.SerializableSteps = if (has_serializable_steps) .{
        .serialize = &serializationSteps,
        .deserialize = &deserializeNew,
    } else null;

    const has_serializable_steps = blk: {
        const impls = @import("impls");
        if (!@hasDecl(impls, "File")) break :blk false;
        break :blk @hasDecl(impls.File, "serializationSteps") and @hasDecl(impls.File, "deserializationSteps");
    };

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, fileBits: runtime.JSValue, fileName: runtime.USVString, options: webidl.Opt(FilePropertyBag)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try FileImpl.call_constructor(ctx, fileBits, fileName, options);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try FileImpl.get_name(instance);
    }

    pub fn get_lastModified(instance: *runtime.Instance) anyerror!i64 {
        return try FileImpl.get_lastModified(instance);
    }

    pub fn get_webkitRelativePath(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FileImpl.get_webkitRelativePath(instance);
    }
};
