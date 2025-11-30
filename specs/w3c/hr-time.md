
This specification defines an API that provides the time origin, and
current time in sub-millisecond resolution, such that it is not subject
to system clock skew or adjustments.

## Introduction

The ECMAScript Language specification \[\[ECMA-262\]\] defines the
[`Date`] object
as a time value representing time in milliseconds since 01 January, 1970
UTC. For most purposes, this definition of time is sufficient as these
values represent time to millisecond precision for any moment that is
within approximately 285,616 years from 01 January, 1970 UTC.

In practice, these definitions of time are subject to both clock skew
and adjustment of the system clock. The value of time may not always be
monotonically increasing and subsequent values may either decrease or
remain the same.

For example, the following script may record a positive number, negative
number, or zero for computed `duration`:

```

 var mark_start = Date.now();
 doTask(); // Some task
 var duration = Date.now() - mark_start;

```

For certain tasks this definition of time may not be sufficient as it:

- Does not have a stable monotonic clock, and as a result, it is subject
 to system clock skew.
- Does not provide sub-millisecond time resolution.

This specification does not propose changing the behavior of
[`Date.now()`]
\[\[ECMA-262\]\] as it is genuinely useful in determining the current
value of the calendar time and has a long history of usage. The
{{DOMHighResTimeStamp}} type, {{Performance}}.{{Performance/now()}}
method, and {{Performance}}.{{Performance/timeOrigin}} attributes of the
{{Performance}} interface resolve the above issues by providing
monotonically increasing time values with sub-millisecond resolution.

Providing sub-millisecond resolution is not a mandatory part of this
specification. Implementations may choose to limit the timer resolution
they expose for privacy and security reasons, and not expose
sub-millisecond timers. Use-cases that rely on sub-millisecond
resolution may not be satisfied when that happens.

### Use-cases

This specification defines a few different capabilities: it provides
timestamps based on a stable, monotonic clock, comparable across
contexts, with potential sub-millisecond resolution.

The need for a stable monotonic clock when talking about performance
measurements stems from the fact that unrelated clock skew can distort
measurements and render them useless. For example, when attempting to
accurately measure the elapsed time of navigating to a Document,
fetching of resources or execution of script, a monotonically increasing
clock with sub-millisecond resolution is desired.

Comparing timestamps between contexts is essential e.g. when
synchronizing work between a {{Worker}} and the main thread or when
instrumenting such work in order to create a unified view of the event
timeline.

Finally, the need for sub-millisecond timers revolves around the
following use-cases:

- Ability to schedule work in sub-millisecond intervals. That is
 particularly important on the main thread, where work can interfere
 with frame rendering which needs to happen in short and regular
 intervals, to avoid user-visible jank.
- When calculating the frame rate of a script-based animation,
 developers will need sub-millisecond resolution in order to determine
 if an animation is drawing at 60 FPS. Without sub-millisecond
 resolution, a developer can only determine if an animation is drawing
 at 58.8 FPS (1000ms / 16) or 62.5 FPS (1000ms / 17).
- When collecting in-the-wild measurements of JS code (e.g. using
 User-Timing), developers may be interested in gathering
 sub-milliseconds timing of their functions, to catch regressions
 early.
- When attempting to cue audio to a specific point in an animation or
 ensure that the audio and animation are perfectly synchronized,
 developers will need to accurately measure the amount of time elapsed.

### Examples

A developer may wish to construct a timeline of their entire
application, including events from {{Worker}} or {{SharedWorker}}, which
have different \[=environment settings object/time origins=\]. To
display such events on the same timeline, the application can translate
the {{DOMHighResTimeStamp}}s with the help of the
{{Performance}}.{{Performance/timeOrigin}} attribute.

```

 // ---- worker.js -----------------------------
 // Shared worker script
 onconnect = function(e) {
 var port = e.ports[0];
 port.onmessage = function(e) {
 // Time execution in worker
 var task_start = performance.now();
 result = runSomeWorkerTask();
 var task_end = performance.now();
 }

 // Send results and epoch-relative timestamps to another context
 port.postMessage({
 'task': 'Some worker task',
 'start_time': task_start + performance.timeOrigin,
 'end_time': task_end + performance.timeOrigin,
 'result': result
 });
 }

 // ---- application.js ------------------------
 // Timing tasks in the document
 var task_start = performance.now();
 runSomeApplicationTask();
 var task_end = performance.now();

 // developer provided method to upload runtime performance data
 reportEventToAnalytics({
 'task': 'Some document task',
 'start_time': task_start,
 'duration': task_end - task_start
 });

 // Translating worker timestamps into document's time origin
 var worker = new SharedWorker('worker.js');
 worker.port.onmessage = function (event) {
 var msg = event.data;

 // translate epoch-relative timestamps into document's time origin
 msg.start_time = msg.start_time - performance.timeOrigin;
 msg.end_time = msg.end_time - performance.timeOrigin;

 reportEventToAnalytics(msg);
 }

```

### Time Concepts

#### Clocks

A [clock] tracks the passage of time and can report the [unsafe
current time] that an algorithm step is executing. There are many
kinds of clocks. All clocks on the web platform attempt to count 1
millisecond of clock time per 1 millisecond of real-world time, but they
differ in how they handle cases where they can\'t be exactly correct.

- The [wall clock]\'s [unsafe current
 time] is always as close as possible to a user\'s notion of time.
 Since a computer sometimes runs slow or fast or loses track of time,
 its \[=wall clock=\] sometimes needs to be adjusted, which means the
 \[=wall clock/unsafe current time=\] can decrease, making it
 unreliable for performance measurement or recording the orders of
 events. The web platform shares a \[=wall clock=\] with
 \[\[ECMA-262\]\] [time].

- The [monotonic clock]\'s [unsafe current
 time] never decreases, so it can\'t be changed by
 system clock adjustments. The \[=monotonic clock=\] only exists within
 a single execution of the \[=user agent=\], so it can\'t be used to
 compare events that might happen in different executions.

 Since the \[=monotonic clock=\] can\'t be adjusted to match the
 user\'s notion of time, it should be used for measurement, rather than
 user-visible times. For any time communication with the user, use the
 wall clock.

 The user agent can pick a new \[=estimated monotonic time of the Unix
 epoch=\] when the browser restarts, when it starts an isolated
 browsing session---e.g. incognito or a similar browsing mode---or when
 it creates an \[=environment settings object=\] that can\'t
 communicate with any existing settings objects. As a result,
 developers should not use shared timestamps as absolute time that
 holds its monotonic properties across all past, present, and future
 contexts; in practice, the monotonic properties only apply for
 contexts that can reach each other by exchanging messages via one of
 the provided messaging mechanisms - e.g. {{Window/postMessage(message,
 options)}}, {{BroadcastChannel}}, etc.

 In certain scenarios (e.g. when a tab is backgrounded), the user agent
 may choose to throttle timers and periodic callbacks run in that
 context or even freeze them entirely. Any such throttling should not
 affect the resolution or accuracy of the time returned by the
 monotonic clock.

::: section
#### Moments and Durations

Each \[=clock=\]\'s \[=unsafe current time=\] returns an [unsafe
moment]. \[=Coarsen time=\] converts these \[=unsafe moments=\] to
[coarsened moments] or just \[=moments=\].
\[=Unsafe moments=\] and \[=moments=\] from different clocks are not
comparable.

\[=Moments=\] and \[=unsafe moments=\] represent points in time, which
means they can\'t be directly stored as numbers. Implementations will
usually represent a \[=moment=\] as a \[=duration=\] from some other
fixed point in time, but specifications ought to deal in the
\[=moments=\] themselves.

A [duration] is the distance from one \[=moment=\] to
another from the same \[=clock=\]. Neither endpoint can be an \[=unsafe
moment=\] so that both \[=durations=\] and differences of
\[=durations=\] mitigate the concerns in \[\[\[#clock-resolution\]\]\].
\[=Durations=\] are measured in milliseconds, seconds, etc. Since all
\[=clocks=\] attempt to count at the same rate, \[=durations=\] don\'t
have an associated \[=clock=\], and a \[=duration=\] calculated from two
\[=moments=\] on one clock can be added to a \[=moment=\] from a second
\[=clock=\], to produce another \[=moment=\] on that second \[=clock=\].

The [duration from] \|a:moment\| to \|b:moment\| is the
result of the following algorithm:

1. Assert: \|a\| was created by the same \[=clock=\] as \|b\|.
2. Assert: Both \|a\| and \|b\| are \[=coarsened moments=\].
3. Return the amount of time from \|a\| to \|b\| as a \[=duration=\].
 If \|b\| came before \|a\|, this will be a negative \[=duration=\].

\[=Durations=\] can be used implicitly as {{DOMHighResTimeStamp}}s. To
[implicitly convert a duration to a timestamp], given a
\[=duration=\] \|d:duration\|, return the number of milliseconds in
\|d\|.

### Tools for Specification Authors

For measuring time within a single page (within the context of a single
\[=environment settings object=\]), use the \|settingsObject:environment
settings object\|\'s [current relative timestamp], defined as the \[=duration
from=\] \|settingsObject\|\'s \[=environment settings object/time
origin=\] to the \|settingsObject\|\'s \[=environment settings
object/current monotonic time=\]. This value can be exposed directly to
JavaScript using the \[=duration=\]\'s \[=implicitly convert a duration
to a timestamp\|implicit conversion=\] to {{DOMHighResTimeStamp}}.

For measuring time within a single UA execution when an \[=environment
settings object=\]\'s \[=environment settings object/time origin=\]
isn\'t an appropriate base for comparison, create \[=moments=\] using an
\[=environment settings object=\]\'s \[=environment settings
object/current monotonic time=\]. An \[=environment settings object=\]
\|settingsObject:environment settings object\|\'s [current monotonic
time] is the
result of the following steps:

1. Let \|unsafeMonotonicTime:unsafe moment on the monotonic clock\| be
 the \[=monotonic clock=\]\'s \[=monotonic clock/unsafe current
 time=\].
2. Return the result of calling \[=coarsen time=\] with
 \|unsafeMonotonicTime\| and \|settingsObject\|\'s \[=environment
 settings object/cross-origin isolated capability=\].

\[=Moments=\] from the \[=monotonic clock=\] can\'t be directly
represented in JavaScript or HTTP. Instead, expose a \[=duration=\]
between two such \[=moments=\].

For measuring time across multiple UA executions, create \[=moments=\]
using the \[=current coarsened wall time=\] or (if you need higher
precision in \[=environment settings object/cross-origin isolated
capability\|cross-origin-isolated contexts=\]) an \[=environment
settings object=\]\'s \[=environment settings object/current wall
time=\]. The [current coarsened wall time] is the result of calling \[=coarsen time=\] with the \[=wall
clock=\]\'s \[=wall clock/unsafe current time=\].

An \[=environment settings object=\] \|settingsObject:environment
settings object\|\'s [current wall time] is the result of the
following steps:

1. Let \|unsafeWallTime:unsafe moment on the wall clock\| be the
 \[=wall clock=\]\'s \[=wall clock/unsafe current time=\].
2. Return the result of calling \[=coarsen time=\] with
 \|unsafeWallTime\| and \|settingsObject\|\'s \[=environment settings
 object/cross-origin isolated capability=\].

When using \[=moments=\] from the \[=wall clock=\], be sure that your
design accounts for situations when the user adjusts their clock either
forward or backward.

\[=Moments=\] from the \[=wall clock=\] can be represented in JavaScript
by passing the number of milliseconds from the \[=Unix epoch=\] to that
\[=moment=\] into the {{Date}} constructor, or by passing the number of
nanoseconds from the \[=Unix epoch=\] to that \[=moment=\] into the
[Temporal.Instant] constructor.

Avoid sending similar representations between computers, as doing so
will expose the user\'s clock skew, which is a \[=tracking vector=\].
Instead, use an approach similar to \[=monotonic clock=\] \[=moments=\]
of sending a duration between two \[=moments=\].

### Examples

The time a DOM event happens can be reported using:

7. Initialize \|event\|\'s {{Event/timeStamp}} attribute to
 \[=this=\]\'s \[=relevant settings object=\]\'s \[=environment
 settings object/current relative timestamp=\].

The age of an error report can be computed using:

7. Initialize \|report\|\'s [generation
 time] to \|settings\|\'
 \[=environment settings object/current monotonic time=\].

Later:

2. Let \|data\| be a map with the following key/value pairs:

 age
 : The number of milliseconds between \|report\|\'s [generation
 time] and \|context\|\'s
 \[=relevant settings object=\]\'s \[=environment settings
 object/current monotonic time=\], rounded to the nearest
 integer.
 : \...

Multi-day attribution report expirations can be handled as:

2. Let \|source\| be a new attribution source struct whose items are:

 \...\
 source time
 : \|context\|\'s \[=environment settings object/current wall
 time=\]

 expiry
 : [parse a duration
 string] from
 `|value|["expiry"]`

Days later:

2. If \|context\|\'s \[=environment settings object/current wall
 time=\] is less than \|source\|\'s source time + \|source\|\'s
 expiry, send a report.

### Time Origin

The [Unix epoch] is the \[=moment=\] on the \[=wall
clock=\] corresponding to 1 January 1970 00:00:00 UTC.

Each group of \[=environment settings objects=\] that could possibly
communicate in any way has an [estimated monotonic time of the Unix
epoch], a \[=moment=\] on the \[=monotonic clock=\], whose value
is initialized by the following steps:

1. Let \|wall time:unsafe moment on the wall clock\| be the \[=wall
 clock=\]\'s \[=wall clock/unsafe current time=\].
2. Let \|monotonic time:unsafe moment on the monotonic clock\| be the
 \[=monotonic clock=\]\'s \[=monotonic clock/unsafe current time=\].
3. Let \|epoch time:unsafe moment on the monotonic clock\| be
 `|monotonic time| - (|wall time| - [=Unix epoch=])`
4. Initialize the \[=estimated monotonic time of the Unix epoch=\] to
 the result of calling \[=coarsen time=\] with \|epoch time\|.

::: issue
The above set of settings-objects-that-could-possibly-communicate needs
to be specified better. It\'s similar to [familiar
with] but includes
{{Worker}}s.

Performance measurements report a \[=duration=\] from a \[=moment=\]
early in the initialization of a relevant \[=environment settings
object=\]. That \[=moment=\] is stored in that settings object\'s
\[=environment settings object/time origin=\].

To [get time origin timestamp], given a \[=/global object=\]
\|global:global object\|, run the following steps, which return a
\[=duration=\]:

1. Let \|timeOrigin:moment on the monotonic clock\| be \|global\|\'s
 \[=relevant settings object=\]\'s \[=environment settings
 object/time origin=\].

 In {{Window}} contexts, this value represents the time when
 \[=navigate\|navigation has started=\]. In {{Worker}} and
 {{ServiceWorker}} contents, this value represent the time when the
 \[=run a worker\|worker is run=\]. \[\[service-workers\]\]

2. Return the \[=duration from=\] the \[=estimated monotonic time of
 the Unix epoch=\] to \|timeOrigin\|.

The value returned by \[=get time origin timestamp=\] is approximately
the time after the \[=Unix epoch=\] that \|global\|\'s \[=environment
settings object/time origin=\] happened. It may differ from the value
returned by Date.now() executed at the time origin, because the former
is recorded with respect to a monotonic clock that is not subject to
system and user clock adjustments, clock skew, and so on.

The [coarsen time] algorithm, given an \[=unsafe
moment=\] \|timestamp:unsafe moment\| on some \[=clock=\] and an
optional boolean \|crossOriginIsolatedCapability:boolean\| (default
false), runs the following steps:

1. Let \|time resolution:duration\| be 100 microseconds, or a higher
 implementation-defined value.
2. If \|crossOriginIsolatedCapability\| is true, set \|time
 resolution\| to be 5 microseconds, or a higher
 implementation-defined value.
3. In an implementation-defined manner, coarsen and potentially jitter
 \|timestamp\| such that its resolution will not exceed \|time
 resolution\|.
4. Return \|timestamp\| as a \[=moment=\].

The [relative high resolution time] given an \[=unsafe
moment=\] from the \[=monotonic clock=\] \|time:unsafe moment on the
monotonic clock\| and a \[=Realm/global object=\] \|global:global
object\|, is the \[=duration=\] returned from the following steps:

1. Let \|coarse time:moment on the monotonic clock\| be the result of
 calling \[=coarsen time=\] with \|time\| and \|global\|\'s
 \[=relevant settings object=\]\'s \[=environment settings
 object/cross-origin isolated capability=\].
2. Return the \[=relative high resolution coarse time=\] for \|coarse
 time\| and \|global\|.

The [relative high resolution coarse time] given a
\[=moment=\] from the \[=monotonic clock=\] \|coarseTime:moment on the
monotonic clock\| and a \[=Realm/global object=\] \|global:global
object\|, is the \[=duration from=\] \|global\|\'s \[=relevant settings
object=\]\'s \[=environment settings object/time origin=\] to
\|coarseTime\|.

The [current high resolution time] given a \[=/global
object=\] \|current global:global object\| must return the result of
\[=relative high resolution time=\] given \[=unsafe shared current
time=\] and \|current global\|.

The [coarsened shared current time] given an optional
boolean \|crossOriginIsolatedCapability:boolean\| (default false), must
return the result of calling \[=coarsen time=\] with the \[=unsafe
shared current time=\] and \|crossOriginIsolatedCapability\|.

The [unsafe shared current time] must return the
\[=monotonic clock/unsafe current time=\] of the monotonic clock.

### The [DOMHighResTimeStamp] typedef

The {{DOMHighResTimeStamp}} type is used to store a \[=duration=\] in
milliseconds. Depending on its context, it may represent the
\[=moment=\] that is this \[=duration=\] after a base \[=moment=\] like
a \[=environment settings object/time origin=\] or the \[=Unix epoch=\].

``` idl

 typedef double DOMHighResTimeStamp;

```

A {{DOMHighResTimeStamp}} SHOULD represent a time in milliseconds
accurate enough to allow measurement while preventing timing attacks -
see (#clock-resolution) for additional considerations.

A {{DOMHighResTimeStamp}} is a {{double}}, so it can only represent an
epoch-relative time---the number of milliseconds from the \[=Unix
epoch=\] to a \[=moment=\]---to a finite resolution. For \[=moments=\]
in 2023, that resolution is approximately 0.2 microseconds.

::: section
### The [EpochTimeStamp] typedef

``` idl

 typedef unsigned long long EpochTimeStamp;

```

The use of \`EpochTimeStamp\`, known previously as \`DOMTimeStamp\`, is
discouraged. Wherever possible use {{DOMHighResTimeStamp}} instead.

A {{EpochTimeStamp}} represents an integral number of milliseconds from
the \[=Unix epoch=\] to a given \[=moment=\] on the \[=wall clock=\],
excluding leap seconds. Specifications that use this type define how the
number of milliseconds are interpreted.

### The [Performance] interface

``` idl

 [Exposed=(Window,Worker)]
 interface Performance : EventTarget {
 DOMHighResTimeStamp now();
 readonly attribute DOMHighResTimeStamp timeOrigin;
 [Default] object toJSON();
 };

```

::: section
### \`now()\` method

The [now()] method MUST return the number of milliseconds in the
current high resolution time given \[=this=\]\'s \[=relevant global
object=\] (a \[=duration=\]).

The time values returned when calling the {{Performance/now()}} method
on {{Performance}} objects with the same \[=environment settings
object/time origin=\] MUST use the same \[=monotonic clock=\]. The
difference between any two chronologically recorded time values returned
from the {{Performance/now()}} method MUST never be negative if the two
time values have the same \[=environment settings object/time origin=\].

::: section
### \`timeOrigin\` attribute

The [timeOrigin] attribute MUST return the number of milliseconds
in the \[=duration=\] returned by \[=get time origin timestamp=\] for
the relevant global object of \[=this=\].

The time values returned when getting
{{Performance}}.{{Performance/timeOrigin}} MUST use the same
\[=monotonic clock=\] that is shared by \[=environment settings
object/time origins=\], and whose reference point is the
\[\[ECMA-262\]\]
[time] definition -
see \[\[\[#sec-security\]\]\].

::: section
### \`toJSON()\` method

When [toJSON()] is called, run \[\[WEBIDL\]\]\'s default toJSON
steps.

:::: section
## Extensions to \`WindowOrWorkerGlobalScope\` mixin

### The `performance` attribute

The [performance] attribute on the interface mixin
{{WindowOrWorkerGlobalScope}} allows access to performance related
attributes and methods from the \[=Realm/global object=\].

``` idl

 partial interface mixin WindowOrWorkerGlobalScope {
 [Replaceable] readonly attribute Performance performance;
 };

```

### Security Considerations

:::: section
### Clock resolution

Access to accurate timing information, both for measurement and
scheduling purposes, is a common requirement for many applications. For
example, coordinating animations, sound, and other activity on the page
requires access to high-resolution time to provide a good user
experience. Similarly, measurement enables developers to track the
performance of critical code components, detect regressions, and so on.

However, access to the same accurate timing information can sometimes be
also used for malicious purposes by an attacker to guess and infer data
that they can\'t see or access otherwise. For example, cache attacks,
statistical fingerprinting and micro-architectural attacks are a privacy
and security concern where a malicious web site may use high resolution
timing data of various browser or application-initiated operations to
differentiate between subset of users, identify a particular user or
reveal unrelated but same-process user data - see \[\[?CACHE-ATTACKS\]\]
and \[\[SPECTRE\]\] for more background.

This specification defines an API that provides sub-millisecond time
resolution, which is more accurate than the previously available
millisecond resolution exposed by {{EpochTimeStamp}}. However, even
without this new API an attacker may be able to obtain high-resolution
estimates through repeat execution and statistical analysis.

To ensure that the new API does not significantly improve the accuracy
or speed of such attacks, the minimum resolution of the
{{DOMHighResTimeStamp}} type should be inaccurate enough to prevent
attacks.

Where necessary, the user agent should set higher resolution values to
\|time resolution\| in \[=coarsen time=\]\'s processing model, to
address privacy and security concerns due to architecture or software
constraints, or other considerations.

In order to mitigate such attacks user agents may deploy any technique
they deem necessary. Deployment of those techniques may vary based on
the browser\'s architecture, the user\'s device, the content and its
ability to maliciously read cross-origin data, or other practical
considerations.

These techniques may include:

- Resolution reduction.
- Added jitter.
- Abuse detection and/or API call throttling.

Mitigating such timing side-channel attacks entirely is practically
impossible: either all operations would have to execute in a time that
does not vary based on the value of any confidential information, or the
application would need to be isolated from any time-related primitives
(clock, timers, counters, etc). Neither is practical due to the
associated complexity for the browser and application developers and the
associated negative effects on performance and responsiveness of
applications.

::: note
Clock resolution is an unsolved and evolving area of research, with no
existing industry consensus or definitive set of recommendations that
applies to all browsers. To track the discussion, refer to [Issue
79](https://github.com/w3c/hr-time/issues/79).

::: section
### Clock drift

This specification also defines an API that provides sub-millisecond
time resolution of the zero time of the time origin, which requires and
exposes a monotonic clock to the application, and that must be shared
across all the browser contexts. The monotonic clock does not need to be
tied to physical time, but is recommended to be set with respect to the
\[\[ECMA-262\]\] definition of time to avoid exposing new fingerprint
entropy about the user --- e.g. this time can already be easily obtained
by the application, whereas exposing a new logical clock provides new
information.

However, even with the above mechanism in place, the monotonic clock may
provide additional [clock
drift](https://en.wikipedia.org/wiki/Clock_drift) resolution. Today, the
application can timestamp the time-of-day and monotonic time values (via
Date.now() and {{Performance/now()}}) at multiple points within the same
context and observe drift between them---e.g. due to automatic or user
clock adjustments. With the {{Performance/timeOrigin}} attribute, the
attacker can also compare the \[=environment settings object/time
origin=\], as reported by the monotonic clock, against the current
time-of-day estimate of the \[=environment settings object/time
origin=\] (i.e. the difference between \`performance.timeOrigin\` and
\`Date.now() - performance.now()\`) and potentially observe clock drift
between these clocks over a longer time period.

In practice, the same time drift can be observed by an application
across multiple navigations: the application can record the logical time
in each context and use a client or server time synchronization
mechanism to infer changes in the user\'s clock. Similarly, lower-layer
mechanisms such as TCP timestamps may reveal the same high-resolution
information to the server without the need for multiple visits. As such,
the information provided by this API should not expose any significant
or previously unavailable entropy about the user.

### Privacy Considerations

The current definition of \[=environment settings object/time origin=\]
for a {{Document}} exposes the total time of cross-origin redirects
prior to the request arriving at the document\'s origin. This exposes
cross-origin information, however it\'s not yet decided how to mitigate
this without causing major breakages to performance metrics.

To track the discussion, refer to [Navigation Timing Issue
160](https://github.com/w3c/navigation-timing/issues/160).

Some conformance requirements are phrased as requirements on attributes,
methods or objects. Such requirements are to be interpreted as
requirements on user agents.

## Acknowledgments

Thanks to Arvind Jain, Angelos D. Keromytis, Boris Zbarsky, Jason Weber,
Karen Anderson, Nat Duca, Philippe Le Hegaret, Ryosuke Niwa, Simha
Sethumadhavan, Todd Reifsteck, Tony Gentilcore, Vasileios P. Kemerlis,
Yoav Weiss, and Yossef Oren for their contributions to this work.
