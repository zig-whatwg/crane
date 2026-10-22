//! Generated from: css-typed-om.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSUnparsedValueImpl = @import("impls").CSSUnparsedValue;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSStyleValue = @import("interfaces").CSSStyleValue;
const CSSUnparsedSegment = @import("typedefs").CSSUnparsedSegment;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;

pub const CSSUnparsedValue = struct {
    pub const Meta = struct {
        pub const name = "CSSUnparsedValue";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = CSSStyleValue.State;
        pub const ParentInterface = CSSStyleValue;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker", "PaintWorklet", "LayoutWorklet" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
            .PaintWorklet = true,
            .LayoutWorklet = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "length", "get_length", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "parse",
            "parseAll",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "length", "get_length", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;

        /// WebIDL 2.5.6 special operations, own or inherited (the derived-most):
        /// the function that runs each. The binding installs indexed and named
        /// property handlers from this table (webidl.SpecialOperations).
        pub const special_operations: webidl.SpecialOperations = .{
            .indexed_getter = .{ .function = "call_getter", .implemented = @hasDecl(CSSUnparsedValueImpl, "call_getter") },
            .indexed_setter = .{ .function = "call_setter", .implemented = @hasDecl(CSSUnparsedValueImpl, "call_setter") },
        };

        /// Iterable declaration (for Symbol.iterator support)
        pub const iterable = .{
            .value_type = "CSSUnparsedSegment",
            .key_type = null,
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            length: u32 = undefined,
            _internal: ?*CSSUnparsedValueImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_length = &get_length,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("CSSUnparsedValue has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(CSSUnparsedValueImpl, "init") and @hasDecl(CSSUnparsedValueImpl, "initOwn")) @compileError("CSSUnparsedValueImpl defines both init and initOwn");
        if (comptime @hasDecl(CSSUnparsedValueImpl, "init")) return CSSUnparsedValueImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(CSSUnparsedValueImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try CSSUnparsedValueImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CSSUnparsedValueImpl, "init")) return false;
        if (comptime @hasDecl(CSSUnparsedValueImpl, "construction_args")) {
            inline for (CSSUnparsedValueImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return Meta.ParentInterface.takesConstructionArg(name);
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(CSSUnparsedValueImpl, "deinit") and @hasDecl(CSSUnparsedValueImpl, "deinitOwn")) @compileError("CSSUnparsedValueImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(CSSUnparsedValueImpl, "deinit")) return CSSUnparsedValueImpl.deinit(instance);
        if (comptime @hasDecl(CSSUnparsedValueImpl, "deinitOwn")) CSSUnparsedValueImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CSSUnparsedValue")) {
            if (comptime @hasDecl(impls.CSSUnparsedValue, "installHooks")) impls.CSSUnparsedValue.installHooks();
        }
    }

    pub const constructor_required_arguments: usize = 1;

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, members: runtime.JSValue) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSUnparsedValueImpl.call_constructor(ctx, members);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try CSSUnparsedValueImpl.get_length(instance);
    }

    pub fn call_getter(instance: *runtime.Instance, index: u32) anyerror!CSSUnparsedSegment {
        if (comptime @hasDecl(CSSUnparsedValueImpl, "call_getter")) {
            return try CSSUnparsedValueImpl.call_getter(instance, index);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_setter(instance: *runtime.Instance, index: u32, val: CSSUnparsedSegment) anyerror!void {
        if (comptime @hasDecl(CSSUnparsedValueImpl, "call_setter")) {
            return try CSSUnparsedValueImpl.call_setter(instance, index, val);
        } else {
            return error.NotImplemented;
        }
    }
};
