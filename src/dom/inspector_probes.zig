//! The DevTools DOM agents' probes: where the DOM tells the Chrome DevTools
//! Protocol remote end (src/devtools) that a tree changed, so a client's DOM
//! domain stays live (roadmap cdp-live-dom; lane cdpd1, design
//! tmp/plans/cdpd1-design.md section 1).
//!
//! Blink's probe layer, reproduced: every probe is an inline check of ONE
//! process-wide atomic - CoreProbeSink::s_existingAgents, read by
//! HasAgentsGlobal in each generated probe (Chromium 157.0.8103.78,
//! third_party/blink/renderer/build/scripts/templates/
//! instrumenting_probes_inl.h.tmpl, probe_sink.h.tmpl) - and only behind it
//! the sink of the node's Browser (Blink: the local root frame's
//! CoreProbeSink, its InspectorDOMAgents). With no DOM agent enabled
//! anywhere, a probe costs one acquire load and a branch not taken, and its
//! arguments are not computed: each call site reads
//!
//!     if (inspector_probes.active()) inspector_probes.didInsertDOMNode(node);
//!
//! The sink is a side table of the Browser's scope (`.inspector_probes`),
//! which src/devtools fills when it adopts the Browser and clears when it
//! lets the Browser go (devtools.BrowserSide): no hook slot, since the agents
//! belong to a Browser, not to the process. Without src/devtools (-Dcdp=false)
//! nothing ever opens the gate.
//!
//! The probes sit where Blink's do, not at the MutationObserver record
//! points: insertion after the link and the slot steps, before the insertion
//! steps (ContainerNode::InsertNodeVector); removal before the unlink
//! (ContainerNode::WillRemoveChild); an attribute after its change steps
//! (Element::DidAddAttribute, DidModifyAttribute, DidRemoveAttribute); data
//! after its children changed steps (CharacterData::DidModifyData); a shadow
//! root once attached (Element::AttachShadowRootInternal); the top layer
//! when its members change (Document::AddToTopLayer, RemoveFromTopLayer).

const std = @import("std");
const runtime = @import("runtime");
const NodeBase = @import("node_base.zig").NodeBase;

// Blink's CoreProbeSink::s_existingAgents: how many CDP DOM agents are
// enabled in this process, in any Browser. A fast-return gate and nothing
// else: every probe reads it first and reads nothing through it. Each
// Browser's thread changes it only with atomic read-modify-writes (an
// agent's enable, and its disable or its session's end), probes read it with
// an acquire load, and a probe that finds it open in a Browser whose own sink
// has no agent (another Browser's agent opened it) finds none there and
// returns.
// process-wide: a gate counting the DOM agents enabled in any Browser (Blink's s_existingAgents); atomic increments and decrements from each Browser's thread, acquire reads, never a pointer: a stale open read only costs a sink lookup that finds no agent
var enabled_agents: std.atomic.Value(u32) = .init(0);

/// Whether any DOM agent is enabled in the process: the one check at every
/// probe site (Blink's HasAgentsGlobal(kInspectorDOMAgent)).
pub inline fn active() bool {
    return enabled_agents.load(.acquire) != 0;
}

/// A DOM agent was enabled (Blink: InspectorDOMAgent::EnableAndReset ->
/// InstrumentingAgents::AddInspectorDOMAgent).
pub fn agentEnabled() void {
    _ = enabled_agents.fetchAdd(1, .acq_rel);
}

/// A DOM agent was disabled or its session ended (RemoveInspectorDOMAgent).
pub fn agentDisabled() void {
    const before = enabled_agents.fetchSub(1, .acq_rel);
    std.debug.assert(before != 0);
}

/// How many DOM agents are enabled in the process (tests).
pub fn enabledAgentCount() u32 {
    return enabled_agents.load(.acquire);
}

/// An attribute's qualified name, as a probe reports it: Blink's
/// QualifiedName::ToString is "prefix:localName", or the local name.
pub const AttributeName = struct {
    prefix: ?[]const u8,
    local_name: []const u8,
};

/// What a Browser's agents do with each probe (src/devtools). Every
/// function runs on the Browser's window agent thread, inside the DOM
/// algorithm that called the probe: it reads the tree, and never runs script
/// or mutates the tree.
pub const VTable = struct {
    did_insert_dom_node: *const fn (context: *anyopaque, node: *runtime.Instance) void,
    will_remove_dom_node: *const fn (context: *anyopaque, node: *runtime.Instance) void,
    /// `value` null: the attribute was removed.
    did_modify_dom_attr: *const fn (context: *anyopaque, element: *runtime.Instance, name: AttributeName, value: ?[]const u8) void,
    character_data_modified: *const fn (context: *anyopaque, node: *runtime.Instance) void,
    did_invalidate_style_attr: *const fn (context: *anyopaque, element: *runtime.Instance) void,
    did_push_shadow_root: *const fn (context: *anyopaque, host: *runtime.Instance, root: *runtime.Instance) void,
    top_layer_elements_changed: *const fn (context: *anyopaque, document: *runtime.Instance) void,
};

/// A Browser's probe sink: its scope's `.inspector_probes` table.
pub const Sink = struct {
    /// The Browser's agents, set while src/devtools has adopted it.
    context: ?*anyopaque = null,
    vtable: ?*const VTable = null,

    pub fn init(allocator: std.mem.Allocator) Sink {
        _ = allocator;
        return .{};
    }

    pub fn deinit(self: *Sink) void {
        self.* = .{};
    }

    /// Install `vtable`'s handlers for the Browser (null: remove them).
    pub fn set(self: *Sink, context: ?*anyopaque, vtable: ?*const VTable) void {
        self.context = context;
        self.vtable = vtable;
    }
};

/// The sink of the Browser that made `instance`, while it has agents.
fn sinkOf(instance: *const runtime.Instance) ?struct { context: *anyopaque, vtable: *const VTable } {
    const scope = runtime.BrowserScope.ofInstance(instance);
    const sink = scope.existingTable(.inspector_probes, Sink) orelse return null;
    const vtable = sink.vtable orelse return null;
    const context = sink.context orelse return null;
    return .{ .context = context, .vtable = vtable };
}

// ============================================================================
// The probes (behind `active()`)
// ============================================================================

/// DOM "insert", step 7: `node` was just linked into its parent (Blink
/// probe::DidInsertDOMNode).
pub noinline fn didInsertDOMNode(node: *NodeBase) void {
    const instance = node.registeredInstance() orelse return;
    const sink = sinkOf(instance) orelse return;
    sink.vtable.did_insert_dom_node(sink.context, instance);
}

/// DOM "remove": `node` is about to leave its parent, which it still has
/// (Blink probe::WillRemoveDOMNode).
pub noinline fn willRemoveDOMNode(node: *NodeBase) void {
    const instance = node.registeredInstance() orelse return;
    const sink = sinkOf(instance) orelse return;
    sink.vtable.will_remove_dom_node(sink.context, instance);
}

/// DOM "handle attribute changes", after its steps: Blink's
/// probe::DidModifyDOMAttr for an added or changed attribute - nothing when
/// the value did not change (InspectorDOMAgent::WillModifyDOMAttr sets
/// suppress_attribute_modified_event_ for old == new) - and
/// probe::DidRemoveDOMAttr for a removed one. A styled element's style
/// attribute also invalidates its inline style (Element::StyleAttributeChanged
/// -> probe::DidInvalidateStyleAttr, for every set and removal, the same
/// value too); set by its own declaration block's update (CSSOM "update
/// style attribute", `cssom_update`) it ONLY invalidates, as Blink's CSSOM
/// path never changes the attribute but by a lazy synchronization that runs
/// no probe (AttributeModificationReason::kBySynchronizationOfLazyAttribute).
pub noinline fn attributeChanged(
    element: *runtime.Instance,
    namespace: ?[]const u8,
    prefix: ?[]const u8,
    local_name: []const u8,
    old_value: ?[]const u8,
    new_value: ?[]const u8,
    styled: bool,
    cssom_update: bool,
) void {
    const sink = sinkOf(element) orelse return;
    const is_style = styled and namespace == null and std.mem.eql(u8, local_name, "style");
    if (is_style) sink.vtable.did_invalidate_style_attr(sink.context, element);
    if (is_style and cssom_update) return;
    if (new_value) |value| {
        if (old_value) |old| if (std.mem.eql(u8, old, value)) return;
    }
    sink.vtable.did_modify_dom_attr(sink.context, element, .{ .prefix = prefix, .local_name = local_name }, new_value);
}

/// CSSOM changed an element's inline style without its attribute (Blink
/// Element::InlineStyleChanged -> probe::DidInvalidateStyleAttr).
pub noinline fn didInvalidateStyleAttr(element: *runtime.Instance) void {
    const sink = sinkOf(element) orelse return;
    sink.vtable.did_invalidate_style_attr(sink.context, element);
}

/// DOM "replace data", after its steps (Blink CharacterData::DidModifyData ->
/// probe::CharacterDataModified).
pub noinline fn characterDataModified(node: *runtime.Instance) void {
    const sink = sinkOf(node) orelse return;
    sink.vtable.character_data_modified(sink.context, node);
}

/// DOM "attach a shadow root": `root` is `host`'s now (Blink
/// probe::DidPushShadowRoot).
pub noinline fn didPushShadowRoot(host: *runtime.Instance, root: *runtime.Instance) void {
    const sink = sinkOf(host) orelse return;
    sink.vtable.did_push_shadow_root(sink.context, host, root);
}

/// `document`'s top layer gained or lost a member (Blink
/// probe::TopLayerElementsChanged).
pub noinline fn topLayerElementsChanged(document: *runtime.Instance) void {
    const sink = sinkOf(document) orelse return;
    sink.vtable.top_layer_elements_changed(sink.context, document);
}

test "the gate is closed while no agent is enabled, and counts agents" {
    const before = enabledAgentCount();
    agentEnabled();
    try std.testing.expect(active());
    try std.testing.expectEqual(before + 1, enabledAgentCount());
    agentDisabled();
    try std.testing.expectEqual(before, enabledAgentCount());
    try std.testing.expectEqual(before != 0, active());
}
