//! Character movement skips noneditable positions within its editing root.
const helpers = @import("edges_node_holders_helpers.zig");

fn exercise() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const host = document.createElement('div');
        \\host.contentEditable = 'true';
        \\host.innerHTML = 'a<span contenteditable="false"><b>blocked</b></span>b';
        \\document.body.append(host);
        \\const selection = getSelection();
        \\for (const forward of [true, false]) {
        \\  selection.collapse(forward ? host.firstChild : host.lastChild, forward ? 1 : 0);
        \\  selection.modify('move', forward ? 'forward' : 'backward', 'character');
        \\  const expected = forward ? host.lastChild : host.firstChild;
        \\  const offset = forward ? 0 : 1;
        \\  const atText = selection.focusNode === expected && selection.focusOffset === offset;
        \\  const atBoundary = selection.focusNode === host && selection.focusOffset === (forward ? 2 : 1);
        \\  if (!atText && !atBoundary) throw new Error('caret entered noneditable subtree');
        \\}
        \\selection.removeAllRanges();
        \\host.remove();
    );
}

test "Selection.modify skips a noneditable subtree in both directions" {
    try helpers.onFreshThread(exercise);
}

fn siblingText() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const outer = document.createElement('div');
        \\const host = document.createElement('span');
        \\const left = document.createTextNode('ab');
        \\const right = document.createTextNode('cd');
        \\host.append(left, right);
        \\outer.append(host);
        \\document.body.append(outer);
        \\const selection = getSelection();
        \\for (const outerEditable of ['true', 'false']) {
        \\  outer.contentEditable = outerEditable;
        \\  for (const innerEditable of ['inherit', 'true', 'false']) {
        \\    host.contentEditable = innerEditable;
        \\    selection.collapse(left, left.length);
        \\    selection.modify('move', 'forward', 'character');
        \\    if (selection.focusNode !== right || selection.focusOffset !== 1)
        \\      throw new Error('sibling Text forward transition changed');
        \\    selection.modify('move', 'backward', 'character');
        \\    if (selection.focusNode !== left || selection.focusOffset !== left.length)
        \\      throw new Error('sibling Text backward transition changed');
        \\  }
        \\}
        \\selection.removeAllRanges();
    );
}

test "sibling Text transitions preserve their shared editing context in both directions" {
    // Text siblings inherit the same parent editing context, including an
    // explicit false or true boundary nested inside the opposite context.
    // The end of "ab" and the start of "cd" are one caret position, so a
    // forward character move from the end of "ab" passes "c" (corrected
    // 2026-11-12, lane editing5 b4, from the old structural unit's
    // (cd, 0)): Blink's NextVisuallyDistinctCandidate and WebKit's
    // nextVisuallyDistinctCandidate skip a visually equivalent position,
    // and selection/contenteditable/modify-around-inline-element-
    // boundary.tentative.html's "abc[]<span>def</span>" -> (def, 1) passes
    // in Chrome 157, Firefox 160 and Safari 27.2 (wpt.fyi 24ddf405a0).
    // Backward from there returns to the end of "ab".
    try helpers.onFreshThread(siblingText);
}
