//! HTML 8.9.1.6 "PDF viewing support": PluginArray, navigator.plugins - its
//! relevant global object's "PDF viewer plugin objects".
//!
//! A Window has one Navigator, whose plugins attribute is [SameObject]: one
//! PluginArray per Window. So the Window's PDF viewer plugin objects - five
//! Plugin objects when the user agent's PDF viewer supported is true, none
//! otherwise (html_core.navigator.pdf_viewer) - are made by and kept with
//! that PluginArray, each a traced child (engine.traceChild) so that the
//! same objects come back for as long as the array lives. Plugin's and
//! MimeType's steps that name "this's relevant global object's PDF viewer
//! plugin objects" reach them through the Window's navigator.plugins.
//!
//! Spec: https://html.spec.whatwg.org/multipage/system-state.html#pdf-viewing-support

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const pdf_viewer = @import("html_core").navigator.pdf_viewer;

pub const State = interfaces.PluginArray.State;

pub const ImplError = error{
    NotImplemented,
};

const count = pdf_viewer.plugin_names.len;

/// The Window's PDF viewer plugin objects, made on first use.
pub const InternalState = struct {
    plugins: [count]?*runtime.Instance = @splat(null),
    generations: [count]u64 = @splat(0),
    made: usize = 0,
};

const slot_names = blk: {
    var names: [count][]const u8 = undefined;
    for (0..count) |i| names[i] = std.fmt.comptimePrint("PluginArray:pdf viewer plugin {d}", .{i});
    break :blk names;
};

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = allocator;
    _ = StateType;
    _ = args;
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{};
    instance.getState(State).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    // The edges still waiting for this array's wrapper (an array freed
    // before script saw it); an edge on a wrapper dies with the wrapper.
    inline for (0..count) |i| {
        if (i < internal.made) engine.forgetTracedChild(instance, .{ .name = slot_names[i] });
    }
    runtime.arenaOf(instance).destroy(InternalState, internal);
}

/// The Window's PDF viewer plugin objects: the list - five Plugin objects
/// named by `pdf_viewer.plugin_names`, or the empty list when the PDF viewer
/// is not supported. BORROWED.
fn pluginObjects(instance: *runtime.Instance) ![]const ?*runtime.Instance {
    const state = instance.stateAs(State) orelse return error.InvalidStateError;
    const internal = state.own._internal orelse return error.InvalidStateError;
    const wanted = pdf_viewer.pluginNamesWhen(pdf_viewer.supported()).len;
    while (internal.made < wanted) {
        const index = internal.made;
        const plugin = try interfaces.Plugin.initWith(instance.ctx.allocator, instance.ctx, .{ .pdf_plugin_index = @as(u8, @intCast(index)) });
        internal.plugins[index] = plugin;
        internal.generations[index] = runtime.SlabAllocator.generationOf(plugin);
        internal.made += 1;
        // This array keeps it: the same object comes back from item(),
        // namedItem() and a MimeType's enabledPlugin.
        engine.traceChild(instance, plugin, .{ .name = slot_names[index] });
    }
    return internal.plugins[0..wanted];
}

fn pluginAt(instance: *runtime.Instance, index: usize) !?*runtime.Instance {
    const plugins = try pluginObjects(instance);
    if (index >= plugins.len) return null;
    const plugin = plugins[index] orelse return null;
    const state = instance.stateAs(State) orelse return null;
    const internal = state.own._internal orelse return null;
    if (runtime.SlabAllocator.generationOf(plugin) != internal.generations[index]) return null;
    return plugin;
}

/// "The PluginArray interface's length getter steps are to return this's
/// relevant global object's PDF viewer plugin objects's size."
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    _ = instance;
    return @intCast(pdf_viewer.pluginNamesWhen(pdf_viewer.supported()).len);
}

/// item(index): "1. Let plugins be this's relevant global object's PDF
/// viewer plugin objects. 2. If index < plugins's size, then return
/// plugins[index]. 3. Return null." Also the indexed getter.
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
    return pluginAt(instance, index);
}

/// namedItem(name): "1. For each Plugin plugin of this's relevant global
/// object's PDF viewer plugin objects: if plugin's name is name, then return
/// plugin. 2. Return null." Also the named getter.
pub fn call_namedItem(instance: *runtime.Instance, name: runtime.DOMString) anyerror!?*runtime.Instance {
    const index = pdf_viewer.pluginIndex(pdf_viewer.supported(), name.asSlice()) orelse return null;
    return pluginAt(instance, index);
}

/// "The PluginArray interface supports named properties. If the user agent's
/// PDF viewer supported is true, then they are the PDF viewer plugin names.
/// Otherwise, they are the empty list."
pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
    _ = instance;
    const names = pdf_viewer.pluginNamesWhen(pdf_viewer.supported());
    const out = try allocator.alloc(runtime.DOMString, names.len);
    for (out, names) |*slot, name| slot.* = runtime.DOMString.initInterned(name);
    return out;
}

pub fn isSupportedPropertyName(instance: *runtime.Instance, name: runtime.DOMString) anyerror!bool {
    _ = instance;
    return pdf_viewer.pluginIndex(pdf_viewer.supported(), name.asSlice()) != null;
}

/// "The PluginArray interface's refresh() method steps are to do nothing."
pub fn call_refresh(instance: *runtime.Instance) anyerror!void {
    _ = instance;
}
