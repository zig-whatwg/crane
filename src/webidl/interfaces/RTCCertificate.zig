//! Generated from: webrtc.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const RTCCertificateImpl = @import("impls").RTCCertificate;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EpochTimeStamp = @import("typedefs").EpochTimeStamp;
const RTCDtlsFingerprint = @import("dictionaries").RTCDtlsFingerprint;

pub const RTCCertificate = struct {
    pub const Meta = struct {
        pub const name = "RTCCertificate";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "Serializable" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "expires", "get_expires", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getFingerprints", "call_getFingerprints", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getFingerprints",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "expires", "get_expires", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            expires: typedefs.EpochTimeStamp = undefined,
            _internal: ?*RTCCertificateImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_expires = &get_expires,

        .call_getFingerprints = &call_getFingerprints,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("RTCCertificate has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(RTCCertificateImpl, "init") and @hasDecl(RTCCertificateImpl, "initOwn")) @compileError("RTCCertificateImpl defines both init and initOwn");
        if (comptime @hasDecl(RTCCertificateImpl, "init")) return RTCCertificateImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(RTCCertificateImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try RTCCertificateImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(RTCCertificateImpl, "init")) return false;
        if (comptime @hasDecl(RTCCertificateImpl, "construction_args")) {
            inline for (RTCCertificateImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(RTCCertificateImpl, "deinit") and @hasDecl(RTCCertificateImpl, "deinitOwn")) @compileError("RTCCertificateImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(RTCCertificateImpl, "deinit")) return RTCCertificateImpl.deinit(instance);
        if (comptime @hasDecl(RTCCertificateImpl, "deinitOwn")) RTCCertificateImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "RTCCertificate")) {
            if (comptime @hasDecl(impls.RTCCertificate, "installHooks")) impls.RTCCertificate.installHooks();
        }
    }

    // HTML 2.7.1 serializable objects: RTCCertificate is [Serializable].

    /// RTCCertificate's serialization steps, given `value` and `serialized`: its impl's.
    pub fn serializationSteps(value: *runtime.Instance, serialized: *runtime.SerializationRecord) anyerror!void {
        return @import("impls").RTCCertificate.serializationSteps(value, serialized);
    }

    /// RTCCertificate's deserialization steps, given `serialized`, `value` and
    /// `target_realm`: its impl's.
    pub fn deserializationSteps(serialized: *runtime.DeserializationRecord, value: *runtime.Instance, target_realm: runtime.Context) anyerror!void {
        return @import("impls").RTCCertificate.deserializationSteps(serialized, value, target_realm);
    }

    /// HTML StructuredDeserialize steps 22.3 and 24.4: a new instance of
    /// RTCCertificate, created in `target_realm`, set up by its deserialization steps.
    /// Unwrapped: the engine wraps it in `target_realm`.
    fn deserializeNew(serialized: *runtime.DeserializationRecord, target_realm: runtime.Context) anyerror!*runtime.Instance {
        const value = try init(target_realm.allocator, target_realm);
        const generation = runtime.SlabAllocator.generationOf(value);
        errdefer value.releaseIfUnwrapped(generation);
        try deserializationSteps(serialized, value, target_realm);
        return value;
    }

    /// RTCCertificate's serialization and deserialization steps, as an engine finds
    /// them by interface identifier; null while its impl defines none.
    pub const serializable_steps: ?runtime.SerializableSteps = if (has_serializable_steps) .{
        .serialize = &serializationSteps,
        .deserialize = &deserializeNew,
    } else null;

    const has_serializable_steps = blk: {
        const impls = @import("impls");
        if (!@hasDecl(impls, "RTCCertificate")) break :blk false;
        break :blk @hasDecl(impls.RTCCertificate, "serializationSteps") and @hasDecl(impls.RTCCertificate, "deserializationSteps");
    };

    pub fn get_expires(instance: *runtime.Instance) anyerror!EpochTimeStamp {
        return try RTCCertificateImpl.get_expires(instance);
    }

    pub fn call_getFingerprints(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try RTCCertificateImpl.call_getFingerprints(instance);
    }
};
