# Testing: A count cannot see a tree's shape

**Date**: 2026-10-08
**Lesson**: The tree builder had no "in body" steps for li, dd, dt, button, option, optgroup, ruby, hr, image, xmp, iframe and the void elements, so `<li>x<li>y` nested - and the parse benchmark, which counted `li` elements, passed either way.

**Why**: `querySelectorAll('li').length` is 2 for `<li>x</li><li>y</li>` and for `<li>x<li>y</li></li>`. A test that asserts how many nodes a parse made says nothing about where it put them. The WPT html5lib files did see it (html5lib_write and its siblings failed ~610 subtests each in every sweep), but a file that is OK with most subtests passing never blocks the 0.1 gate, so nobody looked.

**What Happened**: The parser holds lane added a DOMParser parity test and its expected serialization showed `<ul><li>x<li>y</li></li></ul>`. A scratch Crane test on the frozen runners showed the same nesting in the live parser, at the lane's base and at the pre-row-10 target: the steps were never written. Implemented from the spec text (two commits), they moved html5lib_url, html5lib_write and html5lib_write_single by +93 subtests each and the parser directories by +291, with no file losing a subtest.

**Fix**: tests/html/parser_implied_end_tags_test.zig parses each case through document.write into a frame AND through DOMParser and compares exact body serialization with the spec's tree.

**Takeaway**: **Assert a parse by its serialization, through every parser path, never by counting nodes; and read the large failure counts in OK files, not only the blocking ones.**
