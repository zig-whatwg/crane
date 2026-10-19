//! Structural continuation from a parent boundary consumes one adjacent character.
//! Blink position_units.cc Next/PreviousPositionOfAlgorithm and
//! Next/PreviousVisuallyDistinctCandidate descend from the boundary into text.
//! Engine-source expectations stay native (row 73 Q11), not Crane WPT tests.
const helpers = @import("edges_node_holders_helpers.zig");

fn exercise() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const host = document.createElement('div');
        \\host.contentEditable = 'true';
        \\host.innerHTML = 'before<span contenteditable="false">widget</span>after';
        \\document.body.append(host);
        \\const selection = getSelection();
        \\for (const forward of [true, false]) {
        \\  for (const afterSkip of [false, true]) {
        \\    if (afterSkip) {
        \\      const start = forward ? host.firstChild : host.lastChild;
        \\      selection.collapse(start, forward ? start.length : 0);
        \\      selection.modify('move', forward ? 'forward' : 'backward', 'character');
        \\    } else {
        \\      selection.collapse(host, forward ? 2 : 1);
        \\    }
        \\    selection.modify('move', forward ? 'forward' : 'backward', 'character');
        \\    if (selection.focusNode !== (forward ? host.lastChild : host.firstChild) ||
        \\        selection.focusOffset !== (forward ? 1 : 5))
        \\      throw new Error('parent boundary skipped the adjacent text: ' + forward + '/' + afterSkip);
        \\  }
        \\}
        \\host.innerHTML = '<i>before<b></b></i><span contenteditable="false">widget</span><i><b></b>after</i>';
        \\for (const forward of [true, false]) {
        \\  selection.collapse(host, forward ? 2 : 1);
        \\  selection.modify('move', forward ? 'forward' : 'backward', 'character');
        \\  const text = forward ? host.lastChild.lastChild : host.firstChild.firstChild;
        \\  if (selection.focusNode !== text || selection.focusOffset !== (forward ? 1 : 5))
        \\    throw new Error('empty inline descendant hid adjacent text: ' + forward);
        \\}
        \\selection.removeAllRanges();
        \\host.remove();
    );
}

test "Selection.modify consumes one character after a parent boundary in both directions" {
    try helpers.onFreshThread(exercise);
}
