//! Generated from: mediastream-recording.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MediaRecorderImpl = @import("impls").MediaRecorder;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const BitrateMode = @import("enums").BitrateMode;
const MediaRecorderOptions = @import("dictionaries").MediaRecorderOptions;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const RecordingState = @import("enums").RecordingState;
const MediaStream = @import("interfaces").MediaStream;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const MediaRecorder = struct {
    pub const Meta = struct {
        pub const name = "MediaRecorder";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "stream", "get_stream", null },
            .{ "mimeType", "get_mimeType", null },
            .{ "state", "get_state", null },
            .{ "onstart", "get_onstart", "set_onstart" },
            .{ "onstop", "get_onstop", "set_onstop" },
            .{ "ondataavailable", "get_ondataavailable", "set_ondataavailable" },
            .{ "onpause", "get_onpause", "set_onpause" },
            .{ "onresume", "get_onresume", "set_onresume" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "videoBitsPerSecond", "get_videoBitsPerSecond", null },
            .{ "audioBitsPerSecond", "get_audioBitsPerSecond", null },
            .{ "audioBitrateMode", "get_audioBitrateMode", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "start", "call_start", 0 },
            .{ "stop", "call_stop", 0 },
            .{ "pause", "call_pause", 0 },
            .{ "resume", "call_resume", 0 },
            .{ "requestData", "call_requestData", 0 },
        };

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "isTypeSupported", "call_static_isTypeSupported", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "start",
            "stop",
            "pause",
            "resume",
            "requestData",
            "isTypeSupported",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "stream", "get_stream", null },
            .{ "mimeType", "get_mimeType", null },
            .{ "state", "get_state", null },
            .{ "onstart", "get_onstart", "set_onstart" },
            .{ "onstop", "get_onstop", "set_onstop" },
            .{ "ondataavailable", "get_ondataavailable", "set_ondataavailable" },
            .{ "onpause", "get_onpause", "set_onpause" },
            .{ "onresume", "get_onresume", "set_onresume" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "videoBitsPerSecond", "get_videoBitsPerSecond", null },
            .{ "audioBitsPerSecond", "get_audioBitsPerSecond", null },
            .{ "audioBitrateMode", "get_audioBitrateMode", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            stream: *runtime.Instance = undefined,
            mimeType: runtime.DOMString = undefined,
            state: enums.RecordingState = undefined,
            onstart: typedefs.EventHandler = undefined,
            onstop: typedefs.EventHandler = undefined,
            ondataavailable: typedefs.EventHandler = undefined,
            onpause: typedefs.EventHandler = undefined,
            onresume: typedefs.EventHandler = undefined,
            onerror: typedefs.EventHandler = undefined,
            videoBitsPerSecond: u32 = undefined,
            audioBitsPerSecond: u32 = undefined,
            audioBitrateMode: enums.BitrateMode = undefined,
            _internal: ?*MediaRecorderImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_audioBitrateMode = &get_audioBitrateMode,
        .get_audioBitsPerSecond = &get_audioBitsPerSecond,
        .get_mimeType = &get_mimeType,
        .get_ondataavailable = &get_ondataavailable,
        .get_onerror = &get_onerror,
        .get_onpause = &get_onpause,
        .get_onresume = &get_onresume,
        .get_onstart = &get_onstart,
        .get_onstop = &get_onstop,
        .get_state = &get_state,
        .get_stream = &get_stream,
        .get_videoBitsPerSecond = &get_videoBitsPerSecond,

        .set_ondataavailable = &set_ondataavailable,
        .set_onerror = &set_onerror,
        .set_onpause = &set_onpause,
        .set_onresume = &set_onresume,
        .set_onstart = &set_onstart,
        .set_onstop = &set_onstop,

        .call_pause = &call_pause,
        .call_requestData = &call_requestData,
        .call_resume = &call_resume,
        .call_start = &call_start,
        .call_stop = &call_stop,

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
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("MediaRecorder has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(MediaRecorderImpl, "init") and @hasDecl(MediaRecorderImpl, "initOwn")) @compileError("MediaRecorderImpl defines both init and initOwn");
        if (comptime @hasDecl(MediaRecorderImpl, "init")) return MediaRecorderImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(MediaRecorderImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try MediaRecorderImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(MediaRecorderImpl, "init")) return false;
        if (comptime @hasDecl(MediaRecorderImpl, "construction_args")) {
            inline for (MediaRecorderImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(MediaRecorderImpl, "deinit") and @hasDecl(MediaRecorderImpl, "deinitOwn")) @compileError("MediaRecorderImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(MediaRecorderImpl, "deinit")) return MediaRecorderImpl.deinit(instance);
        if (comptime @hasDecl(MediaRecorderImpl, "deinitOwn")) MediaRecorderImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "MediaRecorder")) {
            if (comptime @hasDecl(impls.MediaRecorder, "installHooks")) impls.MediaRecorder.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 1;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, stream: *runtime.Instance, options: webidl.Opt(MediaRecorderOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try MediaRecorderImpl.call_constructor(ctx, stream, options);
    }

    /// WebIDL interface types: the interface each interface-typed constructor
    /// argument converts to (ConstructorArgs variant - "" for a sole
    /// constructor -, argument index, interface).
    pub const constructor_interface_arguments = .{
        .{ "", 0, "MediaStream" },
    };

    pub fn get_stream(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try MediaRecorderImpl.get_stream(instance);
    }

    pub fn get_mimeType(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try MediaRecorderImpl.get_mimeType(instance);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!RecordingState {
        return try MediaRecorderImpl.get_state(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onstart(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(MediaRecorderImpl, "get_onstart")) return try MediaRecorderImpl.get_onstart(instance);
        return event_handlers.value(EventHandler, instance, "onstart");
    }

    pub fn set_onstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(MediaRecorderImpl, "set_onstart")) return try MediaRecorderImpl.set_onstart(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onstart", value);
    }

    pub fn get_onstop(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(MediaRecorderImpl, "get_onstop")) return try MediaRecorderImpl.get_onstop(instance);
        return event_handlers.value(EventHandler, instance, "onstop");
    }

    pub fn set_onstop(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(MediaRecorderImpl, "set_onstop")) return try MediaRecorderImpl.set_onstop(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onstop", value);
    }

    pub fn get_ondataavailable(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(MediaRecorderImpl, "get_ondataavailable")) return try MediaRecorderImpl.get_ondataavailable(instance);
        return event_handlers.value(EventHandler, instance, "ondataavailable");
    }

    pub fn set_ondataavailable(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(MediaRecorderImpl, "set_ondataavailable")) return try MediaRecorderImpl.set_ondataavailable(instance, value);
        try event_handlers.setValue(EventHandler, instance, "ondataavailable", value);
    }

    pub fn get_onpause(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(MediaRecorderImpl, "get_onpause")) return try MediaRecorderImpl.get_onpause(instance);
        return event_handlers.value(EventHandler, instance, "onpause");
    }

    pub fn set_onpause(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(MediaRecorderImpl, "set_onpause")) return try MediaRecorderImpl.set_onpause(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onpause", value);
    }

    pub fn get_onresume(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(MediaRecorderImpl, "get_onresume")) return try MediaRecorderImpl.get_onresume(instance);
        return event_handlers.value(EventHandler, instance, "onresume");
    }

    pub fn set_onresume(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(MediaRecorderImpl, "set_onresume")) return try MediaRecorderImpl.set_onresume(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onresume", value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(MediaRecorderImpl, "get_onerror")) return try MediaRecorderImpl.get_onerror(instance);
        return event_handlers.value(EventHandler, instance, "onerror");
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(MediaRecorderImpl, "set_onerror")) return try MediaRecorderImpl.set_onerror(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onerror", value);
    }

    pub fn get_videoBitsPerSecond(instance: *runtime.Instance) anyerror!u32 {
        return try MediaRecorderImpl.get_videoBitsPerSecond(instance);
    }

    pub fn get_audioBitsPerSecond(instance: *runtime.Instance) anyerror!u32 {
        return try MediaRecorderImpl.get_audioBitsPerSecond(instance);
    }

    pub fn get_audioBitrateMode(instance: *runtime.Instance) anyerror!BitrateMode {
        return try MediaRecorderImpl.get_audioBitrateMode(instance);
    }

    pub fn call_start(instance: *runtime.Instance, timeslice: webidl.Opt(u32)) anyerror!void {
        return try MediaRecorderImpl.call_start(instance, timeslice);
    }

    pub fn call_pause(instance: *runtime.Instance) anyerror!void {
        return try MediaRecorderImpl.call_pause(instance);
    }

    pub fn call_resume(instance: *runtime.Instance) anyerror!void {
        return try MediaRecorderImpl.call_resume(instance);
    }

    pub fn call_static_isTypeSupported(instance: *runtime.Instance, @"type": runtime.DOMString) anyerror!bool {
        return try MediaRecorderImpl.call_static_isTypeSupported(instance, @"type");
    }

    pub fn call_stop(instance: *runtime.Instance) anyerror!void {
        return try MediaRecorderImpl.call_stop(instance);
    }

    pub fn call_requestData(instance: *runtime.Instance) anyerror!void {
        return try MediaRecorderImpl.call_requestData(instance);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{ "set_onstart", "set_onstop", "set_ondataavailable", "set_onpause", "set_onresume", "set_onerror" };
};
