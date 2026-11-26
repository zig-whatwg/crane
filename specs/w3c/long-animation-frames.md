## 1. Introduction

As the page is loading and while the user is interacting with the page
afterwards, both the application and browser queue various events that
are then executed by the browser \-- e.g. user agent schedules input
events based on user's activity, the application schedules callbacks for
requestAnimationFrame and other callbacks, etc. Once in the queue, the
browser dequeues these events one-by-one and executes them.

However, some tasks can take a long time (multiple frames) and if/when
that happens, the UI thread may become blocked and block all other tasks
as well. To the user, this is commonly visible as a \"locked up\" page
where the browser is unable to respond to user input; this is a major
source of bad user experience on the web today:

Delayed \"time to Interactive\":

: while the page is loading, or even completely visually rendered,
 long tasks often tie up the main thread and prevent the user from
 interacting with the page. Poorly designed third-party content is
 frequently the culprit.

High/variable input latency:

: critical user-interaction events (e.g. tap, click, scroll, wheel,
 etc.) are queued behind long tasks which yields janky and
 unpredictable user experience.

High/variable event handling latency:

: like input, processing event callbacks (e.g. onload events, etc.)
 delay application updates.

Janky animations and scrolling:

: some animation and scrolling interactions require coordination
 between compositor and main threads; if a long task is blocking the
 main thread it can affect responsiveness of animations and
 scrolling.

Some applications (and
[RUM](https://en.wikipedia.org/wiki/Real_user_monitoring) vendors) are
already attempting to identify and track cases where \"long tasks\"
happen. For example, one known pattern is to install a \~short periodic
timer and inspect the elapsed time between the successive expirations:
if the elapsed time is greater than the timer period, then there is high
likelihood that one or more long tasks have delayed execution of the
event loop. This approach mostly works but has several bad performance
implications: by polling to detect long tasks, the application prevents
quiescence and long idle blocks (see requestIdleCallback); it's bad for
battery life; there is no way to know what is causing the delay (e.g.
first party or third party code).

The
[RAIL](https://developers.google.com/web/fundamentals/performance/rail)
performance model suggests that applications should respond to user
input in less than 100ms (for touch move and scrolling, the threshold is
16ms). The goal of this API is to surface notifications about tasks that
may prevent the application from hitting these targets. This API
surfaces tasks that take 50ms or more. A website without these tasks
should respond to user input in under 100ms: it will take less than 50ms
to finish the task that is being executed when the user input is
received and less than 50ms to execute the task to react to such user
input.

### 1.1. Usage Example

```
const observer = new PerformanceObserver(function(list) {
 for (const entry of list.getEntries()) {
 // Process long task notifications:
 // report back for analytics and monitoring
 // ...
 }
});

// Register observer for previous and future long animation frame notifications.
// After this, long periods where the main thread is busy will result in queueing
// and receiving "long-animation-frame" entries in the observer.
observer.observe({type: "long-animation-frame", buffered: true});
```

### 1.2. Long Animation Frames vs. Long Tasks

While both [long
tasks](https://w3c.github.io/longtasks/#long-task) and long animation frames measure congestion and jank,
long animation frames provide information that has a better correlation
with how users perceive this type of congestion. That's because long
animation frames measure a sequence that begins when the main thread is
idle, and end when the frame either renders or the user agents decides
there is nothing to render.

The
[task](https://html.spec.whatwg.org/multipage/webappapis.html#concept-task) term is somewhat of an implementation detail, and the
long animation frame addition attempts to remedy that by introducing a
more user-centric metric of the same phenomenon of main thread
congestion/jank.

Because long animation frames are guaranteed to have a maximum of one
rendering phase, we can also use them to expose additional information
about the rendering phase itself, such as
[`renderStart`](#dom-performancelonganimationframetiming-renderstart) and
[`styleAndLayoutStart`](#dom-performancelonganimationframetiming-styleandlayoutstart).

## 2. Long Animation Frame Timing

A [long animation frame] refers to any of the following occurrences
whose duration exceeds 50ms:

- A
 [task](https://html.spec.whatwg.org/multipage/webappapis.html#concept-task), after which updating the rendering is not necessary.

- A
 [task](https://html.spec.whatwg.org/multipage/webappapis.html#concept-task) after which updating the rendering is necessary, up
 until rendering is updated.

Long Animation Frame timing involves the following new interfaces:

### 2.1. [`PerformanceLongAnimationFrameTiming` interface]
```
[Exposed=Window]
interface PerformanceLongAnimationFrameTiming : PerformanceEntry {
 /* Overloading PerformanceEntry */
 readonly attribute DOMHighResTimeStamp startTime;
 readonly attribute DOMHighResTimeStamp duration;
 readonly attribute DOMString name;
 readonly attribute DOMString entryType;

 readonly attribute DOMHighResTimeStamp renderStart;
 readonly attribute DOMHighResTimeStamp styleAndLayoutStart;
 readonly attribute DOMHighResTimeStamp styleDuration;
 readonly attribute DOMHighResTimeStamp layoutDuration;
 readonly attribute DOMHighResTimeStamp blockingDuration;
 readonly attribute DOMHighResTimeStamp firstUIEventTimestamp;
 [SameObject] readonly attribute FrozenArray<PerformanceScriptTiming> scripts;
 [Default] object toJSON();
};

PerformanceLongAnimationFrameTiming includes PaintTimingMixin;
```

A
[`PerformanceLongAnimationFrameTiming`](#performancelonganimationframetiming) has a [frame timing
info](#frame-timing-info)
[timing info].

The
[`entryType`](#dom-performancelonganimationframetiming-entrytype) attribute's getter step is to return
`"long-animation-frame"`.

The
[`name`](#dom-performancelonganimationframetiming-name) attribute's getter step is to return
`"long-animation-frame"`.

The
[`startTime`](#dom-performancelonganimationframetiming-starttime) attribute's getter step is to return the [relative high
resolution
time](https://w3c.github.io/hr-time/#dfn-relative-high-resolution-time) given
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performancelonganimationframetiming-timing-info)'s [start
time](#frame-timing-info-start-time) and
[this](https://webidl.spec.whatwg.org/#this)'s [relevant global
object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).

The
[`duration`](#dom-performancelonganimationframetiming-duration) attribute's getter steps are:

1. If [this](https://webidl.spec.whatwg.org/#this)'s
 [`paintTime`](https://w3c.github.io/paint-timing/#dom-painttimingmixin-painttime) is not 0, then return the
 [duration](https://w3c.github.io/hr-time/#dfn-duration) between
 [this](https://webidl.spec.whatwg.org/#this)'s
 [`startTime`](https://w3c.github.io/performance-timeline/#dom-performanceentry-starttime) and
 [this](https://webidl.spec.whatwg.org/#this)'s
 [`paintTime`](https://w3c.github.io/paint-timing/#dom-painttimingmixin-painttime).

2. Return the
 [duration](https://w3c.github.io/hr-time/#dfn-duration) between
 [this](https://webidl.spec.whatwg.org/#this)'s
 [`startTime`](https://w3c.github.io/performance-timeline/#dom-performanceentry-starttime) and the [relative high resolution
 time](https://w3c.github.io/hr-time/#dfn-relative-high-resolution-time) given
 [this](https://webidl.spec.whatwg.org/#this)'s [timing
 info](#performancelonganimationframetiming-timing-info)'s [end
 time](#frame-timing-info-end-time) and
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).

The
[`renderStart`](#dom-performancelonganimationframetiming-renderstart) attribute's getter step is to return 0 if
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performancelonganimationframetiming-timing-info)'s [update the rendering start
time](#frame-timing-info-update-the-rendering-start-time) is 0; otherwise the [relative high resolution
time](https://w3c.github.io/hr-time/#dfn-relative-high-resolution-time) given
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performancelonganimationframetiming-timing-info)'s [update the rendering start
time](#frame-timing-info-update-the-rendering-start-time) and
[this](https://webidl.spec.whatwg.org/#this)'s [relevant global
object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).

The
[`styleAndLayoutStart`](#dom-performancelonganimationframetiming-styleandlayoutstart) attribute's getter step is to return 0 if
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performancelonganimationframetiming-timing-info)'s [style and layout start
time](#frame-timing-info-style-and-layout-start-time) is 0; otherwise the [relative high resolution
time](https://w3c.github.io/hr-time/#dfn-relative-high-resolution-time) given
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performancelonganimationframetiming-timing-info)'s [style and layout start
time](#frame-timing-info-style-and-layout-start-time) and
[this](https://webidl.spec.whatwg.org/#this)'s [relevant global
object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).

The
[`styleDuration`](#dom-performancelonganimationframetiming-styleduration) attribute's getter step is to return
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performancelonganimationframetiming-timing-info)'s [style
duration](#frame-timing-info-style-duration).

The
[`layoutDuration`](#dom-performancelonganimationframetiming-layoutduration) attribute's getter step is to return
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performancelonganimationframetiming-timing-info)'s [layout
duration](#frame-timing-info-layout-duration).

For every
[`PerformanceLongAnimationFrameTiming`](#performancelonganimationframetiming) `entry`, the sum of `entry`'s
[`styleDuration`](#dom-performancelonganimationframetiming-styleduration) and
[`layoutDuration`](#dom-performancelonganimationframetiming-layoutduration) MUST be less than or equal to the
[duration](https://w3c.github.io/hr-time/#dfn-duration) between `entry`'s
[`styleAndLayoutStart`](#dom-performancelonganimationframetiming-styleandlayoutstart) and `entry`'s
[`startTime`](https://w3c.github.io/performance-timeline/#dom-performanceentry-starttime) + `entry`'s
[`duration`](https://w3c.github.io/performance-timeline/#dom-performanceentry-duration). If `entry`'s [timing
info](#performancelonganimationframetiming-timing-info)'s [update the rendering start
time](#frame-timing-info-update-the-rendering-start-time) is 0, i.e. the frame did not include a rendering
update, then `entry`'s
[`styleDuration`](#dom-performancelonganimationframetiming-styleduration) and
[`layoutDuration`](#dom-performancelonganimationframetiming-layoutduration) MUST both be 0.

[`styleDuration`](#dom-performancelonganimationframetiming-styleduration) and
[`layoutDuration`](#dom-performancelonganimationframetiming-layoutduration) represent the time spent recalculating styles and
updating layout, respectively, as part of the rendering update. Their
sum can be less than the duration between
[`styleAndLayoutStart`](#dom-performancelonganimationframetiming-styleandlayoutstart) and
[`paintTime`](https://w3c.github.io/paint-timing/#dom-painttimingmixin-painttime), as that period can also include other work that is not
included in these durations, such as running
[`ResizeObserver`](https://drafts.csswg.org/resize-observer-1/#resizeobserver) callbacks or updating intersection observations. Style
and layout performed synchronously by scripts are not included, and are
reported via
[`forcedStyleDuration`](#dom-performancescripttiming-forcedstyleduration) and
[`forcedLayoutDuration`](#dom-performancescripttiming-forcedlayoutduration) instead.

The
[`firstUIEventTimestamp`](#dom-performancelonganimationframetiming-firstuieventtimestamp) attribute's getter steps are:

1. Let `timestamp` be
 [this](https://webidl.spec.whatwg.org/#this)'s [timing
 info](#performancelonganimationframetiming-timing-info)'s [first ui event
 timestamp](#frame-timing-info-first-ui-event-timestamp).

2. If `timestamp` is null, then return 0.

3. Return the [relative high resolution coarse
 time](https://w3c.github.io/hr-time/#dfn-relative-high-resolution-coarse-time) given `timestamp` and
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).

The
[`blockingDuration`](#dom-performancelonganimationframetiming-blockingduration) attribute's getter steps are:

1. Let `sortedTaskDurations` be
 [this](https://webidl.spec.whatwg.org/#this)'s [timing
 info](#performancelonganimationframetiming-timing-info)'s [task
 durations](#frame-timing-info-task-durations), [sorted in descending
 order](https://infra.spec.whatwg.org/#list-sort-in-descending-order).

2. If [this](https://webidl.spec.whatwg.org/#this)'s [timing
 info](#performancelonganimationframetiming-timing-info)'s [update the rendering start
 time](#frame-timing-info-update-the-rendering-start-time) is not zero, then:

 1. Let `renderEndTime` be
 [this](https://webidl.spec.whatwg.org/#this)'s
 [`paintTime`](https://w3c.github.io/paint-timing/#dom-painttimingmixin-painttime) if
 [this](https://webidl.spec.whatwg.org/#this)'s
 [`paintTime`](https://w3c.github.io/paint-timing/#dom-painttimingmixin-painttime) is not 0; otherwise the [relative high
 resolution
 time](https://w3c.github.io/hr-time/#dfn-relative-high-resolution-time) given
 [this](https://webidl.spec.whatwg.org/#this)'s [timing
 info](#performancelonganimationframetiming-timing-info)'s [end
 time](#frame-timing-info-end-time) and
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).

 2. Let `renderDuration` be the
 [duration](https://w3c.github.io/hr-time/#dfn-duration) between
 [this](https://webidl.spec.whatwg.org/#this)'s
 [`renderStart`](#dom-performancelonganimationframetiming-renderstart) and `renderEndTime`.

 3. If `sortedTaskDurations` [is
 empty](https://infra.spec.whatwg.org/#list-is-empty), then
 [append](https://infra.spec.whatwg.org/#list-append) `renderDuration` to
 `sortedTaskDurations`.

 4. Otherwise, increment `sortedTaskDurations`\[0\] by
 `renderDuration`.

 This makes it so that the longest task
 duration + render duration would be considered blocking if their
 total duration is \>50ms.

3. Let `totalBlockingDuration` be 0.

4. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `duration` in
 `sortedTaskDurations`, if `duration` is
 greater than 50 then increment `totalBlockingDuration` by
 `duration` - 50.

5. Return `totalBlockingDuration`.

The
[`scripts`](#dom-performancelonganimationframetiming-scripts) attribute's getter steps are:

1. Let `scripts` be a
 [list](https://infra.spec.whatwg.org/#list) « ».

2. Let `entryWindow` be `this`'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).

3. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `scriptInfo` in
 [this](https://webidl.spec.whatwg.org/#this)'s [frame timing
 info](#frame-timing-info)'s
 [scripts](#frame-timing-info-scripts):

 1. Let `scriptWindow` be `scriptInfo`'s
 [window](#script-timing-info-window).

 2. Let `scriptEntry` be a new
 [`PerformanceScriptTiming`](#performancescripttiming) in
 [this](https://webidl.spec.whatwg.org/#this)'s [relevant
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm), whose [timing
 info](#performancescripttiming-timing-info) is `scriptInfo` and whose [window
 attribution](#performancescripttiming-window-attribution) is the value corresponding to the first
 matching statement:

 `scriptWindow` is undefined or `scriptWindow`'s [associated Document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) is not [fully active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active)

 : [`other`](#dom-scriptwindowattribution-other)

 `scriptWindow` is `entryWindow`

 : [`self`](#dom-scriptwindowattribution-self)

 `entryWindow`'s associated [`Document`](https://dom.spec.whatwg.org/#document)'s [node navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable)'s [ancestor navigables](https://html.spec.whatwg.org/multipage/document-sequences.html#ancestor-navigables) [contains](https://infra.spec.whatwg.org/#list-contain) `scriptWindow`'s associated [`Document`](https://dom.spec.whatwg.org/#document)'s [node navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable)

 : [`ancestor`](#dom-scriptwindowattribution-ancestor)

 `scriptWindow`'s associated [`Document`](https://dom.spec.whatwg.org/#document)'s [node navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable)'s [ancestor navigables](https://html.spec.whatwg.org/multipage/document-sequences.html#ancestor-navigables) [contains](https://infra.spec.whatwg.org/#list-contain) `entryWindow`'s associated [`Document`](https://dom.spec.whatwg.org/#document)'s [node navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable)

 : [`descendant`](#dom-scriptwindowattribution-descendant)

 `entryWindow`'s associated [`Document`](https://dom.spec.whatwg.org/#document)'s [node navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable)'s [top-level traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top) is `scriptWindow`'s associated [`Document`](https://dom.spec.whatwg.org/#document)'s [node navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable)'s [top-level traversable](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-top)

 : [`same-page`](#dom-scriptwindowattribution-same-page)

 Otherwise

 : [`other`](#dom-scriptwindowattribution-other).

 3. [Append](https://infra.spec.whatwg.org/#list-append) `scriptEntry` to
 `scripts`.

4. Return `scripts`.

### 2.2. [`PerformanceScriptTiming` interface]
```
enum ScriptInvokerType {
 "classic-script",
 "module-script",
 "event-listener",
 "user-callback",
 "resolve-promise",
 "reject-promise"
};

enum ScriptWindowAttribution {
 "self", "descendant", "ancestor", "same-page", "other"
};

[Exposed=Window]
interface PerformanceScriptTiming : PerformanceEntry {
 /* Overloading PerformanceEntry */
 readonly attribute DOMHighResTimeStamp startTime;
 readonly attribute DOMHighResTimeStamp duration;
 readonly attribute DOMString name;
 readonly attribute DOMString entryType;

 readonly attribute ScriptInvokerType invokerType;
 readonly attribute DOMString invoker;
 readonly attribute DOMHighResTimeStamp executionStart;
 readonly attribute DOMString sourceURL;
 readonly attribute DOMString sourceFunctionName;
 readonly attribute long long sourceCharPosition;
 readonly attribute long long sourceLine;
 readonly attribute long long sourceColumn;
 readonly attribute DOMHighResTimeStamp pauseDuration;
 readonly attribute DOMHighResTimeStamp forcedStyleAndLayoutDuration;
 readonly attribute DOMHighResTimeStamp forcedStyleDuration;
 readonly attribute DOMHighResTimeStamp forcedLayoutDuration;
 readonly attribute Window? window;
 readonly attribute ScriptWindowAttribution windowAttribution;
 [Default] object toJSON();
};
```

A
[`PerformanceScriptTiming`](#performancescripttiming) has an associated [script timing
info](#script-timing-info)
[timing info].

A
[`PerformanceScriptTiming`](#performancescripttiming) has an associated
[`ScriptWindowAttribution`](#enumdef-scriptwindowattribution) [window
attribution].

The
[`entryType`](#dom-performancescripttiming-entrytype) attribute's getter step is to return
`"script"`.

The
[`name`](#dom-performancescripttiming-name) attribute's getter step is to return
`"script"`.

The
[`invokerType`](#dom-performancescripttiming-invokertype) attribute's getter step is to return
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performancescripttiming-timing-info)'s [invoker
type](#script-timing-info-invoker-type).

The
[`invoker`](#dom-performancescripttiming-invoker) attribute's getter steps are:

1. Switch on `this`'s
 [`invokerType`](#dom-performancescripttiming-invokertype):

 \"\`classic-script\`\"\
 \"\`module-script\`\"

 : Return `this`'s [timing
 info](#performancescripttiming-timing-info)'s [source
 url](#script-timing-info-source-url).

 \"\`event-listener\`\"

 : 1. Let `targetName` be `this`'s [timing
 info](#performancescripttiming-timing-info)'s [invoker
 name](#script-timing-info-invoker-name).

 2. If `this`'s [timing
 info](#performancescripttiming-timing-info)'s [event target element
 id](#script-timing-info-event-target-element-id) is not the empty string, then: Set
 `targetName` to the
 [concatenation](https://infra.spec.whatwg.org/#string-concatenate) of « `targetName`, \"#\",
 `this`'s [timing
 info](#performancescripttiming-timing-info)'s [event target element
 id](#script-timing-info-event-target-element-id) ».

 3. Otherwise, if
 [this](https://webidl.spec.whatwg.org/#this)'s [timing
 info](#performancescripttiming-timing-info)'s [event target element src
 attribute](#script-timing-info-event-target-element-src-attribute) is not the empty string, then: Set
 `targetName` to the
 [concatenation](https://infra.spec.whatwg.org/#string-concatenate) of « `targetName`,
 \"\[src=\\\"\",
 [this](https://webidl.spec.whatwg.org/#this)'s [timing
 info](#performancescripttiming-timing-info)'s [event target element src
 attribute](#script-timing-info-event-target-element-src-attribute), \"\\\"\]\" ».

 4. Return the
 [concatenation](https://infra.spec.whatwg.org/#string-concatenate) of « `targetName`, \".on\",
 [this](https://webidl.spec.whatwg.org/#this)'s [timing
 info](#performancescripttiming-timing-info)'s [event
 type](#script-timing-info-event-type) ».

 (#issue-5d051999) this feels a bit custom, need to
 discuss name generation.

 \"\`user-callback\`\"

 : Return `this`'s [timing
 info](#performancescripttiming-timing-info)'s [invoker
 name](#script-timing-info-invoker-name).

 \"\`resolve-promise\`\"\
 \"\`reject-promise\`\"

 : 1. Let `thenOrCatch` be \"\`then\`\" if
 [this](https://webidl.spec.whatwg.org/#this)'s
 [`invokerType`](#dom-performancescripttiming-invokertype) is \"\`resolve-promise\`\"; otherwise
 \"\`catch\`\".

 2. Return the
 [concatenation](https://infra.spec.whatwg.org/#string-concatenate) of «
 [this](https://webidl.spec.whatwg.org/#this)'s [timing
 info](#performancescripttiming-timing-info)'s [invoker
 name](#script-timing-info-invoker-name), \".\", `thenOrCatch` ».

The
[`startTime`](#dom-performancescripttiming-starttime) attribute's getter step is to return the [relative high
resolution
time](https://w3c.github.io/hr-time/#dfn-relative-high-resolution-time) given
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performancescripttiming-timing-info)'s [start
time](#script-timing-info-start-time) and
[this](https://webidl.spec.whatwg.org/#this)'s [relevant global
object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).

The
[`duration`](#dom-performancescripttiming-duration) attribute's getter step is to return the
[duration](https://w3c.github.io/hr-time/#dfn-duration) between
[this](https://webidl.spec.whatwg.org/#this)'s
[`startTime`](#dom-performancescripttiming-starttime) and the [relative high resolution
time](https://w3c.github.io/hr-time/#dfn-relative-high-resolution-time) given
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performancescripttiming-timing-info)'s [end
time](#script-timing-info-end-time) and
[this](https://webidl.spec.whatwg.org/#this)'s [relevant global
object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).

The
[`executionStart`](#dom-performancescripttiming-executionstart) attribute's getter step is to return 0 if
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performancescripttiming-timing-info)'s [execution start
time](#script-timing-info-execution-start-time) is 0; Otherwise the [relative high resolution
time](https://w3c.github.io/hr-time/#dfn-relative-high-resolution-time) given
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performancescripttiming-timing-info)'s [execution start
time](#script-timing-info-execution-start-time) and
[this](https://webidl.spec.whatwg.org/#this)'s [relevant global
object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).

The
[`forcedStyleAndLayoutDuration`](#dom-performancescripttiming-forcedstyleandlayoutduration) attribute's getter step is to return the sum of
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performancescripttiming-timing-info)'s [forced style
duration](#script-timing-info-forced-style-duration) and [forced layout
duration](#script-timing-info-forced-layout-duration).

The
[`forcedStyleDuration`](#dom-performancescripttiming-forcedstyleduration) attribute's getter step is to return
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performancescripttiming-timing-info)'s [forced style
duration](#script-timing-info-forced-style-duration).

The
[`forcedLayoutDuration`](#dom-performancescripttiming-forcedlayoutduration) attribute's getter step is to return
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performancescripttiming-timing-info)'s [forced layout
duration](#script-timing-info-forced-layout-duration).

[`forcedStyleDuration`](#dom-performancescripttiming-forcedstyleduration) and
[`forcedLayoutDuration`](#dom-performancescripttiming-forcedlayoutduration) represent the time spent recalculating styles and
updating layout, respectively, synchronously while the script was
running, e.g. when it called
[`getComputedStyle()`](https://drafts.csswg.org/cssom-1/#dom-window-getcomputedstyle) or
[`getBoundingClientRect()`](https://drafts.csswg.org/cssom-view-1/#dom-element-getboundingclientrect). See [§ 3.2.3 Style and Layout
Monitoring](#style-and-layout-monitoring).

The
[`pauseDuration`](#dom-performancescripttiming-pauseduration) attribute's getter step is to return
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performancescripttiming-timing-info)'s [pause
duration](#script-timing-info-pause-duration).

The
[`sourceURL`](#dom-performancescripttiming-sourceurl) attribute's getter step is to return
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performancescripttiming-timing-info)'s [source
url](#script-timing-info-source-url). The
[`sourceFunctionName`](#dom-performancescripttiming-sourcefunctionname) attribute's getter step is to return
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performancescripttiming-timing-info)'s [source function
name](#script-timing-info-source-function-name). The
[`sourceCharPosition`](#dom-performancescripttiming-sourcecharposition) attribute's getter step is to return
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performancescripttiming-timing-info)'s [source character
position](#script-timing-info-source-character-position). The
[`sourceLine`](#dom-performancescripttiming-sourceline) attribute's getter step is to return
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performancescripttiming-timing-info)'s [source line
number](#script-timing-info-source-line-number). The
[`sourceColumn`](#dom-performancescripttiming-sourcecolumn) attribute's getter step is to return
[this](https://webidl.spec.whatwg.org/#this)'s [timing
info](#performancescripttiming-timing-info)'s [source column
number](#script-timing-info-source-column-number).

The
[`window`](#dom-performancescripttiming-window) attribute's getter steps are:

1. Let `window` be the result of calling
 [deref](https://tc39.es/ecma262/multipage/managing-memory.html#sec-weakrefderef) on
 [this](https://webidl.spec.whatwg.org/#this)'s [timing
 info](#performancescripttiming-timing-info)'s
 [window](#script-timing-info-window).

2. If `window` is undefined or `window`'s
 [associated
 Document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window) is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active), then return null; otherwise return
 `window`.

The
[`windowAttribution`](#dom-performancescripttiming-windowattribution) attribute's getter step is to return
[this](https://webidl.spec.whatwg.org/#this)'s [window
attribution](#performancescripttiming-window-attribution).

## 3. Processing model

 A user agent implementing the Long Animation Frame API
would need to include `"long-animation-frame"` in
[`supportedEntryTypes`](https://w3c.github.io/performance-timeline/#supportedentrytypes-attribute) for
[`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window) contexts, respectively.

### 3.1. Frame Timing Info

[frame timing info] is a
[struct](https://infra.spec.whatwg.org/#struct) used as a bookkeeping detail by the long animation
frame algorithms. It has the following
[items](https://infra.spec.whatwg.org/#struct-item):

[start time]\
[current task start time]\
[update the rendering start time]\
[style and layout start time]\
[end time]

: A
 [`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#idl-def-domhighrestimestamp), initially 0. Note: these timestamps are
 [unsafe](https://w3c.github.io/hr-time/#monotonic-clock-unsafe-current-time), and should be
 [coarsened](https://w3c.github.io/hr-time/#dfn-coarsen-time) when exposed via an API.

[first ui event timestamp]

: Null or a
 [coarsened](https://w3c.github.io/hr-time/#dfn-coarsen-time)
 [moment](https://w3c.github.io/hr-time/#dfn-moment) on the [monotonic
 clock](https://w3c.github.io/hr-time/#dfn-monotonic-clock), initially null.

[style duration]

: A
 [`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#idl-def-domhighrestimestamp) representing a number of milliseconds, initially 0.

[layout duration]

: A
 [`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#idl-def-domhighrestimestamp) representing a number of milliseconds, initially 0.

[style and layout stack]

: A [stack](https://infra.spec.whatwg.org/#stack) of \"\`style\`\", \"\`layout\`\", and
 \"\`script\`\" strings, initially empty. It represents the style
 recalculations, layouts, and scripts that are in progress, with the
 innermost one at the top.

[style and layout stack change time]

: A
 [`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#idl-def-domhighrestimestamp), initially 0, representing the
 [coarsened](https://w3c.github.io/hr-time/#dfn-coarsen-time) time at which the [style and layout
 stack](#frame-timing-info-style-and-layout-stack) was last modified.

[style and layout periods]

: A [list](https://infra.spec.whatwg.org/#list) of [style and layout
 periods](#frame-timing-info-style-and-layout-periods), initially empty. It holds the style recalculations
 and layouts that were performed while no script was running.

[cross-origin isolated capability]

: A boolean, initially false, used to
 [coarsen](https://w3c.github.io/hr-time/#dfn-coarsen-time) the times from which style and layout durations are
 computed.

[task durations]

: A [list](https://infra.spec.whatwg.org/#list) of
 [`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#idl-def-domhighrestimestamp), initially empty.

[scripts]

: A [list](https://infra.spec.whatwg.org/#list) of [script timing
 info](#script-timing-info), initially empty.

[pending script]

: Null or a [script timing
 info](#script-timing-info), initially null.

[script initiated]

: A boolean, initially false.

[script timing info] is a
[struct](https://infra.spec.whatwg.org/#struct). It has the following
[items](https://infra.spec.whatwg.org/#struct-item):

[invoker type]

: A
 [`ScriptInvokerType`](#enumdef-scriptinvokertype).

[start time]\
[end time]\
[execution start time]

: An unsafe
 [`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#idl-def-domhighrestimestamp), initially 0.

[pause duration]\
[forced style duration]\
[forced layout duration]

: A
 [`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#idl-def-domhighrestimestamp) representing a number of milliseconds, initially 0.

[invoker name]\
[source url]\
[source function name]\
[event type]\
[event target element id]\
[event target element src attribute]

: A string, initially the empty string.

[source character position]

: A number, initially -1.

[source line number]

: A number, initially -1.

[source column number]

: A number, initially -1.

[window]

: A
 [`WeakRef`](https://tc39.es/ecma262/multipage/managing-memory.html#sec-weak-ref-objects) to a
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window).

A [style and layout period] is a
[struct](https://infra.spec.whatwg.org/#struct). It has the following
[items](https://infra.spec.whatwg.org/#struct-item):

[type]

: \"\`style\`\" or \"\`layout\`\".

[start time]\
[end time]

: A
 [coarsened](https://w3c.github.io/hr-time/#dfn-coarsen-time)
 [`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#idl-def-domhighrestimestamp).

A
[`Document`](https://dom.spec.whatwg.org/#document) has a null or [frame timing
info](#frame-timing-info)
[current frame timing info], initially null.

A [classic
script](https://html.spec.whatwg.org/multipage/webappapis.html#classic-script) has a
[URL](https://url.spec.whatwg.org/#concept-url)-or-null [original source
URL], initially null.

A
[script](https://html.spec.whatwg.org/multipage/webappapis.html#concept-script) `script`'s [exposed source
URL] is `script`'s [original source
URL](#classic-script-original-source-url) if `script` is a [classic
script](https://html.spec.whatwg.org/multipage/webappapis.html#classic-script) whose [original source
URL](#classic-script-original-source-url) is not null; otherwise `script`'s [base
URL](https://html.spec.whatwg.org/multipage/webappapis.html#concept-script-base-url).

 For an external classic script, the [original source
URL](#classic-script-original-source-url) is the URL that was requested (the \`script\` element's
\`src\`, before any redirects), whereas the [base
URL](https://html.spec.whatwg.org/multipage/webappapis.html#concept-script-base-url) is the URL of the response (after redirects). For
inline classic scripts, the [original source
URL](#classic-script-original-source-url) is null and the [base
URL](https://html.spec.whatwg.org/multipage/webappapis.html#concept-script-base-url) is the document's base URL. Exposing the original
source URL avoids revealing where a cross-origin script was redirected
to, matching what is already observable from the \`script\` element
itself.

### 3.2. Report Long Animation Frames

#### 3.2.1. Long Animation Frame Monitoring

To get the [nearest same-origin root] for a
[`Document`](https://dom.spec.whatwg.org/#document) `document`:

1. Let `ancestors` be the [ancestor
 navigables](https://html.spec.whatwg.org/multipage/document-sequences.html#ancestor-navigables) of `document`.

2. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `ancestorNavigable` in
 `ancestors`: If `ancestorNavigable`'s [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document)'s
 [origin](https://dom.spec.whatwg.org/#concept-document-origin) is [same
 origin](https://html.spec.whatwg.org/multipage/browsers.html#same-origin) with `document`'s
 [origin](https://dom.spec.whatwg.org/#concept-document-origin), and `ancestorNavigable`'s [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document)'s [relevant
 agent](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-agent) is `document`'s [relevant
 agent](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-agent), then return `ancestorNavigable`'s
 [active
 document](https://html.spec.whatwg.org/multipage/document-sequences.html#nav-document).

3. Return `document`.

The [relevant frame timing info] for a
[`Document`](https://dom.spec.whatwg.org/#document) `document` is its [nearest same-origin
root](#nearest-same-origin-root)'s [current frame timing
info](#current-frame-timing-info).

To [start recording task time if
needed] given an [environment settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) `settingsObject`:

 this is called from the [fire an
event](https://dom.spec.whatwg.org/#concept-event-fire) algorithm and the [create script entry
point](#create-script-entry-point) algorithm. It starts recording frame timing info for
the duration of the [event
firing](https://dom.spec.whatwg.org/#concept-event-fire) or
[script](#create-script-entry-point), as if it was a task. This accounts for script and
event durations that are not associated with tasks, which would
otherwise require an [implied
document](https://html.spec.whatwg.org/multipage/#implied-document).

1. If `settingsObject`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global) is not a
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window), then return false.

2. Let `document` be `settingsObject`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global)'s [associated
 Document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

3. If `document`'s [relevant frame timing
 info](#relevant-frame-timing-info) is non-null, then return false.

4. [Record task start
 time](#record-task-start-time) given the [unsafe shared current
 time](https://w3c.github.io/hr-time/#dfn-unsafe-shared-current-time) and `document`.

5. Return true if `document`'s [relevant frame timing
 info](#relevant-frame-timing-info) is non-null; otherwise false.

To [record task start time] given a
[`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#idl-def-domhighrestimestamp) `unsafeTaskStartTime`, and a
[`Document`](https://dom.spec.whatwg.org/#document) `document`:

1. If `document` is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active) or `document`'s [visibility
 state](https://html.spec.whatwg.org/multipage/interaction.html#visibility-state) is \"\`hidden\`\", then return.

2. Let `root` be `document`'s [nearest
 same-origin
 root](#nearest-same-origin-root).

3. If `root` is not [fully
 active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active) or `root`'s [visibility
 state](https://html.spec.whatwg.org/multipage/interaction.html#visibility-state) is \"\`hidden\`\", then return.

4. If `root`'s [current frame timing
 info](#current-frame-timing-info) is null, then set `root`'s [current
 frame timing
 info](#current-frame-timing-info) to a new [frame timing
 info](#frame-timing-info) whose [start
 time](#frame-timing-info-start-time) is `unsafeTaskStartTime`, and whose
 [cross-origin isolated
 capability](#frame-timing-info-cross-origin-isolated-capability) is `root`'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object)'s [cross-origin isolated
 capability](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-cross-origin-isolated-capability).

5. Set `root`'s [current frame timing
 info](#current-frame-timing-info)'s [current task start
 time](#frame-timing-info-current-task-start-time) to `unsafeTaskStartTime`.

Whenever a
[`Document`](https://dom.spec.whatwg.org/#document) `document`'s [visibility
state](https://html.spec.whatwg.org/multipage/interaction.html#visibility-state) becomes \"\`hidden\`\" or `document` ceases
to be [fully
active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active), set `document`'s [current frame timing
info](#current-frame-timing-info) to null.

To [record task end time] given a
[`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#idl-def-domhighrestimestamp) `unsafeTaskEndTime`, and a
[`Document`](https://dom.spec.whatwg.org/#document) `document`:

1. Let `timingInfo` be `document`'s [relevant
 frame timing
 info](#relevant-frame-timing-info).

2. If `timingInfo` is null, then return.

 This can occur if the browser becomes hidden during
 the sequence.

3. Let `global` be `document`'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).

4. Let `safeTaskEndTime` be the [relative high resolution
 time](https://w3c.github.io/hr-time/#dfn-relative-high-resolution-time) given `unsafeTaskEndTime` and
 `global`.

5. Let `safeTaskStartTime` be the [relative high resolution
 time](https://w3c.github.io/hr-time/#dfn-relative-high-resolution-time) given `timingInfo`'s [current task start
 time](#frame-timing-info-current-task-start-time) and `global`.

6. [Append](https://infra.spec.whatwg.org/#list-append) the
 [duration](https://w3c.github.io/hr-time/#dfn-duration) between `safeTaskStartTime` and
 `safeTaskEndTime` to `timingInfo`'s [task
 durations](#frame-timing-info-task-durations).

7. If the user agent believes that updating the rendering of
 `document`'s [node
 navigable](https://html.spec.whatwg.org/multipage/document-sequences.html#node-navigable) would have no visible effect, then:

 1. Set `document`'s [nearest same-origin
 root](#nearest-same-origin-root)'s [current frame timing
 info](#current-frame-timing-info) to null.

 2. Set `timingInfo`'s [end
 time](#frame-timing-info-end-time) to `unsafeTaskEndTime`.

 3. Let `frameDuration` be the
 [duration](https://w3c.github.io/hr-time/#dfn-duration) between the [relative high resolution
 time](https://w3c.github.io/hr-time/#dfn-relative-high-resolution-time) given `timingInfo`'s [start
 time](#frame-timing-info-start-time) and `global`, and
 `safeTaskEndTime`.

 4. If `frameDuration` is equal or greater than 50
 milliseconds, then [queue a long animation frame
 entry](#queue-a-long-animation-frame-entry) given `document`,
 `timingInfo`, and a new [paint timing
 info](https://w3c.github.io/paint-timing/#paint-timing-info).

 even though there was no actual visual update, we
 mark a [long animation
 frame](#long-animation-frame) here because it would be blocking in a scenario
 where it coincided with an unrelated visual update.

To [record rendering time] given a
[`Document`](https://dom.spec.whatwg.org/#document) `document`, and a
[`DOMHighResTimeStamp`](https://w3c.github.io/hr-time/#idl-def-domhighrestimestamp) `unsafeStyleAndLayoutStart`:

1. Let `root` be `document`'s [nearest
 same-origin
 root](#nearest-same-origin-root).

2. Let `timingInfo` be `root`'s [current frame
 timing
 info](#current-frame-timing-info).

3. If `timingInfo` is null, then return.

 This can occur if the browser becomes hidden during
 the sequence.

4. [Assert](https://infra.spec.whatwg.org/#assert): `timingInfo`'s [style and layout
 stack](#frame-timing-info-style-and-layout-stack) [is
 empty](https://infra.spec.whatwg.org/#list-is-empty).

 This means that no style recalculation, layout, or
 script is in progress.

5. Let `global` be `root`'s [relevant global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-global).

6. Let `frameDuration` be the
 [duration](https://w3c.github.io/hr-time/#dfn-duration) between the [relative high resolution
 time](https://w3c.github.io/hr-time/#dfn-relative-high-resolution-time) given `timingInfo`'s [start
 time](#frame-timing-info-start-time) and `global`, and the [current high
 resolution
 time](https://w3c.github.io/hr-time/#dfn-current-high-resolution-time) given `global`.

7. If `frameDuration` is less than 50 milliseconds, then set
 `root`'s [current frame timing
 info](#current-frame-timing-info) to null and return.

8. Set `timingInfo`'s [update the rendering start
 time](#frame-timing-info-update-the-rendering-start-time) to `timingInfo`'s [current task start
 time](#frame-timing-info-current-task-start-time).

9. Set `timingInfo`'s [style and layout start
 time](#frame-timing-info-style-and-layout-start-time) to `unsafeStyleAndLayoutStart`.

10. Let `styleAndLayoutStart` be the result of
 [coarsening](https://w3c.github.io/hr-time/#dfn-coarsen-time) `unsafeStyleAndLayoutStart` given
 `timingInfo`'s [cross-origin isolated
 capability](#frame-timing-info-cross-origin-isolated-capability).

11. [For
 each](https://infra.spec.whatwg.org/#list-iterate) `period` of `timingInfo`'s
 [style and layout
 periods](#frame-timing-info-style-and-layout-periods) whose [start
 time](#style-and-layout-period-start-time) is greater than or equal to
 `styleAndLayoutStart`:

 1. Let `duration` be the
 [duration](https://w3c.github.io/hr-time/#dfn-duration) between `period`'s [start
 time](#style-and-layout-period-start-time) and `period`'s [end
 time](#style-and-layout-period-end-time).

 2. If `period`'s
 [type](#style-and-layout-period-type) is \"\`style\`\", then increment
 `timingInfo`'s [style
 duration](#frame-timing-info-style-duration) by the milliseconds value of
 `duration`.

 3. Otherwise, increment `timingInfo`'s [layout
 duration](#frame-timing-info-layout-duration) by the milliseconds value of
 `duration`.

 Style recalculation and layout performed while no
 script was running, before the rendering update recalculates styles
 and updates layout, e.g. for hit testing, are not counted.

12. [Empty](https://infra.spec.whatwg.org/#list-empty) `timingInfo`'s [style and layout
 periods](#frame-timing-info-style-and-layout-periods).

13. If `root`'s [browsing
 context](https://html.spec.whatwg.org/multipage/document-sequences.html#concept-document-bc) is not [paint-timing
 eligible](https://w3c.github.io/paint-timing/#paint-timing-eligible), then:

 1. Set `root`'s [current frame timing
 info](#current-frame-timing-info) to null.

 2. Set `timingInfo`'s [end
 time](#frame-timing-info-end-time) to the [unsafe shared current
 time](https://w3c.github.io/hr-time/#dfn-unsafe-shared-current-time).

 3. [Queue a long animation frame
 entry](#queue-a-long-animation-frame-entry) given `root`,
 `timingInfo`, and a new [paint timing
 info](https://w3c.github.io/paint-timing/#paint-timing-info).

To [queue a long animation frame
entry] given a
[`Document`](https://dom.spec.whatwg.org/#document) `document`, a [frame timing
info](#frame-timing-info)
`timingInfo`, and a [paint timing
info](https://w3c.github.io/paint-timing/#paint-timing-info) `paintTimingInfo`:

1. [Assert](https://infra.spec.whatwg.org/#assert): `timingInfo`'s [style and layout
 stack](#frame-timing-info-style-and-layout-stack) [is
 empty](https://infra.spec.whatwg.org/#list-is-empty).

2. [Queue](https://w3c.github.io/performance-timeline/#dfn-queue-a-performanceentry) a new
 [`PerformanceLongAnimationFrameTiming`](#performancelonganimationframetiming) in `document`'s [relevant
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm), whose [timing
 info](#performancelonganimationframetiming-timing-info) is `timingInfo` and whose [paint timing
 info](https://w3c.github.io/paint-timing/#painttimingmixin-paint-timing-info) is `paintTimingInfo`.

#### 3.2.2. Long Script Monitoring

To [record timing info for user
callback] given a [callback
function](https://webidl.spec.whatwg.org/#dfn-callback-function) `callback` and an [environment settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) `settings`: [Create script entry
point](#create-script-entry-point) given `settings`, \"\`user-callback\`\", and
the following steps given a [script timing
info](#script-timing-info)
`scriptTimingInfo`:

1. Set `scriptTimingInfo`'s [invoker
 name](#script-timing-info-invoker-name) to `callback`'s
 [identifier](https://webidl.spec.whatwg.org/#dfn-identifier).

2. [Apply source
 location](#apply-source-location) for `scriptTimingInfo` given
 `callback`.

To [record timing info for timer
handler] given a string or
[`Function`](https://webidl.spec.whatwg.org/#Function) `handler`, an [environment settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) `settings`, and a boolean
`repeat`: [Create script entry
point](#create-script-entry-point) given `settings`, \"\`user-callback\`\", and
the following steps given a [script timing
info](#script-timing-info)
`scriptTimingInfo`:

1. Let `setTimeoutOrInterval` be \"setInterval\" if
 `repeat` is true, \"setTimeout\" otherwise.

2. Set `scriptTimingInfo`'s [invoker
 name](#script-timing-info-invoker-name) to
 [concatenation](https://infra.spec.whatwg.org/#string-concatenate) of « TimerHandler:\",
 `setTimeoutOrInterval` ».

3. If `handler` is a
 [`Function`](https://webidl.spec.whatwg.org/#Function), then [apply source
 location](#apply-source-location) for `scriptTimingInfo` given
 `handler`.

To [record timing info for event
listener] given an
[`Event`](https://dom.spec.whatwg.org/#event) `event` and an
[`EventListener`](https://dom.spec.whatwg.org/#callbackdef-eventlistener) `listener`: [Create script entry
point](#create-script-entry-point) given `listener`'s [relevant settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object), \"\`event-listener\`\", and the following steps given
a [script timing info](#script-timing-info) `scriptTimingInfo` and a [frame timing
info](#frame-timing-info)
`frameTimingInfo`:

1. Set `scriptTimingInfo`'s [event
 type](#script-timing-info-event-type) to `event`'s
 [`type`](https://dom.spec.whatwg.org/#dom-event-type).

2. Let `target` be `event`'s
 [`currentTarget`](https://dom.spec.whatwg.org/#dom-event-currenttarget).

3. If `target` is a
 [`Node`](https://dom.spec.whatwg.org/#node), then:

 1. Set `scriptTimingInfo`'s [invoker
 name](#script-timing-info-invoker-name) to `target`'s
 [`nodeName`](https://dom.spec.whatwg.org/#dom-node-nodename).

 2. If `target` is an
 [`Element`](https://dom.spec.whatwg.org/#element), then:

 1. Set `scriptTimingInfo`'s [event target element
 id](#script-timing-info-event-target-element-id) to `target`'s
 [id](https://dom.spec.whatwg.org/#concept-id).

 2. Set `scriptTimingInfo`'s [event target element
 src
 attribute](#script-timing-info-event-target-element-src-attribute) to the result of [getting an attribute
 value by
 name](https://dom.spec.whatwg.org/#concept-element-attributes-get-by-name) \"\`src\`\" and `target`.

4. Else, set `scriptTimingInfo`'s [invoker
 name](#script-timing-info-invoker-name) to `target`'s interface name.

5. [Apply source
 location](#apply-source-location) for `scriptTimingInfo` given
 `listener`'s
 [callback](https://dom.spec.whatwg.org/#event-listener-callback).

6. If `event` is a
 [`UIEvent`](https://w3c.github.io/uievents/#uievent), and `frameTimingInfo`'s [first ui event
 timestamp](#frame-timing-info-first-ui-event-timestamp) is null, then set `frameTimingInfo`'s
 [first ui event
 timestamp](#frame-timing-info-first-ui-event-timestamp) to `event`'s [relevant settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object)'s [time
 origin](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-time-origin) + a
 [duration](https://w3c.github.io/hr-time/#dfn-duration) of `event`'s
 [`timeStamp`](https://dom.spec.whatwg.org/#dom-event-timestamp) milliseconds.

To [record timing info for promise
resolver] given a
[`Promise`](https://webidl.spec.whatwg.org/#idl-promise) `promise` and a \"\`resolve-promise\`\" or
\"\`reject-promise\`\" `type`:

1. [Create script entry
 point](#create-script-entry-point) given `promise`'s [relevant
 realm](https://html.spec.whatwg.org/multipage/webappapis.html#concept-relevant-realm)'s [settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm-settings-object), `type`, and the following steps given a
 [script timing
 info](#script-timing-info) `scriptTimingInfo`:

 1. Set `scriptTimingInfo`'s [invoker
 name](#script-timing-info-invoker-name) to `promise`'s [invoker name when
 created](#promise-invoker-name-when-created).

 2. Set `scriptTimingInfo`'s [source
 url](#script-timing-info-source-url) to `promise`'s [script url when
 created](#promise-script-url-when-created).

 3. Set `scriptTimingInfo`'s [source character
 position](#script-timing-info-source-character-position) to `promise`'s [source character
 position when
 created](#promise-source-character-position-when-created).

 4. Set `scriptTimingInfo`'s [source line
 number](#script-timing-info-source-line-number) to `promise`'s [source line when
 created](#promise-source-line-when-created).

 5. Set `scriptTimingInfo`'s [source column
 number](#script-timing-info-source-column-number) to `promise`'s [source column when
 created](#promise-source-column-when-created).

To [set source url for script block] given a [script timing
info](#script-timing-info)
`scriptTimingInfo`, a
[script](https://html.spec.whatwg.org/multipage/webappapis.html#concept-script) `script`, and a
[URL](https://url.spec.whatwg.org/#concept-url)-or-null `url`:

1. Set `scriptTimingInfo`'s [source character
 position](#script-timing-info-source-character-position) to 0.

2. If `url` is null, then return.

3. If `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) is \"\`http\`\", \"\`https\`\", or \"\`blob\`\",
 then set `scriptTimingInfo`'s [source
 url](#script-timing-info-source-url) to the
 [serialization](https://url.spec.whatwg.org/#concept-url-serializer) of `url`.

4. Otherwise, if `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) is \"\`data\`\", then set
 `scriptTimingInfo`'s [source
 url](#script-timing-info-source-url) to \"\`data:\`\".

5. If `script` is not a [classic
 script](https://html.spec.whatwg.org/multipage/webappapis.html#classic-script) whose [muted
 errors](https://html.spec.whatwg.org/multipage/#muted-errors) is true, then:

 1. Set `scriptTimingInfo`'s [source line
 number](#script-timing-info-source-line-number) to 1.

 2. Set `scriptTimingInfo`'s [source column
 number](#script-timing-info-source-column-number) to 1.

To [record classic script creation
time] given a [classic
script](https://html.spec.whatwg.org/multipage/webappapis.html#classic-script) `script` and a
[URL](https://url.spec.whatwg.org/#concept-url)-or-null `originalSourceURL`:

1. Set `script`'s [original source
 URL](#classic-script-original-source-url) to `originalSourceURL`.

2. [Create script entry
 point](#create-script-entry-point) given `script`'s [settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#settings-object), \"\`classic-script\`\", and the following step
 given a [script timing
 info](#script-timing-info) `scriptTimingInfo`: [Set source url for
 script
 block](#set-source-url-for-script-block) given `scriptTimingInfo`,
 `script`, and `script`'s [exposed source
 URL](#script-exposed-source-url).

To [record classic script execution start
time] given a [classic
script](https://html.spec.whatwg.org/multipage/webappapis.html#classic-script) `script`:

1. Let `settings` be `script`'s [settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#settings-object).

2. If `settings`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global) is not a
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window), then return.

3. Let `document` be `settings`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global)'s [associated
 Document](https://html.spec.whatwg.org/multipage/nav-history-apis.html#concept-document-window).

4. Let `frameTimingInfo` be `document`'s
 [relevant frame timing
 info](#relevant-frame-timing-info).

5. If `frameTimingInfo` is null or
 `frameTimingInfo`'s [pending
 script](#frame-timing-info-pending-script) is null:

 1. [Create script entry
 point](#create-script-entry-point) given `settings`,
 \"\`classic-script\`\", and the following step given a [script
 timing info](#script-timing-info) `scriptTimingInfo`: [Set source url
 for script
 block](#set-source-url-for-script-block) given `scriptTimingInfo`,
 `script`, and `script`'s [exposed source
 URL](#script-exposed-source-url).

 2. Return.

 When classic script creation (compilation) and
 execution occur in separate tasks (for example, for a \`defer\`
 script whose fetch completes before it runs), each step is measured
 in its respective task: the creation task closes the entry opened by
 [record classic script creation
 time](#record-classic-script-creation-time) at its microtask checkpoint (reporting it with
 [`executionStart`](#dom-performancescripttiming-executionstart) equal to
 [`startTime`](#dom-performancescripttiming-starttime) if compilation took at least 5 milliseconds), and
 the execution task opens a new entry here.

6. If `script`'s [muted
 errors](https://html.spec.whatwg.org/multipage/#muted-errors) is false and the [running
 script](https://html.spec.whatwg.org/multipage/#running-script) is null, then set `frameTimingInfo`'s
 [pending
 script](#frame-timing-info-pending-script)'s [execution start
 time](#script-timing-info-execution-start-time) to the [unsafe shared current
 time](https://w3c.github.io/hr-time/#dfn-unsafe-shared-current-time).

To [record module script execution start
time] given a [module
script](https://html.spec.whatwg.org/multipage/webappapis.html#module-script) `script`: [Create script entry
point](#create-script-entry-point) given `script`'s [settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#settings-object), \"\`module-script\`\", and the following steps given a
[script timing info](#script-timing-info) `scriptTimingInfo`: [Set source url for
script
block](#set-source-url-for-script-block) given `scriptTimingInfo`,
`script`, and `script`'s [base
URL](https://html.spec.whatwg.org/multipage/webappapis.html#concept-script-base-url).

To [create script entry point] given an [environment settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) `settings`, a
[`ScriptInvokerType`](#enumdef-scriptinvokertype) `invokerType`, and `steps`, which
is an algorithm that takes a [script timing
info](#script-timing-info) and an optional [frame timing
info](#frame-timing-info):

1. If `settings` is not a
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window), then return.

2. Let `document` be `settings`'s
 [`document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-2).

3. Let `didStartRecording` be the result of calling [start
 recording task time if
 needed](#start-recording-task-time-if-needed) given `settings`.

4. Let `frameTimingInfo` be `document`'s
 [relevant frame timing
 info](#relevant-frame-timing-info).

5. If `frameTimingInfo` is null, then return.

6. Set `frameTimingInfo`'s [script
 initiated](#frame-timing-info-script-initiated) to `didStartRecording`.

7. If `frameTimingInfo`'s [pending
 script](#frame-timing-info-pending-script) is not null, then return.

8. Let `now` be the [unsafe shared current
 time](https://w3c.github.io/hr-time/#dfn-unsafe-shared-current-time).

9. Let `scriptTimingInfo` be a new [script timing
 info](#script-timing-info) whose [start
 time](#script-timing-info-start-time) is `now`, whose [execution start
 time](#script-timing-info-execution-start-time) is `now`, and whose [invoker
 type](#script-timing-info-invoker-type) is `invokerType`.

10. Run `steps` given `scriptTimingInfo` and
 `frameTimingInfo`.

11. Set `scriptTimingInfo`'s
 [window](#script-timing-info-window) to `settings`.

12. [Accumulate style and layout
 time](#accumulate-style-and-layout-time) given `frameTimingInfo`.

13. [Push](https://infra.spec.whatwg.org/#stack-push) \"\`script\`\" onto `frameTimingInfo`'s
 [style and layout
 stack](#frame-timing-info-style-and-layout-stack).

14. Set `frameTimingInfo`'s [pending
 script](#frame-timing-info-pending-script) to `scriptTimingInfo`.

To [record timing info for microtask
checkpoint]:

1. [For
 each](https://infra.spec.whatwg.org/#list-iterate)
 [`Document`](https://dom.spec.whatwg.org/#document) `root` whose [relevant
 agent](https://html.spec.whatwg.org/multipage/webappapis.html#relevant-agent)'s [event
 loop](https://html.spec.whatwg.org/multipage/webappapis.html#concept-agent-event-loop) is the [surrounding
 agent](https://tc39.es/ecma262/multipage/executable-code-and-execution-contexts.html#surrounding-agent)'s [event
 loop](https://html.spec.whatwg.org/multipage/webappapis.html#concept-agent-event-loop), and whose [current frame timing
 info](#current-frame-timing-info) is not null and has a non-null [pending
 script](#frame-timing-info-pending-script): [Finish the pending
 script](#finish-the-pending-script) of `root`.

 This doesn't rely on the [running
script](https://html.spec.whatwg.org/multipage/#running-script), which is generally null when a microtask checkpoint is
performed, or on the
[`Document`](https://dom.spec.whatwg.org/#document) of the script, which might no longer be [fully
active](https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active), e.g. if the script removed its own
[`iframe`](https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-iframe-element).

To [finish the pending script] of a
[`Document`](https://dom.spec.whatwg.org/#document) `root`:

1. Let `frameTimingInfo` be `root`'s [current
 frame timing
 info](#current-frame-timing-info).

2. Let `scriptTimingInfo` be `frameTimingInfo`'s
 [pending
 script](#frame-timing-info-pending-script).

3. [Accumulate style and layout
 time](#accumulate-style-and-layout-time) given `frameTimingInfo`.

4. Let `popped` be the result of
 [popping](https://infra.spec.whatwg.org/#stack-pop) from `frameTimingInfo`'s [style and
 layout
 stack](#frame-timing-info-style-and-layout-stack).

5. [Assert](https://infra.spec.whatwg.org/#assert): `popped` is \"\`script\`\", i.e. any
 style recalculation or layout forced by the script has ended.

6. Let `endTime` be the [unsafe shared current
 time](https://w3c.github.io/hr-time/#dfn-unsafe-shared-current-time).

7. Set `frameTimingInfo`'s [pending
 script](#frame-timing-info-pending-script) to null.

8. Set `scriptTimingInfo`'s [end
 time](#script-timing-info-end-time) to `endTime`.

9. If the
 [duration](https://w3c.github.io/hr-time/#dfn-duration) between `scriptTimingInfo`'s [start
 time](#script-timing-info-start-time) and `scriptTimingInfo`'s [end
 time](#script-timing-info-end-time) is greater than 5 milliseconds, then
 [append](https://infra.spec.whatwg.org/#list-append) `scriptTimingInfo` to
 `frameTimingInfo`'s
 [scripts](#frame-timing-info-scripts).

10. If `frameTimingInfo` is [script
 initiated](#frame-timing-info-script-initiated), then [record task end
 time](#record-task-end-time) given `endTime` and `root`.

 For event listeners, the task lifetime is managed
 by the [fire an
 event](https://dom.spec.whatwg.org/#concept-event-fire) algorithm, which may invoke multiple listeners to
 the same event, rather than at the end of a single listener's
 execution.

To [apply source location] to a [script timing
info](#script-timing-info) `scriptTimingInfo` given a [callback
function](https://webidl.spec.whatwg.org/#dfn-callback-function) or
[`Function`](https://webidl.spec.whatwg.org/#Function) `callback`:

1. If `callback` was not defined in a
 [script](https://html.spec.whatwg.org/multipage/webappapis.html#concept-script), then return.

2. Let `script` be the
 [script](https://html.spec.whatwg.org/multipage/webappapis.html#concept-script) where `callback` was defined.

3. Let `url` be `script`'s [exposed source
 URL](#script-exposed-source-url).

4. If `url` is not null:

 1. If `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) is \"\`http\`\", \"\`https\`\", or
 \"\`blob\`\", then the user agent may set
 `scriptTimingInfo`'s [source
 url](#script-timing-info-source-url) to the
 [serialization](https://url.spec.whatwg.org/#concept-url-serializer) of `url`.

 2. Otherwise, if `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) is \"\`data\`\", then the user agent may set
 `scriptTimingInfo`'s [source
 url](#script-timing-info-source-url) to \"\`data:\`\".

5. If `script` is a [classic
 script](https://html.spec.whatwg.org/multipage/webappapis.html#classic-script) whose [muted
 errors](https://html.spec.whatwg.org/multipage/#muted-errors) is true, then return.

6. The user agent may set `scriptTimingInfo`'s [source
 function
 name](#script-timing-info-source-function-name) to the function name of `callback`.

7. The user agent may set `scriptTimingInfo`'s [source
 character
 position](#script-timing-info-source-character-position) to the character position where
 `callback` was defined.

8. The user agent may set `scriptTimingInfo`'s [source line
 number](#script-timing-info-source-line-number) to the line number where `callback` was
 defined.

9. The user agent may set `scriptTimingInfo`'s [source
 column
 number](#script-timing-info-source-column-number) to the column number where `callback`
 was defined.

To [record pause duration] given a
[duration](https://w3c.github.io/hr-time/#dfn-duration) `duration`:

1. Let `script` be the [running
 script](https://html.spec.whatwg.org/multipage/#running-script).

2. If `script` is null, then return.

3. Let `settings` be `script`'s [settings
 object](https://html.spec.whatwg.org/multipage/webappapis.html#settings-object).

4. If `settings`'s [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-global) is not a
 [`Window`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#window), then return.

5. Let `document` be `settings`'s
 [`document`](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-2).

6. Let `frameTimingInfo` be the [relevant frame timing
 info](#relevant-frame-timing-info) given `document`.

7. If `frameTimingInfo` is null or
 `frameTimingInfo`'s [pending
 script](#frame-timing-info-pending-script) is null, then return.

8. Increment `frameTimingInfo`'s [pending
 script](#frame-timing-info-pending-script)'s [pause
 duration](#script-timing-info-pause-duration) by the milliseconds value of `duration`.

#### 3.2.3. Style and Layout Monitoring

The user agent calls [begin style
recalculation](#begin-style-recalculation) and [end style
recalculation](#end-style-recalculation) given a
[`Document`](https://dom.spec.whatwg.org/#document) whenever it starts and finishes recalculating the
styles of that
[`Document`](https://dom.spec.whatwg.org/#document), and [begin
layout](#begin-layout) and [end
layout](#end-layout) given a
[`Document`](https://dom.spec.whatwg.org/#document) whenever it starts and finishes updating the layout of
that
[`Document`](https://dom.spec.whatwg.org/#document). This includes style recalculation and layout performed
as part of [update the
rendering](https://html.spec.whatwg.org/multipage/webappapis.html#update-the-rendering), and style recalculation and layout performed
synchronously while a script is running, e.g. when the script calls
[`getComputedStyle()`](https://drafts.csswg.org/cssom-1/#dom-window-getcomputedstyle) or
[`getBoundingClientRect()`](https://drafts.csswg.org/cssom-view-1/#dom-element-getboundingclientrect). When exactly style recalculation and layout are
performed, and therefore when these algorithms are called, is
[implementation-defined](https://infra.spec.whatwg.org/#implementation-defined).

Find a way to make this
interoperable/normative. Perhaps mark those functions in WebIDL as
requiring synchronous style/layout?

 Style recalculation and layout can be nested, e.g. when
evaluating [container size
queries](https://drafts.csswg.org/css-conditional-5/#container-size-query) requires recalculating styles in the middle of layout.
Elapsed time is always attributed to the innermost style recalculation,
layout, or script in progress, so the same time is never counted twice,
and time spent running scripts is not counted as style or layout. Style
recalculation and layout performed while a script is running count
towards that script's [forced style
duration](#script-timing-info-forced-style-duration) and [forced layout
duration](#script-timing-info-forced-layout-duration). Otherwise, they only count towards the frame's [style
duration](#frame-timing-info-style-duration) and [layout
duration](#frame-timing-info-layout-duration) if they are performed as part of the rendering update,
after
[`styleAndLayoutStart`](#dom-performancelonganimationframetiming-styleandlayoutstart).

 Recalculating styles or updating layout for one
[`Document`](https://dom.spec.whatwg.org/#document) can require doing so for other documents, e.g. for an
ancestor whose layout determines the size of a descendant's viewport. In
that case, these algorithms are called for each of these documents. As
time is attributed to each document's [relevant frame timing
info](#relevant-frame-timing-info), the style recalculation and layout of documents with a
different [nearest same-origin
root](#nearest-same-origin-root) are never attributed to the script that caused them,
and only count towards their own root's frame if they are performed as
part of its rendering update.

To [begin style recalculation] given a
[`Document`](https://dom.spec.whatwg.org/#document) `document`, [begin style or layout
work](#begin-style-or-layout-work) given `document` and \"\`style\`\".

To [end style recalculation] given a
[`Document`](https://dom.spec.whatwg.org/#document) `document`, [end style or layout
work](#end-style-or-layout-work) given `document` and \"\`style\`\".

To [begin layout] given a
[`Document`](https://dom.spec.whatwg.org/#document) `document`, [begin style or layout
work](#begin-style-or-layout-work) given `document` and \"\`layout\`\".

To [end layout]
given a
[`Document`](https://dom.spec.whatwg.org/#document) `document`, [end style or layout
work](#end-style-or-layout-work) given `document` and \"\`layout\`\".

To [begin style or layout work] given a
[`Document`](https://dom.spec.whatwg.org/#document) `document` and a string `type`:

1. Let `timingInfo` be `document`'s [relevant
 frame timing
 info](#relevant-frame-timing-info).

2. If `timingInfo` is null, then return.

3. [Accumulate style and layout
 time](#accumulate-style-and-layout-time) given `timingInfo`.

4. [Push](https://infra.spec.whatwg.org/#stack-push) `type` onto `timingInfo`'s
 [style and layout
 stack](#frame-timing-info-style-and-layout-stack).

To [end style or layout work] given a
[`Document`](https://dom.spec.whatwg.org/#document) `document` and a string `type`:

1. Let `timingInfo` be `document`'s [relevant
 frame timing
 info](#relevant-frame-timing-info).

2. If `timingInfo` is null, then return.

3. [Accumulate style and layout
 time](#accumulate-style-and-layout-time) given `timingInfo`.

4. Let `popped` be the result of
 [popping](https://infra.spec.whatwg.org/#stack-pop) from `timingInfo`'s [style and layout
 stack](#frame-timing-info-style-and-layout-stack).

5. [Assert](https://infra.spec.whatwg.org/#assert): `popped` is `type`.

 A [frame timing
info](#frame-timing-info)
is only created or discarded when a task, a script, or a rendering
update starts or ends, which can't happen while a style recalculation or
layout is in progress. So both the beginning and the end of a style
recalculation or layout see the same [relevant frame timing
info](#relevant-frame-timing-info).

To [accumulate style and layout time] given a [frame timing
info](#frame-timing-info)
`timingInfo`:

1. Let `now` be the [coarsened shared current
 time](https://w3c.github.io/hr-time/#dfn-coarsened-shared-current-time) given `timingInfo`'s [cross-origin
 isolated
 capability](#frame-timing-info-cross-origin-isolated-capability).

2. If `timingInfo`'s [style and layout
 stack](#frame-timing-info-style-and-layout-stack) is not
 [empty](https://infra.spec.whatwg.org/#list-is-empty), then:

 1. Let `type` be the result of
 [peeking](https://infra.spec.whatwg.org/#stack-peek) into `timingInfo`'s [style and
 layout
 stack](#frame-timing-info-style-and-layout-stack).

 2. Let `script` be `timingInfo`'s [pending
 script](#frame-timing-info-pending-script).

 3. Let `duration` be the
 [duration](https://w3c.github.io/hr-time/#dfn-duration) between `timingInfo`'s [style and
 layout stack change
 time](#frame-timing-info-style-and-layout-stack-change-time) and `now`.

 4. If `type` is \"\`style\`\" and `script` is
 not null, then increment `script`'s [forced style
 duration](#script-timing-info-forced-style-duration) by the milliseconds value of
 `duration`.

 5. Otherwise, if `type` is \"\`layout\`\" and
 `script` is not null, then increment
 `script`'s [forced layout
 duration](#script-timing-info-forced-layout-duration) by the milliseconds value of
 `duration`.

 6. Otherwise, if `type` is \"\`style\`\" or
 \"\`layout\`\", then
 [append](https://infra.spec.whatwg.org/#list-append) a new [style and layout
 period](#style-and-layout-period) whose
 [type](#style-and-layout-period-type) is `type`, [start
 time](#style-and-layout-period-start-time) is `timingInfo`'s [style and layout
 stack change
 time](#frame-timing-info-style-and-layout-stack-change-time), and [end
 time](#style-and-layout-period-end-time) is `now`, to
 `timingInfo`'s [style and layout
 periods](#frame-timing-info-style-and-layout-periods).

 [Record rendering
 time](#record-rendering-time) only counts the periods that are part of the
 rendering update.

 If `type` is \"\`script\`\", then the
 elapsed time is spent running a script, and is not counted as style
 or layout.

3. Set `timingInfo`'s [style and layout stack change
 time](#frame-timing-info-style-and-layout-stack-change-time) to `now`.

 The durations are computed only from
[coarsened](https://w3c.github.io/hr-time/#dfn-coarsen-time) times, using the [cross-origin isolated
capability](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-cross-origin-isolated-capability) of the [nearest same-origin
root](#nearest-same-origin-root) to which `timingInfo` belongs. This ensures
that they don't expose timing information at a higher resolution than
that document's timestamps, even when summing up many short periods.

## 4. Additions to existing standards

### 4.1. Monkey-patches to the WebIDL standard

[`Promise`](https://webidl.spec.whatwg.org/#idl-promise) interface has an associated string [invoker name when
created], initially
\"\`Promise\`\". The
[`Promise`](https://webidl.spec.whatwg.org/#idl-promise) interface has an associated string [script url when
created], initially the empty
string. The
[`Promise`](https://webidl.spec.whatwg.org/#idl-promise) interface has an associated number [source character
position when created],
initially -1. The
[`Promise`](https://webidl.spec.whatwg.org/#idl-promise) interface has an associated number [source line when
created], initially -1. The
[`Promise`](https://webidl.spec.whatwg.org/#idl-promise) interface has an associated number [source column when
created], initially -1.

Append the following steps to [creating a new
promise](https://webidl.spec.whatwg.org/#a-new-promise), before
returning the
[`Promise`](https://webidl.spec.whatwg.org/#idl-promise):

1. If this promise was created by the steps of an
 [attribute](https://webidl.spec.whatwg.org/#dfn-attribute), [regular
 operation](https://webidl.spec.whatwg.org/#dfn-regular-operation), or [static
 operation](https://webidl.spec.whatwg.org/#dfn-static-operation) `member` defined on an
 [interface](https://webidl.spec.whatwg.org/#dfn-interface) `interface`, then:

 1. Let `interfaceName` be `interface`'s
 [identifier](https://webidl.spec.whatwg.org/#dfn-identifier).

 2. Let `memberName` be `member`'s
 [identifier](https://webidl.spec.whatwg.org/#dfn-identifier).

 3. The user agent may set the created
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)'s [invoker name when
 created](#promise-invoker-name-when-created) to the
 [concatenation](https://infra.spec.whatwg.org/#string-concatenate) of « `interfaceName`, \".\",
 `memberName` ».

2. Let `script` be the [running
 script](https://html.spec.whatwg.org/multipage/#running-script).

3. If `script` is not null:

 1. Let `url` be `script`'s [exposed source
 URL](#script-exposed-source-url).

 2. If `url` is not null:

 1. If `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) is \"\`http\`\", \"\`https\`\", or
 \"\`blob\`\", then the user agent may set the created
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)'s [script url when
 created](#promise-script-url-when-created) to the
 [serialization](https://url.spec.whatwg.org/#concept-url-serializer) of `url`.

 2. Otherwise, if `url`'s
 [scheme](https://url.spec.whatwg.org/#concept-url-scheme) is \"\`data\`\", then the user agent may
 set the created
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)'s [script url when
 created](#promise-script-url-when-created) to \"\`data:\`\".

 3. If `script` is not a [classic
 script](https://html.spec.whatwg.org/multipage/webappapis.html#classic-script) whose [muted
 errors](https://html.spec.whatwg.org/multipage/#muted-errors) is true:

 1. The user agent may set the created
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)'s [source character position when
 created](#promise-source-character-position-when-created) to the zero-based character position in
 `script` where the operation or attribute getter
 that created this promise was invoked.

 2. The user agent may set the created
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)'s [source line when
 created](#promise-source-line-when-created) to the one-based line number in
 `script` where the operation or attribute getter
 that created this promise was invoked.

 3. The user agent may set the created
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise)'s [source column when
 created](#promise-source-column-when-created) to the one-based column number in
 `script` where the operation or attribute getter
 that created this promise was invoked.

 Attribution at promise creation time is optional
because probing the current execution stack when creating a promise can
incur performance overhead. User agents that do not apply this
attribution will leave these values at their defaults (reporting
\"\`Promise.then\`\" or \"\`Promise.catch\`\" for
[`invoker`](#dom-performancescripttiming-invoker) and \`-1\` for
[`sourceCharPosition`](#dom-performancescripttiming-sourcecharposition),
[`sourceLine`](#dom-performancescripttiming-sourceline), and
[`sourceColumn`](#dom-performancescripttiming-sourcecolumn)).

Prepend the following step to [resolve a
promise](https://webidl.spec.whatwg.org/#resolve) given
[`Promise`](https://webidl.spec.whatwg.org/#idl-promise) `p`: [Record timing info for promise
resolver](#record-timing-info-for-promise-resolver) given `p` and \"\`resolve-promise\`\".

Prepend the following step to [reject a
promise](https://webidl.spec.whatwg.org/#reject) given
[`Promise`](https://webidl.spec.whatwg.org/#idl-promise) `p`: [Record timing info for promise
resolver](#record-timing-info-for-promise-resolver) given `p` and \"\`reject-promise\`\".

 Hooking WebIDL
[resolve](https://webidl.spec.whatwg.org/#resolve) and
[reject](https://webidl.spec.whatwg.org/#reject) opens the script entry point when the promise is
settled in the resolving task and closes it at the end of the subsequent
[microtask
checkpoint](https://html.spec.whatwg.org/multipage/webappapis.html#perform-a-microtask-checkpoint), rather than hooking each individual promise reaction
job. As a consequence, only the first WebIDL promise settled while no
script entry point is pending opens an entry for that checkpoint, and
promises created and settled purely in JavaScript are not attributed on
their own.

Insert the following steps to [invoke a callback
function](https://webidl.spec.whatwg.org/#invoke-a-callback-function),
once we have an [environment settings
object](https://html.spec.whatwg.org/multipage/webappapis.html#environment-settings-object) `relevant settings` and a [callback
function](https://webidl.spec.whatwg.org/#dfn-callback-function) `F`: [Record timing info for user
callback](#record-timing-info-for-user-callback) given `F` and
`relevant settings`.

## 5. Security & privacy considerations

The Long Animation Frames API adheres to the same-origin policy by
including origin-safe attribution information about the source of the
long task. There is a 50ms threshold for long tasks. Timestamps and
durations are
[coarsened](https://w3c.github.io/hr-time/#dfn-coarsen-time) according to
[\[HR-TIME\]](#biblio-hr-time "High Resolution Time"),
with a resolution that depends on the [cross-origin isolated
capability](https://html.spec.whatwg.org/multipage/webappapis.html#concept-settings-object-cross-origin-isolated-capability). Style and layout durations are sums of many short
periods, so they are computed only from coarsened times (see [accumulate
style and layout
time](#accumulate-style-and-layout-time)), which ensures that summing them up doesn't expose
timing information at a higher resolution than the timestamps. Together
this provides adequate protection against cross-origin leaks.

The Long Animation Frames API provides timing information about the
duration and type of tasks executed by the user, as well as attribution
such as the browsing context causing the function calls. This could
enable an attacker to perform side-channel timing attacks to guess the
user's action, or identify the user. For example, a pattern of long
script followed by a long render could be put together to guess user's
interaction with a social widget. Detailed function call attribution
would be used to determine the user's action.

### 5.1. What is Exposed to Observers?

All observers within the top level page (i.e. all iframes in the page
and the main frame) will receive notifications about presence of long
animation frames. We expose the start time of the task, its duration
(coarsened according to
[\[HR-TIME\]](#biblio-hr-time "High Resolution Time")),
and a pointer to the culprit frame. This information can already be
observed today, and with higher resolution, using setTimeout. An
attacker can do this by clearing everything else on the page and adding
the vulnerable cross-origin resource to ensure that delays from the
setTimeout are caused by that resource. Observers in other different
pages (tabs or windows) should not receive notifications, regardless of
the architecture of the user agent.

### 5.2. Attack Scenarios Considered

The following are the timing attacks considered:

1. **Traditional timing attacks**: using external resource load time to
 reveal the size of private data. For instance the number of hidden
 pictures in a gallery, whether username is valid, etc. See an
 [example](http://crypto.stanford.edu/~dabo/papers/webtiming.pdf).

2. **Side-channel timing attacks**: using time for video parsing,
 script parsing, App Cache reads or Cache API (service workers) usage
 to uniquely identify a user, or to create a profile of the user's
 age, gender, location, and interests etc. For
 [instance](https://tom.vg/papers/timing-attacks_ccs2015.pdf), status
 updates from a social network can be limited to certain demographic
 (eg. females of age 20-30) the file size of the permalink page can
 be used to determine whether the user is in the target demographic.

These scenarios are addressed by the 50ms threshold AND respecting
cross-origin boundary i.e. not showing task type or additional
attribution to untrusted cross origin observers.

### 5.3. Additional information exposed by the Long Animation Frames API

Since several cross-origin documents can share the same event loop, they
can also render as part of the same frame sequence and influence each
other's rendering time. This makes it so that these timings are already
somewhat observable cross-origin, e.g. by requesting an animation frame
and observing if it is delayed, though long animation frames exposes
them at a higher fidelity.

To mitigate this, long animation frames are only reported to
\"participating local roots\": only documents that are associated with a
work task that contributed to the sequence, or that were rendered as
part of the frame, are eligible to observe the long animation frame, and
that long animation frame would be available only in their nearest
ancestor that is either topmost or has a cross-origin parent.

[`styleDuration`](#dom-performancelonganimationframetiming-styleduration),
[`layoutDuration`](#dom-performancelonganimationframetiming-layoutduration),
[`forcedStyleDuration`](#dom-performancescripttiming-forcedstyleduration), and
[`forcedLayoutDuration`](#dom-performancescripttiming-forcedlayoutduration) only include the style recalculation and layout of
documents that share the same [nearest same-origin
root](#nearest-same-origin-root) (see [§ 3.2.3 Style and Layout
Monitoring](#style-and-layout-monitoring)). They don't expose how much
time cross-origin documents spend on style and layout, beyond what the
overall rendering timings described above already expose.

### 5.4. [`PerformanceScriptTiming` and opaque scripts]
Since
[`PerformanceScriptTiming`](#performancescripttiming) exposes information about script execution, we need to
make sure it doesn't expose too much information about [CORS
cross-origin](https://html.spec.whatwg.org/multipage/#cors-cross-origin) scripts that cannot be easily deduced otherwise. To do
that, we use the existing [muted
errors](https://html.spec.whatwg.org/multipage/#muted-errors) boolean: for [classic
scripts](https://html.spec.whatwg.org/multipage/webappapis.html#classic-script) whose [muted
errors](https://html.spec.whatwg.org/multipage/#muted-errors) is true (as well as callbacks or promises defined
inside them),
[`sourceURL`](#dom-performancescripttiming-sourceurl) exposes only the pre-redirect request URL (the
\`script\` element's initial URL) rather than the post-redirect response
URL,
[`executionStart`](#dom-performancescripttiming-executionstart) is set equal to
[`startTime`](#dom-performancescripttiming-starttime) so compilation duration is not exposed, and for
callbacks or promises defined inside such scripts,
[`sourceFunctionName`](#dom-performancescripttiming-sourcefunctionname),
[`sourceCharPosition`](#dom-performancescripttiming-sourcecharposition),
[`sourceLine`](#dom-performancescripttiming-sourceline), and
[`sourceColumn`](#dom-performancescripttiming-sourcecolumn) are omitted.
