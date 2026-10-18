# Spec Compliance: Browser failures can be implementation lag

**Date**: 2026-10-17
**Lesson**: Check the spec change, implementer positions and engine bugs before treating a shared browser failure as a deliberate alternative to a newer algorithm.

**Why**: WPT reports observed behavior. A failed assertion or timeout does not establish why an engine differs from the standard. Crane's newer-spec rule needs evidence of intent before substituting browser behavior.

**What Happened**: In row 58, `consume-user-activation/window-open-multi-global.html` failed in aligned Chrome 155 and Firefox 158 runs because the entry global's activation stayed active; Safari 27 timed out. HTML [PR 10547](https://github.com/whatwg/html/pull/10547), merged in November 2024, added activation consumption with Mozilla and Chromium support and no recorded opposition. Its discussion explicitly chose the entry global and identified Chromium's wrong-global bug, 379674022. Gecko's [1931035](https://bugzilla.mozilla.org/show_bug.cgi?id=1931035) remained an open implementation bug. These results showed lag against an agreed algorithm.

**Fix**: Follow the navigable chooser's input. Window open passes the entry global's document; hyperlinks and forms pass the element's document. Consume activation only in the branch creating a new top-level traversable. In Crane's shared helper, that Window is the `window` argument; `current_window` carries `open()`'s receiver for existing sandbox logic. Check the full multi-global WPT as well as ordinary creation and named-window reuse, and cite the spec history beside the implementation.

**Takeaway**: **Use spec history and engine bugs to distinguish implementation lag from an intentional standards disagreement.**
