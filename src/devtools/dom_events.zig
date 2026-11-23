//! The DOM agents' sink (lane cdpd1; design tmp/plans/cdpd1-design.md 1-2):
//! what a Browser's DOM-enabled page sessions do with the DOM's probes
//! (dom.inspector_probes). One sink per Browser - its scope's
//! `.inspector_probes` table, set while this remote end has adopted the
//! Browser (BrowserSide.install / uninstall) - and every probe goes to each
//! DOM-enabled session in the order their agents were enabled, as Blink's
//! probes go to each InspectorDOMAgent of the local root's
//! InstrumentingAgents (third_party/blink/renderer/build/scripts/templates/
//! instrumenting_probes_impl.cc.tmpl, the AgentRegistry's order).
//!
//! Everything here runs on the Browser's thread, inside the DOM algorithm
//! that called the probe: an agent reads the tree and sends events, and
//! never runs script or changes the tree.

const std = @import("std");
const runtime = @import("runtime");
const inspector_probes = @import("dom").inspector_probes;
const BrowserSide = @import("browser_side.zig").BrowserSide;
const PageSession = @import("page_session.zig").PageSession;
const dom_domain = @import("domains/dom.zig");

/// How many DOM agents are enabled in the process (the probes' gate).
pub fn enabledAgentCount() u32 {
    return inspector_probes.enabledAgentCount();
}

/// The Browser's DOM agents: the sessions whose DOM domain is enabled, in
/// the order it was enabled. Browser thread only.
pub const Agents = struct {
    sessions: std.ArrayListUnmanaged(*PageSession) = .empty,

    pub fn deinit(self: *Agents, allocator: std.mem.Allocator) void {
        std.debug.assert(self.sessions.items.len == 0);
        self.sessions.deinit(allocator);
    }
};

/// `session`'s DOM agent was enabled: it hears the probes from now on
/// (Blink: InspectorDOMAgent::EnableAndReset -> AddInspectorDOMAgent).
pub fn register(side: *BrowserSide, session: *PageSession) std.mem.Allocator.Error!void {
    try side.dom_agents.sessions.append(side.allocator, session);
    inspector_probes.agentEnabled();
}

/// `session`'s DOM agent was disabled, or its session is ending
/// (RemoveInspectorDOMAgent).
pub fn unregister(side: *BrowserSide, session: *PageSession) void {
    for (side.dom_agents.sessions.items, 0..) |s, i| if (s == session) {
        _ = side.dom_agents.sessions.orderedRemove(i);
        inspector_probes.agentDisabled();
        return;
    };
}

/// Install the Browser's sink (BrowserSide.install).
pub fn install(side: *BrowserSide, scope: *runtime.BrowserScope) std.mem.Allocator.Error!void {
    const sink = try scope.table(.inspector_probes, inspector_probes.Sink);
    sink.set(side, &vtable);
}

/// Remove it (BrowserSide.uninstall, after every session detached).
pub fn uninstall(scope: *runtime.BrowserScope) void {
    const sink = scope.existingTable(.inspector_probes, inspector_probes.Sink) orelse return;
    sink.set(null, null);
}

const vtable: inspector_probes.VTable = .{
    .did_insert_dom_node = didInsertDOMNode,
    .will_remove_dom_node = willRemoveDOMNode,
    .did_modify_dom_attr = didModifyDOMAttr,
    .character_data_modified = characterDataModified,
    .did_invalidate_style_attr = didInvalidateStyleAttr,
    .did_push_shadow_root = didPushShadowRoot,
    .top_layer_elements_changed = topLayerElementsChanged,
    .node_created = nodeCreated,
    .slot_assignment_changed = slotAssignmentChanged,
    .rendering_updated = renderingUpdated,
    .did_modify_adopted_style_sheets = didModifyAdoptedStyleSheets,
};

/// The agents a probe goes to: a copy, so that an agent's handler may
/// change the list (none does today).
fn agentsOf(context: *anyopaque, buffer: []*PageSession) []*PageSession {
    const side: *BrowserSide = @ptrCast(@alignCast(context));
    const sessions = side.dom_agents.sessions.items;
    const n = @min(sessions.len, buffer.len);
    @memcpy(buffer[0..n], sessions[0..n]);
    return buffer[0..n];
}

const max_agents = 64;

fn didInsertDOMNode(context: *anyopaque, node: *runtime.Instance) void {
    var buffer: [max_agents]*PageSession = undefined;
    for (agentsOf(context, &buffer)) |session| dom_domain.didInsertDOMNode(session, node);
}

fn willRemoveDOMNode(context: *anyopaque, node: *runtime.Instance) void {
    var buffer: [max_agents]*PageSession = undefined;
    for (agentsOf(context, &buffer)) |session| dom_domain.willRemoveDOMNode(session, node);
}

fn didModifyDOMAttr(context: *anyopaque, element: *runtime.Instance, name: inspector_probes.AttributeName, value: ?[]const u8) void {
    var buffer: [max_agents]*PageSession = undefined;
    for (agentsOf(context, &buffer)) |session| dom_domain.didModifyDOMAttr(session, element, name, value);
}

fn characterDataModified(context: *anyopaque, node: *runtime.Instance) void {
    var buffer: [max_agents]*PageSession = undefined;
    for (agentsOf(context, &buffer)) |session| dom_domain.characterDataModified(session, node);
}

fn didInvalidateStyleAttr(context: *anyopaque, element: *runtime.Instance) void {
    var buffer: [max_agents]*PageSession = undefined;
    for (agentsOf(context, &buffer)) |session| dom_domain.didInvalidateStyleAttr(session, element);
}

fn didPushShadowRoot(context: *anyopaque, host: *runtime.Instance, root: *runtime.Instance) void {
    var buffer: [max_agents]*PageSession = undefined;
    for (agentsOf(context, &buffer)) |session| {
        // Inside "attach a shadow root": what it pushes resolves no style.
        session.states.DOM.in_probe = true;
        defer session.states.DOM.in_probe = false;
        dom_domain.didPushShadowRoot(session, host, root);
    }
}

fn topLayerElementsChanged(context: *anyopaque, document: *runtime.Instance) void {
    var buffer: [max_agents]*PageSession = undefined;
    for (agentsOf(context, &buffer)) |session| dom_domain.topLayerElementsChanged(session, document);
}

fn nodeCreated(context: *anyopaque, node: *runtime.Instance) void {
    var buffer: [max_agents]*PageSession = undefined;
    for (agentsOf(context, &buffer)) |session| dom_domain.nodeCreated(session, node);
}

fn slotAssignmentChanged(context: *anyopaque, slot: *runtime.Instance) void {
    var buffer: [max_agents]*PageSession = undefined;
    for (agentsOf(context, &buffer)) |session| dom_domain.slotAssignmentChanged(session, slot);
}

fn renderingUpdated(context: *anyopaque, document: *runtime.Instance) void {
    var buffer: [max_agents]*PageSession = undefined;
    for (agentsOf(context, &buffer)) |session| dom_domain.renderingUpdated(session, document);
}

fn didModifyAdoptedStyleSheets(context: *anyopaque, owner: *runtime.Instance) void {
    var buffer: [max_agents]*PageSession = undefined;
    for (agentsOf(context, &buffer)) |session| dom_domain.didModifyAdoptedStyleSheets(session, owner);
}
