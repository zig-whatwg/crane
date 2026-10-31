//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DataTransferItemListImpl = @import("impls").DataTransferItemList;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DataTransferItem = @import("interfaces").DataTransferItem;
const File = @import("interfaces").File;
const DOMString = @import("typedefs").DOMString;

pub const DataTransferItemList = struct {
    pub const Meta = struct {
        pub const name = "DataTransferItemList";
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
            .{ "add", "call_add", 1 },
            .{ "remove", "call_remove", 1 },
            .{ "clear", "call_clear", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "add",
            "remove",
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
            .indexed_getter = .{ .function = "call_getter", .implemented = @hasDecl(DataTransferItemListImpl, "call_getter") },
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            length: u32 = undefined,
            _internal: ?*DataTransferItemListImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_length = &get_length,

        .call_add = &call_add,
        .call_clear = &call_clear,
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
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("DataTransferItemList has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(DataTransferItemListImpl, "init") and @hasDecl(DataTransferItemListImpl, "initOwn")) @compileError("DataTransferItemListImpl defines both init and initOwn");
        if (comptime @hasDecl(DataTransferItemListImpl, "init")) return DataTransferItemListImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(DataTransferItemListImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try DataTransferItemListImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(DataTransferItemListImpl, "init")) return false;
        if (comptime @hasDecl(DataTransferItemListImpl, "construction_args")) {
            inline for (DataTransferItemListImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(DataTransferItemListImpl, "deinit") and @hasDecl(DataTransferItemListImpl, "deinitOwn")) @compileError("DataTransferItemListImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(DataTransferItemListImpl, "deinit")) return DataTransferItemListImpl.deinit(instance);
        if (comptime @hasDecl(DataTransferItemListImpl, "deinitOwn")) DataTransferItemListImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "DataTransferItemList")) {
            if (comptime @hasDecl(impls.DataTransferItemList, "installHooks")) impls.DataTransferItemList.installHooks();
        }
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try DataTransferItemListImpl.get_length(instance);
    }

    pub fn call_getter(instance: *runtime.Instance, index: u32) anyerror!*runtime.Instance {
        if (comptime @hasDecl(DataTransferItemListImpl, "call_getter")) {
            return try DataTransferItemListImpl.call_getter(instance, index);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try DataTransferItemListImpl.call_clear(instance);
    }

    pub fn call_remove(instance: *runtime.Instance, index: u32) anyerror!void {
        return try DataTransferItemListImpl.call_remove(instance, index);
    }

    pub fn call_add(instance: *runtime.Instance, data: runtime.DOMString, @"type": runtime.DOMString) anyerror!?*runtime.Instance {
        return try DataTransferItemListImpl.call_add(instance, data, @"type");
    }

    pub fn call_add__1(instance: *runtime.Instance, data: *runtime.Instance) anyerror!?*runtime.Instance {
        if (comptime @hasDecl(DataTransferItemListImpl, "call_add__1")) {
            return try DataTransferItemListImpl.call_add__1(instance, data);
        } else {
            return error.NotImplemented;
        }
    }

    /// WebIDL overload sets: every overload of each overloaded operation,
    /// in IDL order, for the overload resolution algorithm
    /// (webidl.overload_resolution). The binding is installed for the first
    /// overload and forwards to the one the arguments select.
    pub const overloads = .{
        .{ "add", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_add", .args = &.{ .{ .kinds = &.{.string} }, .{ .kinds = &.{.string} } } },
            .{ .function = "call_add__1", .implemented = @hasDecl(DataTransferItemListImpl, "call_add__1"), .args = &.{.{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "File")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").File.State) } else .other)} }} },
        } },
    };

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_add__1", 0, "File" },
    };
};
