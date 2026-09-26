# Testing: A subtest that passes because an earlier step throws the expected exception

**Date**: 2026-09-22
**Lesson**: `new Request("")` threw TypeError from its URL parse, so every
`assert_throws_js(TypeError, () => new Request("", badInit))` passed without
ever reading `badInit`. Giving the constructor its API base URL (7204b9e6b)
turned ten `request-error` subtests red; implementing the steps they were
really testing took the file from 34 to 40 of 44.

**Takeaway**: **When fixing one step turns `assert_throws_*` subtests red, they
were testing a later step that does not exist yet - the drop is a map of it.**
