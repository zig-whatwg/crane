//! Generated from: DOM-Style.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSValueImpl = @import("impls").CSSValue;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const CSSValue = struct {
    pub const Meta = struct {
        pub const name = "CSSValue";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "cssText", "get_cssText", "set_cssText" },
            .{ "cssValueType", "get_cssValueType", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "CSS_INHERIT", "get_CSS_INHERIT" },
            .{ "CSS_PRIMITIVE_VALUE", "get_CSS_PRIMITIVE_VALUE" },
            .{ "CSS_VALUE_LIST", "get_CSS_VALUE_LIST" },
            .{ "CSS_CUSTOM", "get_CSS_CUSTOM" },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "cssText", "get_cssText", "set_cssText" },
            .{ "cssValueType", "get_cssValueType", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            cssText: typedefs.DOMString = undefined,
            cssValueType: u16 = undefined,
            _internal: ?*CSSValueImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short CSS_INHERIT = 0;
    pub fn get_CSS_INHERIT() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short CSS_PRIMITIVE_VALUE = 1;
    pub fn get_CSS_PRIMITIVE_VALUE() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short CSS_VALUE_LIST = 2;
    pub fn get_CSS_VALUE_LIST() u16 {
        return 2;
    }

    /// WebIDL constant: const unsigned short CSS_CUSTOM = 3;
    pub fn get_CSS_CUSTOM() u16 {
        return 3;
    }

    const delegates = .{
        .get_CSS_CUSTOM = &get_CSS_CUSTOM,
        .get_CSS_INHERIT = &get_CSS_INHERIT,
        .get_CSS_PRIMITIVE_VALUE = &get_CSS_PRIMITIVE_VALUE,
        .get_CSS_VALUE_LIST = &get_CSS_VALUE_LIST,
        .get_cssText = &get_cssText,
        .get_cssValueType = &get_cssValueType,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("CSSValue has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(CSSValueImpl, "init") and @hasDecl(CSSValueImpl, "initOwn")) @compileError("CSSValueImpl defines both init and initOwn");
        if (comptime @hasDecl(CSSValueImpl, "init")) return CSSValueImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(CSSValueImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try CSSValueImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CSSValueImpl, "init")) return false;
        if (comptime @hasDecl(CSSValueImpl, "construction_args")) {
            inline for (CSSValueImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(CSSValueImpl, "deinit") and @hasDecl(CSSValueImpl, "deinitOwn")) @compileError("CSSValueImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(CSSValueImpl, "deinit")) return CSSValueImpl.deinit(instance);
        if (comptime @hasDecl(CSSValueImpl, "deinitOwn")) CSSValueImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CSSValue")) {
            if (comptime @hasDecl(impls.CSSValue, "installHooks")) impls.CSSValue.installHooks();
        }
    }

    pub fn get_cssText(instance: *runtime.Instance) anyerror!DOMString {
        return try CSSValueImpl.get_cssText(instance);
    }

    pub fn set_cssText(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try CSSValueImpl.set_cssText(instance, value);
    }

    pub fn get_cssValueType(instance: *runtime.Instance) anyerror!u16 {
        return try CSSValueImpl.get_cssValueType(instance);
    }
};
