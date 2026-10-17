//! Generated from: webaudio.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AudioWorkletGlobalScopeImpl = @import("impls").AudioWorkletGlobalScope;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const WorkletGlobalScope = @import("interfaces").WorkletGlobalScope;
const AudioWorkletProcessorConstructor = @import("callbacks").AudioWorkletProcessorConstructor;
const MessagePort = @import("interfaces").MessagePort;
const DOMString = @import("typedefs").DOMString;

pub const AudioWorkletGlobalScope = struct {
    pub const Meta = struct {
        pub const name = "AudioWorkletGlobalScope";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = WorkletGlobalScope.State;
        pub const ParentInterface = WorkletGlobalScope;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Global", .value = .{ .identifier_list = &.{ "Worklet", "AudioWorklet" } } },
            .{ .name = "Exposed", .value = .{ .identifier = "AudioWorklet" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .AudioWorklet = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "currentFrame", "get_currentFrame", null },
            .{ "currentTime", "get_currentTime", null },
            .{ "sampleRate", "get_sampleRate", null },
            .{ "renderQuantumSize", "get_renderQuantumSize", null },
            .{ "port", "get_port", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "registerProcessor", "call_registerProcessor", 2 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "registerProcessor",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "currentFrame", "get_currentFrame", null },
            .{ "currentTime", "get_currentTime", null },
            .{ "sampleRate", "get_sampleRate", null },
            .{ "renderQuantumSize", "get_renderQuantumSize", null },
            .{ "port", "get_port", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            currentFrame: u64 = undefined,
            currentTime: f64 = undefined,
            sampleRate: f32 = undefined,
            renderQuantumSize: u32 = undefined,
            port: *runtime.Instance = undefined,
            _internal: ?*AudioWorkletGlobalScopeImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_currentFrame = &get_currentFrame,
        .get_currentTime = &get_currentTime,
        .get_port = &get_port,
        .get_renderQuantumSize = &get_renderQuantumSize,
        .get_sampleRate = &get_sampleRate,

        .call_registerProcessor = &call_registerProcessor,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("AudioWorkletGlobalScope has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(AudioWorkletGlobalScopeImpl, "init") and @hasDecl(AudioWorkletGlobalScopeImpl, "initOwn")) @compileError("AudioWorkletGlobalScopeImpl defines both init and initOwn");
        if (comptime @hasDecl(AudioWorkletGlobalScopeImpl, "init")) return AudioWorkletGlobalScopeImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(AudioWorkletGlobalScopeImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try AudioWorkletGlobalScopeImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(AudioWorkletGlobalScopeImpl, "init")) return false;
        if (comptime @hasDecl(AudioWorkletGlobalScopeImpl, "construction_args")) {
            inline for (AudioWorkletGlobalScopeImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(AudioWorkletGlobalScopeImpl, "deinit") and @hasDecl(AudioWorkletGlobalScopeImpl, "deinitOwn")) @compileError("AudioWorkletGlobalScopeImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(AudioWorkletGlobalScopeImpl, "deinit")) return AudioWorkletGlobalScopeImpl.deinit(instance);
        if (comptime @hasDecl(AudioWorkletGlobalScopeImpl, "deinitOwn")) AudioWorkletGlobalScopeImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "AudioWorkletGlobalScope")) {
            if (comptime @hasDecl(impls.AudioWorkletGlobalScope, "installHooks")) impls.AudioWorkletGlobalScope.installHooks();
        }
    }

    pub fn get_currentFrame(instance: *runtime.Instance) anyerror!u64 {
        return try AudioWorkletGlobalScopeImpl.get_currentFrame(instance);
    }

    pub fn get_currentTime(instance: *runtime.Instance) anyerror!f64 {
        return try AudioWorkletGlobalScopeImpl.get_currentTime(instance);
    }

    pub fn get_sampleRate(instance: *runtime.Instance) anyerror!f32 {
        return try AudioWorkletGlobalScopeImpl.get_sampleRate(instance);
    }

    pub fn get_renderQuantumSize(instance: *runtime.Instance) anyerror!u32 {
        return try AudioWorkletGlobalScopeImpl.get_renderQuantumSize(instance);
    }

    pub fn get_port(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioWorkletGlobalScopeImpl.get_port(instance);
    }

    pub fn call_registerProcessor(instance: *runtime.Instance, name: runtime.DOMString, processorCtor: AudioWorkletProcessorConstructor) anyerror!void {
        return try AudioWorkletGlobalScopeImpl.call_registerProcessor(instance, name, processorCtor);
    }
};
