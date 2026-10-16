//! HTML source candidates keep the URL resolved when src last changed.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
pub const State = interfaces.HTMLSourceElement.State;
/// The URL its src resolved to, made with the element: a block of the
/// Browser's arena, registered (dom.orphan_states). A source removed from
/// its tree while script held no wrapper of it - `innerHTML = ''` over a
/// parsed `<audio><source src>` - is an orphan nothing deinits; a block of
/// its own leaked, and its URL with it (lane orphanleak,
/// crane/cl-orphan-media.html).
pub const InternalState = struct {
    /// The allocator the URL came from: the context's.
    allocator: std.mem.Allocator,
    url: ?[]const u8 = null,

    /// What the state owns, without its element (dom.orphan_states).
    pub fn deinit(self: *InternalState) void {
        if (self.url) |url| self.allocator.free(url);
        self.url = null;
    }
};

const States = dom.orphan_states.Swept(.html_source_element, InternalState);

pub fn installHooks() void {
    dom.media_elements.installSourceElement(sourceURL);
    dom.attribute_change_steps.install("source", attributeChanged);
    // The states no deinit reached - orphaned sources' - at their Browser's
    // end.
    States.installSweep();
}
pub fn init(allocator: std.mem.Allocator, comptime StateType: type, vtable: *const runtime.VTable, ctx: runtime.Context) !*runtime.Instance {
    const instance = try interfaces.HTMLElement.initWithState(allocator, StateType, vtable, ctx);
    instance.getState(State).own._internal = null;
    errdefer instance.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(instance));
    instance.getState(State).own._internal = try States.create(instance, .{ .allocator = ctx.allocator });
    return instance;
}
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal != null) {
        state.own._internal = null;
        States.destroy(instance);
    }
    interfaces.HTMLElement.deinit(instance);
}
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    return init(ctx.allocator, State, &interfaces.HTMLSourceElement.vtable, ctx);
}
fn sourceURL(instance: *runtime.Instance) ?[]const u8 {
    const data = instance.getState(State).own._internal orelse return null;
    return data.url;
}
fn attributeChanged(instance: *runtime.Instance, name: []const u8, _: ?[]const u8, value: ?[]const u8, namespace: ?[]const u8) void {
    if (namespace != null or !std.mem.eql(u8, name, "src")) return;
    const data = instance.getState(State).own._internal orelse return;
    // Resource selection, children steps 4–7: the node document WHEN src
    // LAST CHANGED, so adopting a candidate does not silently rebase its URL.
    const url = if (value) |text| (if (text.len != 0) @import("html").encoding_parse.encodingParseAndSerialize(instance, text) catch null else null) else null;
    if (data.url) |old| instance.ctx.allocator.free(old);
    data.url = url;
}
