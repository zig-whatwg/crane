//! Generated from: local-font-access.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FontDataImpl = @import("impls").FontData;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Blob = @import("interfaces").Blob;
const USVString = @import("typedefs").USVString;

pub const FontData = struct {
    pub const Meta = struct {
        pub const name = "FontData";
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
            .{ "postscriptName", "get_postscriptName", null },
            .{ "fullName", "get_fullName", null },
            .{ "family", "get_family", null },
            .{ "style", "get_style", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "blob", "call_blob", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "blob",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "postscriptName", "get_postscriptName", null },
            .{ "fullName", "get_fullName", null },
            .{ "family", "get_family", null },
            .{ "style", "get_style", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            postscriptName: runtime.USVString = undefined,
            fullName: runtime.USVString = undefined,
            family: runtime.USVString = undefined,
            style: runtime.USVString = undefined,
            _internal: ?*FontDataImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_family = &get_family,
        .get_fullName = &get_fullName,
        .get_postscriptName = &get_postscriptName,
        .get_style = &get_style,

        .call_blob = &call_blob,

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
            if (comptime !takesConstructionArg(field_name)) @compileError("FontData has no construction argument '" ++ field_name ++ "'");
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
        if (comptime @hasDecl(FontDataImpl, "init") and @hasDecl(FontDataImpl, "initOwn")) @compileError("FontDataImpl defines both init and initOwn");
        if (comptime @hasDecl(FontDataImpl, "init")) return FontDataImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(FontDataImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try FontDataImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(FontDataImpl, "init")) return false;
        if (comptime @hasDecl(FontDataImpl, "construction_args")) {
            inline for (FontDataImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(FontDataImpl, "deinit") and @hasDecl(FontDataImpl, "deinitOwn")) @compileError("FontDataImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(FontDataImpl, "deinit")) return FontDataImpl.deinit(instance);
        if (comptime @hasDecl(FontDataImpl, "deinitOwn")) FontDataImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "FontData")) {
            if (comptime @hasDecl(impls.FontData, "installHooks")) impls.FontData.installHooks();
        }
    }

    pub fn get_postscriptName(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FontDataImpl.get_postscriptName(instance);
    }

    pub fn get_fullName(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FontDataImpl.get_fullName(instance);
    }

    pub fn get_family(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FontDataImpl.get_family(instance);
    }

    pub fn get_style(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FontDataImpl.get_style(instance);
    }

    pub fn call_blob(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try FontDataImpl.call_blob(instance);
    }

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_blob",
    };
};
