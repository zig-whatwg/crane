//! Generated from: webaudio.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AudioProcessingEventImpl = @import("impls").AudioProcessingEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Event = @import("interfaces").Event;
const DOMString = @import("typedefs").DOMString;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const AudioBuffer = @import("interfaces").AudioBuffer;
const EventInit = @import("dictionaries").EventInit;
const AudioProcessingEventInit = @import("dictionaries").AudioProcessingEventInit;

pub const AudioProcessingEvent = struct {
    pub const Meta = struct {
        pub const name = "AudioProcessingEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Event.State;
        pub const ParentInterface = Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "playbackTime", "get_playbackTime", null },
            .{ "inputBuffer", "get_inputBuffer", null },
            .{ "outputBuffer", "get_outputBuffer", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "playbackTime", "get_playbackTime", null },
            .{ "inputBuffer", "get_inputBuffer", null },
            .{ "outputBuffer", "get_outputBuffer", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            playbackTime: f64 = undefined,
            inputBuffer: *runtime.Instance = undefined,
            outputBuffer: *runtime.Instance = undefined,
            _internal: ?*AudioProcessingEventImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_inputBuffer = &get_inputBuffer,
        .get_outputBuffer = &get_outputBuffer,
        .get_playbackTime = &get_playbackTime,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("AudioProcessingEvent has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(AudioProcessingEventImpl, "init") and @hasDecl(AudioProcessingEventImpl, "initOwn")) @compileError("AudioProcessingEventImpl defines both init and initOwn");
        if (comptime @hasDecl(AudioProcessingEventImpl, "init")) return AudioProcessingEventImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(AudioProcessingEventImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try AudioProcessingEventImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(AudioProcessingEventImpl, "init")) return false;
        if (comptime @hasDecl(AudioProcessingEventImpl, "construction_args")) {
            inline for (AudioProcessingEventImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(AudioProcessingEventImpl, "deinit") and @hasDecl(AudioProcessingEventImpl, "deinitOwn")) @compileError("AudioProcessingEventImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(AudioProcessingEventImpl, "deinit")) return AudioProcessingEventImpl.deinit(instance);
        if (comptime @hasDecl(AudioProcessingEventImpl, "deinitOwn")) AudioProcessingEventImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "AudioProcessingEvent")) {
            if (comptime @hasDecl(impls.AudioProcessingEvent, "installHooks")) impls.AudioProcessingEvent.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 2;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: AudioProcessingEventInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try AudioProcessingEventImpl.call_constructor(ctx, @"type", eventInitDict);
    }

    pub fn get_playbackTime(instance: *runtime.Instance) anyerror!f64 {
        return try AudioProcessingEventImpl.get_playbackTime(instance);
    }

    pub fn get_inputBuffer(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioProcessingEventImpl.get_inputBuffer(instance);
    }

    pub fn get_outputBuffer(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try AudioProcessingEventImpl.get_outputBuffer(instance);
    }
};
