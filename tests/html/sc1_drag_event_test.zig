//! DragEvent construction uses its ancestors' event construction steps.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

fn dragEvent() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const result = try page.evaluate(
        \\(() => {
        \\  const related = document.createElement('span');
        \\  related.textContent = 'kept';
        \\  const init = {bubbles:true, cancelable:true, composed:true, view:window,
        \\    detail:3, screenX:17, screenY:-19, clientX:23, clientY:-31,
        \\    ctrlKey:true, altKey:true, shiftKey:true, metaKey:true, button:2,
        \\    buttons:5, movementX:3, movementY:-4, relatedTarget:related};
        \\  for (const Constructor of [MouseEvent, DragEvent]) {
        \\    const event = new Constructor('dragenter', init);
        \\    if (event.type !== 'dragenter') return Constructor.name + ': type';
        \\    for (const key of Object.keys(init))
        \\      if (event[key] !== init[key]) return Constructor.name + ': ' + key;
        \\    const target = new EventTarget();
        \\    let called = false;
        \\    target.addEventListener('dragenter', e => { called = true; e.preventDefault(); });
        \\    if (target.dispatchEvent(event) || !called) return Constructor.name + ': dispatch';
        \\  }
        \\  globalThis.sc1HeldDrag = new DragEvent('dragenter', {relatedTarget: related});
        \\  return 'ok';
        \\})()
    );
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("ok", result);
    try page.turn();
    try page.run(
        \\collectNow();
        \\if (sc1HeldDrag.relatedTarget.textContent !== 'kept') throw new Error('lost related target');
    );
}

test "DragEvent inherits MouseEvent initialization and its related-target hold" {
    try helpers.onFreshThread(dragEvent);
}
