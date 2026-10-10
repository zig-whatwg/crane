//! An event keeps the target dispatch left it with (Blink: Event::Trace
//! visits target_). Before lane ownerdoc it was a bare pointer, and a held
//! event read a freed node once its target's tree was collected.
const od = @import("od_test_helpers.zig");

fn eventKeepsItsTarget() !void {
    const page = try od.open();
    defer page.close();
    try page.run(
        \\globalThis.kept = (() => {
        \\  const doc = makeDocument();
        \\  const p = doc.createElement('p');
        \\  const byScript = new Event('od');
        \\  p.dispatchEvent(byScript);
        \\  const button = doc.body.appendChild(doc.createElement('button'));
        \\  let byEngine = null;
        \\  button.addEventListener('click', e => { byEngine = e; });
        \\  button.click();
        \\  return { byScript, byEngine };
        \\})();
    );
    try od.collectAndTurn(page);
    try page.run(
        \\if (kept.byScript.target.localName !== 'p') throw new Error('target of a script event');
        \\checkDocument(kept.byScript.target, 'script event target');
        \\if (kept.byScript.srcElement !== kept.byScript.target) throw new Error('srcElement');
        \\if (kept.byEngine.target.localName !== 'button') throw new Error('target of an engine event');
        \\checkDocument(kept.byEngine.target, 'engine event target');
    );
}

test "an event keeps its target after dispatch" {
    try od.onFreshThread(eventKeepsItsTarget);
}
