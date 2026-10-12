//! Generated from: cssom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSRuleImpl = @import("impls").CSSRule;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;

pub const CSSRule = struct {
    pub const Meta = struct {
        pub const name = "CSSRule";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "cssText", "get_cssText", "set_cssText" },
            .{ "parentRule", "get_parentRule", null },
            .{ "parentStyleSheet", "get_parentStyleSheet", null },
            .{ "type", "get_type", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "STYLE_RULE", "get_STYLE_RULE" },
            .{ "CHARSET_RULE", "get_CHARSET_RULE" },
            .{ "IMPORT_RULE", "get_IMPORT_RULE" },
            .{ "MEDIA_RULE", "get_MEDIA_RULE" },
            .{ "FONT_FACE_RULE", "get_FONT_FACE_RULE" },
            .{ "PAGE_RULE", "get_PAGE_RULE" },
            .{ "MARGIN_RULE", "get_MARGIN_RULE" },
            .{ "NAMESPACE_RULE", "get_NAMESPACE_RULE" },
            .{ "KEYFRAMES_RULE", "get_KEYFRAMES_RULE" },
            .{ "KEYFRAME_RULE", "get_KEYFRAME_RULE" },
            .{ "SUPPORTS_RULE", "get_SUPPORTS_RULE" },
            .{ "COUNTER_STYLE_RULE", "get_COUNTER_STYLE_RULE" },
            .{ "FONT_FEATURE_VALUES_RULE", "get_FONT_FEATURE_VALUES_RULE" },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "cssText", "get_cssText", "set_cssText" },
            .{ "parentRule", "get_parentRule", null },
            .{ "parentStyleSheet", "get_parentStyleSheet", null },
            .{ "type", "get_type", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            cssText: typedefs.CSSOMString = undefined,
            parentRule: ?*runtime.Instance = null,
            parentStyleSheet: ?*runtime.Instance = null,
            type: u16 = undefined,
            _internal: ?*CSSRuleImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short STYLE_RULE = 1;
    pub fn get_STYLE_RULE() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short CHARSET_RULE = 2;
    pub fn get_CHARSET_RULE() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short IMPORT_RULE = 3;
    pub fn get_IMPORT_RULE() u16 {
        return 3;
    }

    /// WebIDL constant: const unsigned short MEDIA_RULE = 4;
    pub fn get_MEDIA_RULE() u16 {
        return 4;
    }

    /// WebIDL constant: const unsigned short FONT_FACE_RULE = 5;
    pub fn get_FONT_FACE_RULE() u16 {
        return 5;
    }

    /// WebIDL constant: const unsigned short PAGE_RULE = 6;
    pub fn get_PAGE_RULE() u16 {
        return 6;
    }

    /// WebIDL constant: const unsigned short MARGIN_RULE = 9;
    pub fn get_MARGIN_RULE() u16 {
        return 9;
    }

    /// WebIDL constant: const unsigned short NAMESPACE_RULE = 10;
    pub fn get_NAMESPACE_RULE() u16 {
        return 10;
    }

    /// WebIDL constant: const unsigned short KEYFRAMES_RULE = 7;
    pub fn get_KEYFRAMES_RULE() u16 {
        return 7;
    }

    /// WebIDL constant: const unsigned short KEYFRAME_RULE = 8;
    pub fn get_KEYFRAME_RULE() u16 {
        return 8;
    }

    /// WebIDL constant: const unsigned short SUPPORTS_RULE = 12;
    pub fn get_SUPPORTS_RULE() u16 {
        return 12;
    }

    /// WebIDL constant: const unsigned short COUNTER_STYLE_RULE = 11;
    pub fn get_COUNTER_STYLE_RULE() u16 {
        return 11;
    }

    /// WebIDL constant: const unsigned short FONT_FEATURE_VALUES_RULE = 14;
    pub fn get_FONT_FEATURE_VALUES_RULE() u16 {
        return 14;
    }

    const delegates = .{
        .get_CHARSET_RULE = &get_CHARSET_RULE,
        .get_COUNTER_STYLE_RULE = &get_COUNTER_STYLE_RULE,
        .get_FONT_FACE_RULE = &get_FONT_FACE_RULE,
        .get_FONT_FEATURE_VALUES_RULE = &get_FONT_FEATURE_VALUES_RULE,
        .get_IMPORT_RULE = &get_IMPORT_RULE,
        .get_KEYFRAMES_RULE = &get_KEYFRAMES_RULE,
        .get_KEYFRAME_RULE = &get_KEYFRAME_RULE,
        .get_MARGIN_RULE = &get_MARGIN_RULE,
        .get_MEDIA_RULE = &get_MEDIA_RULE,
        .get_NAMESPACE_RULE = &get_NAMESPACE_RULE,
        .get_PAGE_RULE = &get_PAGE_RULE,
        .get_STYLE_RULE = &get_STYLE_RULE,
        .get_SUPPORTS_RULE = &get_SUPPORTS_RULE,
        .get_cssText = &get_cssText,
        .get_parentRule = &get_parentRule,
        .get_parentStyleSheet = &get_parentStyleSheet,
        .get_type = &get_type,

        .set_cssText = &set_cssText,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("CSSRule has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(CSSRuleImpl, "init") and @hasDecl(CSSRuleImpl, "initOwn")) @compileError("CSSRuleImpl defines both init and initOwn");
        if (comptime @hasDecl(CSSRuleImpl, "init")) return CSSRuleImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(CSSRuleImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try CSSRuleImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CSSRuleImpl, "init")) return false;
        if (comptime @hasDecl(CSSRuleImpl, "construction_args")) {
            inline for (CSSRuleImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(CSSRuleImpl, "deinit") and @hasDecl(CSSRuleImpl, "deinitOwn")) @compileError("CSSRuleImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(CSSRuleImpl, "deinit")) return CSSRuleImpl.deinit(instance);
        if (comptime @hasDecl(CSSRuleImpl, "deinitOwn")) CSSRuleImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CSSRule")) {
            if (comptime @hasDecl(impls.CSSRule, "installHooks")) impls.CSSRule.installHooks();
        }
    }

    pub fn get_cssText(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSRuleImpl.get_cssText(instance);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSRuleImpl.set_cssText(instance, value);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try CSSRuleImpl.get_parentRule(instance);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try CSSRuleImpl.get_parentStyleSheet(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!u16 {
        return try CSSRuleImpl.get_type(instance);
    }
};
