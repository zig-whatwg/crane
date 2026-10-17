//! Generated from: cssom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSStyleSheetImpl = @import("impls").CSSStyleSheet;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const StyleSheet = @import("interfaces").StyleSheet;
const Element = @import("interfaces").Element;
const CSSStyleSheetInit = @import("dictionaries").CSSStyleSheetInit;
const CSSRule = @import("interfaces").CSSRule;
const CSSOMString = @import("typedefs").CSSOMString;
const CSSRuleList = @import("interfaces").CSSRuleList;
const ProcessingInstruction = @import("interfaces").ProcessingInstruction;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;
const MediaList = @import("interfaces").MediaList;

pub const CSSStyleSheet = struct {
    pub const Meta = struct {
        pub const name = "CSSStyleSheet";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = StyleSheet.State;
        pub const ParentInterface = StyleSheet;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "ownerRule", "get_ownerRule", null },
            .{ "cssRules", "get_cssRules", null },
            .{ "rules", "get_rules", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "insertRule", "call_insertRule", 1 },
            .{ "deleteRule", "call_deleteRule", 1 },
            .{ "replace", "call_replace", 1 },
            .{ "replaceSync", "call_replaceSync", 1 },
            .{ "addRule", "call_addRule", 0 },
            .{ "removeRule", "call_removeRule", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "insertRule",
            "deleteRule",
            "replace",
            "replaceSync",
            "addRule",
            "removeRule",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "ownerRule", "get_ownerRule", null },
            .{ "cssRules", "get_cssRules", null },
            .{ "rules", "get_rules", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            ownerRule: ?*runtime.Instance = null,
            cssRules: *runtime.Instance = undefined,
            rules: *runtime.Instance = undefined,
            cached_cssRules: ?*runtime.Instance = null,
            cached_rules: ?*runtime.Instance = null,
            _internal: ?*CSSStyleSheetImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_cssRules = &get_cssRules,
        .get_ownerRule = &get_ownerRule,
        .get_rules = &get_rules,

        .call_addRule = &call_addRule,
        .call_deleteRule = &call_deleteRule,
        .call_insertRule = &call_insertRule,
        .call_removeRule = &call_removeRule,
        .call_replace = &call_replace,
        .call_replaceSync = &call_replaceSync,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("CSSStyleSheet has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(CSSStyleSheetImpl, "init") and @hasDecl(CSSStyleSheetImpl, "initOwn")) @compileError("CSSStyleSheetImpl defines both init and initOwn");
        if (comptime @hasDecl(CSSStyleSheetImpl, "init")) return CSSStyleSheetImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(CSSStyleSheetImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try CSSStyleSheetImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CSSStyleSheetImpl, "init")) return false;
        if (comptime @hasDecl(CSSStyleSheetImpl, "construction_args")) {
            inline for (CSSStyleSheetImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(CSSStyleSheetImpl, "deinit") and @hasDecl(CSSStyleSheetImpl, "deinitOwn")) @compileError("CSSStyleSheetImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(CSSStyleSheetImpl, "deinit")) return CSSStyleSheetImpl.deinit(instance);
        if (comptime @hasDecl(CSSStyleSheetImpl, "deinitOwn")) CSSStyleSheetImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CSSStyleSheet")) {
            if (comptime @hasDecl(impls.CSSStyleSheet, "installHooks")) impls.CSSStyleSheet.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, options: webidl.Opt(CSSStyleSheetInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSStyleSheetImpl.call_constructor(ctx, options);
    }

    pub fn get_ownerRule(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try CSSStyleSheetImpl.get_ownerRule(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_cssRules(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_cssRules) |cached| {
            return cached;
        }
        const value = try CSSStyleSheetImpl.get_cssRules(instance);
        state.own.cached_cssRules = value;
        @import("dom").same_object_cache.made(instance, value, "cssRules");
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_rules(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_rules) |cached| {
            return cached;
        }
        const value = try CSSStyleSheetImpl.get_rules(instance);
        state.own.cached_rules = value;
        @import("dom").same_object_cache.made(instance, value, "rules");
        return value;
    }

    pub fn call_removeRule(instance: *runtime.Instance, index: webidl.Opt(u32)) anyerror!void {
        return try CSSStyleSheetImpl.call_removeRule(instance, index);
    }

    pub fn call_replace(instance: *runtime.Instance, text: runtime.USVString) anyerror!runtime.JSValue {
        return try CSSStyleSheetImpl.call_replace(instance, text);
    }

    pub fn call_insertRule(instance: *runtime.Instance, rule: CSSOMString, index: webidl.Opt(u32)) anyerror!u32 {
        return try CSSStyleSheetImpl.call_insertRule(instance, rule, index);
    }

    pub fn call_replaceSync(instance: *runtime.Instance, text: runtime.USVString) anyerror!void {
        return try CSSStyleSheetImpl.call_replaceSync(instance, text);
    }

    pub fn call_addRule(instance: *runtime.Instance, selector: webidl.Opt(runtime.DOMString), style: webidl.Opt(runtime.DOMString), index: webidl.Opt(u32)) anyerror!i32 {
        return try CSSStyleSheetImpl.call_addRule(instance, selector, style, index);
    }

    pub fn call_deleteRule(instance: *runtime.Instance, index: u32) anyerror!void {
        return try CSSStyleSheetImpl.call_deleteRule(instance, index);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_replace",
    };
};
