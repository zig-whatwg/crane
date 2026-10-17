//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLAllCollectionImpl = @import("impls").HTMLAllCollection;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Element = @import("interfaces").Element;
const HTMLCollection = @import("interfaces").HTMLCollection;
const DOMString = @import("typedefs").DOMString;

pub const HTMLAllCollection = struct {
    pub const Meta = struct {
        pub const name = "HTMLAllCollection";
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
            .{ "namedItem", "call_namedItem", 1 },
            .{ "item", "call_item", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "namedItem",
            "item",
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
            .indexed_getter = .{ .function = "call_getter", .implemented = @hasDecl(HTMLAllCollectionImpl, "call_getter") },
            .named_getter = .{ .function = "call_namedItem" },
            .supported_property_name = .{ .function = "isSupportedPropertyName", .implemented = @hasDecl(HTMLAllCollectionImpl, "isSupportedPropertyName") },
            .legacy_unenumerable_named_properties = true,
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            length: u32 = undefined,
            _internal: ?*HTMLAllCollectionImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_length = &get_length,

        .call_item = &call_item,
        .call_namedItem = &call_namedItem,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("HTMLAllCollection has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(HTMLAllCollectionImpl, "init") and @hasDecl(HTMLAllCollectionImpl, "initOwn")) @compileError("HTMLAllCollectionImpl defines both init and initOwn");
        if (comptime @hasDecl(HTMLAllCollectionImpl, "init")) return HTMLAllCollectionImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(HTMLAllCollectionImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try HTMLAllCollectionImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(HTMLAllCollectionImpl, "init")) return false;
        if (comptime @hasDecl(HTMLAllCollectionImpl, "construction_args")) {
            inline for (HTMLAllCollectionImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(HTMLAllCollectionImpl, "deinit") and @hasDecl(HTMLAllCollectionImpl, "deinitOwn")) @compileError("HTMLAllCollectionImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(HTMLAllCollectionImpl, "deinit")) return HTMLAllCollectionImpl.deinit(instance);
        if (comptime @hasDecl(HTMLAllCollectionImpl, "deinitOwn")) HTMLAllCollectionImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "HTMLAllCollection")) {
            if (comptime @hasDecl(impls.HTMLAllCollection, "installHooks")) impls.HTMLAllCollection.installHooks();
        }
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLAllCollectionImpl.get_length(instance);
    }

    pub fn call_getter(instance: *runtime.Instance, index: u32) anyerror!*runtime.Instance {
        if (comptime @hasDecl(HTMLAllCollectionImpl, "call_getter")) {
            return try HTMLAllCollectionImpl.call_getter(instance, index);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_namedItem(instance: *runtime.Instance, name: runtime.DOMString) anyerror!?runtime.JSValue {
        return try HTMLAllCollectionImpl.call_namedItem(instance, name);
    }

    pub fn call_item(instance: *runtime.Instance, nameOrIndex: webidl.Opt(runtime.DOMString)) anyerror!?runtime.JSValue {
        return try HTMLAllCollectionImpl.call_item(instance, nameOrIndex);
    }

    /// Get supported property names for named property enumeration (Reflect.ownKeys, etc.)
    /// Per WebIDL spec §3.9.3, returns names in list order for proper enumeration
    pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
        return HTMLAllCollectionImpl.getSupportedPropertyNames(instance, allocator);
    }

    /// Whether `name` is one of the supported property names (WebIDL 3.9.7
    /// step 1, asked for one name), answered without building the list. Gated:
    /// error.NotImplemented until the impl declares it, and
    /// Meta.special_operations.supported_property_name says whether it does -
    /// without it the binding searches getSupportedPropertyNames' list.
    pub fn isSupportedPropertyName(instance: *runtime.Instance, name: runtime.DOMString) anyerror!bool {
        if (comptime @hasDecl(HTMLAllCollectionImpl, "isSupportedPropertyName")) {
            return try HTMLAllCollectionImpl.isSupportedPropertyName(instance, name);
        } else {
            return error.NotImplemented;
        }
    }
};
