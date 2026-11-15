# Testing: A port's "never reached" branch is reached as soon as its input set grows

**Date**: 2026-11-14
**Lesson**: When a port of a test spec refuses a branch because "no app of ours reaches it", the claim holds only for today's apps; widen the app list and the refusal turns into failures that look like the apps'.

**Why**: TodoMVC's app spec keys its behaviour by per-app tables (noLocalStorageSpyCheck, noAppStartCheck, frameworkFolders). Crane's in-page port was written for four apps, all in the table that skips the localStorage.setItem spy check, so the port threw "not ported" in that branch with a comment saying it was never reached.

**What Happened**: Lane fw1 b5 widened the port to every app todomvc.com lists (43 served apps). 25 of them are not in noLocalStorageSpyCheck, so every test that calls checkItemSaved failed - in Chrome too, which made the failures look like the apps' own. A probe of two apps in headless Chrome showed javascript-es5 failing 26 of 29 tests with the port's own "not ported" message. In the same widening, the spec's frameworkFolders table turned out to name a folder other than the one todomvc.com links for five apps (javascript-es5/dist, jquery/dist, backbone/dist, web-components/dist, emberjs/todomvc/dist).

**Fix**:
1. Port the branch instead of refusing it: the spy now counts Storage.prototype.setItem calls on the app's window from the moment the app has loaded (the in-page equivalent of Cypress's onBeforeLoad that exists), and each check reads the calls since the previous one with Cypress's retry timeout. The difference is written in excluded/todomvc-port.txt and on the report.
2. Open the build the site links (`&folder=`), not the spec table's folder, when the report measures the site's apps.
3. Run the widened set in Chrome first: a failure every app shares in Chrome is the port's.

**Takeaway**: **A port's "never reached" is a statement about its current inputs: port the branch, or fail it loudly and re-check the claim whenever the input set grows - and run the widened set in a reference browser before reading any failure as the app's or the engine's.**
