# Testing: Past the harness timeout, a file's status is a race; name each build

**Date**: 2026-09-22
**Lesson**: A file that blocks past the harness's 10 s (a 26 s synchronous fetch) reads OK in some runs and TIMEOUT in others - compare its subtests, not its status. And crash reports identify the build only by executable name (`procPath` is redacted), so copy each build to a unique name before sweeping with it.
