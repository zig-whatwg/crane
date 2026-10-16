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
const form_submission = @import("form_submission.zig");

pub const OwnerChange = form_submission.OwnerChange;

/// One agent's forms whose past names map has entries.
pub const Registry = struct {
    allocator: std.mem.Allocator,
    forms: std.ArrayListUnmanaged(Link) = .empty,

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
        for (self.forms.items) |link| if (link.get() == form) return;
        try self.forms.append(self.allocator, Link.to(form));
    }

    /// Whether any form of the agent has a past names entry.
    pub fn isEmpty(self: *const Registry) bool {
        return self.forms.items.len == 0;
    }

    /// Hand `change` to every live form with entries
    /// (form_submission.pastNamesOwnerChange, HTMLFormElement's), and drop
    /// the forms left with none, and the dead. Runs no script: a form only
    /// recomputes form owners and removes its own entries.
    pub fn dispatch(self: *Registry, change: OwnerChange) void {
        var index: usize = 0;
        while (index < self.forms.items.len) {
            const form = self.forms.items[index].get() orelse {
                _ = self.forms.swapRemove(index);
                continue;
            };
            if (!form_submission.pastNamesOwnerChange(form, change)) {
                _ = self.forms.swapRemove(index);
                continue;
            }
            index += 1;
        }
    }
};

test "an empty registry dispatches nothing, and frees nothing it does not hold" {
    var registry = Registry.init(std.testing.allocator);
    defer registry.deinit();
    try std.testing.expect(registry.isEmpty());
    registry.dispatch(.id_attribute);
    try std.testing.expect(registry.isEmpty());
}
