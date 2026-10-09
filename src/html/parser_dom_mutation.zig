//! HTML tree construction must consult the live DOM after script runs.
//! Design: WebKit HTMLConstructionSite's reparent and take-all-children tasks.
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const engine = @import("engine");
const TreeBuilder = @import("html_core").parser.TreeBuilder;
const TreeNode = @import("html_core").parser.TreeNode;

pub const Location = struct { parent: *runtime.Instance, before: ?*runtime.Instance };

// An Owned value keeps a wrapper alive, but realm teardown can still free its
// native Instance (engine protocol's Instance contract). Keep the context and
// slab generation before any operation that can run a removal reaction.
const SavedNode = struct {
    node: *runtime.Instance,
    context: runtime.Context,
    generation: u64,
    had_engine: bool,

    fn init(node: *runtime.Instance) SavedNode {
        return .{ .node = node, .context = node.ctx, .generation = runtime.SlabAllocator.generationOf(node), .had_engine = node.ctx.hasEngine() };
    }

    fn alive(self: SavedNode) bool {
        return (!self.had_engine or self.context.hasEngine()) and runtime.SlabAllocator.generationOf(self.node) == self.generation;
    }
};

/// Appropriate place steps 3–6: the on-stack table's LIVE parent wins.
/// If that parent is a template, discard the reference and use its content.
pub fn resolve(adapter: anytype, location: TreeBuilder.InsertionLocation) !Location {
    var parent = adapter.getDomNode(location.parent) orelse return error.InvalidStateError;
    var before = if (location.before) |node| adapter.getDomNode(node) else null;
    if (location.foster_table) |node| {
        const table = adapter.getDomNode(node) orelse return error.InvalidStateError;
        if (try interfaces.Node.get_parentNode(table)) |live_parent| {
            parent = live_parent;
            before = table;
        } else {
            parent = adapter.getDomNode(location.foster_fallback.?) orelse return error.InvalidStateError;
            before = null;
        }
    }
    // Step 6 can only apply to a template: the TreeNode parent is an HTML
    // template, or - foster parenting - the table's live parent, which script
    // can have made anything. Skip the template lookup otherwise.
    if (location.foster_table == null and !isHtmlTemplate(location.parent)) return .{ .parent = parent, .before = before };
    const target = try dom.template_contents.insertionTarget(parent);
    if (target != parent) before = null;
    return .{ .parent = target, .before = before };
}

fn isHtmlTemplate(node: *const TreeNode) bool {
    return node.node_type == .element and node.namespace == .html and node.hasTagName("template");
}

pub fn remove(node: *runtime.Instance) !void {
    if (try interfaces.Node.get_parentNode(node)) |parent|
        _ = try interfaces.Node.call_removeChild(parent, node);
}

pub fn insert(adapter: anytype, location: TreeBuilder.InsertionLocation, child: *TreeNode) !bool {
    // Adoption steps 4.14–4.16 compute the location BEFORE removing lastNode.
    const target = try resolve(adapter, location);
    const node = adapter.getDomNode(child) orelse return false;
    const saved_node = SavedNode.init(node);
    const saved_parent = SavedNode.init(target.parent);
    const saved_before: ?SavedNode = if (target.before) |before| SavedNode.init(before) else null;
    // Only a real move - a node with a live parent - runs a removal, and
    // with it reactions. A fresh node has no parent: nothing is held for it
    // (the parser's structures hold what it needs; design 5.4). For a move,
    // keep both ends alive until the following insertion, like
    // HTMLConstructionSite's owning references across its reparent task: a
    // live foster parent may have been created by script, and a moved node
    // the parser does not hold is in no parser structure. (A held moved node
    // is also rescued by the removal itself.)
    const moving = location.move and (try interfaces.Node.get_parentNode(node)) != null;
    var parent_hold: ?engine.Owned = if (moving and node.ctx.hasEngine()) try engine.retainValue(target.parent.ctx, .{ .instance = target.parent }) else null;
    defer if (parent_hold) |*held| held.release();
    var node_hold: ?engine.Owned = if (moving and node.ctx.hasEngine()) try engine.retainValue(node.ctx, .{ .instance = node }) else null;
    defer if (node_hold) |*held| held.release();
    if (moving) try remove(node);
    if (!saved_node.alive() or !saved_parent.alive()) return false;
    if (saved_before) |before| if (!before.alive()) return false;
    // A removal callback may have reattached it. Normal parser insertion also
    // leaves an element alone if its custom constructor already attached it.
    if ((try interfaces.Node.get_parentNode(node)) != null) return false;
    // pre-insert validity includes host edges, reference membership, and the
    // single document-element constraint. Invalid parser moves are dropped.
    _ = interfaces.Node.call_insertBefore(target.parent, node, target.before) catch |err| switch (err) {
        error.HierarchyRequestError, error.NotFoundError => return false,
        else => return err,
    };
    return true;
}

pub fn moveChildren(adapter: anytype, source: *TreeNode, destination: *TreeNode) !void {
    const from = adapter.getDomNode(source) orelse return;
    const to = adapter.getDomNode(destination) orelse return;
    const saved_from = SavedNode.init(from);
    const saved_to = SavedNode.init(to);
    // Adoption step 4.18: include children introduced by script, which the
    // parser's token tree cannot enumerate.
    while (saved_from.alive() and saved_to.alive()) {
        const child = (try interfaces.Node.get_firstChild(from)) orelse break;
        const saved_child = SavedNode.init(child);
        // A script-created child is absent from the adapter's parser roots.
        // Keep the borrowed child across removal and its possible reactions.
        var held: ?engine.Owned = if (child.ctx.hasEngine()) try engine.retainValue(child.ctx, .{ .instance = child }) else null;
        defer if (held) |*owned| owned.release();
        try remove(child);
        if (!saved_child.alive() or !saved_to.alive()) return;
        _ = interfaces.Node.call_appendChild(to, child) catch |err| switch (err) {
            error.HierarchyRequestError, error.NotFoundError => continue,
            else => return err,
        };
    }
}
