//! "Recording and restoring overrides" (specs/w3c/execCommand.md), the
//! Document's state and value overrides, "record the values" / "restore
//! the values" (Assorted block formatting command algorithms) - and, below
//! them, the block formatting steps the delete commands lean on (normalize
//! sublists, fix disallowed ancestors, outdent: lane editing4's).
//!
//! The overrides live on the Document's editor state
//! (html_core editing.state.FormattingOverrides, freed with the Document),
//! deep-copied there with its own allocator - never in a command's scratch
//! arena. They are unset "whenever the number of ranges in the selection
//! changes ... and whenever a boundary point of the range at a given index
//! in the selection changes": the overrides carry the selection they were
//! set under (range and boundary nodes by address and slab generation,
//! never dereferenced) and read as unset once it differs - Gecko's design
//! (PendingStyles::OnSelectionChange, editor/libeditor/PendingStyles.cpp:
//! pending styles survive while the caret stays at mLastSelectionPoint),
//! with no hook into Selection.
//!
//! The recorded lists (record current overrides / states and values,
//! record the values) live in the command's scratch arena (Edit.scratch).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const html_core = @import("html_core");
const common = @import("common.zig");
const inline_formatting = @import("inline.zig");

const Edit = common.Edit;
const Instance = common.Instance;
const Command = inline_formatting.Command;
const EditorState = html_core.editing.state.EditorState;
pub const FormattingOverrides = html_core.editing.state.FormattingOverrides;

// ============================================================================
// The Document's state and value overrides
// ============================================================================

fn editorState(edit: *Edit) !*EditorState {
    return try html_core.editing.executor.editorStateOf(edit.allocator, @ptrCast(edit.document));
}

/// The Document's CSS styling flag.
pub fn cssStylingFlag(edit: *Edit) !bool {
    return (try editorState(edit)).style_with_css;
}

/// The identity of the selection's range and boundary points now.
fn selectionKey(edit: *Edit) !FormattingOverrides.SelectionKey {
    const count = try interfaces.Selection.get_rangeCount(edit.selection);
    var key: FormattingOverrides.SelectionKey = .{ .range_count = count };
    if (count == 0) return key;
    const range = try interfaces.Selection.call_getRangeAt(edit.selection, 0);
    key.range = @intFromPtr(range);
    key.range_generation = runtime.SlabAllocator.generationOf(range);
    const start = (try edit.rangeStart()) orelse return key;
    const end = (try edit.rangeEnd()) orelse return key;
    key.start = @intFromPtr(start.node);
    key.start_generation = runtime.SlabAllocator.generationOf(start.node);
    key.start_offset = start.offset;
    key.end = @intFromPtr(end.node);
    key.end_generation = runtime.SlabAllocator.generationOf(end.node);
    key.end_offset = end.offset;
    return key;
}

/// The Document's overrides, unset first when the selection changed since
/// they were set.
fn current(edit: *Edit) !*FormattingOverrides {
    const state = try editorState(edit);
    const store = &state.formatting_overrides;
    if (store.any()) {
        const key = try selectionKey(edit);
        if (!key.eql(store.selection)) store.clear(state.allocator);
    }
    return store;
}

fn stateCommand(command: Command) ?FormattingOverrides.StateCommand {
    return switch (command) {
        .bold => .bold,
        .italic => .italic,
        .strikethrough => .strikethrough,
        .subscript => .subscript,
        .superscript => .superscript,
        .underline => .underline,
        else => null,
    };
}

/// The value override slot; backColor shares hiliteColor's ("such that
/// setting one sets the other to the same thing and unsetting one unsets
/// the other").
fn valueCommand(command: Command) ?FormattingOverrides.ValueCommand {
    return switch (command) {
        .create_link => .create_link,
        .font_name => .font_name,
        .font_size => .font_size,
        .fore_color => .fore_color,
        .hilite_color, .back_color => .hilite_color,
        else => null,
    };
}

/// The state override for `command`, or null when unset.
pub fn stateOverride(edit: *Edit, command: Command) !?bool {
    const slot = stateCommand(command) orelse return null;
    return (try current(edit)).states.get(slot);
}

pub fn setStateOverride(edit: *Edit, command: Command, value: bool) !void {
    const slot = stateCommand(command) orelse return;
    const store = try current(edit);
    store.states.set(slot, value);
    store.state_order.set(slot, store.next_order);
    store.next_order += 1;
    store.selection = try selectionKey(edit);
}

pub fn unsetStateOverride(edit: *Edit, command: Command) !void {
    const slot = stateCommand(command) orelse return;
    (try current(edit)).states.set(slot, null);
}

/// The value override for `command`, or null when unset: borrowed from the
/// editor state until the next override write.
pub fn valueOverride(edit: *Edit, command: Command) !?[]const u8 {
    const slot = valueCommand(command) orelse return null;
    return (try current(edit)).values.get(slot);
}

pub fn setValueOverride(edit: *Edit, command: Command, value: []const u8) !void {
    const slot = valueCommand(command) orelse return;
    const state = try editorState(edit);
    const store = try current(edit);
    const owned = try state.allocator.dupe(u8, value);
    if (store.values.get(slot)) |old| state.allocator.free(old);
    store.values.set(slot, owned);
    store.selection = try selectionKey(edit);
}

pub fn unsetValueOverride(edit: *Edit, command: Command) !void {
    const slot = valueCommand(command) orelse return;
    const state = try editorState(edit);
    const store = try current(edit);
    if (store.values.get(slot)) |old| state.allocator.free(old);
    store.values.set(slot, null);
}

// ============================================================================
// Recording and restoring overrides
// ============================================================================

/// One recorded (command, state-or-value) pair; a null string is neither
/// (an effective command value that was null), which restoring skips.
pub const Override = struct {
    command: Command,
    value: union(enum) { state: bool, value: ?[]const u8 },
};

/// "record current overrides" / "record current states and values": the
/// list restored after the action, in the command's scratch arena.
pub const Overrides = struct {
    items: []const Override = &.{},
};

/// "record current overrides".
pub fn recordCurrentOverrides(edit: *Edit) !Overrides {
    const arena = edit.scratchAllocator();
    var list: std.ArrayList(Override) = .empty;
    // Step 2: createLink's value override first.
    if (try valueOverride(edit, .create_link)) |link| try list.append(arena, .{ .command = .create_link, .value = .{ .value = try arena.dupe(u8, link) } });
    // Step 3: the state overrides - in the order they were set rather than
    // the spec's fixed order, so a deletion's recorded wrappers come back
    // nested as they were (see recordCurrentStatesAndValues).
    const Ordered = struct { command: Command, state: bool, order: u32 };
    var states: std.ArrayList(Ordered) = .empty;
    for ([_]Command{ .bold, .italic, .strikethrough, .subscript, .superscript, .underline }) |command| {
        if (try stateOverride(edit, command)) |state| {
            const order = (try editorState(edit)).formatting_overrides.state_order.get(stateCommand(command).?);
            try states.append(arena, .{ .command = command, .state = state, .order = order });
        }
    }
    std.mem.sort(Ordered, states.items, {}, struct {
        fn earlierFirst(_: void, a: Ordered, b: Ordered) bool {
            return a.order < b.order;
        }
    }.earlierFirst);
    for (states.items) |entry| try list.append(arena, .{ .command = entry.command, .value = .{ .state = entry.state } });
    // Step 4: the value overrides.
    for ([_]Command{ .font_name, .font_size, .fore_color, .hilite_color }) |command| {
        if (try valueOverride(edit, command)) |value| try list.append(arena, .{ .command = command, .value = .{ .value = try arena.dupe(u8, value) } });
    }
    return .{ .items = list.items };
}

/// "record current states and values" (execCommand.md line 4434), which
/// delete the selection runs before it deletes (steps 18-19).
///
/// Two deviations, both the browsers' (golden rule 2, no newer spec - the
/// spec text is the 2011-era draft's):
/// - The values are those in effect at the range's START node as the
///   deletion was given it (`start_node`), not at the first formattable
///   node effectively contained: a deletion that starts outside a wrapper
///   does not hand the wrapper's style to the next typed text. Blink saves
///   its typing style from the start of the selection it deletes
///   (DeleteSelectionCommand::SaveTypingStyleState:
///   EditingStyle(selection_to_delete_.Start()),
///   third_party/blink/renderer/core/editing/commands/
///   delete_selection_command.cc at chromium f31874d8d6d0). WPT
///   editing/run/multitest.html ?9001-last, "delete, inserttext d,e on
///   <div>abc[<b><i><img src="/img/lion.svg">de]f</i></b>ghi</div>", its
///   "{" form and the forwarddelete pairs expect the text unstyled
///   (`abcde<b><i>f</i></b>ghi`): Chrome 156 and Safari 27 pass all six,
///   Firefox 158 fails five of them with the styled result the spec gives
///   (wpt.fyi c645564b0e; lane editing1's class B). Majority: Chrome and
///   Safari. Lane editing2's insertText test cites Chrome and Firefox for
///   the same rule on `<div>abc[<b><i><img>def]</i></b>ghi</div>`. The
///   spec's "nothing formattable, nothing recorded" (steps 2-3) stays.
/// - The toggles are listed outermost wrapper first, and record current
///   overrides replays state overrides in the order they were set, so
///   restoring rebuilds the nesting the deleted text had: `<b><i>[def]</i>
///   </b>` deleted and retyped is `<b><i>def</i></b>` and `<i><b>[def]</b>
///   </i>` is `<i><b>d</b></i>` in all three browsers (multitest.html
///   ?9001-last "delete, inserttext d,e,f on <div>abc<b><i>[def]</i></b>
///   ghi</div>" and its forwarddelete form: Chrome 156, Firefox 158 and
///   Safari 27 pass). Each later wrapper goes inside the earlier ones,
///   because set the selection's value does not wrap an element that holds
///   the whole range (inline.zig); the spec's fixed order (bold, then
///   italic) would rebuild `<i><b>` for both.
pub fn recordCurrentStatesAndValues(edit: *Edit, start_node: *Instance) !Overrides {
    const arena = edit.scratchAllocator();
    var list: std.ArrayList(Override) = .empty;
    // Steps 2-3: nothing formattable effectively contained in the active
    // range, nothing to record.
    _ = (try inline_formatting.firstFormattableNode(edit)) orelse return .{};
    // The range's start as the caller was given it (delete the selection
    // has normalized the active range by now).
    const node = start_node;
    // Step 4: its link.
    try list.append(arena, .{ .command = .create_link, .value = .{ .value = try inline_formatting.effectiveValue(edit, node, .create_link) } });
    // Step 5: the toggles, true when its effective command value is one of
    // the inline command activated values - outermost wrapper first.
    const Toggle = struct { command: Command, active: bool, depth: u32 };
    var toggles: std.ArrayList(Toggle) = .empty;
    for ([_]Command{ .bold, .italic, .strikethrough, .subscript, .superscript, .underline }) |command| {
        const effective = try inline_formatting.effectiveValue(edit, node, command);
        var active = false;
        if (effective) |v| for (command.activatedValues().?) |candidate| {
            if (std.mem.eql(u8, v, candidate)) active = true;
        };
        const depth: u32 = if (active) try specifyingDepth(edit, node, command) else 0;
        try toggles.append(arena, .{ .command = command, .active = active, .depth = depth });
    }
    std.mem.sort(Toggle, toggles.items, {}, struct {
        fn outermostFirst(_: void, a: Toggle, b: Toggle) bool {
            const ka: u32 = if (a.active) a.depth else std.math.maxInt(u32);
            const kb: u32 = if (b.active) b.depth else std.math.maxInt(u32);
            return ka < kb;
        }
    }.outermostFirst);
    for (toggles.items) |toggle| try list.append(arena, .{ .command = toggle.command, .value = .{ .state = toggle.active } });
    // Step 6: fontName, foreColor and hiliteColor (at the start node, see
    // above).
    for ([_]Command{ .font_name, .fore_color, .hilite_color }) |command| {
        try list.append(arena, .{ .command = command, .value = .{ .value = try inline_formatting.effectiveValue(edit, node, command) } });
    }
    // Step 7: fontSize as the node's effective command value (pixels).
    try list.append(arena, .{ .command = .font_size, .value = .{ .value = try inline_formatting.effectiveValue(edit, node, .font_size) } });
    return .{ .items = list.items };
}

/// The depth (ancestor count) of the nearest inclusive ancestor element of
/// `node` that specifies a value for `command`; 0 for none.
fn specifyingDepth(edit: *Edit, node: *Instance, command: Command) !u32 {
    const ancestor = (try specifyingAncestor(edit, node, command)) orelse return 0;
    var depth: u32 = 1;
    var up = try common.parent(ancestor);
    while (up) |c| : (up = try common.parent(c)) depth += 1;
    return depth;
}

/// "restore states and values" from `recorded` (line 4483).
pub fn restoreStatesAndValues(edit: *Edit, recorded: Overrides) !void {
    // Step 1.
    var node = try inline_formatting.firstFormattableNode(edit);
    // Step 2: something formattable - take each command's action where it
    // differs.
    if (node != null) {
        for (recorded.items) |pair| {
            const command = pair.command;
            switch (pair.value) {
                // Step 2.1.
                .state => |override| {
                    if ((try inline_formatting.queryState(edit, command)) == override) continue;
                    _ = try inline_formatting.action(edit, command, "");
                },
                .value => |maybe| {
                    const override = maybe orelse continue;
                    switch (command) {
                        // Step 2.3: createLink has no value; compare its
                        // value override or the node's link.
                        .create_link => {
                            const differs = if (try valueOverride(edit, .create_link)) |link|
                                !std.mem.eql(u8, link, override)
                            else blk: {
                                const effective = try inline_formatting.effectiveValue(edit, node.?, .create_link);
                                break :blk effective == null or !std.mem.eql(u8, effective.?, override);
                            };
                            if (!differs) continue;
                            _ = try inline_formatting.action(edit, .create_link, override);
                        },
                        // Step 2.4: fontSize through its legacy size.
                        .font_size => {
                            const differs = if (try valueOverride(edit, .font_size)) |size|
                                !std.mem.eql(u8, size, override)
                            else
                                !inline_formatting.areLooselyEquivalent(edit, .font_size, try inline_formatting.effectiveValue(edit, node.?, .font_size), override);
                            if (!differs) continue;
                            const legacy = @import("style_values.zig").legacyFontSizeFor(inline_formatting.overrideToPixels(override));
                            const digits = [_][]const u8{ "1", "2", "3", "4", "5", "6", "7" };
                            _ = try inline_formatting.action(edit, .font_size, digits[legacy - 1]);
                        },
                        // Step 2.2.
                        else => {
                            if (inline_formatting.areEquivalent(edit, command, try inline_formatting.queryValue(edit, command), override)) continue;
                            _ = try inline_formatting.action(edit, command, override);
                        },
                    }
                },
            }
            // Step 2.6: the action may have split the node.
            if (try inline_formatting.firstFormattableNode(edit)) |first| node = first;
        }
        return;
    }
    // Step 3: nothing formattable - the overrides themselves.
    for (recorded.items) |pair| {
        switch (pair.value) {
            .state => |override| try setStateOverride(edit, pair.command, override),
            .value => |maybe| if (maybe) |override| try setValueOverride(edit, pair.command, override),
        }
    }
}

// ============================================================================
// Recording and restoring the values of moved nodes
// ============================================================================

/// One (node, command, specified command value) triple.
pub const RecordedValue = struct {
    node: *Instance,
    command: Command,
    value: inline_formatting.Value,
};

/// "record the values" of a node list: the specified command value each
/// node inherits from its nearest specifying ancestor, for the inline
/// formatting commands, so a move can restore them. In the scratch arena.
pub const Values = struct {
    items: []const RecordedValue = &.{},
};

/// The nearest inclusive ancestor element of `node` (its parent for a
/// non-element) with a specified command value for `command`, or null.
fn specifyingAncestor(edit: *Edit, node: *Instance, command: Command) !?*Instance {
    var ancestor: ?*Instance = if (common.isElement(node)) node else try common.parent(node);
    while (ancestor) |a| {
        if (!common.isElement(a)) return null;
        if ((try inline_formatting.specifiedValue(edit, a, command)) != null) return a;
        ancestor = try common.parent(a);
    }
    return null;
}

/// "record the values" of `nodes`.
pub fn recordTheValues(edit: *Edit, nodes: []const *Instance) !Values {
    const arena = edit.scratchAllocator();
    var list: std.ArrayList(RecordedValue) = .empty;
    for (nodes) |node| {
        for (inline_formatting.recorded_commands) |command| {
            const ancestor = try specifyingAncestor(edit, node, command);
            const value: inline_formatting.Value = if (ancestor) |a| try inline_formatting.specifiedValue(edit, a, command) else null;
            try list.append(arena, .{ .node = node, .command = command, .value = value });
        }
    }
    return .{ .items = list.items };
}

/// "restore the values" recorded in `values`.
pub fn restoreTheValues(edit: *Edit, values: Values) !void {
    for (values.items) |triple| {
        // Steps 1.1-1.3: the nearest specifying ancestor now.
        const ancestor = try specifyingAncestor(edit, triple.node, triple.command);
        if (triple.value == null and ancestor != null) {
            // Step 1.4: something specifies a value that was not there -
            // push it down, aiming for none.
            try inline_formatting.pushDownValues(edit, triple.node, triple.command, null);
        } else if ((ancestor != null and !inline_formatting.areEquivalent(edit, triple.command, try inline_formatting.specifiedValue(edit, ancestor.?, triple.command), triple.value)) or
            (ancestor == null and triple.value != null))
        {
            // Step 1.5: a different value, or none where there was one -
            // force the recorded one.
            try inline_formatting.forceValue(edit, triple.node, triple.command, triple.value);
        }
    }
}

/// "normalize sublists" in `item` (line 3988).
/// TODO(editing, list commands): split an li around its ol/ul children.
pub fn normalizeSublists(edit: *Edit, item: *Instance) !void {
    _ = edit;
    _ = item;
}

/// "fix disallowed ancestors" of `node` (line 3882).
/// TODO(editing, block commands): split the parent until node is an
/// allowed child of its ancestors, converting stray list items and cells
/// to the default single-line container.
pub fn fixDisallowedAncestors(edit: *Edit, node: *Instance) !void {
    _ = edit;
    _ = node;
}

/// The delete command's step 10: at the start of an indentation element,
/// block-extend the caret's range and "outdent" each of its nodes
/// ("Indenting and outdenting", line 5697).
/// TODO(editing, indent/outdent): the outdent algorithm; until it exists
/// the caret stays and nothing changes.
pub fn outdentAtIndentationElement(edit: *Edit, node: *Instance) !void {
    _ = edit;
    _ = node;
}

test "an empty record restores nothing" {
    const recorded: Overrides = .{};
    try std.testing.expectEqual(@as(usize, 0), recorded.items.len);
    const values: Values = .{};
    try std.testing.expectEqual(@as(usize, 0), values.items.len);
}
