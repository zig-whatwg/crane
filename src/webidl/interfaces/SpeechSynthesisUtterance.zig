//! Generated from: speech-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SpeechSynthesisUtteranceImpl = @import("impls").SpeechSynthesisUtterance;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("interfaces").Event;
const SpeechSynthesisVoice = @import("interfaces").SpeechSynthesisVoice;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const SpeechSynthesisUtterance = struct {
    pub const Meta = struct {
        pub const name = "SpeechSynthesisUtterance";
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
            .{ "text", "get_text", "set_text" },
            .{ "lang", "get_lang", "set_lang" },
            .{ "voice", "get_voice", "set_voice" },
            .{ "volume", "get_volume", "set_volume" },
            .{ "rate", "get_rate", "set_rate" },
            .{ "pitch", "get_pitch", "set_pitch" },
            .{ "onstart", "get_onstart", "set_onstart" },
            .{ "onend", "get_onend", "set_onend" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onpause", "get_onpause", "set_onpause" },
            .{ "onresume", "get_onresume", "set_onresume" },
            .{ "onmark", "get_onmark", "set_onmark" },
            .{ "onboundary", "get_onboundary", "set_onboundary" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "text", "get_text", "set_text" },
            .{ "lang", "get_lang", "set_lang" },
            .{ "voice", "get_voice", "set_voice" },
            .{ "volume", "get_volume", "set_volume" },
            .{ "rate", "get_rate", "set_rate" },
            .{ "pitch", "get_pitch", "set_pitch" },
            .{ "onstart", "get_onstart", "set_onstart" },
            .{ "onend", "get_onend", "set_onend" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onpause", "get_onpause", "set_onpause" },
            .{ "onresume", "get_onresume", "set_onresume" },
            .{ "onmark", "get_onmark", "set_onmark" },
            .{ "onboundary", "get_onboundary", "set_onboundary" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            text: runtime.DOMString = undefined,
            lang: runtime.DOMString = undefined,
            voice: ?*runtime.Instance = null,
            volume: f32 = undefined,
            rate: f32 = undefined,
            pitch: f32 = undefined,
            onstart: typedefs.EventHandler = undefined,
            onend: typedefs.EventHandler = undefined,
            onerror: typedefs.EventHandler = undefined,
            onpause: typedefs.EventHandler = undefined,
            onresume: typedefs.EventHandler = undefined,
            onmark: typedefs.EventHandler = undefined,
            onboundary: typedefs.EventHandler = undefined,
            _internal: ?*SpeechSynthesisUtteranceImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_lang = &get_lang,
        .get_onboundary = &get_onboundary,
        .get_onend = &get_onend,
        .get_onerror = &get_onerror,
        .get_onmark = &get_onmark,
        .get_onpause = &get_onpause,
        .get_onresume = &get_onresume,
        .get_onstart = &get_onstart,
        .get_pitch = &get_pitch,
        .get_rate = &get_rate,
        .get_text = &get_text,
        .get_voice = &get_voice,
        .get_volume = &get_volume,

        .set_lang = &set_lang,
        .set_onboundary = &set_onboundary,
        .set_onend = &set_onend,
        .set_onerror = &set_onerror,
        .set_onmark = &set_onmark,
        .set_onpause = &set_onpause,
        .set_onresume = &set_onresume,
        .set_onstart = &set_onstart,
        .set_pitch = &set_pitch,
        .set_rate = &set_rate,
        .set_text = &set_text,
        .set_voice = &set_voice,
        .set_volume = &set_volume,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("SpeechSynthesisUtterance has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(SpeechSynthesisUtteranceImpl, "init") and @hasDecl(SpeechSynthesisUtteranceImpl, "initOwn")) @compileError("SpeechSynthesisUtteranceImpl defines both init and initOwn");
        if (comptime @hasDecl(SpeechSynthesisUtteranceImpl, "init")) return SpeechSynthesisUtteranceImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(SpeechSynthesisUtteranceImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try SpeechSynthesisUtteranceImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SpeechSynthesisUtteranceImpl, "init")) return false;
        if (comptime @hasDecl(SpeechSynthesisUtteranceImpl, "construction_args")) {
            inline for (SpeechSynthesisUtteranceImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(SpeechSynthesisUtteranceImpl, "deinit") and @hasDecl(SpeechSynthesisUtteranceImpl, "deinitOwn")) @compileError("SpeechSynthesisUtteranceImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SpeechSynthesisUtteranceImpl, "deinit")) return SpeechSynthesisUtteranceImpl.deinit(instance);
        if (comptime @hasDecl(SpeechSynthesisUtteranceImpl, "deinitOwn")) SpeechSynthesisUtteranceImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SpeechSynthesisUtterance")) {
            if (comptime @hasDecl(impls.SpeechSynthesisUtterance, "installHooks")) impls.SpeechSynthesisUtterance.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 0;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, text: webidl.Opt(runtime.DOMString)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try SpeechSynthesisUtteranceImpl.call_constructor(ctx, text);
    }

    pub fn get_text(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try SpeechSynthesisUtteranceImpl.get_text(instance);
    }

    pub fn set_text(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        try SpeechSynthesisUtteranceImpl.set_text(instance, value);
    }

    pub fn get_lang(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try SpeechSynthesisUtteranceImpl.get_lang(instance);
    }

    pub fn set_lang(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        try SpeechSynthesisUtteranceImpl.set_lang(instance, value);
    }

    pub fn get_voice(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try SpeechSynthesisUtteranceImpl.get_voice(instance);
    }

    pub fn set_voice(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
        try SpeechSynthesisUtteranceImpl.set_voice(instance, value);
    }

    pub fn get_volume(instance: *runtime.Instance) anyerror!f32 {
        return try SpeechSynthesisUtteranceImpl.get_volume(instance);
    }

    pub fn set_volume(instance: *runtime.Instance, value: f32) anyerror!void {
        try SpeechSynthesisUtteranceImpl.set_volume(instance, value);
    }

    pub fn get_rate(instance: *runtime.Instance) anyerror!f32 {
        return try SpeechSynthesisUtteranceImpl.get_rate(instance);
    }

    pub fn set_rate(instance: *runtime.Instance, value: f32) anyerror!void {
        try SpeechSynthesisUtteranceImpl.set_rate(instance, value);
    }

    pub fn get_pitch(instance: *runtime.Instance) anyerror!f32 {
        return try SpeechSynthesisUtteranceImpl.get_pitch(instance);
    }

    pub fn set_pitch(instance: *runtime.Instance, value: f32) anyerror!void {
        try SpeechSynthesisUtteranceImpl.set_pitch(instance, value);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onstart(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SpeechSynthesisUtteranceImpl, "get_onstart")) return try SpeechSynthesisUtteranceImpl.get_onstart(instance);
        return event_handlers.value(EventHandler, instance, "onstart");
    }

    pub fn set_onstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SpeechSynthesisUtteranceImpl, "set_onstart")) return try SpeechSynthesisUtteranceImpl.set_onstart(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onstart", value);
    }

    pub fn get_onend(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SpeechSynthesisUtteranceImpl, "get_onend")) return try SpeechSynthesisUtteranceImpl.get_onend(instance);
        return event_handlers.value(EventHandler, instance, "onend");
    }

    pub fn set_onend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SpeechSynthesisUtteranceImpl, "set_onend")) return try SpeechSynthesisUtteranceImpl.set_onend(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onend", value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SpeechSynthesisUtteranceImpl, "get_onerror")) return try SpeechSynthesisUtteranceImpl.get_onerror(instance);
        return event_handlers.value(EventHandler, instance, "onerror");
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SpeechSynthesisUtteranceImpl, "set_onerror")) return try SpeechSynthesisUtteranceImpl.set_onerror(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onerror", value);
    }

    pub fn get_onpause(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SpeechSynthesisUtteranceImpl, "get_onpause")) return try SpeechSynthesisUtteranceImpl.get_onpause(instance);
        return event_handlers.value(EventHandler, instance, "onpause");
    }

    pub fn set_onpause(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SpeechSynthesisUtteranceImpl, "set_onpause")) return try SpeechSynthesisUtteranceImpl.set_onpause(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onpause", value);
    }

    pub fn get_onresume(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SpeechSynthesisUtteranceImpl, "get_onresume")) return try SpeechSynthesisUtteranceImpl.get_onresume(instance);
        return event_handlers.value(EventHandler, instance, "onresume");
    }

    pub fn set_onresume(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SpeechSynthesisUtteranceImpl, "set_onresume")) return try SpeechSynthesisUtteranceImpl.set_onresume(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onresume", value);
    }

    pub fn get_onmark(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SpeechSynthesisUtteranceImpl, "get_onmark")) return try SpeechSynthesisUtteranceImpl.get_onmark(instance);
        return event_handlers.value(EventHandler, instance, "onmark");
    }

    pub fn set_onmark(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SpeechSynthesisUtteranceImpl, "set_onmark")) return try SpeechSynthesisUtteranceImpl.set_onmark(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onmark", value);
    }

    pub fn get_onboundary(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SpeechSynthesisUtteranceImpl, "get_onboundary")) return try SpeechSynthesisUtteranceImpl.get_onboundary(instance);
        return event_handlers.value(EventHandler, instance, "onboundary");
    }

    pub fn set_onboundary(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SpeechSynthesisUtteranceImpl, "set_onboundary")) return try SpeechSynthesisUtteranceImpl.set_onboundary(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onboundary", value);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{ "set_onstart", "set_onend", "set_onerror", "set_onpause", "set_onresume", "set_onmark", "set_onboundary" };

    /// WebIDL `double` and `float` (not `unrestricted`): the values NaN and
    /// the infinities throw a TypeError for (bit i = argument i; an attribute
    /// setter's value is bit 0).
    pub const restricted_floats = .{
        .{ "set_volume", 0b1 },
        .{ "set_rate", 0b1 },
        .{ "set_pitch", 0b1 },
    };

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "set_voice", 0, "SpeechSynthesisVoice" },
    };
};
