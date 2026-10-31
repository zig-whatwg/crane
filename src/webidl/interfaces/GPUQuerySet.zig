//! Generated from: webgpu.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPUQuerySetImpl = @import("impls").GPUQuerySet;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const GPUObjectBase = @import("mixins").GPUObjectBase;
const GPUQueryType = @import("enums").GPUQueryType;
const GPUSize32Out = @import("typedefs").GPUSize32Out;
const USVString = @import("typedefs").USVString;

pub const GPUQuerySet = struct {
    pub const Meta = struct {
        pub const name = "GPUQuerySet";
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
            .{ "type", "get_type", null },
            .{ "count", "get_count", null },
            .{ "label", "get_label", "set_label" },
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
            .{ "type", "get_type", null },
            .{ "count", "get_count", null },
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
            type: enums.GPUQueryType = undefined,
            count: typedefs.GPUSize32Out = undefined,
            label: runtime.USVString = undefined,
            _internal: ?*GPUQuerySetImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_count = &get_count,
        .get_label = &get_label,
        .get_type = &get_type,

        .set_label = &set_label,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("GPUQuerySet has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(GPUQuerySetImpl, "init") and @hasDecl(GPUQuerySetImpl, "initOwn")) @compileError("GPUQuerySetImpl defines both init and initOwn");
        if (comptime @hasDecl(GPUQuerySetImpl, "init")) return GPUQuerySetImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(GPUQuerySetImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try GPUQuerySetImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(GPUQuerySetImpl, "init")) return false;
        if (comptime @hasDecl(GPUQuerySetImpl, "construction_args")) {
            inline for (GPUQuerySetImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(GPUQuerySetImpl, "deinit") and @hasDecl(GPUQuerySetImpl, "deinitOwn")) @compileError("GPUQuerySetImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(GPUQuerySetImpl, "deinit")) return GPUQuerySetImpl.deinit(instance);
        if (comptime @hasDecl(GPUQuerySetImpl, "deinitOwn")) GPUQuerySetImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "GPUQuerySet")) {
            if (comptime @hasDecl(impls.GPUQuerySet, "installHooks")) impls.GPUQuerySet.installHooks();
        }
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!GPUQueryType {
        return try GPUQuerySetImpl.get_type(instance);
    }

    pub fn get_count(instance: *runtime.Instance) anyerror!GPUSize32Out {
        return try GPUQuerySetImpl.get_count(instance);
    }

    pub const get_label = mixins.GPUObjectBase.get_label;
    pub const set_label = mixins.GPUObjectBase.set_label;

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try GPUQuerySetImpl.call_destroy(instance);
    }
};
