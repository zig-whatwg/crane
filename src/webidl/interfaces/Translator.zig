//! Generated from: translation-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TranslatorImpl = @import("impls").Translator;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DestroyableModel = @import("mixins").DestroyableModel;
const TranslatorCreateOptions = @import("dictionaries").TranslatorCreateOptions;
const Availability = @import("enums").Availability;
const ReadableStream = @import("interfaces").ReadableStream;
const TranslatorCreateCoreOptions = @import("dictionaries").TranslatorCreateCoreOptions;
const TranslatorTranslateOptions = @import("dictionaries").TranslatorTranslateOptions;
const DOMString = @import("typedefs").DOMString;

pub const Translator = struct {
    pub const Meta = struct {
        pub const name = "Translator";
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
            .{ "sourceLanguage", "get_sourceLanguage", null },
            .{ "targetLanguage", "get_targetLanguage", null },
            .{ "inputQuota", "get_inputQuota", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "translate", "call_translate", 1 },
            .{ "translateStreaming", "call_translateStreaming", 1 },
            .{ "measureInputUsage", "call_measureInputUsage", 1 },
            .{ "destroy", "call_destroy", 0 },
        };

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "create", "call_static_create", 1 },
            .{ "availability", "call_static_availability", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "create",
            "availability",
            "translate",
            "translateStreaming",
            "measureInputUsage",
            "destroy",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "sourceLanguage", "get_sourceLanguage", null },
            .{ "targetLanguage", "get_targetLanguage", null },
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
            sourceLanguage: runtime.DOMString = undefined,
            targetLanguage: runtime.DOMString = undefined,
            inputQuota: f64 = undefined,
            _internal: ?*TranslatorImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_inputQuota = &get_inputQuota,
        .get_sourceLanguage = &get_sourceLanguage,
        .get_targetLanguage = &get_targetLanguage,

        .call_destroy = &call_destroy,
        .call_measureInputUsage = &call_measureInputUsage,
        .call_translate = &call_translate,
        .call_translateStreaming = &call_translateStreaming,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("Translator has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(TranslatorImpl, "init") and @hasDecl(TranslatorImpl, "initOwn")) @compileError("TranslatorImpl defines both init and initOwn");
        if (comptime @hasDecl(TranslatorImpl, "init")) return TranslatorImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(TranslatorImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try TranslatorImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(TranslatorImpl, "init")) return false;
        if (comptime @hasDecl(TranslatorImpl, "construction_args")) {
            inline for (TranslatorImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(TranslatorImpl, "deinit") and @hasDecl(TranslatorImpl, "deinitOwn")) @compileError("TranslatorImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(TranslatorImpl, "deinit")) return TranslatorImpl.deinit(instance);
        if (comptime @hasDecl(TranslatorImpl, "deinitOwn")) TranslatorImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Translator")) {
            if (comptime @hasDecl(impls.Translator, "installHooks")) impls.Translator.installHooks();
        }
    }

    pub fn get_sourceLanguage(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try TranslatorImpl.get_sourceLanguage(instance);
    }

    pub fn get_targetLanguage(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try TranslatorImpl.get_targetLanguage(instance);
    }

    pub fn get_inputQuota(instance: *runtime.Instance) anyerror!f64 {
        return try TranslatorImpl.get_inputQuota(instance);
    }

    pub fn call_translate(instance: *runtime.Instance, input: runtime.DOMString, options: webidl.Opt(TranslatorTranslateOptions)) anyerror!runtime.JSValue {
        return try TranslatorImpl.call_translate(instance, input, options);
    }

    pub fn call_translateStreaming(instance: *runtime.Instance, input: runtime.DOMString, options: webidl.Opt(TranslatorTranslateOptions)) anyerror!*runtime.Instance {
        return try TranslatorImpl.call_translateStreaming(instance, input, options);
    }

    pub const call_destroy = mixins.DestroyableModel.call_destroy;

    pub fn call_static_create(instance: *runtime.Instance, options: TranslatorCreateOptions) anyerror!runtime.JSValue {
        return try TranslatorImpl.call_static_create(instance, options);
    }

    pub fn call_static_availability(instance: *runtime.Instance, options: TranslatorCreateCoreOptions) anyerror!runtime.JSValue {
        return try TranslatorImpl.call_static_availability(instance, options);
    }

    pub fn call_measureInputUsage(instance: *runtime.Instance, input: runtime.DOMString, options: webidl.Opt(TranslatorTranslateOptions)) anyerror!runtime.JSValue {
        return try TranslatorImpl.call_measureInputUsage(instance, input, options);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_translate",
        "call_static_create",
        "call_static_availability",
        "call_measureInputUsage",
    };
};
