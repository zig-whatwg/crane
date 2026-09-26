# Architecture: load and DOMContentLoaded were each fired twice

**Date**: 2026-09-22
**Lesson**: `navigation.fireLoad` dispatched `load` - which already runs
`window.onload` - and then called `window.onload(event)` again;
`Context.loadHTML` re-fired DOMContentLoaded after the parser had. Invisible
until `<body onload>` worked, when a handler registered its tests twice and the
file ended in ERROR.

**Takeaway**: **A handler that tolerates running twice hides a double fire.
When a newly working handler turns a file into ERROR, look for the second
caller.**
