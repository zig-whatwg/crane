//! Generated from: cssom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSPageDescriptorsImpl = @import("impls").CSSPageDescriptors;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const CSSOMString = @import("typedefs").CSSOMString;
const CSSRule = @import("interfaces").CSSRule;

pub const CSSPageDescriptors = struct {
    pub const Meta = struct {
        pub const name = "CSSPageDescriptors";
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
            .{ "margin", "get_margin", "set_margin" },
            .{ "marginTop", "get_marginTop", "set_marginTop" },
            .{ "marginRight", "get_marginRight", "set_marginRight" },
            .{ "marginBottom", "get_marginBottom", "set_marginBottom" },
            .{ "marginLeft", "get_marginLeft", "set_marginLeft" },
            .{ "margin-top", "get_margin_top", "set_margin_top" },
            .{ "margin-right", "get_margin_right", "set_margin_right" },
            .{ "margin-bottom", "get_margin_bottom", "set_margin_bottom" },
            .{ "margin-left", "get_margin_left", "set_margin_left" },
            .{ "size", "get_size", "set_size" },
            .{ "pageOrientation", "get_pageOrientation", "set_pageOrientation" },
            .{ "page-orientation", "get_page_orientation", "set_page_orientation" },
            .{ "marks", "get_marks", "set_marks" },
            .{ "bleed", "get_bleed", "set_bleed" },
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
            .{ "margin", "get_margin", "set_margin" },
            .{ "marginTop", "get_marginTop", "set_marginTop" },
            .{ "marginRight", "get_marginRight", "set_marginRight" },
            .{ "marginBottom", "get_marginBottom", "set_marginBottom" },
            .{ "marginLeft", "get_marginLeft", "set_marginLeft" },
            .{ "margin-top", "get_margin_top", "set_margin_top" },
            .{ "margin-right", "get_margin_right", "set_margin_right" },
            .{ "margin-bottom", "get_margin_bottom", "set_margin_bottom" },
            .{ "margin-left", "get_margin_left", "set_margin_left" },
            .{ "size", "get_size", "set_size" },
            .{ "pageOrientation", "get_pageOrientation", "set_pageOrientation" },
            .{ "page-orientation", "get_page_orientation", "set_page_orientation" },
            .{ "marks", "get_marks", "set_marks" },
            .{ "bleed", "get_bleed", "set_bleed" },
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
            margin: typedefs.CSSOMString = undefined,
            marginTop: typedefs.CSSOMString = undefined,
            marginRight: typedefs.CSSOMString = undefined,
            marginBottom: typedefs.CSSOMString = undefined,
            marginLeft: typedefs.CSSOMString = undefined,
            @"margin-top": typedefs.CSSOMString = undefined,
            @"margin-right": typedefs.CSSOMString = undefined,
            @"margin-bottom": typedefs.CSSOMString = undefined,
            @"margin-left": typedefs.CSSOMString = undefined,
            size: typedefs.CSSOMString = undefined,
            pageOrientation: typedefs.CSSOMString = undefined,
            @"page-orientation": typedefs.CSSOMString = undefined,
            marks: typedefs.CSSOMString = undefined,
            bleed: typedefs.CSSOMString = undefined,
            _internal: ?*CSSPageDescriptorsImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_bleed = &get_bleed,
        .get_margin = &get_margin,
        .get_marginBottom = &get_marginBottom,
        .get_marginLeft = &get_marginLeft,
        .get_marginRight = &get_marginRight,
        .get_marginTop = &get_marginTop,
        .get_margin_bottom = &get_margin_bottom,
        .get_margin_left = &get_margin_left,
        .get_margin_right = &get_margin_right,
        .get_margin_top = &get_margin_top,
        .get_marks = &get_marks,
        .get_pageOrientation = &get_pageOrientation,
        .get_page_orientation = &get_page_orientation,
        .get_size = &get_size,

        .set_bleed = &set_bleed,
        .set_margin = &set_margin,
        .set_marginBottom = &set_marginBottom,
        .set_marginLeft = &set_marginLeft,
        .set_marginRight = &set_marginRight,
        .set_marginTop = &set_marginTop,
        .set_margin_bottom = &set_margin_bottom,
        .set_margin_left = &set_margin_left,
        .set_margin_right = &set_margin_right,
        .set_margin_top = &set_margin_top,
        .set_marks = &set_marks,
        .set_pageOrientation = &set_pageOrientation,
        .set_page_orientation = &set_page_orientation,
        .set_size = &set_size,

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
        inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
            if (comptime !takesConstructionArg(field.name)) @compileError("CSSPageDescriptors has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(CSSPageDescriptorsImpl, "init") and @hasDecl(CSSPageDescriptorsImpl, "initOwn")) @compileError("CSSPageDescriptorsImpl defines both init and initOwn");
        if (comptime @hasDecl(CSSPageDescriptorsImpl, "init")) return CSSPageDescriptorsImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(CSSPageDescriptorsImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try CSSPageDescriptorsImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CSSPageDescriptorsImpl, "init")) return false;
        if (comptime @hasDecl(CSSPageDescriptorsImpl, "construction_args")) {
            inline for (CSSPageDescriptorsImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(CSSPageDescriptorsImpl, "deinit") and @hasDecl(CSSPageDescriptorsImpl, "deinitOwn")) @compileError("CSSPageDescriptorsImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(CSSPageDescriptorsImpl, "deinit")) return CSSPageDescriptorsImpl.deinit(instance);
        if (comptime @hasDecl(CSSPageDescriptorsImpl, "deinitOwn")) CSSPageDescriptorsImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CSSPageDescriptors")) {
            if (comptime @hasDecl(impls.CSSPageDescriptors, "installHooks")) impls.CSSPageDescriptors.installHooks();
        }
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_margin(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_margin(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_margin(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_margin(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_marginTop(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_marginTop(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_marginTop(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_marginTop(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_marginRight(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_marginRight(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_marginRight(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_marginRight(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_marginBottom(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_marginBottom(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_marginBottom(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_marginBottom(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_marginLeft(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_marginLeft(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_marginLeft(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_marginLeft(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_margin_top(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_margin_top(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_margin_top(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_margin_top(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_margin_right(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_margin_right(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_margin_right(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_margin_right(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_margin_bottom(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_margin_bottom(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_margin_bottom(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_margin_bottom(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_margin_left(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_margin_left(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_margin_left(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_margin_left(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_size(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_size(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_size(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_size(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_pageOrientation(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_pageOrientation(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_pageOrientation(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_pageOrientation(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_page_orientation(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_page_orientation(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_page_orientation(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_page_orientation(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_marks(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_marks(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_marks(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_marks(instance, value);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn get_bleed(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPageDescriptorsImpl.get_bleed(instance);
    }

    /// Extended attributes: [LegacyNullToEmptyString]
    pub fn set_bleed(instance: *runtime.Instance, value: CSSOMString) anyerror!void {
        try CSSPageDescriptorsImpl.set_bleed(instance, value);
    }

    /// WebIDL [LegacyNullToEmptyString]: the values null converts to "" for
    /// (bit i = argument i; an attribute setter's value is bit 0).
    pub const legacy_null_to_empty = .{
        .{ "set_margin", 0b1 },
        .{ "set_marginTop", 0b1 },
        .{ "set_marginRight", 0b1 },
        .{ "set_marginBottom", 0b1 },
        .{ "set_marginLeft", 0b1 },
        .{ "set_margin_top", 0b1 },
        .{ "set_margin_right", 0b1 },
        .{ "set_margin_bottom", 0b1 },
        .{ "set_margin_left", 0b1 },
        .{ "set_size", 0b1 },
        .{ "set_pageOrientation", 0b1 },
        .{ "set_page_orientation", 0b1 },
        .{ "set_marks", 0b1 },
        .{ "set_bleed", 0b1 },
    };

    pub const call_item = CSSStyleDeclaration.call_item;

    pub const get_length = CSSStyleDeclaration.get_length;

    /// Named property getter for CSS property access
    /// Maps style.color, style.backgroundColor to getPropertyValue()
    /// Per CSS OM spec §6.6.1
    pub fn call_namedItem(instance: *runtime.Instance, name: runtime.DOMString) anyerror!?runtime.DOMString {
        return CSSPageDescriptorsImpl.call_namedItem(instance, name);
    }

    /// Named property setter for CSS property access
    /// Maps style.color = "red" to setProperty()
    /// Per CSS OM spec §6.6.1
    pub fn call_setNamedItem(instance: *runtime.Instance, name: runtime.DOMString, value: runtime.DOMString) anyerror!void {
        return CSSPageDescriptorsImpl.call_setNamedItem(instance, name, value);
    }

    /// Get supported property names for CSS property enumeration
    /// Returns CSS property names that have been set on this declaration
    pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
        return CSSPageDescriptorsImpl.getSupportedPropertyNames(instance, allocator);
    }
};
