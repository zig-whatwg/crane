//! An element's ElementInternals lives exactly as long as the element
//! (lifefix2's PR-N1 audit, item 6 of lane edges): :state(), form validity
//! and form submission read it through the element's bare
//! `element_internals` pointer (dom.custom_elements.attachedInternals).
//!
//! Why the pointer is never left dangling: the element keeps its internals
//! by an edge from its own wrapper (HTMLElement.ensureInternals,
//! engine.traceChild), and that wrapper lives as long as the element does:
//! - an element script has not wrapped keeps the edge waiting, the internals
//!   held strongly, in its realm's wrapper cache until it is wrapped, and
//!   HTMLElement.deinit lets it go if the element is freed unwrapped;
//! - a wrapper is never replaced once made (WrapperCache.set refuses
//!   AlreadyWrapped, PR-M1), so its edges are never dropped from under a
//!   live element;
//! - node tracing collects a wrapped element's wrapper only together with
//!   its whole tree's, and the tree's root teardown frees the element then -
//!   its internals go in that same collection;
//! - an element adopted out of a frame keeps its wrapper in the frame's
//!   realm, which therefore lives as long as script holds the element.
//! Blink's ElementRareData traces Member<ElementInternals>; WebKit's holds a
//! RefPtr. Each case below drops every other reference, collects, lets
//! other elements' internals take any freed slot, and reads the element's.
const helpers = @import("edges_node_holders_helpers.zig");
const onFreshThread = helpers.onFreshThread;
const Page = helpers.Page;

fn internalsLiveAsLongAsTheElement() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\class Face extends HTMLElement {
        \\  static formAssociated = true;
        \\  constructor() {
        \\    super();
        \\    const internals = this.attachInternals();
        \\    internals.states.add('on');
        \\    internals.setFormValue('mine');
        \\  }
        \\}
        \\customElements.define('ed-native-face', Face);
        \\globalThis.face = new Face();
        \\globalThis.tree = (() => {
        \\  const root = document.createElement('div');
        \\  root.append(document.createElement('p'));
        \\  root.firstChild.append(new Face());
        \\  return root.firstChild;
        \\})();
        \\const frame = document.body.appendChild(document.createElement('iframe'));
        \\frame.contentWindow.eval(`
        \\  class Face extends HTMLElement {
        \\    static formAssociated = true;
        \\    constructor() { super(); this.attachInternals().states.add('framed'); }
        \\  }
        \\  customElements.define('ed-native-frame-face', Face);
        \\  window.made = new Face();
        \\`);
        \\globalThis.adopted = frame.contentWindow.made;
        \\document.body.append(adopted);
        \\frame.remove();
    );
    try page.turn();
    try page.run(
        \\TestUtils.gc();
        \\globalThis.others = [];
        \\for (let i = 0; i < 300; i++) others.push(new Face());
        \\TestUtils.gc();
        \\if (!face.matches(':state(on)')) throw new Error('an element script holds lost its internals');
        \\if (!tree.firstChild.matches(':state(on)')) throw new Error('an element in a held detached tree lost its internals');
        \\if (!adopted.matches(':state(framed)')) throw new Error('an element adopted out of a removed frame lost its internals');
        \\const form = document.body.appendChild(document.createElement('form'));
        \\face.setAttribute('name', 'f');
        \\form.append(face);
        \\if (new FormData(form).get('f') !== 'mine') throw new Error('form value');
    );
}

test "an element's ElementInternals lives as long as the element" {
    try onFreshThread(internalsLiveAsLongAsTheElement);
}
