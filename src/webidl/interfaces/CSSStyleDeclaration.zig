//! Generated from: cssom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSStyleDeclarationImpl = @import("impls").CSSStyleDeclaration;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSOMString = @import("typedefs").CSSOMString;
const CSSRule = @import("interfaces").CSSRule;

pub const CSSStyleDeclaration = struct {
    pub const Meta = struct {
        pub const name = "CSSStyleDeclaration";
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
            .{ "length", "get_length", null },
            .{ "parentRule", "get_parentRule", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "item", "call_item", 1 },
            .{ "getPropertyValue", "call_getPropertyValue", 1 },
            .{ "getPropertyPriority", "call_getPropertyPriority", 1 },
            .{ "setProperty", "call_setProperty", 2 },
            .{ "removeProperty", "call_removeProperty", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "item",
            "getPropertyValue",
            "getPropertyPriority",
            "setProperty",
            "removeProperty",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "cssText", "get_cssText", "set_cssText" },
            .{ "length", "get_length", null },
            .{ "parentRule", "get_parentRule", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// WebIDL 2.5.6 special operations, own or inherited (the derived-most):
        /// the function that runs each. The binding installs indexed and named
        /// property handlers from this table (webidl.SpecialOperations).
        pub const special_operations: webidl.SpecialOperations = .{
            .indexed_getter = .{ .function = "call_item" },
            .named_getter = .{ .function = "call_namedItem" },
            .named_setter = .{ .function = "call_setNamedItem" },
            .crane_css_properties = true,
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            cssText: typedefs.CSSOMString = undefined,
            length: u32 = undefined,
            parentRule: ?*runtime.Instance = null,
            _internal: ?*CSSStyleDeclarationImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_cssText = &get_cssText,
        .get_length = &get_length,
        .get_parentRule = &get_parentRule,

        .set_cssText = &set_cssText,

        .call_getPropertyPriority = &call_getPropertyPriority,
        .call_getPropertyValue = &call_getPropertyValue,
        .call_item = &call_item,
        .call_removeProperty = &call_removeProperty,
        .call_setProperty = &call_setProperty,

        .call_namedItem = &call_namedItem,
        .call_setNamedItem = &call_setNamedItem,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("CSSStyleDeclaration has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(CSSStyleDeclarationImpl, "init") and @hasDecl(CSSStyleDeclarationImpl, "initOwn")) @compileError("CSSStyleDeclarationImpl defines both init and initOwn");
        if (comptime @hasDecl(CSSStyleDeclarationImpl, "init")) return CSSStyleDeclarationImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(CSSStyleDeclarationImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try CSSStyleDeclarationImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CSSStyleDeclarationImpl, "init")) return false;
        if (comptime @hasDecl(CSSStyleDeclarationImpl, "construction_args")) {
            inline for (CSSStyleDeclarationImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(CSSStyleDeclarationImpl, "deinit") and @hasDecl(CSSStyleDeclarationImpl, "deinitOwn")) @compileError("CSSStyleDeclarationImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(CSSStyleDeclarationImpl, "deinit")) return CSSStyleDeclarationImpl.deinit(instance);
        if (comptime @hasDecl(CSSStyleDeclarationImpl, "deinitOwn")) CSSStyleDeclarationImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CSSStyleDeclaration")) {
            if (comptime @hasDecl(impls.CSSStyleDeclaration, "installHooks")) impls.CSSStyleDeclaration.installHooks();
        }
    }

    /// Extended attributes: [CEReactions]
    pub fn get_cssText(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSStyleDeclarationImpl.get_cssText(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_cssText(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try CSSStyleDeclarationImpl.set_cssText(instance, value);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try CSSStyleDeclarationImpl.get_length(instance);
    }

    pub fn get_parentRule(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try CSSStyleDeclarationImpl.get_parentRule(instance);
    }

    pub fn call_getPropertyPriority(instance: *runtime.Instance, property: CSSOMString) anyerror!CSSOMString {
        return try CSSStyleDeclarationImpl.call_getPropertyPriority(instance, property);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setProperty(instance: *runtime.Instance, property: CSSOMString, value: CSSOMString, priority: webidl.Opt(CSSOMString)) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try CSSStyleDeclarationImpl.call_setProperty(instance, property, value, priority);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeProperty(instance: *runtime.Instance, property: CSSOMString) anyerror!CSSOMString {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try CSSStyleDeclarationImpl.call_removeProperty(instance, property);
    }

    pub fn call_getPropertyValue(instance: *runtime.Instance, property: CSSOMString) anyerror!CSSOMString {
        return try CSSStyleDeclarationImpl.call_getPropertyValue(instance, property);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!CSSOMString {
        return try CSSStyleDeclarationImpl.call_item(instance, index);
    }

    /// WebIDL [LegacyNullToEmptyString]: the values null converts to "" for
    /// (bit i = argument i; an attribute setter's value is bit 0).
    pub const legacy_null_to_empty = .{
        .{ "call_setProperty", 0b110 },
    };

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "set_cssText",
        "call_setProperty",
        "call_removeProperty",
    };

    /// Named property getter for CSS property access
    /// Maps style.color, style.backgroundColor to getPropertyValue()
    /// Per CSS OM spec §6.6.1
    pub fn call_namedItem(instance: *runtime.Instance, name: runtime.DOMString) anyerror!?runtime.DOMString {
        return CSSStyleDeclarationImpl.call_namedItem(instance, name);
    }

    /// Named property setter for CSS property access
    /// Maps style.color = "red" to setProperty()
    /// Per CSS OM spec §6.6.1
    pub fn call_setNamedItem(instance: *runtime.Instance, name: runtime.DOMString, value: runtime.DOMString) anyerror!void {
        return CSSStyleDeclarationImpl.call_setNamedItem(instance, name, value);
    }

    /// Get supported property names for CSS property enumeration
    /// Returns CSS property names that have been set on this declaration
    pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
        return CSSStyleDeclarationImpl.getSupportedPropertyNames(instance, allocator);
    }
};
