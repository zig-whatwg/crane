//! Generated from: proofreader-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ProofreaderImpl = @import("impls").Proofreader;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Availability = @import("enums").Availability;
const ProofreaderCreateOptions = @import("dictionaries").ProofreaderCreateOptions;
const ProofreaderProofreadOptions = @import("dictionaries").ProofreaderProofreadOptions;
const ProofreadResult = @import("dictionaries").ProofreadResult;
const ProofreaderCreateCoreOptions = @import("dictionaries").ProofreaderCreateCoreOptions;
const DOMString = @import("typedefs").DOMString;

pub const Proofreader = struct {
    pub const Meta = struct {
        pub const name = "Proofreader";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "includeCorrectionTypes", "get_includeCorrectionTypes", null },
            .{ "includeCorrectionExplanations", "get_includeCorrectionExplanations", null },
            .{ "expectedInputLanguages", "get_expectedInputLanguages", null },
            .{ "correctionExplanationLanguage", "get_correctionExplanationLanguage", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "proofread", "call_proofread", 1 },
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
            "proofread",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "includeCorrectionTypes", "get_includeCorrectionTypes", null },
            .{ "includeCorrectionExplanations", "get_includeCorrectionExplanations", null },
            .{ "expectedInputLanguages", "get_expectedInputLanguages", null },
            .{ "correctionExplanationLanguage", "get_correctionExplanationLanguage", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            includeCorrectionTypes: bool = undefined,
            includeCorrectionExplanations: bool = undefined,
            expectedInputLanguages: ?runtime.JSValue = null,
            correctionExplanationLanguage: ?runtime.DOMString = null,
            _internal: ?*ProofreaderImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_correctionExplanationLanguage = &get_correctionExplanationLanguage,
        .get_expectedInputLanguages = &get_expectedInputLanguages,
        .get_includeCorrectionExplanations = &get_includeCorrectionExplanations,
        .get_includeCorrectionTypes = &get_includeCorrectionTypes,

        .call_proofread = &call_proofread,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("Proofreader has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(ProofreaderImpl, "init") and @hasDecl(ProofreaderImpl, "initOwn")) @compileError("ProofreaderImpl defines both init and initOwn");
        if (comptime @hasDecl(ProofreaderImpl, "init")) return ProofreaderImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(ProofreaderImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try ProofreaderImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ProofreaderImpl, "init")) return false;
        if (comptime @hasDecl(ProofreaderImpl, "construction_args")) {
            inline for (ProofreaderImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ProofreaderImpl, "deinit") and @hasDecl(ProofreaderImpl, "deinitOwn")) @compileError("ProofreaderImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ProofreaderImpl, "deinit")) return ProofreaderImpl.deinit(instance);
        if (comptime @hasDecl(ProofreaderImpl, "deinitOwn")) ProofreaderImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Proofreader")) {
            if (comptime @hasDecl(impls.Proofreader, "installHooks")) impls.Proofreader.installHooks();
        }
    }

    pub fn get_includeCorrectionTypes(instance: *runtime.Instance) anyerror!bool {
        return try ProofreaderImpl.get_includeCorrectionTypes(instance);
    }

    pub fn get_includeCorrectionExplanations(instance: *runtime.Instance) anyerror!bool {
        return try ProofreaderImpl.get_includeCorrectionExplanations(instance);
    }

    pub fn get_expectedInputLanguages(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try ProofreaderImpl.get_expectedInputLanguages(instance);
    }

    pub fn get_correctionExplanationLanguage(instance: *runtime.Instance) anyerror!?runtime.DOMString {
        return try ProofreaderImpl.get_correctionExplanationLanguage(instance);
    }

    pub fn call_proofread(instance: *runtime.Instance, input: runtime.DOMString, options: webidl.Opt(ProofreaderProofreadOptions)) anyerror!runtime.JSValue {
        return try ProofreaderImpl.call_proofread(instance, input, options);
    }

    pub fn call_static_create(instance: *runtime.Instance, options: webidl.Opt(ProofreaderCreateOptions)) anyerror!runtime.JSValue {
        return try ProofreaderImpl.call_static_create(instance, options);
    }

    pub fn call_static_availability(instance: *runtime.Instance, options: webidl.Opt(ProofreaderCreateCoreOptions)) anyerror!runtime.JSValue {
        return try ProofreaderImpl.call_static_availability(instance, options);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_proofread",
        "call_static_create",
        "call_static_availability",
    };
};
