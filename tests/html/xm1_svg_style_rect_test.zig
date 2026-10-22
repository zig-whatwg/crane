//! CSSOM §7.1 and SVG 2 §5.13.2: existing objects behind SVG entry points.
const helpers = @import("edges_node_holders_helpers.zig");

fn inlineStyles() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\for (const name of ['svg', 'rect', 'use', 'foreignObject', 'xm1-unknown']) {
        \\  const e = document.createElementNS('http://www.w3.org/2000/svg', name);
        \\  const style = e.style;
        \\  if (!(style instanceof CSSStyleDeclaration) || style !== e.style) throw new Error(name + ': style identity');
        \\  if (style.parentRule !== null) throw new Error(name + ': style parent');
        \\  e.style = 'color: blue;';
        \\  if (style.color !== 'blue' || e.getAttribute('style') !== 'color: blue;') throw new Error(name + ': style forwarding');
        \\  e.setAttribute('style', 'opacity: 0.5');
        \\  if (style.opacity !== '0.5' || style.color !== '') throw new Error(name + ': attribute mutation');
        \\}
    );
}

test "SVG inline style has stable identity and reflects both mutation directions" {
    try helpers.onFreshThread(inlineStyles);
}

fn retainedStyle() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.svgStyle = (() => {
        \\  const owner = document.createElementNS('http://www.w3.org/2000/svg', 'use');
        \\  document.body.appendChild(owner);
        \\  const style = owner.style;
        \\  owner.remove();
        \\  globalThis.svgOwner = new WeakRef(owner);
        \\  return style;
        \\})();
    );
    try page.turn();
    try page.run(
        \\collectNow();
        \\svgStyle.color = 'red';
        \\const owner = svgOwner.deref();
        \\if (!owner) throw new Error('SVG style lost its owner');
        \\if (owner.style !== svgStyle) throw new Error('retained SVG style identity');
        \\if (owner.getAttribute('style') !== 'color: red;') throw new Error('retained SVG style mutation: ' + owner.getAttribute('style'));
    );
}

test "retaining an SVG inline style keeps its detached owner alive" {
    try helpers.onFreshThread(retainedStyle);
}

fn rectangles() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const root = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        \\const a = root.createSVGRect(), b = root.createSVGRect();
        \\if (!(a instanceof DOMRect) || a === b) throw new Error('createSVGRect object identity');
        \\for (const key of ['x', 'y', 'width', 'height', 'top', 'right', 'bottom', 'left'])
        \\  if (a[key] !== 0) throw new Error('createSVGRect initial ' + key);
        \\a.x = 3; a.y = 4; a.width = 5; a.height = 6;
        \\if (a.right !== 8 || a.bottom !== 10 || b.x !== 0) throw new Error('createSVGRect mutation');
        \\for (const method of ['checkIntersection', 'checkEnclosure']) {
        \\  let threw = false;
        \\  try { root[method](null, a); } catch (e) { if (!(e instanceof TypeError)) throw e; threw = true; }
        \\  if (!threw) throw new Error(method + ' accepted null');
        \\}
    );
}

test "createSVGRect returns fresh mutable zero rectangles and preserves null conversion errors" {
    try helpers.onFreshThread(rectangles);
}
