//! Lane forms1 (C2): Web Animations 1 §6.6 "pseudo-element parsing" accepts
//! the form-control pseudo-elements Crane's selectors support, ::picker-icon
//! and ::checkmark (CSS Forms 1 §§4.1, 4.3), and their computed style takes
//! the effect. Chrome passes customizable-select/picker-icon-animation.html
//! and checkmark-animation.html; Safari accepts both and animates
//! ::checkmark.
const std = @import("std");
const Page = @import("edges_node_holders_helpers.zig").Page;
const onFreshThread = @import("edges_node_holders_helpers.zig").onFreshThread;

fn pickerIcon() !void {
    const p = try Page.open();
    defer p.close();
    try p.run(
        \\const eq = (a, e, what) => { if (a !== e) throw new Error(what + ': expected ' + e + ' got ' + a); };
        \\const style = document.createElement('style');
        \\style.textContent = 'select { appearance: base-select }';
        \\document.head.append(style);
        \\const select = document.createElement('select');
        \\select.innerHTML = '<option>one</option>';
        \\document.body.append(select);
        \\const animation = select.animate([{ color: 'rgb(0, 100, 200)' }, { color: 'rgb(200, 0, 100)' }], { pseudoElement: '::picker-icon', duration: 2, delay: -1 });
        \\eq(animation.effect.pseudoElement, '::picker-icon', 'effect pseudoElement');
        \\eq(getComputedStyle(select, '::picker-icon').color, 'rgb(100, 50, 150)', '::picker-icon animated color');
        \\eq(getComputedStyle(select).color, 'rgb(0, 0, 0)', 'the select itself is not animated');
        \\animation.cancel();
        \\eq(getComputedStyle(select, '::picker-icon').color, 'rgb(0, 0, 0)', '::picker-icon color after cancel');
    );
}

test "Element.animate() targets a select's ::picker-icon" {
    try onFreshThread(pickerIcon);
}

fn checkmark() !void {
    const p = try Page.open();
    defer p.close();
    try p.run(
        \\const eq = (a, e, what) => { if (a !== e) throw new Error(what + ': expected ' + e + ' got ' + a); };
        \\const style = document.createElement('style');
        \\style.textContent = 'select, ::picker(select) { appearance: base-select }';
        \\document.head.append(style);
        \\const select = document.createElement('select');
        \\select.innerHTML = '<option selected>one</option>';
        \\document.body.append(select);
        \\const option = select.options[0];
        \\const effect = new KeyframeEffect(option, [{ color: 'rgb(0, 100, 200)' }, { color: 'rgb(200, 0, 100)' }], { pseudoElement: '::checkmark', duration: 2, delay: -1 });
        \\eq(effect.pseudoElement, '::checkmark', 'KeyframeEffect pseudoElement');
        \\const animation = new Animation(effect, document.timeline);
        \\animation.play();
        \\eq(getComputedStyle(option, '::checkmark').color, 'rgb(100, 50, 150)', '::checkmark animated color');
        \\effect.pseudoElement = '::picker-icon';
        \\eq(effect.pseudoElement, '::picker-icon', 'the setter takes ::picker-icon');
        \\animation.cancel();
    );
}

test "a KeyframeEffect targets an option's ::checkmark" {
    try onFreshThread(checkmark);
}
