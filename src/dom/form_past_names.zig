//! HTML "the form element", the past names map's removal rule: "If an
//! element listed in a form element's past names map changes form owner,
//! then its entries must be removed from that map."
//!
//! The map is the form's (HTMLFormElement's state). The rule is applied at
//! the change, never at the next read: a control removed and reinserted
//! between two reads changed its owner twice and has the owner it had, yet
//! its entries are gone (tmp/plans/codex-lpo-questions.md Q2). The form
//! owner is computed (html form_associated.zig), so no association event
//! says when it changes; the changes that can change it are the "reset the
//! form owner" triggers (HTML § 4.10.18.3), which the mutation seams report
//! (html.form_past_names): an insertion, removal or move, a `form` or `id`
//! attribute change, a parser association recorded. WebKit and Blink drop
//! the entries where they disassociate the element
//! (HTMLFormElement::removeFromPastNamesMap from unregisterFormListedElement
//! and unregisterImgElement; Blink's Disassociate).
//!
//! Which forms have entries is the AGENT's (`Registry`, on the agent's
//! host): an element and its form can move between the documents of one
//! agent (adoptNode), never between agents, so a per-document list would
//! lose a form adopted with its controls. The list holds the forms weakly -
//! a form's teardown frees its map, and its dead link is dropped at the next
//! change - and is empty, one length check per mutation, until script reads
//! a single named element off a form.
const std = @import("std");
const runtime = @import("runtime");
const Link = @import("live_collections.zig").Link;
const NodeBase = @import("node_base.zig").NodeBase;
const instance_bridge = @import("instance_bridge.zig");
const form_submission = @import("form_submission.zig");

pub const OwnerChange = form_submission.OwnerChange;

/// One agent's forms whose past names map has entries.
pub const Registry = struct {
    allocator: std.mem.Allocator,
    forms: std.ArrayListUnmanaged(Form) = .empty,

    /// A form with entries: weakly, and its tree node, read through the
    /// link first, for its node document.
    const Form = struct { link: Link, base: *NodeBase };

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Registry) void {
        self.forms.deinit(self.allocator);
        self.forms = .empty;
    }

    /// `form` has a past names entry: tell it of every change that can give
    /// an element another owner, until it has none. Once per form.
    pub fn add(self: *Registry, form: *runtime.Instance) !void {
        for (self.forms.items) |entry| if (entry.link.get() == form) return;
        const base = instance_bridge.getNodeBase(@ptrCast(form)) orelse return error.InvalidState;
        try self.forms.append(self.allocator, .{ .link = Link.to(form), .base = base });
    }

    /// Whether any form of the agent has a past names entry.
    pub fn isEmpty(self: *const Registry) bool {
        return self.forms.items.len == 0;
    }

    /// Hand `change` - made to a node of the document `document` - to every
    /// live form with entries in that document
    /// (form_submission.pastNamesOwnerChange, HTMLFormElement's), and drop
    /// the forms left with none, and the dead. A form in another document
    /// is skipped with one comparison: an entry's element is in its form's
    /// tree, so a change reaches it only in the form's node document (an
    /// adoption reaches it as the removal from the old document). Runs no
    /// script: a form only recomputes form owners and removes its own
    /// entries.
    pub fn dispatch(self: *Registry, change: OwnerChange, document: usize) void {
        var index: usize = 0;
        while (index < self.forms.items.len) {
            const entry = self.forms.items[index];
            const form = entry.link.get() orelse {
                _ = self.forms.swapRemove(index);
                continue;
            };
            if (documentOf(entry.base) != document) {
                index += 1;
                continue;
            }
            if (!form_submission.pastNamesOwnerChange(form, change)) {
                _ = self.forms.swapRemove(index);
                continue;
            }
            index += 1;
        }
    }
};

/// `node`'s node document, as a key (live_collections' documentKey): the
/// document's own tree node is what its nodes' owner_document points at.
pub fn documentOf(node: *const NodeBase) usize {
    if (node.node_type == NodeBase.DOCUMENT_NODE) return @intFromPtr(node);
    return @intFromPtr(node.owner_document);
}

test "an empty registry dispatches nothing, and frees nothing it does not hold" {
    var registry = Registry.init(std.testing.allocator);
    defer registry.deinit();
    try std.testing.expect(registry.isEmpty());
    registry.dispatch(.id_attribute, 0);
    try std.testing.expect(registry.isEmpty());
}
