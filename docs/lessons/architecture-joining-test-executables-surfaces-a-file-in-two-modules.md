# Architecture: Joining test executables surfaces a file in two modules

**Date**: 2026-11-03
**Lesson**: A module root that imports another module's root as a file is a conflict waiting for a referencer: separate test executables hid `src/webidl/root.zig`'s `@import("codegen/root.zig")` against the `codegen` module, and the first one-binary build failed on it.

**Why**: Zig puts a file in one module per compile. A file import inside a declaration nobody reaches is never resolved, so a compile that holds both modules builds as long as nothing analyses that declaration. tests/codegen imports the `codegen` module and never touches `webidl.codegen`; the suites that reach `webidl.codegen` never import `codegen`. One executable holding all of them has both, and a referencer: `error: file exists in modules 'codegen' and 'webidl'` (`file is the root of module 'codegen'`, `file is imported here by the root of module 'webidl'`). The same latency as [A re-export does not mean the code is compiled](architecture-a-re-export-does-not-mean-the-code-is-compiled.md), in the other direction: here the unreached code is what kept the build green.

**What Happened**: Lane onebin1's -Dtest-binaries=one prototype joined every tests/<dir>/ whose import names agreed. The dom-only and css-only checks passed; the first full build (chat2, 2026-11-03) failed at the one executable's compile.

**Fix**: build.zig's `finishOneBinary` reads the root file of every module in the one executable's import table and keeps out each member that imports a module another root imports as a file (`tools/test_suites.zig` `pathFrom`, `importsAsFile`, pinned with std.testing). It excludes exactly tests/codegen, which keeps an executable of its own. A transitive file import (a root importing a file that imports another module's root) is not detected: it fails the compile loudly, with the two module names, and the rule then needs widening.

**Takeaway**: **Before joining compiles, find the module roots that import other module roots as files: lazy analysis keeps that conflict silent only until one compile holds both modules and a reference.**
