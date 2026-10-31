//! Generated from: css-mixins.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSMixinRuleImpl = @import("impls").CSSMixinRule;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSGroupingRule = @import("interfaces").CSSGroupingRule;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;
const FunctionParameter = @import("dictionaries").FunctionParameter;
const CSSRule = @import("interfaces").CSSRule;
const CSSRuleList = @import("interfaces").CSSRuleList;

pub const CSSMixinRule = struct {
    pub const Meta = struct {
        pub const name = "CSSMixinRule";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = CSSGroupingRule.State;
        pub const ParentInterface = CSSGroupingRule;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", null },
            .{ "contents", "get_contents", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getParameters", "call_getParameters", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getParameters",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "insertRule",
            "deleteRule",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "name", "get_name", null },
            .{ "contents", "get_contents", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            name: typedefs.CSSOMString = undefined,
            contents: bool = undefined,
            _internal: ?*CSSMixinRuleImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_contents = &get_contents,
        .get_name = &get_name,

        .call_getParameters = &call_getParameters,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("CSSMixinRule has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(CSSMixinRuleImpl, "init") and @hasDecl(CSSMixinRuleImpl, "initOwn")) @compileError("CSSMixinRuleImpl defines both init and initOwn");
        if (comptime @hasDecl(CSSMixinRuleImpl, "init")) return CSSMixinRuleImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(CSSMixinRuleImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try CSSMixinRuleImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CSSMixinRuleImpl, "init")) return false;
        if (comptime @hasDecl(CSSMixinRuleImpl, "construction_args")) {
            inline for (CSSMixinRuleImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(CSSMixinRuleImpl, "deinit") and @hasDecl(CSSMixinRuleImpl, "deinitOwn")) @compileError("CSSMixinRuleImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(CSSMixinRuleImpl, "deinit")) return CSSMixinRuleImpl.deinit(instance);
        if (comptime @hasDecl(CSSMixinRuleImpl, "deinitOwn")) CSSMixinRuleImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CSSMixinRule")) {
            if (comptime @hasDecl(impls.CSSMixinRule, "installHooks")) impls.CSSMixinRule.installHooks();
        }
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSMixinRuleImpl.get_name(instance);
    }

    pub fn get_contents(instance: *runtime.Instance) anyerror!bool {
        return try CSSMixinRuleImpl.get_contents(instance);
    }

    pub fn call_getParameters(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try CSSMixinRuleImpl.call_getParameters(instance);
    }
};
