//! Generated from: webaudio.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AudioBufferImpl = @import("impls").AudioBuffer;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const AudioBufferOptions = @import("dictionaries").AudioBufferOptions;

pub const AudioBuffer = struct {
    pub const Meta = struct {
        pub const name = "AudioBuffer";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "sampleRate", "get_sampleRate", null },
            .{ "length", "get_length", null },
            .{ "duration", "get_duration", null },
            .{ "numberOfChannels", "get_numberOfChannels", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getChannelData", "call_getChannelData", 1 },
            .{ "copyFromChannel", "call_copyFromChannel", 2 },
            .{ "copyToChannel", "call_copyToChannel", 2 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getChannelData",
            "copyFromChannel",
            "copyToChannel",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "sampleRate", "get_sampleRate", null },
            .{ "length", "get_length", null },
            .{ "duration", "get_duration", null },
            .{ "numberOfChannels", "get_numberOfChannels", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            sampleRate: f32 = undefined,
            length: u32 = undefined,
            duration: f64 = undefined,
            numberOfChannels: u32 = undefined,
            _internal: ?*AudioBufferImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_duration = &get_duration,
        .get_length = &get_length,
        .get_numberOfChannels = &get_numberOfChannels,
        .get_sampleRate = &get_sampleRate,

        .call_copyFromChannel = &call_copyFromChannel,
        .call_copyToChannel = &call_copyToChannel,
        .call_getChannelData = &call_getChannelData,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("AudioBuffer has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(AudioBufferImpl, "init") and @hasDecl(AudioBufferImpl, "initOwn")) @compileError("AudioBufferImpl defines both init and initOwn");
        if (comptime @hasDecl(AudioBufferImpl, "init")) return AudioBufferImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(AudioBufferImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try AudioBufferImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(AudioBufferImpl, "init")) return false;
        if (comptime @hasDecl(AudioBufferImpl, "construction_args")) {
            inline for (AudioBufferImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(AudioBufferImpl, "deinit") and @hasDecl(AudioBufferImpl, "deinitOwn")) @compileError("AudioBufferImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(AudioBufferImpl, "deinit")) return AudioBufferImpl.deinit(instance);
        if (comptime @hasDecl(AudioBufferImpl, "deinitOwn")) AudioBufferImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "AudioBuffer")) {
            if (comptime @hasDecl(impls.AudioBuffer, "installHooks")) impls.AudioBuffer.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 1;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, options: AudioBufferOptions) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try AudioBufferImpl.call_constructor(ctx, options);
    }

    pub fn get_sampleRate(instance: *runtime.Instance) anyerror!f32 {
        return try AudioBufferImpl.get_sampleRate(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try AudioBufferImpl.get_length(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!f64 {
        return try AudioBufferImpl.get_duration(instance);
    }

    pub fn get_numberOfChannels(instance: *runtime.Instance) anyerror!u32 {
        return try AudioBufferImpl.get_numberOfChannels(instance);
    }

    pub fn call_getChannelData(instance: *runtime.Instance, channel: u32) anyerror!runtime.JSValue {
        return try AudioBufferImpl.call_getChannelData(instance, channel);
    }

    pub fn call_copyToChannel(instance: *runtime.Instance, source: runtime.JSValue, channelNumber: u32, bufferOffset: webidl.Opt(u32)) anyerror!void {
        return try AudioBufferImpl.call_copyToChannel(instance, source, channelNumber, bufferOffset);
    }

    pub fn call_copyFromChannel(instance: *runtime.Instance, destination: runtime.JSValue, channelNumber: u32, bufferOffset: webidl.Opt(u32)) anyerror!void {
        return try AudioBufferImpl.call_copyFromChannel(instance, destination, channelNumber, bufferOffset);
    }
};
