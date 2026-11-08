//! Lane anim1 batch 5 (item 3): the CSS Typed OM transform family (CSS Typed
//! OM 1 4.4 CSSTransformValue objects, 5.8 reifying a <transform-list>, 6.6
//! their serialization). Chrome 157 and Safari 27.2 ship it (WPT
//! css/css-transforms/animation/transform-interpolation-computed-value.html
//! 82/82 in both, which reads computedStyleMap().get('transform')); Firefox
//! 159 ships no Typed OM.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

fn check(comptime source: []const u8, expected: []const u8) !void {
    const Run = struct {
        fn run(want: []const u8, failure: *?anyerror) void {
            exercise(want) catch |err| {
                failure.* = err;
            };
        }
        fn exercise(want: []const u8) !void {
            const page = try helpers.Page.open();
            defer page.close();
            const actual = try page.evaluate(source);
            defer std.testing.allocator.free(actual);
            try std.testing.expectEqualStrings(want, actual);
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{ expected, &failure });
    thread.join();
    if (failure) |err| return err;
}

test "anim1b5: 5.8 a computed <transform-list> reifies as a CSSTransformValue of components" {
    try check(
        \\const div = document.body.appendChild(document.createElement('div'));
        \\div.style.transform = 'translate(25px) rotateZ(60deg) scale(1.5) skewX(30deg) perspective(4px)';
        \\const value = div.computedStyleMap().get('transform');
        \\JSON.stringify([value instanceof CSSTransformValue, value.length, value.is2D,
        \\  value[0] instanceof CSSTranslate, value[1] instanceof CSSRotate, value[2] instanceof CSSScale,
        \\  value[3] instanceof CSSSkewX, value[4] instanceof CSSPerspective, value.toString()]);
    , "[true,5,false,true,true,true,true,true,\"translate(25px, 0px) rotate3d(0, 0, 1, 60deg) scale(1.5, 1.5) skewX(30deg) perspective(4px)\"]");
}

test "anim1b5: 6.6 component serializations by is2D, and the 2D-only setters" {
    try check(
        \\const t = new CSSTranslate(CSS.px(1), CSS.percent(2));
        \\const t3 = new CSSTranslate(CSS.px(1), CSS.px(2), CSS.px(3));
        \\const r = new CSSRotate(CSS.deg(45));
        \\const r3 = new CSSRotate(1, 0, 0, CSS.deg(90));
        \\const s = new CSSScale(2, 3);
        \\const sk = new CSSSkew(CSS.deg(10), CSS.deg(0));
        \\// perspective(none) reified: the binding cannot yet convert a string or
        \\// a CSSKeywordValue to CSSPerspectiveValue's nested CSSKeywordish arm.
        \\const holder = document.body.appendChild(document.createElement('div'));
        \\holder.style.transform = 'perspective(none)';
        \\const p = holder.computedStyleMap().get('transform')[0];
        \\sk.is2D = false; p.is2D = true; t.is2D = false;
        \\JSON.stringify([String(t), String(t3), String(r), String(r3), String(s), String(new CSSScale(2, 2)),
        \\  String(sk), sk.is2D, String(p), p.is2D, t3.is2D, String(new CSSSkewY(CSS.rad(1)))]);
    , "[\"translate3d(1px, 2%, 0px)\",\"translate3d(1px, 2px, 3px)\",\"rotate(45deg)\",\"rotate3d(1, 0, 0, 90deg)\",\"scale(2, 3)\",\"scale(2, 2)\",\"skew(10deg)\",true,\"perspective(none)\",false,false,\"skewY(1rad)\"]");
}

test "anim1b5: 4.4 constructors reject what their slots cannot hold" {
    try check(
        \\const errors = [];
        \\for (const make of [
        \\  () => new CSSTransformValue([]),
        \\  () => new CSSTranslate(CSS.deg(1), CSS.px(1)),
        \\  () => new CSSTranslate(CSS.px(1), CSS.px(1), CSS.percent(1)),
        \\  () => new CSSRotate(CSS.px(1)),
        \\  () => new CSSScale(CSS.px(1), 1),
        \\  () => new CSSSkew(CSS.deg(1), CSS.px(1)),
        \\  () => new CSSPerspective('auto'),
        \\  () => new CSSPerspective(CSS.deg(1)),
        \\]) { try { make(); errors.push('none'); } catch (e) { errors.push(e.name); } }
        \\errors.join(' ');
    , "TypeError TypeError TypeError TypeError TypeError TypeError TypeError TypeError");
}

test "anim1b5: 4.4 toMatrix() multiplies the components' matrices; relative lengths throw" {
    try check(
        \\const value = new CSSTransformValue([new CSSTranslate(CSS.px(10), CSS.px(20)), new CSSScale(2, 3)]);
        \\const m = value.toMatrix();
        \\let threw = 'none';
        \\try { new CSSTranslate(CSS.em(1), CSS.px(0)).toMatrix(); } catch (e) { threw = e.name; }
        \\JSON.stringify([m.is2D, m.a, m.d, m.e, m.f, new CSSPerspective(CSS.px(100)).toMatrix().m34, threw,
        \\  new CSSMatrixComponent(new DOMMatrixReadOnly([1, 2, 3, 4, 5, 6])).toString()]);
    , "[true,2,3,10,20,-0.01,\"TypeError\",\"matrix(1, 2, 3, 4, 5, 6)\"]");
}

test "anim1b5: a CSSTransformValue sets transform, and its indexed setter appends at length" {
    try check(
        \\const div = document.body.appendChild(document.createElement('div'));
        \\const value = new CSSTransformValue([new CSSTranslate(CSS.px(5), CSS.px(0))]);
        \\value[1] = new CSSRotate(CSS.deg(10));
        \\let range = 'none';
        \\try { value[5] = new CSSRotate(CSS.deg(1)); } catch (e) { range = e.name; }
        \\div.attributeStyleMap.set('transform', value);
        \\JSON.stringify([value.length, range, div.style.transform, [...value].length]);
    , "[2,\"RangeError\",\"translate(5px, 0px) rotate(10deg)\",2]");
}
