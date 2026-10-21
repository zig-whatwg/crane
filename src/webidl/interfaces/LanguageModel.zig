//! Generated from: prompt-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const LanguageModelImpl = @import("impls").LanguageModel;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const DestroyableModel = @import("mixins").DestroyableModel;
const DOMString = @import("typedefs").DOMString;
const Availability = @import("enums").Availability;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const LanguageModelCreateCoreOptions = @import("dictionaries").LanguageModelCreateCoreOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const LanguageModelPrompt = @import("typedefs").LanguageModelPrompt;
const LanguageModelCreateOptions = @import("dictionaries").LanguageModelCreateOptions;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const ReadableStream = @import("interfaces").ReadableStream;
const LanguageModelParams = @import("interfaces").LanguageModelParams;
const LanguageModelSamplingMode = @import("enums").LanguageModelSamplingMode;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const LanguageModelAppendOptions = @import("dictionaries").LanguageModelAppendOptions;
const LanguageModelCloneOptions = @import("dictionaries").LanguageModelCloneOptions;
const EventHandler = @import("typedefs").EventHandler;
const LanguageModelPromptOptions = @import("dictionaries").LanguageModelPromptOptions;

pub const LanguageModel = struct {
    pub const Meta = struct {
        pub const name = "LanguageModel";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{
            DestroyableModel,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "contextUsage", "get_contextUsage", null },
            .{ "contextWindow", "get_contextWindow", null },
            .{ "oncontextoverflow", "get_oncontextoverflow", "set_oncontextoverflow" },
            .{ "inputUsage", "get_inputUsage", null },
            .{ "inputQuota", "get_inputQuota", null },
            .{ "onquotaoverflow", "get_onquotaoverflow", "set_onquotaoverflow" },
            .{ "topK", "get_topK", null },
            .{ "temperature", "get_temperature", null },
            .{ "samplingMode", "get_samplingMode", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "prompt", "call_prompt", 1 },
            .{ "promptStreaming", "call_promptStreaming", 1 },
            .{ "append", "call_append", 1 },
            .{ "measureContextUsage", "call_measureContextUsage", 1 },
            .{ "measureInputUsage", "call_measureInputUsage", 1 },
            .{ "clone", "call_clone", 0 },
            .{ "destroy", "call_destroy", 0 },
        };

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "create", "call_static_create", 0 },
            .{ "availability", "call_static_availability", 0 },
            .{ "params", "call_static_params", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "create",
            "availability",
            "params",
            "prompt",
            "promptStreaming",
            "append",
            "measureContextUsage",
            "measureInputUsage",
            "clone",
            "destroy",
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
            .{ "contextUsage", "get_contextUsage", null },
            .{ "contextWindow", "get_contextWindow", null },
            .{ "oncontextoverflow", "get_oncontextoverflow", "set_oncontextoverflow" },
            .{ "inputUsage", "get_inputUsage", null },
            .{ "inputQuota", "get_inputQuota", null },
            .{ "onquotaoverflow", "get_onquotaoverflow", "set_onquotaoverflow" },
            .{ "topK", "get_topK", null },
            .{ "temperature", "get_temperature", null },
            .{ "samplingMode", "get_samplingMode", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            contextUsage: f64 = undefined,
            contextWindow: f64 = undefined,
            oncontextoverflow: typedefs.EventHandler = undefined,
            inputUsage: f64 = undefined,
            inputQuota: f64 = undefined,
            onquotaoverflow: typedefs.EventHandler = undefined,
            topK: u32 = undefined,
            temperature: f32 = undefined,
            samplingMode: enums.LanguageModelSamplingMode = undefined,
            _internal: ?*LanguageModelImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_contextUsage = &get_contextUsage,
        .get_contextWindow = &get_contextWindow,
        .get_inputQuota = &get_inputQuota,
        .get_inputUsage = &get_inputUsage,
        .get_oncontextoverflow = &get_oncontextoverflow,
        .get_onquotaoverflow = &get_onquotaoverflow,
        .get_samplingMode = &get_samplingMode,
        .get_temperature = &get_temperature,
        .get_topK = &get_topK,

        .set_oncontextoverflow = &set_oncontextoverflow,
        .set_onquotaoverflow = &set_onquotaoverflow,

        .call_append = &call_append,
        .call_clone = &call_clone,
        .call_destroy = &call_destroy,
        .call_measureContextUsage = &call_measureContextUsage,
        .call_measureInputUsage = &call_measureInputUsage,
        .call_prompt = &call_prompt,
        .call_promptStreaming = &call_promptStreaming,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("LanguageModel has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(LanguageModelImpl, "init") and @hasDecl(LanguageModelImpl, "initOwn")) @compileError("LanguageModelImpl defines both init and initOwn");
        if (comptime @hasDecl(LanguageModelImpl, "init")) return LanguageModelImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(LanguageModelImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try LanguageModelImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(LanguageModelImpl, "init")) return false;
        if (comptime @hasDecl(LanguageModelImpl, "construction_args")) {
            inline for (LanguageModelImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(LanguageModelImpl, "deinit") and @hasDecl(LanguageModelImpl, "deinitOwn")) @compileError("LanguageModelImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(LanguageModelImpl, "deinit")) return LanguageModelImpl.deinit(instance);
        if (comptime @hasDecl(LanguageModelImpl, "deinitOwn")) LanguageModelImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "LanguageModel")) {
            if (comptime @hasDecl(impls.LanguageModel, "installHooks")) impls.LanguageModel.installHooks();
        }
    }

    pub fn get_contextUsage(instance: *runtime.Instance) anyerror!f64 {
        return try LanguageModelImpl.get_contextUsage(instance);
    }

    pub fn get_contextWindow(instance: *runtime.Instance) anyerror!f64 {
        return try LanguageModelImpl.get_contextWindow(instance);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_oncontextoverflow(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(LanguageModelImpl, "get_oncontextoverflow")) return try LanguageModelImpl.get_oncontextoverflow(instance);
        return event_handlers.value(EventHandler, instance, "oncontextoverflow");
    }

    pub fn set_oncontextoverflow(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(LanguageModelImpl, "set_oncontextoverflow")) return try LanguageModelImpl.set_oncontextoverflow(instance, value);
        try event_handlers.setValue(EventHandler, instance, "oncontextoverflow", value);
    }

    pub fn get_inputUsage(instance: *runtime.Instance) anyerror!f64 {
        return try LanguageModelImpl.get_inputUsage(instance);
    }

    pub fn get_inputQuota(instance: *runtime.Instance) anyerror!f64 {
        return try LanguageModelImpl.get_inputQuota(instance);
    }

    pub fn get_onquotaoverflow(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(LanguageModelImpl, "get_onquotaoverflow")) return try LanguageModelImpl.get_onquotaoverflow(instance);
        return event_handlers.value(EventHandler, instance, "onquotaoverflow");
    }

    pub fn set_onquotaoverflow(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(LanguageModelImpl, "set_onquotaoverflow")) return try LanguageModelImpl.set_onquotaoverflow(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onquotaoverflow", value);
    }

    pub fn get_topK(instance: *runtime.Instance) anyerror!u32 {
        return try LanguageModelImpl.get_topK(instance);
    }

    pub fn get_temperature(instance: *runtime.Instance) anyerror!f32 {
        return try LanguageModelImpl.get_temperature(instance);
    }

    pub fn get_samplingMode(instance: *runtime.Instance) anyerror!LanguageModelSamplingMode {
        return try LanguageModelImpl.get_samplingMode(instance);
    }

    pub fn call_measureInputUsage(instance: *runtime.Instance, input: LanguageModelPrompt, options: webidl.Opt(LanguageModelPromptOptions)) anyerror!runtime.JSValue {
        return try LanguageModelImpl.call_measureInputUsage(instance, input, options);
    }

    pub fn call_clone(instance: *runtime.Instance, options: webidl.Opt(LanguageModelCloneOptions)) anyerror!runtime.JSValue {
        return try LanguageModelImpl.call_clone(instance, options);
    }

    pub const call_destroy = mixins.DestroyableModel.call_destroy;

    pub fn call_static_availability(instance: *runtime.Instance, options: webidl.Opt(LanguageModelCreateCoreOptions)) anyerror!runtime.JSValue {
        return try LanguageModelImpl.call_static_availability(instance, options);
    }

    pub fn call_prompt(instance: *runtime.Instance, input: LanguageModelPrompt, options: webidl.Opt(LanguageModelPromptOptions)) anyerror!runtime.JSValue {
        return try LanguageModelImpl.call_prompt(instance, input, options);
    }

    pub fn call_static_params(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try LanguageModelImpl.call_static_params(instance);
    }

    pub fn call_promptStreaming(instance: *runtime.Instance, input: LanguageModelPrompt, options: webidl.Opt(LanguageModelPromptOptions)) anyerror!*runtime.Instance {
        return try LanguageModelImpl.call_promptStreaming(instance, input, options);
    }

    pub fn call_static_create(instance: *runtime.Instance, options: webidl.Opt(LanguageModelCreateOptions)) anyerror!runtime.JSValue {
        return try LanguageModelImpl.call_static_create(instance, options);
    }

    pub fn call_append(instance: *runtime.Instance, input: LanguageModelPrompt, options: webidl.Opt(LanguageModelAppendOptions)) anyerror!runtime.JSValue {
        return try LanguageModelImpl.call_append(instance, input, options);
    }

    pub fn call_measureContextUsage(instance: *runtime.Instance, input: LanguageModelPrompt, options: webidl.Opt(LanguageModelPromptOptions)) anyerror!runtime.JSValue {
        return try LanguageModelImpl.call_measureContextUsage(instance, input, options);
    }

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{ "set_oncontextoverflow", "set_onquotaoverflow" };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_measureInputUsage",
        "call_clone",
        "call_static_availability",
        "call_prompt",
        "call_static_params",
        "call_static_create",
        "call_append",
        "call_measureContextUsage",
    };
};
