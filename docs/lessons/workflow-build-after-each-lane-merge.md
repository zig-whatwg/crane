# Workflow: Build after each lane merge - two clean merges can make a broken tree

**Date**: 2026-09-26
**Lesson**: Two lanes merged back to back, each textually clean and each green on its own branch, left main unbuildable - and would have hidden a silent regression behind the compile error.

**What Happened**: the networking lane's increment 3 changed `AsyncFetch.terminate()` to take a failure and made `AsyncFetch.start` stream (its `done` fires at the headers, the body still a pipe). The navigation lane's increment 1, written against the old API, called `terminate()` and read `body.getBytes()` in `done`. The integrator merged networking, then navigation, without a build in between: `HTMLIFrameElement.zig:681: member function expected 1 argument(s), found 0`. Behind it, had it compiled, every http(s) frame navigation would have committed an empty document. The gate-and-sweep job launched right after would have swept a stale `zig-out` binary. The networking lane caught it on its next `git merge main`.

**Fix**: after merging each lane, build (`zig build wpt-runner`) before merging the next; gate the merged tree before any sweep. A changed shared API keeps its old name with the old meaning and adds the new behaviour under a new name (`start` collects, `startStreaming` streams; `terminate()` / `terminateWith(failure)`), so a caller written against the old contract stays correct.

**Takeaway**: **"Each branch is green" says nothing about their merge. Build between merges, and never let a sweep script fall back to a binary it did not just build.**
