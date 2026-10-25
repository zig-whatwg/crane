# Testing: A subtest missing from all three browsers on wpt.fyi was changed upstream

**Date**: 2026-10-25
**Lesson**: Before fixing a lost or failing subtest of the pinned tests/wpt, read the file's upstream history: wpt.fyi runs upstream master, and the subtest may no longer exist there.

**Why**: Crane's tests/wpt is pinned until the current worklist is closed out. Upstream keeps editing tests in the meantime, sometimes removing assertions it decided the specs do not require. A pinned subtest can therefore demand something upstream has already dropped. Fixing it costs work, and the fix may change behaviour the spec leaves open, while the subtest itself disappears at the next tests/wpt update.

**What Happened**: Lane vars1's A/B lost four names: `position` and `abspos` in css/css-variables/variable-first-letter.html and variable-first-line.html. They expect `position: var(--p)` with `--p: absolute` to read `static` on the pseudo-element. Each was passing on BASE only because BASE did not substitute var() at all. The integrator ruled to implement CSS Pseudo 4's property lists for the two pseudo-elements. While gathering browser evidence, the cached wpt.fyi results for those two files showed only four subtests per browser, and `position` and `abspos` were absent from Chrome, Firefox and Safari alike. Upstream WPT a26422aab3 (2026-10-19, "Remove optional position checks from pseudo-element variable tests") had deleted them. Its reasoning: CSS Pseudo lets UAs apply properties beyond the required lists, and it does not require an inapplicable property to compute to its initial value. The filter still went in, because css/css-pseudo/first-letter-allowed-properties.html and first-line-allowed-properties.html still assert it and Chrome and Firefox pass every "should not be applied" case there. The four names were recorded as ones the next tests/wpt update removes.

**Fix**:
1. For each lost or targeted subtest, fetch the browsers' per-test results from the wpt.fyi run (`https://storage.googleapis.com/wptd/<sha>/<browser-run>/<test path>`).
2. If a name is missing from all three browsers, the test changed upstream. Diff the pinned file against `https://raw.githubusercontent.com/web-platform-tests/wpt/master/<path>` and read the commit (`api.github.com/repos/web-platform-tests/wpt/commits?path=<path>`).
3. Decide on the evidence that still stands: the spec, the browsers, and the other upstream tests that still assert the behaviour. Do not decide on the pinned subtest alone. Put the upstream commit in the report so the loss's disposition can cite it.

**Takeaway**: **wpt.fyi reports upstream master, not Crane's pin: a subtest that no browser reports was removed or renamed upstream, so read the file's history before treating it as a requirement.**
