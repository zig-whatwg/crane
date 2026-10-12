//! Generated from: webcodecs.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AudioDataImpl = @import("impls").AudioData;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const AllowSharedBufferSource = @import("typedefs").AllowSharedBufferSource;
const AudioDataInit = @import("dictionaries").AudioDataInit;
const AudioDataCopyToOptions = @import("dictionaries").AudioDataCopyToOptions;
const AudioSampleFormat = @import("enums").AudioSampleFormat;

pub const AudioData = struct {
    pub const Meta = struct {
        pub const name = "AudioData";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
            .{ .name = "Serializable" },
            .{ .name = "Transferable" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "format", "get_format", null },
            .{ "sampleRate", "get_sampleRate", null },
            .{ "numberOfFrames", "get_numberOfFrames", null },
            .{ "numberOfChannels", "get_numberOfChannels", null },
            .{ "duration", "get_duration", null },
            .{ "timestamp", "get_timestamp", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "allocationSize", "call_allocationSize", 1 },
            .{ "copyTo", "call_copyTo", 2 },
            .{ "clone", "call_clone", 0 },
            .{ "close", "call_close", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "allocationSize",
            "copyTo",
            "clone",
            "close",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "format", "get_format", null },
            .{ "sampleRate", "get_sampleRate", null },
            .{ "numberOfFrames", "get_numberOfFrames", null },
            .{ "numberOfChannels", "get_numberOfChannels", null },
            .{ "duration", "get_duration", null },
            .{ "timestamp", "get_timestamp", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            format: ?enums.AudioSampleFormat = null,
            sampleRate: f32 = undefined,
            numberOfFrames: u32 = undefined,
            numberOfChannels: u32 = undefined,
            duration: u64 = undefined,
            timestamp: i64 = undefined,
            _internal: ?*AudioDataImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_duration = &get_duration,
        .get_format = &get_format,
        .get_numberOfChannels = &get_numberOfChannels,
        .get_numberOfFrames = &get_numberOfFrames,
        .get_sampleRate = &get_sampleRate,
        .get_timestamp = &get_timestamp,

        .call_allocationSize = &call_allocationSize,
        .call_clone = &call_clone,
        .call_close = &call_close,
        .call_copyTo = &call_copyTo,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("AudioData has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(AudioDataImpl, "init") and @hasDecl(AudioDataImpl, "initOwn")) @compileError("AudioDataImpl defines both init and initOwn");
        if (comptime @hasDecl(AudioDataImpl, "init")) return AudioDataImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(AudioDataImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try AudioDataImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(AudioDataImpl, "init")) return false;
        if (comptime @hasDecl(AudioDataImpl, "construction_args")) {
            inline for (AudioDataImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(AudioDataImpl, "deinit") and @hasDecl(AudioDataImpl, "deinitOwn")) @compileError("AudioDataImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(AudioDataImpl, "deinit")) return AudioDataImpl.deinit(instance);
        if (comptime @hasDecl(AudioDataImpl, "deinitOwn")) AudioDataImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "AudioData")) {
            if (comptime @hasDecl(impls.AudioData, "installHooks")) impls.AudioData.installHooks();
        }
    }

    // HTML 2.7.1 serializable objects: AudioData is [Serializable].

    /// AudioData's serialization steps, given `value` and `serialized`: its impl's.
    pub fn serializationSteps(value: *runtime.Instance, serialized: *runtime.SerializationRecord) anyerror!void {
        return @import("impls").AudioData.serializationSteps(value, serialized);
    }

    /// AudioData's deserialization steps, given `serialized`, `value` and
    /// `target_realm`: its impl's.
    pub fn deserializationSteps(serialized: *runtime.DeserializationRecord, value: *runtime.Instance, target_realm: runtime.Context) anyerror!void {
        return @import("impls").AudioData.deserializationSteps(serialized, value, target_realm);
    }

    /// HTML StructuredDeserialize steps 22.3 and 24.4: a new instance of
    /// AudioData, created in `target_realm`, set up by its deserialization steps.
    /// Unwrapped: the engine wraps it in `target_realm`.
    fn deserializeNew(serialized: *runtime.DeserializationRecord, target_realm: runtime.Context) anyerror!*runtime.Instance {
        const value = try init(target_realm.allocator, target_realm);
        const generation = runtime.SlabAllocator.generationOf(value);
        errdefer value.releaseIfUnwrapped(generation);
        try deserializationSteps(serialized, value, target_realm);
        return value;
    }

    /// AudioData's serialization and deserialization steps, as an engine finds
    /// them by interface identifier; null while its impl defines none.
    pub const serializable_steps: ?runtime.SerializableSteps = if (has_serializable_steps) .{
        .serialize = &serializationSteps,
        .deserialize = &deserializeNew,
    } else null;

    const has_serializable_steps = blk: {
        const impls = @import("impls");
        if (!@hasDecl(impls, "AudioData")) break :blk false;
        break :blk @hasDecl(impls.AudioData, "serializationSteps") and @hasDecl(impls.AudioData, "deserializationSteps");
    };

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, init_data: AudioDataInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try AudioDataImpl.call_constructor(ctx, init_data);
    }

    pub fn get_format(instance: *runtime.Instance) anyerror!?AudioSampleFormat {
        return try AudioDataImpl.get_format(instance);
    }

    pub fn get_sampleRate(instance: *runtime.Instance) anyerror!f32 {
        return try AudioDataImpl.get_sampleRate(instance);
    }

    pub fn get_numberOfFrames(instance: *runtime.Instance) anyerror!u32 {
        return try AudioDataImpl.get_numberOfFrames(instance);
    }

    pub fn get_numberOfChannels(instance: *runtime.Instance) anyerror!u32 {
        return try AudioDataImpl.get_numberOfChannels(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!u64 {
        return try AudioDataImpl.get_duration(instance);
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyerror!i64 {
        return try AudioDataImpl.get_timestamp(instance);
    }

    pub fn call_allocationSize(instance: *runtime.Instance, options: AudioDataCopyToOptions) anyerror!u32 {
        return try AudioDataImpl.call_allocationSize(instance, options);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try AudioDataImpl.call_close(instance);
    }

    pub fn call_copyTo(instance: *runtime.Instance, destination: AllowSharedBufferSource, options: AudioDataCopyToOptions) anyerror!void {
        return try AudioDataImpl.call_copyTo(instance, destination, options);
    }

    pub fn call_clone(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioDataImpl.call_clone(instance);
    }
};
