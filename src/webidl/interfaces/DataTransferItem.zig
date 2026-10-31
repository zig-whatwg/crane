//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DataTransferItemImpl = @import("impls").DataTransferItem;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const FileSystemEntry = @import("interfaces").FileSystemEntry;
const FunctionStringCallback = @import("callbacks").FunctionStringCallback;
const File = @import("interfaces").File;
const DOMString = @import("typedefs").DOMString;
const FileSystemHandle = @import("interfaces").FileSystemHandle;

pub const DataTransferItem = struct {
    pub const Meta = struct {
        pub const name = "DataTransferItem";
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
            .{ "kind", "get_kind", null },
            .{ "type", "get_type", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getAsString", "call_getAsString", 1 },
            .{ "getAsFile", "call_getAsFile", 0 },
            .{ "webkitGetAsEntry", "call_webkitGetAsEntry", 0 },
            .{ "getAsFileSystemHandle", "call_getAsFileSystemHandle", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getAsString",
            "getAsFile",
            "webkitGetAsEntry",
            "getAsFileSystemHandle",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "kind", "get_kind", null },
            .{ "type", "get_type", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            kind: runtime.DOMString = undefined,
            type: runtime.DOMString = undefined,
            _internal: ?*DataTransferItemImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_kind = &get_kind,
        .get_type = &get_type,

        .call_getAsFile = &call_getAsFile,
        .call_getAsFileSystemHandle = &call_getAsFileSystemHandle,
        .call_getAsString = &call_getAsString,
        .call_webkitGetAsEntry = &call_webkitGetAsEntry,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("DataTransferItem has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(DataTransferItemImpl, "init") and @hasDecl(DataTransferItemImpl, "initOwn")) @compileError("DataTransferItemImpl defines both init and initOwn");
        if (comptime @hasDecl(DataTransferItemImpl, "init")) return DataTransferItemImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(DataTransferItemImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try DataTransferItemImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(DataTransferItemImpl, "init")) return false;
        if (comptime @hasDecl(DataTransferItemImpl, "construction_args")) {
            inline for (DataTransferItemImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(DataTransferItemImpl, "deinit") and @hasDecl(DataTransferItemImpl, "deinitOwn")) @compileError("DataTransferItemImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(DataTransferItemImpl, "deinit")) return DataTransferItemImpl.deinit(instance);
        if (comptime @hasDecl(DataTransferItemImpl, "deinitOwn")) DataTransferItemImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "DataTransferItem")) {
            if (comptime @hasDecl(impls.DataTransferItem, "installHooks")) impls.DataTransferItem.installHooks();
        }
    }

    pub fn get_kind(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try DataTransferItemImpl.get_kind(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try DataTransferItemImpl.get_type(instance);
    }

    pub fn call_getAsString(instance: *runtime.Instance, callback: ?FunctionStringCallback) anyerror!void {
        return try DataTransferItemImpl.call_getAsString(instance, callback);
    }

    pub fn call_webkitGetAsEntry(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DataTransferItemImpl.call_webkitGetAsEntry(instance);
    }

    pub fn call_getAsFile(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try DataTransferItemImpl.call_getAsFile(instance);
    }

    pub fn call_getAsFileSystemHandle(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try DataTransferItemImpl.call_getAsFileSystemHandle(instance);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_getAsFileSystemHandle",
    };
};
