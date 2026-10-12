//! Generated from: writing-assistance-apis.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SummarizerImpl = @import("impls").Summarizer;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DestroyableModel = @import("mixins").DestroyableModel;
const Availability = @import("enums").Availability;
const ReadableStream = @import("interfaces").ReadableStream;
const SummarizerSummarizeOptions = @import("dictionaries").SummarizerSummarizeOptions;
const SummarizerCreateCoreOptions = @import("dictionaries").SummarizerCreateCoreOptions;
const SummarizerType = @import("enums").SummarizerType;
const SummarizerCreateOptions = @import("dictionaries").SummarizerCreateOptions;
const SummarizerLength = @import("enums").SummarizerLength;
const SummarizerFormat = @import("enums").SummarizerFormat;
const DOMString = @import("typedefs").DOMString;

pub const Summarizer = struct {
    pub const Meta = struct {
        pub const name = "Summarizer";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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
            .{ "sharedContext", "get_sharedContext", null },
            .{ "type", "get_type", null },
            .{ "format", "get_format", null },
            .{ "length", "get_length", null },
            .{ "expectedInputLanguages", "get_expectedInputLanguages", null },
            .{ "expectedContextLanguages", "get_expectedContextLanguages", null },
            .{ "outputLanguage", "get_outputLanguage", null },
            .{ "inputQuota", "get_inputQuota", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "summarize", "call_summarize", 1 },
            .{ "summarizeStreaming", "call_summarizeStreaming", 1 },
            .{ "measureInputUsage", "call_measureInputUsage", 1 },
            .{ "destroy", "call_destroy", 0 },
        };

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "create", "call_static_create", 0 },
            .{ "availability", "call_static_availability", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "create",
            "availability",
            "summarize",
            "summarizeStreaming",
            "measureInputUsage",
            "destroy",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "sharedContext", "get_sharedContext", null },
            .{ "type", "get_type", null },
            .{ "format", "get_format", null },
            .{ "length", "get_length", null },
            .{ "expectedInputLanguages", "get_expectedInputLanguages", null },
            .{ "expectedContextLanguages", "get_expectedContextLanguages", null },
            .{ "outputLanguage", "get_outputLanguage", null },
            .{ "inputQuota", "get_inputQuota", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            sharedContext: typedefs.DOMString = undefined,
            type: enums.SummarizerType = undefined,
            format: enums.SummarizerFormat = undefined,
            length: enums.SummarizerLength = undefined,
            expectedInputLanguages: ?runtime.JSValue = null,
            expectedContextLanguages: ?runtime.JSValue = null,
            outputLanguage: ?typedefs.DOMString = null,
            inputQuota: f64 = undefined,
            _internal: ?*SummarizerImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_expectedContextLanguages = &get_expectedContextLanguages,
        .get_expectedInputLanguages = &get_expectedInputLanguages,
        .get_format = &get_format,
        .get_inputQuota = &get_inputQuota,
        .get_length = &get_length,
        .get_outputLanguage = &get_outputLanguage,
        .get_sharedContext = &get_sharedContext,
        .get_type = &get_type,

        .call_destroy = &call_destroy,
        .call_measureInputUsage = &call_measureInputUsage,
        .call_summarize = &call_summarize,
        .call_summarizeStreaming = &call_summarizeStreaming,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("Summarizer has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(SummarizerImpl, "init") and @hasDecl(SummarizerImpl, "initOwn")) @compileError("SummarizerImpl defines both init and initOwn");
        if (comptime @hasDecl(SummarizerImpl, "init")) return SummarizerImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(SummarizerImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try SummarizerImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SummarizerImpl, "init")) return false;
        if (comptime @hasDecl(SummarizerImpl, "construction_args")) {
            inline for (SummarizerImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(SummarizerImpl, "deinit") and @hasDecl(SummarizerImpl, "deinitOwn")) @compileError("SummarizerImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SummarizerImpl, "deinit")) return SummarizerImpl.deinit(instance);
        if (comptime @hasDecl(SummarizerImpl, "deinitOwn")) SummarizerImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Summarizer")) {
            if (comptime @hasDecl(impls.Summarizer, "installHooks")) impls.Summarizer.installHooks();
        }
    }

    pub fn get_sharedContext(instance: *runtime.Instance) anyerror!DOMString {
        return try SummarizerImpl.get_sharedContext(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!SummarizerType {
        return try SummarizerImpl.get_type(instance);
    }

    pub fn get_format(instance: *runtime.Instance) anyerror!SummarizerFormat {
        return try SummarizerImpl.get_format(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!SummarizerLength {
        return try SummarizerImpl.get_length(instance);
    }

    pub fn get_expectedInputLanguages(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try SummarizerImpl.get_expectedInputLanguages(instance);
    }

    pub fn get_expectedContextLanguages(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try SummarizerImpl.get_expectedContextLanguages(instance);
    }

    pub fn get_outputLanguage(instance: *runtime.Instance) anyerror!?DOMString {
        return try SummarizerImpl.get_outputLanguage(instance);
    }

    pub fn get_inputQuota(instance: *runtime.Instance) anyerror!f64 {
        return try SummarizerImpl.get_inputQuota(instance);
    }

    pub fn call_measureInputUsage(instance: *runtime.Instance, input: DOMString, options: webidl.Opt(SummarizerSummarizeOptions)) anyerror!runtime.JSValue {
        return try SummarizerImpl.call_measureInputUsage(instance, input, options);
    }

    pub const call_destroy = mixins.DestroyableModel.call_destroy;

    pub fn call_summarizeStreaming(instance: *runtime.Instance, input: DOMString, options: webidl.Opt(SummarizerSummarizeOptions)) anyerror!*runtime.Instance {
        return try SummarizerImpl.call_summarizeStreaming(instance, input, options);
    }

    pub fn call_static_create(instance: *runtime.Instance, options: webidl.Opt(SummarizerCreateOptions)) anyerror!runtime.JSValue {
        return try SummarizerImpl.call_static_create(instance, options);
    }

    pub fn call_static_availability(instance: *runtime.Instance, options: webidl.Opt(SummarizerCreateCoreOptions)) anyerror!runtime.JSValue {
        return try SummarizerImpl.call_static_availability(instance, options);
    }

    pub fn call_summarize(instance: *runtime.Instance, input: DOMString, options: webidl.Opt(SummarizerSummarizeOptions)) anyerror!runtime.JSValue {
        return try SummarizerImpl.call_summarize(instance, input, options);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_measureInputUsage",
        "call_static_create",
        "call_static_availability",
        "call_summarize",
    };
};
