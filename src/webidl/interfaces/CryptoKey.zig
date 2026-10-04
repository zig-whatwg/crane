//! Generated from: webcrypto.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CryptoKeyImpl = @import("impls").CryptoKey;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const KeyType = @import("enums").KeyType;

pub const CryptoKey = struct {
    pub const Meta = struct {
        pub const name = "CryptoKey";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
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
            .{ "type", "get_type", null },
            .{ "extractable", "get_extractable", null },
            .{ "algorithm", "get_algorithm", null },
            .{ "usages", "get_usages", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "type", "get_type", null },
            .{ "extractable", "get_extractable", null },
            .{ "algorithm", "get_algorithm", null },
            .{ "usages", "get_usages", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            type: enums.KeyType = undefined,
            extractable: bool = undefined,
            algorithm: runtime.JSValue = undefined,
            usages: runtime.JSValue = undefined,
            _internal: ?*CryptoKeyImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_algorithm = &get_algorithm,
        .get_extractable = &get_extractable,
        .get_type = &get_type,
        .get_usages = &get_usages,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CryptoKeyImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return CryptoKeyImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CryptoKeyImpl.deinit(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CryptoKey")) {
            if (comptime @hasDecl(impls.CryptoKey, "installHooks")) impls.CryptoKey.installHooks();
        }
    }

    // HTML 2.7.1 serializable objects: CryptoKey is [Serializable].

    /// CryptoKey's serialization steps, given `value` and `serialized`: its impl's.
    pub fn serializationSteps(value: *runtime.Instance, serialized: *runtime.SerializationRecord) anyerror!void {
        return @import("impls").CryptoKey.serializationSteps(value, serialized);
    }

    /// CryptoKey's deserialization steps, given `serialized`, `value` and
    /// `target_realm`: its impl's.
    pub fn deserializationSteps(serialized: *runtime.DeserializationRecord, value: *runtime.Instance, target_realm: runtime.Context) anyerror!void {
        return @import("impls").CryptoKey.deserializationSteps(serialized, value, target_realm);
    }

    /// HTML StructuredDeserialize steps 22.3 and 24.4: a new instance of
    /// CryptoKey, created in `target_realm`, set up by its deserialization steps.
    /// Unwrapped: the engine wraps it in `target_realm`.
    fn deserializeNew(serialized: *runtime.DeserializationRecord, target_realm: runtime.Context) anyerror!*runtime.Instance {
        const value = try init(target_realm.allocator, target_realm);
        const generation = runtime.SlabAllocator.generationOf(value);
        errdefer value.releaseIfUnwrapped(generation);
        try deserializationSteps(serialized, value, target_realm);
        return value;
    }

    /// CryptoKey's serialization and deserialization steps, as an engine finds
    /// them by interface identifier; null while its impl defines none.
    pub const serializable_steps: ?runtime.SerializableSteps = if (has_serializable_steps) .{
        .serialize = &serializationSteps,
        .deserialize = &deserializeNew,
    } else null;

    const has_serializable_steps = blk: {
        const impls = @import("impls");
        if (!@hasDecl(impls, "CryptoKey")) break :blk false;
        break :blk @hasDecl(impls.CryptoKey, "serializationSteps") and @hasDecl(impls.CryptoKey, "deserializationSteps");
    };

    pub fn get_type(instance: *runtime.Instance) anyerror!KeyType {
        return try CryptoKeyImpl.get_type(instance);
    }

    pub fn get_extractable(instance: *runtime.Instance) anyerror!bool {
        return try CryptoKeyImpl.get_extractable(instance);
    }

    pub fn get_algorithm(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try CryptoKeyImpl.get_algorithm(instance);
    }

    pub fn get_usages(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try CryptoKeyImpl.get_usages(instance);
    }
};
