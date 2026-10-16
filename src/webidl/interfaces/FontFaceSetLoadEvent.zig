//! Generated from: css-font-loading.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FontFaceSetLoadEventImpl = @import("impls").FontFaceSetLoadEvent;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Event = @import("interfaces").Event;
const CSSOMString = @import("typedefs").CSSOMString;
const EventTarget = @import("interfaces").EventTarget;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const FontFaceSetLoadEventInit = @import("dictionaries").FontFaceSetLoadEventInit;
const FontFace = @import("interfaces").FontFace;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const FontFaceSetLoadEvent = struct {
    pub const Meta = struct {
        pub const name = "FontFaceSetLoadEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Event.State;
        pub const ParentInterface = Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "fontfaces", "get_fontfaces", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "fontfaces", "get_fontfaces", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            fontfaces: runtime.JSValue = undefined,
            cached_fontfaces: ?runtime.JSValue = null,
            _internal: ?*FontFaceSetLoadEventImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_fontfaces = &get_fontfaces,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("FontFaceSetLoadEvent has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(FontFaceSetLoadEventImpl, "init") and @hasDecl(FontFaceSetLoadEventImpl, "initOwn")) @compileError("FontFaceSetLoadEventImpl defines both init and initOwn");
        if (comptime @hasDecl(FontFaceSetLoadEventImpl, "init")) return FontFaceSetLoadEventImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(FontFaceSetLoadEventImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try FontFaceSetLoadEventImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(FontFaceSetLoadEventImpl, "init")) return false;
        if (comptime @hasDecl(FontFaceSetLoadEventImpl, "construction_args")) {
            inline for (FontFaceSetLoadEventImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(FontFaceSetLoadEventImpl, "deinit") and @hasDecl(FontFaceSetLoadEventImpl, "deinitOwn")) @compileError("FontFaceSetLoadEventImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(FontFaceSetLoadEventImpl, "deinit")) return FontFaceSetLoadEventImpl.deinit(instance);
        if (comptime @hasDecl(FontFaceSetLoadEventImpl, "deinitOwn")) FontFaceSetLoadEventImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "FontFaceSetLoadEvent")) {
            if (comptime @hasDecl(impls.FontFaceSetLoadEvent, "installHooks")) impls.FontFaceSetLoadEvent.installHooks();
        }
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, @"type": CSSOMString, eventInitDict: webidl.Opt(FontFaceSetLoadEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try FontFaceSetLoadEventImpl.call_constructor(ctx, @"type", eventInitDict);
    }

    /// Extended attributes: [SameObject]
    pub fn get_fontfaces(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try FontFaceSetLoadEventImpl.get_fontfaces(instance);
    }
};
