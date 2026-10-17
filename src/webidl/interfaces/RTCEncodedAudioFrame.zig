//! Generated from: webrtc-encoded-transform.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const RTCEncodedAudioFrameImpl = @import("impls").RTCEncodedAudioFrame;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const RTCEncodedAudioFrameOptions = @import("dictionaries").RTCEncodedAudioFrameOptions;
const RTCEncodedAudioFrameMetadata = @import("dictionaries").RTCEncodedAudioFrameMetadata;

pub const RTCEncodedAudioFrame = struct {
    pub const Meta = struct {
        pub const name = "RTCEncodedAudioFrame";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
            .{ .name = "Serializable" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "data", "get_data", "set_data" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getMetadata", "call_getMetadata", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getMetadata",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "data", "get_data", "set_data" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            data: runtime.ArrayBuffer = undefined,
            _internal: ?*RTCEncodedAudioFrameImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_data = &get_data,

        .set_data = &set_data,

        .call_getMetadata = &call_getMetadata,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("RTCEncodedAudioFrame has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(RTCEncodedAudioFrameImpl, "init") and @hasDecl(RTCEncodedAudioFrameImpl, "initOwn")) @compileError("RTCEncodedAudioFrameImpl defines both init and initOwn");
        if (comptime @hasDecl(RTCEncodedAudioFrameImpl, "init")) return RTCEncodedAudioFrameImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(RTCEncodedAudioFrameImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try RTCEncodedAudioFrameImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(RTCEncodedAudioFrameImpl, "init")) return false;
        if (comptime @hasDecl(RTCEncodedAudioFrameImpl, "construction_args")) {
            inline for (RTCEncodedAudioFrameImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(RTCEncodedAudioFrameImpl, "deinit") and @hasDecl(RTCEncodedAudioFrameImpl, "deinitOwn")) @compileError("RTCEncodedAudioFrameImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(RTCEncodedAudioFrameImpl, "deinit")) return RTCEncodedAudioFrameImpl.deinit(instance);
        if (comptime @hasDecl(RTCEncodedAudioFrameImpl, "deinitOwn")) RTCEncodedAudioFrameImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "RTCEncodedAudioFrame")) {
            if (comptime @hasDecl(impls.RTCEncodedAudioFrame, "installHooks")) impls.RTCEncodedAudioFrame.installHooks();
        }
    }

    // HTML 2.7.1 serializable objects: RTCEncodedAudioFrame is [Serializable].

    /// RTCEncodedAudioFrame's serialization steps, given `value` and `serialized`: its impl's.
    pub fn serializationSteps(value: *runtime.Instance, serialized: *runtime.SerializationRecord) anyerror!void {
        return @import("impls").RTCEncodedAudioFrame.serializationSteps(value, serialized);
    }

    /// RTCEncodedAudioFrame's deserialization steps, given `serialized`, `value` and
    /// `target_realm`: its impl's.
    pub fn deserializationSteps(serialized: *runtime.DeserializationRecord, value: *runtime.Instance, target_realm: runtime.Context) anyerror!void {
        return @import("impls").RTCEncodedAudioFrame.deserializationSteps(serialized, value, target_realm);
    }

    /// HTML StructuredDeserialize steps 22.3 and 24.4: a new instance of
    /// RTCEncodedAudioFrame, created in `target_realm`, set up by its deserialization steps.
    /// Unwrapped: the engine wraps it in `target_realm`.
    fn deserializeNew(serialized: *runtime.DeserializationRecord, target_realm: runtime.Context) anyerror!*runtime.Instance {
        const value = try init(target_realm.allocator, target_realm);
        const generation = runtime.SlabAllocator.generationOf(value);
        errdefer value.releaseIfUnwrapped(generation);
        try deserializationSteps(serialized, value, target_realm);
        return value;
    }

    /// RTCEncodedAudioFrame's serialization and deserialization steps, as an engine finds
    /// them by interface identifier; null while its impl defines none.
    pub const serializable_steps: ?runtime.SerializableSteps = if (has_serializable_steps) .{
        .serialize = &serializationSteps,
        .deserialize = &deserializeNew,
    } else null;

    const has_serializable_steps = blk: {
        const impls = @import("impls");
        if (!@hasDecl(impls, "RTCEncodedAudioFrame")) break :blk false;
        break :blk @hasDecl(impls.RTCEncodedAudioFrame, "serializationSteps") and @hasDecl(impls.RTCEncodedAudioFrame, "deserializationSteps");
    };

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, originalFrame: *runtime.Instance, options: webidl.Opt(RTCEncodedAudioFrameOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try RTCEncodedAudioFrameImpl.call_constructor(ctx, originalFrame, options);
    }

    /// WebIDL interface types: the interface each interface-typed constructor
    /// argument converts to (ConstructorArgs variant - "" for a sole
    /// constructor -, argument index, interface).
    pub const constructor_interface_arguments = .{
        .{ "", 0, "RTCEncodedAudioFrame" },
    };

    pub fn get_data(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try RTCEncodedAudioFrameImpl.get_data(instance);
    }

    pub fn set_data(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        try RTCEncodedAudioFrameImpl.set_data(instance, value);
    }

    pub fn call_getMetadata(instance: *runtime.Instance) anyerror!RTCEncodedAudioFrameMetadata {
        return try RTCEncodedAudioFrameImpl.call_getMetadata(instance);
    }
};
