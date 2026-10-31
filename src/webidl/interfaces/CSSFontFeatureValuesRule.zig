//! Generated from: css-fonts.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSFontFeatureValuesRuleImpl = @import("impls").CSSFontFeatureValuesRule;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSRule = @import("interfaces").CSSRule;
const CSSFontFeatureValuesMap = @import("interfaces").CSSFontFeatureValuesMap;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;

pub const CSSFontFeatureValuesRule = struct {
    pub const Meta = struct {
        pub const name = "CSSFontFeatureValuesRule";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = CSSRule.State;
        pub const ParentInterface = CSSRule;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "fontFamily", "get_fontFamily", "set_fontFamily" },
            .{ "annotation", "get_annotation", null },
            .{ "ornaments", "get_ornaments", null },
            .{ "stylistic", "get_stylistic", null },
            .{ "swash", "get_swash", null },
            .{ "characterVariant", "get_characterVariant", null },
            .{ "styleset", "get_styleset", null },
            .{ "historicalForms", "get_historicalForms", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "fontFamily", "get_fontFamily", "set_fontFamily" },
            .{ "annotation", "get_annotation", null },
            .{ "ornaments", "get_ornaments", null },
            .{ "stylistic", "get_stylistic", null },
            .{ "swash", "get_swash", null },
            .{ "characterVariant", "get_characterVariant", null },
            .{ "styleset", "get_styleset", null },
            .{ "historicalForms", "get_historicalForms", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            fontFamily: typedefs.CSSOMString = undefined,
            annotation: *runtime.Instance = undefined,
            ornaments: *runtime.Instance = undefined,
            stylistic: *runtime.Instance = undefined,
            swash: *runtime.Instance = undefined,
            characterVariant: *runtime.Instance = undefined,
            styleset: *runtime.Instance = undefined,
            historicalForms: *runtime.Instance = undefined,
            _internal: ?*CSSFontFeatureValuesRuleImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_annotation = &get_annotation,
        .get_characterVariant = &get_characterVariant,
        .get_fontFamily = &get_fontFamily,
        .get_historicalForms = &get_historicalForms,
        .get_ornaments = &get_ornaments,
        .get_styleset = &get_styleset,
        .get_stylistic = &get_stylistic,
        .get_swash = &get_swash,

        .set_fontFamily = &set_fontFamily,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("CSSFontFeatureValuesRule has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(CSSFontFeatureValuesRuleImpl, "init") and @hasDecl(CSSFontFeatureValuesRuleImpl, "initOwn")) @compileError("CSSFontFeatureValuesRuleImpl defines both init and initOwn");
        if (comptime @hasDecl(CSSFontFeatureValuesRuleImpl, "init")) return CSSFontFeatureValuesRuleImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(CSSFontFeatureValuesRuleImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try CSSFontFeatureValuesRuleImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CSSFontFeatureValuesRuleImpl, "init")) return false;
        if (comptime @hasDecl(CSSFontFeatureValuesRuleImpl, "construction_args")) {
            inline for (CSSFontFeatureValuesRuleImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(CSSFontFeatureValuesRuleImpl, "deinit") and @hasDecl(CSSFontFeatureValuesRuleImpl, "deinitOwn")) @compileError("CSSFontFeatureValuesRuleImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(CSSFontFeatureValuesRuleImpl, "deinit")) return CSSFontFeatureValuesRuleImpl.deinit(instance);
        if (comptime @hasDecl(CSSFontFeatureValuesRuleImpl, "deinitOwn")) CSSFontFeatureValuesRuleImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CSSFontFeatureValuesRule")) {
            if (comptime @hasDecl(impls.CSSFontFeatureValuesRule, "installHooks")) impls.CSSFontFeatureValuesRule.installHooks();
        }
    }

    pub fn get_fontFamily(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSFontFeatureValuesRuleImpl.get_fontFamily(instance);
    }

    pub fn set_fontFamily(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSFontFeatureValuesRuleImpl.set_fontFamily(instance, value);
    }

    pub fn get_annotation(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSFontFeatureValuesRuleImpl.get_annotation(instance);
    }

    pub fn get_ornaments(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSFontFeatureValuesRuleImpl.get_ornaments(instance);
    }

    pub fn get_stylistic(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSFontFeatureValuesRuleImpl.get_stylistic(instance);
    }

    pub fn get_swash(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSFontFeatureValuesRuleImpl.get_swash(instance);
    }

    pub fn get_characterVariant(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSFontFeatureValuesRuleImpl.get_characterVariant(instance);
    }

    pub fn get_styleset(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSFontFeatureValuesRuleImpl.get_styleset(instance);
    }

    pub fn get_historicalForms(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSFontFeatureValuesRuleImpl.get_historicalForms(instance);
    }
};
