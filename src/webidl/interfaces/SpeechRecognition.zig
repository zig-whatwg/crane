//! Generated from: speech-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SpeechRecognitionImpl = @import("impls").SpeechRecognition;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const AvailabilityStatus = @import("enums").AvailabilityStatus;
const MediaStreamTrack = @import("interfaces").MediaStreamTrack;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const SpeechRecognitionOptions = @import("dictionaries").SpeechRecognitionOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const SpeechGrammarList = @import("interfaces").SpeechGrammarList;
const EventListener = @import("interfaces").EventListener;
const SpeechRecognitionPhrase = @import("interfaces").SpeechRecognitionPhrase;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const SpeechRecognition = struct {
    pub const Meta = struct {
        pub const name = "SpeechRecognition";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "grammars", "get_grammars", "set_grammars" },
            .{ "lang", "get_lang", "set_lang" },
            .{ "continuous", "get_continuous", "set_continuous" },
            .{ "interimResults", "get_interimResults", "set_interimResults" },
            .{ "unspokenPunctuation", "get_unspokenPunctuation", "set_unspokenPunctuation" },
            .{ "maxAlternatives", "get_maxAlternatives", "set_maxAlternatives" },
            .{ "processLocally", "get_processLocally", "set_processLocally" },
            .{ "phrases", "get_phrases", "set_phrases" },
            .{ "onaudiostart", "get_onaudiostart", "set_onaudiostart" },
            .{ "onsoundstart", "get_onsoundstart", "set_onsoundstart" },
            .{ "onspeechstart", "get_onspeechstart", "set_onspeechstart" },
            .{ "onspeechend", "get_onspeechend", "set_onspeechend" },
            .{ "onsoundend", "get_onsoundend", "set_onsoundend" },
            .{ "onaudioend", "get_onaudioend", "set_onaudioend" },
            .{ "onresult", "get_onresult", "set_onresult" },
            .{ "onnomatch", "get_onnomatch", "set_onnomatch" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onstart", "get_onstart", "set_onstart" },
            .{ "onend", "get_onend", "set_onend" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "start", "call_start", 0 },
            .{ "stop", "call_stop", 0 },
            .{ "abort", "call_abort", 0 },
        };

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "available", "call_static_available", 1 },
            .{ "install", "call_static_install", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "start",
            "stop",
            "abort",
            "available",
            "install",
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
            .{ "grammars", "get_grammars", "set_grammars" },
            .{ "lang", "get_lang", "set_lang" },
            .{ "continuous", "get_continuous", "set_continuous" },
            .{ "interimResults", "get_interimResults", "set_interimResults" },
            .{ "unspokenPunctuation", "get_unspokenPunctuation", "set_unspokenPunctuation" },
            .{ "maxAlternatives", "get_maxAlternatives", "set_maxAlternatives" },
            .{ "processLocally", "get_processLocally", "set_processLocally" },
            .{ "phrases", "get_phrases", "set_phrases" },
            .{ "onaudiostart", "get_onaudiostart", "set_onaudiostart" },
            .{ "onsoundstart", "get_onsoundstart", "set_onsoundstart" },
            .{ "onspeechstart", "get_onspeechstart", "set_onspeechstart" },
            .{ "onspeechend", "get_onspeechend", "set_onspeechend" },
            .{ "onsoundend", "get_onsoundend", "set_onsoundend" },
            .{ "onaudioend", "get_onaudioend", "set_onaudioend" },
            .{ "onresult", "get_onresult", "set_onresult" },
            .{ "onnomatch", "get_onnomatch", "set_onnomatch" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onstart", "get_onstart", "set_onstart" },
            .{ "onend", "get_onend", "set_onend" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            grammars: *runtime.Instance = undefined,
            lang: runtime.DOMString = undefined,
            continuous: bool = undefined,
            interimResults: bool = undefined,
            unspokenPunctuation: bool = undefined,
            maxAlternatives: u32 = undefined,
            processLocally: bool = undefined,
            phrases: runtime.JSValue = undefined,
            onaudiostart: typedefs.EventHandler = undefined,
            onsoundstart: typedefs.EventHandler = undefined,
            onspeechstart: typedefs.EventHandler = undefined,
            onspeechend: typedefs.EventHandler = undefined,
            onsoundend: typedefs.EventHandler = undefined,
            onaudioend: typedefs.EventHandler = undefined,
            onresult: typedefs.EventHandler = undefined,
            onnomatch: typedefs.EventHandler = undefined,
            onerror: typedefs.EventHandler = undefined,
            onstart: typedefs.EventHandler = undefined,
            onend: typedefs.EventHandler = undefined,
            _internal: ?*SpeechRecognitionImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_continuous = &get_continuous,
        .get_grammars = &get_grammars,
        .get_interimResults = &get_interimResults,
        .get_lang = &get_lang,
        .get_maxAlternatives = &get_maxAlternatives,
        .get_onaudioend = &get_onaudioend,
        .get_onaudiostart = &get_onaudiostart,
        .get_onend = &get_onend,
        .get_onerror = &get_onerror,
        .get_onnomatch = &get_onnomatch,
        .get_onresult = &get_onresult,
        .get_onsoundend = &get_onsoundend,
        .get_onsoundstart = &get_onsoundstart,
        .get_onspeechend = &get_onspeechend,
        .get_onspeechstart = &get_onspeechstart,
        .get_onstart = &get_onstart,
        .get_phrases = &get_phrases,
        .get_processLocally = &get_processLocally,
        .get_unspokenPunctuation = &get_unspokenPunctuation,

        .set_continuous = &set_continuous,
        .set_grammars = &set_grammars,
        .set_interimResults = &set_interimResults,
        .set_lang = &set_lang,
        .set_maxAlternatives = &set_maxAlternatives,
        .set_onaudioend = &set_onaudioend,
        .set_onaudiostart = &set_onaudiostart,
        .set_onend = &set_onend,
        .set_onerror = &set_onerror,
        .set_onnomatch = &set_onnomatch,
        .set_onresult = &set_onresult,
        .set_onsoundend = &set_onsoundend,
        .set_onsoundstart = &set_onsoundstart,
        .set_onspeechend = &set_onspeechend,
        .set_onspeechstart = &set_onspeechstart,
        .set_onstart = &set_onstart,
        .set_phrases = &set_phrases,
        .set_processLocally = &set_processLocally,
        .set_unspokenPunctuation = &set_unspokenPunctuation,

        .call_abort = &call_abort,
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
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("SpeechRecognition has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(SpeechRecognitionImpl, "init") and @hasDecl(SpeechRecognitionImpl, "initOwn")) @compileError("SpeechRecognitionImpl defines both init and initOwn");
        if (comptime @hasDecl(SpeechRecognitionImpl, "init")) return SpeechRecognitionImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(SpeechRecognitionImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try SpeechRecognitionImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SpeechRecognitionImpl, "init")) return false;
        if (comptime @hasDecl(SpeechRecognitionImpl, "construction_args")) {
            inline for (SpeechRecognitionImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(SpeechRecognitionImpl, "deinit") and @hasDecl(SpeechRecognitionImpl, "deinitOwn")) @compileError("SpeechRecognitionImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SpeechRecognitionImpl, "deinit")) return SpeechRecognitionImpl.deinit(instance);
        if (comptime @hasDecl(SpeechRecognitionImpl, "deinitOwn")) SpeechRecognitionImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SpeechRecognition")) {
            if (comptime @hasDecl(impls.SpeechRecognition, "installHooks")) impls.SpeechRecognition.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try SpeechRecognitionImpl.call_constructor(ctx);
    }

    pub fn get_grammars(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SpeechRecognitionImpl.get_grammars(instance);
    }

    pub fn set_grammars(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try SpeechRecognitionImpl.set_grammars(instance, value);
    }

    pub fn get_lang(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try SpeechRecognitionImpl.get_lang(instance);
    }

    pub fn set_lang(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        try SpeechRecognitionImpl.set_lang(instance, value);
    }

    pub fn get_continuous(instance: *runtime.Instance) anyerror!bool {
        return try SpeechRecognitionImpl.get_continuous(instance);
    }

    pub fn set_continuous(instance: *runtime.Instance, value: bool) anyerror!void {
        try SpeechRecognitionImpl.set_continuous(instance, value);
    }

    pub fn get_interimResults(instance: *runtime.Instance) anyerror!bool {
        return try SpeechRecognitionImpl.get_interimResults(instance);
    }

    pub fn set_interimResults(instance: *runtime.Instance, value: bool) anyerror!void {
        try SpeechRecognitionImpl.set_interimResults(instance, value);
    }

    pub fn get_unspokenPunctuation(instance: *runtime.Instance) anyerror!bool {
        return try SpeechRecognitionImpl.get_unspokenPunctuation(instance);
    }

    pub fn set_unspokenPunctuation(instance: *runtime.Instance, value: bool) anyerror!void {
        try SpeechRecognitionImpl.set_unspokenPunctuation(instance, value);
    }

    pub fn get_maxAlternatives(instance: *runtime.Instance) anyerror!u32 {
        return try SpeechRecognitionImpl.get_maxAlternatives(instance);
    }

    pub fn set_maxAlternatives(instance: *runtime.Instance, value: u32) anyerror!void {
        try SpeechRecognitionImpl.set_maxAlternatives(instance, value);
    }

    pub fn get_processLocally(instance: *runtime.Instance) anyerror!bool {
        return try SpeechRecognitionImpl.get_processLocally(instance);
    }

    pub fn set_processLocally(instance: *runtime.Instance, value: bool) anyerror!void {
        try SpeechRecognitionImpl.set_processLocally(instance, value);
    }

    pub fn get_phrases(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try SpeechRecognitionImpl.get_phrases(instance);
    }

    pub fn set_phrases(instance: *runtime.Instance, value: runtime.JSValue) anyerror!void {
        try SpeechRecognitionImpl.set_phrases(instance, value);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onaudiostart(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SpeechRecognitionImpl, "get_onaudiostart")) return try SpeechRecognitionImpl.get_onaudiostart(instance);
        return event_handlers.value(EventHandler, instance, "onaudiostart");
    }

    pub fn set_onaudiostart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SpeechRecognitionImpl, "set_onaudiostart")) return try SpeechRecognitionImpl.set_onaudiostart(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onaudiostart", value);
    }

    pub fn get_onsoundstart(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SpeechRecognitionImpl, "get_onsoundstart")) return try SpeechRecognitionImpl.get_onsoundstart(instance);
        return event_handlers.value(EventHandler, instance, "onsoundstart");
    }

    pub fn set_onsoundstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SpeechRecognitionImpl, "set_onsoundstart")) return try SpeechRecognitionImpl.set_onsoundstart(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onsoundstart", value);
    }

    pub fn get_onspeechstart(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SpeechRecognitionImpl, "get_onspeechstart")) return try SpeechRecognitionImpl.get_onspeechstart(instance);
        return event_handlers.value(EventHandler, instance, "onspeechstart");
    }

    pub fn set_onspeechstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SpeechRecognitionImpl, "set_onspeechstart")) return try SpeechRecognitionImpl.set_onspeechstart(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onspeechstart", value);
    }

    pub fn get_onspeechend(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SpeechRecognitionImpl, "get_onspeechend")) return try SpeechRecognitionImpl.get_onspeechend(instance);
        return event_handlers.value(EventHandler, instance, "onspeechend");
    }

    pub fn set_onspeechend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SpeechRecognitionImpl, "set_onspeechend")) return try SpeechRecognitionImpl.set_onspeechend(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onspeechend", value);
    }

    pub fn get_onsoundend(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SpeechRecognitionImpl, "get_onsoundend")) return try SpeechRecognitionImpl.get_onsoundend(instance);
        return event_handlers.value(EventHandler, instance, "onsoundend");
    }

    pub fn set_onsoundend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SpeechRecognitionImpl, "set_onsoundend")) return try SpeechRecognitionImpl.set_onsoundend(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onsoundend", value);
    }

    pub fn get_onaudioend(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SpeechRecognitionImpl, "get_onaudioend")) return try SpeechRecognitionImpl.get_onaudioend(instance);
        return event_handlers.value(EventHandler, instance, "onaudioend");
    }

    pub fn set_onaudioend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SpeechRecognitionImpl, "set_onaudioend")) return try SpeechRecognitionImpl.set_onaudioend(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onaudioend", value);
    }

    pub fn get_onresult(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SpeechRecognitionImpl, "get_onresult")) return try SpeechRecognitionImpl.get_onresult(instance);
        return event_handlers.value(EventHandler, instance, "onresult");
    }

    pub fn set_onresult(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SpeechRecognitionImpl, "set_onresult")) return try SpeechRecognitionImpl.set_onresult(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onresult", value);
    }

    pub fn get_onnomatch(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SpeechRecognitionImpl, "get_onnomatch")) return try SpeechRecognitionImpl.get_onnomatch(instance);
        return event_handlers.value(EventHandler, instance, "onnomatch");
    }

    pub fn set_onnomatch(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SpeechRecognitionImpl, "set_onnomatch")) return try SpeechRecognitionImpl.set_onnomatch(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onnomatch", value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SpeechRecognitionImpl, "get_onerror")) return try SpeechRecognitionImpl.get_onerror(instance);
        return event_handlers.value(EventHandler, instance, "onerror");
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SpeechRecognitionImpl, "set_onerror")) return try SpeechRecognitionImpl.set_onerror(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onerror", value);
    }

    pub fn get_onstart(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SpeechRecognitionImpl, "get_onstart")) return try SpeechRecognitionImpl.get_onstart(instance);
        return event_handlers.value(EventHandler, instance, "onstart");
    }

    pub fn set_onstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SpeechRecognitionImpl, "set_onstart")) return try SpeechRecognitionImpl.set_onstart(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onstart", value);
    }

    pub fn get_onend(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(SpeechRecognitionImpl, "get_onend")) return try SpeechRecognitionImpl.get_onend(instance);
        return event_handlers.value(EventHandler, instance, "onend");
    }

    pub fn set_onend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(SpeechRecognitionImpl, "set_onend")) return try SpeechRecognitionImpl.set_onend(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onend", value);
    }

    pub fn call_abort(instance: *runtime.Instance) anyerror!void {
        return try SpeechRecognitionImpl.call_abort(instance);
    }

    pub fn call_start(instance: *runtime.Instance) anyerror!void {
        return try SpeechRecognitionImpl.call_start(instance);
    }

    pub fn call_stop(instance: *runtime.Instance) anyerror!void {
        return try SpeechRecognitionImpl.call_stop(instance);
    }

    pub fn call_static_install(instance: *runtime.Instance, options: SpeechRecognitionOptions) anyerror!runtime.JSValue {
        return try SpeechRecognitionImpl.call_static_install(instance, options);
    }

    pub fn call_static_available(instance: *runtime.Instance, options: SpeechRecognitionOptions) anyerror!runtime.JSValue {
        return try SpeechRecognitionImpl.call_static_available(instance, options);
    }

    pub fn call_start__1(instance: *runtime.Instance, audioTrack: *runtime.Instance) anyerror!void {
        if (comptime @hasDecl(SpeechRecognitionImpl, "call_start__1")) {
            return try SpeechRecognitionImpl.call_start__1(instance, audioTrack);
        } else {
            return error.NotImplemented;
        }
    }

    /// WebIDL overload sets: every overload of each overloaded operation,
    /// in IDL order, for the overload resolution algorithm
    /// (webidl.overload_resolution). The binding is installed for the first
    /// overload and forwards to the one the arguments select.
    pub const overloads = .{
        .{ "start", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_start", .args = &.{} },
            .{ .function = "call_start__1", .implemented = @hasDecl(SpeechRecognitionImpl, "call_start__1"), .args = &.{.{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "MediaStreamTrack")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").MediaStreamTrack.State) } else .other)} }} },
        } },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_static_install",
        "call_static_available",
    };
};
