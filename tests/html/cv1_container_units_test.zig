//! Conditional 5 §7, row127 Q94: container-type support and per-axis
//! eligibility ship together; eligible sizes stay unresolved without layout.
const helpers = @import("edges_node_holders_helpers.zig");

test "container units use the viewport only without an eligible axis" {
    try helpers.onFreshThread(realElement);
}

fn realElement() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<div id="plain"></div><section id="parent"><div id="child"></div></section>';
        \\const parent = document.getElementById('parent');
        \\for (const id of ['plain', 'child']) {
        \\  const target = document.getElementById(id);
        \\  for (const [cq, sv] of [['cqw','svw'],['cqh','svh'],['cqi','svi'],['cqb','svb'],['cqmin','svmin'],['cqmax','svmax']]) {
        \\    target.style.left = '2' + sv;
        \\    const expected = getComputedStyle(target).left;
        \\    target.style.left = '2' + cq;
        \\    if (target.style.left !== '2' + cq) throw Error('container unit dropped: ' + cq);
        \\    if (getComputedStyle(target).left !== expected) throw Error(id + ' ' + cq + ' fallback');
        \\  }
        \\}
        \\const child = document.getElementById('child');
        \\function retained(unit) {
        \\  child.style.left = '2' + unit;
        \\  if (getComputedStyle(child).left !== '2' + unit) throw Error('eligible ' + unit + ' was resolved');
        \\}
        \\function fallback(unit, viewport) {
        \\  child.style.left = '2' + viewport;
        \\  const expected = getComputedStyle(child).left;
        \\  child.style.left = '2' + unit;
        \\  if (getComputedStyle(child).left !== expected) throw Error('ineligible ' + unit + ' did not fall back');
        \\}
        \\parent.style.setProperty('container-type', 'size');
        \\if (parent.style.getPropertyValue('container-type') !== 'size') throw Error('supported container-type was dropped');
        \\for (const unit of ['cqw','cqh','cqi','cqb','cqmin','cqmax']) retained(unit);
        \\parent.style.cssText = 'container-type:inline-size; writing-mode:vertical-rl';
        \\child.style.writingMode = 'horizontal-tb';
        \\retained('cqh'); retained('cqb'); fallback('cqw', 'svw'); fallback('cqi', 'svi');
        \\const outer = document.createElement('section');
        \\parent.before(outer); outer.appendChild(parent); outer.style.containerType = 'size';
        \\retained('cqw'); retained('cqh');
        \\outer.style.containerType = 'normal';
        \\for (const style of ['container-type:scroll-state', 'container-type:size;display:contents', 'container-type:size;display:none']) {
        \\  parent.style.cssText = style;
        \\  for (const [cq, sv] of [['cqw','svw'],['cqh','svh'],['cqi','svi'],['cqb','svb'],['cqmin','svmin'],['cqmax','svmax']]) fallback(cq, sv);
        \\}
        \\parent.style.cssText = 'container-type:size';
        \\const sheet = document.createElement('style'); sheet.textContent = '#child { tab-size:7 }'; document.head.appendChild(sheet);
        \\child.style.tabSize = 'sign(2cqw - 10px)';
        \\if (getComputedStyle(child).tabSize !== '7') throw Error('unavailable scalar did not skip to the lower candidate');
    );
}
