# Testing: A backend that plays exposes every step the element skipped

**Date**: 2026-10-09
**Lesson**: When media starts to load, files that passed because nothing ever loaded lose their passes, and files that failed fast start to wait - on autoplay, progress, cue processing or lazy loading - and time out.

**Why**: With no decoder for the runner's video type, every getVideoURI resource errored at once: `video.readyState` stayed HAVE_NOTHING (so loading=lazy assertions held), `activeCues` stayed empty, and an `error` listener failed the async test in milliseconds. Once WebM played, the same files reached the steps Crane had never implemented.

**What Happened**: The webm lane's first A/B (3f92e2672d vs afa3c4a9ee) gained 56 files and lost 18: ten event_* files went OK 2/4 -> TIMEOUT 2/4 waiting for autoplay's play event or for a progress event that a fast body never got (Crane fired progress only from its 350ms timer, not "once the entire media resource has been fetched"); track-active-cues needed cue processing in time marches on; seven video-loading-lazy files had passed only because nothing loaded (Firefox and Safari fail them too).

**Fix**: Implement what the newly reached files show missing in the same lane (autoplay and the end-of-fetch progress, ed4daae165), and record the rest with the three browsers' numbers as follow-ups. Count a pass that existed only because nothing loaded as an honest failure, not a regression.

**Takeaway**: **Before turning on playback, list what the media tests do next - play, progress, cues, lazy loading - and budget for it: an element that loads is exposure, like an API that starts to exist.**
