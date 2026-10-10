//! PointerEvent and WheelEvent are MouseEvents: their relatedTarget is the
//! MouseEvent's, kept by the event (dom.event_construction's MouseEvent
//! step), and their teardown is MouseEvent's too. Before lane ownerdoc each
//! wrote the generated field raw - a bare pointer a held event read freed.
const od = @import("od_test_helpers.zig");

fn subclassesKeepTheirRelatedTarget() !void {
    const page = try od.open();
    defer page.close();
    try page.run(
        \\globalThis.kept = (() => {
        \\  const doc = makeDocument();
        \\  return {
        \\    pointer: new PointerEvent('pointerover', { relatedTarget: doc.createElement('span') }),
        \\    wheel: new WheelEvent('wheel', { relatedTarget: doc.createElement('em') }),
        \\    none: new PointerEvent('pointerdown'),
        \\  };
        \\})();
    );
    try od.collectAndTurn(page);
    try page.run(
        \\if (kept.pointer.relatedTarget.localName !== 'span') throw new Error('pointer: ' + kept.pointer.relatedTarget);
        \\checkDocument(kept.pointer.relatedTarget, 'pointer related target');
        \\if (kept.wheel.relatedTarget.localName !== 'em') throw new Error('wheel: ' + kept.wheel.relatedTarget);
        \\checkDocument(kept.wheel.relatedTarget, 'wheel related target');
        \\if (kept.none.relatedTarget !== null) throw new Error('none');
    );
}

test "a PointerEvent and a WheelEvent keep their related target" {
    try od.onFreshThread(subclassesKeepTheirRelatedTarget);
}
