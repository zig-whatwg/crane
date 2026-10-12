//! Generated from: css-animations.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSKeyframesRuleImpl = @import("impls").CSSKeyframesRule;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSRule = @import("interfaces").CSSRule;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;
const CSSKeyframeRule = @import("interfaces").CSSKeyframeRule;
const CSSRuleList = @import("interfaces").CSSRuleList;

pub const CSSKeyframesRule = struct {
    pub const Meta = struct {
        pub const name = "CSSKeyframesRule";
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
            .{ "name", "get_name", "set_name" },
            .{ "cssRules", "get_cssRules", null },
            .{ "length", "get_length", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "appendRule", "call_appendRule", 1 },
            .{ "deleteRule", "call_deleteRule", 1 },
            .{ "findRule", "call_findRule", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "appendRule",
            "deleteRule",
            "findRule",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "name", "get_name", "set_name" },
            .{ "cssRules", "get_cssRules", null },
            .{ "length", "get_length", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// WebIDL 2.5.6 special operations, own or inherited (the derived-most):
        /// the function that runs each. The binding installs indexed and named
        /// property handlers from this table (webidl.SpecialOperations).
        pub const special_operations: webidl.SpecialOperations = .{
            .indexed_getter = .{ .function = "call_getter", .implemented = @hasDecl(CSSKeyframesRuleImpl, "call_getter") },
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            name: typedefs.CSSOMString = undefined,
            cssRules: *runtime.Instance = undefined,
            length: u32 = undefined,
            _internal: ?*CSSKeyframesRuleImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_cssRules = &get_cssRules,
        .get_length = &get_length,
        .get_name = &get_name,

        .set_name = &set_name,

        .call_appendRule = &call_appendRule,
        .call_deleteRule = &call_deleteRule,
        .call_findRule = &call_findRule,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("CSSKeyframesRule has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(CSSKeyframesRuleImpl, "init") and @hasDecl(CSSKeyframesRuleImpl, "initOwn")) @compileError("CSSKeyframesRuleImpl defines both init and initOwn");
        if (comptime @hasDecl(CSSKeyframesRuleImpl, "init")) return CSSKeyframesRuleImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(CSSKeyframesRuleImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try CSSKeyframesRuleImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CSSKeyframesRuleImpl, "init")) return false;
        if (comptime @hasDecl(CSSKeyframesRuleImpl, "construction_args")) {
            inline for (CSSKeyframesRuleImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(CSSKeyframesRuleImpl, "deinit") and @hasDecl(CSSKeyframesRuleImpl, "deinitOwn")) @compileError("CSSKeyframesRuleImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(CSSKeyframesRuleImpl, "deinit")) return CSSKeyframesRuleImpl.deinit(instance);
        if (comptime @hasDecl(CSSKeyframesRuleImpl, "deinitOwn")) CSSKeyframesRuleImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CSSKeyframesRule")) {
            if (comptime @hasDecl(impls.CSSKeyframesRule, "installHooks")) impls.CSSKeyframesRule.installHooks();
        }
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSKeyframesRuleImpl.get_name(instance);
    }

    pub fn set_name(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSKeyframesRuleImpl.set_name(instance, value);
    }

    pub fn get_cssRules(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSKeyframesRuleImpl.get_cssRules(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try CSSKeyframesRuleImpl.get_length(instance);
    }

    pub fn call_getter(instance: *runtime.Instance, index: u32) anyerror!*runtime.Instance {
        if (comptime @hasDecl(CSSKeyframesRuleImpl, "call_getter")) {
            return try CSSKeyframesRuleImpl.call_getter(instance, index);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_appendRule(instance: *runtime.Instance, rule: CSSOMString) anyerror!void {
        return try CSSKeyframesRuleImpl.call_appendRule(instance, rule);
    }

    pub fn call_findRule(instance: *runtime.Instance, select: CSSOMString) anyerror!?*runtime.Instance {
        return try CSSKeyframesRuleImpl.call_findRule(instance, select);
    }

    pub fn call_deleteRule(instance: *runtime.Instance, select: CSSOMString) anyerror!void {
        return try CSSKeyframesRuleImpl.call_deleteRule(instance, select);
    }
};
