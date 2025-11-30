Initial Author of this Specification was Ian Hickson, Google Inc., with
the following copyright statement:\
© Copyright 2004-2011 Apple Computer, Inc., Mozilla Foundation, and
Opera Software ASA. You are granted a license to use, reproduce and
create derivative works of this document.

All subsequent changes since 26 July 2011 done by the W3C WebRTC Working
Group (and previously the Device APIs Working Group) are under the
following [Copyright](https://www.w3.org/policies/#copyright) ©
2011-2023 [World Wide Web Consortium](https://www.w3.org/). [W3C]{.abbr
title="World Wide Web Consortium"}^®^
[liability](https://www.w3.org/policies/#Legal_Disclaimer),
[trademark](https://www.w3.org/policies/#W3C_Trademarks) and [permissive
document license](https://www.w3.org/copyright/software-license/) rules
apply.

::: {#abstract .section}
This document defines a set of JavaScript APIs that allow local media,
including audio and video, to be requested from a platform.
:::

::: {#sotd .section}
This document is not complete. The API is based on preliminary work done
in the WHATWG.

Before this document proceeds to Proposed Recommendation, the WebRTC
Working Group intends to address [issues that emerged from wide
review](https://www.w3.org/PM/horizontal/review.html?shortname=mediacapture-streams).
:::

::: {#intro .section .informative}
## Introduction

This document defines APIs for requesting access to local multimedia
devices, such as microphones or video cameras.

This document also defines the MediaStream API, which provides the means
to control where multimedia stream data is consumed, and provides some
control over the devices that produce the media. It also exposes
information about devices able to capture and render media.
:::

::: {#conformance .section}
This specification defines conformance criteria that apply to a single
product: the [User Agent]{.dfn} that implements the interfaces that it
contains.

Conformance requirements phrased as algorithms or specific steps may be
implemented in any manner, so long as the end result is equivalent. (In
particular, the algorithms defined in this specification are intended to
be easy to follow, and not intended to be performant.)

Implementations that use ECMAScript \[\[ECMA-262\]\] to implement the
APIs defined in this specification must implement them in a manner
consistent with the ECMAScript Bindings defined in the Web IDL
specification \[\[WEBIDL\]\], as this specification uses that
specification and terminology.
:::

::: section
## Terminology

[source]{.dfn export=""}

:   A source is the \"thing\" providing the source of a media stream
    track. The source is the broadcaster of the media itself. A source
    can be a physical webcam, microphone, local video or audio file from
    the user\'s hard drive, network resource, or static image. Note that
    this document describes the use of microphone and camera type
    sources only, the use of other source types is described in other
    documents.

    An application that has no prior authorization regarding sources is
    only given the number of available sources, their type and any
    relationship to other devices. Additional information about sources
    can become available when applications are authorized to use a
    source (see [](#access-control-model)).

    Sources **do not** have constraints --- tracks have constraints.
    When a source is connected to a track, it must produce media that
    conforms to the constraints present on that track, to that track.
    Multiple tracks can be attached to the same source. \[=User Agent=\]
    processing, such as downsampling, MAY be used to ensure that all
    tracks have appropriate media.

    Sources have constrainable properties which have \[=capabilities=\]
    and \[=settings=\] exposed on tracks. While the constrainable
    properties are \"owned\" by the source, sources MAY be able to
    accommodate different demands at once. For this reason, capabilities
    are common to any (multiple) tracks that happen to be using the same
    source, whereas settings MAY differ per track (e.g., if two
    different track objects bound to the same source query capability
    and settings information, they will get back the same capabilities,
    but may get different settings that are tailored to satisfy their
    individual constraints).

[Setting]{.dfn lt="settings"} (Source Setting)

:   A setting refers to the immediate, current value of the source\'s
    constrainable properties. Settings are always read-only.

    A source conditions may dynamically change, such as when a camera
    switches to a lower frame rate due to low light conditions. In these
    cases the tracks related to the affected source might not satisfy
    the set constraints any longer. The platform SHOULD try to minimize
    such excursions as far as possible, but will continue to deliver
    media even when a temporary or permanent condition exists that
    prevents satisfying the constraints.

    Although settings are a property of the source, they are only
    exposed to the application through the tracks attached to the
    source. This is exposed via the ConstrainablePattern interface.

[Capability]{.dfn lt="capabilities"}

:   For each constrainable property, there is a capability that
    describes whether it is supported by the source and if so, the range
    of supported values. As with settings, capabilities are exposed to
    the application via the ConstrainablePattern interface.

    The values of the supported capabilities must be normalized to the
    ranges and enumerated types defined in this specification.

    A {{MediaStreamTrack/getCapabilities()}} call on a track returns the
    same underlying per-source capabilities for all tracks connected to
    the source.

    This API is intentionally simplified. Capabilities are not capable
    of describing interactions between different values. For instance,
    it is not possible to accurately describe the capabilities of a
    camera that can produce a high resolution video stream at a low
    frame rate and lower resolutions at a higher frame rate.
    Capabilities describe the complete range of each value. Interactions
    between constraints are exposed by attempting to apply constraints.

[Constraint]{.dfn}s

:   Constraints provide a general control surface that allows
    applications to both select an appropriate source for a track and,
    once selected, to influence how a source operates.

    Constraints limit the range of operating modes that a source can use
    when providing media for a track. Without provided track
    constraints, implementations are free to select a source\'s settings
    from the full ranges of its supported capabilities. Implementations
    may also adjust source settings at any time within the bounds
    imposed by all applied constraints.

    {{MediaDevices/getUserMedia()}} uses constraints to help select an
    appropriate source for a track and configure it. Additionally, the
    ConstrainablePattern interface on tracks includes an API for
    dynamically changing the track\'s constraints at any later time.

    A track will not be connected to a source using
    {{MediaDevices/getUserMedia()}} if its initial constraints cannot be
    satisfied. However, the ability to meet the constraints on a track
    can change over time, and constraints can be changed. If
    circumstances change such that constraints cannot be met, the
    ConstrainablePattern interface defines an appropriate error to
    inform the application.
    \[\[\[#the-model-sources-sinks-constraints-and-settings\]\]\]
    explains how constraints interact in more detail.

    For each constrainable property, a constraint exists whose name
    corresponds with the relevant source setting name and capability
    name.

    A constraint falls into one of three groups, depending on its place
    in the constraints structure. The groups are:

    - [required constraints]{.dfn} are all
      [non-advanced]{lt="advanced constraints"} constraints that are
      required.
    - [optional basic constraints]{.dfn} are the remaining
      [non-advanced]{lt="advanced constraints"} constraints.
    - [advanced constraints]{.dfn} are all constraints specified using
      the [`advanced`](#dom-constraints-advanced) keyword.

    In general, \[=User Agents=\] will have more flexibility to optimize
    the media streaming experience the fewer constraints are applied, so
    application authors are strongly encouraged to use required
    constraints sparingly.
:::

:::::::::::::::::::::::::::::::::::::::::::::::::: {#stream-api .section}
## MediaStream API

::: section
## Introduction

The two main components in the MediaStream API are the
{{MediaStreamTrack}} and {{MediaStream}} interfaces. The
{{MediaStreamTrack}} object represents media of a single type that
originates from one media source in the \[=User Agent=\], e.g. video
produced by a web camera. A {{MediaStream}} is used to group several
{{MediaStreamTrack}} objects into one unit that can be recorded or
rendered in a media element.

Each {{MediaStream}} can contain zero or more {{MediaStreamTrack}}
objects. All tracks in a {{MediaStream}} are intended to be synchronized
when rendered. This is not a hard requirement, since it might not be
possible to synchronize tracks from sources that have different clocks.
Different {{MediaStream}} objects do not need to be synchronized.

While the intent is to synchronize tracks, it could be better in some
circumstances to permit tracks to lose synchronization. In particular,
when tracks are remotely sourced and real-time \[\[?WEBRTC\]\], it can
be better to allow loss of synchronization than to accumulate delays or
risk glitches and other artifacts. Implementations are expected to
understand the implications of choices regarding synchronization of
playback and the effect that these have on user perception.

A single {{MediaStreamTrack}} can represent multi-channel content, such
as stereo or 5.1 audio or stereoscopic video, where the channels have a
well defined relationship to each other. Information about channels
might be exposed through other APIs, such as \[\[?WEBAUDIO\]\], but this
specification provides no direct access to channels.

A {{MediaStream}} object has an input and an output that represent the
combined input and output of all the object\'s tracks. The output of the
{{MediaStream}} controls how the object is rendered, e.g., what is saved
if the object is recorded to a file or what is displayed if the object
is used in a \[\^video\^\] element. A single {{MediaStream}} object can
be attached to multiple different outputs at the same time.

A new {{MediaStream}} object can be created from existing media streams
or tracks using the {{MediaStream/MediaStream()}} constructor. The
constructor argument can either be an existing {{MediaStream}} object,
in which case all the tracks of the given stream are added to the new
{{MediaStream}} object, or an array of {{MediaStreamTrack}} objects. The
latter form makes it possible to compose a stream from different source
streams.

Both {{MediaStream}} and {{MediaStreamTrack}} objects can be cloned. A
cloned {{MediaStream}} contains clones of all member tracks from the
original stream. A cloned {{MediaStreamTrack}} has a [set of
constraints](#constrainable-interface) that is independent of the
instance it is cloned from, which allows media from the same source to
have different constraints applied for different consumers. The
{{MediaStream}} object is also used in contexts outside
{{MediaDevices/getUserMedia}}, such as \[\[?WEBRTC\]\].
:::

:::::::: section
## {{MediaStream}}

The MediaStream [constructor]{.dfn idl="" dfn-for="MediaStream"}
composes a new stream out of existing tracks. It takes an optional
argument of type {{MediaStream}} or an array of {{MediaStreamTrack}}
objects. When the constructor is invoked, the User Agent must run the
following steps:

1.  Let `stream`{.variable} be a newly constructed {{MediaStream}}
    object.

2.  Initialize `stream`{.variable}.{{MediaStream/id}} attribute to a
    newly generated value.

3.  If the constructor\'s argument is present, run the following steps:

    1.  Construct a set of tracks `tracks`{.variable} based on the type
        of argument:

        - A {{MediaStream}} object:

          Let `tracks`{.variable} be a set containing all the
          {{MediaStreamTrack}} objects in the {{MediaStream}} track set.

        - A sequence of {{MediaStreamTrack}} objects:

          Let `tracks`{.variable} be a set containing all the
          {{MediaStreamTrack}} objects in the provided sequence.

    2.  For each {{MediaStreamTrack}}, `track`{.variable} , in
        `tracks`{.variable}, run the following steps:

        1.  If `track`{.variable} is already in `stream`{.variable}\'s
            \[=track set=\], skip `track`{.variable}.

        2.  Otherwise, add `track`{.variable} to `stream`{.variable}\'s
            \[=track set=\].

4.  Return `stream`{.variable}.

The tracks of a {{MediaStream}} are stored in a [track set]{.dfn
.export}. The track set MUST contain the {{MediaStreamTrack}} objects
that correspond to the tracks of the stream. The relative order of the
tracks in the set is User Agent defined and the API will never put any
requirements on the order. The proper way to find a specific
{{MediaStreamTrack}} object in the set is to look it up by its
{{MediaStreamTrack/id}}.

An object that reads data from the output of a {{MediaStream}} is
referred to as a {{MediaStream}} [consumer]{.dfn export=""
data-for="MediaStream"}. The list of {{MediaStream}} consumers currently
include media elements (such as \[\^video\^\] and \[\^audio\^\])
\[\[HTML\]\], Web Real-Time Communications (WebRTC;
{{RTCPeerConnection}}) \[\[?WEBRTC\]\], media recording
(`MediaRecorder`{.fixme}) \[\[?mediastream-recording\]\], image capture
(`ImageCapture`{.fixme}) \[\[?image-capture\]\], and web audio
({{MediaStreamAudioSourceNode}}) \[\[?WEBAUDIO\]\].

{{MediaStream}} consumers must be able to handle tracks being added and
removed. This behavior is specified per consumer.

A {{MediaStream}} object is said to be [active]{#stream-active .dfn
dfn-for="stream"} when it has at least one {{MediaStreamTrack}} that has
not \[=MediaStreamTrack/ended=\]. A {{MediaStream}} that does not have
any tracks or only has tracks that are \[= MediaStreamTrack/ended =\] is
[inactive]{#stream-inactive .dfn dfn-for="stream"}.

A {{MediaStream}} object is said to be [audible]{#stream-audible .dfn
dfn-for="stream"} when it has at least one {{MediaStreamTrack}} whose
{{MediaStreamTrack/\[\[Kind\]\]}} is \"audio\" that has not
\[=MediaStreamTrack/ended=\]. A {{MediaStream}} that does not have any
audio tracks or only has audio tracks that are
\[=MediaStreamTrack/ended=\] is [inaudible]{#stream-inaudible .dfn
dfn-for="stream"}.

The \[=User Agent=\] may update a {{MediaStream}}\'s \[=track set=\] in
response to, for example, an external event. This specification does not
specify any such cases, but other specifications using the MediaStream
API may. One such example is the WebRTC 1.0 \[\[?WEBRTC\]\]
specification where the \[=track set=\] of a {{MediaStream}}, received
from another peer, can be updated as a result of changes to the media
session.

To [add a track]{.dfn .abstract-op dfn-for="MediaStream"}
`track`{.variable} to a {{MediaStream}} `stream`{.variable}, the \[=User
Agent=\] MUST run the following steps:

1.  If `track`{.variable} is already in `stream's`{.variable} \[=track
    set=\], then abort these steps.

2.  Add `track`{.variable} to `stream`{.variable}\'s \[=track set=\].

3.  \[= Fire a track event=\] named {{addtrack}} with `track`{.variable}
    at `stream`{.variable}.

To [remove a track]{.dfn .abstract-op dfn-for="MediaStream"}
`track`{.variable} from a {{MediaStream}} `stream`{.variable}, the
\[=User Agent=\] MUST run the following steps:

1.  If `track`{.variable} is not in `stream's`{.variable} \[=track
    set=\], then abort these steps.

2.  \[=set/Remove=\] `track`{.variable} from `stream`{.variable}\'s
    \[=track set=\].

3.  \[= Fire a track event =\] named {{removetrack}} with
    `track`{.variable} at `stream`{.variable}.

::::::: {}
``` idl
[Exposed=Window]
interface MediaStream : EventTarget {
  constructor();
  constructor(MediaStream stream);
  constructor(sequence<MediaStreamTrack> tracks);
  readonly attribute DOMString id;
  sequence<MediaStreamTrack> getAudioTracks();
  sequence<MediaStreamTrack> getVideoTracks();
  sequence<MediaStreamTrack> getTracks();
  MediaStreamTrack? getTrackById(DOMString trackId);
  undefined addTrack(MediaStreamTrack track);
  undefined removeTrack(MediaStreamTrack track);
  MediaStream clone();
  readonly attribute boolean active;
  attribute EventHandler onaddtrack;
  attribute EventHandler onremovetrack;
};
```

::: section
## Constructors

{{MediaStream}}

:   See the [MediaStream constructor
    algorithm](#mediastream-constructor)

    ::: {}
    *No parameters.*
    :::

{{MediaStream}}

:   See the [MediaStream constructor
    algorithm](#mediastream-constructor)

{{MediaStream}}

:   See the [MediaStream constructor
    algorithm](#mediastream-constructor)
:::

::: section
## Attributes

{{id}} of type {{DOMString}}, readonly

:   The [id]{.dfn idl=""} attribute MUST return the value to which it
    was initialized when the object was created.

    When a {{MediaStream}} is created, the User Agent MUST generate an
    identifier string, and MUST initialize the object\'s {{id}}
    attribute to that string, unless the object is created as part of a
    special purpose algorithm that specifies how the stream id must be
    initialized. A good practice is to use a UUID \[\[rfc4122\]\], which
    is 36 characters long in its canonical form. To avoid
    fingerprinting, implementations SHOULD use the forms in section 4.4
    or 4.5 of RFC 4122 when generating UUIDs.

    An example of an algorithm that specifies how the stream id must be
    initialized is the algorithm to associate an incoming network
    component with a {{MediaStream}} object. \[\[?WEBRTC\]\]

[active]{.dfn} of type {{boolean}}, readonly

:   The {{active}} attribute MUST return `true` if this {{MediaStream}}
    is \[= stream/active =\] and `false` otherwise.

[onaddtrack]{.dfn} of type {{EventHandler}}

:   The event type of this event handler is {{addtrack}}.

[onremovetrack]{.dfn} of type {{EventHandler}}

:   The event type of this event handler is {{removetrack}}.
:::

::: section
## Methods

[getAudioTracks()]{.dfn}

:   Returns a sequence of {{MediaStreamTrack}} objects representing the
    audio tracks in this stream.

    The {{getAudioTracks}} method MUST return a sequence that represents
    a snapshot of all the {{MediaStreamTrack}} objects in this stream\'s
    \[=track set=\] whose {{MediaStreamTrack/\[\[Kind\]\]}} is equal to
    \"audio\". The conversion from the \[=track set=\] to the sequence
    is \[=User Agent=\] defined and the order does not have to be stable
    between calls.

[getVideoTracks()]{.dfn}

:   Returns a sequence of {{MediaStreamTrack}} objects representing the
    video tracks in this stream.

    The {{getVideoTracks}} method MUST return a sequence that represents
    a snapshot of all the {{MediaStreamTrack}} objects in this stream\'s
    \[=track set=\] whose {{MediaStreamTrack/\[\[Kind\]\]}} is equal to
    \"video\". The conversion from the \[=track set=\] to the sequence
    is \[=User Agent=\] defined and the order does not have to be stable
    between calls.

[getTracks()]{.dfn}

:   Returns a sequence of {{MediaStreamTrack}} objects representing all
    the tracks in this stream.

    The {{getTracks}} method MUST return a sequence that represents a
    snapshot of all the {{MediaStreamTrack}} objects in this stream\'s
    \[=track set=\], regardless of {{MediaStreamTrack/\[\[Kind\]\]}}.
    The conversion from the \[=track set=\] to the sequence is User
    Agent defined and the order does not have to be stable between
    calls.

[getTrackById()]{.dfn}

:   The {{getTrackById}} method MUST return either a
    {{MediaStreamTrack}} object from this stream\'s \[=track set=\]
    whose {{MediaStreamTrack/\[\[Id\]\]}} is equal to
    `trackId`{.variable}, or `null`, if no such track exists.

[addTrack()]{.dfn}

:   Adds the given {{MediaStreamTrack}} to this {{MediaStream}}.

    When the {{addTrack}} method is invoked, the \[=User Agent=\] MUST
    run the following steps:

    1.  Let `track`{.variable} be the methods argument and
        `stream`{.variable} the {{MediaStream}} object on which the
        method was called.

    2.  If `track`{.variable} is already in `stream`{.variable}\'s
        \[=track set=\], then abort these steps.

    3.  \[=MediaStream/Add a track\|Add=\] `track`{.variable} to
        `stream`{.variable}\'s \[=track set=\].

[removeTrack()]{.dfn}

:   Removes the given {{MediaStreamTrack}} object from this
    {{MediaStream}}.

    When the {{removeTrack}} method is invoked, the \[=User Agent=\]
    MUST run the following steps:

    1.  Let `track`{.variable} be the methods argument and
        `stream`{.variable} the {{MediaStream}} object on which the
        method was called.

    2.  If `track`{.variable} is not in `stream's`{.variable} \[=track
        set=\], then abort these steps.

    3.  \[=MediaStream/Remove a track\|Remove=\] `track`{.variable} from
        `stream`{.variable}\'s \[=track set=\].

[clone()]{.dfn}

:   Clones the given {{MediaStream}} and all its tracks.

    When the {{clone()}} method is invoked, the User Agent MUST run the
    following steps:

    1.  Let `streamClone`{.variable} be a newly constructed
        {{MediaStream}} object.

    2.  Initialize `streamClone`{.variable}.{{MediaStream.id}} to a
        newly generated value.

    3.  [Clone each track](#track-clone) in this {{MediaStream}} object
        and add the result to `streamClone`{.variable}\'s track set.

    4.  Return `streamClone`{.variable}.
:::

::: section
## Garbage Collection

User agent code that expects to fire the addtrack or removetrack events
is expected to keep the target {{MediaStream}} objects alive by
reference from another object. The presence of addtrack or removetrack
event listeners does not need to be taken into account when trying to
garbage collect {{MediaStream}} objects.
:::
:::::::
::::::::

:::::::::::::::::::::::::::::::::::: section
## {{MediaStreamTrack}}

A {{MediaStreamTrack}} object represents a media source in the \[=User
Agent=\]. An example source is a device connected to the \[=User
Agent=\]. Other specifications may define sources for
{{MediaStreamTrack}} that override the behavior specified here. Several
{{MediaStreamTrack}} objects can represent the same media source, e.g.,
when the user chooses the same camera in the UI shown by two consecutive
calls to {{MediaDevices/getUserMedia()}}.

A {{MediaStreamTrack}} source defines the following properties:

1.  A source has a [MediaStreamTrack source type]{.dfn export=""}. It is
    set to either {{MediaStreamTrack}} or a subtype of
    {{MediaStreamTrack}}. By default, it is set to {{MediaStreamTrack}}.
2.  A source has [MediaStreamTrack source-specific construction
    steps]{.dfn export=""} that are executed when creating a
    {{MediaStreamTrack}} from a source. The steps take a newly created
    {{MediaStreamTrack}} as input. By default, the steps are empty.
3.  A source has [MediaStreamTrack source-specific clone steps]{.dfn
    export=""} that are executed when cloning a {{MediaStreamTrack}} of
    the given source. The steps take the source and destination
    {{MediaStreamTrack}}s as input. By default, the steps are empty.

The data from a {{MediaStreamTrack}} object does not necessarily have a
canonical binary form; for example, it could just be \"the video
currently coming from the user\'s video camera\". This allows \[=User
Agents=\] to manipulate media in whatever fashion is most suitable on
the user\'s platform.

A script can indicate that a {{MediaStreamTrack}} object no longer needs
its source with the {{MediaStreamTrack/stop()}} method. When all tracks
using a source have been stopped or ended by some other means, the
source is [stopped]{#source-stopped .dfn lt="source stopped state"}. If
the source is a device exposed by {{MediaDevices/getUserMedia()}}, then
when the source is stopped, the \[=User Agent=\] MUST run the following
steps:

1.  Let `mediaDevices`{.variable} be the {{MediaDevices}} object in
    question.

2.  Let `deviceId`{.variable} be the source device\'s
    {{MediaDeviceInfo/deviceId}}.

3.  Set
    `mediaDevices`{.variable}.{{MediaDevices/\[\[devicesLiveMap\]\]}}\[`deviceId`{.variable}\]
    to `false`.

4.  If the \[=permission state=\] of the permission associated with the
    device\'s kind and `deviceId`{.variable} for
    `mediaDevices`{.variable}\'s \[=relevant settings object=\], is not
    {{PermissionState/\"granted\"}}, then set
    `mediaDevices`{.variable}.{{MediaDevices/\[\[devicesAccessibleMap\]\]}}\[`deviceId`{.variable}\]
    to `false`.

To [create a MediaStreamTrack]{.dfn .abstract-op} with an underlying
`source`{.variable}, and a `mediaDevicesToTieSourceTo`{.variable}, run
the following steps:

1.  Let `track`{.variable} be a new object of type
    `source`{.variable}\'s \[=MediaStreamTrack source type=\].

    Initialize track with the following internal slots:

    - [\[\[\\Source\]\]]{.dfn}, initialized to `source`{.variable}.

    - [\[\[\\Id\]\]]{.dfn}, initialized to a newly generated unique
      identifier string. See {{MediaStream.id}} attribute for guidelines
      on how to generate such an identifier.

    - [\[\[\\Kind\]\]]{.dfn}, initialized to [`"audio"`]{.dfn} if
      `source`{.variable} is an audio source, or [`"video"`]{.dfn} if
      `source`{.variable} is a video source.

    - [\[\[\\Label\]\]]{.dfn}, initialized to `source`{.variable}\'s
      label, if provided by the User Agent, or `""` otherwise. \[=User
      Agents=\] MAY label audio and video sources (e.g., \"Internal
      microphone\" or \"External USB Webcam\").

    - [\[\[\\ReadyState\]\]]{.dfn}, initialized to
      {{MediaStreamTrackState/\"live\"}}.

    - [\[\[\\Enabled\]\]]{.dfn}, initialized to `true`.

    - [\[\[\\Muted\]\]]{.dfn}, initialized to `true` if
      `source`{.variable} is \[= source/muted =\], and `false`
      otherwise.

    - [\[\[\\Capabilities\]\]]{link-for="constrainable object"
      link-type="attribute"},
      [\[\[\\Constraints\]\]]{link-for="constrainable object"
      link-type="attribute"}, and
      [\[\[\\Settings\]\]]{link-for="constrainable object"
      link-type="attribute"}, all initialized as specified in the
      {{ConstrainablePattern}}.

    - [\[\[\\Restrictable\]\]]{.dfn .export}, initialized to `false`.

2.  If `mediaDevicesToTieSourceTo`{.variable} is not `null`, \[=tie
    track source to \`MediaDevices\`=\] with `source`{.variable} and
    `mediaDevicesToTieSourceTo`{.variable}.

3.  Run `source`{.variable}\'s \[=MediaStreamTrack source-specific
    construction steps=\] with `track`{.variable} as parameter.

4.  Return `track`{.variable}.

To [initialize the underlying source]{.dfn .abstract-op} of
`track`{.variable} to `source`{.variable}, run the following steps:

1.  Initialize `track`{.variable}.{{MediaStreamTrack/\[\[Source\]\]}} to
    `source`{.variable}.

2.  Initialize `track`{.variable}\'s
    [\[\[\\Capabilities\]\]]{link-for="constrainable object"
    link-type="attribute"},
    [\[\[\\Constraints\]\]]{link-for="constrainable object"
    link-type="attribute"}, and
    [\[\[\\Settings\]\]]{link-for="constrainable object"
    link-type="attribute"}, as specified in the
    {{ConstrainablePattern}}.

To [tie track source to \`MediaDevices\`]{.dfn .abstract-op}, given
`source`{.variable} and `mediaDevices`{.variable}, run the following
steps:

1.  Add `source`{.variable} to
    `mediaDevices`{.variable}.{{MediaDevices/\[\[mediaStreamTrackSources\]\]}}.

To [stop all sources]{.dfn .abstract-op} of a \[=global object=\], named
`globalObject`{.variable}, the \[=User Agent=\] MUST run the following
steps:

1.  For each {{MediaStreamTrack}} object `track`{.variable} whose
    [relevant global object]{data-cite="!HTML/#concept-relevant-global"}
    is `globalObject`{.variable}, set `track`{.variable}\'s
    {{MediaStreamTrack/\[\[ReadyState\]\]}} to
    {{MediaStreamTrackState/\"ended\"}}.

2.  If `globalObject`{.variable} is a {{Window}}, then for each
    `source`{.variable} in `globalObject`{.variable}\'s \[=associated
    \`MediaDevices\`=\].{{MediaDevices/\[\[mediaStreamTrackSources\]\]}},
    \[= source/stopped \| stop =\] `source`{.variable}.

The \[=User Agent=\] MUST \[=stop all sources=\] of a
`globalObject`{.variable} in the following conditions:

1.  If `globalObject`{.variable} is a {{Window}} object and the
    \[=unloading document cleanup steps=\] are executed for its
    \[=associated document=\].

2.  If `globalObject`{.variable} is a {{WorkerGlobalScope}} object and
    its
    [closing]{data-cite="!HTML/workers.html#dom-workerglobalscope-closing"}
    flag is set to true.

An implementation may use a per-source reference count to keep track of
source usage, but the specifics are out of scope for this specification.

To [clone a track]{#track-clone .dfn .abstract-op} the \[=User Agent=\]
MUST run the following steps:

1.  Let `track`{.variable} be the {{MediaStreamTrack}} object to be
    cloned.

2.  Let `source`{.variable} be `track`{.variable}\'s
    {{MediaStreamTrack/\[\[Source\]\]}}.

3.  Let `trackClone`{.variable} be the result of \[=create a
    MediaStreamTrack \| creating a MediaStreamTrack=\] with
    `source`{.variable} and `null`.

4.  Set `trackClone`{.variable}\'s
    {{MediaStreamTrack/\[\[ReadyState\]\]}} to `track`{.variable}\'s
    {{MediaStreamTrack/\[\[ReadyState\]\]}} value.

5.  Set `trackClone`{.variable}\'s
    [\[\[\\Capabilities\]\]]{link-for="constrainable object"
    link-type="attribute"} to a clone of `track`{.variable}\'s
    [\[\[\\Capabilities\]\]]{link-for="constrainable object"
    link-type="attribute"}.

6.  Set `trackClone`{.variable}\'s
    [\[\[\\Constraints\]\]]{link-for="constrainable object"
    link-type="attribute"} to a clone of `track`{.variable}\'s
    [\[\[\\Constraints\]\]]{link-for="constrainable object"
    link-type="attribute"}.

7.  Set `trackClone`{.variable}\'s
    [\[\[\\Settings\]\]]{link-for="constrainable object"
    link-type="attribute"} to a clone of `track`{.variable}\'s
    [\[\[\\Settings\]\]]{link-for="constrainable object"
    link-type="attribute"}.

8.  Run `source`{.variable} \[=MediaStreamTrack source-specific clone
    steps=\] with `track`{.variable} and `trackClone`{.variable} as
    parameters.

9.  Return `trackClone`{.variable}.

::::::: section
### Media Flow and Life-cycle

:::: section
#### Media Flow

There are two dimensions related to the media flow for a
{{MediaStreamTrackState/\"live\"}} {{MediaStreamTrack}} : muted / not
muted, and enabled / disabled.

[Muted]{#track-muted .dfn .export dfn-for="MediaStreamTrack"
dfn-type="dfn"} refers to the input to the {{MediaStreamTrack}}. A
{{MediaStreamTrack}} is \[= MediaStreamTrack/muted =\] when its source
is [muted]{.dfn dfn-for="source"}, i.e. temporarily unable to provide
the track with data. Live samples MUST NOT be made available to a
{{MediaStreamTrack}} while it is \[=MediaStreamTrack/muted=\].

The \[=MediaStreamTrack/muted=\] state is outside the control of web
applications, but can be observed by the application by reading the
{{MediaStreamTrack/muted}} attribute and listening to the associated
events {{mute}} and {{unmute}}. The reasons for a {{MediaStreamTrack}}
to be muted are defined by its source.

For camera and microphone sources, the reasons to
\[=source/muted\|mute=\] are \[=implementation-defined=\]. This allows
user agents to implement privacy mitigations in situations like: the
user pushing a physical mute button on the microphone, the user closing
a laptop lid with an embedded camera, the user toggling a control in the
operating system, the user clicking a mute button in the \[=User
Agent=\] chrome, the \[=User Agent=\] (on behalf of the user) mutes,
etc.

On some operating systems, microphone access may get stolen from the
\[=User Agent=\] when another application with higher-audio priority
gets access to it, for instance in case of an incoming phone call on
mobile OS. The \[=User Agent=\] SHOULD provide this information to the
web application through {{MediaStreamTrack/muted}} and its associated
events.

Whenever the \[=User Agent=\] initiates such an \[=
implementation-defined=\] change for camera or microphone sources, it
MUST queue a task, using the user interaction task source, to
\[=MediaStreamTrack/set a track\'s muted state=\] to the state desired
by the user.

::: note
This does not apply to \[=source\|sources=\] defined in other
specifications. Other specifications need to define their own steps to
\[=MediaStreamTrack/set a track\'s muted state=\] if desired.
:::

To [set a track\'s muted state]{#set-track-muted .dfn .export
.abstract-op dfn-for="MediaStreamTrack"} to `newState`{.variable}, the
\[=User Agent=\] MUST run the following steps:

1.  Let `track`{.variable} be the {{MediaStreamTrack}} in question.

2.  If `track`{.variable}.{{MediaStreamTrack/\[\[Muted\]\]}} is already
    `newState`{.variable}, then abort these steps.

3.  Set `track`{.variable}.{{MediaStreamTrack/\[\[Muted\]\]}} to
    `newState`{.variable}.

4.  If `newState`{.variable} is `true` let `eventName`{.variable} be
    {{mute}}, otherwise {{unmute}}.

5.  \[=Fire an event=\] named `eventName`{.variable} on
    `track`{.variable}.

[Enabled/disabled]{#track-enabled .dfn export=""
dfn-for="MediaStreamTrack" dfn-type="dfn"
lt="track enabled state|enabled" lt-nodefault=""} on the other hand is
available to the application to control (and observe) via the
{{MediaStreamTrack/enabled}} attribute.

The result for the consumer is the same in the sense that whenever
{{MediaStreamTrack}} is muted or disabled (or both) the consumer gets
zero-information-content, which means silence for audio and black frames
for video. In other words, media from the source only flows when a
{{MediaStreamTrack}} object is both unmuted and enabled. For example, a
video element sourced by a {{MediaStream}} containing only muted or
disabled {{MediaStreamTrack}}s for audio and video, is playing but
rendering black video frames in silence.

For a newly created {{MediaStreamTrack}} object, the following applies:
the track is always enabled unless stated otherwise (for example when
cloned) and the muted state reflects the state of the source at the time
the track is created.
::::

:::: section
#### Life-cycle

A {{MediaStreamTrack}} has two states in its life-cycle: live and ended.
A newly created {{MediaStreamTrack}} can be in either state depending on
how it was created. For example, cloning an ended track results in a new
ended track. The current state is reflected by the object\'s
{{MediaStreamTrack/readyState}} attribute.

In the live state, the track is active and media (or
zero-information-content if the {{MediaStreamTrack}} is \[=
MediaStreamTrack/muted =\] or \[= MediaStreamTrack/enabled \| disabled
=\]) is available for use by consumers.

If the source is a device exposed by
\`navigator.mediaDevices.\`{{MediaDevices/getUserMedia()}}, then when a
track becomes either muted or disabled, and this brings all tracks
connected to the device to be either muted, disabled, or stopped, then
the UA MAY, using the device\'s {{MediaDeviceInfo/deviceId}},
`deviceId`{.variable}, set
\`navigator.mediaDevices.\`{{MediaDevices/\[\[devicesLiveMap\]\]}}\[`deviceId`{.variable}\]
to `false`, provided the UA sets it back to `true` as soon as any
unstopped track connected to this device becomes un-muted or enabled
again.

When a {{MediaStreamTrackState/\"live\"}}, \[= MediaStreamTrack/muted \|
unmuted =\], and \[= MediaStreamTrack/enabled =\] track sourced by a
device exposed by {{MediaDevices/getUserMedia()}} becomes either \[=
MediaStreamTrack/muted =\] or \[= MediaStreamTrack/enabled \| disabled
=\], and this brings *all* tracks connected to the device (across all
\[=navigables=\] the user agent operates) to be either muted, disabled,
or stopped, then the UA SHOULD [relinquish the device]{.dfn} within 3
seconds while allowing time for a reasonably-observant user to become
aware of the transition. The UA SHOULD attempt to reacquire the device
as soon as any live track sourced by the device becomes both \[=
MediaStreamTrack/muted \| unmuted =\] and \[= MediaStreamTrack/enabled
=\] again, provided that track\'s \[=relevant global object=\]\'s
\[=associated \`Document\`=\] \[=Document/is in view=\] at that time. If
the document is not \[=Document/is in view\|in view=\] at that time, the
UA SHOULD instead queue a task to \[=MediaStreamTrack/muted\|mute=\] the
track, and not queue a task to \[=MediaStreamTrack/muted\|unmute=\] it
until the document comes \[=Document/is in view\|into view=\]. If
reacquiring the device fails, the UA MUST \[= track ended by the User
agent \| end the track =\] (The UA MAY end it earlier should it detect a
device problem, like the device being physically removed).

::: note
The intent is to give users the assurance of privacy that having
physical camera (and microphone) hardware lights off brings, by aligning
physical and logical "privacy indicators", at least while the current
document is the sole user of a device.

While other applications and documents using the device simultaneously
may interfere with this intent at times, they do not interfere with the
rules laid forth.
:::

A {{MediaStreamTrack}} object is said to *end* when the source of the
track is disconnected or exhausted.

If all {{MediaStreamTrack}}s that are using the same source are \[=
MediaStreamTrack/ended =\], the source will be \[= source/stopped =\].

After the application has invoked the {{MediaStreamTrack/stop()}} method
on a {{MediaStreamTrack}} object, or once the \[=source=\] of a
{{MediaStreamTrack}} permanently ends production of live samples to its
tracks, whichever is sooner, a {{MediaStreamTrack}} is said to be
[ended]{#track-ended .dfn dfn-for="MediaStreamTrack" dfn-type="dfn"
export=""}.

For camera and microphone sources, the reasons for a source to
\[=MediaStreamTrack/ended\|end=\] besides {{MediaStreamTrack/stop()}}
are \[=implementation-defined=\] (e.g., because the user rescinds the
permission for the page to use the local camera, or because the User
Agent has instructed the track to end for any reason).

When a {{MediaStreamTrack}} `track`{.variable} [ends for any reason
other than the {{MediaStreamTrack/stop()}} method being
invoked]{#ends-nostop .dfn lt="track ended by the User agent"
data-for="MediaStreamTrack" export=""}, the \[=User Agent=\] MUST queue
a task that runs the following steps:

1.  If `track`{.variable}\'s {{MediaStreamTrack/\[\[ReadyState\]\]}} has
    the value {{MediaStreamTrackState/\"ended\"}} already, then abort
    these steps.

2.  Set `track`{.variable}\'s {{MediaStreamTrack/\[\[ReadyState\]\]}} to
    {{MediaStreamTrackState/\"ended\"}}.

3.  Notify `track`{.variable}\'s {{MediaStreamTrack/\[\[Source\]\]}}
    that `track`{.variable} is \[= MediaStreamTrack/ended =\] so that
    the source may be \[= source/stopped =\], unless other
    {{MediaStreamTrack}} objects depend on it.

4.  \[=Fire an event=\] named [ended]{link-type="event"} at the object.

If the end of the track was reached due to a user request, the event
source for this event is the user interaction event source.

To invoke the [device permission revocation algorithm]{.dfn
.abstract-op} with `permissionName`{.variable}, run the following steps:

1.  Let `tracks`{.variable} be the set of all currently
    {{MediaStreamTrackState/\"live\"}} `MediaStreamTrack`s whose
    permission associated with this kind of track (\"camera\" or
    \"microphone\") matches `permissionName`{.variable}.

2.  For each `track`{.variable} in `tracks`{.variable},
    [end](#ends-nostop) the track.
::::
:::::::

::: section
### Tracks and Constraints

{{MediaStreamTrack}} is a constrainable object as defined in the
[Constrainable Pattern](#constrainable-interface) section. Constraints
are set on tracks and may affect sources.

Whether `Constraints` were provided at track initialization time or need
to be established later at runtime, the APIs defined in the
ConstrainablePattern Interface allow the retrieval and manipulation of
the constraints currently established on a track.

Once ended, a track will continue exposing a [ list of inherent
constrainable track
properties]{#list-of-inherent-constrainable-track-properties .dfn}. This
list contains [`deviceId`](#def-constraint-deviceId),
[`facingMode`](#def-constraint-facingMode) and
[`groupId`](#def-constraint-groupId).
:::

::::::: {#media-stream-track-interface-definition .section}
### Interface Definition

::::: {}
``` idl
[Exposed=Window]
interface MediaStreamTrack : EventTarget {
  readonly attribute DOMString kind;
  readonly attribute DOMString id;
  readonly attribute DOMString label;
  attribute boolean enabled;
  readonly attribute boolean muted;
  attribute EventHandler onmute;
  attribute EventHandler onunmute;
  readonly attribute MediaStreamTrackState readyState;
  attribute EventHandler onended;
  MediaStreamTrack clone();
  undefined stop();
  MediaTrackCapabilities getCapabilities();
  MediaTrackConstraints getConstraints();
  MediaTrackSettings getSettings();
  Promise<undefined> applyConstraints(optional MediaTrackConstraints constraints = {});
};
```

::: section
## Attributes

{{kind}} of type {{DOMString}}, readonly

:   The [kind]{.dfn} attribute MUST return
    \[=this=\].{{MediaStreamTrack/\[\[Kind\]\]}}.

{{id}} of type {{DOMString}}, readonly

:   The [id]{.dfn} attribute MUST return
    \[=this=\].{{MediaStreamTrack/\[\[Id\]\]}}.

{{label}} of type {{DOMString}}, readonly

:   The [label]{.dfn} attribute MUST return
    \[=this=\].{{MediaStreamTrack/\[\[Label\]\]}}.

{{enabled}} of type {{boolean}}

:   The [enabled]{#dom-mediastreamtrack-enabled .dfn} attribute controls
    the \[= MediaStreamTrack/enabled =\] state for the object.

    On getting, \[=this=\].{{MediaStreamTrack/\[\[Enabled\]\]}} MUST be
    returned. On setting,
    \[=this=\].{{MediaStreamTrack/\[\[Enabled\]\]}} MUST be set to the
    new value.

    Thus, after a {{MediaStreamTrack}} has \[= MediaStreamTrack/ended
    =\], its {{MediaStreamTrack/enabled}} attribute still changes value
    when set; it just doesn\'t do anything with that new value.

{{muted}} of type {{boolean}}, readonly

:   The [muted]{.dfn idl=""} attribute reflects whether the track is \[=
    MediaStreamTrack/muted =\]. It MUST return
    \[=this=\].{{MediaStreamTrack/\[\[Muted\]\]}}.

[onmute]{.dfn} of type {{EventHandler}}

:   The event type of this event handler is [mute]{link-type="event"}.

[onunmute]{.dfn} of type {{EventHandler}}

:   The event type of this event handler is [unmute]{link-type="event"}.

{{readyState}} of type {{MediaStreamTrackState}}, readonly

:   On getting, the [readyState]{.dfn} attribute MUST return
    \[=this=\].{{MediaStreamTrack/\[\[ReadyState\]\]}}.

[onended]{.dfn} of type {{EventHandler}}

:   The event type of this event handler is [ended]{link-type="event"}.
:::

::: section
## Methods

[clone]{.dfn}

:   When the {{clone()}} method is invoked, the \[=User Agent=\] MUST
    return the result of \[=clone a track=\] with \[=this=\].

[stop]{.dfn}

:   When a {{MediaStreamTrack}} object\'s {{stop()}} method is invoked,
    the User Agent MUST run following steps:

    1.  Let `track`{.variable} be the current {{MediaStreamTrack}}
        object.

    2.  If `track`{.variable}\'s {{MediaStreamTrack/\[\[ReadyState\]\]}}
        is {{MediaStreamTrackState/\"ended\"}}, then abort these steps.

    3.  Notify `track`{.variable}\'s source that `track`{.variable} is
        \[= MediaStreamTrack/ended =\].

        A source that is notified of a track ending will be \[=
        source/stopped =\], unless other {{MediaStreamTrack}} objects
        depend on it.

    4.  Set `track`{.variable}\'s
        {{MediaStreamTrack/\[\[ReadyState\]\]}} to
        {{MediaStreamTrackState/\"ended\"}}.

[getCapabilities]{.dfn}

:   Returns the capabilites of the source that this
    {{MediaStreamTrack}}, the constrainable object, represents.

    See [ConstrainablePattern Interface](#constrainable-interface) for
    the definition of this method.

    Since this method gives likely persistent, cross-origin information
    about the underlying device, it adds to the fingerprint surface of
    the device.

[getConstraints]{.dfn}

:   See [ConstrainablePattern Interface](#constrainable-interface) for
    the definition of this method.

[getSettings]{.dfn}

:   When a {{MediaStreamTrack}} object\'s
    {{MediaStreamTrack.getSettings()}} method is invoked, the \[=User
    Agent=\] MUST run following steps:

    1.  Let `track`{.variable} be the current {{MediaStreamTrack}}
        object.

    2.  If `track`{.variable}\'s {{MediaStreamTrack/\[\[ReadyState\]\]}}
        is {{MediaStreamTrackState/\"ended\"}}, run the following sub
        steps:

        1.  Let `settings`{.variable} be a new {{MediaTrackSettings}}
            dictionary.

        2.  For each `property`{.variable} of the list of inherent
            constrainable track properties, add a corresponding property
            to `settings`{.variable} if `track`{.variable} had such
            property at the time it was ended, with the value at the
            time `track`{.variable} was ended.

        3.  Return `settings`{.variable}.

    3.  Return the current settings of the track as defined in
        [ConstrainablePattern Interface](#constrainable-interface).

[applyConstraints]{.dfn}

:   When a {{MediaStreamTrack}} object\'s {{applyConstraints()}} method
    is invoked, the User Agent MUST run following steps:

    1.  Let `track`{.variable} be the current {{MediaStreamTrack}}
        object.

    2.  If `track`{.variable}\'s {{MediaStreamTrack/\[\[ReadyState\]\]}}
        is {{MediaStreamTrackState/\"ended\"}}, run the following sub
        steps:

        1.  Let `p`{.variable} be a new promise.

        2.  \[= resolve =\] `p`{.variable} with `undefined`.

        3.  Return `p`{.variable}.

    3.  Invoke and return the result of the applyConstraints template
        method where:

        - In the SelectSettings algorithm,
          - `object`{.variable} is the {{MediaStreamTrack}} on which
            this method was called, and

          - settings dictionary refers to a possible instance of the
            {{MediaTrackSettings}} dictionary. The \[=User Agent=\] MUST
            NOT include inherent unchangeable device properties as
            members unless they are in the list of inherent
            constrainable track properties, or otherwise include device
            properties that [must not be exposed]{.dfn}.

            Other specifications may define constrainable properties
            that at times must not be exposed.

          - For every \[=settings dictionary=\] with
            [resizeMode](#def-constraint-resizeMode) set to
            [\"none\"](#idl-def-VideoResizeModeEnum.none), the \[=User
            Agent=\] MUST include another otherwise identical
            \[=settings dictionary=\] with
            [resizeMode](#def-constraint-resizeMode) set to
            [\"crop-and-scale\"](#idl-def-VideoResizeModeEnum.cropandscale).
            Constraining around non-native modes is not supported.

            The net effect is to reflect that crop-and-scale is a
            superset of none.
        - In step 3 of the ApplyConstraints algorithm, all changes
          listed are to be made to `object`{.variable}, and
        - In step 4 of the ApplyConstraints algorithm, the requirement
          on getConstraints() applies to the getConstraints() method of
          `object`{.variable}.
:::
:::::

::: {}
``` idl
enum MediaStreamTrackState {
  "live",
  "ended"
};
```

+----------------------------------------------+------------------------------------+
| Enum value                                   | Description                        |
+==============================================+====================================+
| [live]{#idl-def-MediaStreamTrackState.live   | The track is active (the track\'s  |
| .dfn}                                        | underlying media source is making  |
|                                              | a best-effort attempt to provide   |
|                                              | data in real time).                |
|                                              |                                    |
|                                              | The output of a track in the       |
|                                              | {{MediaStreamTrackState/\"live\"}} |
|                                              | state can be switched on and off   |
|                                              | with the                           |
|                                              | {{MediaStreamTrack/enabled}}       |
|                                              | attribute.                         |
+----------------------------------------------+------------------------------------+
| [ended]{#idl-def-MediaStreamTrackState.ended | The track has \[=                  |
| .dfn}                                        | MediaStreamTrack/ended =\] (the    |
|                                              | track\'s underlying media source   |
|                                              | is no longer providing data, and   |
|                                              | will never provide more data for   |
|                                              | this track). Once a track enters   |
|                                              | this state, it never exits it.     |
|                                              |                                    |
|                                              | For example, a video track in a    |
|                                              | {{MediaStream}} ends when the user |
|                                              | unplugs the USB web camera that    |
|                                              | acts as the track\'s media source. |
+----------------------------------------------+------------------------------------+

: [MediaStreamTrackState]{.dfn} Enumeration description {.simple
link-for="MediaStreamTrackState" dfn-for="MediaStreamTrackState"}
:::
:::::::

::::: {#media-track-supported-constraints .section}
## [MediaTrackSupportedConstraints]{.dfn}

{{MediaTrackSupportedConstraints}} represents the list of constraints
recognized by a \[=User Agent=\] for controlling the Capabilities of a
{{MediaStreamTrack}} object. This dictionary is used as a function
return value, and never as an operation argument.

Future specifications can extend the {{MediaTrackSupportedConstraints}}
dictionary by defining a partial dictionary with dictionary members of
type {{boolean}}.

The constraints specified in this specification apply only to instances
of {{MediaStreamTrack}} generated by {{MediaDevices.getUserMedia()}},
unless stated otherwise in other specifications.

:::: {}
``` idl
dictionary MediaTrackSupportedConstraints {
  boolean width = true;
  boolean height = true;
  boolean aspectRatio = true;
  boolean frameRate = true;
  boolean facingMode = true;
  boolean resizeMode = true;
  boolean sampleRate = true;
  boolean sampleSize = true;
  boolean echoCancellation = true;
  boolean autoGainControl = true;
  boolean noiseSuppression = true;
  boolean latency = true;
  boolean channelCount = true;
  boolean deviceId = true;
  boolean groupId = true;
  boolean backgroundBlur = true;
};
```

::: section
## Dictionary {{MediaTrackSupportedConstraints}} Members

[width]{.dfn} of type {{boolean}}, defaulting to `true`
:   See [width](#def-constraint-width) for details.

[height]{.dfn} of type {{boolean}}, defaulting to `true`
:   See [height](#def-constraint-height) for details.

[aspectRatio]{.dfn} of type {{boolean}}, defaulting to `true`
:   See [aspectRatio](#def-constraint-aspect) for details.

[frameRate]{.dfn} of type {{boolean}}, defaulting to `true`
:   See [frameRate](#def-constraint-frameRate) for details.

[facingMode]{.dfn} of type {{boolean}}, defaulting to `true`
:   See [facingMode](#def-constraint-facingMode) for details.

[resizeMode]{.dfn} of type {{boolean}}, defaulting to `true`
:   See [resizeMode](#def-constraint-resizeMode) for details.

[sampleRate]{.dfn} of type {{boolean}}, defaulting to `true`
:   See [sampleRate](#def-constraint-sampleRate) for details.

[sampleSize]{.dfn} of type {{boolean}}, defaulting to `true`
:   See [sampleSize](#def-constraint-sampleSize) for details.

[echoCancellation]{.dfn} of type {{boolean}}, defaulting to `true`
:   See [echoCancellation](#def-constraint-echoCancellation) for
    details.

[autoGainControl]{.dfn} of type {{boolean}}, defaulting to `true`
:   See [autoGainControl](#def-constraint-autoGainControl) for details.

[noiseSuppression]{.dfn} of type {{boolean}}, defaulting to `true`
:   See [noiseSuppression](#def-constraint-noiseSuppression) for
    details.

[latency]{.dfn} of type {{boolean}}, defaulting to `true`
:   See [latency](#def-constraint-latency) for details.

[channelCount]{.dfn} of type {{boolean}}, defaulting to `true`
:   See [channelCount](#def-constraint-channelCount) for details.

[deviceId]{.dfn} of type {{boolean}}, defaulting to `true`
:   See [deviceId](#def-constraint-deviceId) for details.

[groupId]{.dfn} of type {{boolean}}, defaulting to `true`
:   See [groupId](#def-constraint-groupId) for details.

[backgroundBlur]{.dfn} of type {{boolean}}, defaulting to `true`
:   See [backgroundBlur](#def-constraint-backgroundBlur) for details.
:::
::::
:::::

:::::: {#media-track-capabilities .section}
## [MediaTrackCapabilities]{.dfn}

{{MediaTrackCapabilities}} represents the Capabilities of a
{{MediaStreamTrack}} object.

Future specifications can extend the MediaTrackCapabilities dictionary
by defining a partial dictionary with dictionary members of appropriate
type.

::::: {}
``` idl
dictionary MediaTrackCapabilities {
  ULongRange width;
  ULongRange height;
  DoubleRange aspectRatio;
  DoubleRange frameRate;
  sequence<DOMString> facingMode;
  sequence<DOMString> resizeMode;
  ULongRange sampleRate;
  ULongRange sampleSize;
  sequence<(boolean or DOMString)> echoCancellation;
  sequence<boolean> autoGainControl;
  sequence<boolean> noiseSuppression;
  DoubleRange latency;
  ULongRange channelCount;
  DOMString deviceId;
  DOMString groupId;
  sequence<boolean> backgroundBlur;
};
```

::: note
For historical reasons, {{MediaTrackCapabilities/deviceId}} and
{{MediaTrackCapabilities/groupId}} are {{DOMString}} instead of the
\`sequence\<DOMString\>\` expected by {{Capabilities}} in the
`ConstrainablePattern`.
:::

::: section
## Dictionary {{MediaTrackCapabilities}} Members

[width]{.dfn} of type {{ULongRange}}
:   See [width](#def-constraint-width) for details.

[height]{.dfn} of type {{ULongRange}}
:   See [height](#def-constraint-height) for details.

[aspectRatio]{.dfn} of type {{DoubleRange}}
:   See [aspectRatio](#def-constraint-aspect) for details.

[frameRate]{.dfn} of type {{DoubleRange}}
:   See [frameRate](#def-constraint-frameRate) for details.

[facingMode]{.dfn} of type `sequence<{{DOMString}}>`

:   A camera can report multiple facing modes. For example, in a
    high-end telepresence solution with several cameras facing the user,
    a camera to the left of the user can report both
    {{VideoFacingModeEnum/\"left\"}} and
    {{VideoFacingModeEnum/\"user\"}}. See
    [facingMode](#def-constraint-facingMode) for additional details.

[resizeMode]{.dfn} of type `sequence<{{DOMString}}>`

:   The \[=User Agent=\] MAY use cropping and downscaling to offer more
    resolution choices than this camera naturally produces. The reported
    sequence MUST list all the means the UA may employ to derive
    resolution choices for this camera. The value
    {{VideoResizeModeEnum/\"none\"}} MUST be present, indicating the
    ability to constrain the UA from cropping and downscaling. See
    [resizeMode](#def-constraint-resizeMode) for additional details.

[sampleRate]{.dfn} of type {{ULongRange}}
:   See [sampleRate](#def-constraint-sampleRate) for details.

[sampleSize]{.dfn} of type {{ULongRange}}
:   See [sampleSize](#def-constraint-sampleSize) for details.

[echoCancellation]{.dfn} of type `sequence<{{boolean}}>`

:   If the source cannot do echo cancellation a single `false` MUST be
    the only element in the list. If the source can do echo
    cancellation, then `true` MUST be included in the list. If the
    script can control the feature, the list MUST include at least both
    `true` and `false`. Additionally, if the source allows controlling
    which audio sources will be cancelled, it must include any supported
    values from the {{EchoCancellationModeEnum}} enum. If `true` or
    `false` are included in the list, they must appear before any value
    from {{EchoCancellationModeEnum}}. See
    [echoCancellation](#def-constraint-echoCancellation) for additional
    details.

[autoGainControl]{.dfn} of type `sequence<{{boolean}}>`

:   If the source cannot do auto gain control a single `false` is
    reported. If auto gain control cannot be turned off, a single `true`
    is reported. If the script can control the feature, the source
    reports a list with both `true` and `false` as possible values. See
    [autoGainControl](#def-constraint-autoGainControl) for additional
    details.

[noiseSuppression]{.dfn} of type `sequence<{{boolean}}>`

:   If the source cannot do noise suppression a single `false` is
    reported. If noise suppression cannot be turned off, a single `true`
    is reported. If the script can control the feature, the source
    reports a list with both `true` and `false` as possible values. See
    [noiseSuppression](#def-constraint-noiseSuppression) for additional
    details.

[latency]{.dfn} of type {{DoubleRange}}
:   See [latency](#def-constraint-latency) for details.

[channelCount]{.dfn} of type {{ULongRange}}
:   See [channelCount](#def-constraint-channelCount) for details.

[deviceId]{.dfn} of type {{DOMString}}
:   See [deviceId](#def-constraint-deviceId) for details.

[groupId]{.dfn} of type {{DOMString}}
:   See [groupId](#def-constraint-groupId) for details.

[backgroundBlur]{.dfn} of type `sequence<{{boolean}}>`
:   If the source does not have built-in background blurring, a single
    `false` is reported. If background blurring cannot be turned off, a
    single `true` is reported. If the script can control the feature,
    the source reports a list with both true and false as possible
    values. See [backgroundBlur](#def-constraint-backgroundBlur) for
    details.
:::
:::::
::::::

::::::: {#media-track-constraints .section}
## [MediaTrackConstraints]{.dfn}

:::: {}
``` idl
dictionary MediaTrackConstraints : MediaTrackConstraintSet {
  sequence<MediaTrackConstraintSet> advanced;
};
```

::: section
## Dictionary {{MediaTrackConstraints}} Members

[advanced]{.dfn} of type `sequence<{{MediaTrackConstraintSet}}>`

:   See [Constraints and ConstraintSet](#constraints) for the definition
    of this element.
:::
::::

Future specifications can extend the [MediaTrackConstraintSet]{.dfn}
dictionary by defining a partial dictionary with dictionary members of
appropriate type.

:::: {}
``` idl
dictionary MediaTrackConstraintSet {
  ConstrainULong width;
  ConstrainULong height;
  ConstrainDouble aspectRatio;
  ConstrainDouble frameRate;
  ConstrainDOMString facingMode;
  ConstrainDOMString resizeMode;
  ConstrainULong sampleRate;
  ConstrainULong sampleSize;
  ConstrainBooleanOrDOMString echoCancellation;
  ConstrainBoolean autoGainControl;
  ConstrainBoolean noiseSuppression;
  ConstrainDouble latency;
  ConstrainULong channelCount;
  ConstrainDOMString deviceId;
  ConstrainDOMString groupId;
  ConstrainBoolean backgroundBlur;
};
```

::: section
## Dictionary {{MediaTrackConstraintSet}} Members

[width]{.dfn} of type {{ConstrainULong}}
:   See [width](#def-constraint-width) for details.

[height]{.dfn} of type {{ConstrainULong}}
:   See [height](#def-constraint-height) for details.

[aspectRatio]{.dfn} of type {{ConstrainDouble}}
:   See [aspectRatio](#def-constraint-aspect) for details.

[frameRate]{.dfn} of type {{ConstrainDouble}}
:   See [frameRate](#def-constraint-frameRate) for details.

[facingMode]{.dfn} of type {{ConstrainDOMString}}
:   See [facingMode](#def-constraint-facingMode) for details.

[resizeMode]{.dfn} of type {{ConstrainDOMString}}
:   See [resizeMode](#def-constraint-resizeMode) for details.

[sampleRate]{.dfn} of type {{ConstrainULong}}
:   See [sampleRate](#def-constraint-sampleRate) for details.

[sampleSize]{.dfn} of type {{ConstrainULong}}
:   See [sampleSize](#def-constraint-sampleSize) for details.

[echoCancellation]{.dfn} of type {{ConstrainBooleanOrDOMString}}
:   See [echoCancellation](#def-constraint-echoCancellation) for
    details.

[autoGainControl]{.dfn} of type {{ConstrainBoolean}}
:   See [autoGainControl](#def-constraint-autoGainControl) for details.

[noiseSuppression]{.dfn} of type {{ConstrainBoolean}}
:   See [noiseSuppression](#def-constraint-noiseSuppression) for
    details.

[latency]{.dfn} of type {{ConstrainDouble}}
:   See [latency](#def-constraint-latency) for details.

[channelCount]{.dfn} of type {{ConstrainULong}}
:   See [channelCount](#def-constraint-channelCount) for details.

[deviceId]{.dfn} of type {{ConstrainDOMString}}
:   See [deviceId](#def-constraint-deviceId) for details.

[groupId]{.dfn} of type {{ConstrainDOMString}}
:   See [groupId](#def-constraint-groupId) for details.

[backgroundBlur]{.dfn} of type {{ConstrainBoolean}}
:   See [backgroundBlur](#def-constraint-backgroundBlur) for details.
:::
::::
:::::::

::::: {#media-track-settings .section}
## [MediaTrackSettings]{.dfn}

{{MediaTrackSettings}} represents the Settings of a {{MediaStreamTrack}}
object.

Future specifications can extend the MediaTrackSettings dictionary by
defining a partial dictionary with dictionary members of appropriate
type.

:::: {}
``` idl
dictionary MediaTrackSettings {
  unsigned long width;
  unsigned long height;
  double aspectRatio;
  double frameRate;
  DOMString facingMode;
  DOMString resizeMode;
  unsigned long sampleRate;
  unsigned long sampleSize;
  (boolean or DOMString) echoCancellation;
  boolean autoGainControl;
  boolean noiseSuppression;
  double latency;
  unsigned long channelCount;
  DOMString deviceId;
  DOMString groupId;
  boolean backgroundBlur;
};
```

::: section
## Dictionary {{MediaTrackSettings}} Members

[width]{.dfn} of type {{unsigned long}}
:   See [width](#def-constraint-width) for details.

[height]{.dfn} of type {{unsigned long}}
:   See [height](#def-constraint-height) for details.

[aspectRatio]{.dfn} of type {{double}}
:   See [aspectRatio](#def-constraint-aspect) for details.

[frameRate]{.dfn} of type {{double}}
:   See [frameRate](#def-constraint-frameRate) for details.

[facingMode]{.dfn} of type {{DOMString}}
:   See [facingMode](#def-constraint-facingMode) for details.

[resizeMode]{.dfn} of type {{DOMString}}
:   See [resizeMode](#def-constraint-resizeMode) for details.

[sampleRate]{.dfn} of type {{unsigned long}}
:   See [sampleRate](#def-constraint-sampleRate) for details.

[sampleSize]{.dfn} of type {{unsigned long}}
:   See [sampleSize](#def-constraint-sampleSize) for details.

[echoCancellation]{.dfn} of type {{boolean}} or {{DOMString}}
:   See [echoCancellation](#def-constraint-echoCancellation) for
    details.

[autoGainControl]{.dfn} of type {{boolean}}
:   See [autoGainControl](#def-constraint-autoGainControl) for details.

[noiseSuppression]{.dfn} of type {{boolean}}
:   See [noiseSuppression](#def-constraint-noiseSuppression) for
    details.

[latency]{.dfn} of type {{double}}
:   See [latency](#def-constraint-latency) for details.

[channelCount]{.dfn} of type {{unsigned long}}
:   See [channelCount](#def-constraint-channelCount) for details.

[deviceId]{.dfn} of type {{DOMString}}
:   See [deviceId](#def-constraint-deviceId) for details.

[groupId]{.dfn} of type {{DOMString}}
:   See [groupId](#def-constraint-groupId) for details.

[backgroundBlur]{.dfn} of type {{boolean}}, defaulting to `true`
:   See [backgroundBlur](#def-constraint-backgroundBlur) for details.
:::
::::
:::::

::::::: section
## Constrainable Properties

The names of the initial set of constrainable properties for
MediaStreamTrack are defined below.

The following constrainable properties are defined to apply to both
video and audio {{MediaStreamTrack}} objects:

  Property Name      Type            Notes
  ------------------ --------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  [deviceId]{.dfn}   {{DOMString}}   The identifier of the device generating the content of the {{MediaStreamTrack}}. It conforms with the definition of {{MediaDeviceInfo.deviceId}}. Note that the setting of this property is uniquely determined by the source that is attached to the {{MediaStreamTrack}}. In particular, {{MediaStreamTrack/getCapabilities()}} will return only a single value for deviceId. This property can therefore be used for initial media selection with {{MediaDevices/getUserMedia()}}. However, it is not useful for subsequent media control with {{MediaStreamTrack/applyConstraints()}}, since any attempt to set a different value will result in an unsatisfiable ConstraintSet. If a string of length 0 is used as a deviceId value constraint with {{MediaDevices/getUserMedia()}}, it MAY be interpreted as if the constraint is not specified.
  [groupId]{.dfn}    {{DOMString}}   The \[=document=\]-unique group identifier for the device generating the content of the {{MediaStreamTrack}}. It conforms with the definition of {{MediaDeviceInfo.groupId}}. Note that the setting of this property is uniquely determined by the source that is attached to the {{MediaStreamTrack}}. In particular, {{MediaStreamTrack/getCapabilities()}} will return only a single value for groupId. Since this property is not stable between browsing sessions, its usefulness for initial media selection with {{MediaDevices/getUserMedia()}} is limited. It is not useful for subsequent media control with {{MediaStreamTrack/applyConstraints()}}, since any attempt to set a different value will result in an unsatisfiable ConstraintSet.

The following constrainable properties are defined to apply only to
video {{MediaStreamTrack}} objects:

+-------------------------------------------------+-----------------------+-----------------------------------------------------+
| Property Name                                   | Type                  | Notes                                               |
+=================================================+=======================+=====================================================+
| [width]{.dfn}                                   | {{unsigned long}}     | The width, in pixels. As a capability, its valid    |
|                                                 |                       | range should span the video source\'s pre-set width |
|                                                 |                       | values with min being equal to 1 and max being the  |
|                                                 |                       | largest width. The \[=User Agent=\] MUST support    |
|                                                 |                       | downsampling to any value between the min width     |
|                                                 |                       | range value and the native resolution width.        |
+-------------------------------------------------+-----------------------+-----------------------------------------------------+
| [height]{.dfn}                                  | {{unsigned long}}     | The height, in pixels. As a capability, its valid   |
|                                                 |                       | range should span the video source\'s pre-set       |
|                                                 |                       | height values with min being equal to 1 and max     |
|                                                 |                       | being the largest height. The \[=User Agent=\] MUST |
|                                                 |                       | support downsampling to any value between the min   |
|                                                 |                       | height range value and the native resolution        |
|                                                 |                       | height.                                             |
+-------------------------------------------------+-----------------------+-----------------------------------------------------+
| [frameRate]{.dfn}                               | {{double}}            | The frame rate (frames per second). If video        |
|                                                 |                       | source\'s pre-set can determine frame rates, then,  |
|                                                 |                       | as a capability, its valid range should span the    |
|                                                 |                       | video source\'s pre-set frame rate values with min  |
|                                                 |                       | being equal to 0 and max being the largest frame    |
|                                                 |                       | rate. The \[=User Agent=\] MUST support frame rates |
|                                                 |                       | obtained from integral decimation of the native     |
|                                                 |                       | resolution frame rate. If frame rate cannot be      |
|                                                 |                       | determined (e.g. the source does not natively       |
|                                                 |                       | provide a frame rate, or the frame rate cannot be   |
|                                                 |                       | determined from the source stream), then the        |
|                                                 |                       | capability values MUST refer to the \[=User         |
|                                                 |                       | Agent=\]\'s vsync display rate.                     |
|                                                 |                       |                                                     |
|                                                 |                       | As a setting, this value represents the configured  |
|                                                 |                       | frame rate. If decimation is used, this is that     |
|                                                 |                       | value rather than the native frame rate. For        |
|                                                 |                       | example, if the setting is 25 frames per second via |
|                                                 |                       | decimation, the native frame rate of the camera is  |
|                                                 |                       | 30 frames per second but due to lighting conditions |
|                                                 |                       | only 20 frames per second is achieved,              |
|                                                 |                       | {{frameRate}} reports the setting: 25 frames per    |
|                                                 |                       | second.                                             |
+-------------------------------------------------+-----------------------+-----------------------------------------------------+
| [aspectRatio]{.dfn}                             | {{double}}            | The exact aspect ratio (width in pixels divided by  |
|                                                 |                       | height in pixels, represented as a double rounded   |
|                                                 |                       | to the tenth decimal place) or aspect ratio range.  |
+-------------------------------------------------+-----------------------+-----------------------------------------------------+
| [facingMode]{.dfn}                              | {{DOMString}}         | This string is one of the members of                |
|                                                 |                       | {{VideoFacingModeEnum}}. The members describe the   |
|                                                 |                       | directions that the camera can face, as seen from   |
|                                                 |                       | the user\'s perspective. Note that                  |
|                                                 |                       | [`getConstraints`]{link-for="ConstrainablePattern"} |
|                                                 |                       | may not return exactly the same string for strings  |
|                                                 |                       | not in this enum. This preserves the possibility of |
|                                                 |                       | using a future version of WebIDL enum for this      |
|                                                 |                       | property.                                           |
+-------------------------------------------------+-----------------------+-----------------------------------------------------+
| [resizeMode]{.dfn}                              | {{DOMString}}         | This string is one of the members of                |
|                                                 |                       | {{VideoResizeModeEnum}}. The members describe the   |
|                                                 |                       | means by which the resolution can be derived by the |
|                                                 |                       | UA. In other words, whether the UA is allowed to    |
|                                                 |                       | use cropping and downscaling on the camera output.  |
|                                                 |                       |                                                     |
|                                                 |                       | The UA MAY disguise concurrent use of the camera,   |
|                                                 |                       | by downscaling, upscaling, and/or cropping to mimic |
|                                                 |                       | native resolutions when \"none\" is used, but only  |
|                                                 |                       | when the camera is in use in another application    |
|                                                 |                       | outside the \[=User Agent=\].                       |
|                                                 |                       |                                                     |
|                                                 |                       | Note that                                           |
|                                                 |                       | [`getConstraints`]{link-for="ConstrainablePattern"} |
|                                                 |                       | may not return exactly the same string for strings  |
|                                                 |                       | not in this enum. This preserves the possibility of |
|                                                 |                       | using a future version of WebIDL enum for this      |
|                                                 |                       | property.                                           |
+-------------------------------------------------+-----------------------+-----------------------------------------------------+
| [backgroundBlur]{#def-constraint-backgroundBlur | {{boolean}}           | Some platforms or User Agents may provide built-in  |
| .dfn}                                           |                       | support for background blurring of video frames, in |
|                                                 |                       | particular for camera video streams. Web            |
|                                                 |                       | applications may either want to control or at least |
|                                                 |                       | be aware that background blur is applied at the     |
|                                                 |                       | source level. This may for instance allow the web   |
|                                                 |                       | application to update its UI or to not apply        |
|                                                 |                       | background blur on its own.                         |
+-------------------------------------------------+-----------------------+-----------------------------------------------------+

On systems where it\'s desirable to sometimes automatically flip the X
and Y axis of the resulting captured video in response to ongoing
environmental factors, the {{width}}, {{height}} and {{aspectRatio}}
constraints and capabilities MUST remain unaffected in all algorithms
and be considered in the primary orientation only, except for the
{{MediaStreamTrack/getSettings()}} algorithm where settings for these
constrainable properties MUST be flipped if necessary to match the
returned dimensions of the captured video at any point in time.

The [primary orientation]{.dfn} of a system that supports flipping the X
and Y axis of resulting captured video is defined by the User Agent for
the particular system.

::: note
On systems that support automatic switching between landscape and
portrait mode, \[=User Agents=\] are encouraged to make landscape mode
the primary orientation.
:::

::: {}
``` idl
enum VideoFacingModeEnum {
  "user",
  "environment",
  "left",
  "right"
};
```

  Enum value                                                        Description
  ----------------------------------------------------------------- --------------------------------------------------------------------
  [`user`{#idl-def-VideoFacingModeEnum.user}]{.dfn}                 The source is facing toward the user (a self-view camera).
  [`environment`{#idl-def-VideoFacingModeEnum.environment}]{.dfn}   The source is facing away from the user (viewing the environment).
  [`left`{#idl-def-VideoFacingModeEnum.left}]{.dfn}                 The source is facing to the left of the user.
  [`right`{#idl-def-VideoFacingModeEnum.right}]{.dfn}               The source is facing to the right of the user.

  : [VideoFacingModeEnum]{.dfn} Enumeration description {.simple
  link-for="VideoFacingModeEnum" dfn-for="VideoFacingModeEnum"}
:::

Below is an illustration of the video facing modes in relation to the
user.\
![Illustration of video facing modes in relation to
user](images/camera-names-exp.svg){style="width:40%"}

::: {}
``` idl
enum VideoResizeModeEnum {
  "none",
  "crop-and-scale"
};
```

+------------------------------------------------------------+-----------------------------------+
| Enum value                                                 | Description                       |
+============================================================+===================================+
| [none]{#idl-def-VideoResizeModeEnum.none .dfn}             | This resolution and frame rate is |
|                                                            | offered by the camera, its        |
|                                                            | driver, or the OS.                |
|                                                            |                                   |
|                                                            | Note: The UA MAY report this      |
|                                                            | value to disguise concurrent use, |
|                                                            | but only when the camera is in    |
|                                                            | use in another \[=navigable=\].   |
+------------------------------------------------------------+-----------------------------------+
| [crop-and-scale]{#idl-def-VideoResizeModeEnum.cropandscale | This resolution is downscaled     |
| .dfn}                                                      | and/or cropped from a higher      |
|                                                            | camera resolution by the \[=User  |
|                                                            | Agent=\], or its frame rate is    |
|                                                            | decimated by the \[=User          |
|                                                            | Agent=\]. The media MUST NOT be   |
|                                                            | upscaled, stretched or have fake  |
|                                                            | data created that did not occur   |
|                                                            | in the input source, except as    |
|                                                            | noted below.                      |
|                                                            |                                   |
|                                                            | Note: The UA MAY upscale to       |
|                                                            | disguise concurrent use, but only |
|                                                            | when the camera is in use in      |
|                                                            | another application outside the   |
|                                                            | \[=User Agent=\].                 |
+------------------------------------------------------------+-----------------------------------+

: [VideoResizeModeEnum]{.dfn} Enumeration description {.simple
link-for="VideoResizeModeEnum" dfn-for="VideoResizeModeEnum"}
:::

The following constrainable properties are defined to apply only to
audio {{MediaStreamTrack}} objects:

  Property Name              Values                         Notes
  -------------------------- ------------------------------ ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  [sampleRate]{.dfn}         {{unsigned long}}              The sample rate in samples per second for the audio data.
  [sampleSize]{.dfn}         {{unsigned long}}              The linear sample size in bits. As a constraint, it can only be satisfied for audio devices that produce linear samples.
  [echoCancellation]{.dfn}   {{boolean}} or {{DOMString}}   This is either `false`, `true`, or one of the members of {{EchoCancellationModeEnum}}. When one or more audio streams are being played in the processes of various microphones, it is often desirable to attempt to remove sound being played from the input signals recorded by the microphones. This is referred to as echo cancellation. There are cases where it is not needed and it is desirable to turn it off so that no audio artifacts are introduced. This allows applications to control this behavior.
  [autoGainControl]{.dfn}    {{boolean}}                    Automatic gain control is often desirable on the input signal recorded by the microphone. There are cases where it is not needed and it is desirable to turn it off so that the audio is not altered. This allows applications to control this behavior.
  [noiseSuppression]{.dfn}   {{boolean}}                    Noise suppression is often desirable on the input signal recorded by the microphone. There are cases where it is not needed and it is desirable to turn it off so that the audio is not altered. This allows applications to control this behavior.
  [latency]{.dfn}            {{double}}                     The latency or latency range, in seconds. The latency is the time between start of processing (for instance, when sound occurs in the real world) to the data being available to the next step in the process. Low latency is critical for some applications; high latency may be acceptable for other applications because it helps with power constraints. The number is expected to be the target latency of the configuration; the actual latency may show some variation from that.
  [channelCount]{.dfn}       {{unsigned long}}              The number of independent channels of sound that the audio data contains, i.e. the number of audio samples per sample frame.

::: {}
``` idl
enum EchoCancellationModeEnum {
  "all",
  "remote-only"
};
```

+----------------------------------------------+-----------------------------------+
| Enum value                                   | Description                       |
+==============================================+===================================+
| {{EchoCancellationModeEnum/\"all\"}}         | The system MUST attempt to remove |
|                                              | all sound being played by the     |
|                                              | system from the input signal of   |
|                                              | the microphone.                   |
|                                              |                                   |
|                                              | This option is meant to provide   |
|                                              | maximum privacy, as it prevents   |
|                                              | the transmission of local audio   |
|                                              | such as notifications or screen   |
|                                              | readers.                          |
+----------------------------------------------+-----------------------------------+
| {{EchoCancellationModeEnum/\"remote-only\"}} | The system MUST attempt to remove |
|                                              | the sound from incoming audio     |
|                                              | {{MediaStreamTrack}}s sourced     |
|                                              | from WebRTC                       |
|                                              | {{RTCPeerConnection}}s.           |
|                                              |                                   |
|                                              | This option is useful for cases   |
|                                              | where it is desirable to transmit |
|                                              | locally played audio. One example |
|                                              | is a remote music class, where a  |
|                                              | student plays an instrument       |
|                                              | together with some accompaniment  |
|                                              | produced by a local application.  |
|                                              | In this case, the application     |
|                                              | requires audio coming from the    |
|                                              | remote participant (i.e., the     |
|                                              | teacher) to be cancelled in order |
|                                              | to avoid echo, but also requires  |
|                                              | that the accompaniment not be     |
|                                              | cancelled since the music teacher |
|                                              | on the remote side needs to hear  |
|                                              | it together with the sound from   |
|                                              | the instrument.                   |
|                                              |                                   |
|                                              | It is up to the UA to decide      |
|                                              | which {{RTCPeerConnection}}s to   |
|                                              | cancel, but the ones being played |
|                                              | out by the browsing context       |
|                                              | capturing microphone SHOULD be    |
|                                              | among those cancelled.            |
+----------------------------------------------+-----------------------------------+

: [EchoCancellationModeEnum]{.dfn} Enumeration description {.simple
link-for="EchoCancellationModeEnum" dfn-for="EchoCancellationModeEnum"}

In addition to the values from {{EchoCancellationModeEnum}}, the
{{echoCancellation}} constrainable property also accepts the values
`true` and `false`. `false` means that no echo cancellation will take
place. `true` means that the UA decides what audio will be removed from
the signals recorded by the microphone. `true` MUST attempt to cancel at
least as much as {{EchoCancellationModeEnum/\"remote-only\"}} and SHOULD
attempt to cancel as much as {{EchoCancellationModeEnum/\"all\"}}.
:::
:::::::

:::: section
## Garbage Collection

A {{MediaStreamTrack}} object MUST NOT be garbage collected if it is not
\[=MediaStreamTrack/ended=\] and there are any event listeners
registered for [mute]{lt="muted"}, [unmute]{lt="unmuted"} or
[ended]{lt="ended"} events. Each source type can further refine the
garbage collection rules as sources may never fire a particular event.

::: note
Authors are encouraged to call stop() on {{MediaStreamTrack}},
especially capture tracks since the underlying resource are costly and
it can have effects on the privacy indicators presented to the user.
:::
::::
::::::::::::::::::::::::::::::::::::

:::::::: section
### {{MediaStreamTrackEvent}}

The {{addtrack}} and {{removetrack}} events use the
{{MediaStreamTrackEvent}} interface.

The {{addtrack}} and {{removetrack}} events notify the script that the
\[=track set=\] of a {{MediaStream}} has been updated by the \[=User
Agent=\].

[Firing a track event named `e`{.variable}]{.dfn
lt="Fire a track event"} with a {{MediaStreamTrack}} `track`{.variable}
means that an event with the name `e`{.variable}, which does not bubble
(except where otherwise stated) and is not cancelable (except where
otherwise stated), and which uses the {{MediaStreamTrackEvent}}
interface with the {{MediaStreamTrackEvent/track}} attribute set to
`track`{.variable}, MUST be created and dispatched at the given target.

::::: {}
``` idl
[Exposed=Window]
interface MediaStreamTrackEvent : Event {
  constructor(DOMString type, MediaStreamTrackEventInit eventInitDict);
  [SameObject] readonly attribute MediaStreamTrack track;
};
```

::: section
## Constructors

[constructor()]{.dfn}

:   Constructs a new {{MediaStreamTrackEvent}}.
:::

::: section
## Attributes

{{track}} of type {{MediaStreamTrack}}, readonly

:   The [track]{#dom-mediastreamtrackevent-track .dfn} attribute
    represents the {{MediaStreamTrack}} object associated with the
    event.
:::
:::::

:::: {}
``` idl
dictionary MediaStreamTrackEventInit : EventInit {
  required MediaStreamTrack track;
};
```

::: section
## Dictionary [MediaStreamTrackEventInit]{.dfn} Members

[track]{.dfn} of type {{MediaStreamTrack}}, required

:   
:::
::::
::::::::
::::::::::::::::::::::::::::::::::::::::::::::::::

:::: {#the-model-sources-sinks-constraints-and-settings .section .informative data-cite="?webrtc"}
## The model: sources, sinks, constraints, and settings

\[=User Agents=\] provide a media pipeline from sources to sinks. In a
\[=User Agent=\], sinks are the \<\[\^img\^\]\>, \<\[\^video\^\]\>, and
\<\[\^audio\^\]\> tags. Traditional sources include streamed content,
files, and web resources. The media produced by these sources typically
does not change over time - these sources can be considered to be
static.

The sinks that display these sources to the user (the actual tags
themselves) have a variety of controls for manipulating the source
content. For example, an \<\[\^img\^\]\> tag scales down a huge source
image of 1600x1200 pixels to fit in a rectangle defined with
`width="400"` and `height="300"`.

Sources have a lifetime. By default, a source lifetime is tied to the
context that created it. For instance, sources created by
{{MediaDevices.getUserMedia()}} are considered as created by its
navigator.{{mediaDevices}} context. Similarly, sources of
{{RTCRtpReceiver}} objects are bound to the {{RTCPeerConnection}}
itself, which is bound to its creation context. Except if stated
explicitly in the definition of specific sources, a source is always \[=
source/stopped =\] when its creation context goes away. It should be
noted that two sources of different contexts may use the same capture
device at the same time. One source can be stopped independently of the
other one.

The getUserMedia API adds dynamic sources such as microphones and
cameras - the characteristics of these sources can change in response to
application needs. These sources can be considered to be dynamic in
nature. A \<\[\^video\^\]\> element that displays media from a dynamic
source can either perform scaling or it can feed back information along
the media pipeline and have the source produce content more suitable for
display.

::: note
**Note:** This sort of feedback loop is obviously just enabling an
\"optimization\", but it\'s a non-trivial gain. This optimization can
save battery, allow for less network congestion, etc\...
:::

Note that {{MediaStream}} sinks (such as \<\[\^video\^\]\>,
\<\[\^audio\^\]\>, and even {{RTCPeerConnection}}) will continue to have
mechanisms to further transform the source stream beyond that which the
Settings, Capabilities, and Constraints described in this specification
offer. (The sink transformation options, including those of
{{RTCPeerConnection}}, are outside the scope of this specification.)

The act of changing or applying a track constraint may affect the
\[=settings=\] of all tracks sharing that source and consequently all
down-level sinks that are using that source. Many sinks may be able to
take these changes in stride, such as the `<[^video^]>` element or
{{RTCPeerConnection}}. Others like the Recorder API may fail as a result
of a source setting change.

The {{RTCPeerConnection}} is an interesting object because it acts
simultaneously as both a sink **and** a source for over-the-network
streams. As a sink, it has source transformational capabilities (e.g.,
lowering bit-rates, scaling-up / down resolutions, and adjusting
frame-rates), and as a source it could have its own settings changed by
a track source.

To illustrate how changes to a given source impact various sinks,
consider the following example. This example only uses width and height,
but the same principles apply to all of the Settings exposed in this
specification. In the first figure a home client has obtained a video
source from its local video camera. The source\'s width and height
settings are 800 pixels and 600 pixels, respectively. Three
{{MediaStream}} objects on the home client contain tracks that use this
same \<{{MediaStreamTrack/deviceId}}. The three media streams are
connected to three different sinks: a `<[^video^]>` element (A), another
`<[^video^]>` element (B), and a peer connection (C). The peer
connection is streaming the source video to a remote client. On the
remote client there are two media streams with tracks that use the peer
connection as a source. These two media streams are connected to two
`<[^video^]>` element sinks (Y and Z).

![Changing media stream source effects: before the requested
change](images/change_states_before.svg)

Note that at this moment, all of the sinks on the home client must apply
a transformation to the original source\'s provided dimension settings.
B is scaling the video down, A is scaling the video up (resulting in
loss of quality), and C is also scaling the video up slightly for
sending over the network. On the remote client, sink Y is scaling the
video *way* down, while sink Z is not applying any scaling.

In response to {{MediaStreamTrack/applyConstraints()}} being called, one
of the tracks wants a higher resolution (1920 by 1200 pixels) from the
home client\'s video source.

![Changing media stream source effects: after the requested
change](images/change_states_after.svg)

Note that the source change immediately affects all of the tracks and
sinks on the home client, but does not impact any of the sinks (or
sources) on the remote client. With the increase in the home client
source video\'s dimensions, sink A no longer has to perform any scaling,
while sink B must scale down even further than before. Sink C (the peer
connection) must now scale down the video in order to keep the
transmission constant to the remote client.

While not shown, an equally valid settings change request could be made
on the remote client\'s side. In addition to impacting sink Y and Z in
the same manner as A, B and C were impacted earlier, it could lead to
re-negotiation with the peer connection on the home client in order to
alter the transformation that it is applying to the home client\'s video
source. Such a change is NOT REQUIRED to change anything related to sink
A or B or the home client\'s video source.

Note that this specification does not define a mechanism by which a
change to the remote client\'s video source could automatically trigger
a change to the home client\'s video source. Implementations may choose
to make such source-to-sink optimizations as long as they only do so
within the constraints established by the application, as the next
example demonstrates.

It is fairly obvious that changes to a given source will impact sink
consumers. However, in some situations changes to a given sink may also
cause implementations to adjust a source\'s settings. This is
illustrated in the following figures. In the first figure below, the
home client\'s video source is sending a video stream sized at 1920 by
1200 pixels. The video source is also unconstrained, such that the exact
source dimensions are flexible as far as the application is concerned.
Two {{MediaStream}} objects contain tracks with the same
{{MediaStreamTrack/deviceId}}, and those {{MediaStream}}s are connected
to two different `<[^video^]>` element sinks A and B. Sink A has been
sized to `width="1920"` and `height="1200"` and is displaying the
source\'s video content without any transformations. Sink B has been
sized smaller and, as a result, is scaling the video down to fit its
rectangle of 320 pixels across by 200 pixels down.

![Changing media stream sinks may affect sources: before the requested
change](images/change_states_before2.svg)

When the application changes sink A to a smaller dimension (from 1920 to
1024 pixels wide and from 1200 to 768 pixels tall), the \[=User
Agent=\]\'s media pipeline may recognize that none of its sinks require
the higher source resolution, and needless work is being done both on
the part of the source and sink A. In such a case and without any other
constraints forcing the source to continue producing the higher
resolution video, the media pipeline MAY change the source resolution:

![Changing media stream sinks may affect sources: after the requested
change](images/change_states_after2.svg)

In the above figure, the home client\'s video source resolution was
changed to the greater of that from sink A and B in order to optimize
playback. While not shown above, the same behavior could apply to peer
connections and other sinks.

It is possible that constraints can be applied to a track which a source
is unable to satisfy, either because the source itself cannot satisfy
the constraint or because the source is already satisfying a conflicting
constraint. When this happens, the promise returned from
{{MediaStreamTrack/applyConstraints()}} will be rejected, without
applying any of the new constraints. Since no change in constraints
occurs in this case, there is also no required change to the source
itself as a result of this condition. Here is an example of this
behavior.

In this example, two media streams each have a video track that share
the same source. The first track initially has no constraints applied.
It is connected to sink N. Sink N has a resolution of 800 by 600 pixels
and is scaling down the source\'s resolution of 1024 by 768 to fit. The
other track has a [required constraint]{lt="required constraints"}
forcing off the source\'s fill light; it is connected to sink P. Sink P
has a width and height equal to that of the source.

![Overconstrained application](images/overconstrained_apply.svg)

Now, the first track adds a [required
constraint]{lt="required constraints"} that the fill light should be
forced on. At this point, both required constraints cannot be satisfied
by the source (the fill light cannot be simultaneously on and off at the
same time). Since this state was caused by the first track\'s attempt to
apply a conflicting constraint, the constraint application fails and
there is no change in the source\'s settings nor to the constraints on
either track.
::::

:::: section
## MediaStreams in Media Elements

A {{MediaStream}} may be assigned to media elements. A {{MediaStream}}
is not preloadable or seekable and represents a simple, potentially
infinite, linear [media timeline]{data-cite="!HTML/#media-timeline"}.
The timeline starts at 0 and increments linearly in real time as long as
the media element is [potentially
playing]{data-cite="!HTML/#potentially-playing"}. The timeline does not
increment when the playout of the {{MediaStream}} is paused.

\[=User Agents=\] that support this specification MUST support the
{{HTMLMediaElement/srcObject}} attribute of the {{HTMLMediaElement}}
interface defined in \[\[HTML\]\], which includes support for playing
{{MediaStream}} objects.

The \[\[HTML\]\] document outlines how the {{HTMLMediaElement}} works
with a *media provider object*. The following applies when the *media
provider object* is a {{MediaStream}}:

- Whenever an {{AudioTrack}} or a {{VideoTrack}} is created, the `id`
  and `label` attributes must be initialized to the corresponding
  attributes of the {{MediaStreamTrack}}, the `kind` attribute must be
  initialized to `"main"` and the `language` attribute to the empty
  string

- The \[=User Agent=\] MUST always play the current data from the
  {{MediaStream}} and MUST NOT buffer.

- Since the order in the {{MediaStream}} \'s \[=track set=\] is
  undefined, no requirements are put on how the {{AudioTrackList}} and
  {{VideoTrackList}} is ordered

- If the element is an {{HTMLVideoElement}}, then it is said to have
  [ended playback]{data-cite="!HTML/#ended-playback"} when it has ended
  video playback, which is when:

  1.  The element\'s {{HTMLMediaElement/readyState}} is
      {{HTMLMediaElement/HAVE_METADATA}} or greater, and

      1.  The {{MediaStream}} state is \[= stream/inactive =\] after
          having been \[= stream/active =\], or

      2.  The {{MediaStream}} state is \[= stream/active =\] after
          having been \[= stream/inactive =\] after having been \[=
          stream/active =\] after {{HTMLMediaElement/play()}} was last
          called, and {{HTMLMediaElement/autoplay}} is `false`.

      ::: note
      Once playback has ended, it won\'t resume if new
      {{MediaStreamTrack}}s are added to the {{MediaStream}} unless
      {{HTMLMediaElement/autoplay}} is `true` or the element is
      restarted, e.g., by the web application calling
      {{HTMLMediaElement/play()}}.
      :::

- If the element is an {{HTMLAudioElement}}, then it is said to have
  [ended playback]{data-cite="!HTML/#ended-playback"} when it has ended
  audio playback, which is when:

  1.  The element\'s {{HTMLMediaElement/readyState}} is
      {{HTMLMediaElement/HAVE_METADATA}} or greater, and

      1.  The {{MediaStream}} state is \[= stream/inaudible =\] after
          having been \[= stream/audible =\], or

      2.  The {{MediaStream}} state is \[= stream/audible =\] after
          having been \[= stream/inaudible =\] after having been \[=
          stream/audible =\] after {{HTMLMediaElement/play()}} was last
          called, and {{HTMLMediaElement/autoplay}} is `false`.

      ::: note
      Once playback has ended, it won\'t resume if new audio
      {{MediaStreamTrack}}s are added to the {{MediaStream}} unless
      {{HTMLMediaElement/autoplay}} is `true` or the element is
      restarted, e.g., by the web application calling
      {{HTMLMediaElement/play()}}.
      :::

- Any calls to the {{HTMLMediaElement/fastSeek()}} method on a
  {{HTMLMediaElement}} must be ignored

The nature of the {{MediaStream}} places certain restrictions on the
behavior of attributes of the associated {{HTMLMediaElement}} and on the
operations that can be performed on it, as shown below:

  ------------------------------------------------------------------------------------------------------------------------------------------------------------
  Attribute Name                             Attribute Type    Setter/Getter Behavior When         Additional considerations
                                                               Provider is a MediaStream           
  ------------------------------------------ ----------------- ----------------------------------- -----------------------------------------------------------
  {{HTMLMediaElement/preload}}               {{DOMString}}     On getting: `none`. On setting:     A {{MediaStream}} cannot be preloaded.
                                                               ignored.                            

  {{HTMLMediaElement/buffered}}              {{TimeRanges}}    `buffered.length` MUST return `0`.  A {{MediaStream}} cannot be preloaded. Therefore, the
                                                                                                   amount buffered is always an empty time range.

  {{HTMLMediaElement/currentTime}}           {{double}}        Any non-negative integer. The       The value is the [official playback
                                                               initial value is `0` and the values position]{data-cite="!HTML/#official-playback-position"},
                                                               increments linearly in real time    in seconds. Any attempt to alter it MUST be ignored.
                                                               whenever the element is \[=media    
                                                               element/potentially playing=\].     

  {{HTMLMediaElement/seeking}}               {{boolean}}       `false`                             A {{MediaStream}} is not seekable. Therefore, this
                                                                                                   attribute MUST always return the value `false`.

  {{HTMLMediaElement/defaultPlaybackRate}}   {{double}}        On getting: `1.0`. On setting:      A {{MediaStream}} is not seekable. Therefore, this
                                                               ignored.                            attribute MUST always return the value `1.0` and any
                                                                                                   attempt to alter it MUST be ignored. Note that this also
                                                                                                   means that the
                                                                                                   [`ratechange`]{data-cite="!HTML/#event-media-ratechange"}
                                                                                                   event will not fire.

  {{HTMLMediaElement/playbackRate}}          {{double}}        On getting: `1.0`. On setting:      A {{MediaStream}} is not seekable. Therefore, this
                                                               ignored.                            attribute MUST always return the value `1.0` and any
                                                                                                   attempt to alter it MUST be ignored. Note that this also
                                                                                                   means that the
                                                                                                   [`ratechange`]{data-cite="!HTML/#event-media-ratechange"}
                                                                                                   event will not fire.

  {{HTMLMediaElement/played}}                {{TimeRanges}}    `played.length` MUST return `1`.\   A {{MediaStream}}\'s timeline always consists of a single
                                                               `played.start(0)` MUST return `0`.\ range, starting at 0 and extending up to the currentTime.
                                                               `played.end(0)` MUST return the     
                                                               last known                          
                                                               {{HTMLMediaElement/currentTime}}.   

  {{HTMLMediaElement/seekable}}              {{TimeRanges}}    `seekable.length` MUST return `0`.  A {{MediaStream}} is not seekable.

  {{HTMLMediaElement/loop}}                  {{boolean}}       `true`, `false`                     Setting the {{HTMLMediaElement/loop}} attribute has no
                                                                                                   effect since a {{MediaStream}} has no defined end and
                                                                                                   therefore cannot be looped.
  ------------------------------------------------------------------------------------------------------------------------------------------------------------

Since none of the setters listed above alter internal state of the
{{HTMLMediaElement}}, once a {{MediaStream}} is no longer the element\'s
[assigned media provider
object]{data-cite="HTML#assigned-media-provider-object"}, the attributes
listed will appear to resume the values they had before a stream was
assigned to the element.

::: note
A {{MediaStream}} stops being the element\'s [assigned media provider
object]{data-cite="HTML#assigned-media-provider-object"} when
{{HTMLMediaElement/srcObject}} is assigned `null` or a non-stream
object, just ahead of the [media element load
algorithm]{data-cite="HTML#media-element-load-algorithm"}. As a result,
the [`ratechange`]{data-cite="!HTML/#event-media-ratechange"} event may
fire (from step 7) if {{HTMLMediaElement/playbackRate}} and
{{HTMLMediaElement/defaultPlaybackRate}} were different from before a
{{MediaStream}} was assigned.
:::
::::

::::::: section
## Error Handling

Some operations throw or fire `OverconstrainedError`. This is an
extension of {{DOMException}} that carries additional information
related to constraints failure.

:::::: section
## OverconstrainedError Interface

::: {}
``` {.idl tests=""}
[Exposed=Window]
interface OverconstrainedError : DOMException {
  constructor(DOMString constraint, optional DOMString message = "");
  readonly attribute DOMString constraint;
};
```
:::

::: section
## Constructors

[`OverconstrainedError`]{.dfn idl=""}

:   Run the following steps:

    1.  Let `constraint`{.variable} be the constructor\'s first
        argument.

    2.  Let `message`{.variable} be the constructor\'s second argument.

    3.  Let `e`{.variable} be a new {{OverconstrainedError}} object.

    4.  Invoke the {{DOMException}} constructor of `e`{.variable} with
        the `message` argument set to `message`{.variable} and the
        `name` argument set to `"OverconstrainedError"`.

        This name does not have a mapping to a legacy code so
        `e`{.variable}\'s `code` attribute will return 0.

    5.  Set `e.constraint`{.variable} to `constraint`{.variable}.

    6.  Return `e`{.variable}.
:::

::: section
## Attributes

[`constraint`]{.dfn idl=""} of type [{{DOMString}}]{.idlAttrType}, readonly

:   The name of a constraint associated with this error, or `""` if no
    specific constraint name is revealed.
:::
::::::
:::::::

::: {.section .informative}
## Event summary

The following events fire on {{MediaStream}} objects:

  Event name                                                            Interface                   Fired when\...
  --------------------------------------------------------------------- --------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------
  [addtrack]{#event-mediastream-addtrack .dfn dfn-type="event"}         {{MediaStreamTrackEvent}}   A new {{MediaStreamTrack}} has been added to this stream. Note that this event is not fired when the script directly modifies the tracks of a {{MediaStream}}.
  [removetrack]{#event-mediastream-removetrack .dfn dfn-type="event"}   {{MediaStreamTrackEvent}}   A {{MediaStreamTrack}} has been removed from this stream. Note that this event is not fired when the script directly modifies the tracks of a {{MediaStream}}.

The following events fire on {{MediaStreamTrack}} objects:

  Event name                                                       Interface   Fired when\...
  ---------------------------------------------------------------- ----------- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  [mute]{#event-mediastreamtrack-mute .dfn dfn-type="event"}       {{Event}}   The {{MediaStreamTrack}} object\'s source is temporarily unable to provide data.
  [unmute]{#event-mediastreamtrack-unmute .dfn dfn-type="event"}   {{Event}}   The {{MediaStreamTrack}} object\'s source is live again after having been temporarily unable to provide data.
  [ended]{#event-mediastreamtrack-ended .dfn dfn-type="event"}     {{Event}}   The {{MediaStreamTrack}} object\'s source will no longer provide any data, either because the user revoked the permissions, or because the source device has been ejected, or because the remote peer permanently stopped sending data.

The following events fire on {{MediaDevices}} objects:

  Event name                                                               Interface               Fired when\...
  ------------------------------------------------------------------------ ----------------------- --------------------------------------------------------------------------------------------------------------------------------------------------------------------
  [devicechange]{#event-mediadevices-devicechange .dfn dfn-type="event"}   {{DeviceChangeEvent}}   The set of media devices, available to the \[=User Agent=\], has changed. The current list of devices is available in the {{DeviceChangeEvent/devices}} attribute.
:::

::::::::::::::::::::::::::::::: {#enumerating-devices .section}
## Enumerating Local Media Devices

This section describes an API that the script can use to query the User
Agent about connected media input and output devices (for example a web
camera or a headset).

::::: section
### \`Navigator\` Interface Extensions

Each {{Window}} has an [associated \`MediaDevices\`]{.dfn}, which is a
{{MediaDevices}} object. Upon creation of the {{Window}} object, its
\[=associated \`MediaDevices\`=\] MUST be set to a newly \[=create a
MediaDevices \| created MediaDevices=\] object with the {{Window}}
object\'s \[=relevant realm=\].

:::: {}
``` idl
partial interface Navigator {
  [SameObject, SecureContext] readonly attribute MediaDevices mediaDevices;
};
```

::: section
## Attributes

[mediaDevices]{.dfn} of type {{MediaDevices}}, readonly

:   Return \[=this=\]\'s \[=relevant global object=\]\'s \[=associated
    \`MediaDevices\`=\].
:::
::::
:::::

::::::::::::: section
### {{MediaDevices}}

The [MediaDevices]{.dfn} object is the entry point to the API used to
examine and get access to media devices available to the \[=User
Agent=\].

To [create a MediaDevices]{.dfn .abstract-op} object, given
`realm`{.variable}, run the following steps:

1.  Let `mediaDevices`{.variable} be a new {{MediaDevices}} object in
    `realm`{.variable}, initalized with the following internal slots:

    - [\[\[\\devicesLiveMap\]\]]{.dfn}, initialized to an empty
      \[=ordered map \| map=\].

    - [\[\[\\devicesAccessibleMap\]\]]{.dfn}, initialized to an empty
      \[=ordered map \| map=\].

    - [\[\[\\kindsAccessibleMap\]\]]{.dfn}, initialized to an empty
      \[=ordered map \| map=\].

    - [\[\[\\storedDeviceList\]\]]{.dfn dfn-for="MediaDevices"},
      initialized to a \[=list=\] of all media input and output devices
      available to the \[=User Agent=\].

    - [\[\[\\canExposeCameraInfo\]\]]{.dfn dfn-for="MediaDevices"},
      initialized to `false`.

    - [\[\[\\canExposeMicrophoneInfo\]\]]{.dfn dfn-for="MediaDevices"},
      initialized to `false`.

    - [\[\[\\mediaStreamTrackSources\]\]]{.dfn dfn-for="MediaDevices"},
      initialized to an empty \[=set=\].

2.  Let `settings`{.variable} be `mediaDevices`{.variable}\'s
    \[=relevant settings object=\].

3.  For each kind of device, `kind`{.variable}, that
    {{MediaDevices.getUserMedia()}} exposes, run the following step:

    1.  Set
        `mediaDevices`{.variable}.{{MediaDevices/\[\[kindsAccessibleMap\]\]}}`[kind]`{.variable}
        to either `true` if the \[=permission state=\] of the permission
        associated with `kind`{.variable} (e.g. \"camera\",
        \"microphone\") for `settings`{.variable} is
        {{PermissionState/\"granted\"}}, or to `false` otherwise.

4.  For each individual device that {{MediaDevices.getUserMedia()}}
    exposes, using the device\'s deviceId, `deviceId`{.variable}, run
    the following step:

    1.  Set
        `mediaDevices`{.variable}.{{MediaDevices/\[\[devicesLiveMap\]\]}}`[deviceId]`{.variable}
        to `false`, and set
        `mediaDevices`{.variable}.{{MediaDevices/\[\[devicesAccessibleMap\]\]}}`[deviceId]`{.variable}
        to either `true` if the \[=permission state=\] of the permission
        associated with the device's kind and `deviceId`{.variable} for
        `settings`{.variable}, is {{PermissionState/\"granted\"}}, or to
        `false` otherwise.

5.  Return `mediaDevices`{.variable}.

For each kind of device, `kind`{.variable}, that
{{MediaDevices/getUserMedia()}} exposes, \[=permission state\|whenever a
transition occurs of the permission state=\] of the permission
associated with `kind`{.variable} for `mediaDevices`{.variable}\'s
\[=relevant settings object=\], run the following steps:

1.  If the transition is to {{PermissionState/\"granted\"}} from another
    value, then set
    `mediaDevices`{.variable}.{{MediaDevices/\[\[kindsAccessibleMap\]\]}}`[kind]`{.variable}
    to `true`.

2.  If the transition is from {{PermissionState/\"granted\"}} to another
    value, then set
    `mediaDevices`{.variable}.{{MediaDevices/\[\[kindsAccessibleMap\]\]}}`[kind]`{.variable}
    to `false`.

For each device that {{MediaDevices/getUserMedia()}} exposes, whenever a
transition occurs of the \[=permission state=\] of the permission
associated with the device\'s kind and the device\'s deviceId,
`deviceId`{.variable}, for `mediaDevices`{.variable}\'s \[=relevant
settings object=\], run the following steps:

1.  If the transition is to {{PermissionState/\"granted\"}} from another
    value, then set
    `mediaDevices`{.variable}.{{MediaDevices/\[\[devicesAccessibleMap\]\]}}`[deviceId]`{.variable}
    to `true`, if it isn't already `true`.

2.  If the transition is from {{PermissionState/\"granted\"}} to another
    value, and the device is currently \[= source/stopped =\], then set
    `mediaDevices`{.variable}.{{MediaDevices/\[\[devicesAccessibleMap\]\]}}`[deviceId]`{.variable}
    to `false`.

When new media input and/or output devices are made available to the
\[=User Agent=\], or any available input and/or output device becomes
unavailable, or the system default for input and/or output devices of a
{{MediaDeviceKind}} changed, the \[=User Agent=\] MUST run the following
[device change notification steps]{.dfn .abstract-op} for each
{{MediaDevices}} object, `mediaDevices`{.variable}, for which \[=device
enumeration can proceed=\] is `true`, but for no other {{MediaDevices}}
object:

1.  Let `lastExposedDevices`{.variable} be the result of \[=creating a
    list of device info objects=\] with `mediaDevices`{.variable} and
    `mediaDevices`{.variable}.{{MediaDevices/\[\[storedDeviceList\]\]}}.

2.  Let `deviceList`{.variable} be the list of all media input and/or
    output devices available to the \[=User Agent=\].

3.  Let `newExposedDevices`{.variable} be the result of \[=creating a
    list of device info objects=\] with `mediaDevices`{.variable} and
    `deviceList`{.variable}.

4.  If the {{MediaDeviceInfo}} objects in `newExposedDevices`{.variable}
    match those in `lastExposedDevices`{.variable} and have the same
    order, then abort these steps.

    ::: note
    Due to the {{MediaDevices/enumerateDevices}} algorithm, the above
    step limits firing the [devicechange]{link-type="event"} event to
    documents \[=allowed to use=\] {{MediaDevices/enumerateDevices}} to
    enumerate devices of a particular {{MediaDeviceKind}}.
    :::

5.  Set
    `mediaDevices`{.variable}.{{MediaDevices/\[\[storedDeviceList\]\]}}
    to `deviceList`{.variable}.

6.  Queue a task that \[= fire an event \| fires an event=\] named
    {{devicechange}}, using the {{DeviceChangeEvent}} constructor with
    {{DeviceChangeEventInit/devices}} initialized to
    `newExposedDevices`{.variable}, at `mediaDevices`{.variable}.

    The \[=User Agent=\] MAY combine firing multiple events into firing
    one event when several events are due or when multiple devices are
    added or removed at the same time, e.g. a camera with a microphone.

Additionally, if a {{MediaDevices}} object that was traversed comes to
meet the \[=device enumeration can proceed=\] criteria later (e.g.
\[=Document/is in view \| comes into view=\]), the \[=User Agent=\] MUST
execute the \[=device change notification steps=\] on the
{{MediaDevices}} object at that time.

::: note
These events are potentially triggered simultaneously on documents of
different origins. \[=User Agents=\] MAY add fuzzing on the timing of
events to avoid cross-origin activity correlation.
:::

::::: {}
``` idl
[Exposed=Window, SecureContext]
interface MediaDevices : EventTarget {
  attribute EventHandler ondevicechange;
  Promise<sequence<MediaDeviceInfo>> enumerateDevices();
};
```

::: section
## Attributes

[ondevicechange]{.dfn} of type {{EventHandler}}

:   The event type of this event handler is
    [devicechange]{link-type="event"}.
:::

::: section
## Methods

[enumerateDevices]{.dfn}

:   Collects information about the \[=User Agent=\]\'s available media
    input and output devices.

    This method returns a promise. The promise will be \[=upon
    fulfillment\|fulfilled=\] with a sequence of {{MediaDeviceInfo}}
    objects representing the \[=User Agent=\]\'s available media input
    and output devices if enumeration is successful.

    Elements of this sequence that represent input devices will be of
    type {{InputDeviceInfo}} which extends {{MediaDeviceInfo}}.

    Camera and microphone sources SHOULD be enumerable. Specifications
    that add additional types of source will provide recommendations
    about whether the source type should be enumerable.

    When the {{MediaDevices/enumerateDevices()}} method is called, the
    \[=User Agent=\] must run the following steps:

    1.  Let `p`{.variable} be a new promise.

    2.  Let `proceed`{.variable} be the result of \[=device enumeration
        can proceed=\] with \[=this=\].

    3.  Let `mediaDevices`{.variable} be \[=this=\].

    4.  Run the following steps in parallel:

        1.  While `proceed`{.variable} is \`false\`, the \[=User
            Agent=\] MUST wait to proceed to the next step until a task
            queued to set `proceed`{.variable} to the result of
            \[=device enumeration can proceed=\] with
            `mediaDevices`{.variable}, would set `proceed`{.variable} to
            \`true\`.

        2.  Let `resultList`{.variable} be the result of \[=creating a
            list of device info objects=\] with
            `mediaDevices`{.variable} and
            `mediaDevices`{.variable}.{{MediaDevices/\[\[storedDeviceList\]\]}}.

        3.  \[= resolve =\] `p`{.variable} with `resultList`{.variable}.

    5.  Return `p`{.variable}.

    To perform [ creating a list of device info
    objects]{#creating-a-list-of-device-info-objects .dfn .abstract-op},
    given `mediaDevices`{.variable} and `deviceList`{.variable}, run the
    following steps:

    1.  Let `resultList`{.variable} be an empty list.

    2.  Let `microphoneList`{.variable}, `cameraList`{.variable} and
        `otherDeviceList`{.variable} be empty lists.

    3.  Let `document`{.variable} be `mediaDevices`{.variable}\'s
        \[=relevant global object=\]\'s \[=associated \`Document\`=\].

    4.  Run the following sub steps for each discovered device in
        `deviceList`{.variable}, `device`{.variable}:

        1.  If `device`{.variable} is not a microphone, or
            `document`{.variable} is not \[=allowed to use=\] the
            feature identified by \"microphone\", abort these sub steps
            and continue with the next device (if any).

        2.  Let `deviceInfo`{.variable} be the result of \[=creating a
            device info object=\] to represent `device`{.variable}, with
            `mediaDevices`{.variable}.

        3.  If `device`{.variable} is the system default microphone,
            prepend `deviceInfo`{.variable} to
            `microphoneList`{.variable}. Otherwise, append
            `deviceInfo`{.variable} to `microphoneList`{.variable}.

    5.  Run the following sub steps for each discovered device in
        `deviceList`{.variable}, `device`{.variable}:

        1.  If `device`{.variable} is not a camera, or
            `document`{.variable} is not \[=allowed to use=\] the
            feature identified by \"camera\", abort these sub steps and
            continue with the next device (if any).

        2.  Let `deviceInfo`{.variable} be the result of \[=creating a
            device info object=\] to represent `device`{.variable}, with
            `mediaDevices`{.variable}.

        3.  If `device`{.variable} is the system default camera, prepend
            `deviceInfo`{.variable} to `cameraList`{.variable}.
            Otherwise, append `deviceInfo`{.variable} to
            `cameraList`{.variable}.

    6.  If \[=microphone information can be exposed=\] on
        `mediaDevices`{.variable} is `false`, truncate
        `microphoneList`{.variable} to its first item.

    7.  If \[=camera information can be exposed=\] on
        `mediaDevices`{.variable} is `false`, truncate
        `cameraList`{.variable} to its first item.

    8.  Run the following sub steps for each discovered device in
        `deviceList`{.variable}, `device`{.variable}:

        1.  If `device`{.variable} is a microphone or
            `device`{.variable} is a camera, abort these sub steps and
            continue with the next device (if any).

        2.  Run the \[=exposure decision algorithm for devices other
            than camera and microphone=\], with `device`{.variable},
            `microphoneList`{.variable}, `cameraList`{.variable} and
            `mediaDevices`{.variable} as input. If the result of this
            algorithm is `false`, abort these sub steps and continue
            with the next device (if any).

        3.  Let `deviceInfo`{.variable} be the result of \[=creating a
            device info object=\] to represent `device`{.variable}, with
            `mediaDevices`{.variable}.

        4.  Append `deviceInfo`{.variable} to
            `otherDeviceList`{.variable}.

        5.  If `device`{.variable} is the system default audio output,
            run the following sub steps:

            1.  Let `defaultAudioOutputInfo`{.variable} be the result of
                \[=creating a device info object=\] to represent
                `device`{.variable}, with `mediaDevices`{.variable}.

            2.  Set `defaultAudioOutputInfo`{.variable}\'s
                {{MediaDeviceInfo/deviceId}} to \"default\".

            3.  The user agent SHOULD update
                `defaultAudioOutputInfo`{.variable}\'s
                {{MediaDeviceInfo/label}} to make it explicit that this
                is the system default audio output.

            4.  Prepend `defaultAudioOutputInfo`{.variable} to
                `otherDeviceList`{.variable}.

    9.  Append to `resultList`{.variable} all devices of
        `microphoneList`{.variable} in order.

    10. Append to `resultList`{.variable} all devices of
        `cameraList`{.variable} in order.

    11. Append to `resultList`{.variable} all devices of
        `otherDeviceList`{.variable} in order.

    12. Return `resultList`{.variable}.

    Since this method returns persistent information across browsing
    sessions and origins via the availability of media capture devices,
    it adds to the fingerprinting surface exposed by the \[=User
    Agent=\].

    As long as the \[=relevant global object=\]\'s \[=associated
    \`Document\`=\] did not capture, this method will limit exposure to
    two bits of information: whether there is a camera and whether there
    is a microphone. A \[=User Agent=\] may mitigate this by pretending
    the system has a camera and a microphone, for instance until the
    \[=relevant global object=\]\'s \[=associated \`Document\`=\] calls
    {{MediaDevices/getUserMedia()}} with constraints deemed reasonable.

    After the \[=relevant global object=\]\'s \[=associated
    \`Document\`=\] started capture, it provides additional persistent
    cross-origin information via the list of all media capture devices,
    including their grouping and human readable labels associated with
    the capture devices, which further adds to the fingerprinting
    surface.

    A \[=User Agent=\] may limit exposure by sanitizing device labels.
    This could for instance mean removing user names found in labels,
    but keeping device manufacturer or model information. It is
    important that the sanitized labels allow users to identify the
    corresponding devices.
:::
:::::

::: section
## Access control model

The algorithm described above means that the access to media device
information depends on whether or not the \[=relevant global
object=\]\'s \[=associated \`Document\`=\] did capture.

For camera and microphone devices, if the \[=relevant global
object=\]\'s \[=associated \`Document\`=\] did not capture (i.e.
{{MediaDevices/getUserMedia()}} was not called or never resolved
successfully), the {{MediaDeviceInfo}} object will contain a valid value
for {{MediaDeviceInfo/kind}} but empty strings for
{{MediaDeviceInfo/deviceId}}, {{MediaDeviceInfo/label}}, and
{{MediaDeviceInfo/groupId}}. Additionally, at most one device of each
{{MediaDeviceInfo/kind}} will be listed in
{{MediaDevices/enumerateDevices()}} result.

Otherwise, the [MediaDeviceInfo]{.dfn} object will contain meaningful
values for {{MediaDeviceInfo/deviceId}}, {{MediaDeviceInfo/kind}},
{{MediaDeviceInfo/label}}, and {{MediaDeviceInfo/groupId}}. All
available devices are listed in {{MediaDevices/enumerateDevices()}}
result.

To perform [creating a device info
object]{#creating-a-device-info-object .dfn .abstract-op} to represent a
discovered device, `device`{.variable}, given `mediaDevices`{.variable},
run the following steps:

1.  Let `deviceInfo`{.variable} be a new {{MediaDeviceInfo}} object to
    represent `device`{.variable}.

2.  Initialize `deviceInfo`{.variable}.{{MediaDeviceInfo/kind}} for
    `device`{.variable}.

3.  If `deviceInfo`{.variable}.{{MediaDeviceInfo/kind}} is equal to
    \"videoinput\" and \[=camera information can be exposed=\] on
    `mediaDevices`{.variable} is `false`, return
    `deviceInfo`{.variable}.

4.  If `deviceInfo`{.variable}.{{MediaDeviceInfo/kind}} is equal to
    \"audioinput\" and \[=microphone information can be exposed=\] on
    `mediaDevices`{.variable} is `false`, return
    `deviceInfo`{.variable}.

5.  Initialize `deviceInfo`{.variable}.{{MediaDeviceInfo/label}} for
    `device`{.variable}.

6.  If a stored {{MediaDeviceInfo/deviceId}} exists for
    `device`{.variable}, initialize
    `deviceInfo`{.variable}.{{MediaDeviceInfo/deviceId}} to that value.
    Otherwise, let `deviceInfo`{.variable}.{{MediaDeviceInfo/deviceId}}
    be a newly generated unique identifier as described under
    {{MediaDeviceInfo/deviceId}}.

7.  If `device`{.variable} belongs to the same physical device as a
    device already represented for `document`{.variable}, initialize
    `deviceInfo`{.variable}.{{MediaDeviceInfo/groupId}} to the
    {{MediaDeviceInfo/groupId}} value of the existing
    {{MediaDeviceInfo}} object. Otherwise, let
    `deviceInfo`{.variable}.{{MediaDeviceInfo/groupId}} be a newly
    generated unique identifier as described under
    {{MediaDeviceInfo/groupId}}.

8.  Return `deviceInfo`{.variable}
:::

::: section
## Device information exposure

To perform a [device enumeration can
proceed]{#device-enumeration-can-proceed .dfn .abstract-op} check, given
`mediaDevices`{.variable}, run the following steps:

1.  The \[=User Agent=\] MAY return `true` if \[=device information can
    be exposed=\] on `mediaDevices`{.variable}.

2.  Return the result of \[=Document/is in view=\] with
    `mediaDevices`{.variable}.

To perform a [device information can be
exposed]{#device-information-can-be-exposed .dfn .abstract-op} check,
given `mediaDevices`{.variable}, run the following steps:

1.  If \[=camera information can be exposed=\] on
    `mediaDevices`{.variable}, return `true`.

2.  If \[=microphone information can be exposed=\] on
    `mediaDevices`{.variable}, return `true`.

3.  Return `false`.

To perform a [camera information can be
exposed]{#camera-information-can-be-exposed .dfn .abstract-op} check,
given `mediaDevices`{.variable}, run the following steps:

1.  If any of the local devices of kind \"videoinput\" are attached to a
    live {{MediaStreamTrack}} in `mediaDevices`{.variable}\'s
    \[=relevant global object=\]\'s \[=associated \`Document\`=\],
    return `true`.

2.  Return
    `mediaDevices`{.variable}.{{MediaDevices/\[\[canExposeCameraInfo\]\]}}.

To perform a [microphone information can be
exposed]{#microphone-information-can-be-exposed .dfn .abstract-op}
check, given `mediaDevices`{.variable}, run the following steps:

1.  If any of the local devices of kind \"audioinput\" are attached to a
    live {{MediaStreamTrack}} in the \[=relevant global object=\]\'s
    \[=associated \`Document\`=\], return `true`.

2.  Return
    `mediaDevices`{.variable}.{{MediaDevices/\[\[canExposeMicrophoneInfo\]\]}}.

To perform an [is in view]{.dfn .abstract-op dfn-for="Document"} check,
given `mediaDevices`{.variable}, run the following steps:

1.  If `mediaDevices`{.variable}\'s \[=relevant global object=\]\'s
    \[=associated \`Document\`=\] is \[=Document/fully active=\] and its
    \[=Document/visibility state=\] is \`\"visible\"\`, return \`true\`.
    Otherwise, return \`false\`.

To perform a [has system focus]{.dfn} check, given
`mediaDevices`{.variable}, run the following steps:

1.  If `mediaDevices`{.variable}\'s \[=relevant global object=\]\'s
    \[=navigable=\]\'s \[=top-level traversable=\] has [system
    focus]{data-cite="!HTML/#tlbc-system-focus"}, return \`true\`.
    Otherwise, return \`false\`.

To perform a [device exposure can be extended]{.dfn} check, given
`deviceType`{.variable}, run the following steps:

1.  Let `permission`{.variable} be the result of reading the
    \[=permission state=\] for the descriptor whose name is
    `deviceType`{.variable}.

2.  If `permission`{.variable} is {{PermissionState/\"granted\"}},
    return `true`.

3.  If `permission`{.variable} is {{PermissionState/\"prompt\"}}, the
    User Agent MAY return `true` if it knows that
    `deviceType`{.variable} access was previously granted for that
    origin.

4.  Return `false`.
:::

:::: section
## Set device information exposure

To [set the device information
exposure]{#set-device-information-exposure .dfn .abstract-op} on
`mediaDevices`{.variable}, given a `requestedTypes`{.variable}
\[=set=\], and a boolean `value`{.variable}, run the following steps:

1.  If \"video\" is in `requestedTypes`{.variable}, run the following
    sub-steps:

    1.  Set
        `mediaDevices`{.variable}.{{MediaDevices/\[\[canExposeCameraInfo\]\]}}
        to `value`{.variable}.

    2.  If `value`{.variable} is `true` and if \[=device exposure can be
        extended=\] with \"microphone\", set
        `mediaDevices`{.variable}.{{MediaDevices/\[\[canExposeMicrophoneInfo\]\]}}
        to `true`.

2.  If \"audio\" is in `requestedTypes`{.variable}, run the following
    sub-steps:

    1.  Set
        `mediaDevices`{.variable}.{{MediaDevices/\[\[canExposeMicrophoneInfo\]\]}}
        to `value`{.variable}.

    2.  If `value`{.variable} is `true` and if \[=device exposure can be
        extended=\] with \"camera\", set
        `mediaDevices`{.variable}.{{MediaDevices/\[\[canExposeCameraInfo\]\]}}
        to `true`.

::: note
A \[=User Agent=\] MAY at any point set the device information exposure
back to `false`, for instance if the \[=User Agent=\] decides to revoke
device access on a given {{Document}}.
:::
::::

::: section
## Exposure decision algorithm for devices other than camera and microphone

The [exposure decision algorithm for devices other than camera and
microphone]{#device-exposure-decision-non-camera-microphone .dfn
export=""} takes a `device`{.variable}, `microphoneList`{.variable},
`cameraList`{.variable} and `mediaDevices`{.variable} as input and
returns a boolean to decide whether to expose information about
`device`{.variable} to the web page or not.

By default, it returns `false`.

Other specifications can define the algorithm for specific device types.
:::

::: section
## Context capturing state

To perform a [context is capturing]{#context-is-capturing .dfn
.abstract-op} check for `globalObject`{.variable}, run the following
steps:

1.  If `globalObject`{.variable} is not a {{Window}}, then return false.

2.  Let `mediaDevices`{.variable} be `globalObject`{.variable}\'s
    \[=associated \`MediaDevices\`=\].

3.  For each `source`{.variable} in
    `mediaDevices`{.variable}.{{MediaDevices/\[\[mediaStreamTrackSources\]\]}},
    run the following sub steps:

    1.  If `source`{.variable} is \[=source/stopped=\] or
        \[=source/muted=\], abort these steps.

    2.  Let `deviceId`{.variable} be `source`{.variable}\'s device\'s
        deviceId.

    3.  If
        `mediaDevices`{.variable}.{{MediaDevices/\[\[devicesLiveMap\]\]}}\[`deviceId`{.variable}\]
        is `true`, return `true`.

4.  Return `false`.

This algorithm covers all capture tracks, including microphone, camera
and display.
:::
:::::::::::::

::::::: section
## Device Info

::::: {}
``` idl
[Exposed=Window, SecureContext]
interface MediaDeviceInfo {
  readonly attribute DOMString deviceId;
  readonly attribute MediaDeviceKind kind;
  readonly attribute DOMString label;
  readonly attribute DOMString groupId;
  [Default] object toJSON();
};
```

::: section
## Attributes

[deviceId]{.dfn} of type {{DOMString}}, readonly

:   The identifier of the represented device. The device MUST be
    uniquely identified by its identifier and its
    {{MediaDeviceInfo/kind}}.

    To ensure stored identifiers are recognized, the identifier MUST be
    the same in {{Document}}s of the \[=same origin=\] in \[=top-level
    traversables=\]. In \[=child navigables=\], the decision of whether
    or not the identifier is the same across documents, MUST follow the
    \[=User Agent=\]\'s partitioning rules for storage (such as
    {{WindowLocalStorage/localStorage}}), if any, to not interfere with
    mitigations for cross-site correlation. If the identifier can
    uniquely identify the user, then it MUST be un-guessable in
    documents from other origins to prevent the identifier from being
    used to correlate the same user across different origins. An
    identifier can be reused across origins as long as it is not tied to
    the user and can be guessed by other means, like the User-Agent
    string.

    If any local devices have been attached to a live
    {{MediaStreamTrack}} in a page from this origin, or \[=stored
    permission=\] to access local devices has been granted to this
    origin, then this identifier MUST be persisted, except as detailed
    below. Unique and stable identifiers let the application save,
    identify the availability of, and directly request specific sources,
    across multiple visits.

    However, as long as no local device has been attached to a live
    MediaStreamTrack in a page from this origin, and no \[=stored
    permission=\] to access local devices has been granted to this
    origin, then the \[=User Agent=\] MAY clear this identifier once the
    last browsing session from this origin has been closed. If the
    \[=User Agent=\] chooses not to clear the identifier in this
    condition, then it MUST provide for the user to visibly inspect and
    delete the identifier, like a cookie.

    Since {{deviceId}} may persist across browsing sessions and to
    reduce its potential as a fingerprinting mechanism, {{deviceId}} is
    to be treated as other persistent storage mechanisms such as cookies
    \[\[COOKIES\]\], in that \[=User Agents=\] MUST NOT persist device
    identifiers for sites that are blocked from using cookies, and
    \[=User Agents=\] MUST rotate per-origin device identifiers when
    other persistent storage are cleared.

[kind]{.dfn} of type {{MediaDeviceKind}}, readonly

:   The kind of the represented device.

[label]{.dfn} of type {{DOMString}}, readonly

:   A label describing this device (for example \"External USB
    Webcam\"). This label is intended to allow the end user to tell the
    difference between devices. Applications can't assume that the label
    contains any specific information, such as the device type or model.
    If the device has no associated label, then this attribute MUST
    return the empty string.

[groupId]{.dfn} of type {{DOMString}}, readonly

:   The group identifier of the represented device. Two devices have the
    same group identifier if they belong to the same physical device.
    For example, the audio input and output devices representing the
    speaker and microphone of the same headset have the same groupId.

    The group identifier MUST be uniquely generated for each document.
:::

::: section
## Methods

[toJSON]{.dfn}
:   When called, run \[\[WEBIDL\]\]\'s default toJSON steps.
:::
:::::

::: {}
``` idl
enum MediaDeviceKind {
  "audioinput",
  "audiooutput",
  "videoinput"
};
```

+----------------------------------------------------+----------------------------------+
| [MediaDeviceKind]{.dfn} Enumeration description                                       |
+----------------------------------------------------+----------------------------------+
| [audioinput]{#idl-def-MediaDeviceKind.audioinput   | Represents an audio input        |
| .dfn}                                              | device; for example a            |
|                                                    | microphone.                      |
+----------------------------------------------------+----------------------------------+
| [audiooutput]{#idl-def-MediaDeviceKind.audiooutput | Represents an audio output       |
| .dfn}                                              | device; for example a pair of    |
|                                                    | headphones.                      |
+----------------------------------------------------+----------------------------------+
| [videoinput]{#idl-def-MediaDeviceKind.videoinput   | Represents a video input device; |
| .dfn}                                              | for example a webcam.            |
+----------------------------------------------------+----------------------------------+
:::
:::::::

::::: section
## Input-specific Device Info

The [InputDeviceInfo]{.dfn} interface gives access to the capabilities
of the input device it represents.

:::: {}
``` idl
[Exposed=Window, SecureContext]
interface InputDeviceInfo : MediaDeviceInfo {
  MediaTrackCapabilities getCapabilities();
};
```

::: section
## Methods

[getCapabilities]{.dfn}

:   Returns a {{MediaTrackCapabilities}} object describing the primary
    audio or video track of a device\'s {{MediaStream}} (according to
    its {{MediaStreamTrack/kind}} value), in the absence of any
    user-supplied constraints. These capabilities MUST be identical to
    those that would have been obtained by calling
    {{MediaStreamTrack/getCapabilities()}} on the first
    {{MediaStreamTrack}} of this type in a {{MediaStream}} returned by
    `getUserMedia({deviceId: `*`id`*`})` where `id`{.variable} is the
    value of the {{MediaDeviceInfo/deviceId}} attribute of this
    {{MediaDeviceInfo}}.

    If no access has been granted to any local devices and this
    {{InputDeviceInfo}} has been filtered with respect to unique
    identifying information (see above description of
    {{MediaDevices/enumerateDevices()}} result), then this method
    returns an empty dictionary.
:::
::::
:::::

:::::::: section
### {{DeviceChangeEvent}}

The {{devicechange}} event uses the {{DeviceChangeEvent}} interface.

::::: {}
``` idl
[Exposed=Window]
interface DeviceChangeEvent : Event {
  constructor(DOMString type, optional DeviceChangeEventInit eventInitDict = {});
  [SameObject] readonly attribute FrozenArray<MediaDeviceInfo> devices;
  [SameObject] readonly attribute FrozenArray<MediaDeviceInfo> userInsertedDevices;
};
```

::: section
## Constructors

[constructor()]{.dfn}

:   Initialize \[=this=\].{{DeviceChangeEvent/devices}} to the result of
    \[=creating a frozen array=\] from
    `eventInitDict`{.variable}.{{DeviceChangeEventInit/devices}}.
:::

::: section
## Attributes

[devices]{.dfn idl=""} of type [FrozenArray\<{{MediaDeviceInfo}}\>]{.idlAttrType}, readonly

:   The {{devices}} attribute returns an array of {{MediaDeviceInfo}}
    objects representing the list of available devices at this time.

[userInsertedDevices]{.dfn idl=""} of type [FrozenArray\<{{MediaDeviceInfo}}\>]{.idlAttrType}, readonly

:   The {{userInsertedDevices}} attribute returns an array containing
    only those {{MediaDeviceInfo}} objects from {{devices}} that the
    user physically inserted or activated recently and are newly exposed
    with this event as a result. Otherwise, an empty list is returned.

    The \[=User Agent=\] MAY include devices the user inserted or
    activated before {{MediaDevices/getUserMedia()}} was called,
    provided this event marks their first exposure, and the user did not
    choose devices in {{MediaDevices/getUserMedia()}}.

    The {{MediaDeviceInfo}} objects, if any, MUST also exist in
    {{devices}}.

    ::: note
    A user inserting a device during (or immediately ahead of) a call
    can be a strong signal that they wish to use the device immediately.

    Applications are encouraged to rely on this attribute to
    disambiguate this signal from differences in {{devices}} that might
    happen from changes in device information exposure.
    :::

    ::: note
    If the attribute is missing, it means that this UA has not been
    upgraded to implement this version of the specification.
    :::
:::
:::::

:::: {}
``` idl
dictionary DeviceChangeEventInit : EventInit {
  sequence<MediaDeviceInfo> devices = [];
};
```

::: section
## Dictionary [DeviceChangeEventInit]{.dfn} Members

[devices]{.dfn idl=""} of type [sequence\<{{MediaDeviceInfo}}\>]{.idlMemberType}, defaulting to `[]`

:   The {{devices}} member is an array of {{MediaDeviceInfo}} objects
    representing the available devices.
:::
::::
::::::::
:::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::: {#local-content .section}
## Obtaining local multimedia content

This section extends {{Navigator}} and {{MediaDevices}} with APIs to
request permission to access media input devices available to the
\[=User Agent=\].

Alternatively, a local {{MediaStream}} can be captured from certain
types of DOM elements, such as the video element
\[\[?mediacapture-fromelement\]\]. This can be useful for automated
testing.

::::::::: section
### {{MediaDevices}} Interface Extensions

::: note
The definition of {{Navigator/getUserMedia()}} in this section reflects
two major changes from the method definition that has existed under
{{Navigator}} for many months.

First, the official definition for the {{MediaDevices/getUserMedia()}}
method, and the one which developers are encouraged to use, is now the
one defined here under {{MediaDevices}}. This decision reflected
consensus as long as the original API remained available at
Navigator.getUserMedia under the {{Navigator}} object for backwards
compatibility reasons, since the working group acknowledges that early
users of these APIs have been encouraged to define getUserMedia as \"var
getUserMedia = navigator.getUserMedia \|\| navigator.webkitGetUserMedia
\|\| navigator.mozGetUserMedia;\" in order for their code to be
functional both before and after official implementations of
getUserMedia() in popular \[=User Agents=\]. To ensure functional
equivalence, the getUserMedia() method under {{Navigator}} is defined in
terms of the method here.

Second, the method defined here is Promises-based, while the one defined
under {{Navigator}} is currently still callback-based. Developers
expecting to find getUserMedia() defined under Navigator are strongly
encouraged to read the detailed Note given there.
:::

The {{MediaDevices/getSupportedConstraints}} method is provided to allow
the application to determine which constraints the \[=User Agent=\]
recognizes. Applications may need this information to use required
constraints reliably or get predictable results from combinatory logic
in advanced constraints.

:::: {}
``` idl
partial interface MediaDevices {
  MediaTrackSupportedConstraints getSupportedConstraints();
  Promise<MediaStream> getUserMedia(optional MediaStreamConstraints constraints = {});
};
```

::: section
## Methods

[getSupportedConstraints]{.dfn}

:   Returns a dictionary whose members are the constrainable properties
    known to the \[=User Agent=\]. A supported constrainable property
    MUST be represented and any constrainable properties not supported
    by the \[=User Agent=\] MUST NOT be present in the returned
    dictionary. The values returned represent what the \[=User Agent=\]
    implements and will not change during a browsing session.

getUserMedia

:   Prompts the user for permission to use their Web cam or other video
    or audio input.

    The `constraints`{.variable} argument is a dictionary of type
    {{MediaStreamConstraints}}.

    This method returns a promise. The promise will be \[=upon
    fulfillment\|fulfilled=\] with a suitable {{MediaStream}} object if
    the user accepts valid tracks as described below.

    The promise will be rejected if there is a failure in finding valid
    tracks or if the user denies permission, as described below.

    When the [getUserMedia()]{.dfn} method is called, the \[=User
    Agent=\] MUST run the following steps:

    1.  Let `constraints`{.variable} be the method\'s first argument.

    2.  Let `requestedMediaTypes`{.variable} be the set of media types
        in `constraints`{.variable} with either a dictionary value or a
        value of `true`.

    3.  If `requestedMediaTypes`{.variable} is the empty set, return a
        promise rejected with a {{TypeError}}. The word \"optional\"
        occurs in the WebIDL due to WebIDL rules, but the argument MUST
        be supplied in order for the call to succeed.

    4.  Let `document`{.variable} be the \[=relevant global object=\]\'s
        \[=associated \`Document\`=\].

    5.  If `document`{.variable} is NOT \[=Document/fully active=\],
        return a promise rejected with a {{DOMException}} object whose
        {{DOMException/name}} attribute has the value
        {{\"InvalidStateError\"}}.

    6.  If `requestedMediaTypes`{.variable} contains \"audio\" and
        `document`{.variable} is not \[=allowed to use=\] the feature
        identified by the \"microphone\" permission name, jump to the
        step labeled *Permission Failure* below.

    7.  If `requestedMediaTypes`{.variable} contains \"video\" and
        `document`{.variable} is not \[=allowed to use=\] the feature
        identified by the \"camera\" permission name, jump to the step
        labeled *Permission Failure* below.

    8.  Let `mediaDevices`{.variable} be \[=this=\].

    9.  Let `isInView`{.variable} be the result of the \[= Document/is
        in view =\] algorithm.

    10. Let `p`{.variable} be a new promise.

    11. Run the following steps in parallel:

        1.  While `isInView`{.variable} is \`false\`, the \[=User
            Agent=\] MUST wait to proceed to the next step until a task
            queued to set `isInView`{.variable} to the result of the
            \[=Document/is in view=\] algorithm, would set
            `isInView`{.variable} to \`true\`.

        2.  Let `finalSet`{.variable} be an (initially) empty set.

        3.  For each media type `kind`{.variable} in
            `requestedMediaTypes`{.variable}, run the following steps:

            1.  For each possible configuration of each possible source
                device of media of type `kind`{.variable}, conceive a
                [candidate]{.dfn} as a placeholder for an eventual
                {{MediaStreamTrack}} holding a source device and
                configured with a settings dictionary comprised of its
                specific settings.

                Call this set of candidates the
                `candidateSet`{.variable}.

                If `candidateSet`{.variable} is the empty set, jump to
                the step labeled *NotFound Failure* below.

            2.  If the value of the `kind`{.variable} entry of
                `constraints`{.variable} is `true`, set `CS`{.variable}
                to the empty constraint set (no constraint). Otherwise,
                continue with `CS`{.variable} set to the value of the
                `kind`{.variable} entry of `constraints`{.variable}.

            3.  Remove any constrainable property inside of
                `CS`{.variable} that are not defined for
                {{MediaStreamTrack}} objects of type `kind`{.variable}.
                This means that audio-only constraints inside of
                \"video\" and video-only constraints inside of \"audio\"
                are simply ignored rather than causing
                `OverconstrainedError`.

            4.  If `CS`{.variable} contains a member that is a required
                constraint and whose name is not in the list of allowed
                required constraints for device selection, then \[=
                reject =\] `p`{.variable} with a {{TypeError}}, and
                abort these steps.

            5.  Run the SelectSettings algorithm on each candidate in
                `candidateSet`{.variable} with `CS`{.variable} as the
                constraint set. If the algorithm returns `undefined`,
                remove the candidate from `candidateSet`{.variable}.
                This eliminates devices unable to satisfy the
                constraints, by verifying that at least one settings
                dictionary exists that satisfies the constraints.

                If `candidateSet`{.variable} is the empty set, let
                `failedConstraint`{.variable} be any [required
                constraint]{lt="required constraints"} whose fitness
                distance was infinity for all settings dictionaries
                examined while executing the SelectSettings algorithm,
                or `""` if there isn\'t one, and jump to the step
                labeled *Constraint Failure* below.

                This error gives information about what the underlying
                device is not capable of producing, before the user has
                given any authorization to any device, and can thus be
                used as a fingerprinting surface.

            6.  Read the current \[=permission state=\] for all
                candidate devices in `candidateSet`{.variable} that are
                not attached to a live {{MediaStreamTrack}} in the
                current {{Document}}. Remove from
                `candidateSet`{.variable} any candidate whose device\'s
                permission state is {{PermissionState/\"denied\"}}.

                If `candidateSet`{.variable} is now empty, indicating
                that all devices of this type are in state
                {{PermissionState/\"denied\"}}, jump to the step labeled
                *PermissionFailure* below.

            7.  Optionally, e.g., based on a previously-established user
                preference, for security reasons, or due to platform
                limitations, jump to the step labeled *Permission
                Failure* below.

            8.  Add all candidates from `candidateSet`{.variable} to
                `finalSet`{.variable}.

        4.  Let `stream`{.variable} be a new and empty {{MediaStream}}
            object.

        5.  For each media type `kind`{.variable} in
            `requestedMediaTypes`{.variable}, run the following sub
            steps, preferably at the same time:

            ::: note
            \[=User Agents=\] are encouraged to bundle concurrent
            requests for different kinds of media into a single
            user-facing permission prompt.
            :::

            1.  \[=Request permission to use=\] a
                {{PermissionDescriptor}} with its
                {{PermissionDescriptor/name}} member set to the
                permission name associated with `kind`{.variable} (e.g.
                \"camera\" for \"video\", \"microphone\" for \"audio\"),
                while considering all devices attached to a live and
                same-permission {{MediaStreamTrack}} in the current
                {{Document}} to have permission status
                {{PermissionState/\"granted\"}}, resulting in a set of
                provided media. [Same-permission]{.dfn} in this context
                means a {{MediaStreamTrack}} that required the same
                level of permission to obtain as what is being requested
                (e.g. not isolated).

                When asking the user's permission, the \[=User Agent=\]
                MUST disclose whether permission will be granted only to
                the device chosen, or to all devices of that
                `kind`{.variable}.

                ::: note
                If the user never responds, this algorithm stalls on
                this step.
                :::

            2.  If the result of the request is
                {{PermissionState/\"denied\"}}, jump to the step labeled
                *Permission Failure* below.

        6.  Let `hasSystemFocus`{.variable} be \`false\`.

        7.  While `hasSystemFocus`{.variable} is \`false\`, the \[=User
            Agent=\] MUST wait to proceed to the next step until a task
            queued to set `hasSystemFocus`{.variable} to the result of
            the \[=has system focus=\] algorithm, would set
            `hasSystemFocus`{.variable} to \`true\`.

        8.  \[=Set the device information exposure=\] on
            `mediaDevices`{.variable} with `requestedMediaTypes` and
            `true`.

        9.  For each media type `kind`{.variable} in
            `requestedMediaTypes`{.variable}, run the following sub
            steps:

            1.  Let `finalCandidate`{.variable} be the provided media,
                which MUST be precisely one candidate of type
                `kind`{.variable} from `finalSet`{.variable}. The
                decision of which candidate to choose from the
                `finalSet`{.variable} is completely up to the \[=User
                Agent=\] and may be determined by asking the user.

                The \[=User Agent=\] SHOULD use the value of the
                computed fitness distance from the SelectSettings
                algorithm as an input to the selection algorithm.
                However, it MAY also use other internally-available
                information about the devices, such as user preference.

                ::: note
                This means that non-\[=required constraints=\] values
                are not guaranteed.
                :::

                \[=User Agents=\] are encouraged to default to using the
                user\'s primary or system default device for
                `kind`{.variable} (when possible). \[=User Agents=\] MAY
                allow users to use any media source, including
                pre-recorded media files.

            2.  The result of the request is
                {{PermissionState/\"granted\"}}. If a hardware error
                such as an OS/program/webpage lock prevents access,
                remove the corresponding candidate from
                `finalSet`{.variable}. If `finalSet`{.variable} has no
                candidates of type `kind`{.variable}, \[= reject =\]
                `p`{.variable} with a new {{DOMException}} object whose
                {{DOMException/name}} attribute has the value
                {{\"NotReadableError\"}} and abort these steps.
                Otherwise, restart these sub steps with the updated
                `finalSet`{.variable}.

                If device access fails for any reason other than those
                listed above, remove the corresponding candidate from
                `finalSet`{.variable}. If `finalSet`{.variable} has no
                candidates of type `kind`{.variable}, \[= reject =\]
                `p`{.variable} with a new {{DOMException}} object whose
                {{DOMException/name}} attribute has the value
                {{\"AbortError\"}} and abort these steps. Otherwise,
                restart these sub steps with the updated
                `finalSet`{.variable}.

            3.  Let `grantedDevice`{.variable} be
                `finalCandidate`{.variable}\'s source device.

            4.  Using `grantedDevice`{.variable}\'s deviceId,
                `deviceId`{.variable}, set
                `mediaDevices`{.variable}.{{MediaDevices/\[\[devicesLiveMap\]\]}}\[`deviceId`{.variable}\]
                to `true`, if it isn't already `true`, and set
                `mediaDevices`{.variable}.{{MediaDevices/\[\[devicesAccessibleMap\]\]}}\[`deviceId`{.variable}\]
                to `true`, if it isn't already `true`.

            5.  Let `track`{.variable} be the result of \[=create a
                MediaStreamTrack\|creating a MediaStreamTrack=\] with
                `grantedDevice`{.variable} and
                `mediaDevices`{.variable}. The source of the
                {{MediaStreamTrack}} MUST NOT change.

            6.  Add `track`{.variable} to `stream`{.variable}\'s track
                set.

        10. Run the ApplyConstraints algorithm on all tracks in
            `stream`{.variable} with the appropriate constraints. If any
            of them returns something other than `undefined`, let
            `failedConstraint`{.variable} be that result and jump to the
            step labeled *Constraint Failure* below.

        11. For each `track`{.variable} in `stream`{.variable}, \[=tie
            track source to \`MediaDevices\`=\] with
            `track`{.variable}.{{MediaStreamTrack/\[\[Source\]\]}} and
            `mediaDevices`{.variable}.

        12. \[= Resolve =\] `p`{.variable} with `stream`{.variable} and
            abort these steps.

        13. *NotFound Failure*:

            1.  If \[=getUserMedia specific failure is allowed=\] given
                `requestedMediaTypes`{.variable} returns `false`, jump
                to the step labeled *Permission Failure* below.

            2.  \[=Reject=\] `p`{.variable} with a new {{DOMException}}
                object whose {{DOMException/name}} attribute has the
                value {{\"NotFoundError\"}}.

        14. *Constraint Failure*:

            1.  If \[=getUserMedia specific failure is allowed=\] given
                `requestedMediaTypes`{.variable} returns `false`, jump
                to the step labeled *Permission Failure* below.

            2.  Let `message`{.variable} be either `undefined` or an
                informative human-readable message, let
                `constraint`{.variable} be `failedConstraint`{.variable}
                if \[=device information can be exposed=\] is `true`, or
                `""` otherwise.

            3.  \[=Reject=\] `p`{.variable} with a new
                `OverconstrainedError` created by calling
                `OverconstrainedError(``constraint`{.variable}`, ``message`{.variable}`)`.

        15. *Permission Failure*: \[= Reject =\] `p`{.variable} with a
            new {{DOMException}} object whose {{DOMException/name}}
            attribute has the value {{\"NotAllowedError\"}}.

    12. Return `p`{.variable}.
:::
::::

::: {}
To check whether [getUserMedia specific failure is
allowed]{#getUserMedia-specific-failure-is-allowed .dfn .abstract-op},
given `requestedMediaTypes`{.variable}, run the following steps:

1.  If `requestedMediaTypes`{.variable} contains \"audio\", read the
    \[=permission state=\] for the descriptor whose name is
    \"microphone\". If the result of the request is
    {{PermissionState/\"denied\"}}, return `false`.

2.  If `requestedMediaTypes`{.variable} contains \"video\", read the
    \[=permission state=\] for the descriptor whose name is \"camera\".
    If the result of the request is {{PermissionState/\"denied\"}},
    return `false`.

3.  Return `true`.
:::

::: note
In the algorithm above, constraints are checked twice - once at device
selection, and once after access approval. Time may have passed between
those checks, so it is conceivable that the selected device is no longer
suitable. In this case, a NotReadableError will result.
:::

::: {}
The [allowed required constraints for device selection]{.dfn .export}
contains the following constraint names: width, height, aspectRatio,
frameRate, facingMode, resizeMode, sampleRate, sampleSize,
echoCancellation, autoGainControl, noiseSuppression, latency,
channelCount, deviceId, groupId.
:::
:::::::::

::::: section
## {{MediaStreamConstraints}}

The [MediaStreamConstraints]{.dfn} dictionary is used to instruct the
\[=User Agent=\] what sort of {{MediaStreamTrack}}s to include in the
MediaStream returned by {{MediaDevices/getUserMedia()}}.

:::: {}
``` idl
dictionary MediaStreamConstraints {
  (boolean or MediaTrackConstraints) video = false;
  (boolean or MediaTrackConstraints) audio = false;
};
```

::: section
## Dictionary [MediaStreamConstraints]{.idlType} Members

[video]{.dfn} of type `({{boolean}} or {{MediaTrackConstraints}})`, defaulting to `false`

:   If `true`, it requests that the returned MediaStream contain a video
    track. If a Constraints structure is provided, it further specifies
    the nature and settings of the video Track. If `false`, the
    {{MediaStream}} MUST NOT contain a video Track.

[audio]{.dfn} of type `({{boolean}} or {{MediaTrackConstraints}})`, defaulting to `false`

:   If `true`, it requests that the returned MediaStream contain an
    audio track. If a Constraints structure is provided, it further
    specifies the nature and settings of the audio Track. If `false`,
    the MediaStream MUST NOT contain an audio Track.
:::
::::
:::::

::::::::::::: {.section .informative}
### Legacy GetUserMedia interface

::: note
The definition of getUserMedia() in this section reflects the call
format that was originally proposed; it is only documented here for
browsers that wish to retain backwards compatibility. It differs from
the recommended interface in two important ways.

First, the official definition for the getUserMedia() method, and the
one which developers are encouraged to use, is now at {{MediaDevices}}.
This decision reflected consensus as long as the original API remained
available here under the Navigator object for backwards compatibility
reasons, since the working group acknowledges that early users of these
APIs have been encouraged to define getUserMedia as \"var getUserMedia =
navigator.getUserMedia \|\| navigator.webkitGetUserMedia \|\|
navigator.mozGetUserMedia;\" in order for their code to be functional
both before and after official implementations of getUserMedia() in
popular browsers. To ensure functional equivalence, the getUserMedia()
method here is defined in terms of the method under MediaDevices.

Second, the decision to change all other callback-based methods in the
specification to be based on Promises instead required that the
navigator.getUserMedia() definition reflect this in its use of
navigator.mediaDevices.getUserMedia(). Because navigator.getUserMedia()
is now the only callback-based method remaining in the specification,
there is ongoing discussion as to a) whether it still belongs in the
specification, and b) if it does, whether its syntax should remain
callback-based or change in some way to use Promises. Input on these
questions is encouraged, particularly from developers actively using
today\'s implementations of this functionality.

Note that the other methods that changed from a callback-based syntax to
a Promises-based syntax were not considered to have been implemented
widely enough in any form to have to consider legacy usage.

Implementations do not need to implement this interface in order to be
considered compliant.
:::

::::: section
### Interface definition

:::: {}
``` idl
partial interface Navigator {
  [SecureContext] undefined getUserMedia(MediaStreamConstraints constraints,
                                    NavigatorUserMediaSuccessCallback successCallback,
                                    NavigatorUserMediaErrorCallback errorCallback);
};
```

::: section
## Methods

[getUserMedia]{.dfn}

:   Prompts the user for permission to use their Web cam or other video
    or audio input.

    The `constraints`{.variable} argument is a dictionary of type
    {{MediaStreamConstraints}}.

    The `successCallback`{.variable} will be invoked with a suitable
    {{MediaStream}} object as its argument if the user accepts valid
    tracks as described in {{MediaDevices/getUserMedia()}} on
    {{MediaDevices}}.

    The `errorCallback`{.variable} will be invoked if there is a failure
    in finding valid tracks or if the user denies permission, as
    described in {{MediaDevices/getUserMedia()}} on {{MediaDevices}}.

    When the {{getUserMedia()}} method is called, the User Agent MUST
    run the following steps:

    1.  Let `constraints`{.variable} be the method\'s first argument.

    2.  Let `successCallback`{.variable} be the callback indicated by
        the method\'s second argument.

    3.  Let `errorCallback`{.variable} be the callback indicated by the
        method\'s third argument.

    4.  Run the steps specified by the [getUserMedia()
        algorithm](#dom-mediadevices-getusermedia) with
        `constraints`{.variable} as the argument, and let `p`{.variable}
        be the resulting promise.

    5.  \[=Upon fulfillment=\] of `p`{.variable} with value
        `stream`{.variable}, run the following step:

        1.  Invoke `successCallback`{.variable} with `stream`{.variable}
            as the argument.

    6.  \[=Upon rejection=\] of `p`{.variable} with reason
        `r`{.variable}, run the following step:

        1.  Invoke `errorCallback`{.variable} with `r`{.variable} as the
            argument.
:::
::::
:::::

::::: section
## [NavigatorUserMediaSuccessCallback]{.dfn}

:::: {}
``` idl
callback NavigatorUserMediaSuccessCallback = undefined (MediaStream stream);
```

::: section
## Callback [NavigatorUserMediaSuccessCallback]{.idlType} Parameters

stream of type {{MediaStream}}
:   {{MediaStream}} object representing the stream to which the user
    granted permission as described in the {{Navigator.getUserMedia}}
    algorithm.
:::
::::
:::::

::::: section
## [NavigatorUserMediaErrorCallback]{.dfn}

:::: {}
``` idl
callback NavigatorUserMediaErrorCallback = undefined (DOMException error);
```

::: section
## Callback [NavigatorUserMediaErrorCallback]{.idlType} Parameters

error of type {{DOMException}}
:   Error in obtaining a {{MediaStream}} as described in the failure
    steps of the {{Navigator.getUserMedia}} algorithm.
:::
::::
:::::
:::::::::::::

:::::::: {.section .informative}
## Implementation Suggestions

::: practice
[Resource reservation]{#resource-reservation .practicelab}

The \[=User Agent=\] is encouraged to reserve resources when it has
determined that a given call to {{MediaDevices/getUserMedia()}} will be
successful. It is preferable to reserve the resource prior to resolving
the returned promise. Subsequent calls to
{{MediaDevices/getUserMedia()}} (in this page or any other) should treat
the resource that was previously allocated, as well as resources held by
other applications, as busy. Resources marked as busy should not be
provided as sources to the current web page, unless specified by the
user. Optionally, the \[=User Agent=\] may choose to provide a stream
sourced from a busy source but only to a page whose origin matches the
owner of the original stream that is keeping the source busy.

This document recommends that in the permission grant dialog or device
selection interface (if one is present), the user be allowed to select
any available hardware as a source for the stream requested by the page
(provided the resource is able to fulfill any specified required
constraints). Although not specifically recommended as best practice,
note that some \[=User Agents=\] may support the ability to substitute a
video or audio source with local files and other media. A file picker
may be used to provide this functionality to the user.

This document also recommends that the user be shown all resources that
are currently busy as a result of prior calls to
[getUserMedia()](#dom-mediadevices-getusermedia) (in this page or any
other page that is still alive) and be allowed to terminate that stream
and utilize the resource for the current page instead. If possible in
the current operating environment, it is also suggested that resources
currently held by other applications be presented and treated in the
same manner. If the user chooses this option, the track corresponding to
the resource that was provided to the page whose stream was affected
must be removed.
:::

::: practice
[Stored Permission]{#stored-permissions .dfn .practicelab}s

When permission is requested for a device, the \[=User Agent=\] may
choose to store this permission for later use by the same origin, so
that the user does not need to grant permission again at a later time.
It is a \[=User Agent=\] choice whether it offers functionality to store
permission to each device separately, all devices of a given class, or
all devices; the choice needs to be apparent to the user, and permission
must have been granted for the entire set whose permission is being
stored, e.g., to store permission to use all cameras the user must have
given permission to use all cameras and not just one.

As described, this specification does not dictate whether or not
granting permission results in a stored permission. When permission is
not stored, permission will last only until such time as all
MediaStreamTracks sourced from that device have been stopped.
:::

::: practice
[Handling multiple devices]{#handling-devices .practicelab}

A MediaStream may contain more than one video and audio track. This
makes it possible to include video from two or more webcams in a single
stream object, for example. However, the current API does not allow a
page to express a need for multiple video streams from independent
sources.

It is recommended for multiple calls to
[getUserMedia()](#dom-mediadevices-getusermedia) from the same page to
be allowed as a way for pages to request multiple discrete video and/or
audio streams.

Note also that if multiple
[getUserMedia()](#dom-mediadevices-getusermedia) calls are done by a
page, the order in which they request resources, and the order in which
they complete, is not constrained by this specification.

A single call to [getUserMedia()](#dom-mediadevices-getusermedia) will
always return a stream with either zero or one audio tracks, and either
zero or one video tracks. If a script calls
[getUserMedia()](#dom-mediadevices-getusermedia) multiple times before
reaching a stable state, this document advises the UI designer that the
permission dialogs should be merged, so that the user can give
permission for the use of multiple cameras and/or media sources in one
dialog interaction. The constraints on each getUserMedia call can be
used to decide which stream gets which media sources.
:::

::: practice
[Generating deviceIds]{#generating-deviceids .practicelab}

An efficient practice for generating a {{MediaDeviceInfo/deviceId}} is
to generate a cryptographic hash from a private key + (origin or
origin + top-level origin, based on the user agents\' partitioning
rules) + salt + device\'s underlying (hardware) id in the driver, and
present the resulting hash as an alphanumeric string. Using 32 bits or
fewer for the hash is recommended, but not much lower, to avoid risk of
collision.

A lower-entropy alternative, at the cost of storage, is to assign the
numbers 0 through 255 randomly to each new device encountered for each
origin or origin + top-level origin, based on the \[=User Agent=\]\'s
partitioning rules, retiring the number that hasn\'t been seen the
longest if numbers run out.
:::

::: practice
[Device muting initiated by \[=User Agent=\]]{#muting-devices
.practicelab}

A track sourced by a camera or microphone may be forcibly \[=
MediaStreamTrack/muted =\] by a \[=User Agent=\] at any time, in order
to manage a user\'s privacy. However, doing so may create web
compatibility issues, as well as leak information about user activity,
so caution is advised.

Best practice is to [mute]{lt="muted"} a camera or microphone track in
the following instances:

- An OS-level event for which the \[=User Agent=\] already suspends
  media playback globally, but JavaScript is not suspended. The
  rationale is users may otherwise be surprised if capture were to
  continue in this situation (unless they\'ve intentionally configured
  it this way). If the OS-level event already causes frames to stop
  coming in on the track, then no new information of user activity is
  revealed by this. Even when this is not the case, revealing that
  capture is ending seems like a reasonable privacy tradeoff compared to
  continuing capture in situations that may surprise users.

- A web page not \[=Document/is in view\|in view=\]
  \[=MediaStreamTrack/enabled\|re-enables=\] a track when all tracks
  from that source are \[=MediaStreamTrack/enabled\|disabled=\], in
  order to delay resumption of capture until the page \[=Document/is in
  view=\].

Best practice is to \[= MediaStreamTrack/muted \| unmute =\] a camera or
microphone track it previously \[= MediaStreamTrack/muted =\], in the
following instances:

- An OS-level event for which the \[=User Agent=\] already resumes media
  playback globally, *and* the page is visible to the user (e.g. not
  during a lock screen). \[=User Agents=\] may defer such action if it
  determines significant time has passed that may jeopardize a user\'s
  awareness of the earlier capture session.

- A web page comes \[=Document/is in view\|into view=\] and has one or
  more \[=MediaStreamTrack/enabled=\] tracks that are also \[=
  MediaStreamTrack/muted =\].
:::
::::::::
::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::: {#constrainable-interface .section}
## Constrainable Pattern

The Constrainable pattern allows applications to inspect and adjust the
properties of objects implementing it (the [constrainable
object]{.dfn}). It is broken out as a separate set of definitions so
that it can be referred to by other specifications. The core concept is
the Capability, which consists of a constrainable property of an object
and the set of its possible values, which may be specified either as a
range or as an enumeration. For example, a camera might be capable of
framerates (a property) between 20 and 50 frames per second (a range)
and may be able to be positioned (a property) facing towards the user,
away from the user, or to the left or right of the user (an enumerated
set). The application can examine a constrainable property\'s supported
Capabilities via the `getCapabilities()` accessor.

The application can select the (range of) values it wants for an
object\'s Capabilities by means of basic and/or advanced ConstraintSets
and the `applyConstraints()` method. A ConstraintSet consists of the
names of one or more properties of the object plus the desired value (or
a range of desired values) for each property. Each of those
property/value pairs can be considered to be an individual constraint.
For example, the application may set a ConstraintSet containing two
constraints, the first stating that the framerate of a camera be between
30 and 40 frames per second (a range) and the second that the camera
should be facing the user (a specific value). How the individual
constraints interact depends on whether and how they are given in the
basic Constraint structure, which is a ConstraintSet with an additional
\'advanced\' property, or whether they are in a ConstraintSet in the
advanced list. The behavior is as follows: all \'min\', \'max\', and
\'exact\' constraints in the basic Constraint structure are together
treated as the required constraints, and if it is not possible to
satisfy simultaneously all of those individual constraints for the
indicated property names, the \[=User Agent=\] MUST \[= reject =\] the
returned promise. Otherwise, it must apply the required constraints.
Next, it will consider any ConstraintSets given in the
[`advanced`](#dom-constraints-advanced) list, in the order in which they
are specified, and will try to satisfy/apply each complete ConstraintSet
(i.e., all constraints in the ConstraintSet together), but will skip a
ConstraintSet if and only if it cannot satisfy/apply it in its entirety.
Next, the \[=User Agent=\] MUST attempt to apply, individually, any
\'ideal\' constraints or a constraint given as a bare value for the
property (referred to as optional basic constraints). Of these
properties, it MUST satisfy the largest number that it can, in any
order. Finally, the \[=User Agent=\] MUST \[= resolve =\] the returned
promise.

::: note
Any constraint provided via this API will only be considered if the
given constrainable property is supported by the \[=User Agent=\].
JavaScript application code is expected to first check, via
`getSupportedConstraints()`, that all the named properties that are used
are supported by the \[=User Agent=\]. The reason for this is that
WebIDL drops any unsupported names from the dictionary holding the
constraints, so the \[=User Agent=\] does not see them and the
unsupported names end up being silently ignored. This will cause
confusing programming errors as the JavaScript code will be setting
constraints but the \[=User Agent=\] will be ignoring them. \[=User
Agents=\] that support (recognize) the name of a required constraint but
cannot satisfy it will generate an error, while \[=User Agents=\] that
do not support the constrainable property will not generate an error.
:::

The following examples may help to understand how constraints work. The
first shows a basic Constraint structure. Three constraints are given,
each of which the \[=User Agent=\] will attempt to satisfy individually.
Depending upon the resolutions available for this camera, it is possible
that not all three constraints can be satisfied at the same time. If so,
the \[=User Agent=\] will satisfy two if it can, or only one if not even
two constraints can be satisfied together. Note that if not all three
can be satisfied simultaneously, it is possible that there is more than
one combination of two constraints that could be satisfied. If so, the
\[=User Agent=\] will choose.

``` example

const stream = await navigator.mediaDevices.getUserMedia({
  video: {
    width: 1280,
    height: 720,
    aspectRatio: 3/2
  }
});
    
```

This next example adds a small bit of complexity. The ideal values are
still given for width and height, but this time with minimum
requirements on each as well as a minimum frameRate that must be
satisfied. If it cannot satisfy the frameRate, width or height minimum
it will \[= reject =\] the promise. Otherwise, it will try to satisfy
the width, height, and aspectRatio target values as well and then \[=
resolve =\] the promise.

``` example

try {
  const stream = await navigator.mediaDevices.getUserMedia({
    video: {
      width: {min: 640, ideal: 1280},
      height: {min: 480, ideal: 720},
      aspectRatio: 3/2,
      frameRate: {min: 20}
    }
  });
} catch (error) {
  if (error.name != "OverconstrainedError") {
    throw error;
  }
  // Overconstrained. Try again with a different combination (no prompt was shown)
}
    
```

This example illustrates the full control possible with the Constraints
structure by adding the \'advanced\' property. In this case, the \[=User
Agent=\] behaves the same way with respect to the required constraints,
but before attempting to satisfy the ideal values it will process the
\'advanced\' list. In this example the \'advanced\' list contains two
ConstraintSets. The first specifies width and height constraints, and
the second specifies an aspectRatio constraint. Note that in the
advanced list, these bare values are treated as \'exact\' values. This
example represents the following: \"I need my video to be at least 640
pixels wide and at least 480 pixels high. My preference is for precisely
1920x1280, but if you can\'t give me that, give me an aspectRatio of 4x3
if at all possible. If even that is not possible, give me a resolution
as close to 1280x720 as possible.\"

``` example

try {
  const stream = await navigator.mediaDevices.getUserMedia({
    video: {
      width: {min: 640, ideal: 1280},
      height: {min: 480, ideal: 720},
      frameRate: {min: 30},
      advanced: [
        {width: 1920, height: 1280},
        {aspectRatio: 4/3},
        {frameRate: {min: 50}},
        {frameRate: {min: 40}}
      ]
    }
  });
} catch (error) {
  if (error.name != "OverconstrainedError") {
    throw error;
  }
  // Overconstrained. Try again with a different combination (no prompt was shown)
}
    
```

The ordering of advanced ConstraintSets is significant. In the preceding
example it is impossible to satisfy both the 1920x1280 ConstraintSet and
the 4x3 aspect ratio ConstraintSet at the same time. Since the 1920x1280
occurs first in the list, the \[=User Agent=\] will attempt to satisfy
it first. Application authors can therefore implement a backoff strategy
by specifying multiple advanced ConstraintSets for the same property.
The application also specifies two more advanced ConstraintSets, the
first asking for a frame rate greater than 50, the second asking for a
frame rate greater than 40. If the \[=User Agent=\] is capable of
setting a frame rate greater than 50, it will (and the subsequent
ConstraintSet will be trivially satisfied). However, if the \[=User
Agent=\] cannot set the frame rate above 50, it will skip that
ConstraintSet and attempt to set the frame rate above 40. In case the
\[=User Agent=\] cannot satisfy either of the two ConstraintSets, the
\'min\' value in the basic ConstraintSet insists on 30 as a lower bound.
In other words, the \[=User Agent=\] would fail altogether if it
couldn\'t get a value over 30, but would choose a value over 50 if
possible, then try for a value over 40.

Note that, unlike basic constraints, the constraints within a
ConstraintSet in the advanced list must be satisfied together or skipped
together. Thus, {width: 1920, height: 1280} is a request for that
specific resolution, not a request for that width or that height. One
can think of the basic constraints as requesting an \'or\'
(non-exclusive) of the individual constraints, while each advanced
ConstraintSet is requesting an \'and\' of the individual constraints in
the ConstraintSet. An application may inspect the full set of
Constraints currently in effect via the `getConstraints()` accessor.

The specific value that the \[=User Agent=\] chooses for a constrainable
property is referred to as a Setting. For example, if the application
applies a ConstraintSet specifying that the frameRate must be at least
30 frames per second, and no greater than 40, the Setting can be any
intermediate value, e.g., 32, 35, or 37 frames per second. The
application can query the current settings of the object\'s
constrainable properties via the {{MediaStreamTrack/getSettings()}}
accessor.

:::::::: section
## Interface Definition

Although this specification formally defines
[ConstrainablePattern]{.dfn} as a WebIDL interface, it is actually a
template or pattern for other interfaces and cannot be inherited
directly since the return values of the methods need to be extended,
something WebIDL cannot do. Thus, each interface that wishes to make use
of the functionality defined here will have to provide its own copy of
the WebIDL for the functions and interfaces given here. However it can
refer to the semantics defined here, which will not change. See
[MediaStreamTrack Interface
Definition](#media-stream-track-interface-definition) for an example of
this.

This pattern relies on the constrainable object defining three internal
slots:

1.  A [\[\[\\Capabilities\]\]]{.dfn dfn-for="constrainable object"}
    internal slot, initialized to a `Capabilities` dictionary describing
    the aggregate allowable values for each constrainable property
    exposed, as explained under [Capabilities](#dom-capabilities), or an
    empty dictionary if it has none.

2.  A [\[\[\\Constraints\]\]]{.dfn dfn-for="constrainable object"}
    internal slot, initialized to an empty `Constraints` dictionary.

3.  A [\[\[\\Settings\]\]]{.dfn dfn-for="constrainable object"} internal
    slot, initialized to a `Settings` dictionary describing the
    currently active settings values for each constrainable property
    exposed, as explained under [Settings](#dom-settings), or an empty
    dictionary if it has none.

::::: {}
::: example
Template:

``` idl
[Exposed=Window]
interface ConstrainablePattern {
  Capabilities  getCapabilities();
  Constraints   getConstraints();
  Settings      getSettings();
  Promise<undefined> applyConstraints(optional Constraints constraints = {});
};
```
:::

::: section
## Methods

getCapabilities

:   The [getCapabilities()]{.dfn
    lt="ConstrainablePattern.getCapabilities"} method returns the
    dictionary of the names of the constrainable properties that the
    object supports. When invoked, the \[=User Agent=\] MUST return the
    value of the
    [\[\[\\Capabilities\]\]]{link-for="constrainable object"
    link-type="attribute"} internal slot.

    ::: note
    It is possible that the underlying hardware may not exactly map to
    the range defined for the constrainable property. Where this is
    possible, the entry SHOULD define how to translate and scale the
    hardware\'s setting onto the values defined for the property. For
    example, suppose that a hypothetical fluxCapacitance property ranges
    from -10 (min) to 10 (max), but there are common hardware devices
    that support only values of \"off\" \"medium\" and \"full\". The
    constrainable property definition might specify that for such
    hardware, the \[=User Agent=\] should map the range value of -10 to
    \"off\", 10 to \"full\", and 0 to \"medium\". It might also indicate
    that given a ConstraintSet imposing a strict value of 3, the \[=User
    Agent=\] should attempt to set the value of \"medium\" on the
    hardware, and that {{getSettings()}} should return a fluxCapacitance
    of 0, since that is the value defined as corresponding to
    \"medium\".
    :::

{{getConstraints}}

:   The [getConstraints()]{.dfn} method returns the Constraints that
    were the argument to the most recent successful invocation of the
    ApplyConstraints algorithm on the object, maintaining the order in
    which they were specified. Note that some of the advanced
    ConstraintSets returned may not be currently satisfied. To check
    which ConstraintSets are currently in effect, the application should
    use {{getSettings}}. Instead of returning the exact constraints as
    described above, the UA MAY return a constraint set that has the
    identical effect in all situations as the applied constraints. When
    invoked, the \[=User Agent=\] MUST return the value of the
    [\[\[\\Constraints\]\]]{link-for="constrainable object"
    link-type="attribute"} internal slot.

getSettings

:   The [getSettings()]{.dfn} method returns the current settings of all
    the constrainable properties of the object, whether they are
    platform defaults or have been set by the ApplyConstraints
    algorithm. Note that a setting is a target value that complies with
    constraints, and therefore may differ from measured performance at
    times. When invoked, the User Agent MUST return the value of the
    [\[\[\\Settings\]\]]{link-for="constrainable object"
    link-type="attribute"} internal slot.

applyConstraints

:   When the [applyConstraints template method]{.dfn} is invoked, the
    \[=User Agent=\] MUST run the following steps:

    1.  Let `object`{.variable} be the object on which this method was
        invoked.

    2.  Let `newConstraints`{.variable} be the argument to this method.

    3.  Let `p`{.variable} be a new promise.

    4.  Run the following steps in parallel, maintaining the order of
        invocations if this method is called multiple times:

        1.  Let `failedConstraint`{.variable} be the result of running
            the ApplyConstraints algorithm with
            `newConstraints`{.variable} as the argument.

        2.  Let `successfulSettings`{.variable} be the
            `object`{.variable}\'s current settings after the algorithm
            in the above step has finished.

        3.  Queue a task that runs the following steps:

            1.  If `failedConstraint`{.variable} is not `undefined`, let
                `message`{.variable} be either `undefined` or an
                informative human-readable message, \[= reject =\]
                `p`{.variable} with a new `OverconstrainedError` created
                by calling
                `OverconstrainedError(``failedConstraint`{.variable}`, ``message`{.variable}`)`,
                and abort these steps. The existing constraints remain
                in effect in this case.

            2.  Set `object`{.variable}\'s
                [\[\[\\Constraints\]\]]{link-for="constrainable object"
                link-type="attribute"} internal slot to
                `newConstraints`{.variable} or a `Constraints`
                dictionary that has the identical effect in all
                situations as `newConstraints`{.variable}.

            3.  Set `object`{.variable}\'s
                [\[\[\\Settings\]\]]{link-for="constrainable object"
                link-type="attribute"} internal slot to
                `successfulSettings`{.variable}.

            4.  \[= resolve =\] `p`{.variable} with `undefined`.

    5.  Return `p`{.variable}.

    The \[=ApplyConstraints algorithm=\] for applying constraints is
    stated below. Here are some preliminary definitions that are used in
    the statement of the algorithm:

    We use the term [settings dictionary]{.dfn export=""} for the set of
    values that might be applied as settings to the object.

    For string valued constraints, we define \"==\" below to be true if
    one of the values in the sequence is exactly the same as the value
    being compared against.

    We define the [fitness distance]{.dfn export=""} between a settings
    dictionary and a constraint set `CS`{.variable} as the sum, for each
    member (represented by a `constraintName`{.variable} and
    `constraintValue`{.variable} pair) which \[= map/exist =\]s in
    `CS`{.variable}, of the following values:

    1.  If `constraintName`{.variable} is not supported by the \[=User
        Agent=\], the fitness distance is 0.

    2.  If the constraint is [required]{.dfn}
        (`constraintValue`{.variable} either contains one or more
        members named \'min\', \'max\', or \'exact\', or is itself a
        bare value in an advanced ConstraintSet), and the settings
        dictionary\'s `constraintName`{.variable} member\'s value does
        not satisfy the constraint or doesn\'t \[= map/exist =\], the
        fitness distance is positive infinity.

    3.  If the constraint does not apply for this type of object, the
        fitness distance is 0 (that is, the constraint does not
        influence the fitness distance).

    4.  If `constraintValue`{.variable} is a boolean, but the
        constrainable property is not, then the fitness distance is
        based on whether the settings dictionary\'s
        `constraintName`{.variable} member \[= map/exist \| exists =\]
        or not, from the formula

            (constraintValue == exists) ? 0 : 1

    5.  If the settings dictionary\'s `constraintName`{.variable} member
        does \[= map/exist \| not exist=\], the fitness distance is 1.

    6.  If no ideal value is specified (`constraintValue`{.variable}
        either contains no member named \'ideal\', or, if bare values
        are to be treated as \'ideal\', isn\'t a bare value), the
        fitness distance is 0.

    7.  For all positive numeric constraints (such as height, width,
        frameRate, aspectRatio, sampleRate and sampleSize), the fitness
        distance is the result of the formula


            (actual == ideal) ? 0 : |actual - ideal| / max(|actual|, |ideal|)

    8.  For all string, enum and boolean constraints (e.g. deviceId,
        groupId, facingMode, resizeMode, echoCancellation), the fitness
        distance is the result of the formula

            (actual == ideal) ? 0 : 1

    More definitions:

    - We refer to each element of a ConstraintSet (other than the
      special term \'advanced\') as a \'constraint\' since it is
      intended to constrain the acceptable settings for the given
      property from the full list or range given in the corresponding
      Capability of the ConstrainablePattern object to a value that is
      within the range or list of values it specifies.
    - We refer to the \"effective Capability\" C of an object O as the
      possibly proper subset of the possible values of C (as returned by
      getCapabilities) taking into consideration environmental
      limitations and/or restrictions placed by other constraints. For
      example given a ConstraintSet that constrains the aspectRatio,
      height, and width properties, the values assigned to any two of
      the properties limit the effective Capability of the third. The
      set of effective Capabilities may be platform dependent. For
      example, on a resource-limited device it may not be possible to
      set properties P1 and P2 both to \'high\', while on another less
      limited device, this may be possible.
    - A settings dictionary, which is a set of values for the
      constrainable properties of an object O, satisfies ConstraintSet
      CS if the fitness distance between the set and CS is less than
      infinity.
    - A set of ConstraintSets CS1\...CSn (n \>= 1) can be satisfied by
      an object O if it is possible to find a settings dictionary of O
      that satisfies CS1\...CSn simultaneously.
    - To apply a set of ConstraintSets CS1\...CSn to object O is to
      choose such a sequence of values that satisfy CS1\...CSn and
      assign them as the settings for the properties of O.

    We define the [SelectSettings]{.dfn .abstract-op} algorithm as
    follows:

    1.  Each constraint specifies one or more values (or a range of
        values) for its property. A property MAY appear more than once
        in the list of \'advanced\' ConstraintSets. If an empty list has
        been given as the value for a constraint, it MUST be interpreted
        as if the constraint were not specified (in other words, an
        empty constraint == no constraint).

        Note that unknown properties are discarded by WebIDL, which
        means that unknown/unsupported required constraints will
        silently disappear. To avoid this being a surprise, application
        authors are expected to first use the
        {{MediaDevices/getSupportedConstraints()}} method as shown in
        the Examples below.

    2.  Let `object`{.variable} be the `ConstrainablePattern` object on
        which this algorithm is applied. Let `copy`{.variable} be an
        unconstrained copy of `object`{.variable} (i.e.,
        `copy`{.variable} should behave as if it were
        `object`{.variable} with all ConstraintSets removed.)

    3.  For every possible settings dictionary of `copy`{.variable}
        compute its fitness distance, treating bare values of properties
        as ideal values. Let `candidates`{.variable} be the set of
        [settings dictionaries]{lt="settings dictionary"} for which the
        fitness distance is finite.

    4.  If `candidates`{.variable} is empty, return `undefined` as the
        result of the SelectSettings algorithm.

    5.  Iterate over the \'advanced\' ConstraintSets in
        `newConstraints`{.variable} in the order in which they were
        specified. For each ConstraintSet:
        1.  compute the fitness distance between it and each settings
            dictionary in `candidates`{.variable}, treating bare values
            of properties as exact.

        2.  If the fitness distance is finite for one or more settings
            dictionaries in `candidates`{.variable}, keep those settings
            dictionaries in `candidates`{.variable}, discarding others.

            If the fitness distance is infinite for all settings
            dictionaries in `candidates`{.variable}, ignore this
            ConstraintSet.

    6.  Select one settings dictionary from `candidates`{.variable}, and
        return it as the result of the SelectSettings algorithm. The
        \[=User Agent=\] MUST use one with the smallest fitness
        distance, as calculated in step 3. If more than one settings
        dictionary have the smallest fitness distance, the \[=User
        Agent=\] chooses one of them based on system default property
        values and \[=User Agent=\] default property values.

    For any property with a system default value for the selected
    device, the system default value SHOULD be used if compatible with
    the above algorithm. This is usually the case for properties like
    [sampleRate](#def-constraint-sampleRate) or
    [sampleSize](#def-constraint-sampleSize). Other properties, like
    [echoCancellation](#def-constraint-echoCancellation) or
    [resizeMode](#def-constraint-resizeMode) do not usually have system
    default values. The \[=User Agent=\] defines its own default values
    for these properties. Implementors need to be cautious to select
    good default values since they will often have an impact on how
    media content is generated.

    ::: note
    It is recommended to look at existing implementations to select
    meaningful default values. Note that default values may differ based
    on the system, for instance desktop vs. mobile. At time of writing,
    \[=User Agent=\] implementations tend to use the following default
    values, which were chosen for their suitability for using
    RTCPeerConnection as a sink:

    1.  [width](#def-constraint-width) set to 640.

    2.  [height](#def-constraint-height) set to 480.

    3.  [frameRate](#def-constraint-frameRate) set to 30.

    4.  [echoCancellation](#def-constraint-echoCancellation) set to
        `true`.
    :::

    To apply the [ApplyConstraints algorithm]{.dfn .abstract-op} to an
    `object`{.variable}, given `newConstraints`{.variable} as an
    argument, the \[=User Agent=\] MUST run the following steps:

    1.  Let `successfulSettings`{.variable} be the result of running the
        SelectSettings algorithm with `newConstraints`{.variable} as the
        constraint set.

    2.  If `successfulSettings`{.variable} is `undefined`, let
        `failedConstraint`{.variable} be any [required
        constraint]{lt="required constraints"} whose fitness distance
        was infinity for all settings dictionaries examined while
        executing the SelectSettings algorithm, or `""` if there isn\'t
        one, and then return `failedConstraint`{.variable} and abort
        these steps.

    3.  In a single operation, remove the existing constraints from
        `object`{.variable}, apply `newConstraints`{.variable}, and
        apply `successfulSettings`{.variable} as the current settings.

    4.  Return `undefined`.

    ::: note
    If the UA \[=relinquish the device\|relinquished the device=\], for
    instance if the track is \[=MediaStreamTrack/muted\|muted=\],
    applying the settings does not mean changing the device
    configuration. Instead, the UA will configure the device to match
    the track settings at the time the UA is reacquiring the device, for
    instance when the track gets \[=MediaStreamTrack/muted\|unmuted=\].
    :::

    ::: note
    Any implementation that has the same result as the algorithm above
    is an allowed implementation. For instance, the implementation may
    choose to keep track of the maximum and minimum values for a setting
    that are OK under the constraints considered, rather than keeping
    track of all possible values for the setting.
    :::

    ::: note
    When picking a settings dictionary, the UA can use any information
    available to it. Examples of such information may be whether the
    selection is done as part of device selection in getUserMedia,
    whether the energy usage of the camera varies between the settings
    dictionaries, or whether using a settings dictionary will cause the
    device driver to apply resampling.
    :::

    The \[=User Agent=\] MAY choose new settings for the constrainable
    properties of the object at any time. When it does so it MUST
    attempt to satisfy all current Constraints, in the manner described
    in the algorithm above, let `successfulSettings`{.variable} be the
    resulting new settings, and queue a task to run the following steps:

    1.  Let `object`{.variable} be the `ConstrainablePattern` object on
        which new settings for one or more constrainable properties have
        changed.

    2.  Set `object`{.variable}\'s
        [\[\[\\Settings\]\]]{link-for="constrainable object"
        link-type="attribute"} internal slot to
        `successfulSettings`{.variable}.
:::
:::::

An example of Constraints that could be passed into
{{MediaStreamTrack/applyConstraints()}} or returned as a value of
`constraints` is below. It uses the [constrainable
properties](#constrainable-properties) defined for camera-sourced
{{MediaStreamTrack}}s. In this example, all constraints are ideal
values, which means results are \"best effort\" based on the user\'s
specific camera:

``` example

await track.applyConstraints({
  width: 1920,
  height: 1080,
  frameRate: 30,
});
const {width, height, frameRate} = track.getSettings();

console.log(`${width}x${height}x${frameRate}`); // 1920x1080x30, or it might be e.g.
                                                // 1280x720x30 as best effort
      
```

For finer control, an application can insist on an exact match, provided
it\'s prepared to handle failure:

``` example

try {
  await track.applyConstraints({
    width: {exact: 1920},
    height: {exact: 1080},
    frameRate: {min: 25, ideal: 30, max: 30},
  });
  const {width, height, frameRate} = track.getSettings();

  console.log(`${width}x${height}x${frameRate}`); // 1920x1080x25-30!

} catch (error) {
  if (error.name != "OverconstrainedError") {
    throw error;
  }
  console.log(`This camera cannot produce the requested ${error.constraint}.`);
}

      
```

Constraints can also be passed into {{MediaDevices/getUserMedia}}, not
just as an initialization convenience, but to influence device
selection. In this case, \[= list of inherent constrainable track
properties \| inherent constraints =\] are also available.

Here\'s an example of using constraints to prefer a specific camera and
microphone from a previous visit, with requirements on dimensions and a
preference for stereo, to be applied once granted, and to help find
suitable replacements in case the requested devices are no longer
available (or in some user agents, overriden by the user).

``` example

try {
  const stream = await navigator.mediaDevices.getUserMedia({
    video: {
      deviceId: localStorage.camId,
      width: {min: 800, ideal: 1024, max: 1280},
      height: {min: 600}
    },
    audio: {
      deviceId: localStorage.micId,
      channelCount: 2
    }
  });

  // Granted. Store deviceIds for next time
  localStorage.camId = stream.getVideoTracks()[0].getSettings().deviceId;
  localStorage.micId = stream.getAudioTracks()[0].getSettings().deviceId;

} catch (error) {
  if (error.name != "OverconstrainedError") {
    throw error;
  }
  // Overconstrained. No suitable replacements found
}
      
```

::: note
The above example avoids using `{exact: deviceId}`, so that browsers can
use internally-available information about the devices, such as user
preference or absence of a device, over the provided `deviceId`.

The example also stores the `deviceId`s on every grant, in case they
represent a new choice.
:::

In contrast, here\'s an example of using constraints to implement an
in-content camera picker. In this case, we use `exact` and rely solely
on a `deviceId` that comes from the user picking from a list of choices:

``` example

async function switchCameraTrack(freshlyChosenDeviceId, oldTrack) {
  if (isMobile) {
    oldTrack.stop(); // Some platforms can only open one camera at a time.
  }
  const stream = await navigator.mediaDevices.getUserMedia({
    video: {
      deviceId: {exact: freshlyChosenDeviceId}
    }
  });
  const [track] = stream.getVideoTracks();
  localStorage.camId = track.getSettings().deviceId;
  return track;
}
      
```

Here\'s an example asking for a back camera on a phone, ideally in 720p,
but accepting anything close to that. Note how constraints on dimensions
are specified in landscape mode:

``` example

async function getBackCamera() {
  return await navigator.mediaDevices.getUserMedia({
    video: {
      facingMode: {exact: 'environment'},
      width: 1280,
      height: 720
    }
  });
}
      
```

Here\'s an example of \"I want a native 16:9 resolution near 720p, but
with an exact frame rate of 10 even if not natively available\". This
needs to be done in two steps: One to discover the native mode, and a
second step to apply the custom frame rate. This also shows how to
derive constraints from current settings, which may be rotated:

``` example

async function nativeResolutionButDecimatedFrameRate() {
  const stream = await navigator.mediaDevices.getUserMedia({
    video: {
      resizeMode: 'none', // means native resolution and frame rate
      width: 1280,
      height: 720,
      aspectRatio: 16 / 9 // aspect ratios may not be exactly accurate
    }
  });
  const [track] = stream.getVideoTracks();
  const {width, height, aspectRatio} = track.getSettings();

  // Constraints are in landscape, while settings may be rotated (portrait)
  if (width < height) {
    [width, height] = [height, width];
    aspectRatio = 1 / aspectRatio;
  }

  await track.applyConstraints({
    resizeMode: 'crop-and-scale',
    width: {exact: width},
    height: {exact: height},
    frameRate: {exact: 10},
    aspectRatio,
  });

  return stream;
}
      
```

::: note
The above example assumes the primary orientation is landscape.
:::

Here\'s an example showing how to use
{{MediaDevices/getSupportedConstraints}}, for cases where a constraint
being ignored due to lack of support in a user agent is not tolerated by
the application:

``` example

async function getFrontCameraRes() {
  const supports = navigator.mediaDevices.getSupportedConstraints();

  for (const constraint of ["facingMode", "aspectRatio", "resizeMode"]) {
    if (!(constraint in supports) {
      throw new OverconstrainedError(constraint, "Not supported");
    }
  }
  return await navigator.mediaDevices.getUserMedia({
    video: {
      facingMode: {exact: 'user'},
      advanced: [
        {aspectRatio: 16/9, height: 1080, resizeMode: "none"},
        {aspectRatio: 4/3, width: 1280, resizeMode: "none"}
      ]
    }
  });
}
      
```
::::::::

::::::::::::::::::::::::::: section
## Constraint Types

The syntax for the specification of the set of valid inputs depends on
the type of the values. In addition to the standard atomic types
(boolean, long, double, DOMString), valid values include lists of any of
the atomic types, plus min-max ranges, as defined below.

List values MUST be interpreted as disjunctions. For example, if a
property \'facingMode\' for a camera is defined as having valid values
\[\"left\", \"right\", \"user\", \"environment\"\], this means that
\'facingMode\' can have the values \"left\", \"right\", \"environment\",
and \"user\". Similarly Constraints restricting \'facingMode\' to
\[\"user\", \"left\", \"right\"\] would mean that the \[=User Agent=\]
should select a camera (or point the camera, if that is possible) so
that \"facingMode\" is either \"user\", \"left\", or \"right\". This
Constraint would thus request that the camera not be facing away from
the user, but would allow the \[=User Agent=\] to allow the user to
choose other directions.

:::: {}
``` idl
dictionary DoubleRange {
  double max;
  double min;
};
```

::: section
## Dictionary [DoubleRange]{.dfn} Members

[max]{.dfn} of type {{double}}

:   The maximum valid value of this property.

[min]{.dfn} of type {{double}}

:   The minimum value of this Property.
:::
::::

:::: {}
``` idl
dictionary ConstrainDoubleRange : DoubleRange {
  double exact;
  double ideal;
};
```

::: section
## Dictionary [ConstrainDoubleRange]{.dfn} Members

[exact]{.dfn} of type {{double}}

:   The exact required value for this property.

[ideal]{.dfn} of type {{double}}

:   The ideal (target) value for this property.
:::
::::

:::: {}
``` idl
dictionary ULongRange {
  [Clamp] unsigned long max;
  [Clamp] unsigned long min;
};
```

::: section
## Dictionary [ULongRange]{.dfn} Members

[max]{.dfn} of type {{unsigned long}}

:   The maximum valid value of this property.

[min]{.dfn} of type {{unsigned long}}

:   The minimum value of this property.
:::
::::

:::: {}
``` idl
dictionary ConstrainULongRange : ULongRange {
  [Clamp] unsigned long exact;
  [Clamp] unsigned long ideal;
};
```

::: section
## Dictionary [ConstrainULongRange]{.dfn} Members

[exact]{.dfn} of type {{unsigned long}}

:   The exact required value for this property.

[ideal]{.dfn} of type {{unsigned long}}

:   The ideal (target) value for this property.
:::
::::

:::: {}
``` idl
dictionary ConstrainBooleanParameters {
  boolean exact;
  boolean ideal;
};
```

::: section
## Dictionary [ConstrainBooleanParameters]{.dfn} Members

[exact]{.dfn} of type {{boolean}}

:   The exact required value for this property.

[ideal]{.dfn} of type {{boolean}}

:   The ideal (target) value for this property.
:::
::::

:::: {}
``` idl
dictionary ConstrainDOMStringParameters {
  (DOMString or sequence<DOMString>) exact;
  (DOMString or sequence<DOMString>) ideal;
};
```

::: section
## Dictionary [ConstrainDOMStringParameters]{.dfn} Members

[exact]{.dfn} of type `({{DOMString}} or sequence<{{DOMString}}>)`

:   The exact required value for this property.

[ideal]{.dfn} of type `({{DOMString}} or sequence<{{DOMString}}>)`

:   The ideal (target) value for this property.
:::
::::

:::: {}
``` idl
dictionary ConstrainBooleanOrDOMStringParameters {
  (boolean or DOMString) exact;
  (boolean or DOMString) ideal;
};
```

::: section
## Dictionary [ConstrainBooleanOrDOMStringParameters]{.dfn} Members

[exact]{.dfn} of type ({{boolean}} or {{DOMString}})

:   The exact required value for this property.

[ideal]{.dfn} of type ({{boolean}} or {{DOMString}})

:   The ideal (target) value for this property.
:::
::::

:::: {}
``` idl
typedef ([Clamp] unsigned long or ConstrainULongRange) ConstrainULong;
```

::: idlTypedefDesc
Throughout this specification, the identifier [ConstrainULong]{.dfn} is
used to refer to the [(\[Clamp\] unsigned long or
ConstrainULongRange)]{.idlTypedefType} type.
:::
::::

:::: {}
``` idl
typedef (double or ConstrainDoubleRange) ConstrainDouble;
```

::: idlTypedefDesc
Throughout this specification, the identifier [ConstrainDouble]{.dfn} is
used to refer to the [(double or ConstrainDoubleRange)]{.idlTypedefType}
type.
:::
::::

:::: {}
``` idl
typedef (boolean or ConstrainBooleanParameters) ConstrainBoolean;
```

::: idlTypedefDesc
Throughout this specification, the identifier [ConstrainBoolean]{.dfn}
is used to refer to the [(boolean or
ConstrainBooleanParameters)]{.idlTypedefType} type.
:::
::::

:::: {}
``` idl
typedef (DOMString or
         sequence<DOMString> or
         ConstrainDOMStringParameters) ConstrainDOMString;
```

::: idlTypedefDesc
Throughout this specification, the identifier [ConstrainDOMString]{.dfn}
is used to refer to the [(DOMString or sequence\<DOMString\> or
ConstrainDOMStringParameters)]{.idlTypedefType} type.
:::
::::

:::: {}
``` idl
typedef (boolean or DOMString or ConstrainBooleanOrDOMStringParameters) ConstrainBooleanOrDOMString;
```

::: idlTypedefDesc
Throughout this specification, the identifier
[ConstrainBooleanOrDOMString]{.dfn} is used to refer to the [(boolean or
DOMString or ConstrainBooleanOrDOMStringParameters)]{.idlTypedefType}
type.
:::
::::
:::::::::::::::::::::::::::

:::: {#capabilities .section}
### Capabilities

[Capabilities]{.dfn dfn-type="dictionary"} is a dictionary containing
one or more key-value pairs, where each key MUST be a constrainable
property, and each value MUST be a subset of the set of values allowed
for that property. The exact syntax of the value expression depends on
the type of the property. The Capabilities dictionary specifies which
constrainable properties that can be applied, as constraints, to the
constrainable object. Note that the Capabilities of a constrainable
object MAY be a subset of the properties defined in the Web platform,
with a subset of the set values for those properties. Note that
Capabilities are returned from the \[=User Agent=\] to the application,
and cannot be specified by the application. However, the application can
control the Settings that the \[=User Agent=\] chooses for constrainable
properties by means of Constraints.

An example of a Capabilities dictionary is shown below. In this case,
the constrainable object is a video source with a very limited set of
Capabilities.

``` example

{
  frameRate: {min: 1.0, max: 60.0},
  facingMode: ['user', 'left']
}
      
```

The next example below points out that capabilities for range values
provide ranges for individual constrainable properties, not
combinations. This is particularly relevant for video width and height,
since the ranges for width and height are reported separately. In the
example, if the constrainable object can only provide 640x480 and
800x600 resolutions the relevant capabilities returned would be:

``` example

{
  width: {min: 640, max: 800},
  height: {min: 480, max: 600},
  aspectRatio: {min: 4/3, max: 4/3}
}
      
```

Note in the example above that the aspectRatio would make clear that
arbitrary combination of widths and heights are not possible, although
it would still suggest that more than two resolutions were available.

A specification using the Constrainable Pattern should not subclass the
below dictionary, but instead provide its own definition. See
{{MediaTrackCapabilities}} for an example.

::: example
Template:

``` idl
dictionary Capabilities {};
```
:::
::::

:::: section
### Settings

[Settings]{.dfn} is a dictionary containing one or more key-value pairs.
It MUST contain each key returned in `getCapabilities()` for which the
property is defined on the object type it\'s returned on; for instance,
an audio {{MediaStreamTrack}} has no \"width\" property. There MUST be a
single value for each key and the value MUST be a member of the set
defined for that property by `getCapabilities()`. The `Settings`
dictionary contains the actual values that the User Agent has chosen for
the object\'s constrainable properties. The exact syntax of the value
depends on the type of the property.

A conforming \[=User Agent=\] MUST support all the constrainable
properties defined in this specification.

An example of a Settings dictionary is shown below. This example is not
very realistic in that a \[=User Agent=\] would actually be required to
support more constrainable properties than just these.

``` example

{
  frameRate: 30.0,
  facingMode: 'user'
}
      
```

A specification using the Constrainable Pattern should not subclass the
below dictionary, but instead provide its own definition. See
{{MediaTrackSettings}} for an example.

::: example
Template:

``` idl
dictionary Settings {};
```
:::
::::

:::::: {#constraints .section}
### Constraints and ConstraintSet

Due to the limitations of WebIDL, interfaces implementing the
Constrainable Pattern cannot simply subclass Constraints and
ConstraintSet as they are defined here. Instead they must provide their
own definitions that follow this pattern. See
[MediaTrackConstraints](#media-track-constraints) for an example of
this.

::: example
Template:

``` idl
dictionary ConstraintSet {};
```
:::

Each member of a [ConstraintSet]{.dfn} corresponds to a constrainable
property and specifies a subset of the property\'s valid Capability
values. Applying a ConstraintSet instructs the \[=User Agent=\] to
restrict the settings of the corresponding constrainable properties to
the specified values or ranges of values. A given property MAY occur
both in the basic Constraints set and in the advanced ConstraintSets
list, and MAY occur at most once in each ConstraintSet in the advanced
list.

::: example
Template:

``` idl
dictionary Constraints : ConstraintSet {
  sequence<ConstraintSet> advanced;
};
```
:::

::: section
## Dictionary [Constraints]{.dfn} Members

[`advanced`]{.dfn} of type [sequence\<{{ConstraintSet}}\>]{.idlMemberType}

:   This is the list of ConstraintSets that the \[=User Agent=\] MUST
    attempt to satisfy, in order, skipping only those that cannot be
    satisfied. The order of these ConstraintSets is significant. In
    particular, when they are passed as an argument to
    `applyConstraints`, the \[=User Agent=\] MUST try to satisfy them in
    the order that is specified. Thus if advanced ConstraintSets C1 and
    C2 can be satisfied individually, but not together, then whichever
    of C1 and C2 is first in this list will be satisfied, and the other
    will not. The \[=User Agent=\] MUST attempt to satisfy all
    ConstraintSets in the list, even if some cannot be satisfied. Thus,
    in the preceding example, if constraint C3 is specified after C1 and
    C2, the \[=User Agent=\] will attempt to satisfy C3 even though C2
    cannot be satisfied. Note that a given property name may occur only
    once in each ConstraintSet but may occur in more than one
    ConstraintSet.
:::
::::::
:::::::::::::::::::::::::::::::::::::::::::

::::: section
## Examples

::: {}
This sample code exposes a button. When clicked, the button is disabled
and the user is prompted to offer a stream. The user can cause the
button to be re-enabled by providing a stream (e.g., giving the page
access to the local camera) and then disabling the stream (e.g.,
revoking that access).

``` example

<button id="startBtn">Start</button>
<script>
const startBtn = document.getElementById('startBtn');

startBtn.onclick = async () => {
  try {
    startBtn.disabled = true;
    const constraints = {
      audio: true,
      video: true
    };

    const stream = await navigator.mediaDevices.getUserMedia(constraints);

    for (const track of stream.getTracks()) {
      track.onended = () => {
        startBtn.disabled = stream.getTracks().some((t) => t.readyState == 'live');
      };
    }
  } catch (err) {
    console.error(err);
  }
};
</script>
      
```
:::

::: {}
This example allows people to take photos of themselves from the local
video camera. Note that the Image Capture specification
\[\[?image-capture\]\] provides a simpler way to accomplish this.

``` example

<script>
window.onload = async () => {
  const video = document.getElementById('monitor');
  const canvas = document.getElementById('photo');
  const shutter = document.getElementById('shutter');

  try {
    video.srcObject = await navigator.mediaDevices.getUserMedia({video: true});

    await new Promise(resolve => video.onloadedmetadata = resolve);
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    document.getElementById('splash').hidden = true;
    document.getElementById('app').hidden = false;

    shutter.onclick = () => canvas.getContext('2d').drawImage(video, 0, 0);
  } catch (err) {
    console.error(err);
  }
};
</script>

<h1>Snapshot Kiosk</h1>

<section id="splash">
  <p id="errorMessage">Loading...</p>
</section>

<section id="app" hidden>
  <video id="monitor" autoplay></video>
  <button id="shutter">&#x1F4F7;</button>
  <canvas id="photo"></canvas>
</section>
      
```
:::
:::::

::: section
# Permissions Integration

This specification defines two \[=powerful features=\] identified by the
\[=powerful feature/names=\] [`"camera"`]{.dfn .permission} and
[`"microphone"`]{.dfn .permission}.

It defines the following types and algorithms:

\[=powerful feature/permission descriptor type=\]

:   ``` idl

              dictionary CameraDevicePermissionDescriptor : PermissionDescriptor {
                boolean panTiltZoom = false;
              };
            
    ```

    A permission covers access to at least one device of a kind.

    The semantics of the descriptor is that it queries for access to any
    device of that kind. Thus, if a query for the \"camera\" permission
    returns {{PermissionState/\"granted\"}}, the client knows that it
    will get access to one camera without a permission prompt, and if
    {{PermissionState/\"denied\"}} is returned, it knows that no
    getUserMedia request for a camera will succeed.

    If the User Agent considers permission given to some, but not all,
    devices of a kind, a query will return
    {{PermissionState/\"granted\"}}.

    If the User Agent considers permission denied to all devices of a
    kind, a query will return {{PermissionState/\"denied\"}}.

    \`{name: \"camera\", panTiltZoom: true}\` is
    \[=PermissionDescriptor/stronger than=\] \`{name: \"camera\",
    panTiltZoom: false}\`.

    A {{PermissionState/\"granted\"}} permission is no guarantee that
    getUserMedia will succeed. It only indicates that the user will not
    be prompted for permission. There are many other things (such as
    constraints or the camera being in use) that can cause getUserMedia
    to fail.

\[=powerful feature/permission revocation algorithm=\]
:   This is the result of calling the \[=device permission revocation
    algorithm=\] passing {{PermissionDescriptor/name}} as argument.
:::

:::: section
# Permissions Policy Integration

This specification defines two \[=policy-controlled features=\]
identified by the strings \"camera\" and \"microphone\". Both have a
\[=policy-controlled feature/default allowlist=\] of
`"self"`{.permissionspolicy}.

::: note
A \[=document=\]\'s \[=Document/permissions policy=\] determines whether
any content in that document is allowed to use
{{MediaDevices/getUserMedia}} to request camera or microphone
respectively. If disabled in any document, no content in the document
will be \[=allowed to use=\] {{MediaDevices/getUserMedia}} to request
the camera or microphone respectively. This is enforced by the
\[=request permission to use=\] algorithm.

Additionally, {{MediaDevices/enumerateDevices}} will only enumerate
devices the document is \[=allowed to use=\].
:::
::::

::: section
# Privacy Indicator Requirements

This specification expresses privacy indicator requirements using
algorithms from the viewpoint of a single {{MediaDevices}} object.
Implementers are encouraged to extrapolate these principles to unify
presentation of indicators to cover multiple {{MediaDevices}} objects
that can co-exist on a page due to iframes.

For each `kind`{.variable} of device that
{{MediaDevices/getUserMedia()}} exposes,

- Define `any<kind>Accessible`{.variable} (e.g.
  `anyAudioAccessible`{.variable}, `anyVideoAccessible`{.variable}) as
  the logical OR of the
  {{MediaDevices/\[\[kindsAccessibleMap\]\]}}`[kind]`{.variable} value
  and all the
  {{MediaDevices/\[\[devicesAccessibleMap\]\]}}`[deviceId]`{.variable}
  values for devices of that kind.
- Define any`<kind>Live`{.variable} (e.g. `anyAudioLive`{.variable},
  `anyVideoLive`{.variable}) to be the logical OR of the
  {{MediaDevices/\[\[kindsAccessibleMap\]\]}}`[kind]`{.variable} value
  and all the
  {{MediaDevices/\[\[devicesLiveMap\]\]}}`[deviceId]`{.variable} values
  for devices of that kind.

Define `anyAccessible`{.variable} to be the logical OR of all
`any<kind>Accessible`{.variable} values.

Define `anyLive`{.variable} to be the logical OR of all
`any<kind>Live`{.variable} values.

Then the following are requirements on the \[=User Agent=\]:

- The \[=User Agent=\] MUST indicate to the user when the value of
  `anyAccessible`{.variable} changes.
- The \[=User Agent=\] MUST indicate to the user when the value of
  `anyLive`{.variable} changes.
- If the \[=User Agent=\] provides indication to the user per
  `kind`{.variable}, then for each `any<kind>Accessible`{.variable}
  value and `any<kind>Live`{.variable} value, it MUST at minimum
  indicate when the value changes.
- If the \[=User Agent=\] provides indication to the user per
  `device`{.variable}, then for each
  {{MediaDevices/\[\[devicesAccessibleMap\]\]}}`[deviceId]`{.variable}
  value and
  {{MediaDevices/\[\[devicesLiveMap\]\]}}`[deviceId]`{.variable} value,
  it MUST at minimum indicate when the value changes.
- Any false-to-true transition indicated MUST remain observable for a
  sufficient time that a reasonably-observant user could become aware of
  it. This SHOULD be at least 3 seconds.
- Any of the above transition indications MAY be combined as long as the
  combined indication cannot transition to false if any of its component
  indications are still true.

and the following are encouraged behaviors for the \[=User Agent=\]:

- The \[=User Agent=\] is encouraged to provide ongoing indication of
  the current state of `anyAccessible`{.variable}.
- The \[=User Agent=\] is encouraged to provide ongoing indication of
  the current state of `anyLive`{.variable} and to make any generic
  hardware device indicator light match.
- If the \[=User Agent=\] provides indication to the user per
  `kind`{.variable}, then for each any`<kind>Accessible`{.variable}
  value and any`<kind>Live`{.variable} value, it is encouraged to
  provide ongoing indication of the current state of the value. It is
  also encouraged to make any device-type-specific hardware indicator
  light match the corresponding any`<kind>Live`{.variable} value.
- If the \[=User Agent=\] provides indication to the user per
  `device`{.variable}, then for each
  {{MediaDevices/\[\[devicesAccessibleMap\]\]}}`[deviceId]`{.variable}
  value and
  {{MediaDevices/\[\[devicesLiveMap\]\]}}`[deviceId]`{.variable} value,
  it is encouraged to provide ongoing indication of the current state of
  the value. It is also encouraged to make any device-specific hardware
  indicator light match the corresponding
  {{MediaDevices/\[\[devicesLiveMap\]\]}}`[deviceId]`{.variable} value.
- Any of the above ongoing indications MAY be used instead of the
  corresponding required transition indication provided the
  false-to-true transition requirement is met.
:::

:::: section
# Privacy and Security Considerations

This section is non-normative; it specifies no new behavior, but instead
summarizes information already present in other parts of the
specification.

This specification extends the Web platform with the ability to manage
input devices for media - specifically microphones, and cameras. It also
potentially allows exposure of information about other media devices,
such as audio output devices (speakers and headphones), but the details
of such exposure is relegated to other specifications. Capturing audio
and video from the user\'s microphone and camera exposes
personally-identifiable information to applications, and this
specification requires obtaining explicit user consent before sharing
it.

Ahead of camera or microphone capture, an application (the \"drive-by
web\") is only offered the ability to tell whether the user has a camera
or a microphone (but not how many). The identifiers for the devices are
designed to not be useful for a fingerprint that can track the user
between origins, but the presence of camera or microphone ability adds
two bits to the fingerprint surface. It recommends to treat the
per-origin persistent identifier {{MediaDeviceInfo/deviceId}} as other
persistent storage (e.g. cookies) are treated.

Once camera or microphone capture has begun, this specification
describes how to get access to, and use, media data from the devices
mentioned. This data may be sensitive; advice is given that indicators
should be supplied to indicate that devices are in use, but both the
nature of permission and the indicators of in-use devices are platform
decisions.

Permission to begin capture may be given on a case-by-case basis, or be
persistent. In the case of a case-by-case permission, it is important
that the user be able to say \"no\" in a way that prevents the UI from
blocking user interaction until permission is given - either by offering
a way to say a \"persistent NO\" or by not using a modal permissions
dialog.

Once capture of camera or microphone has begun, the web document gains
the ability to list all available media capture devices and their
labels. This ability lasts until the web document is closed, and cannot
be persisted. In most cases, the labels are stable across origins, and
thus potentially provide a way to track a given device across time and
origins.

This specification exposes device information of devices other than
those in use. This is for backwards compatibility and legacy reasons.
Future specifications are advised to not use this model and instead
follow best practices as described in the [device enumeration design
principles](https://w3ctag.github.io/design-principles/#device-enumeration).

For open web documents where capture has begun or has taken place, or
for web documents that \[=Document/is in view\|are in view=\], the
[devicechange]{link-type="event"} event can end up being fired at the
same time across \[=navigables=\] and origins each time a new media
device is added or removed; user agents can mitigate the risk of
correlation of browsing activity across origins by fuzzing the timing of
these events, or by deferring their firing until those web documents
\[=Document/is in view \| come into view=\].

Once a web document gains access to a media stream from a capture
device, it also gains access to detailed information about the device,
including its range of operating capabilities (e.g. available
resolutions for a camera). These operating capabilities are for the most
part persistent across browsing sessions and origins, and thus provide a
way to track a given device across time and origins.

Once access to a video stream from a capture device is obtained, that
stream can most likely be used to fingerprint uniquely the said device
(e.g. via dead pixel detection). Similarly, once access to an audio
stream is obtained, that stream can most likely be used to fingerprint
user location down to the level of a room or even simultaneous
occupation of a room by disparate users (e.g. via analysis of ambient
audio or of unique audio purposely played out of the device speaker).
User-level mitigation for both audio and video consists of covering up
the camera and/or microphone or revoking permission via \[=User Agent=\]
chrome controls.

It is possible to use constraints so that the failure of a getUserMedia
call will return information about devices on the system without
prompting the user, which increases the surface available for
fingerprinting. The \[=User Agent=\] should consider limiting the rate
at which failed getUserMedia calls are allowed in order to limit this
additional surface.

In the case of a stored persistent permission to begin capture, it is
important that it is easy to find the list of granted permissions and
revoke permissions that the user wishes to revoke.

Once permission has been granted, the \[=User Agent=\] should make two
things readily apparent to the user:

- That the page has access to the devices for which permission is given
- Whether or not any of the devices are presently recording (\"on air\")
  indicator

::: note
Developers of sites with stored permissions should be careful that these
permissions not be abused. These permissions can be revoked using the
\[\[permissions\]\] API.

In particular, they should not make it possible to automatically send
audio or video streams from authorized media devices to an end point
that a third party can select.

Indeed, if a site offered URLs such as
`https://webrtc.example.org/?call=``user`{.variable} that would
automatically set up calls and transmit audio/video to
`user`{.variable}, it would be open for instance to the following abuse:

Users who have granted stored permissions to
`https://webrtc.example.org/` could be tricked to send their audio/video
streams to an attacker `EvilSpy` by following a link or being redirected
to `https://webrtc.example.org/?user=EvilSpy`.
:::
::::

::::::: {.section .informative}
## Extensibility

Although new versions of this specification may be produced in the
future, it is also expected that other standards will need to define new
capabilities that build upon those in this specification. The purpose of
this section is to provide guidance to creators of such extensions.

Any WebIDL-defined interfaces, methods, or attributes in the
specification may be extended. Two likely extension points are defining
a new media type and defining a new constrainable property.

::: section
## Defining a new {{MediaStreamTrack/kind}} of media (beyond audio and video)

At a minimum, defining a new media type would require

- adding a new getXXXXTracks() method for the type to the
  {{MediaStream}} interface,
- describing what a muted or disabled track of that type will render
  (see \[\[\[#media-flow-and-life-cycle\]\]\]),
- adding the new type as an additional valid value for the
  {{MediaStreamTrack/kind}} attribute on the {{MediaStreamTrack}}
  interface,
- defining any constrainable properties (see
  [](#constrainable-properties)) that are applicable to the media type
  for each source,
- updating how the {{HTMLMediaElement}} works with a {{MediaStream}}
  containing a track of the new media type (see
  [](#mediastreams-in-media-elements)), including adding a corollary to
  \[= stream/audible =\]/inaudible for the new media type,
- updating {{MediaDeviceKind}} if the new type has enumerable devices,
- updating the {{MediaStreamTrack/getCapabilities()}} and
  {{MediaDevices/getUserMedia()}} descriptions,
- adding the new type to the {{MediaStreamConstraints}} dictionary,
- describing any new security and/or privacy considerations (see
  [](#privacy-and-security-considerations)) introduced by the new type,
  and
- if the new type requires user authorization, defining new permissions
  for it, including a new PermissionDescriptor name associated with the
  new {{MediaStreamTrack/kind}}, and defining how these permissions,
  along with access starting and ending, as well as muting/disabling,
  affect any new and/or existing \"on-air\" and \"device accessible\"
  indicator states (see [MediaDevices](#mediadevices)).

Additionally, it should include updating

- the source definition,
- the list of media stream consumers,
- the description of the {{MediaStreamTrack/label}} attribute on the
  {{MediaStreamTrack}} interface,
- the list of sinks (see
  \[\[\[#the-model-sources-sinks-constraints-and-settings\]\]\]), and
- the best practice statements referring to video and audio (see
  [](#implementation-suggestions)).

It might also include

- explaining how the media is expected to be used by potential
  consumers, and
- giving examples in {{MediaStreamTrackState}} of how such a track might
  become ended.
:::

::: section
## Defining a new constrainable property

This will require thinking through and defining how Constraints,
Capabilities, and Settings for the property (see [](#terminology)) will
work. The relevant text in {{MediaTrackSupportedConstraints}},
{{MediaTrackCapabilities}}, {{MediaTrackConstraints}},
{{MediaTrackSettings}}, [](#constrainable-properties), and
{{MediaStreamConstraints}} are the model to use.

Creators of extension specifications are strongly encouraged to notify
the specification maintainers on [the specification
repository](https://github.com/w3c/mediacapture-main/issues).\
Future versions of this specification and others created by the WebRTC
Working Group will take into consideration all extensions they are aware
of in an attempt to reduce potential usage conflicts.
:::

::: section
## Defining a new sink for {{MediaStreamTrack}} and {{MediaStream}}

Other specs can define new sinks for {{MediaStream}} and/or
{{MediaStreamTrack}}. At a minimum, a new consumer of a
{{MediaStreamTrack}} will need to define:

- how a {{MediaStreamTrack}} will be consumed in the various states in
  which it can be, including muted and disabled (see
  \[\[\[#media-flow-and-life-cycle\]\]\]).
:::

::: section
## Defining a new source of {{MediaStreamTrack}}

Other specs can define new sources of {{MediaStreamTrack}}. At a
minimum, a new source of {{MediaStreamTrack}} will need to

- define a new API to \[=create a MediaStreamTrack=\] of the relevant
  {{MediaStreamTrack/kind}}s from this new source
  ({{MediaDevices/getUserMedia()}} is dedicated to camera and microphone
  sources),
- declare which constrainable properties (see
  [](#constrainable-properties)), if any, are applicable to each
  {{MediaStreamTrack/kind}} of media this new source produces, and how
  they work with this source,
- describe how and when to \[=MediaStreamTrack/set a track\'s muted
  state=\] for this source,
- describe how and when to [end](#ends-nostop) tracks from this source,
- if capture of the source is a \[=powerful feature=\] requiring
  \[=express permission=\], describe its [permissions
  integration](#permissions-integration) and [permissions policy
  integration](#permissions-policy-integration),
- if capture of the source poses a privacy concern, describe its
  [privacy indicator requirements](#privacy-indicator-requirements).
:::
:::::::

::: {.section .appendix}
## Acknowledgements

The editors wish to thank the Working Group chairs and Team Contact,
Harald Alvestrand, Stefan Håkansson, Erik Lagerway and Dominique
Hazaël-Massieux, for their support. Substantial text in this
specification was provided by many people including Jim Barnett, Harald
Alvestrand, Travis Leithead, Josh Soref, Martin Thomson, Jan-Ivar
Bruaroey, Peter Thatcher, Dominique Hazaël-Massieux, and Stefan
Håkansson. Dan Burnett would like to acknowledge the significant support
received from Voxeo and Aspect during the development of this
specification.
:::
