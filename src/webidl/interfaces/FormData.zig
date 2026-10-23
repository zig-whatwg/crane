//! Generated from: xhr.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FormDataImpl = @import("impls").FormData;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const USVString = @import("typedefs").USVString;
const Blob = @import("interfaces").Blob;
const HTMLElement = @import("interfaces").HTMLElement;
const HTMLFormElement = @import("interfaces").HTMLFormElement;
const FormDataEntryValue = @import("typedefs").FormDataEntryValue;

pub const FormData = struct {
    pub const Meta = struct {
        pub const name = "FormData";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "append", "call_append", 2 },
            .{ "delete", "call_delete", 1 },
            .{ "get", "call_get", 1 },
            .{ "getAll", "call_getAll", 1 },
            .{ "has", "call_has", 1 },
            .{ "set", "call_set", 2 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "append",
            "delete",
            "get",
            "getAll",
            "has",
            "set",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;

        /// Iterable declaration (for Symbol.iterator support)
        pub const iterable = .{
            .value_type = "FormDataEntryValue",
            .key_type = "runtime.USVString",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*FormDataImpl.InternalState = null,
        },
    );

    const delegates = .{
        .call_append = &call_append,
        .call_delete = &call_delete,
        .call_get = &call_get,
        .call_getAll = &call_getAll,
        .call_has = &call_has,
        .call_set = &call_set,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("FormData has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(FormDataImpl, "init") and @hasDecl(FormDataImpl, "initOwn")) @compileError("FormDataImpl defines both init and initOwn");
        if (comptime @hasDecl(FormDataImpl, "init")) return FormDataImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(FormDataImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try FormDataImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(FormDataImpl, "init")) return false;
        if (comptime @hasDecl(FormDataImpl, "construction_args")) {
            inline for (FormDataImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(FormDataImpl, "deinit") and @hasDecl(FormDataImpl, "deinitOwn")) @compileError("FormDataImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(FormDataImpl, "deinit")) return FormDataImpl.deinit(instance);
        if (comptime @hasDecl(FormDataImpl, "deinitOwn")) FormDataImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "FormData")) {
            if (comptime @hasDecl(impls.FormData, "installHooks")) impls.FormData.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 0;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, form: webidl.Opt(*runtime.Instance), submitter: webidl.Opt(?*runtime.Instance)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try FormDataImpl.call_constructor(ctx, form, submitter);
    }

    /// WebIDL interface types: the interface each interface-typed constructor
    /// argument converts to (ConstructorArgs variant - "" for a sole
    /// constructor -, argument index, interface).
    pub const constructor_interface_arguments = .{
        .{ "", 0, "HTMLFormElement" },
        .{ "", 1, "HTMLElement" },
    };

    pub fn call_delete(instance: *runtime.Instance, name: runtime.USVString) anyerror!void {
        return try FormDataImpl.call_delete(instance, name);
    }

    pub fn call_get(instance: *runtime.Instance, name: runtime.USVString) anyerror!?FormDataEntryValue {
        return try FormDataImpl.call_get(instance, name);
    }

    pub fn call_getAll(instance: *runtime.Instance, name: runtime.USVString) anyerror!runtime.JSValue {
        return try FormDataImpl.call_getAll(instance, name);
    }

    pub fn call_has(instance: *runtime.Instance, name: runtime.USVString) anyerror!bool {
        return try FormDataImpl.call_has(instance, name);
    }

    pub fn call_set(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyerror!void {
        return try FormDataImpl.call_set(instance, name, value);
    }

    pub fn call_append(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyerror!void {
        return try FormDataImpl.call_append(instance, name, value);
    }

    pub fn call_set__1(instance: *runtime.Instance, name: runtime.USVString, blobValue: *runtime.Instance, filename: webidl.Opt(runtime.USVString)) anyerror!void {
        if (comptime @hasDecl(FormDataImpl, "call_set__1")) {
            return try FormDataImpl.call_set__1(instance, name, blobValue, filename);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_append__1(instance: *runtime.Instance, name: runtime.USVString, blobValue: *runtime.Instance, filename: webidl.Opt(runtime.USVString)) anyerror!void {
        if (comptime @hasDecl(FormDataImpl, "call_append__1")) {
            return try FormDataImpl.call_append__1(instance, name, blobValue, filename);
        } else {
            return error.NotImplemented;
        }
    }

    /// WebIDL overload sets: every overload of each overloaded operation,
    /// in IDL order, for the overload resolution algorithm
    /// (webidl.overload_resolution). The binding is installed for the first
    /// overload and forwards to the one the arguments select.
    pub const overloads = .{
        .{ "set", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_set", .args = &.{ .{ .kinds = &.{.string} }, .{ .kinds = &.{.string} } } },
            .{ .function = "call_set__1", .implemented = @hasDecl(FormDataImpl, "call_set__1"), .args = &.{ .{ .kinds = &.{.string} }, .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "Blob")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").Blob.State) } else .other)} }, .{ .kinds = &.{.string}, .optionality = .optional } } },
        } },
        .{ "append", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_append", .args = &.{ .{ .kinds = &.{.string} }, .{ .kinds = &.{.string} } } },
            .{ .function = "call_append__1", .implemented = @hasDecl(FormDataImpl, "call_append__1"), .args = &.{ .{ .kinds = &.{.string} }, .{ .kinds = &.{(if (@hasDecl(@import("interfaces"), "Blob")) webidl.overload_resolution.Kind{ .interface = runtime.typeId(@import("interfaces").Blob.State) } else .other)} }, .{ .kinds = &.{.string}, .optionality = .optional } } },
        } },
    };

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "call_set__1", 1, "Blob" },
        .{ "call_append__1", 1, "Blob" },
    };

    /// Get entries for pair iterable support (used by V8 for iteration)
    /// Returns slice of entries with .name and .value fields
    pub fn getEntriesForIterable(instance: *runtime.Instance) ?[]const FormDataImpl.IterableEntry {
        return FormDataImpl.getEntriesInternal(instance);
    }
};
