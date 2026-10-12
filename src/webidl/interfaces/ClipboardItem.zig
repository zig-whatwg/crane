//! Generated from: clipboard-apis.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ClipboardItemImpl = @import("impls").ClipboardItem;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ClipboardItemOptions = @import("dictionaries").ClipboardItemOptions;
const PresentationStyle = @import("enums").PresentationStyle;
const Blob = @import("interfaces").Blob;
const DOMString = @import("typedefs").DOMString;

pub const ClipboardItem = struct {
    pub const Meta = struct {
        pub const name = "ClipboardItem";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "presentationStyle", "get_presentationStyle", null },
            .{ "types", "get_types", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getType", "call_getType", 1 },
        };

        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "supports", "call_static_supports", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getType",
            "supports",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "presentationStyle", "get_presentationStyle", null },
            .{ "types", "get_types", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            presentationStyle: enums.PresentationStyle = undefined,
            types: runtime.JSValue = undefined,
            _internal: ?*ClipboardItemImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_presentationStyle = &get_presentationStyle,
        .get_types = &get_types,

        .call_getType = &call_getType,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("ClipboardItem has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(ClipboardItemImpl, "init") and @hasDecl(ClipboardItemImpl, "initOwn")) @compileError("ClipboardItemImpl defines both init and initOwn");
        if (comptime @hasDecl(ClipboardItemImpl, "init")) return ClipboardItemImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(ClipboardItemImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try ClipboardItemImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ClipboardItemImpl, "init")) return false;
        if (comptime @hasDecl(ClipboardItemImpl, "construction_args")) {
            inline for (ClipboardItemImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(ClipboardItemImpl, "deinit") and @hasDecl(ClipboardItemImpl, "deinitOwn")) @compileError("ClipboardItemImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(ClipboardItemImpl, "deinit")) return ClipboardItemImpl.deinit(instance);
        if (comptime @hasDecl(ClipboardItemImpl, "deinitOwn")) ClipboardItemImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "ClipboardItem")) {
            if (comptime @hasDecl(impls.ClipboardItem, "installHooks")) impls.ClipboardItem.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, items: runtime.JSValue, options: webidl.Opt(ClipboardItemOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try ClipboardItemImpl.call_constructor(ctx, items, options);
    }

    pub fn get_presentationStyle(instance: *runtime.Instance) anyerror!PresentationStyle {
        return try ClipboardItemImpl.get_presentationStyle(instance);
    }

    pub fn get_types(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ClipboardItemImpl.get_types(instance);
    }

    pub fn call_getType(instance: *runtime.Instance, @"type": DOMString) anyerror!runtime.JSValue {
        return try ClipboardItemImpl.call_getType(instance, @"type");
    }

    pub fn call_static_supports(instance: *runtime.Instance, @"type": DOMString) anyerror!bool {
        return try ClipboardItemImpl.call_static_supports(instance, @"type");
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_getType",
    };
};
