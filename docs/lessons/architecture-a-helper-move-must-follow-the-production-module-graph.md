# Architecture: A helper move must follow the production module graph

**Date**: 2026-10-13
**Lesson**: Moving an algorithm between modules requires checking the production build graph as well as the algorithm's source imports.

**Why**: Zig resolves named imports from the owning module's dependency table. An import visible elsewhere in build.zig, including a test graph, does not establish that dependency for the production module.

**What Happened**: Moving content-attribute reflection into dom also required its document-relative URL helper. Moving that helper from html avoided a dom-to-html dependency, but the production dom module did not import the URL parser. The first snapshot build failed at the unchanged helper's `@import("api_parser")`.

**Fix**: Keep the URL algorithm unchanged, export it from dom, and retain html's export as an alias for its existing callers. Give dom the existing URL parser module directly. Verify the production runner/snapshot graph and an allocator-checked test of document-relative parsing with UTF-8 and a legacy query encoding.

**Takeaway**: **Check the destination module's actual dependency table; a matching import name elsewhere in the build is not evidence that a move will compile.**
