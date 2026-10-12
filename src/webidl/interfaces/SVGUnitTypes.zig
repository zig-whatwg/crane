//! Generated from: SVG.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGUnitTypesImpl = @import("impls").SVGUnitTypes;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const SVGUnitTypes = struct {
    pub const Meta = struct {
        pub const name = "SVGUnitTypes";
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
        pub const properties = .{};

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "SVG_UNIT_TYPE_UNKNOWN", "get_SVG_UNIT_TYPE_UNKNOWN" },
            .{ "SVG_UNIT_TYPE_USERSPACEONUSE", "get_SVG_UNIT_TYPE_USERSPACEONUSE" },
            .{ "SVG_UNIT_TYPE_OBJECTBOUNDINGBOX", "get_SVG_UNIT_TYPE_OBJECTBOUNDINGBOX" },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{};

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*SVGUnitTypesImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const unsigned short SVG_UNIT_TYPE_UNKNOWN = 0;
    pub fn get_SVG_UNIT_TYPE_UNKNOWN() u16 {
        return 0;
    }

    /// WebIDL constant: const unsigned short SVG_UNIT_TYPE_USERSPACEONUSE = 1;
    pub fn get_SVG_UNIT_TYPE_USERSPACEONUSE() u16 {
        return 1;
    }

    /// WebIDL constant: const unsigned short SVG_UNIT_TYPE_OBJECTBOUNDINGBOX = 2;
    pub fn get_SVG_UNIT_TYPE_OBJECTBOUNDINGBOX() u16 {
        return 2;
    }

    const delegates = .{
        .get_SVG_UNIT_TYPE_OBJECTBOUNDINGBOX = &get_SVG_UNIT_TYPE_OBJECTBOUNDINGBOX,
        .get_SVG_UNIT_TYPE_UNKNOWN = &get_SVG_UNIT_TYPE_UNKNOWN,
        .get_SVG_UNIT_TYPE_USERSPACEONUSE = &get_SVG_UNIT_TYPE_USERSPACEONUSE,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("SVGUnitTypes has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(SVGUnitTypesImpl, "init") and @hasDecl(SVGUnitTypesImpl, "initOwn")) @compileError("SVGUnitTypesImpl defines both init and initOwn");
        if (comptime @hasDecl(SVGUnitTypesImpl, "init")) return SVGUnitTypesImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(SVGUnitTypesImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try SVGUnitTypesImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(SVGUnitTypesImpl, "init")) return false;
        if (comptime @hasDecl(SVGUnitTypesImpl, "construction_args")) {
            inline for (SVGUnitTypesImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(SVGUnitTypesImpl, "deinit") and @hasDecl(SVGUnitTypesImpl, "deinitOwn")) @compileError("SVGUnitTypesImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(SVGUnitTypesImpl, "deinit")) return SVGUnitTypesImpl.deinit(instance);
        if (comptime @hasDecl(SVGUnitTypesImpl, "deinitOwn")) SVGUnitTypesImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "SVGUnitTypes")) {
            if (comptime @hasDecl(impls.SVGUnitTypes, "installHooks")) impls.SVGUnitTypes.installHooks();
        }
    }
};
