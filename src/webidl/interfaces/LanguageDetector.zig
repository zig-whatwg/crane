//! Generated from: translation-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const LanguageDetectorImpl = @import("impls").LanguageDetector;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DestroyableModel = @import("mixins").DestroyableModel;
const LanguageDetectorDetectOptions = @import("dictionaries").LanguageDetectorDetectOptions;
const Availability = @import("enums").Availability;
const LanguageDetectorCreateOptions = @import("dictionaries").LanguageDetectorCreateOptions;
const LanguageDetectorCreateCoreOptions = @import("dictionaries").LanguageDetectorCreateCoreOptions;
const DOMString = @import("typedefs").DOMString;

pub const LanguageDetector = struct {
    pub const Meta = struct {
        pub const name = "LanguageDetector";
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
            .{ "expectedInputLanguages", "get_expectedInputLanguages", null },
            .{ "inputQuota", "get_inputQuota", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "detect", "call_detect", 1 },
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
            "detect",
            "measureInputUsage",
            "destroy",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "expectedInputLanguages", "get_expectedInputLanguages", null },
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
            expectedInputLanguages: ?runtime.JSValue = null,
            inputQuota: f64 = undefined,
            _internal: ?*LanguageDetectorImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_expectedInputLanguages = &get_expectedInputLanguages,
        .get_inputQuota = &get_inputQuota,

        .call_destroy = &call_destroy,
        .call_detect = &call_detect,
        .call_measureInputUsage = &call_measureInputUsage,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("LanguageDetector has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(LanguageDetectorImpl, "init") and @hasDecl(LanguageDetectorImpl, "initOwn")) @compileError("LanguageDetectorImpl defines both init and initOwn");
        if (comptime @hasDecl(LanguageDetectorImpl, "init")) return LanguageDetectorImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(LanguageDetectorImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try LanguageDetectorImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(LanguageDetectorImpl, "init")) return false;
        if (comptime @hasDecl(LanguageDetectorImpl, "construction_args")) {
            inline for (LanguageDetectorImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(LanguageDetectorImpl, "deinit") and @hasDecl(LanguageDetectorImpl, "deinitOwn")) @compileError("LanguageDetectorImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(LanguageDetectorImpl, "deinit")) return LanguageDetectorImpl.deinit(instance);
        if (comptime @hasDecl(LanguageDetectorImpl, "deinitOwn")) LanguageDetectorImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "LanguageDetector")) {
            if (comptime @hasDecl(impls.LanguageDetector, "installHooks")) impls.LanguageDetector.installHooks();
        }
    }

    pub fn get_expectedInputLanguages(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try LanguageDetectorImpl.get_expectedInputLanguages(instance);
    }

    pub fn get_inputQuota(instance: *runtime.Instance) anyerror!f64 {
        return try LanguageDetectorImpl.get_inputQuota(instance);
    }

    pub fn call_measureInputUsage(instance: *runtime.Instance, input: runtime.DOMString, options: webidl.Opt(LanguageDetectorDetectOptions)) anyerror!runtime.JSValue {
        return try LanguageDetectorImpl.call_measureInputUsage(instance, input, options);
    }

    pub const call_destroy = mixins.DestroyableModel.call_destroy;

    pub fn call_static_create(instance: *runtime.Instance, options: webidl.Opt(LanguageDetectorCreateOptions)) anyerror!runtime.JSValue {
        return try LanguageDetectorImpl.call_static_create(instance, options);
    }

    pub fn call_static_availability(instance: *runtime.Instance, options: webidl.Opt(LanguageDetectorCreateCoreOptions)) anyerror!runtime.JSValue {
        return try LanguageDetectorImpl.call_static_availability(instance, options);
    }

    pub fn call_detect(instance: *runtime.Instance, input: runtime.DOMString, options: webidl.Opt(LanguageDetectorDetectOptions)) anyerror!runtime.JSValue {
        return try LanguageDetectorImpl.call_detect(instance, input, options);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_measureInputUsage",
        "call_static_create",
        "call_static_availability",
        "call_detect",
    };
};
