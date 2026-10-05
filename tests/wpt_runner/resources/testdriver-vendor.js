// Crane's testdriver vendor file.
//
// WPT's extension point for an automation backend is /resources/testdriver-vendor.js,
// which upstream ships empty and every browser's harness replaces (wptrunner,
// Chromium's web_tests, WebKit's LayoutTests). Crane's WPT runner serves THIS file
// in its place, to the test document and to every frame and popup document the test
// loads (tests/wpt_runner/wpt_browser.zig, src/html/embedder_scripts.zig).
//
// It is wiring only. Each command is a native the runner defines on this realm before
// this file runs: tests/wpt_runner/test_driver.zig, the WebDriver remote end. The
// natives return promises that settle once the command's events have been dispatched.
//
// One deviation from upstream testdriver.js, because Crane has no layout: test_driver.click
// hit-tests the element with getClientRects() and elementsFromPoint() before it reaches
// test_driver_internal, and without boxes that test rejects every click. Here click goes
// straight to the native, which treats a connected element as in view and unobscured,
// and clicks the element itself (WebDriver's in-view centre point, with no coordinates).
(function() {
  "use strict";
  const internal = window.test_driver_internal;
  internal.in_automation = true;
  internal.click = __crane_test_driver_click;
  internal.send_keys = __crane_test_driver_send_keys;
  internal.action_sequence = __crane_test_driver_action_sequence;
  internal.minimize_window = __crane_test_driver_minimize_window;
  internal.set_window_rect = __crane_test_driver_set_window_rect;
  internal.get_window_rect = __crane_test_driver_get_window_rect;
  internal.get_all_cookies = __crane_test_driver_get_all_cookies;
  internal.get_named_cookie = __crane_test_driver_get_named_cookie;
  internal.delete_all_cookies = __crane_test_driver_delete_all_cookies;
  // A plain function, as upstream's is: tests call it with `new` too.
  window.test_driver.click = function(element) {
    return internal.click(element);
  };
})();
