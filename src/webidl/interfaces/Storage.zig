//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const StorageImpl = @import("impls").Storage;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const Storage = struct {
    pub const Meta = struct {
        pub const name = "Storage";
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
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "key", "call_key", 1 },
            .{ "getItem", "call_getItem", 1 },
            .{ "setItem", "call_setItem", 2 },
            .{ "removeItem", "call_removeItem", 1 },
            .{ "clear", "call_clear", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "key",
            "getItem",
            "setItem",
            "removeItem",
            "clear",
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
            .named_getter = .{ .function = "call_getItem" },
            .named_setter = .{ .function = "call_setItem" },
            .named_deleter = .{ .function = "call_removeItem" },
            .supported_property_name = .{ .function = "isSupportedPropertyName", .implemented = @hasDecl(StorageImpl, "isSupportedPropertyName") },
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            length: u32 = undefined,
            _internal: ?*StorageImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_length = &get_length,

        .call_clear = &call_clear,
        .call_getItem = &call_getItem,
        .call_key = &call_key,
        .call_removeItem = &call_removeItem,
        .call_setItem = &call_setItem,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("Storage has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(StorageImpl, "init") and @hasDecl(StorageImpl, "initOwn")) @compileError("StorageImpl defines both init and initOwn");
        if (comptime @hasDecl(StorageImpl, "init")) return StorageImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(StorageImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try StorageImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(StorageImpl, "init")) return false;
        if (comptime @hasDecl(StorageImpl, "construction_args")) {
            inline for (StorageImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(StorageImpl, "deinit") and @hasDecl(StorageImpl, "deinitOwn")) @compileError("StorageImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(StorageImpl, "deinit")) return StorageImpl.deinit(instance);
        if (comptime @hasDecl(StorageImpl, "deinitOwn")) StorageImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Storage")) {
            if (comptime @hasDecl(impls.Storage, "installHooks")) impls.Storage.installHooks();
        }
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try StorageImpl.get_length(instance);
    }

    pub fn call_getItem(instance: *runtime.Instance, key: runtime.DOMString) anyerror!?runtime.DOMString {
        return try StorageImpl.call_getItem(instance, key);
    }

    pub fn call_removeItem(instance: *runtime.Instance, key: runtime.DOMString) anyerror!void {
        return try StorageImpl.call_removeItem(instance, key);
    }

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try StorageImpl.call_clear(instance);
    }

    pub fn call_setItem(instance: *runtime.Instance, key: runtime.DOMString, value: runtime.DOMString) anyerror!void {
        return try StorageImpl.call_setItem(instance, key, value);
    }

    pub fn call_key(instance: *runtime.Instance, index: u32) anyerror!?runtime.DOMString {
        return try StorageImpl.call_key(instance, index);
    }

    /// Get supported property names for named property enumeration (Reflect.ownKeys, etc.)
    /// Per WebIDL spec §3.9.3, returns names in list order for proper enumeration
    pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
        return StorageImpl.getSupportedPropertyNames(instance, allocator);
    }

    /// Whether `name` is one of the supported property names (WebIDL 3.9.7
    /// step 1, asked for one name), answered without building the list. Gated:
    /// error.NotImplemented until the impl declares it, and
    /// Meta.special_operations.supported_property_name says whether it does -
    /// without it the binding searches getSupportedPropertyNames' list.
    pub fn isSupportedPropertyName(instance: *runtime.Instance, name: runtime.DOMString) anyerror!bool {
        if (comptime @hasDecl(StorageImpl, "isSupportedPropertyName")) {
            return try StorageImpl.isSupportedPropertyName(instance, name);
        } else {
            return error.NotImplemented;
        }
    }
};
