//! Trusted pointer light-dismiss algorithms for HTML dialogs.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const form_associated = @import("form_associated.zig");
const close_watchers = @import("close_watchers.zig");

fn flatParent(node: *runtime.Instance) ?*runtime.Instance {
    if (dom.shadow_dom_algorithms.assignedSlotOf(node)) |slot| return slot;
    const parent = form_associated.parentOf(node) orelse return null;
    if (parent.stateAs(interfaces.ShadowRoot.State) != null) return interfaces.ShadowRoot.get_host(parent) catch null;
    return parent;
}

/// HTML "nearest clicked dialog", steps 3–5. Element-origin input supplies
/// an actual hit target; backdrop hit testing belongs to the layout host.
fn nearestClickedDialog(target: *runtime.Instance) ?*runtime.Instance {
    var current: ?*runtime.Instance = target;
    while (current) |node| : (current = flatParent(node)) {
        if (node.stateAs(interfaces.HTMLDialogElement.State) != null and
            form_associated.hasAttribute(node, "open")) return node;
    }
    return null;
}

/// HTML 4.11.5 "light dismiss open dialogs", called after popover dismiss
/// for trusted pointerdown/up, independently of event cancellation.
pub fn lightDismiss(target: *runtime.Instance, down: bool) void {
    const state = (dom.top_layer.ofElement(target, false) catch null) orelse return;
    const ancestor = nearestClickedDialog(target);
    if (down) {
        if (state.lastOpenDialog() != null) state.setDialogPointerdownTarget(ancestor);
        return;
    }
    // 6.1–3. Compare the remembered dialog even if script closed it between
    // down and up, then clear even if cleanup emptied the open list.
    // Q37 probe (2026-10-29, tmp/probes/q37/RESULT.md): Firefox 158 agrees;
    // Chrome 156 recomputes the open ancestor and dismisses another dialog.
    // With the shipping browsers split, the integrator ruled for this spec.
    const same_target = ancestor == state.dialog_pointerdown_target.get();
    state.setDialogPointerdownTarget(null);
    if (!same_target) return;
    // 6.4–6. Dismiss only the last opened dialog, and only in the Any state.
    const topmost = state.lastOpenDialog() orelse return;
    if (ancestor == topmost) return;
    const any = blk: {
        var closed_by = interfaces.HTMLDialogElement.get_closedBy(topmost) catch return;
        defer closed_by.deinit(topmost.ctx.allocator);
        break :blk std.mem.eql(u8, closed_by.asSlice(), "any");
    };
    if (!any) return;
    // 6.7–8. Its watcher keeps the dialog across cancel/close script.
    const window = close_watchers.relevantWindow(topmost) orelse return;
    _ = close_watchers.requestClose(window, .dialog, topmost, false);
}
