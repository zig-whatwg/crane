//! Where the past names map hears of a change that may give an element
//! another form owner (dom.form_past_names says why it is applied at the
//! change): the mutation seams of html/custom_elements/form_owner.zig, which
//! hear every insertion, removal and move and every attribute change, and
//! the parser's form association (form_associated.parserAssociate). Each is
//! one length check while no form of the agent has past names.
//!
//! An agent with no host (an engine-free realm) keeps none: no past names
//! are recorded there (HTMLFormElement's recordPastName asks `registryOf`).
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const dom = @import("dom");

const Registry = dom.form_past_names.Registry;

/// The past-names registry of `realm`'s agent; null for a realm whose agent
/// has no host (engine-free), where no past names are recorded.
pub fn registryOf(realm: runtime.Context) ?*Registry {
    const agent = realm.agent orelse return null;
    const host: *@import("html_core").agent_host.AgentHost = @ptrCast(@alignCast(engine.agentHost(agent) orelse return null));
    return &host.form_past_names;
}

/// `node` was inserted, removed or moved (the tree in its new shape). Only
/// an element can carry what a form owner is computed from: a moved text
/// node or comment changes no owner.
pub fn subtreeMoved(node: *runtime.Instance) void {
    const registry = registryOf(node.ctx) orelse return;
    if (registry.isEmpty()) return;
    const base = dom.instance_bridge.getNodeBase(@ptrCast(node)) orelse return;
    if (base.node_type != dom.NodeBase.ELEMENT_NODE) return;
    registry.dispatch(.{ .subtree = node });
}

/// An attribute in no namespace changed on `element`: its `form` attribute
/// resets its owner, and any `id` may be the one a form attribute names.
pub fn attributeChanged(element: *runtime.Instance, local_name: []const u8) void {
    const form = std.mem.eql(u8, local_name, "form");
    if (!form and !std.mem.eql(u8, local_name, "id")) return;
    const registry = registryOf(element.ctx) orelse return;
    if (registry.isEmpty()) return;
    registry.dispatch(if (form) .{ .form_attribute = element } else .id_attribute);
}

/// The parser recorded `element`'s form association.
pub fn associationRecorded(element: *runtime.Instance) void {
    const registry = registryOf(element.ctx) orelse return;
    if (registry.isEmpty()) return;
    registry.dispatch(.{ .association = element });
}
