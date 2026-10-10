//! A MouseEvent keeps its related target, set by its constructor or by
//! initMouseEvent (Blink: MouseEvent::Trace visits related_target_), as
//! FocusEvent keeps its own. Before lane ownerdoc it was a bare pointer in
//! the generated state, and initMouseEvent was not implemented at all.
const od = @import("od_test_helpers.zig");

fn mouseEventKeepsItsRelatedTarget() !void {
    const page = try od.open();
    defer page.close();
    try page.run(
        \\globalThis.kept = (() => {
        \\  const doc = makeDocument();
        \\  const constructed = new MouseEvent('mouseover', { relatedTarget: doc.createElement('span') });
        \\  const initialized = new MouseEvent('x');
        \\  initialized.initMouseEvent('mouseout', true, true, null, 0, 1, 2, 3, 4, true, false, true, false, 2, doc.createElement('em'));
        \\  return { constructed, initialized };
        \\})();
    );
    try od.collectAndTurn(page);
    try page.run(
        \\if (kept.constructed.relatedTarget.localName !== 'span') throw new Error('constructed: ' + kept.constructed.relatedTarget);
        \\checkDocument(kept.constructed.relatedTarget, 'constructed related target');
        \\const e = kept.initialized;
        \\if (e.type !== 'mouseout' || !e.bubbles || !e.cancelable) throw new Error('initEvent part');
        \\if (e.screenX !== 1 || e.screenY !== 2 || e.clientX !== 3 || e.clientY !== 4) throw new Error('coordinates');
        \\if (!e.ctrlKey || e.altKey || !e.shiftKey || e.metaKey || e.button !== 2) throw new Error('keys and button');
        \\if (e.relatedTarget.localName !== 'em') throw new Error('initialized: ' + e.relatedTarget);
        \\checkDocument(e.relatedTarget, 'initialized related target');
        \\e.initMouseEvent('again');
        \\if (e.relatedTarget !== null || e.clientX !== 0 || e.bubbles) throw new Error('defaults');
    );
}

test "a MouseEvent keeps its related target, from its constructor or initMouseEvent" {
    try od.onFreshThread(mouseEventKeepsItsRelatedTarget);
}
