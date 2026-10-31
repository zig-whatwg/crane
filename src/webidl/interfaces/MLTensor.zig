//! Generated from: webnn.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MLTensorImpl = @import("impls").MLTensor;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const MLOperandDataType = @import("enums").MLOperandDataType;

pub const MLTensor = struct {
    pub const Meta = struct {
        pub const name = "MLTensor";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "dataType", "get_dataType", null },
            .{ "shape", "get_shape", null },
            .{ "readable", "get_readable", null },
            .{ "writable", "get_writable", null },
            .{ "constant", "get_constant", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "destroy", "call_destroy", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "destroy",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "dataType", "get_dataType", null },
            .{ "shape", "get_shape", null },
            .{ "readable", "get_readable", null },
            .{ "writable", "get_writable", null },
            .{ "constant", "get_constant", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            dataType: enums.MLOperandDataType = undefined,
            shape: runtime.JSValue = undefined,
            readable: bool = undefined,
            writable: bool = undefined,
            constant: bool = undefined,
            _internal: ?*MLTensorImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_constant = &get_constant,
        .get_dataType = &get_dataType,
        .get_readable = &get_readable,
        .get_shape = &get_shape,
        .get_writable = &get_writable,

        .call_destroy = &call_destroy,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("MLTensor has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(MLTensorImpl, "init") and @hasDecl(MLTensorImpl, "initOwn")) @compileError("MLTensorImpl defines both init and initOwn");
        if (comptime @hasDecl(MLTensorImpl, "init")) return MLTensorImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(MLTensorImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try MLTensorImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(MLTensorImpl, "init")) return false;
        if (comptime @hasDecl(MLTensorImpl, "construction_args")) {
            inline for (MLTensorImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(MLTensorImpl, "deinit") and @hasDecl(MLTensorImpl, "deinitOwn")) @compileError("MLTensorImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(MLTensorImpl, "deinit")) return MLTensorImpl.deinit(instance);
        if (comptime @hasDecl(MLTensorImpl, "deinitOwn")) MLTensorImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "MLTensor")) {
            if (comptime @hasDecl(impls.MLTensor, "installHooks")) impls.MLTensor.installHooks();
        }
    }

    pub fn get_dataType(instance: *runtime.Instance) anyerror!MLOperandDataType {
        return try MLTensorImpl.get_dataType(instance);
    }

    pub fn get_shape(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try MLTensorImpl.get_shape(instance);
    }

    pub fn get_readable(instance: *runtime.Instance) anyerror!bool {
        return try MLTensorImpl.get_readable(instance);
    }

    pub fn get_writable(instance: *runtime.Instance) anyerror!bool {
        return try MLTensorImpl.get_writable(instance);
    }

    pub fn get_constant(instance: *runtime.Instance) anyerror!bool {
        return try MLTensorImpl.get_constant(instance);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try MLTensorImpl.call_destroy(instance);
    }
};
