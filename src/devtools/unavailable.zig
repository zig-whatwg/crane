//! The `devtools` module of a build without CDP (`-Dcdp=false`): nothing of
//! the remote end is compiled. Its users - the console's
//! --remote-debugging-port, WebDriver's se:cdp - check `enabled` at compile
//! time and answer `unavailable_message`.

/// Whether this build has the Chrome DevTools Protocol remote end.
pub const enabled = false;

/// What a request for CDP answers in this build.
pub const unavailable_message = "this Crane was built without CDP support (-Dcdp=false)";
