//! HTML form submission step 11: dialog results are optional, captured values.
const helpers = @import("edges_node_holders_helpers.zig");
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const html = @import("html");

fn captureAllocationTrial(allocator: std.mem.Allocator, button: *runtime.Instance, expected: []const u8) anyerror!void {
    if (comptime !@hasDecl(html.dialog, "submissionResult")) return error.DialogSubmissionResultNotImplemented;
    var result = try html.dialog.submissionResult(allocator, button);
    defer if (result.wasPassed()) result.value.deinit(allocator);
    try std.testing.expect(result.wasPassed());
    try std.testing.expectEqualStrings(expected, result.value.asSlice());
}

fn captureAllocationFailures() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<button id=submitter value=\"captured value\"></button><input id=image type=image>'");
    const document = page.browser.current_context.?.document_instance.?;
    const button = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("submitter"))).?;
    const image = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("image"))).?;
    try std.testing.checkAllAllocationFailures(std.testing.allocator, captureAllocationTrial, .{ button, "captured value" });
    try std.testing.checkAllAllocationFailures(std.testing.allocator, captureAllocationTrial, .{ image, "0,0" });
}

fn optionalValues() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\for (const tag of ['button', 'input']) {
        \\  for (const value of [null, '', 'accepted']) {
        \\    const dialog = document.body.appendChild(document.createElement('dialog'));
        \\    dialog.innerHTML = '<form method=dialog><' + tag + ' type=submit></' + tag + '></form>';
        \\    const form = dialog.firstElementChild;
        \\    const button = form.firstElementChild;
        \\    if (value !== null) button.setAttribute('value', value);
        \\    dialog.returnValue = 'preserved';
        \\    dialog.show();
        \\    form.requestSubmit(button);
        \\    if (dialog.open) throw new Error('submission left dialog open');
        \\    if (dialog.returnValue !== (value === null ? 'preserved' : value)) throw new Error('optional ' + tag + ' value');
        \\    dialog.remove();
        \\  }
        \\}
    );
}

fn imageAndMutation() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const dialog = document.body.appendChild(document.createElement('dialog'));
        \\dialog.innerHTML = '<form method=dialog><input type=image name=picture></form>';
        \\const form = dialog.firstElementChild;
        \\const image = form.firstElementChild;
        \\let entries;
        \\form.addEventListener('formdata', event => entries = event.formData, {once: true});
        \\dialog.show();
        \\image.click();
        \\if (dialog.open || dialog.returnValue !== '0,0') throw new Error('image result');
        \\if (dialog.returnValue !== entries.get('picture.x') + ',' + entries.get('picture.y')) throw new Error('image entry mismatch');
        \\image.remove();
        \\const button = form.appendChild(document.createElement('button'));
        \\button.name = 'result';
        \\button.value = 'before';
        \\form.addEventListener('formdata', event => {
        \\  event.formData.set('result', 'entry-only');
        \\  button.value = 'captured';
        \\}, {once: true});
        \\dialog.show();
        \\dialog.addEventListener('beforetoggle', () => button.value = 'replacement', {once: true});
        \\form.requestSubmit(button);
        \\if (dialog.open || dialog.returnValue !== 'captured') throw new Error('result capture around formdata/beforetoggle');
    );
}

fn cancellationAndTarget() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const outer = document.body.appendChild(document.createElement('dialog'));
        \\const inner = outer.appendChild(document.createElement('dialog'));
        \\inner.innerHTML = '<form method=dialog><button value=accepted>Submit</button></form>';
        \\const form = inner.firstElementChild;
        \\const button = form.firstElementChild;
        \\outer.show();
        \\inner.show();
        \\form.addEventListener('submit', event => event.preventDefault(), {once: true});
        \\form.requestSubmit(button);
        \\if (!inner.open || !outer.open) throw new Error('canceled submit closed dialog');
        \\form.requestSubmit(button);
        \\if (inner.open || !outer.open || inner.returnValue !== 'accepted') throw new Error('nearest dialog');
        \\inner.show();
        \\document.body.append(form);
        \\form.requestSubmit(button);
        \\if (!inner.open || !outer.open) throw new Error('unrelated dialog closed');
        \\inner.append(form);
        \\form.submit();
        \\if (inner.open || inner.returnValue !== '') throw new Error('submit without submitter must clear returnValue');
    );
}

fn eventSource() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\const dialog = document.body.appendChild(document.createElement('dialog'));
        \\dialog.innerHTML = '<form method=dialog><button value=done>Submit</button></form>';
        \\dialog.show();
    );
    try page.turn();
    try page.run(
        \\const order = [];
        \\const form = dialog.firstElementChild;
        \\form.addEventListener('submit', () => order.push('submit'));
        \\form.addEventListener('formdata', () => order.push('formdata'));
        \\dialog.addEventListener('beforetoggle', event => {
        \\  if (event.source !== null || event.cancelable) throw new Error('beforetoggle source/cancelable');
        \\  order.push('beforetoggle');
        \\});
        \\dialog.addEventListener('toggle', event => {
        \\  if (event.source !== null || event.oldState !== 'open' || event.newState !== 'closed') throw new Error('toggle source/states');
        \\  order.push('toggle');
        \\});
        \\dialog.addEventListener('close', () => order.push('close'));
        \\form.requestSubmit(form.firstElementChild);
        \\if (order.join() !== 'submit,formdata,beforetoggle') throw new Error('synchronous event order: ' + order);
    );
    try page.turn();
    try page.run("if (order.join() !== 'submit,formdata,beforetoggle,toggle,close') throw new Error('queued event order: ' + order)");
}

test "dialog form submission distinguishes absent and empty submitter values" {
    try helpers.onFreshThread(optionalValues);
}

test "dialog form image coordinates agree with entries and values survive dispatch mutation" {
    try helpers.onFreshThread(imageAndMutation);
}

test "dialog form cancellation and nearest ancestor selection" {
    try helpers.onFreshThread(cancellationAndTarget);
}

test "dialog form submission event sources are null and close is queued" {
    try helpers.onFreshThread(eventSource);
}

test "dialog submission result capture releases every allocation on failure" {
    try helpers.onFreshThread(captureAllocationFailures);
}

fn noSubmitterTrial(comptime operation: []const u8) !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\for (const modal of [false, true]) {
        \\  for (const seed of ['seed', undefined, '']) {
        \\    const dialog = document.body.appendChild(document.createElement('dialog'));
        \\    dialog.innerHTML = '<form method=dialog><button value=ignored>Submit</button></form>';
        \\    const form = dialog.firstElementChild;
        \\    dialog.returnValue = seed;
        \\    if (modal) dialog.showModal(); else dialog.show();
    ++ operation ++
        \\    if (dialog.open) throw new Error('no-submitter submission left the dialog open');
        \\    if (dialog.returnValue !== '') throw new Error('no-submitter submission preserved ' + JSON.stringify(dialog.returnValue));
        \\    dialog.remove();
        \\  }
        \\}
    );
}

fn submitWithoutSubmitter() !void {
    try noSubmitterTrial("form.submit();\n");
}

fn requestSubmitWithoutSubmitter() !void {
    try noSubmitterTrial("form.requestSubmit();\n");
}

fn requestSubmitNull() !void {
    try noSubmitterTrial("form.requestSubmit(null);\n");
}

test "dialog form.submit without a submitter clears returnValue" {
    try helpers.onFreshThread(submitWithoutSubmitter);
}

test "dialog requestSubmit without a submitter clears returnValue" {
    try helpers.onFreshThread(requestSubmitWithoutSubmitter);
}

test "dialog requestSubmit null clears returnValue" {
    try helpers.onFreshThread(requestSubmitNull);
}
