//! Lane wc1: which SubtleCrypto methods settle their promise inside the call.
//!
//! WebCrypto 14.3 settles every method's promise from a task on the crypto
//! task source. Two of Chrome, Firefox and Safari do the quick methods'
//! work inside the call and return a promise that is already settled:
//! importKey, exportKey, generateKey unless RSA, and wrapKey / unwrapKey by
//! AES-KW; the rest settle from a task in two of the three. The table and its
//! evidence are at src/webcrypto/operations.zig `Request.settles`; the same
//! rows, with every algorithm, are tests/wpt/crane/wc1-subtle-settles-in-the-
//! call.https.html.
//!
//! What it decides: a page that imports keys from a microtask of its last
//! script has them when the load event fires - the load event fires at the
//! end of the parse (lane nav2 batch 12), ahead of every task. Before, every
//! method settled two tasks after its call, and WPT's
//! WebCryptoAPI/derive_bits_keys/derive_key_and_encrypt.https.any.js, which
//! defines its tests from importKey()'s reaction, was complete at load with
//! its setup test alone (generation 225: 6 subtests -> 2).
//!
//! These rows use HMAC and SHA-256 only: they need no cryptography library,
//! so they run in every build of the tests.

const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;

/// A secure context: crypto.subtle is exposed.
const page_url = "https://web-platform.test:8443/wc1.html";

/// Run the event loop until the page's `answer` is no longer "pending".
fn awaitAnswer(browser: *Browser) ![]u8 {
    const page = browser.current_context orelse return error.NoPage;
    var turns: usize = 0;
    while (turns < 200) : (turns += 1) {
        const result = try page.evaluateScriptToString("String(globalThis.answer)", testing.allocator);
        if (!std.mem.eql(u8, result, "pending")) return result;
        testing.allocator.free(result);
        _ = try browser.runEventLoopBlocking(20);
    }
    return error.NoAnswer;
}

test "keys imported from a microtask of a parser-inserted script are there when load fires" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(
        \\<!doctype html><body><script>
        \\globalThis.answer = "pending";
        \\let imported = false;
        \\Promise.resolve().then(() => {
        \\  const hmac = { name: "HMAC", hash: "SHA-256" };
        \\  Promise.all([
        \\    crypto.subtle.importKey("raw", new Uint8Array(32), hmac, true, ["sign"]),
        \\    crypto.subtle.importKey("raw", new Uint8Array(32), hmac, true, ["verify"]),
        \\  ]).then(() => { imported = true; }, (e) => { answer = "import failed: " + e; });
        \\});
        \\addEventListener("load", () => {
        \\  if (answer === "pending") answer = imported ? "imported before load" : "load before the keys";
        \\});
        \\</script>
    , .{ .base_url = page_url });
    const answer = try awaitAnswer(browser);
    defer testing.allocator.free(answer);
    try testing.expectEqualStrings("imported before load", answer);
}

test "importKey, exportKey and generateKey settle in the call; digest, sign and verify from a task" {
    const browser = try Browser.init(testing.allocator, .{});
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body>", .{ .base_url = page_url });
    _ = try browser.runEventLoopBlocking(20);
    // A reaction registered on the returned promise runs ahead of a microtask
    // queued after it only if the promise was settled when the method
    // returned.
    try page.runScript(
        \\globalThis.answer = "pending";
        \\(async () => {
        \\  const subtle = crypto.subtle, rows = [];
        \\  const hmac = { name: "HMAC", hash: "SHA-256" };
        \\  function settles(name, make) {
        \\    return new Promise((resolve) => {
        \\      const order = [];
        \\      let outcome;
        \\      const promise = make();
        \\      promise.then(() => { outcome = "ok"; order.push("promise"); }, (e) => { outcome = e.name; order.push("promise"); });
        \\      Promise.resolve().then(() => order.push("microtask"));
        \\      const done = () => { rows.push(name + "=" + outcome + (order[0] === "promise" ? "@call" : "@task")); resolve(); };
        \\      promise.then(done, done);
        \\    });
        \\  }
        \\  const key = await subtle.generateKey(hmac, true, ["sign", "verify"]);
        \\  const mac = await subtle.sign("HMAC", key, new Uint8Array(16));
        \\  await settles("importKey", () => subtle.importKey("raw", new Uint8Array(32), hmac, true, ["sign"]));
        \\  await settles("importKey-no-usage", () => subtle.importKey("raw", new Uint8Array(32), hmac, true, []));
        \\  await settles("exportKey", () => subtle.exportKey("raw", key));
        \\  await settles("exportKey-jwk", () => subtle.exportKey("jwk", key));
        \\  await settles("generateKey", () => subtle.generateKey(hmac, true, ["sign"]));
        \\  await settles("digest", () => subtle.digest("SHA-256", new Uint8Array(1)));
        \\  await settles("sign", () => subtle.sign("HMAC", key, new Uint8Array(16)));
        \\  await settles("verify", () => subtle.verify("HMAC", key, mac, new Uint8Array(16)));
        \\  answer = rows.join(" ");
        \\})().catch((e) => { answer = "failed: " + e; });
    );
    const answer = try awaitAnswer(browser);
    defer testing.allocator.free(answer);
    try testing.expectEqualStrings(
        "importKey=ok@call importKey-no-usage=SyntaxError@call exportKey=ok@call exportKey-jwk=ok@call " ++
            "generateKey=ok@call digest=ok@task sign=ok@task verify=ok@task",
        answer,
    );
}
