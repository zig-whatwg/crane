//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLOptionsCollectionImpl = @import("impls").HTMLOptionsCollection;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const HTMLCollection = @import("interfaces").HTMLCollection;
const Element = @import("interfaces").Element;
const HTMLOptionElement = @import("interfaces").HTMLOptionElement;
const HTMLOptionElementOrHTMLOptGroupElement = @import("typedefs").HTMLOptionElementOrHTMLOptGroupElement;
const HTMLElement = @import("interfaces").HTMLElement;
const DOMString = @import("typedefs").DOMString;

pub const HTMLOptionsCollection = struct {
    pub const Meta = struct {
        pub const name = "HTMLOptionsCollection";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = HTMLCollection.State;
        pub const ParentInterface = HTMLCollection;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "length", "get_length", "set_length" },
            .{ "selectedIndex", "get_selectedIndex", "set_selectedIndex" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "add", "call_add", 1 },
            .{ "remove", "call_remove", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "add",
            "remove",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "item",
            "namedItem",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "length", "get_length", "set_length" },
            .{ "selectedIndex", "get_selectedIndex", "set_selectedIndex" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// WebIDL 2.5.6 special operations, own or inherited (the derived-most):
        /// the function that runs each. The binding installs indexed and named
        /// property handlers from this table (webidl.SpecialOperations).
        pub const special_operations: webidl.SpecialOperations = .{
            .indexed_getter = .{ .function = "call_item" },
            .indexed_setter = .{ .function = "call_setter", .implemented = @hasDecl(HTMLOptionsCollectionImpl, "call_setter") },
            .named_getter = .{ .function = "call_namedItem" },
            .supported_property_name = .{ .function = "isSupportedPropertyName", .implemented = HTMLCollection.Meta.special_operations.supported_property_name.?.implemented },
            .legacy_unenumerable_named_properties = true,
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            length: u32 = undefined,
            selectedIndex: i32 = undefined,
            _internal: ?*HTMLOptionsCollectionImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_length = &get_length,
        .get_selectedIndex = &get_selectedIndex,

        .set_length = &set_length,
        .set_selectedIndex = &set_selectedIndex,

        .call_add = &call_add,
        .call_remove = &call_remove,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("HTMLOptionsCollection has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(HTMLOptionsCollectionImpl, "init") and @hasDecl(HTMLOptionsCollectionImpl, "initOwn")) @compileError("HTMLOptionsCollectionImpl defines both init and initOwn");
        if (comptime @hasDecl(HTMLOptionsCollectionImpl, "init")) return HTMLOptionsCollectionImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(HTMLOptionsCollectionImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try HTMLOptionsCollectionImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(HTMLOptionsCollectionImpl, "init")) return false;
        if (comptime @hasDecl(HTMLOptionsCollectionImpl, "construction_args")) {
            inline for (HTMLOptionsCollectionImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(HTMLOptionsCollectionImpl, "deinit") and @hasDecl(HTMLOptionsCollectionImpl, "deinitOwn")) @compileError("HTMLOptionsCollectionImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(HTMLOptionsCollectionImpl, "deinit")) return HTMLOptionsCollectionImpl.deinit(instance);
        if (comptime @hasDecl(HTMLOptionsCollectionImpl, "deinitOwn")) HTMLOptionsCollectionImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "HTMLOptionsCollection")) {
            if (comptime @hasDecl(impls.HTMLOptionsCollection, "installHooks")) impls.HTMLOptionsCollection.installHooks();
        }
    }

    /// Extended attributes: [CEReactions]
    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLOptionsCollectionImpl.get_length(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_length(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try HTMLOptionsCollectionImpl.set_length(instance, value);
    }

    pub fn get_selectedIndex(instance: *runtime.Instance) anyerror!i32 {
        return try HTMLOptionsCollectionImpl.get_selectedIndex(instance);
    }

    pub fn set_selectedIndex(instance: *runtime.Instance, value: i32) anyerror!void {
        try HTMLOptionsCollectionImpl.set_selectedIndex(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setter(instance: *runtime.Instance, index: u32, option: ?*runtime.Instance) anyerror!void {
        if (comptime @hasDecl(HTMLOptionsCollectionImpl, "call_setter")) {
            // [CEReactions] - Trigger Custom Element lifecycle callbacks
            const ce_scope = runtime.CEReactions.begin(instance);
            defer runtime.CEReactions.end(ce_scope);

            return try HTMLOptionsCollectionImpl.call_setter(instance, index, option);
        } else {
            return error.NotImplemented;
        }
    }

    /// Extended attributes: [CEReactions]
    pub fn call_remove(instance: *runtime.Instance, index: i32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try HTMLOptionsCollectionImpl.call_remove(instance, index);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_add(instance: *runtime.Instance, element: HTMLOptionElementOrHTMLOptGroupElement, before: webidl.Opt(?runtime.JSValue)) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try HTMLOptionsCollectionImpl.call_add(instance, element, before);
    }

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "set_length",
        "call_setter",
        "call_remove",
        "call_add",
    };

    pub const call_item = HTMLCollection.call_item;

    pub const call_namedItem = HTMLCollection.call_namedItem;

    pub const getSupportedPropertyNames = HTMLCollection.getSupportedPropertyNames;

    pub const isSupportedPropertyName = HTMLCollection.isSupportedPropertyName;
};
