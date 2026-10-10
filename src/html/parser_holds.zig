//! The live HTML parsers as node holders (src/dom/node_holds.zig).
//!
//! A parser holds natively the nodes its own structures name: the stack of
//! open elements and the head and form element pointers (HTML 13.2.4.2-4).
//! No wrapper is made for them. Blink traces exactly those structures
//! (HTMLConstructionSite::Trace visits open_elements_, head_ and form_, and
//! HTMLStackItem holds a Member<ContainerNode>); WebKit's HTMLElementStack
//! records own their nodes with a RefPtr.
//!
//! The stack changes on every push and pop, so a parser does not mark its
//! nodes; it is a SCANNING holder. It registers with its Browser's
//! `node_holds.Registry` when it is created in a realm that has an engine,
//! and the one removing-steps callback asks it, on each removal ROOT, whether
//! that root is a host-including inclusive ancestor of a node it holds - an
//! O(stack depth) walk (`DocumentParser.holdsNodeUnder`). A parser that says
//! yes rescues the root: it roots that ONE wrapper from its Document's
//! kept-roots container until it is released (`DocumentParser.rescue`).
//! It unregisters when its last reference goes (`DocumentParser.release`) -
//! an old parser that `document.open` replaced while it is still on the
//! native stack stays registered, and still rescues, until then (HTML's
//! "abort a parser" leaves the unwinding frames to finish).
//!
//! Design: tmp/plans/parser-holds-design.md (5.1-5.3); the generalized
//! facility, tmp/plans/lane-nodeholds-handoff.md; lesson
//! docs/lessons/architecture-parser-holds-are-its-structures-and-detached-trees-are-rescued.md.

const dom = @import("dom");
const runtime = @import("runtime");
const node_holds = dom.node_holds;
const DocumentParser = @import("scripted_parser.zig").DocumentParser;

pub const Registry = node_holds.Registry;
pub const isUnderRoot = node_holds.isUnderRoot;
pub const hostIncludingRoot = node_holds.hostIncludingRoot;
pub const putRoot = node_holds.putRoot;
pub const clearRoot = node_holds.clearRoot;

/// Installed once, at process start (crane.Process; docs/instances.md
/// "Hooks"): the removing steps the parsers' rescues depend on.
pub fn installHooks() void {
    node_holds.installHooks();
}

/// `parser` as the registry's scanner: its walk, its rescue, its reference
/// count, and the kept-roots container it shares with the other parsers of
/// its Document.
pub fn scanner(parser: *DocumentParser) node_holds.Scanner {
    return .{
        .context = parser,
        .holds_node_under = &holdsNodeUnder,
        .rescue = &rescue,
        .retain = &retain,
        .release = &release,
        .container_owner = parser.document,
        .container_generation = parser.document_generation,
        .slot_end = &parser.kept_slot_end,
    };
}

fn holdsNodeUnder(context: *anyopaque, root: *dom.NodeBase) bool {
    const parser: *DocumentParser = @ptrCast(@alignCast(context));
    return parser.holdsNodeUnder(root);
}

fn rescue(context: *anyopaque, root: *runtime.Instance) void {
    const parser: *DocumentParser = @ptrCast(@alignCast(context));
    parser.rescue(root);
}

fn retain(context: *anyopaque) void {
    const parser: *DocumentParser = @ptrCast(@alignCast(context));
    parser.retain();
}

fn release(context: *anyopaque) void {
    const parser: *DocumentParser = @ptrCast(@alignCast(context));
    parser.release();
}
