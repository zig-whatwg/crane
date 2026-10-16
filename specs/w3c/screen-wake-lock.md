
This document specifies an API that allows web applications to request a
screen wake lock. Under the right conditions, and if allowed, the screen
wake lock prevents the system from turning off a device\'s screen.

Implementors need to be aware that this specification is extremely
unstable. **Implementors who are not taking part in the discussions will
find the specification changing out from under them in incompatible
ways.** Vendors interested in implementing this specification before it
eventually reaches the Candidate Recommendation phase should [subscribe
to the repository on
GitHub](https://github.com/w3c/screen-wake-lock/issues) and take part in
the discussions.

## Introduction

Modern operating systems achieve longer battery life by implementing
aggressive power management, meaning that shortly after the lack of user
activity, a host device may lower the screen brightness, turn the screen
off and even let the CPU go into a deep power state, limiting power
usage as much as possible.

Though this is great for prolonged battery life, it can sometime hinder
some use cases such as scanning a barcode, reading an ebook, following a
recipe, presenting to an audience, and so on. See also
\[\[\[wake-lock-use-cases\]\]\].

A wake lock will generally prevent something from happening, but UAs
(and the underlying OS) may time limit a wake lock given the battery
status (wall power connected, discharging, low battery level), or even
disallow wake locks in the case a power saving mode is activated.

## Wake Locks

This specification defines the following [wake lock type]:

1. A [screen wake lock] prevents the screen from
 turning off. Only visible documents can acquire the screen wake
 lock.

In the API, the \[=wake lock types=\] are represented by the
{{WakeLockType}} enum values.

Other specifications might define different wake lock types.

### Policy control

The Screen Wake Lock API defines a \[=policy-controlled feature=\]
identified by the string \`\"screen-wake-lock\"\`. Its
\[=policy-controlled feature/default allowlist=\] is \`\'self\'\`.

The \[=policy-controlled feature/default allowlist=\] of \`\'self\'\`
allows wake lock usage in same-origin nested frames but prevents
third-party content from using wake locks.

Third-party usage can be selectively enabled by adding
\`allow=\"screen-wake-lock\"\` attribute to the frame container element:

```

 <iframe src="https://third-party.com" allow="screen-wake-lock"/></iframe>

```

Alternatively, the Screen Wake Lock API can be disabled completely by
specifying the permissions policy in a HTTP response header:

```

 Permissions-Policy: screen-wake-lock=()

```

See \[\[\[PERMISSIONS-POLICY\]\]\] for more details.

### Permissions and user prompts

The \[\[PERMISSIONS\]\] API provides a uniform way for websites to
request permissions from users and query which permissions they have.

A user agent can [deny a wake lock] of a particular wake lock type
for a particular {{Document}} by any implementation-specific reason,
such as platform setting or user preference.

It is RECOMMENDED that a user agent show some form of unobtrusive
notification that informs the user when a wake lock is active, as well
as provides the user with the means to \[=screen wake lock permission
revocation algorithm\|block=\] the ongoing operation, or simply dismiss
the notification.

## The \`\"screen-wake-lock\"\` powerful feature

The \`\"screen-wake-lock\"\` powerful feature enables the capability
defined by this specification.

## Permission algorithms

The \`\"screen-wake-lock\"\` powerful feature defines a \[=powerful
feature/permission revocation algorithm=\]. To invoke the [Screen Wake
Lock permission revocation algorithm], run these steps:

1. Let \|document:Document\| be the \[=current global object=\]\'s
 \[=associated Document=\].
2. Let \|lockList\| be
 \|document\|.{{Document/\[\[ActiveLocks\]\]}}\[\"\`screen\`\"\].
3. \[=list/For each=\] \|lock:WakeLockSentinel\| in \|lockList\|:
 1. Run release a wake lock with \|document\|, \|lock\|, and
 {{WakeLockType/\"screen\"}}.

### Concepts

The task source for the tasks mentioned in this specification is the
[screen wake lock task source].

The term [platform wake lock] refers to platform interfaces with
which the user agent interacts to query state and acquire and release a
wake lock.

A platform wake lock can be defined by the underlying platform (e.g. in
a native wake lock framework) or by the user agent, if it has direct
hardware control.

## Extensions to the \`Document\` interface

### Internal slots

 Internal slot Initial value Description
 ------------------------------- -------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------
 [\[\[\\ActiveLocks\]\]] An ordered map mapping wake lock types to empty lists. An ordered map of wake lock types to a list of {{WakeLockSentinel}} objects associated with this {{Document}}.

## Extensions to the \`Navigator\` interface

``` idl

 [SecureContext]
 partial interface Navigator {
 [SameObject] readonly attribute WakeLock wakeLock;
 };

```

## The [WakeLock] interface

The {{WakeLock}} interface allows a document to acquire a \[=screen wake
lock=\].

``` idl

 [SecureContext, Exposed=(Window)]
 interface WakeLock {
 Promise<WakeLockSentinel> request(optional WakeLockType type = "screen");
 };

```

### The [request()] method

The `request(|type:WakeLockType|)` method steps are:

1. Let \|document:Document\| be \[=this=\]\'s \[=relevant global
 object=\]\'s \[=associated Document=\].
2. If \|document\| is not \[=Document/fully active=\], return \[=a
 promise rejected with=\] with a {{\"NotAllowedError\"}}
 {{DOMException}}.
3. If \|document\| is not \[=allowed to use=\] the \[=policy-controlled
 feature=\] named \"\`screen-wake-lock\`\", return \[=a promise
 rejected with=\] a {{\"NotAllowedError\"}} {{DOMException}}.
4. If the user agent denies the wake lock of this \|type\| for
 \|document\|, return \[=a promise rejected with=\] a
 {{\"NotAllowedError\"}} {{DOMException}}.
5. If \|document\|\'s \[=Document/visibility state=\] is
 \"\`hidden\`\", return \[=a promise rejected with=\]
 {{\"NotAllowedError\"}} {{DOMException}}.
6. Let \|promise:Promise\| be \[=a new promise=\].
7. Run the following steps in parallel:
 1. Let \|state:PermissionState\| be the result of requesting
 permission to use \"\`screen-wake-lock\`\".
 2. If \|state\| is {{PermissionState/\"denied\"}}, then:
 1. Queue a global task on the screen wake lock task source
 given \|document\|\'s relevant global object to reject
 \|promise\| with a {{\"NotAllowedError\"}} {{DOMException}}.
 2. Abort these steps.
 3. Queue a global task on the screen wake lock task source given
 \|document\|\'s relevant global object to run these steps:
 1. If \|document\| is not \[=Document/fully active=\], then:
 1. Reject \|promise\| with a {{\"NotAllowedError\"}}
 {{DOMException}}.
 2. Abort these steps.
 2. If \|document\|\'s \[=Document/visibility state=\] is
 \"\`hidden\`\", then:
 1. Reject \|promise\| with a {{\"NotAllowedError\"}}
 {{DOMException}}.
 2. Abort these steps.
 3. If
 \|document\|.{{Document/\[\[ActiveLocks\]\]}}\[\"\`screen\`\"\]
 \[=list/is empty=\], then invoke the following steps in
 parallel:
 1. Invoke acquire a wake lock with
 {{WakeLockType/\"screen\"}}.
 The acquire a wake lock algorithm may ultimately be
 unable to acquire a lock from the operating system, but
 this is indistinguishable from a successful lock
 acquisition to avoid user fingerprinting (failure to
 acquire a lock can indicate low battery levels, for
 example).
 4. Let \|lock:WakeLockSentinel\| be a new {{WakeLockSentinel}}
 object with its {{WakeLockSentinel/type}} attribute set to
 \|type\|.
 5. \[=List/Append=\] \|lock\| to
 \|document\|.{{Document/\[\[ActiveLocks\]\]}}\[\"\`screen\`\"\].
 6. Resolve \|promise\| with \|lock\|.
8. Return \|promise\|.

## The [WakeLockSentinel] interface

``` idl

 [SecureContext, Exposed=(Window)]
 interface WakeLockSentinel : EventTarget {
 readonly attribute boolean released;
 readonly attribute WakeLockType type;
 Promise<undefined> release();
 attribute EventHandler onrelease;
 };

```

A {{WakeLockSentinel}} object provides a handle to a platform wake lock,
and it holds on to it until it is either manually released or until the
underlying platform wake lock is released. Its existence keeps a
platform wake lock for a given wake lock type active, and releasing all
{{WakeLockSentinel}} instances of a given wake lock type will cause the
underlying platform wake lock to be released.

See auto-releasing wake locks, handling document loss of full activity
and handling document loss of visibility for circumstances under which a
given wake lock may be released by the user agent.

### Internal slots

{{WakeLockSentinel}} instances are created with the following [internal
slots]:

 Internal slot Initial value Description (non-normative)
 ---------------------------- --------------- -----------------------------------------------------------
 [\[\[\\Released\]\]] \`false\` Whether the given {{WakeLockSentinel}} has been released.

### The [released] attribute

The {{WakeLockSentinel/released}} getter steps are to return
\[=this=\].{{WakeLockSentinel/\[\[Released\]\]}}.

Once a {{WakeLockSentinel}} is released, {{WakeLockSentinel/released}}
becomes \`true\`, and the value never changes again.

### The [type] attribute

The {{WakeLockSentinel/type}} getter steps are to return \[=this=\]\'s
wake lock type.

### The [release()] method

The {{WakeLockSentinel/release()}} method steps are:

1. If this\'s {{WakeLockSentinel/\[\[Released\]\]}} is \`false\`, then
 run release a wake lock with \|lock:WakeLockSentinel\| set to this
 and \|type:WakeLockType\| set to the value of this\'s
 {{WakeLockSentinel/type}} attribute.
2. Return a promise resolved with \`undefined\`.

### The [onrelease] attribute

The {{WakeLockSentinel/onrelease}} attribute is an event handler IDL
attribute for the \"`onrelease`\" event handler, whose event handler
event type is \"[`release`]\".

It is used to notify scripts that a given {{WakeLockSentinel}} object\'s
handle has been released, either due to the
{{WakeLockSentinel/release()}} method being called or because the wake
lock was released by the user agent.

A {{WakeLockSentinel}} object\'s handle being released does not
necessarily mean the platform wake lock for a given wake lock type was
released. That depends on the platform wake lock\'s
{{Document/\[\[ActiveLocks\]\]}} internal slot. See release a wake lock.

\[\[\[#onrelease-example\]\]\] contains an example of how to use the
{{WakeLockSentinel/onrelease}} event handler.

### Garbage collection

While a {{WakeLockSentinel}} object has one or more event listeners
registered for \"`release`\", and the {{WakeLockSentinel}} object
hasn\'t already been released, there MUST be a strong reference from the
{{Window}} object that the {{WakeLockSentinel}} object\'s constructor
was invoked from to the {{WakeLockSentinel}} object itself.

While there is a task queued by an {{WakeLockSentinel}} object on the
screen wake lock task source, there MUST be a strong reference from the
{{Window}} object that the {{WakeLockSentinel}} object\'s constructor
was invoked from to that {{WakeLockSentinel}} object.

## The [WakeLockType] enum

For the purpose of wake lock type description, this specification
defines the following enumeration to represent \[=wake lock types=\]:

``` idl

 enum WakeLockType { "screen" };

```

[screen]
: Screen wake lock type.

## Managing Wake Locks

This section applies to each wake lock type equally and independently,
unless a particular wake lock type is explicitly mentioned.

The user agent [acquires the wake lock] by requesting the
underlying operating system to apply the lock. A possible return value
of the request to the underlying operating system is not checked. In
other words, user agents MUST treat wake lock acquisition as
**advisory-only**.

Conversely, the user agent [releases the wake lock] by requesting the
underlying operating system to no longer apply the wake lock. The lock
is considered released only when the request to the operating system
succeeds.

The wake lock is [applicable] if the state of the operating
system permits application of the lock (e.g. there is sufficient battery
charge).

The screen wake lock MUST NOT be applicable after the screen is manually
switched off by the user until it is switched on again.

Whether the wake lock is applicable is a transient condition, e.g. when
the battery charge is low but then the battery is recharged. So like the
visibility requirement, this is part of automatic wake lock management
and not part of the decision process whether to allow or deny the wake
lock.

### [Auto-releasing wake locks]

A user agent may release a wake lock at any time. For example, when:

- It detects abnormal operation: such as infinite loops and tasks
 exceeding imposed time limits (if any).
- Battery is considered low and discharging.
- The user turns on some kind of device power conservation mode.
- The operating system is configured to dim or turn off the screen based
 on the user presence state.

### [Handling document loss of full activity]

When a {{Document}} \|document:Document\| becomes no longer
\[=Document/fully active=\], the user agent must run these steps:

1. \[=list/For each=\] \|lock:WakeLockSentinel\| in
 \|document\|.{{Document/\[\[ActiveLocks\]\]}}\[\"\`screen\`\"\]:
 1. Run release a wake lock with \|document\|, \|lock\|, and
 {{WakeLockType/\"screen\"}}.

### [Handling document loss of visibility]

This specification defines the following \[=page visibility change
steps=\] with \[=Document/visibility state=\] \|state\| and
\|document:Document\|:

1. If \|state\| is not \"\`hidden\`\", abort these steps.
2. \[=list/For each=\] \|lock:WakeLockSentinel\| in
 \|document\|.{{Document/\[\[ActiveLocks\]\]}}\[\"\`screen\`\"\]:
 1. Run release a wake lock with \|document\|, \|lock\|, and
 {{WakeLockType/\"screen\"}}.

### Acquire wake lock algorithm

To [acquire a wake lock] for a given \|type:WakeLockType\|, run
these steps:

1. If the wake lock for type \|type\| is not applicable, abort these
 steps.
2. Ask the underlying operating system to acquire the wake lock of type
 \|type\|.

### Release wake lock algorithm

To [release a wake lock] for a given \|document:Document\|,
\|lock:WakeLockSentinel\|, and \|type:WakeLockType\|, run these steps:

1. If \|document\|.{{Document/\[\[ActiveLocks\]\]}}\[\|type\|\] does
 not contain \|lock\|, abort these steps.
2. Remove \|lock\| from
 \|document\|.{{Document/\[\[ActiveLocks\]\]}}\[\|type\|\].
3. If \|document\|.{{Document/\[\[ActiveLocks\]\]}}\[\|type\|\]
 \[=list/is empty=\], then run the following steps in parallel:
 1. Ask the underlying operating system to release the wake lock of
 type \|type\| and let \|success:boolean\| be \`true\` if the
 operation succeeded, or else \`false\`.
 2. If \|success\| is \`true\` and \|type\| is \`\"screen\"\` run
 the following:
 1. Reset the platform-specific inactivity timer after which the
 screen is actually turned off.

 Resetting the inactivity timer prevents the screen from going
 blank immediately after the wake lock is released.
4. Set \|lock\|\'s {{WakeLockSentinel/\[\[Released\]\]}} to \`true\`.
5. Fire an event named \"`release`\" at \|lock\|.

## Security considerations

Screen wake locks can cause various device components - particularly the
display - to operate at higher power levels than they otherwise would.
This can lead to undesirable effects, such as preventing the device from
automatically locking itself and faster battery depletion. Faster
battery depletion is of particular concern for mobile devices, which
often don\'t have a stationary power source readily available. Complete
battery depletion at an unexpected time can lead to inability of the
user to make or receive calls and use network services, including the
emergency call service.

Implementations MAY ignore requests for screen wake lock if, for
example, the battery capacity is low, or the user has put their device
in a power-saving mode.

## Privacy considerations

It is RECOMMENDED that a user agent provide some UI or indicator that
allows the user to know when a screen wake lock is active. Providing
such a UI could help end users to identify if a particular web
application is having a negative energy impact on the device, and allow
them to take action if so desired.

## Examples

```

 function tryKeepScreenAlive(minutes) {
 navigator.wakeLock.request("screen").then(lock => {
 setTimeout(() => lock.release(), minutes * 60 * 1000);
 });
 }

 tryKeepScreenAlive(10);

```

This example allows the user to request a screen wake lock by clicking
on a checkbox, but updates the checkbox checked state in case the wake
lock state changes:

```

 const checkbox = document.createElement("input");
 checkbox.setAttribute("type", "checkbox");
 document.body.appendChild(checkbox);

 const sentinel = await navigator.wakeLock.request("screen");
 checkbox.checked = !sentinel.released;
 sentinel.onrelease = () => checkbox.checked = !sentinel.released;

```

In this example, two different wake lock requests are created and
released independently:

```

 let lock1 = await navigator.wakeLock.request("screen");
 let lock2 = await navigator.wakeLock.request("screen");

 lock1.release();
 lock2.release();

```

This specification defines conformance criteria for a single product: a
[user agent] that implements the interfaces that it contains.

## Acknowledgments

We would like to offer our sincere thanks to Mounir Lamouri, Sergey
Konstantinov, Matvey Larionov, Dominique Hazael-Massieux, Domenic
Denicola, Thomas Steiner, Anne van Kesteren for their contributions to
this work.

## Changes

This section documents the changes since previous publications.

## Changes since the 14 December 2017 CR

- Convert the document to purely screen wake lock, and move system lock
 to a new specification.
- Rewrite user-visible API.
- Add an if aborted step to `WakeLock.request()` to deal with hidden
 documents.
- Add an IDL Index.
- Remove duplicate normative statements.
- Modernize the examples.
- Use internal slots instead of prose.
- Add info on when the user agent may release a wake lock.
- Handle document visibility.
- Make \`ScreenWakeLock\` constructable.
- Integrate optional permission prompting.
- Handle loss of full activity, as well as running in workers.
- Rewrite the introduction section.
- Rename Feature Policy to Permissions Policy.
- Add `WakeLockSentinel.released`.
- Define a task source for tasks in this specification.
