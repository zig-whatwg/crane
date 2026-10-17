//! Generated from: css-parser-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CSSParserDeclarationImpl = @import("impls").CSSParserDeclaration;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSParserRule = @import("interfaces").CSSParserRule;
const CSSParserValue = @import("interfaces").CSSParserValue;
const DOMString = @import("typedefs").DOMString;

pub const CSSParserDeclaration = struct {
    pub const Meta = struct {
        pub const name = "CSSParserDeclaration";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = CSSParserRule.State;
        pub const ParentInterface = CSSParserRule;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", null },
            .{ "body", "get_body", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "toString", "serialize", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "toString",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "name", "get_name", null },
            .{ "body", "get_body", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            name: typedefs.DOMString = undefined,
            body: runtime.JSValue = undefined,
            _internal: ?*CSSParserDeclarationImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_body = &get_body,
        .get_name = &get_name,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("CSSParserDeclaration has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(CSSParserDeclarationImpl, "init") and @hasDecl(CSSParserDeclarationImpl, "initOwn")) @compileError("CSSParserDeclarationImpl defines both init and initOwn");
        if (comptime @hasDecl(CSSParserDeclarationImpl, "init")) return CSSParserDeclarationImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(CSSParserDeclarationImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try CSSParserDeclarationImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(CSSParserDeclarationImpl, "init")) return false;
        if (comptime @hasDecl(CSSParserDeclarationImpl, "construction_args")) {
            inline for (CSSParserDeclarationImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(CSSParserDeclarationImpl, "deinit") and @hasDecl(CSSParserDeclarationImpl, "deinitOwn")) @compileError("CSSParserDeclarationImpl defines both deinit and deinitOwn");
        if (comptime @hasDecl(CSSParserDeclarationImpl, "deinit")) return CSSParserDeclarationImpl.deinit(instance);
        if (comptime @hasDecl(CSSParserDeclarationImpl, "deinitOwn")) CSSParserDeclarationImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "CSSParserDeclaration")) {
            if (comptime @hasDecl(impls.CSSParserDeclaration, "installHooks")) impls.CSSParserDeclaration.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, name: DOMString, body: webidl.Opt(runtime.JSValue)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try CSSParserDeclarationImpl.call_constructor(ctx, name, body);
    }

    /// WebIDL interface types: the interface each interface-typed constructor
    /// argument converts to (ConstructorArgs variant - "" for a sole
    /// constructor -, argument index, interface).
    pub const constructor_interface_arguments = .{
        .{ "", 1, "CSSParserRule" },
    };

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try CSSParserDeclarationImpl.get_name(instance);
    }

    pub fn get_body(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try CSSParserDeclarationImpl.get_body(instance);
    }

    pub fn call_stringifier(instance: *runtime.Instance) anyerror!DOMString {
        return try CSSParserDeclarationImpl.call_stringifier(instance);
    }

    /// Stringifier delegate - toString() implementation
    /// Per WebIDL spec: https://webidl.spec.whatwg.org/#es-stringifier
    pub fn serialize(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try CSSParserDeclarationImpl.serialize(instance);
    }
};
