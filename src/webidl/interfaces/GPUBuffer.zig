//! Generated from: webgpu.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPUBufferImpl = @import("impls").GPUBuffer;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GPUObjectBase = @import("mixins").GPUObjectBase;
const GPUSize64Out = @import("typedefs").GPUSize64Out;
const GPUBufferMapState = @import("enums").GPUBufferMapState;
const GPUSize64 = @import("typedefs").GPUSize64;
const GPUFlagsConstant = @import("typedefs").GPUFlagsConstant;
const GPUMapModeFlags = @import("typedefs").GPUMapModeFlags;
const USVString = @import("typedefs").USVString;

pub const GPUBuffer = struct {
    pub const Meta = struct {
        pub const name = "GPUBuffer";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{
            GPUObjectBase,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "size", "get_size", null },
            .{ "usage", "get_usage", null },
            .{ "mapState", "get_mapState", null },
            .{ "label", "get_label", "set_label" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "mapAsync", "call_mapAsync", 1 },
            .{ "getMappedRange", "call_getMappedRange", 0 },
            .{ "unmap", "call_unmap", 0 },
            .{ "destroy", "call_destroy", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "mapAsync",
            "getMappedRange",
            "unmap",
            "destroy",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "size", "get_size", null },
            .{ "usage", "get_usage", null },
            .{ "mapState", "get_mapState", null },
            .{ "label", "get_label", "set_label" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            size: typedefs.GPUSize64Out = undefined,
            usage: typedefs.GPUFlagsConstant = undefined,
            mapState: enums.GPUBufferMapState = undefined,
            label: runtime.USVString = undefined,
            _internal: ?*GPUBufferImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_label = &get_label,
        .get_mapState = &get_mapState,
        .get_size = &get_size,
        .get_usage = &get_usage,

        .set_label = &set_label,

        .call_destroy = &call_destroy,
        .call_getMappedRange = &call_getMappedRange,
        .call_mapAsync = &call_mapAsync,
        .call_unmap = &call_unmap,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("GPUBuffer has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(GPUBufferImpl, "init") and @hasDecl(GPUBufferImpl, "initOwn")) @compileError("GPUBufferImpl defines both init and initOwn");
        if (comptime @hasDecl(GPUBufferImpl, "init")) return GPUBufferImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(GPUBufferImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try GPUBufferImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(GPUBufferImpl, "init")) return false;
        if (comptime @hasDecl(GPUBufferImpl, "construction_args")) {
            inline for (GPUBufferImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(GPUBufferImpl, "deinit") and @hasDecl(GPUBufferImpl, "deinitOwn")) @compileError("GPUBufferImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(GPUBufferImpl, "deinit")) return GPUBufferImpl.deinit(instance);
        if (comptime @hasDecl(GPUBufferImpl, "deinitOwn")) GPUBufferImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "GPUBuffer")) {
            if (comptime @hasDecl(impls.GPUBuffer, "installHooks")) impls.GPUBuffer.installHooks();
        }
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!GPUSize64Out {
        return try GPUBufferImpl.get_size(instance);
    }

    pub fn get_usage(instance: *runtime.Instance) anyerror!GPUFlagsConstant {
        return try GPUBufferImpl.get_usage(instance);
    }

    pub fn get_mapState(instance: *runtime.Instance) anyerror!GPUBufferMapState {
        return try GPUBufferImpl.get_mapState(instance);
    }

    pub const get_label = mixins.GPUObjectBase.get_label;
    pub const set_label = mixins.GPUObjectBase.set_label;

    pub fn call_unmap(instance: *runtime.Instance) anyerror!void {
        return try GPUBufferImpl.call_unmap(instance);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try GPUBufferImpl.call_destroy(instance);
    }

    pub fn call_mapAsync(instance: *runtime.Instance, mode: GPUMapModeFlags, offset: webidl.Opt(GPUSize64), size: webidl.Opt(GPUSize64)) anyerror!runtime.JSValue {
        return try GPUBufferImpl.call_mapAsync(instance, mode, offset, size);
    }

    pub fn call_getMappedRange(instance: *runtime.Instance, offset: webidl.Opt(GPUSize64), size: webidl.Opt(GPUSize64)) anyerror!runtime.JSValue {
        return try GPUBufferImpl.call_getMappedRange(instance, offset, size);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_mapAsync",
    };
};
