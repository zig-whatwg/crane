//! Generated from: prompt-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const LanguageModelParamsImpl = @import("impls").LanguageModelParams;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const LanguageModelParams = struct {
    pub const Meta = struct {
        pub const name = "LanguageModelParams";
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
            .{ "defaultTopK", "get_defaultTopK", null },
            .{ "maxTopK", "get_maxTopK", null },
            .{ "defaultTemperature", "get_defaultTemperature", null },
            .{ "maxTemperature", "get_maxTemperature", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "defaultTopK", "get_defaultTopK", null },
            .{ "maxTopK", "get_maxTopK", null },
            .{ "defaultTemperature", "get_defaultTemperature", null },
            .{ "maxTemperature", "get_maxTemperature", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            defaultTopK: u32 = undefined,
            maxTopK: u32 = undefined,
            defaultTemperature: f32 = undefined,
            maxTemperature: f32 = undefined,
            _internal: ?*LanguageModelParamsImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_defaultTemperature = &get_defaultTemperature,
        .get_defaultTopK = &get_defaultTopK,
        .get_maxTemperature = &get_maxTemperature,
        .get_maxTopK = &get_maxTopK,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("LanguageModelParams has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(LanguageModelParamsImpl, "init") and @hasDecl(LanguageModelParamsImpl, "initOwn")) @compileError("LanguageModelParamsImpl defines both init and initOwn");
        if (comptime @hasDecl(LanguageModelParamsImpl, "init")) return LanguageModelParamsImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(LanguageModelParamsImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try LanguageModelParamsImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(LanguageModelParamsImpl, "init")) return false;
        if (comptime @hasDecl(LanguageModelParamsImpl, "construction_args")) {
            inline for (LanguageModelParamsImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(LanguageModelParamsImpl, "deinit") and @hasDecl(LanguageModelParamsImpl, "deinitOwn")) @compileError("LanguageModelParamsImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(LanguageModelParamsImpl, "deinit")) return LanguageModelParamsImpl.deinit(instance);
        if (comptime @hasDecl(LanguageModelParamsImpl, "deinitOwn")) LanguageModelParamsImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "LanguageModelParams")) {
            if (comptime @hasDecl(impls.LanguageModelParams, "installHooks")) impls.LanguageModelParams.installHooks();
        }
    }

    pub fn get_defaultTopK(instance: *runtime.Instance) anyerror!u32 {
        return try LanguageModelParamsImpl.get_defaultTopK(instance);
    }

    pub fn get_maxTopK(instance: *runtime.Instance) anyerror!u32 {
        return try LanguageModelParamsImpl.get_maxTopK(instance);
    }

    pub fn get_defaultTemperature(instance: *runtime.Instance) anyerror!f32 {
        return try LanguageModelParamsImpl.get_defaultTemperature(instance);
    }

    pub fn get_maxTemperature(instance: *runtime.Instance) anyerror!f32 {
        return try LanguageModelParamsImpl.get_maxTemperature(instance);
    }
};
