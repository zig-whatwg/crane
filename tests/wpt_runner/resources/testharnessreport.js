// crane-wpt-runner-report
//
// Crane's WPT runner's testharnessreport.js. `wpt serve` serves it at
// /resources/testharnessreport.js in place of the stock file (a config alias the
// runner writes: tests/wpt_runner/wpt_server.zig), and the page fetches it over HTTP
// like any other script - exactly as wptrunner serves its own report
// (tools/wptrunner/wptrunner/environment.py, get_routes: the
// "/resources/testharnessreport.js" route over wptrunner/testharnessreport.js). It
// used to be handed to the parser by an engine hook only the runner installed, which
// no browser has (the user, 2026-11-09: "We should never special case something").
// The first line is the marker the runner checks before it trusts a server it adopts.
//
// What it does is what wptrunner's report does: harness settings, then a completion
// callback that hands the results to the runner, which reads them from the page
// (window.__wpt_results / __wpt_complete) as wptrunner's executor reads its message
// queue through WebDriver.
(function() {
  if (typeof add_completion_callback !== "function") return;

  // No results table and no per-assertion bookkeeping: nothing reads either in a
  // headless run, and the table alone cost 2.16 ms per subtest (wptrunner's report
  // passes `output` too: 0 unless pausing after a test).
  try { setup({ output: false }); } catch (e) { console.log("[wpt runner] could not disable harness output: " + e); }

  // A `long` file's budget is the runner's (60 s): the harness keeps no timer of its
  // own, and the runner calls timeout() at its ceiling, so step_timeout waits stay
  // real time (tests/wpt_runner/config.zig, Timeout.explicitTimeout). Read the way
  // testharness.js reads it (WindowTestEnvironment.test_timeout): the document's
  // <meta name="timeout" content="long">.
  var metas = document.getElementsByTagName("meta");
  for (var i = 0; i < metas.length; i++) {
    if (metas[i].name === "timeout" && metas[i].content === "long") {
      try { setup({ explicit_timeout: true }); } catch (e) { console.log("[wpt runner] could not set an explicit timeout: " + e); }
      break;
    }
  }

  add_completion_callback(function(tests, harness_status) {
    try {
      window.__wpt_results = {
        status: harness_status ? harness_status.status : 0,
        message: harness_status ? (harness_status.message || null) : null,
        tests: (tests || []).map(function(t) {
          return { name: t.name, status: t.status, message: t.message || null };
        })
      };
    } catch (e) {
      window.__wpt_results = { status: 1, message: e.toString(), tests: [] };
    }
    window.__wpt_complete = true;
  });
  window.__wpt_results = null;
  window.__wpt_complete = false;
})();
