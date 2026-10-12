//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NamedNodeMapImpl = @import("impls").NamedNodeMap;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Attr = @import("interfaces").Attr;
const DOMString = @import("typedefs").DOMString;

pub const NamedNodeMap = struct {
    pub const Meta = struct {
        pub const name = "NamedNodeMap";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "LegacyUnenumerableNamedProperties" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "length", "get_length", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "item", "call_item", 1 },
            .{ "getNamedItem", "call_getNamedItem", 1 },
            .{ "getNamedItemNS", "call_getNamedItemNS", 2 },
            .{ "setNamedItem", "call_setNamedItem", 1 },
            .{ "setNamedItemNS", "call_setNamedItemNS", 1 },
            .{ "removeNamedItem", "call_removeNamedItem", 1 },
            .{ "removeNamedItemNS", "call_removeNamedItemNS", 2 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "item",
            "getNamedItem",
            "getNamedItemNS",
            "setNamedItem",
            "setNamedItemNS",
            "removeNamedItem",
            "removeNamedItemNS",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "length", "get_length", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// WebIDL 2.5.6 special operations, own or inherited (the derived-most):
        /// the function that runs each. The binding installs indexed and named
        /// property handlers from this table (webidl.SpecialOperations).
        pub const special_operations: webidl.SpecialOperations = .{
            .indexed_getter = .{ .function = "call_item" },
            .named_getter = .{ .function = "call_getNamedItem" },
            .legacy_unenumerable_named_properties = true,
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            length: u32 = undefined,
            _internal: ?*NamedNodeMapImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_length = &get_length,

        .call_getNamedItem = &call_getNamedItem,
        .call_getNamedItemNS = &call_getNamedItemNS,
        .call_item = &call_item,
        .call_removeNamedItem = &call_removeNamedItem,
        .call_removeNamedItemNS = &call_removeNamedItemNS,
        .call_setNamedItem = &call_setNamedItem,
        .call_setNamedItemNS = &call_setNamedItemNS,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("NamedNodeMap has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(NamedNodeMapImpl, "init") and @hasDecl(NamedNodeMapImpl, "initOwn")) @compileError("NamedNodeMapImpl defines both init and initOwn");
        if (comptime @hasDecl(NamedNodeMapImpl, "init")) return NamedNodeMapImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(NamedNodeMapImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try NamedNodeMapImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(NamedNodeMapImpl, "init")) return false;
        if (comptime @hasDecl(NamedNodeMapImpl, "construction_args")) {
            inline for (NamedNodeMapImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(NamedNodeMapImpl, "deinit") and @hasDecl(NamedNodeMapImpl, "deinitOwn")) @compileError("NamedNodeMapImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(NamedNodeMapImpl, "deinit")) return NamedNodeMapImpl.deinit(instance);
        if (comptime @hasDecl(NamedNodeMapImpl, "deinitOwn")) NamedNodeMapImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "NamedNodeMap")) {
            if (comptime @hasDecl(impls.NamedNodeMap, "installHooks")) impls.NamedNodeMap.installHooks();
        }
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try NamedNodeMapImpl.get_length(instance);
    }

    pub fn call_getNamedItem(instance: *runtime.Instance, qualifiedName: DOMString) anyerror!?*runtime.Instance {
        return try NamedNodeMapImpl.call_getNamedItem(instance, qualifiedName);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeNamedItem(instance: *runtime.Instance, qualifiedName: DOMString) anyerror!*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);

        const result = NamedNodeMapImpl.call_removeNamedItem(instance, qualifiedName) catch |err| {
            runtime.CEReactions.end(ce_scope);
            return err;
        };
        // A result the reactions freed (its realm ended) is not returned.
        const result_generation = runtime.SlabAllocator.generationOf(result);
        runtime.CEReactions.end(ce_scope);
        if (runtime.SlabAllocator.generationOf(result) != result_generation) return error.InvalidStateError;
        return result;
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setNamedItem(instance: *runtime.Instance, attr: *runtime.Instance) anyerror!?*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);

        const result = NamedNodeMapImpl.call_setNamedItem(instance, attr) catch |err| {
            runtime.CEReactions.end(ce_scope);
            return err;
        };
        // A result the reactions freed (its realm ended) is not returned.
        const result_generation = if (result) |r| runtime.SlabAllocator.generationOf(r) else 0;
        runtime.CEReactions.end(ce_scope);
        if (result) |r| if (runtime.SlabAllocator.generationOf(r) != result_generation) return error.InvalidStateError;
        return result;
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setNamedItemNS(instance: *runtime.Instance, attr: *runtime.Instance) anyerror!?*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);

        const result = NamedNodeMapImpl.call_setNamedItemNS(instance, attr) catch |err| {
            runtime.CEReactions.end(ce_scope);
            return err;
        };
        // A result the reactions freed (its realm ended) is not returned.
        const result_generation = if (result) |r| runtime.SlabAllocator.generationOf(r) else 0;
        runtime.CEReactions.end(ce_scope);
        if (result) |r| if (runtime.SlabAllocator.generationOf(r) != result_generation) return error.InvalidStateError;
        return result;
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeNamedItemNS(instance: *runtime.Instance, namespace: ?DOMString, localName: DOMString) anyerror!*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);

        const result = NamedNodeMapImpl.call_removeNamedItemNS(instance, namespace, localName) catch |err| {
            runtime.CEReactions.end(ce_scope);
            return err;
        };
        // A result the reactions freed (its realm ended) is not returned.
        const result_generation = runtime.SlabAllocator.generationOf(result);
        runtime.CEReactions.end(ce_scope);
        if (runtime.SlabAllocator.generationOf(result) != result_generation) return error.InvalidStateError;
        return result;
    }

    pub fn call_getNamedItemNS(instance: *runtime.Instance, namespace: ?DOMString, localName: DOMString) anyerror!?*runtime.Instance {
        return try NamedNodeMapImpl.call_getNamedItemNS(instance, namespace, localName);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
        return try NamedNodeMapImpl.call_item(instance, index);
    }

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "call_removeNamedItem",
        "call_setNamedItem",
        "call_setNamedItemNS",
        "call_removeNamedItemNS",
    };

    /// Get supported property names for named property enumeration (Reflect.ownKeys, etc.)
    /// Per WebIDL spec §3.9.3, returns names in list order for proper enumeration
    pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
        return NamedNodeMapImpl.getSupportedPropertyNames(instance, allocator);
    }
};
