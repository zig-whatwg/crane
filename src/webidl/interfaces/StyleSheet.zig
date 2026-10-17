//! Generated from: cssom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const StyleSheetImpl = @import("impls").StyleSheet;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Element = @import("interfaces").Element;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const CSSOMString = @import("typedefs").CSSOMString;
const ProcessingInstruction = @import("interfaces").ProcessingInstruction;
const USVString = @import("typedefs").USVString;
const DOMString = @import("typedefs").DOMString;
const MediaList = @import("interfaces").MediaList;

pub const StyleSheet = struct {
    pub const Meta = struct {
        pub const name = "StyleSheet";
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
            .{ "type", "get_type", null },
            .{ "href", "get_href", null },
            .{ "ownerNode", "get_ownerNode", null },
            .{ "parentStyleSheet", "get_parentStyleSheet", null },
            .{ "title", "get_title", null },
            .{ "media", "get_media", "set_media" },
            .{ "disabled", "get_disabled", "set_disabled" },
        };

        /// [PutForwards] attributes: setting the attribute forwards to a property on the value
        /// Format: { "attrName", "forwardedProperty" }
        pub const put_forwards_attributes = .{
            .{ "media", "mediaText" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{};

        /// Methods defined/overridden by this interface
        pub const own_methods = .{};

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "type", "get_type", null },
            .{ "href", "get_href", null },
            .{ "ownerNode", "get_ownerNode", null },
            .{ "parentStyleSheet", "get_parentStyleSheet", null },
            .{ "title", "get_title", null },
            .{ "media", "get_media", "set_media" },
            .{ "disabled", "get_disabled", "set_disabled" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            type: typedefs.CSSOMString = undefined,
            href: ?runtime.USVString = null,
            ownerNode: ?union(enum) {
                Element: Element,
                ProcessingInstruction: ProcessingInstruction,
            } = null,
            parentStyleSheet: ?*runtime.Instance = null,
            title: ?runtime.DOMString = null,
            media: *runtime.Instance = undefined,
            disabled: bool = undefined,
            cached_media: ?*runtime.Instance = null,
            _internal: ?*StyleSheetImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_disabled = &get_disabled,
        .get_href = &get_href,
        .get_media = &get_media,
        .get_ownerNode = &get_ownerNode,
        .get_parentStyleSheet = &get_parentStyleSheet,
        .get_title = &get_title,
        .get_type = &get_type,

        .set_disabled = &set_disabled,
        .set_media = &set_media,

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
            if (comptime !takesConstructionArg(field.name)) @compileError("StyleSheet has no construction argument '" ++ field.name ++ "'");
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
        if (comptime @hasDecl(StyleSheetImpl, "init") and @hasDecl(StyleSheetImpl, "initOwn")) @compileError("StyleSheetImpl defines both init and initOwn");
        if (comptime @hasDecl(StyleSheetImpl, "init")) return StyleSheetImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try runtime.Instance.init(allocator, StateType, vtable_ptr, ctx);
        if (comptime @hasDecl(StyleSheetImpl, "initOwn")) {
            errdefer {
                runtime.gc.releaseStorage(instance);
            }
            try StyleSheetImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(StyleSheetImpl, "init")) return false;
        if (comptime @hasDecl(StyleSheetImpl, "construction_args")) {
            inline for (StyleSheetImpl.construction_args) |arg| {
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
        if (comptime @hasDecl(StyleSheetImpl, "deinit") and @hasDecl(StyleSheetImpl, "deinitOwn")) @compileError("StyleSheetImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.end(State, instance);
        if (comptime @hasDecl(StyleSheetImpl, "deinit")) return StyleSheetImpl.deinit(instance);
        if (comptime @hasDecl(StyleSheetImpl, "deinitOwn")) StyleSheetImpl.deinitOwn(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "StyleSheet")) {
            if (comptime @hasDecl(impls.StyleSheet, "installHooks")) impls.StyleSheet.installHooks();
        }
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!CSSOMString {
        return try StyleSheetImpl.get_type(instance);
    }

    pub fn get_href(instance: *runtime.Instance) anyerror!?runtime.USVString {
        return try StyleSheetImpl.get_href(instance);
    }

    pub fn get_ownerNode(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try StyleSheetImpl.get_ownerNode(instance);
    }

    pub fn get_parentStyleSheet(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try StyleSheetImpl.get_parentStyleSheet(instance);
    }

    pub fn get_title(instance: *runtime.Instance) anyerror!?runtime.DOMString {
        return try StyleSheetImpl.get_title(instance);
    }

    /// Extended attributes: [SameObject], [PutForwards=mediaText]
    pub fn get_media(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_media) |cached| {
            return cached;
        }
        const value = try StyleSheetImpl.get_media(instance);
        state.own.cached_media = value;
        @import("dom").same_object_cache.made(instance, value, "media");
        return value;
    }

    /// Extended attributes: [SameObject], [PutForwards=mediaText]
    pub fn set_media(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [PutForwards] - Get target object and set the forwarded property
        // Per WebIDL spec: setting 'media' forwards to 'mediaText' on the attribute's value
        const target = try get_media(instance);

        // Use JavaScript [[Set]] semantics to set the forwarded property
        // This respects prototype chain and user-defined setters
        try runtime.setPropertyOnInstance(target, "mediaText", value);
    }

    pub fn get_disabled(instance: *runtime.Instance) anyerror!bool {
        return try StyleSheetImpl.get_disabled(instance);
    }

    pub fn set_disabled(instance: *runtime.Instance, value: bool) anyerror!void {
        try StyleSheetImpl.set_disabled(instance, value);
    }
};
