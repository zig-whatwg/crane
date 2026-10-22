//! HTML element references: weak explicit associations and strong snapshots.
const helpers = @import("edges_node_holders_helpers.zig");
const Page = helpers.Page;

fn referenceLifetimes() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.source = document.body.appendChild(document.createElement('div'));
        \\(() => {
        \\  const target = document.createElement('span');
        \\  source.append(target);
        \\  source.ariaActiveDescendantElement = target;
        \\  if (source.ariaActiveDescendantElement !== target) throw new Error('single reference');
        \\  globalThis.weakTarget = new WeakRef(target);
        \\  target.remove();
        \\})();
    );
    try page.turn();
    try page.run(
        \\collectNow();
        \\if (weakTarget.deref() !== undefined) throw new Error('explicit target was rooted');
        \\if (source.ariaActiveDescendantElement !== null) throw new Error('dead weak target');
        \\(() => {
        \\  const target = source.appendChild(document.createElement('span'));
        \\  target.marker = 'kept';
        \\  source.ariaControlsElements = [target];
        \\  globalThis.snapshot = source.ariaControlsElements;
        \\  if (snapshot !== source.ariaControlsElements) throw new Error('unstable snapshot');
        \\  globalThis.weakSource = new WeakRef(source);
        \\  target.remove();
        \\  source.remove();
        \\  source = null;
        \\})();
    );
    try page.turn();
    try page.run(
        \\collectNow();
        \\if (weakSource.deref() !== undefined) throw new Error('snapshot rooted source');
        \\if (snapshot[0].marker !== 'kept') throw new Error('snapshot lost target');
        \\snapshot = null;
        \\collectNow();
    );
}

test "ARIA weak targets collect and snapshots outlive their source" {
    try helpers.onFreshThread(referenceLifetimes);
}

fn referenceRealmEnd() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.frame = document.body.appendChild(document.createElement('iframe'));
        \\globalThis.source = frame.contentDocument.body.appendChild(frame.contentDocument.createElement('div'));
        \\(() => {
        \\  const target = source.appendChild(frame.contentDocument.createElement('span'));
        \\  target.marker = 'frame target';
        \\  source.ariaControlsElements = [target];
        \\})();
        \\globalThis.snapshot = source.ariaControlsElements;
        \\frame.remove();
        \\frame = null;
    );
    try page.turn();
    try page.run(
        \\collectNow();
        \\if (snapshot[0].marker !== 'frame target') throw new Error('realm lost held snapshot');
        \\if (source.ariaControlsElements !== snapshot) throw new Error('realm lost cache');
        \\source = null;
        \\snapshot = null;
    );
    try page.turn();
    try page.run("collectNow();");
}

test "ARIA snapshots remain usable after frame removal and clean up at document teardown" {
    try helpers.onFreshThread(referenceRealmEnd);
}
