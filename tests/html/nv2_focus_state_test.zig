//! Blink Document::SetFocusedElement, WebKit Document::setFocusedElement,
//! and Gecko nsFocusManager::SetFocusInner/BlurImpl clear focus before blur
//! and abandon the pending focus when the blur handler focuses an element.
//! These source-derived cases complement WPT's third-element refocus case.
const helpers = @import("edges_node_holders_helpers.zig");

fn blurRefocus() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\for (const originalAgain of [false, true]) {
        \\  const buttons = Array.from({length: 3}, () => document.createElement('button'));
        \\  buttons.forEach(b => document.body.appendChild(b));
        \\  const [original, pending, third] = buttons;
        \\  original.focus();
        \\  const target = originalAgain ? original : third;
        \\  let duringBlur;
        \\  original.onblur = () => {
        \\    original.onblur = null;
        \\    duringBlur = document.activeElement;
        \\    target.focus();
        \\  };
        \\  pending.focus();
        \\  if (duringBlur !== document.body) throw new Error('old element was still focused during blur');
        \\  if (document.activeElement !== target) throw new Error('blur handler focus was overwritten: original=' + originalAgain);
        \\  buttons.forEach(b => b.remove());
        \\}
    );
}

test "blur observes cleared focus and can refocus the original element" {
    try helpers.onFreshThread(blurRefocus);
}
