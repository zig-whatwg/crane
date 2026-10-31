//! Generated from: cssom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSStylePropertiesImpl = @import("impls").CSSStyleProperties;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const CSSOMString = @import("typedefs").CSSOMString;
const CSSRule = @import("interfaces").CSSRule;

pub const CSSStyleProperties = struct {
    pub const Meta = struct {
        pub const name = "CSSStyleProperties";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = CSSStyleDeclaration.State;
        pub const ParentInterface = CSSStyleDeclaration;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "cssFloat", "get_cssFloat", "set_cssFloat" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "item",
            "getPropertyValue",
            "getPropertyPriority",
            "setProperty",
            "removeProperty",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "cssFloat", "get_cssFloat", "set_cssFloat" },
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
            cssFloat: typedefs.CSSOMString = undefined,
            _internal: ?*CSSStylePropertiesImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_cssFloat = &get_cssFloat,

        .set_cssFloat = &set_cssFloat,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("CSSStyleProperties has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(CSSStylePropertiesImpl, "init") and @hasDecl(CSSStylePropertiesImpl, "initOwn")) @compileError("CSSStylePropertiesImpl defines both init and initOwn");
        if (comptime @hasDecl(CSSStylePropertiesImpl, "init")) return CSSStylePropertiesImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(CSSStylePropertiesImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try CSSStylePropertiesImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CSSStylePropertiesImpl, "init")) return false;
        if (comptime @hasDecl(CSSStylePropertiesImpl, "construction_args")) {
            inline for (CSSStylePropertiesImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(CSSStylePropertiesImpl, "deinit") and @hasDecl(CSSStylePropertiesImpl, "deinitOwn")) @compileError("CSSStylePropertiesImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(CSSStylePropertiesImpl, "deinit")) return CSSStylePropertiesImpl.deinit(instance);
        if (comptime @hasDecl(CSSStylePropertiesImpl, "deinitOwn")) CSSStylePropertiesImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CSSStyleProperties")) {
            if (comptime @hasDecl(impls.CSSStyleProperties, "installHooks")) impls.CSSStyleProperties.installHooks();
        }
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn get_cssFloat(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSStylePropertiesImpl.get_cssFloat(instance);
    }

    /// Extended attributes: [CEReactions], [LegacyNullToEmptyString]
    pub fn set_cssFloat(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try CSSStylePropertiesImpl.set_cssFloat(instance, value);
    }

    /// WebIDL [LegacyNullToEmptyString]: the values null converts to "" for
    /// (bit i = argument i; an attribute setter's value is bit 0).
    pub const legacy_null_to_empty = .{
        .{ "set_cssFloat", 0b1 },
    };

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "set_cssFloat",
    };

    pub const call_item = CSSStyleDeclaration.call_item;

    pub const get_length = CSSStyleDeclaration.get_length;

    /// Named property getter for CSS property access
    /// Maps style.color, style.backgroundColor to getPropertyValue()
    /// Per CSS OM spec §6.6.1
    pub fn call_namedItem(instance: *runtime.Instance, name: runtime.DOMString) anyerror!?runtime.DOMString {
        return CSSStylePropertiesImpl.call_namedItem(instance, name);
    }

    /// Named property setter for CSS property access
    /// Maps style.color = "red" to setProperty()
    /// Per CSS OM spec §6.6.1
    pub fn call_setNamedItem(instance: *runtime.Instance, name: runtime.DOMString, value: runtime.DOMString) anyerror!void {
        return CSSStylePropertiesImpl.call_setNamedItem(instance, name, value);
    }

    /// Get supported property names for CSS property enumeration
    /// Returns CSS property names that have been set on this declaration
    pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
        return CSSStylePropertiesImpl.getSupportedPropertyNames(instance, allocator);
    }
};
