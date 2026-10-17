//! Generated from: SVG.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGStringListImpl = @import("impls").SVGStringList;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const SVGStringList = struct {
    pub const Meta = struct {
        pub const name = "SVGStringList";
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
            .{ "length", "get_length", null },
            .{ "numberOfItems", "get_numberOfItems", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "clear", "call_clear", 0 },
            .{ "initialize", "call_initialize", 1 },
            .{ "getItem", "call_getItem", 1 },
            .{ "insertItemBefore", "call_insertItemBefore", 2 },
            .{ "replaceItem", "call_replaceItem", 2 },
            .{ "removeItem", "call_removeItem", 1 },
            .{ "appendItem", "call_appendItem", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "clear",
            "initialize",
            "getItem",
            "insertItemBefore",
            "replaceItem",
            "removeItem",
            "appendItem",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "length", "get_length", null },
            .{ "numberOfItems", "get_numberOfItems", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// WebIDL 2.5.6 special operations, own or inherited (the derived-most):
        /// the function that runs each. The binding installs indexed and named
        /// property handlers from this table (webidl.SpecialOperations).
        pub const special_operations: webidl.SpecialOperations = .{
            .indexed_getter = .{ .function = "call_getItem" },
            .indexed_setter = .{ .function = "call_setter", .implemented = @hasDecl(SVGStringListImpl, "call_setter") },
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            length: u32 = undefined,
            numberOfItems: u32 = undefined,
            _internal: ?*SVGStringListImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_length = &get_length,
        .get_numberOfItems = &get_numberOfItems,

        .call_appendItem = &call_appendItem,
        .call_clear = &call_clear,
        .call_getItem = &call_getItem,
        .call_initialize = &call_initialize,
        .call_insertItemBefore = &call_insertItemBefore,
        .call_removeItem = &call_removeItem,
        .call_replaceItem = &call_replaceItem,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("SVGStringList has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(SVGStringListImpl, "init") and @hasDecl(SVGStringListImpl, "initOwn")) @compileError("SVGStringListImpl defines both init and initOwn");
        if (comptime @hasDecl(SVGStringListImpl, "init")) return SVGStringListImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(SVGStringListImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try SVGStringListImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SVGStringListImpl, "init")) return false;
        if (comptime @hasDecl(SVGStringListImpl, "construction_args")) {
            inline for (SVGStringListImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(SVGStringListImpl, "deinit") and @hasDecl(SVGStringListImpl, "deinitOwn")) @compileError("SVGStringListImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SVGStringListImpl, "deinit")) return SVGStringListImpl.deinit(instance);
        if (comptime @hasDecl(SVGStringListImpl, "deinitOwn")) SVGStringListImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SVGStringList")) {
            if (comptime @hasDecl(impls.SVGStringList, "installHooks")) impls.SVGStringList.installHooks();
        }
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try SVGStringListImpl.get_length(instance);
    }

    pub fn get_numberOfItems(instance: *runtime.Instance) anyerror!u32 {
        return try SVGStringListImpl.get_numberOfItems(instance);
    }

    pub fn call_setter(instance: *runtime.Instance, index: u32, newItem: runtime.DOMString) anyerror!void {
        if (comptime @hasDecl(SVGStringListImpl, "call_setter")) {
            return try SVGStringListImpl.call_setter(instance, index, newItem);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_removeItem(instance: *runtime.Instance, index: u32) anyerror!runtime.DOMString {
        return try SVGStringListImpl.call_removeItem(instance, index);
    }

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try SVGStringListImpl.call_clear(instance);
    }

    pub fn call_appendItem(instance: *runtime.Instance, newItem: runtime.DOMString) anyerror!runtime.DOMString {
        return try SVGStringListImpl.call_appendItem(instance, newItem);
    }

    pub fn call_insertItemBefore(instance: *runtime.Instance, newItem: runtime.DOMString, index: u32) anyerror!runtime.DOMString {
        return try SVGStringListImpl.call_insertItemBefore(instance, newItem, index);
    }

    pub fn call_initialize(instance: *runtime.Instance, newItem: runtime.DOMString) anyerror!runtime.DOMString {
        return try SVGStringListImpl.call_initialize(instance, newItem);
    }

    pub fn call_getItem(instance: *runtime.Instance, index: u32) anyerror!runtime.DOMString {
        return try SVGStringListImpl.call_getItem(instance, index);
    }

    pub fn call_replaceItem(instance: *runtime.Instance, newItem: runtime.DOMString, index: u32) anyerror!runtime.DOMString {
        return try SVGStringListImpl.call_replaceItem(instance, newItem, index);
    }
};
