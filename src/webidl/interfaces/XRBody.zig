//! Generated from: body-tracking.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XRBodyImpl = @import("impls").XRBody;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const XRBodyJoint = @import("enums").XRBodyJoint;
const XRBodySpace = @import("interfaces").XRBodySpace;

pub const XRBody = struct {
    pub const Meta = struct {
        pub const name = "XRBody";
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
            .{ "size", "get_size", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "get", "call_get", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "get",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "size", "get_size", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// Iterable declaration (for Symbol.iterator support)
        pub const iterable = .{
            .value_type = "XRBodySpace",
            .key_type = "XRBodyJoint",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            size: u32 = undefined,
            _internal: ?*XRBodyImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_size = &get_size,

        .call_get = &call_get,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("XRBody has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(XRBodyImpl, "init") and @hasDecl(XRBodyImpl, "initOwn")) @compileError("XRBodyImpl defines both init and initOwn");
        if (comptime @hasDecl(XRBodyImpl, "init")) return XRBodyImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(XRBodyImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try XRBodyImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(XRBodyImpl, "init")) return false;
        if (comptime @hasDecl(XRBodyImpl, "construction_args")) {
            inline for (XRBodyImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(XRBodyImpl, "deinit") and @hasDecl(XRBodyImpl, "deinitOwn")) @compileError("XRBodyImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(XRBodyImpl, "deinit")) return XRBodyImpl.deinit(instance);
        if (comptime @hasDecl(XRBodyImpl, "deinitOwn")) XRBodyImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "XRBody")) {
            if (comptime @hasDecl(impls.XRBody, "installHooks")) impls.XRBody.installHooks();
        }
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
        return try XRBodyImpl.get_size(instance);
    }

    pub fn call_get(instance: *runtime.Instance, key: XRBodyJoint) anyerror!*runtime.Instance {
        return try XRBodyImpl.call_get(instance, key);
    }

    /// Get entries for pair iterable support (used by V8 for iteration)
    /// Returns slice of entries with .name and .value fields
    pub fn getEntriesForIterable(instance: *runtime.Instance) ?[]const XRBodyImpl.IterableEntry {
        return XRBodyImpl.getEntriesInternal(instance);
    }
};
