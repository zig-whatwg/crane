## 1. Definitions

[Codec]

: Refers generically to an instance of
 [`AudioDecoder`](#audiodecoder),
 [`AudioEncoder`](#audioencoder),
 [`VideoDecoder`](#videodecoder), or
 [`VideoEncoder`](#videoencoder).

[Key Chunk]

: An encoded chunk that does not depend on any other frames for
 decoding. Also commonly referred to as a \"key frame\".

[Internal Pending Output]

: Codec outputs such as
 [`VideoFrame`](#videoframe)s that currently reside in the internal pipeline of
 the underlying codec implementation. The underlying codec
 implementation *MAY* emit new outputs only when new inputs are
 provided. The underlying codec implementation *MUST* emit all
 outputs in response to a flush.

[Codec System Resources]

: Resources including CPU memory, GPU memory, and exclusive handles to
 specific decoding/encoding hardware that *MAY* be allocated by the
 User Agent as part of codec configuration or generation of
 [`AudioData`](#audiodata)
 and [`VideoFrame`](#videoframe) objects. Such resources *MAY* be quickly exhausted
 and *SHOULD* be released immediately when no longer in use.

[Temporal Layer]

: A grouping of
 [`EncodedVideoChunk`](#encodedvideochunk)s whose timestamp cadence produces a particular
 framerate. See
 [`scalabilityMode`](#dom-videoencoderconfig-scalabilitymode).

[Progressive Image]

: An image that supports decoding to multiple levels of detail, with
 lower levels becoming available while the encoded data is not yet
 fully buffered.

[Progressive Image Frame Generation]

: A generational identifier for a given [Progressive
 Image](#progressive-image) decoded output. Each successive generation adds
 additional detail to the decoded output. The mechanism for computing
 a frame's generation is implementer defined.

[Primary Image Track]

: An image track that is marked by the given image file as being the
 default track. The mechanism for indicating a primary track is
 format defined.

[RGB Format]

: A
 [`VideoPixelFormat`](#enumdef-videopixelformat) containing red, green, and blue color channels in
 any order or layout (interleaved or planar), and irrespective of
 whether an alpha channel is present.

[sRGB Color Space]

: A
 [`VideoColorSpace`](#videocolorspace) object, initialized as follows:

 1. [`[[primaries]]`](#dom-videocolorspace-primaries-slot) is set to
 [`bt709`](#dom-videocolorprimaries-bt709),

 2. [`[[transfer]]`](#dom-videocolorspace-transfer-slot) is set to
 [`iec61966-2-1`](#dom-videotransfercharacteristics-iec61966-2-1),

 3. [`[[matrix]]`](#dom-videocolorspace-matrix-slot) is set to
 [`rgb`](#dom-videomatrixcoefficients-rgb),

 4. [`[[full range]]`](#dom-videocolorspace-full-range-slot) is set to `true`

[Display P3 Color Space]

: A
 [`VideoColorSpace`](#videocolorspace) object, initialized as follows:

 1. [`[[primaries]]`](#dom-videocolorspace-primaries-slot) is set to
 [`smpte432`](#dom-videocolorprimaries-smpte432),

 2. [`[[transfer]]`](#dom-videocolorspace-transfer-slot) is set to
 [`iec61966-2-1`](#dom-videotransfercharacteristics-iec61966-2-1),

 3. [`[[matrix]]`](#dom-videocolorspace-matrix-slot) is set to
 [`rgb`](#dom-videomatrixcoefficients-rgb),

 4. [`[[full range]]`](#dom-videocolorspace-full-range-slot) is set to `true`

[REC709 Color Space]

: A
 [`VideoColorSpace`](#videocolorspace) object, initialized as follows:

 1. [`[[primaries]]`](#dom-videocolorspace-primaries-slot) is set to
 [`bt709`](#dom-videocolorprimaries-bt709),

 2. [`[[transfer]]`](#dom-videocolorspace-transfer-slot) is set to
 [`bt709`](#dom-videotransfercharacteristics-bt709),

 3. [`[[matrix]]`](#dom-videocolorspace-matrix-slot) is set to
 [`bt709`](#dom-videomatrixcoefficients-bt709),

 4. [`[[full range]]`](#dom-videocolorspace-full-range-slot) is set to `false`

[Codec Saturation]

: The state of an underlying codec implementation where the number of
 active decoding or encoding requests has reached an implementation
 specific maximum such that it is temporarily unable to accept more
 work. The maximum may be any value greater than 1, including
 infinity (no maximum). While saturated, additional calls to
 `decode()` or `encode()` will be buffered in the [control message
 queue](#control-message-queue), and will increment the respective
 `decodeQueueSize` and `encodeQueueSize` attributes. The codec
 implementation will become unsaturated after making sufficient
 progress on the current workload.

## [2. ][[Codec Processing Model]]
### 2.1. Background

::: non-normative
This section is non-normative.

The codec interfaces defined by the specification are designed such that
new codec tasks can be scheduled while previous tasks are still pending.
For example, web authors can call `decode()` without waiting for a
previous `decode()` to complete. This is achieved by offloading
underlying codec tasks to a separate [parallel
queue](https://html.spec.whatwg.org/multipage/infrastructure.html#parallel-queue) for parallel execution.

This section describes threading behaviors as they are visible from the
perspective of web authors. Implementers can choose to use more threads,
as long as the externally visible behaviors of blocking and sequencing
are maintained as follows.

### 2.2. Control Messages

A [control message] defines a sequence of steps corresponding to a method
invocation on a [codec](#codec) instance
(e.g. `encode()`).

A [control message queue] is a
[queue](https://infra.spec.whatwg.org/#queue) of [control
messages](#control-message).
Each [codec](#codec) instance has a
control message queue stored in an internal slot named [\[\[control
message queue\]\]].

[Queuing a control message]
means
[enqueuing](https://infra.spec.whatwg.org/#queue-enqueue) the message to a [codec](#codec)'s [\[\[control message
queue\]\]](#control-message-queue-slot). Invoking codec methods will generally queue a control
message to schedule work.

[Running a control message] means performing a sequence of steps specified by the
method that enqueued the message.

The steps of a given control message can block processing later messages
in the control message queue. Each [codec](#codec) instance has a boolean internal slot named [\[\[message
queue blocked\]\]] that is set to `true` when this occurs. A
blocking message will conclude by setting [\[\[message queue
blocked\]\]](#message-queue-blocked) to `false` and rerunning the [Process the control
message
queue](#process-the-control-message-queue) steps.

All control messages will return either `"processed"` or
`"not processed"`. Returning `"processed"` indicates the message steps
are being (or have been) executed and the message may be removed from
the [control message
queue](#control-message-queue). `"not processed"` indicates the message must not be
processed at this time and should remain in the [control message
queue](#control-message-queue) to be retried later.

To [Process the control message
queue], run these steps:

1. While [\[\[message queue
 blocked\]\]](#message-queue-blocked) is `false` and [\[\[control message
 queue\]\]](#control-message-queue-slot) is not empty:

 1. Let `front message` be the first message in
 [\[\[control message
 queue\]\]](#control-message-queue-slot).

 2. Let `outcome` be the result of running the [control
 message
 steps](#running-a-control-message) described by `front message`.

 3. If `outcome` equals `"not processed"`, break.

 4. Otherwise, dequeue `front message` from the
 [\[\[control message
 queue\]\]](#control-message-queue-slot).

### 2.3. Codec Work Parallel Queue

Each [codec](#codec) instance has an
internal slot named [\[\[codec work queue\]\]] that is a [parallel
queue](https://html.spec.whatwg.org/multipage/infrastructure.html#parallel-queue).

Each [codec](#codec) instance has an
internal slot named [\[\[codec implementation\]\]] that refers to the
underlying platform encoder or decoder. Except for the initial
assignment, any steps that reference [\[\[codec
implementation\]\]](#codec-implementation) will be enqueued to the [\[\[codec work
queue\]\]](#codec-work-queue).

Each [codec](#codec) instance has a
unique [codec task source]. Tasks
[queued](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) from the [\[\[codec work
queue\]\]](#codec-work-queue) to the [event
loop](https://html.spec.whatwg.org/multipage/webappapis.html#event-loop) will use the [codec task
source](#codec-task-source).

## 3. AudioDecoder Interface

```
[Exposed=(Window,DedicatedWorker), SecureContext]
interface AudioDecoder : EventTarget {
 constructor(AudioDecoderInit init);

 readonly attribute CodecState state;
 readonly attribute unsigned long decodeQueueSize;
 attribute EventHandler ondequeue;

 undefined configure(AudioDecoderConfig config);
 undefined decode(EncodedAudioChunk chunk);
 Promise<undefined> flush();
 undefined reset();
 undefined close();

 static Promise<AudioDecoderSupport> isConfigSupported(AudioDecoderConfig config);
};

dictionary AudioDecoderInit {
 required AudioDataOutputCallback output;
 required WebCodecsErrorCallback error;
};

callback AudioDataOutputCallback = undefined(AudioData output);
```

### 3.1. Internal Slots

[`[[control message queue]]`]

: A [queue](https://infra.spec.whatwg.org/#queue) of [control
 messages](#control-message) to be performed upon this
 [codec](#codec) instance. See
 [\[\[control message
 queue\]\]](#control-message-queue-slot).

[`[[message queue blocked]]`]

: A boolean indicating when processing the
 [`[[control message queue]]`](#dom-audiodecoder-control-message-queue-slot) is blocked by a pending [control
 message](#control-message). See [\[\[message queue
 blocked\]\]](#message-queue-blocked).

[`[[codec implementation]]`]

: Underlying decoder implementation provided by the User Agent. See
 [\[\[codec
 implementation\]\]](#codec-implementation).

[`[[codec work queue]]`]

: A [parallel
 queue](https://html.spec.whatwg.org/multipage/infrastructure.html#parallel-queue) used for running parallel steps that reference the
 [`[[codec implementation]]`](#dom-audiodecoder-codec-implementation-slot). See [\[\[codec work
 queue\]\]](#codec-work-queue).

[`[[codec saturated]]`]

: A boolean indicating when the
 [`[[codec implementation]]`](#dom-audiodecoder-codec-implementation-slot) is unable to accept additional decoding work.

[`[[output callback]]`]

: Callback given at construction for decoded outputs.

[`[[error callback]]`]

: Callback given at construction for decode errors.

[`[[key chunk required]]`]

: A boolean indicating that the next chunk passed to
 [`decode()`](#dom-audiodecoder-decode) *MUST* describe a [key
 chunk](#key-chunk) as indicated
 by
 [`[[type]]`](#dom-encodedaudiochunk-type-slot).

[`[[state]]`]

: The current
 [`CodecState`](#enumdef-codecstate) of this
 [`AudioDecoder`](#audiodecoder).

[`[[decodeQueueSize]]`]

: The number of pending decode requests. This number will decrease as
 the underlying codec is ready to accept new input.

[`[[pending flush promises]]`]

: A list of unresolved promises returned by calls to
 [`flush()`](#dom-audiodecoder-flush).

[`[[dequeue event scheduled]]`]

: A boolean indicating whether a
 [`dequeue`](#eventdef-audiodecoder-dequeue) event is already scheduled to fire. Used to avoid
 event spam.

### 3.2. Constructors

[` AudioDecoder(init) `]

1. Let d be a new
 [`AudioDecoder`](#audiodecoder) object.

2. Assign a new
 [queue](https://infra.spec.whatwg.org/#queue) to
 [`[[control message queue]]`](#dom-audiodecoder-control-message-queue-slot).

3. Assign `false` to
 [`[[message queue blocked]]`](#dom-audiodecoder-message-queue-blocked-slot).

4. Assign `null` to
 [`[[codec implementation]]`](#dom-audiodecoder-codec-implementation-slot).

5. Assign the result of starting a new [parallel
 queue](https://html.spec.whatwg.org/multipage/infrastructure.html#parallel-queue) to
 [`[[codec work queue]]`](#dom-audiodecoder-codec-work-queue-slot).

6. Assign `false` to
 [`[[codec saturated]]`](#dom-audiodecoder-codec-saturated-slot).

7. Assign init.output to
 [`[[output callback]]`](#dom-audiodecoder-output-callback-slot).

8. Assign init.error to
 [`[[error callback]]`](#dom-audiodecoder-error-callback-slot).

9. Assign `true` to
 [`[[key chunk required]]`](#dom-audiodecoder-key-chunk-required-slot).

10. Assign `"unconfigured"` to
 [`[[state]]`](#dom-audiodecoder-state-slot)

11. Assign `0` to
 [`[[decodeQueueSize]]`](#dom-audiodecoder-decodequeuesize-slot).

12. Assign a new
 [list](https://infra.spec.whatwg.org/#list) to
 [`[[pending flush promises]]`](#dom-audiodecoder-pending-flush-promises-slot).

13. Assign `false` to
 [`[[dequeue event scheduled]]`](#dom-audiodecoder-dequeue-event-scheduled-slot).

14. Return d.

### 3.3. Attributes

[`state`], of type [CodecState](#enumdef-codecstate), readonly

: Returns the value of
 [`[[state]]`](#dom-audiodecoder-state-slot).

[`decodeQueueSize`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: Returns the value of
 [`[[decodeQueueSize]]`](#dom-audiodecoder-decodequeuesize-slot).

[`ondequeue`], of type [EventHandler](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler)

: An [event handler IDL
 attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes) whose [event handler event
 type](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type) is
 [`dequeue`](#eventdef-audiodecoder-dequeue).

### 3.4. Event Summary

[`dequeue`]

: Fired at the
 [`AudioDecoder`](#audiodecoder) when the
 [`decodeQueueSize`](#dom-audiodecoder-decodequeuesize) has decreased.

### 3.5. Methods

[`configure(config)`]

: [Enqueues a control
 message](#enqueues-a-control-message) to configure the audio decoder for decoding chunks
 as described by `config`.

 [NOTE:] This method will trigger a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) if the User Agent does not support
 `config`. Authors are encouraged to first check support
 by calling
 [`isConfigSupported()`](#dom-audiodecoder-isconfigsupported) with `config`. User Agents don't have to
 support any particular codec type or configuration.

 When invoked, run these steps:

 1. If `config` is not a [valid
 AudioDecoderConfig](#valid-audiodecoderconfig), throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 2. If
 [`[[state]]`](#dom-audiodecoder-state-slot) is `“closed”`, throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror).

 3. Set
 [`[[state]]`](#dom-audiodecoder-state-slot) to `"configured"`.

 4. Set
 [`[[key chunk required]]`](#dom-audiodecoder-key-chunk-required-slot) to `true`.

 5. [Queue a control
 message](#enqueues-a-control-message) to configure the decoder with
 `config`.

 6. [Process the control message
 queue](#process-the-control-message-queue).

 [Running a control
 message](#running-a-control-message) to configure the decoder means running these steps:

 1. Assign `true` to
 [`[[message queue blocked]]`](#dom-audiodecoder-message-queue-blocked-slot).

 2. Enqueue the following steps to
 [`[[codec work queue]]`](#dom-audiodecoder-codec-work-queue-slot):

 1. Let `supported` be the result of running the
 [Check Configuration
 Support](#check-configuration-support) algorithm with `config`.

 2. If `supported` is `false`, [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the [Close
 AudioDecoder](#close-audiodecoder) algorithm with
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) and abort these steps.

 3. If needed, assign
 [`[[codec implementation]]`](#dom-audiodecoder-codec-implementation-slot) with an implementation supporting
 `config`.

 4. Configure
 [`[[codec implementation]]`](#dom-audiodecoder-codec-implementation-slot) with `config`.

 5. [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the following steps:

 1. Assign `false` to
 [`[[message queue blocked]]`](#dom-audiodecoder-message-queue-blocked-slot).

 2. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to [Process the control message
 queue](#process-the-control-message-queue).

 3. Return `"processed"`.

[`decode(chunk)`]

: [Enqueues a control
 message](#enqueues-a-control-message) to decode the given `chunk`.

 When invoked, run these steps:

 1. If
 [`[[state]]`](#dom-audiodecoder-state-slot) is not `"configured"`, throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror).

 2. If
 [`[[key chunk required]]`](#dom-audiodecoder-key-chunk-required-slot) is `true`:

 1. If
 `chunk`.[`[[type]]`](#dom-encodedaudiochunk-type-slot) is not
 [`key`](#dom-encodedaudiochunktype-key), throw a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. Implementers *SHOULD* inspect the `chunk`'s
 [`[[internal data]]`](#dom-encodedaudiochunk-internal-data-slot) to verify that it is truly a [key
 chunk](#key-chunk). If
 a mismatch is detected, throw a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 3. Otherwise, assign `false` to
 [`[[key chunk required]]`](#dom-audiodecoder-key-chunk-required-slot).

 3. Increment
 [`[[decodeQueueSize]]`](#dom-audiodecoder-decodequeuesize-slot).

 4. [Queue a control
 message](#enqueues-a-control-message) to decode the `chunk`.

 5. [Process the control message
 queue](#process-the-control-message-queue).

 [Running a control
 message](#running-a-control-message) to decode the chunk means performing these steps:

 1. If
 [`[[codec saturated]]`](#dom-audiodecoder-codec-saturated-slot) equals `true`, return `"not processed"`.

 2. If decoding chunk will cause the
 [`[[codec implementation]]`](#dom-audiodecoder-codec-implementation-slot) to become
 [saturated](#saturated),
 assign `true` to
 [`[[codec saturated]]`](#dom-audiodecoder-codec-saturated-slot).

 3. Decrement
 [`[[decodeQueueSize]]`](#dom-audiodecoder-decodequeuesize-slot) and run the [Schedule Dequeue
 Event](#audiodecoder-schedule-dequeue-event) algorithm.

 4. Enqueue the following steps to the
 [`[[codec work queue]]`](#dom-audiodecoder-codec-work-queue-slot):

 1. Attempt to use
 [`[[codec implementation]]`](#dom-audiodecoder-codec-implementation-slot) to decode the chunk.

 2. If decoding results in an error, [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the [Close
 AudioDecoder](#close-audiodecoder) algorithm with
 [`EncodingError`](https://webidl.spec.whatwg.org/#encodingerror) and return.

 3. If
 [`[[codec saturated]]`](#dom-audiodecoder-codec-saturated-slot) equals `true` and
 [`[[codec implementation]]`](#dom-audiodecoder-codec-implementation-slot) is no longer
 [saturated](#saturated), [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to perform the following steps:

 1. Assign `false` to
 [`[[codec saturated]]`](#dom-audiodecoder-codec-saturated-slot).

 2. [Process the control message
 queue](#process-the-control-message-queue).

 4. Let `decoded outputs` be a
 [list](https://infra.spec.whatwg.org/#list) of decoded audio data outputs emitted by
 [`[[codec implementation]]`](#dom-audiodecoder-codec-implementation-slot).

 5. If `decoded outputs` is not empty, [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the [Output
 AudioData](#output-audiodata) algorithm with
 `decoded outputs`.

 5. Return `"processed"`.

[`flush()`]

: Completes all [control
 messages](#control-message) in the [control message
 queue](#control-message-queue) and emits all outputs.

 When invoked, run these steps:

 1. If
 [`[[state]]`](#dom-audiodecoder-state-slot) is not `"configured"`, return [a promise
 rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with)
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. Set
 [`[[key chunk required]]`](#dom-audiodecoder-key-chunk-required-slot) to `true`.

 3. Let `promise` be a new Promise.

 4. Append `promise` to
 [`[[pending flush promises]]`](#dom-audiodecoder-pending-flush-promises-slot).

 5. [Queue a control
 message](#enqueues-a-control-message) to flush the codec with `promise`.

 6. [Process the control message
 queue](#process-the-control-message-queue).

 7. Return `promise`.

 [Running a control
 message](#running-a-control-message) to flush the codec means performing these steps
 with `promise`.

 1. Enqueue the following steps to the
 [`[[codec work queue]]`](#dom-audiodecoder-codec-work-queue-slot):

 1. Signal
 [`[[codec implementation]]`](#dom-audiodecoder-codec-implementation-slot) to emit all [internal pending
 outputs](#internal-pending-output).

 2. Let `decoded outputs` be a
 [list](https://infra.spec.whatwg.org/#list) of decoded audio data outputs emitted by
 [`[[codec implementation]]`](#dom-audiodecoder-codec-implementation-slot).

 3. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to perform these steps:

 1. If `decoded outputs` is not empty, run the
 [Output
 AudioData](#output-audiodata) algorithm with
 `decoded outputs`.

 2. Remove `promise` from
 [`[[pending flush promises]]`](#dom-audiodecoder-pending-flush-promises-slot).

 3. Resolve `promise`.

 2. Return `"processed"`.

[`reset()`]

: Immediately resets all state including configuration, [control
 messages](#control-message) in the [control message
 queue](#control-message-queue), and all pending callbacks.

 When invoked, run the [Reset
 AudioDecoder](#reset-audiodecoder) algorithm with an
 [`AbortError`](https://webidl.spec.whatwg.org/#aborterror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

[`close()`]

: Immediately aborts all pending work and releases [system
 resources](#system-resources). Close is final.

 When invoked, run the [Close
 AudioDecoder](#close-audiodecoder) algorithm with an
 [`AbortError`](https://webidl.spec.whatwg.org/#aborterror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

[`isConfigSupported(config)`]

: Returns a promise indicating whether the provided
 `config` is supported by the User Agent.

 [NOTE:] The returned
 [`AudioDecoderSupport`](#dictdef-audiodecodersupport)
 [`config`](#dom-audiodecodersupport-config) will contain only the dictionary members that User
 Agent recognized. Unrecognized dictionary members will be ignored.
 Authors can detect unrecognized dictionary members by comparing
 [`config`](#dom-audiodecodersupport-config) to their provided `config`.

 When invoked, run these steps:

 1. If `config` is not a [valid
 AudioDecoderConfig](#valid-audiodecoderconfig), return [a promise rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with)
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 2. Let `p` be a new Promise.

 3. Let `checkSupportQueue` be the result of starting a
 new [parallel
 queue](https://html.spec.whatwg.org/multipage/infrastructure.html#parallel-queue).

 4. Enqueue the following steps to `checkSupportQueue`:

 1. Let `supported` be the result of running the
 [Check Configuration
 Support](#check-configuration-support) algorithm with `config`.

 2. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the following steps:

 1. Let `decoderSupport` be a newly constructed
 [`AudioDecoderSupport`](#dictdef-audiodecodersupport), initialized as follows:

 1. Set
 [`config`](#dom-audiodecodersupport-config) to the result of running the [Clone
 Configuration](#clone-configuration) algorithm with `config`.

 2. Set
 [`supported`](#dom-audiodecodersupport-supported) to `supported`.

 2. Resolve `p` with `decoderSupport`.

 5. Return `p`.

### 3.6. Algorithms

[Schedule Dequeue Event]

: 1. If
 [`[[dequeue event scheduled]]`](#dom-audiodecoder-dequeue-event-scheduled-slot) equals `true`, return.

 2. Assign `true` to
 [`[[dequeue event scheduled]]`](#dom-audiodecoder-dequeue-event-scheduled-slot).

 3. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the following steps:

 1. Fire a simple event named
 [`dequeue`](#eventdef-audiodecoder-dequeue) at
 [this](https://webidl.spec.whatwg.org/#this).

 2. Assign `false` to
 [`[[dequeue event scheduled]]`](#dom-audiodecoder-dequeue-event-scheduled-slot).

[Output AudioData] (with `outputs`)
: Run these steps:
 1. For each `output` in `outputs`:

 1. Let `data` be an
 [`AudioData`](#audiodata), initialized as follows:

 1. Assign `false` to
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached).

 2. Let `resource` be the [media
 resource](#media-resource) described by `output`.

 3. Let `resourceReference` be a reference to
 `resource`.

 4. Assign `resourceReference` to
 [`[[resource reference]]`](#dom-audiodata-resource-reference-slot).

 5. Let `timestamp` be the
 [`[[timestamp]]`](#dom-encodedaudiochunk-timestamp-slot) of the
 [`EncodedAudioChunk`](#encodedaudiochunk) associated with `output`.

 6. Assign `timestamp` to
 [`[[timestamp]]`](#dom-audiodata-timestamp-slot).

 7. If `output` uses a recognized
 [`AudioSampleFormat`](#enumdef-audiosampleformat), assign that format to
 [`[[format]]`](#dom-audiodata-format-slot). Otherwise, assign `null` to
 [`[[format]]`](#dom-audiodata-format-slot).

 8. Assign values to
 [`[[sample rate]]`](#dom-audiodata-sample-rate-slot),
 [`[[number of frames]]`](#dom-audiodata-number-of-frames-slot), and
 [`[[number of channels]]`](#dom-audiodata-number-of-channels-slot) as determined by `output`.

 2. Invoke
 [`[[output callback]]`](#dom-audiodecoder-output-callback-slot) with `data`.

[Reset AudioDecoder] (with `exception`)
: Run these steps:
 1. If
 [`[[state]]`](#dom-audiodecoder-state-slot) is `"closed"`, throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror).

 2. Set
 [`[[state]]`](#dom-audiodecoder-state-slot) to `"unconfigured"`.

 3. Signal
 [`[[codec implementation]]`](#dom-audiodecoder-codec-implementation-slot) to cease producing output for the previous
 configuration.

 4. Remove all [control
 messages](#control-message) from the
 [`[[control message queue]]`](#dom-audiodecoder-control-message-queue-slot).

 5. If
 [`[[decodeQueueSize]]`](#dom-audiodecoder-decodequeuesize-slot) is greater than zero:

 1. Set
 [`[[decodeQueueSize]]`](#dom-audiodecoder-decodequeuesize-slot) to zero.

 2. Run the [Schedule Dequeue
 Event](#audiodecoder-schedule-dequeue-event) algorithm.

 6. For each `promise` in
 [`[[pending flush promises]]`](#dom-audiodecoder-pending-flush-promises-slot):

 1. Reject `promise` with `exception`.

 2. Remove `promise` from
 [`[[pending flush promises]]`](#dom-audiodecoder-pending-flush-promises-slot).

[Close AudioDecoder] (with `exception`)
: Run these steps:
 1. Run the [Reset
 AudioDecoder](#reset-audiodecoder) algorithm with `exception`.

 2. Set
 [`[[state]]`](#dom-audiodecoder-state-slot) to `"closed"`.

 3. Clear
 [`[[codec implementation]]`](#dom-audiodecoder-codec-implementation-slot) and release associated [system
 resources](#system-resources).

 4. If `exception` is not an
 [`AbortError`](https://webidl.spec.whatwg.org/#aborterror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException), invoke the
 [`[[error callback]]`](#dom-audiodecoder-error-callback-slot) with `exception`.

## 4. VideoDecoder Interface

```
[Exposed=(Window,DedicatedWorker), SecureContext]
interface VideoDecoder : EventTarget {
 constructor(VideoDecoderInit init);

 readonly attribute CodecState state;
 readonly attribute unsigned long decodeQueueSize;
 attribute EventHandler ondequeue;

 undefined configure(VideoDecoderConfig config);
 undefined decode(EncodedVideoChunk chunk);
 Promise<undefined> flush();
 undefined reset();
 undefined close();

 static Promise<VideoDecoderSupport> isConfigSupported(VideoDecoderConfig config);
};

dictionary VideoDecoderInit {
 required VideoFrameOutputCallback output;
 required WebCodecsErrorCallback error;
};

callback VideoFrameOutputCallback = undefined(VideoFrame output);
```

### 4.1. Internal Slots

[`[[control message queue]]`]

: A [queue](https://infra.spec.whatwg.org/#queue) of [control
 messages](#control-message) to be performed upon this
 [codec](#codec) instance. See
 [\[\[control message
 queue\]\]](#control-message-queue-slot).

[`[[message queue blocked]]`]

: A boolean indicating when processing the
 [`[[control message queue]]`](#dom-videodecoder-control-message-queue-slot) is blocked by a pending [control
 message](#control-message). See [\[\[message queue
 blocked\]\]](#message-queue-blocked).

[`[[codec implementation]]`]

: Underlying decoder implementation provided by the User Agent. See
 [\[\[codec
 implementation\]\]](#codec-implementation).

[`[[codec work queue]]`]

: A [parallel
 queue](https://html.spec.whatwg.org/multipage/infrastructure.html#parallel-queue) used for running parallel steps that reference the
 [`[[codec implementation]]`](#dom-videodecoder-codec-implementation-slot). See [\[\[codec work
 queue\]\]](#codec-work-queue).

[`[[codec saturated]]`]

: A boolean indicating when the
 [`[[codec implementation]]`](#dom-videodecoder-codec-implementation-slot) is unable to accept additional decoding work.

[`[[output callback]]`]

: Callback given at construction for decoded outputs.

[`[[error callback]]`]

: Callback given at construction for decode errors.

[`[[active decoder config]]`]

: The
 [`VideoDecoderConfig`](#dictdef-videodecoderconfig) that is actively applied.

[`[[key chunk required]]`]

: A boolean indicating that the next chunk passed to
 [`decode()`](#dom-videodecoder-decode) *MUST* describe a [key
 chunk](#key-chunk) as indicated
 by
 [`type`](#dom-encodedvideochunk-type).

[`[[state]]`]

: The current
 [`CodecState`](#enumdef-codecstate) of this
 [`VideoDecoder`](#videodecoder).

[`[[decodeQueueSize]]`]

: The number of pending decode requests. This number will decrease as
 the underlying codec is ready to accept new input.

[`[[pending flush promises]]`]

: A list of unresolved promises returned by calls to
 [`flush()`](#dom-videodecoder-flush).

[`[[dequeue event scheduled]]`]

: A boolean indicating whether a
 [`dequeue`](#eventdef-videodecoder-dequeue) event is already scheduled to fire. Used to avoid
 event spam.

### 4.2. Constructors

[` VideoDecoder(init) `]

1. Let d be a new
 [`VideoDecoder`](#videodecoder) object.

2. Assign a new
 [queue](https://infra.spec.whatwg.org/#queue) to
 [`[[control message queue]]`](#dom-videodecoder-control-message-queue-slot).

3. Assign `false` to
 [`[[message queue blocked]]`](#dom-videodecoder-message-queue-blocked-slot).

4. Assign `null` to
 [`[[codec implementation]]`](#dom-videodecoder-codec-implementation-slot).

5. Assign the result of starting a new [parallel
 queue](https://html.spec.whatwg.org/multipage/infrastructure.html#parallel-queue) to
 [`[[codec work queue]]`](#dom-videodecoder-codec-work-queue-slot).

6. Assign `false` to
 [`[[codec saturated]]`](#dom-videodecoder-codec-saturated-slot).

7. Assign init.output to
 [`[[output callback]]`](#dom-videodecoder-output-callback-slot).

8. Assign init.error to
 [`[[error callback]]`](#dom-videodecoder-error-callback-slot).

9. Assign `null` to
 [`[[active decoder config]]`](#dom-videodecoder-active-decoder-config-slot).

10. Assign `true` to
 [`[[key chunk required]]`](#dom-videodecoder-key-chunk-required-slot).

11. Assign `"unconfigured"` to
 [`[[state]]`](#dom-videodecoder-state-slot)

12. Assign `0` to
 [`[[decodeQueueSize]]`](#dom-videodecoder-decodequeuesize-slot).

13. Assign a new
 [list](https://infra.spec.whatwg.org/#list) to
 [`[[pending flush promises]]`](#dom-videodecoder-pending-flush-promises-slot).

14. Assign `false` to
 [`[[dequeue event scheduled]]`](#dom-videodecoder-dequeue-event-scheduled-slot).

15. Return d.

### 4.3. Attributes

[`state`], of type [CodecState](#enumdef-codecstate), readonly

: Returns the value of
 [`[[state]]`](#dom-videodecoder-state-slot).

[`decodeQueueSize`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: Returns the value of
 [`[[decodeQueueSize]]`](#dom-videodecoder-decodequeuesize-slot).

[`ondequeue`], of type [EventHandler](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler)

: An [event handler IDL
 attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes) whose [event handler event
 type](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type) is
 [`dequeue`](#eventdef-videodecoder-dequeue).

### 4.4. Event Summary

[`dequeue`]

: Fired at the
 [`VideoDecoder`](#videodecoder) when the
 [`decodeQueueSize`](#dom-videodecoder-decodequeuesize) has decreased.

### 4.5. Methods

[`configure(config)`]

: [Enqueues a control
 message](#enqueues-a-control-message) to configure the video decoder for decoding chunks
 as described by `config`.

 [NOTE:] This method will trigger a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) if the User Agent does not support
 `config`. Authors are encouraged to first check support
 by calling
 [`isConfigSupported()`](#dom-videodecoder-isconfigsupported) with `config`. User Agents don't have to
 support any particular codec type or configuration.

 When invoked, run these steps:

 1. If `config` is not a [valid
 VideoDecoderConfig](#valid-videodecoderconfig), throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 2. If
 [`[[state]]`](#dom-videodecoder-state-slot) is `“closed”`, throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror).

 3. Set
 [`[[state]]`](#dom-videodecoder-state-slot) to `"configured"`.

 4. Set
 [`[[key chunk required]]`](#dom-videodecoder-key-chunk-required-slot) to `true`.

 5. [Queue a control
 message](#enqueues-a-control-message) to configure the decoder with
 `config`.

 6. [Process the control message
 queue](#process-the-control-message-queue).

 [Running a control
 message](#running-a-control-message) to configure the decoder means running these steps:

 1. Assign `true` to
 [`[[message queue blocked]]`](#dom-videodecoder-message-queue-blocked-slot).

 2. Enqueue the following steps to
 [`[[codec work queue]]`](#dom-videodecoder-codec-work-queue-slot):

 1. Let `supported` be the result of running the
 [Check Configuration
 Support](#check-configuration-support) algorithm with `config`.

 2. If `supported` is `false`, [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the [Close
 VideoDecoder](#close-videodecoder) algorithm with
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) and abort these steps.

 3. If needed, assign
 [`[[codec implementation]]`](#dom-videodecoder-codec-implementation-slot) with an implementation supporting
 `config`.

 4. Configure
 [`[[codec implementation]]`](#dom-videodecoder-codec-implementation-slot) with `config`.

 5. [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the following steps:

 1. Assign `false` to
 [`[[message queue blocked]]`](#dom-videodecoder-message-queue-blocked-slot).

 2. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to [Process the control message
 queue](#process-the-control-message-queue).

 3. Return `"processed"`.

[`decode(chunk)`]

: [Enqueues a control
 message](#enqueues-a-control-message) to decode the given `chunk`.

 [NOTE:] Authors are encouraged to call
 [`close()`](#dom-videoframe-close) on output
 [`VideoFrame`](#videoframe)s immediately when frames are no longer needed. The
 underlying [media
 resource](#media-resource)s are owned by the
 [`VideoDecoder`](#videodecoder) and failing to release them (or waiting for garbage
 collection) can cause decoding to stall.

 [NOTE:]
 [`VideoDecoder`](#videodecoder) requires that frames are output in the order they
 expect to be presented, commonly known as presentation order. When
 using some
 [`[[codec implementation]]`](#dom-videodecoder-codec-implementation-slot)s the User Agent will have to reorder outputs into
 presentation order.

 When invoked, run these steps:

 1. If
 [`[[state]]`](#dom-videodecoder-state-slot) is not `"configured"`, throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror).

 2. If
 [`[[key chunk required]]`](#dom-videodecoder-key-chunk-required-slot) is `true`:

 1. If
 `chunk`.[`type`](#dom-encodedvideochunk-type) is not
 [`key`](#dom-encodedvideochunktype-key), throw a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 2. Implementers *SHOULD* inspect the `chunk`'s
 [`[[internal data]]`](#dom-encodedvideochunk-internal-data-slot) to verify that it is truly a [key
 chunk](#key-chunk). If
 a mismatch is detected, throw a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 3. Otherwise, assign `false` to
 [`[[key chunk required]]`](#dom-videodecoder-key-chunk-required-slot).

 3. Increment
 [`[[decodeQueueSize]]`](#dom-videodecoder-decodequeuesize-slot).

 4. [Queue a control
 message](#enqueues-a-control-message) to decode the `chunk`.

 5. [Process the control message
 queue](#process-the-control-message-queue).

 [Running a control
 message](#running-a-control-message) to decode the chunk means performing these steps:

 1. If
 [`[[codec saturated]]`](#dom-videodecoder-codec-saturated-slot) equals `true`, return `"not processed"`.

 2. If decoding chunk will cause the
 [`[[codec implementation]]`](#dom-videodecoder-codec-implementation-slot) to become
 [saturated](#saturated),
 assign `true` to
 [`[[codec saturated]]`](#dom-videodecoder-codec-saturated-slot).

 3. Decrement
 [`[[decodeQueueSize]]`](#dom-videodecoder-decodequeuesize-slot) and run the [Schedule Dequeue
 Event](#videodecoder-schedule-dequeue-event) algorithm.

 4. Enqueue the following steps to the
 [`[[codec work queue]]`](#dom-videodecoder-codec-work-queue-slot):

 1. Attempt to use
 [`[[codec implementation]]`](#dom-videodecoder-codec-implementation-slot) to decode the chunk.

 2. If decoding results in an error, [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the [Close
 VideoDecoder](#close-videodecoder) algorithm with
 [`EncodingError`](https://webidl.spec.whatwg.org/#encodingerror) and return.

 3. If
 [`[[codec saturated]]`](#dom-videodecoder-codec-saturated-slot) equals `true` and
 [`[[codec implementation]]`](#dom-videodecoder-codec-implementation-slot) is no longer
 [saturated](#saturated), [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to perform the following steps:

 1. Assign `false` to
 [`[[codec saturated]]`](#dom-videodecoder-codec-saturated-slot).

 2. [Process the control message
 queue](#process-the-control-message-queue).

 4. Let `decoded outputs` be a
 [list](https://infra.spec.whatwg.org/#list) of decoded video data outputs emitted by
 [`[[codec implementation]]`](#dom-videodecoder-codec-implementation-slot) in presentation order.

 5. If `decoded outputs` is not empty, [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the [Output
 VideoFrame](#output-videoframes) algorithm with
 `decoded outputs`.

 5. Return `"processed"`.

[`flush()`]

: Completes all [control
 messages](#control-message) in the [control message
 queue](#control-message-queue) and emits all outputs.

 When invoked, run these steps:

 1. If
 [`[[state]]`](#dom-videodecoder-state-slot) is not `"configured"`, return [a promise
 rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with)
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. Set
 [`[[key chunk required]]`](#dom-videodecoder-key-chunk-required-slot) to `true`.

 3. Let `promise` be a new Promise.

 4. Append `promise` to
 [`[[pending flush promises]]`](#dom-videodecoder-pending-flush-promises-slot).

 5. [Queue a control
 message](#enqueues-a-control-message) to flush the codec with `promise`.

 6. [Process the control message
 queue](#process-the-control-message-queue).

 7. Return `promise`.

 [Running a control
 message](#running-a-control-message) to flush the codec means performing these steps
 with `promise`.

 1. Enqueue the following steps to the
 [`[[codec work queue]]`](#dom-videodecoder-codec-work-queue-slot):

 1. Signal
 [`[[codec implementation]]`](#dom-videodecoder-codec-implementation-slot) to emit all [internal pending
 outputs](#internal-pending-output).

 2. Let `decoded outputs` be a
 [list](https://infra.spec.whatwg.org/#list) of decoded video data outputs emitted by
 [`[[codec implementation]]`](#dom-videodecoder-codec-implementation-slot).

 3. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to perform these steps:

 1. If `decoded outputs` is not empty, run the
 [Output
 VideoFrame](#output-videoframes) algorithm with
 `decoded outputs`.

 2. Remove `promise` from
 [`[[pending flush promises]]`](#dom-videodecoder-pending-flush-promises-slot).

 3. Resolve `promise`.

 2. Return `"processed"`.

[`reset()`]

: Immediately resets all state including configuration, [control
 messages](#control-message) in the [control message
 queue](#control-message-queue), and all pending callbacks.

 When invoked, run the [Reset
 VideoDecoder](#reset-videodecoder) algorithm with an
 [`AbortError`](https://webidl.spec.whatwg.org/#aborterror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

[`close()`]

: Immediately aborts all pending work and releases [system
 resources](#system-resources). Close is final.

 When invoked, run the [Close
 VideoDecoder](#close-videodecoder) algorithm with an
 [`AbortError`](https://webidl.spec.whatwg.org/#aborterror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

[`isConfigSupported(config)`]

: Returns a promise indicating whether the provided
 `config` is supported by the User Agent.

 [NOTE:] The returned
 [`VideoDecoderSupport`](#dictdef-videodecodersupport)
 [`config`](#dom-videodecodersupport-config) will contain only the dictionary members that User
 Agent recognized. Unrecognized dictionary members will be ignored.
 Authors can detect unrecognized dictionary members by comparing
 [`config`](#dom-videodecodersupport-config) to their provided `config`.

 When invoked, run these steps:

 1. If `config` is not a [valid
 VideoDecoderConfig](#valid-videodecoderconfig), return [a promise rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with)
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 2. Let `p` be a new Promise.

 3. Let `checkSupportQueue` be the result of starting a
 new [parallel
 queue](https://html.spec.whatwg.org/multipage/infrastructure.html#parallel-queue).

 4. Enqueue the following steps to `checkSupportQueue`:

 1. Let `supported` be the result of running the
 [Check Configuration
 Support](#check-configuration-support) algorithm with `config`.

 2. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the following steps:

 1. Let `decoderSupport` be a newly constructed
 [`VideoDecoderSupport`](#dictdef-videodecodersupport), initialized as follows:

 1. Set
 [`config`](#dom-videodecodersupport-config) to the result of running the [Clone
 Configuration](#clone-configuration) algorithm with `config`.

 2. Set
 [`supported`](#dom-videodecodersupport-supported) to `supported`.

 2. Resolve `p` with `decoderSupport`.

 5. Return `p`.

### 4.6. Algorithms

[Schedule Dequeue Event]

: 1. If
 [`[[dequeue event scheduled]]`](#dom-videodecoder-dequeue-event-scheduled-slot) equals `true`, return.

 2. Assign `true` to
 [`[[dequeue event scheduled]]`](#dom-videodecoder-dequeue-event-scheduled-slot).

 3. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the following steps:

 1. Fire a simple event named
 [`dequeue`](#eventdef-videodecoder-dequeue) at
 [this](https://webidl.spec.whatwg.org/#this).

 2. Assign `false` to
 [`[[dequeue event scheduled]]`](#dom-videodecoder-dequeue-event-scheduled-slot).

[Output VideoFrames] (with `outputs`)
: Run these steps:
 1. For each `output` in `outputs`:

 1. Let `timestamp` and `duration` be the
 [`timestamp`](#dom-encodedvideochunk-timestamp) and
 [`duration`](#dom-encodedvideochunk-duration) from the
 [`EncodedVideoChunk`](#encodedvideochunk) associated with `output`.

 2. Let `displayAspectWidth` and
 `displayAspectHeight` be undefined.

 3. If
 [`displayAspectWidth`](#dom-videodecoderconfig-displayaspectwidth) and
 [`displayAspectHeight`](#dom-videodecoderconfig-displayaspectheight)
 [exist](https://infra.spec.whatwg.org/#map-exists) in the
 [`[[active decoder config]]`](#dom-videodecoder-active-decoder-config-slot), assign their values to
 `displayAspectWidth` and
 `displayAspectHeight` respectively.

 4. Let `colorSpace` be the
 [`VideoColorSpace`](#videocolorspace) for `output` as detected by the
 codec implementation. If no
 [`VideoColorSpace`](#videocolorspace) is detected, let `colorSpace` be
 `undefined`.

 [NOTE:] The codec implementation can detect a
 [`VideoColorSpace`](#videocolorspace) by analyzing the bitstream. Detection is
 made on a best-effort basis. The exact method of detection
 is implementer defined and codec-specific. Authors can
 override the detected
 [`VideoColorSpace`](#videocolorspace) by providing a
 [`colorSpace`](#dom-videodecoderconfig-colorspace) in the
 [`VideoDecoderConfig`](#dictdef-videodecoderconfig).

 5. If
 [`colorSpace`](#dom-videodecoderconfig-colorspace)
 [exists](https://infra.spec.whatwg.org/#map-exists) in the
 [`[[active decoder config]]`](#dom-videodecoder-active-decoder-config-slot), assign its value to
 `colorSpace`.

 6. Assign the values of
 [`rotation`](#dom-videodecoderconfig-rotation) and
 [`flip`](#dom-videodecoderconfig-flip) to `rotation` and
 `flip` respectively.

 7. Let `frame` be the result of running the [Create
 a
 VideoFrame](#create-a-videoframe) algorithm with `output`,
 `timestamp`, `duration`,
 `displayAspectWidth`,
 `displayAspectHeight`, `colorSpace`,
 `rotation`, and `flip`.

 8. Invoke
 [`[[output callback]]`](#dom-videodecoder-output-callback-slot) with `frame`.

[Reset VideoDecoder] (with `exception`)
: Run these steps:
 1. If
 [`state`](#dom-videodecoder-state) is `"closed"`, throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror).

 2. Set
 [`state`](#dom-videodecoder-state) to `"unconfigured"`.

 3. Signal
 [`[[codec implementation]]`](#dom-videodecoder-codec-implementation-slot) to cease producing output for the previous
 configuration.

 4. Remove all [control
 messages](#control-message) from the
 [`[[control message queue]]`](#dom-videodecoder-control-message-queue-slot).

 5. If
 [`[[decodeQueueSize]]`](#dom-videodecoder-decodequeuesize-slot) is greater than zero:

 1. Set
 [`[[decodeQueueSize]]`](#dom-videodecoder-decodequeuesize-slot) to zero.

 2. Run the [Schedule Dequeue
 Event](#videodecoder-schedule-dequeue-event) algorithm.

 6. For each `promise` in
 [`[[pending flush promises]]`](#dom-videodecoder-pending-flush-promises-slot):

 1. Reject `promise` with `exception`.

 2. Remove `promise` from
 [`[[pending flush promises]]`](#dom-videodecoder-pending-flush-promises-slot).

[Close VideoDecoder] (with `exception`)
: Run these steps:
 1. Run the [Reset
 VideoDecoder](#reset-videodecoder) algorithm with `exception`.

 2. Set
 [`state`](#dom-videodecoder-state) to `"closed"`.

 3. Clear
 [`[[codec implementation]]`](#dom-videodecoder-codec-implementation-slot) and release associated [system
 resources](#system-resources).

 4. If `exception` is not an
 [`AbortError`](https://webidl.spec.whatwg.org/#aborterror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException), invoke the
 [`[[error callback]]`](#dom-videodecoder-error-callback-slot) with `exception`.

## 5. AudioEncoder Interface

```
[Exposed=(Window,DedicatedWorker), SecureContext]
interface AudioEncoder : EventTarget {
 constructor(AudioEncoderInit init);

 readonly attribute CodecState state;
 readonly attribute unsigned long encodeQueueSize;
 attribute EventHandler ondequeue;

 undefined configure(AudioEncoderConfig config);
 undefined encode(AudioData data);
 Promise<undefined> flush();
 undefined reset();
 undefined close();

 static Promise<AudioEncoderSupport> isConfigSupported(AudioEncoderConfig config);
};

dictionary AudioEncoderInit {
 required EncodedAudioChunkOutputCallback output;
 required WebCodecsErrorCallback error;
};

callback EncodedAudioChunkOutputCallback =
 undefined (EncodedAudioChunk output,
 optional EncodedAudioChunkMetadata metadata = );
```

### 5.1. Internal Slots

[`[[control message queue]]`]

: A [queue](https://infra.spec.whatwg.org/#queue) of [control
 messages](#control-message) to be performed upon this
 [codec](#codec) instance. See
 [\[\[control message
 queue\]\]](#control-message-queue-slot).

[`[[message queue blocked]]`]

: A boolean indicating when processing the
 [`[[control message queue]]`](#dom-audioencoder-control-message-queue-slot) is blocked by a pending [control
 message](#control-message). See [\[\[message queue
 blocked\]\]](#message-queue-blocked).

[`[[codec implementation]]`]

: Underlying encoder implementation provided by the User Agent. See
 [\[\[codec
 implementation\]\]](#codec-implementation).

[`[[codec work queue]]`]

: A [parallel
 queue](https://html.spec.whatwg.org/multipage/infrastructure.html#parallel-queue) used for running parallel steps that reference the
 [`[[codec implementation]]`](#dom-audioencoder-codec-implementation-slot). See [\[\[codec work
 queue\]\]](#codec-work-queue).

[`[[codec saturated]]`]

: A boolean indicating when the
 [`[[codec implementation]]`](#dom-audioencoder-codec-implementation-slot) is unable to accept additional encoding work.

[`[[output callback]]`]

: Callback given at construction for encoded outputs.

[`[[error callback]]`]

: Callback given at construction for encode errors.

[`[[active encoder config]]`]

: The
 [`AudioEncoderConfig`](#dictdef-audioencoderconfig) that is actively applied.

[`[[active output config]]`]

: The
 [`AudioDecoderConfig`](#dictdef-audiodecoderconfig) that describes how to decode the most recently
 emitted
 [`EncodedAudioChunk`](#encodedaudiochunk).

[`[[state]]`]

: The current
 [`CodecState`](#enumdef-codecstate) of this
 [`AudioEncoder`](#audioencoder).

[`[[encodeQueueSize]]`]

: The number of pending encode requests. This number will decrease as
 the underlying codec is ready to accept new input.

[`[[pending flush promises]]`]

: A list of unresolved promises returned by calls to
 [`flush()`](#dom-audioencoder-flush).

[`[[dequeue event scheduled]]`]

: A boolean indicating whether a
 [`dequeue`](#eventdef-audioencoder-dequeue) event is already scheduled to fire. Used to avoid
 event spam.

### 5.2. Constructors

[` AudioEncoder(init) `]

1. Let e be a new
 [`AudioEncoder`](#audioencoder) object.

2. Assign a new
 [queue](https://infra.spec.whatwg.org/#queue) to
 [`[[control message queue]]`](#dom-audioencoder-control-message-queue-slot).

3. Assign `false` to
 [`[[message queue blocked]]`](#dom-audioencoder-message-queue-blocked-slot).

4. Assign `null` to
 [`[[codec implementation]]`](#dom-audioencoder-codec-implementation-slot).

5. Assign the result of starting a new [parallel
 queue](https://html.spec.whatwg.org/multipage/infrastructure.html#parallel-queue) to
 [`[[codec work queue]]`](#dom-audioencoder-codec-work-queue-slot).

6. Assign `false` to
 [`[[codec saturated]]`](#dom-audioencoder-codec-saturated-slot).

7. Assign init.output to
 [`[[output callback]]`](#dom-audioencoder-output-callback-slot).

8. Assign init.error to
 [`[[error callback]]`](#dom-audioencoder-error-callback-slot).

9. Assign `null` to
 [`[[active encoder config]]`](#dom-audioencoder-active-encoder-config-slot).

10. Assign `null` to
 [`[[active output config]]`](#dom-audioencoder-active-output-config-slot).

11. Assign `"unconfigured"` to
 [`[[state]]`](#dom-audioencoder-state-slot)

12. Assign `0` to
 [`[[encodeQueueSize]]`](#dom-audioencoder-encodequeuesize-slot).

13. Assign a new
 [list](https://infra.spec.whatwg.org/#list) to
 [`[[pending flush promises]]`](#dom-audioencoder-pending-flush-promises-slot).

14. Assign `false` to
 [`[[dequeue event scheduled]]`](#dom-audioencoder-dequeue-event-scheduled-slot).

15. Return e.

### 5.3. Attributes

[`state`], of type [CodecState](#enumdef-codecstate), readonly

: Returns the value of
 [`[[state]]`](#dom-audioencoder-state-slot).

[`encodeQueueSize`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: Returns the value of
 [`[[encodeQueueSize]]`](#dom-audioencoder-encodequeuesize-slot).

[`ondequeue`], of type [EventHandler](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler)

: An [event handler IDL
 attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes) whose [event handler event
 type](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type) is
 [`dequeue`](#eventdef-audioencoder-dequeue).

### 5.4. Event Summary

[`dequeue`]

: Fired at the
 [`AudioEncoder`](#audioencoder) when the
 [`encodeQueueSize`](#dom-audioencoder-encodequeuesize) has decreased.

### 5.5. Methods

[`configure(config)`]

: [Enqueues a control
 message](#enqueues-a-control-message) to configure the audio encoder for encoding audio
 data as described by `config`.

 [NOTE:] This method will trigger a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) if the User Agent does not support
 `config`. Authors are encouraged to first check support
 by calling
 [`isConfigSupported()`](#dom-audioencoder-isconfigsupported) with `config`. User Agents don't have to
 support any particular codec type or configuration.

 When invoked, run these steps:

 1. If `config` is not a [valid
 AudioEncoderConfig](#valid-audioencoderconfig), throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 2. If
 [`[[state]]`](#dom-audioencoder-state-slot) is `"closed"`, throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror).

 3. Set
 [`[[state]]`](#dom-audioencoder-state-slot) to `"configured"`.

 4. [Queue a control
 message](#enqueues-a-control-message) to configure the encoder using
 `config`.

 5. [Process the control message
 queue](#process-the-control-message-queue).

 [Running a control
 message](#running-a-control-message) to configure the encoder means performing these
 steps:

 1. Assign `true` to
 [`[[message queue blocked]]`](#dom-audioencoder-message-queue-blocked-slot).

 2. Enqueue the following steps to
 [`[[codec work queue]]`](#dom-audioencoder-codec-work-queue-slot):

 1. Let `supported` be the result of running the
 [Check Configuration
 Support](#check-configuration-support) algorithm with `config`.

 2. If `supported` is `false`, [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the [Close
 AudioEncoder](#close-audioencoder) algorithm with
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) and abort these steps.

 3. If needed, assign
 [`[[codec implementation]]`](#dom-audioencoder-codec-implementation-slot) with an implementation supporting
 `config`.

 4. Configure
 [`[[codec implementation]]`](#dom-audioencoder-codec-implementation-slot) with `config`.

 5. [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the following steps:

 1. Assign `false` to
 [`[[message queue blocked]]`](#dom-audioencoder-message-queue-blocked-slot).

 2. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to [Process the control message
 queue](#process-the-control-message-queue).

 3. Return `"processed"`.

[`encode(data)`]

: [Enqueues a control
 message](#enqueues-a-control-message) to encode the given `data`.

 When invoked, run these steps:

 1. If the value of `data`'s
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached) internal slot is `true`, throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 2. If
 [`[[state]]`](#dom-audioencoder-state-slot) is not `"configured"`, throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror).

 3. Let `dataClone` hold the result of running the [Clone
 AudioData](#clone-audiodata) algorithm with `data`.

 4. Increment
 [`[[encodeQueueSize]]`](#dom-audioencoder-encodequeuesize-slot).

 5. [Queue a control
 message](#enqueues-a-control-message) to encode `dataClone`.

 6. [Process the control message
 queue](#process-the-control-message-queue).

 [Running a control
 message](#running-a-control-message) to encode the data means performing these steps:

 1. If
 [`[[codec saturated]]`](#dom-audioencoder-codec-saturated-slot) equals `true`, return `"not processed"`.

 2. If encoding `data` will cause the
 [`[[codec implementation]]`](#dom-audioencoder-codec-implementation-slot) to become
 [saturated](#saturated),
 assign `true` to
 [`[[codec saturated]]`](#dom-audioencoder-codec-saturated-slot).

 3. Decrement
 [`[[encodeQueueSize]]`](#dom-audioencoder-encodequeuesize-slot) and run the [Schedule Dequeue
 Event](#audioencoder-schedule-dequeue-event) algorithm.

 4. Enqueue the following steps to the
 [`[[codec work queue]]`](#dom-audioencoder-codec-work-queue-slot):

 1. Attempt to use
 [`[[codec implementation]]`](#dom-audioencoder-codec-implementation-slot) to encode the [media
 resource](#media-resource) described by `dataClone`.

 2. If encoding results in an error, [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the [Close
 AudioEncoder](#close-audioencoder) algorithm with
 [`EncodingError`](https://webidl.spec.whatwg.org/#encodingerror) and return.

 3. If
 [`[[codec saturated]]`](#dom-audioencoder-codec-saturated-slot) equals `true` and
 [`[[codec implementation]]`](#dom-audioencoder-codec-implementation-slot) is no longer
 [saturated](#saturated), [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to perform the following steps:

 1. Assign `false` to
 [`[[codec saturated]]`](#dom-audioencoder-codec-saturated-slot).

 2. [Process the control message
 queue](#process-the-control-message-queue).

 4. Let `encoded outputs` be a
 [list](https://infra.spec.whatwg.org/#list) of encoded audio data outputs emitted by
 [`[[codec implementation]]`](#dom-audioencoder-codec-implementation-slot).

 5. If `encoded outputs` is not empty, [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the [Output
 EncodedAudioChunks](#output-encodedaudiochunks) algorithm with
 `encoded outputs`.

 5. Return `"processed"`.

[`flush()`]

: Completes all [control
 messages](#control-message) in the [control message
 queue](#control-message-queue) and emits all outputs.

 When invoked, run these steps:

 1. If
 [`[[state]]`](#dom-audioencoder-state-slot) is not `"configured"`, return [a promise
 rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with)
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. Let `promise` be a new Promise.

 3. Append `promise` to
 [`[[pending flush promises]]`](#dom-audioencoder-pending-flush-promises-slot).

 4. [Queue a control
 message](#enqueues-a-control-message) to flush the codec with `promise`.

 5. [Process the control message
 queue](#process-the-control-message-queue).

 6. Return `promise`.

 [Running a control
 message](#running-a-control-message) to flush the codec means performing these steps
 with `promise`.

 1. Enqueue the following steps to the
 [`[[codec work queue]]`](#dom-audioencoder-codec-work-queue-slot):

 1. Signal
 [`[[codec implementation]]`](#dom-audioencoder-codec-implementation-slot) to emit all [internal pending
 outputs](#internal-pending-output).

 2. Let `encoded outputs` be a
 [list](https://infra.spec.whatwg.org/#list) of encoded audio data outputs emitted by
 [`[[codec implementation]]`](#dom-audioencoder-codec-implementation-slot).

 3. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to perform these steps:

 1. If `encoded outputs` is not empty, run the
 [Output
 EncodedAudioChunks](#output-encodedaudiochunks) algorithm with
 `encoded outputs`.

 2. Remove `promise` from
 [`[[pending flush promises]]`](#dom-audioencoder-pending-flush-promises-slot).

 3. Resolve `promise`.

 2. Return `"processed"`.

[`reset()`]

: Immediately resets all state including configuration, [control
 messages](#control-message) in the [control message
 queue](#control-message-queue), and all pending callbacks.

 When invoked, run the [Reset
 AudioEncoder](#reset-audioencoder) algorithm with an
 [`AbortError`](https://webidl.spec.whatwg.org/#aborterror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

[`close()`]

: Immediately aborts all pending work and releases [system
 resources](#system-resources). Close is final.

 When invoked, run the [Close
 AudioEncoder](#close-audioencoder) algorithm with an
 [`AbortError`](https://webidl.spec.whatwg.org/#aborterror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

[`isConfigSupported(config)`]

: Returns a promise indicating whether the provided
 `config` is supported by the User Agent.

 [NOTE:] The returned
 [`AudioEncoderSupport`](#dictdef-audioencodersupport)
 [`config`](#dom-audioencodersupport-config) will contain only the dictionary members that User
 Agent recognized. Unrecognized dictionary members will be ignored.
 Authors can detect unrecognized dictionary members by comparing
 [`config`](#dom-audioencodersupport-config) to their provided `config`.

 When invoked, run these steps:

 1. If `config` is not a [valid
 AudioEncoderConfig](#valid-audioencoderconfig), return [a promise rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with)
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 2. Let `p` be a new Promise.

 3. Let `checkSupportQueue` be the result of starting a
 new [parallel
 queue](https://html.spec.whatwg.org/multipage/infrastructure.html#parallel-queue).

 4. Enqueue the following steps to `checkSupportQueue`:

 1. Let `supported` be the result of running the
 [Check Configuration
 Support](#check-configuration-support) algorithm with `config`.

 2. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the following steps:

 1. Let `encoderSupport` be a newly constructed
 [`AudioEncoderSupport`](#dictdef-audioencodersupport), initialized as follows:

 1. Set
 [`config`](#dom-audioencodersupport-config) to the result of running the [Clone
 Configuration](#clone-configuration) algorithm with `config`.

 2. Set
 [`supported`](#dom-audioencodersupport-supported) to `supported`.

 2. Resolve `p` with `encoderSupport`.

 5. Return `p`.

### 5.6. Algorithms

[Schedule Dequeue Event]

: 1. If
 [`[[dequeue event scheduled]]`](#dom-audioencoder-dequeue-event-scheduled-slot) equals `true`, return.

 2. Assign `true` to
 [`[[dequeue event scheduled]]`](#dom-audioencoder-dequeue-event-scheduled-slot).

 3. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the following steps:

 1. Fire a simple event named
 [`dequeue`](#eventdef-audioencoder-dequeue) at
 [this](https://webidl.spec.whatwg.org/#this).

 2. Assign `false` to
 [`[[dequeue event scheduled]]`](#dom-audioencoder-dequeue-event-scheduled-slot).

[Output EncodedAudioChunks] (with `outputs`)
: Run these steps:
 1. For each `output` in `outputs`:

 1. Let `chunkInit` be an
 [`EncodedAudioChunkInit`](#dictdef-encodedaudiochunkinit) with the following keys:

 1. Let
 [`data`](#dom-encodedaudiochunkinit-data) contain the encoded audio data from
 `output`.

 2. Let
 [`type`](#dom-encodedaudiochunkinit-type) be the
 [`EncodedAudioChunkType`](#enumdef-encodedaudiochunktype) of `output`.

 3. Let
 [`timestamp`](#dom-encodedaudiochunkinit-timestamp) be the
 [`timestamp`](#dom-audiodata-timestamp) from the AudioData associated with
 `output`.

 4. Let
 [`duration`](#dom-encodedaudiochunkinit-duration) be the
 [`duration`](#dom-audiodata-duration) from the AudioData associated with
 `output`.

 2. Let `chunk` be a new
 [`EncodedAudioChunk`](#encodedaudiochunk) constructed with `chunkInit`.

 3. Let `chunkMetadata` be a new
 [`EncodedAudioChunkMetadata`](#dictdef-encodedaudiochunkmetadata).

 4. Let `encoderConfig` be the
 [`[[active encoder config]]`](#dom-audioencoder-active-encoder-config-slot).

 5. Let `outputConfig` be a new
 [`AudioDecoderConfig`](#dictdef-audiodecoderconfig) that describes `output`.
 Initialize `outputConfig` as follows:

 1. Assign
 `encoderConfig`.[`codec`](#dom-audioencoderconfig-codec) to
 `outputConfig`.[`codec`](#dom-audiodecoderconfig-codec).

 2. Assign
 `encoderConfig`.[`sampleRate`](#dom-audioencoderconfig-samplerate) to
 `outputConfig`.[`sampleRate`](#dom-audiodecoderconfig-samplerate).

 3. Assign to
 `encoderConfig`.[`numberOfChannels`](#dom-audioencoderconfig-numberofchannels) to
 `outputConfig`.[`numberOfChannels`](#dom-audiodecoderconfig-numberofchannels).

 4. Assign
 `outputConfig`.[`description`](#dom-audiodecoderconfig-description) with a sequence of codec specific bytes
 as determined by the
 [`[[codec implementation]]`](#dom-audioencoder-codec-implementation-slot). The User Agent *MUST* ensure that the
 provided description could be used to correctly decode
 output.

 [NOTE:] The codec specific requirements for
 populating the
 [`description`](#dom-audiodecoderconfig-description) are described in the
 [\[WEBCODECS-CODEC-REGISTRY\]](#biblio-webcodecs-codec-registry "WebCodecs Codec Registry").

 6. If `outputConfig` and
 [`[[active output config]]`](#dom-audioencoder-active-output-config-slot) are not [equal
 dictionaries](#equal-dictionaries):

 1. Assign `outputConfig` to
 `chunkMetadata`.[`decoderConfig`](#dom-encodedaudiochunkmetadata-decoderconfig).

 2. Assign `outputConfig` to
 [`[[active output config]]`](#dom-audioencoder-active-output-config-slot).

 7. Invoke
 [`[[output callback]]`](#dom-audioencoder-output-callback-slot) with `chunk` and
 `chunkMetadata`.

[Reset AudioEncoder] (with `exception`)
: Run these steps:
 1. If
 [`[[state]]`](#dom-audioencoder-state-slot) is `"closed"`, throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror).

 2. Set
 [`[[state]]`](#dom-audioencoder-state-slot) to `"unconfigured"`.

 3. Set
 [`[[active encoder config]]`](#dom-audioencoder-active-encoder-config-slot) to `null`.

 4. Set
 [`[[active output config]]`](#dom-audioencoder-active-output-config-slot) to `null`.

 5. Signal
 [`[[codec implementation]]`](#dom-audioencoder-codec-implementation-slot) to cease producing output for the previous
 configuration.

 6. Remove all [control
 messages](#control-message) from the
 [`[[control message queue]]`](#dom-audioencoder-control-message-queue-slot).

 7. If
 [`[[encodeQueueSize]]`](#dom-audioencoder-encodequeuesize-slot) is greater than zero:

 1. Set
 [`[[encodeQueueSize]]`](#dom-audioencoder-encodequeuesize-slot) to zero.

 2. Run the [Schedule Dequeue
 Event](#audioencoder-schedule-dequeue-event) algorithm.

 8. For each `promise` in
 [`[[pending flush promises]]`](#dom-audioencoder-pending-flush-promises-slot):

 1. Reject `promise` with `exception`.

 2. Remove `promise` from
 [`[[pending flush promises]]`](#dom-audioencoder-pending-flush-promises-slot).

[Close AudioEncoder] (with `exception`)
: Run these steps:
 1. Run the [Reset
 AudioEncoder](#reset-audioencoder) algorithm with `exception`.

 2. Set
 [`[[state]]`](#dom-audioencoder-state-slot) to `"closed"`.

 3. Clear
 [`[[codec implementation]]`](#dom-audioencoder-codec-implementation-slot) and release associated [system
 resources](#system-resources).

 4. If `exception` is not an
 [`AbortError`](https://webidl.spec.whatwg.org/#aborterror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException), invoke the
 [`[[error callback]]`](#dom-audioencoder-error-callback-slot) with `exception`.

### 5.7. EncodedAudioChunkMetadata

The following metadata dictionary is emitted by the
[`EncodedAudioChunkOutputCallback`](#callbackdef-encodedaudiochunkoutputcallback) alongside an associated
[`EncodedAudioChunk`](#encodedaudiochunk).

```
dictionary EncodedAudioChunkMetadata {
 AudioDecoderConfig decoderConfig;
};
```

[`decoderConfig`], of type [AudioDecoderConfig](#dictdef-audiodecoderconfig)

: A
 [`AudioDecoderConfig`](#dictdef-audiodecoderconfig) that authors *MAY* use to decode the associated
 [`EncodedAudioChunk`](#encodedaudiochunk).

## 6. VideoEncoder Interface

```
[Exposed=(Window,DedicatedWorker), SecureContext]
interface VideoEncoder : EventTarget {
 constructor(VideoEncoderInit init);

 readonly attribute CodecState state;
 readonly attribute unsigned long encodeQueueSize;
 attribute EventHandler ondequeue;

 undefined configure(VideoEncoderConfig config);
 undefined encode(VideoFrame frame, optional VideoEncoderEncodeOptions options = );
 Promise<undefined> flush();
 undefined reset();
 undefined close();

 static Promise<VideoEncoderSupport> isConfigSupported(VideoEncoderConfig config);
};

dictionary VideoEncoderInit {
 required EncodedVideoChunkOutputCallback output;
 required WebCodecsErrorCallback error;
};

callback EncodedVideoChunkOutputCallback =
 undefined (EncodedVideoChunk chunk,
 optional EncodedVideoChunkMetadata metadata = );
```

### 6.1. Internal Slots

[`[[control message queue]]`]

: A [queue](https://infra.spec.whatwg.org/#queue) of [control
 messages](#control-message) to be performed upon this
 [codec](#codec) instance. See
 [\[\[control message
 queue\]\]](#control-message-queue-slot).

[`[[message queue blocked]]`]

: A boolean indicating when processing the
 [`[[control message queue]]`](#dom-videoencoder-control-message-queue-slot) is blocked by a pending [control
 message](#control-message). See [\[\[message queue
 blocked\]\]](#message-queue-blocked).

[`[[codec implementation]]`]

: Underlying encoder implementation provided by the User Agent. See
 [\[\[codec
 implementation\]\]](#codec-implementation).

[`[[codec work queue]]`]

: A [parallel
 queue](https://html.spec.whatwg.org/multipage/infrastructure.html#parallel-queue) used for running parallel steps that reference the
 [`[[codec implementation]]`](#dom-videoencoder-codec-implementation-slot). See [\[\[codec work
 queue\]\]](#codec-work-queue).

[`[[codec saturated]]`]

: A boolean indicating when the
 [`[[codec implementation]]`](#dom-videoencoder-codec-implementation-slot) is unable to accept additional encoding work.

[`[[output callback]]`]

: Callback given at construction for encoded outputs.

[`[[error callback]]`]

: Callback given at construction for encode errors.

[`[[active encoder config]]`]

: The
 [`VideoEncoderConfig`](#dictdef-videoencoderconfig) that is actively applied.

[`[[active output config]]`]

: The
 [`VideoDecoderConfig`](#dictdef-videodecoderconfig) that describes how to decode the most recently
 emitted
 [`EncodedVideoChunk`](#encodedvideochunk).

[`[[state]]`]

: The current
 [`CodecState`](#enumdef-codecstate) of this
 [`VideoEncoder`](#videoencoder).

[`[[encodeQueueSize]]`]

: The number of pending encode requests. This number will decrease as
 the underlying codec is ready to accept new input.

[`[[pending flush promises]]`]

: A list of unresolved promises returned by calls to
 [`flush()`](#dom-videoencoder-flush).

[`[[dequeue event scheduled]]`]

: A boolean indicating whether a
 [`dequeue`](#eventdef-videoencoder-dequeue) event is already scheduled to fire. Used to avoid
 event spam.

[`[[active orientation]]`]

: An integer and boolean pair indicating the
 [`[[flip]]`](#dom-videoframe-flip-slot) and
 [`[[rotation]]`](#dom-videoframe-rotation-slot) of the first
 [`VideoFrame`](#videoframe) given to
 [`encode()`](#dom-videoencoder-encode) after
 [`configure()`](#dom-videoencoder-configure).

### 6.2. Constructors

[` VideoEncoder(init) `]

1. Let e be a new
 [`VideoEncoder`](#videoencoder) object.

2. Assign a new
 [queue](https://infra.spec.whatwg.org/#queue) to
 [`[[control message queue]]`](#dom-videoencoder-control-message-queue-slot).

3. Assign `false` to
 [`[[message queue blocked]]`](#dom-videoencoder-message-queue-blocked-slot).

4. Assign `null` to
 [`[[codec implementation]]`](#dom-videoencoder-codec-implementation-slot).

5. Assign the result of starting a new [parallel
 queue](https://html.spec.whatwg.org/multipage/infrastructure.html#parallel-queue) to
 [`[[codec work queue]]`](#dom-videoencoder-codec-work-queue-slot).

6. Assign `false` to
 [`[[codec saturated]]`](#dom-videoencoder-codec-saturated-slot).

7. Assign init.output to
 [`[[output callback]]`](#dom-videoencoder-output-callback-slot).

8. Assign init.error to
 [`[[error callback]]`](#dom-videoencoder-error-callback-slot).

9. Assign `null` to
 [`[[active encoder config]]`](#dom-videoencoder-active-encoder-config-slot).

10. Assign `null` to
 [`[[active output config]]`](#dom-videoencoder-active-output-config-slot).

11. Assign `"unconfigured"` to
 [`[[state]]`](#dom-videoencoder-state-slot)

12. Assign `0` to
 [`[[encodeQueueSize]]`](#dom-videoencoder-encodequeuesize-slot).

13. Assign a new
 [list](https://infra.spec.whatwg.org/#list) to
 [`[[pending flush promises]]`](#dom-videoencoder-pending-flush-promises-slot).

14. Assign `false` to
 [`[[dequeue event scheduled]]`](#dom-videoencoder-dequeue-event-scheduled-slot).

15. Return e.

### 6.3. Attributes

[`state`], of type [CodecState](#enumdef-codecstate), readonly

: Returns the value of
 [`[[state]]`](#dom-videoencoder-state-slot).

[`encodeQueueSize`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: Returns the value of
 [`[[encodeQueueSize]]`](#dom-videoencoder-encodequeuesize-slot).

[`ondequeue`], of type [EventHandler](https://html.spec.whatwg.org/multipage/webappapis.html#eventhandler)

: An [event handler IDL
 attribute](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-idl-attributes) whose [event handler event
 type](https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-event-type) is
 [`dequeue`](#eventdef-videoencoder-dequeue).

### 6.4. Event Summary

[`dequeue`]

: Fired at the
 [`VideoEncoder`](#videoencoder) when the
 [`encodeQueueSize`](#dom-videoencoder-encodequeuesize) has decreased.

### 6.5. Methods

[`configure(config)`]

: [Enqueues a control
 message](#enqueues-a-control-message) to configure the video encoder for encoding video
 frames as described by `config`.

 [NOTE:] This method will trigger a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) if the User Agent does not support
 `config`. Authors are encouraged to first check support
 by calling
 [`isConfigSupported()`](#dom-videoencoder-isconfigsupported) with `config`. User Agents don't have to
 support any particular codec type or configuration.

 When invoked, run these steps:

 1. If `config` is not a [valid
 VideoEncoderConfig](#valid-videoencoderconfig), throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 2. If
 [`[[state]]`](#dom-videoencoder-state-slot) is `"closed"`, throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror).

 3. Set
 [`[[state]]`](#dom-videoencoder-state-slot) to `"configured"`.

 4. Set
 [`[[active orientation]]`](#dom-videoencoder-active-orientation-slot) to `null`.

 5. [Queue a control
 message](#enqueues-a-control-message) to configure the encoder using
 `config`.

 6. [Process the control message
 queue](#process-the-control-message-queue).

 [Running a control
 message](#running-a-control-message) to configure the encoder means performing these
 steps:

 1. Assign `true` to
 [`[[message queue blocked]]`](#dom-videoencoder-message-queue-blocked-slot).

 2. Enqueue the following steps to
 [`[[codec work queue]]`](#dom-videoencoder-codec-work-queue-slot):

 1. Let `supported` be the result of running the
 [Check Configuration
 Support](#check-configuration-support) algorithm with `config`.

 2. If `supported` is `false`, [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the [Close
 VideoEncoder](#close-videoencoder) algorithm with
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) and abort these steps.

 3. If needed, assign
 [`[[codec implementation]]`](#dom-videoencoder-codec-implementation-slot) with an implementation supporting
 `config`.

 4. Configure
 [`[[codec implementation]]`](#dom-videoencoder-codec-implementation-slot) with `config`.

 5. [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the following steps:

 1. Assign `false` to
 [`[[message queue blocked]]`](#dom-videoencoder-message-queue-blocked-slot).

 2. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to [Process the control message
 queue](#process-the-control-message-queue).

 3. Return `"processed"`.

[`encode(``frame``, ``options``)`]

: [Enqueues a control
 message](#enqueues-a-control-message) to encode the given `frame`.

 When invoked, run these steps:

 1. If the value of `frame`'s
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached) internal slot is `true`, throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 2. If
 [`[[state]]`](#dom-videoencoder-state-slot) is not `"configured"`, throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror).

 3. If
 [`[[active orientation]]`](#dom-videoencoder-active-orientation-slot) is not `null` and does not match
 `frame`'s
 [`[[rotation]]`](#dom-videoframe-rotation-slot) and
 [`[[flip]]`](#dom-videoframe-flip-slot) throw a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror).

 4. If
 [`[[active orientation]]`](#dom-videoencoder-active-orientation-slot) is `null`, set it to `frame`'s
 [`[[rotation]]`](#dom-videoframe-rotation-slot) and
 [`[[flip]]`](#dom-videoframe-flip-slot).

 5. Let `frameClone` hold the result of running the
 [Clone VideoFrame](#clone-videoframe) algorithm with `frame`.

 6. Increment
 [`[[encodeQueueSize]]`](#dom-videoencoder-encodequeuesize-slot).

 7. [Queue a control
 message](#enqueues-a-control-message) to encode `frameClone`.

 8. [Process the control message
 queue](#process-the-control-message-queue).

 [Running a control
 message](#running-a-control-message) to encode the frame means performing these steps:

 1. If
 [`[[codec saturated]]`](#dom-videoencoder-codec-saturated-slot) equals `true`, return `"not processed"`.

 2. If encoding `frame` will cause the
 [`[[codec implementation]]`](#dom-videoencoder-codec-implementation-slot) to become
 [saturated](#saturated),
 assign `true` to
 [`[[codec saturated]]`](#dom-videoencoder-codec-saturated-slot).

 3. Decrement
 [`[[encodeQueueSize]]`](#dom-videoencoder-encodequeuesize-slot) and run the [Schedule Dequeue
 Event](#videoencoder-schedule-dequeue-event) algorithm.

 4. Enqueue the following steps to the
 [`[[codec work queue]]`](#dom-videoencoder-codec-work-queue-slot):

 1. Attempt to use
 [`[[codec implementation]]`](#dom-videoencoder-codec-implementation-slot) to encode the `frameClone`
 according to `options`.

 2. If encoding results in an error, [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the [Close
 VideoEncoder](#close-videoencoder) algorithm with
 [`EncodingError`](https://webidl.spec.whatwg.org/#encodingerror) and return.

 3. If
 [`[[codec saturated]]`](#dom-videoencoder-codec-saturated-slot) equals `true` and
 [`[[codec implementation]]`](#dom-videoencoder-codec-implementation-slot) is no longer
 [saturated](#saturated), [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to perform the following steps:

 1. Assign `false` to
 [`[[codec saturated]]`](#dom-videoencoder-codec-saturated-slot).

 2. [Process the control message
 queue](#process-the-control-message-queue).

 4. Let `encoded outputs` be a
 [list](https://infra.spec.whatwg.org/#list) of encoded video data outputs emitted by
 [`[[codec implementation]]`](#dom-videoencoder-codec-implementation-slot).

 5. If `encoded outputs` is not empty, [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the [Output
 EncodedVideoChunks](#output-encodedvideochunks) algorithm with
 `encoded outputs`.

 5. Return `"processed"`.

[`flush()`]

: Completes all [control
 messages](#control-message) in the [control message
 queue](#control-message-queue) and emits all outputs.

 When invoked, run these steps:

 1. If
 [`[[state]]`](#dom-videoencoder-state-slot) is not `"configured"`, return [a promise
 rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with)
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. Let `promise` be a new Promise.

 3. Append `promise` to
 [`[[pending flush promises]]`](#dom-videoencoder-pending-flush-promises-slot).

 4. [Queue a control
 message](#enqueues-a-control-message) to flush the codec with `promise`.

 5. [Process the control message
 queue](#process-the-control-message-queue).

 6. Return `promise`.

 [Running a control
 message](#running-a-control-message) to flush the codec means performing these steps
 with `promise`:

 1. Enqueue the following steps to the
 [`[[codec work queue]]`](#dom-videoencoder-codec-work-queue-slot):

 1. Signal
 [`[[codec implementation]]`](#dom-videoencoder-codec-implementation-slot) to emit all [internal pending
 outputs](#internal-pending-output).

 2. Let `encoded outputs` be a
 [list](https://infra.spec.whatwg.org/#list) of encoded video data outputs emitted by
 [`[[codec implementation]]`](#dom-videoencoder-codec-implementation-slot).

 3. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to perform these steps:

 1. If `encoded outputs` is not empty, run the
 [Output
 EncodedVideoChunks](#output-encodedvideochunks) algorithm with
 `encoded outputs`.

 2. Remove `promise` from
 [`[[pending flush promises]]`](#dom-videoencoder-pending-flush-promises-slot).

 3. Resolve `promise`.

 2. Return `"processed"`.

[`reset()`]

: Immediately resets all state including configuration, [control
 messages](#control-message) in the [control message
 queue](#control-message-queue), and all pending callbacks.

 When invoked, run the [Reset
 VideoEncoder](#reset-videoencoder) algorithm with an
 [`AbortError`](https://webidl.spec.whatwg.org/#aborterror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

[`close()`]

: Immediately aborts all pending work and releases [system
 resources](#system-resources). Close is final.

 When invoked, run the [Close
 VideoEncoder](#close-videoencoder) algorithm with an
 [`AbortError`](https://webidl.spec.whatwg.org/#aborterror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

[`isConfigSupported(config)`]

: Returns a promise indicating whether the provided
 `config` is supported by the User Agent.

 [NOTE:] The returned
 [`VideoEncoderSupport`](#dictdef-videoencodersupport)
 [`config`](#dom-videoencodersupport-config) will contain only the dictionary members that User
 Agent recognized. Unrecognized dictionary members will be ignored.
 Authors can detect unrecognized dictionary members by comparing
 [`config`](#dom-videoencodersupport-config) to their provided `config`.

 When invoked, run these steps:

 1. If `config` is not a [valid
 VideoEncoderConfig](#valid-videoencoderconfig), return [a promise rejected
 with](https://webidl.spec.whatwg.org/#a-promise-rejected-with)
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 2. Let `p` be a new Promise.

 3. Let `checkSupportQueue` be the result of starting a
 new [parallel
 queue](https://html.spec.whatwg.org/multipage/infrastructure.html#parallel-queue).

 4. Enqueue the following steps to `checkSupportQueue`:

 1. Let `supported` be the result of running the
 [Check Configuration
 Support](#check-configuration-support) algorithm with `config`.

 2. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the following steps:

 1. Let `encoderSupport` be a newly constructed
 [`VideoEncoderSupport`](#dictdef-videoencodersupport), initialized as follows:

 1. Set
 [`config`](#dom-videoencodersupport-config) to the result of running the [Clone
 Configuration](#clone-configuration) algorithm with `config`.

 2. Set
 [`supported`](#dom-videoencodersupport-supported) to `supported`.

 3. Resolve `p` with `encoderSupport`.

 5. Return `p`.

### 6.6. Algorithms

[Schedule Dequeue Event]

: 1. If
 [`[[dequeue event scheduled]]`](#dom-videoencoder-dequeue-event-scheduled-slot) equals `true`, return.

 2. Assign `true` to
 [`[[dequeue event scheduled]]`](#dom-videoencoder-dequeue-event-scheduled-slot).

 3. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the following steps:

 1. Fire a simple event named
 [`dequeue`](#eventdef-videoencoder-dequeue) at
 [this](https://webidl.spec.whatwg.org/#this).

 2. Assign `false` to
 [`[[dequeue event scheduled]]`](#dom-videoencoder-dequeue-event-scheduled-slot).

[Output EncodedVideoChunks] (with `outputs`)
: Run these steps:
 1. For each `output` in `outputs`:

 1. Let `chunkInit` be an
 [`EncodedVideoChunkInit`](#dictdef-encodedvideochunkinit) with the following keys:

 1. Let
 [`data`](#dom-encodedvideochunkinit-data) contain the encoded video data from
 `output`.

 2. Let
 [`type`](#dom-encodedvideochunkinit-type) be the
 [`EncodedVideoChunkType`](#enumdef-encodedvideochunktype) of `output`.

 3. Let
 [`timestamp`](#dom-encodedvideochunkinit-timestamp) be the
 [`[[timestamp]]`](#dom-videoframe-timestamp-slot) from the
 [`VideoFrame`](#videoframe) associated with `output`.

 4. Let
 [`duration`](#dom-encodedvideochunkinit-duration) be the
 [`[[duration]]`](#dom-videoframe-duration-slot) from the
 [`VideoFrame`](#videoframe) associated with `output`.

 2. Let `chunk` be a new
 [`EncodedVideoChunk`](#encodedvideochunk) constructed with `chunkInit`.

 3. Let `chunkMetadata` be a new
 [`EncodedVideoChunkMetadata`](#dictdef-encodedvideochunkmetadata).

 4. Let `encoderConfig` be the
 [`[[active encoder config]]`](#dom-videoencoder-active-encoder-config-slot).

 5. Let `outputConfig` be a
 [`VideoDecoderConfig`](#dictdef-videodecoderconfig) that describes `output`.
 Initialize `outputConfig` as follows:

 1. Assign `encoderConfig.codec` to `outputConfig.codec`.

 2. Assign `encoderConfig.width` to
 `outputConfig.codedWidth`.

 3. Assign `encoderConfig.height` to
 `outputConfig.codedHeight`.

 4. Assign `encoderConfig.displayWidth` to
 `outputConfig.displayAspectWidth`.

 5. Assign `encoderConfig.displayHeight` to
 `outputConfig.displayAspectHeight`.

 6. Assign
 [`[[rotation]]`](#dom-videoframe-rotation-slot) from the
 [`VideoFrame`](#videoframe) associated with `output` to
 `outputConfig.rotation`.

 7. Assign
 [`[[flip]]`](#dom-videoframe-flip-slot) from the
 [`VideoFrame`](#videoframe) associated with `output` to
 `outputConfig.flip`.

 8. Assign the remaining keys of `outputConfig` as
 determined by
 [`[[codec implementation]]`](#dom-videoencoder-codec-implementation-slot). The User Agent *MUST* ensure that the
 configuration is completely described such that
 `outputConfig` could be used to correctly
 decode `output`.

 [NOTE:] The codec specific requirements for
 populating the
 [`description`](#dom-videodecoderconfig-description) are described in the
 [\[WEBCODECS-CODEC-REGISTRY\]](#biblio-webcodecs-codec-registry "WebCodecs Codec Registry").

 6. If `outputConfig` and
 [`[[active output config]]`](#dom-videoencoder-active-output-config-slot) are not [equal
 dictionaries](#equal-dictionaries):

 1. Assign `outputConfig` to
 `chunkMetadata`.[`decoderConfig`](#dom-encodedvideochunkmetadata-decoderconfig).

 2. Assign `outputConfig` to
 [`[[active output config]]`](#dom-videoencoder-active-output-config-slot).

 7. If
 `encoderConfig`.[`scalabilityMode`](#dom-videoencoderconfig-scalabilitymode) describes multiple [temporal
 layers](#temporal-layer):

 1. Let `svc` be a new
 [`SvcOutputMetadata`](#dictdef-svcoutputmetadata) instance.

 2. Let `temporal_layer_id` be the zero-based
 index describing the temporal layer for
 `output`.

 3. Assign `temporal_layer_id` to
 `svc`.[`temporalLayerId`](#dom-svcoutputmetadata-temporallayerid).

 4. Assign `svc` to
 `chunkMetadata`.[`svc`](#dom-encodedvideochunkmetadata-svc).

 8. If
 `encoderConfig`.[`alpha`](#dom-videoencoderconfig-alpha) is set to `"keep"`:

 1. Let `alphaSideData` be the encoded alpha data
 in `output`.

 2. Assign `alphaSideData` to
 `chunkMetadata`.[`alphaSideData`](#dom-encodedvideochunkmetadata-alphasidedata).

 9. Invoke
 [`[[output callback]]`](#dom-videoencoder-output-callback-slot) with `chunk` and
 `chunkMetadata`.

[Reset VideoEncoder] (with `exception`)
: Run these steps:
 1. If
 [`[[state]]`](#dom-videoencoder-state-slot) is `"closed"`, throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror).

 2. Set
 [`[[state]]`](#dom-videoencoder-state-slot) to `"unconfigured"`.

 3. Set
 [`[[active encoder config]]`](#dom-videoencoder-active-encoder-config-slot) to `null`.

 4. Set
 [`[[active output config]]`](#dom-videoencoder-active-output-config-slot) to `null`.

 5. Signal
 [`[[codec implementation]]`](#dom-videoencoder-codec-implementation-slot) to cease producing output for the previous
 configuration.

 6. Remove all [control
 messages](#control-message) from the
 [`[[control message queue]]`](#dom-videoencoder-control-message-queue-slot).

 7. If
 [`[[encodeQueueSize]]`](#dom-videoencoder-encodequeuesize-slot) is greater than zero:

 1. Set
 [`[[encodeQueueSize]]`](#dom-videoencoder-encodequeuesize-slot) to zero.

 2. Run the [Schedule Dequeue
 Event](#videoencoder-schedule-dequeue-event) algorithm.

 8. For each `promise` in
 [`[[pending flush promises]]`](#dom-videoencoder-pending-flush-promises-slot):

 1. Reject `promise` with `exception`.

 2. Remove `promise` from
 [`[[pending flush promises]]`](#dom-videoencoder-pending-flush-promises-slot).

[Close VideoEncoder] (with `exception`)
: Run these steps:
 1. Run the [Reset
 VideoEncoder](#reset-videoencoder) algorithm with `exception`.

 2. Set
 [`[[state]]`](#dom-videoencoder-state-slot) to `"closed"`.

 3. Clear
 [`[[codec implementation]]`](#dom-videoencoder-codec-implementation-slot) and release associated [system
 resources](#system-resources).

 4. If `exception` is not an
 [`AbortError`](https://webidl.spec.whatwg.org/#aborterror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException), invoke the
 [`[[error callback]]`](#dom-videoencoder-error-callback-slot) with `exception`.

### 6.7. EncodedVideoChunkMetadata

The following metadata dictionary is emitted by the
[`EncodedVideoChunkOutputCallback`](#callbackdef-encodedvideochunkoutputcallback) alongside an associated
[`EncodedVideoChunk`](#encodedvideochunk).

```
dictionary EncodedVideoChunkMetadata {
 VideoDecoderConfig decoderConfig;
 SvcOutputMetadata svc;
 BufferSource alphaSideData;
};

dictionary SvcOutputMetadata {
 unsigned long temporalLayerId;
};
```

[`decoderConfig`], of type [VideoDecoderConfig](#dictdef-videodecoderconfig)

: A
 [`VideoDecoderConfig`](#dictdef-videodecoderconfig) that authors *MAY* use to decode the associated
 [`EncodedVideoChunk`](#encodedvideochunk).

[`svc`], of type [SvcOutputMetadata](#dictdef-svcoutputmetadata)

: A collection of metadata describing this
 [`EncodedVideoChunk`](#encodedvideochunk) with respect to the configured
 [`scalabilityMode`](#dom-videoencoderconfig-scalabilitymode).

[`alphaSideData`], of type [BufferSource](https://webidl.spec.whatwg.org/#BufferSource)

: A
 [`BufferSource`](https://webidl.spec.whatwg.org/#BufferSource) that contains the
 [`EncodedVideoChunk`](#encodedvideochunk)'s extra alpha channel data.

[`temporalLayerId`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long)

: A number that identifies the [temporal
 layer](#temporal-layer)
 for the associated
 [`EncodedVideoChunk`](#encodedvideochunk).

## 7. Configurations

### [7.1. ][[Check Configuration Support] (with `config`)]
Run these steps:

1. If the [codec string](#codec-string) in `config`.codec is not a [valid codec
 string](#valid-codec-string) or is otherwise unrecognized by the User Agent,
 return `false`.

2. If `config` is an
 [`AudioDecoderConfig`](#dictdef-audiodecoderconfig) or
 [`VideoDecoderConfig`](#dictdef-videodecoderconfig) and the User Agent can't provide a
 [codec](#codec) that can decode
 the exact profile (where present), level (where present), and
 constraint bits (where present) indicated by the [codec
 string](#codec-string) in
 `config`.codec, return `false`.

3. If `config` is an
 [`AudioEncoderConfig`](#dictdef-audioencoderconfig) or
 [`VideoEncoderConfig`](#dictdef-videoencoderconfig):

 1. If the [codec string](#codec-string) in `config`.codec contains a profile
 and the User Agent can't provide a
 [codec](#codec) that can
 encode the exact profile indicated by `config`.codec,
 return `false`.

 2. If the [codec string](#codec-string) in `config`.codec contains a level
 and the User Agent can't provide a
 [codec](#codec) that can
 encode to a level less than or equal to the level indicated by
 `config`.codec, return `false`.

 3. If the [codec string](#codec-string) in `config`.codec contains
 constraint bits and the User Agent can't provide a
 [codec](#codec) that can
 produce an encoded bitstream at least as constrained as
 indicated by `config`.codec, return `false`.

4. If the User Agent can provide a [codec](#codec) to support all entries of the `config`,
 including applicable default values for keys that are not included,
 return `true`.

 [NOTE:] The types
 [`AudioDecoderConfig`](#dictdef-audiodecoderconfig),
 [`VideoDecoderConfig`](#dictdef-videodecoderconfig),
 [`AudioEncoderConfig`](#dictdef-audioencoderconfig), and
 [`VideoEncoderConfig`](#dictdef-videoencoderconfig) each define their respective configuration entries
 and defaults.

 [NOTE:] Support for a given configuration can change
 dynamically if the hardware is altered (e.g. external GPU unplugged)
 or if essential hardware resources are exhausted. User Agents
 describe support on a best-effort basis given the resources that are
 available at the time of the query.

5. Otherwise, return false.

### [7.2. ][[Clone Configuration] (with `config`)]
[NOTE:] This algorithm will copy only the dictionary members
that the User Agent recognizes as part of the dictionary type.

Run these steps:

1. Let `dictType` be the type of dictionary
 `config`.

2. Let `clone` be a new empty instance of
 `dictType`.

3. For each dictionary member `m` defined on
 `dictType`:

 1. If `m` does not
 [exist](https://infra.spec.whatwg.org/#map-exists) in `config`, then
 [continue](https://infra.spec.whatwg.org/#iteration-continue).

 2. If `config[m]` is a nested dictionary, set `clone[m]` to the
 result of recursively running the [Clone
 Configuration](#clone-configuration) algorithm with `config[m]`.

 3. Otherwise, assign a copy of `config[m]` to `clone[m]`.

 This implements a \"deep-copy\". These configuration
objects are frequently used as the input of asynchronous operations.
Copying means that modifying the original object while the operation is
in flight won't change the operation's outcome.

### 7.3. Signalling Configuration Support

#### 7.3.1. AudioDecoderSupport

```
dictionary AudioDecoderSupport {
 boolean supported;
 AudioDecoderConfig config;
};
```

[`supported`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean)
: A boolean indicating the whether the corresponding
 [`config`](#dom-audiodecodersupport-config) is supported by the User Agent.

[`config`], of type [AudioDecoderConfig](#dictdef-audiodecoderconfig)
: An
 [`AudioDecoderConfig`](#dictdef-audiodecoderconfig) used by the User Agent in determining the value of
 [`supported`](#dom-audiodecodersupport-supported).

#### 7.3.2. VideoDecoderSupport

```
dictionary VideoDecoderSupport {
 boolean supported;
 VideoDecoderConfig config;
};
```

[`supported`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean)
: A boolean indicating the whether the corresponding
 [`config`](#dom-videodecodersupport-config) is supported by the User Agent.

[`config`], of type [VideoDecoderConfig](#dictdef-videodecoderconfig)
: A
 [`VideoDecoderConfig`](#dictdef-videodecoderconfig) used by the User Agent in determining the value of
 [`supported`](#dom-videodecodersupport-supported).

#### 7.3.3. AudioEncoderSupport

```
dictionary AudioEncoderSupport {
 boolean supported;
 AudioEncoderConfig config;
};
```

[`supported`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean)
: A boolean indicating the whether the corresponding
 [`config`](#dom-audioencodersupport-config) is supported by the User Agent.

[`config`], of type [AudioEncoderConfig](#dictdef-audioencoderconfig)
: An
 [`AudioEncoderConfig`](#dictdef-audioencoderconfig) used by the User Agent in determining the value of
 [`supported`](#dom-audioencodersupport-supported).

#### 7.3.4. VideoEncoderSupport

```
dictionary VideoEncoderSupport {
 boolean supported;
 VideoEncoderConfig config;
};
```

[`supported`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean)
: A boolean indicating the whether the corresponding
 [`config`](#dom-videoencodersupport-config) is supported by the User Agent.

[`config`], of type [VideoEncoderConfig](#dictdef-videoencoderconfig)
: A
 [`VideoEncoderConfig`](#dictdef-videoencoderconfig) used by the User Agent in determining the value of
 [`supported`](#dom-videoencodersupport-supported).

### [7.4. ][[Codec String]]
A codec string describes a given codec format to be used for encoding or
decoding.

A [valid codec string] *MUST* meet the following conditions.

1. Is valid per the relevant codec specification (see examples below).

2. It describes a single codec.

3. It is unambiguous about codec profile, level, and constraint bits
 for codecs that define these concepts.

[NOTE:] In other media specifications, codec strings
historically accompanied a [MIME
type](https://mimesniff.spec.whatwg.org/#mime-type) as the \"codecs=\" parameter
([`isTypeSupported()`](https://w3c.github.io/media-source/#dom-mediasource-istypesupported),
[`canPlayType()`](https://html.spec.whatwg.org/multipage/media.html#dom-navigator-canplaytype))
[\[RFC6381\]](#biblio-rfc6381 "The 'Codecs' and 'Profiles' Parameters for "Bucket" Media Types").
In this specification, encoded media is not containerized; hence, only
the value of the codecs parameter is accepted.

[NOTE:] Encoders for codecs that define level and constraint
bits have flexibility around these parameters, but won't produce
bitstreams that have a higher level or are less constrained than
requested.

The format and semantics for codec strings are defined by codec
registrations listed in the
[\[WEBCODECS-CODEC-REGISTRY\]](#biblio-webcodecs-codec-registry "WebCodecs Codec Registry").
A compliant implementation *MAY* support any combination of codec
registrations or none at all.

### 7.5. AudioDecoderConfig

```
dictionary AudioDecoderConfig {
 required DOMString codec;
 [EnforceRange] required unsigned long sampleRate;
 [EnforceRange] required unsigned long numberOfChannels;
 AllowSharedBufferSource description;
};
```

To check if an
[`AudioDecoderConfig`](#dictdef-audiodecoderconfig) is a [valid
AudioDecoderConfig], run these steps:

1. If
 [`codec`](#dom-audiodecoderconfig-codec) is empty after [stripping leading and trailing
 ASCII
 whitespace](https://infra.spec.whatwg.org/#strip-leading-and-trailing-ascii-whitespace), return `false`.

2. If
 [`description`](#dom-audiodecoderconfig-description) is
 \[[detached](https://webidl.spec.whatwg.org/#buffersource-detached)\], return false.

3. Return `true`.

[`codec`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString)
: Contains a [codec string](#codec-string) in `config`.codec describing the codec.

[`sampleRate`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long)
: The number of frame samples per second.

[`numberOfChannels`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long)
: The number of audio channels.

[`description`], of type [AllowSharedBufferSource](https://webidl.spec.whatwg.org/#AllowSharedBufferSource)

: A sequence of codec specific bytes, commonly known as extradata.

 [NOTE:] The registrations in the
 [\[WEBCODECS-CODEC-REGISTRY\]](#biblio-webcodecs-codec-registry "WebCodecs Codec Registry")
 describe whether/how to populate this sequence, corresponding to the
 provided
 [`codec`](#dom-audiodecoderconfig-codec).

### 7.6. VideoDecoderConfig

```
dictionary VideoDecoderConfig {
 required DOMString codec;
 AllowSharedBufferSource description;
 [EnforceRange] unsigned long codedWidth;
 [EnforceRange] unsigned long codedHeight;
 [EnforceRange] unsigned long displayAspectWidth;
 [EnforceRange] unsigned long displayAspectHeight;
 VideoColorSpaceInit colorSpace;
 HardwareAcceleration hardwareAcceleration = "no-preference";
 boolean optimizeForLatency;
 double rotation = 0;
 boolean flip = false;
};
```

To check if a
[`VideoDecoderConfig`](#dictdef-videodecoderconfig) is a [valid
VideoDecoderConfig], run these steps:

1. If
 [`codec`](#dom-videodecoderconfig-codec) is empty after [stripping leading and trailing
 ASCII
 whitespace](https://infra.spec.whatwg.org/#strip-leading-and-trailing-ascii-whitespace), return `false`.

2. If one of
 [`codedWidth`](#dom-videodecoderconfig-codedwidth) or
 [`codedHeight`](#dom-videodecoderconfig-codedheight) is provided but the other isn't, return `false`.

3. If
 [`codedWidth`](#dom-videodecoderconfig-codedwidth) = 0 or
 [`codedHeight`](#dom-videodecoderconfig-codedheight) = 0, return `false`.

4. If one of
 [`displayAspectWidth`](#dom-videodecoderconfig-displayaspectwidth) or
 [`displayAspectHeight`](#dom-videodecoderconfig-displayaspectheight) is provided but the other isn't, return `false`.

5. If
 [`displayAspectWidth`](#dom-videodecoderconfig-displayaspectwidth) = 0 or
 [`displayAspectHeight`](#dom-videodecoderconfig-displayaspectheight) = 0, return `false`.

6. If
 [`description`](#dom-videodecoderconfig-description) is
 \[[detached](https://webidl.spec.whatwg.org/#buffersource-detached)\], return false.

7. Return `true`.

[`codec`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString)
: Contains a [codec string](#codec-string) describing the codec.

[`description`], of type [AllowSharedBufferSource](https://webidl.spec.whatwg.org/#AllowSharedBufferSource)

: A sequence of codec specific bytes, commonly known as extradata.

 [NOTE:] The registrations in the
 [\[WEBCODECS-CODEC-REGISTRY\]](#biblio-webcodecs-codec-registry "WebCodecs Codec Registry")
 describes whether/how to populate this sequence, corresponding to
 the provided
 [`codec`](#dom-videodecoderconfig-codec).

[`codedWidth`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long)
: Width of the VideoFrame in pixels, potentially including non-visible
 padding, and prior to considering potential ratio adjustments.

[`codedHeight`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long)

: Height of the VideoFrame in pixels, potentially including
 non-visible padding, and prior to considering potential ratio
 adjustments.

 [NOTE:]
 [`codedWidth`](#dom-videodecoderconfig-codedwidth) and
 [`codedHeight`](#dom-videodecoderconfig-codedheight) are used when selecting a
 [`[[codec implementation]]`](#dom-videodecoder-codec-implementation-slot).

[`displayAspectWidth`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long)
: Horizontal dimension of the VideoFrame's aspect ratio when
 displayed.

[`displayAspectHeight`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long)

: Vertical dimension of the VideoFrame's aspect ratio when displayed.

 [NOTE:]
 [`displayWidth`](#dom-videoframe-displaywidth) and
 [`displayHeight`](#dom-videoframe-displayheight) can both be different from
 [`displayAspectWidth`](#dom-videodecoderconfig-displayaspectwidth) and
 [`displayAspectHeight`](#dom-videodecoderconfig-displayaspectheight), but have identical ratios, after scaling is
 applied when [creating the video
 frame](#create-a-videoframe).

[`colorSpace`], of type [VideoColorSpaceInit](#dictdef-videocolorspaceinit)
: Configures the
 [`VideoFrame`](#videoframe).[`colorSpace`](#dom-videoframe-colorspace) for
 [`VideoFrame`](#videoframe)s associated with this
 [`VideoDecoderConfig`](#dictdef-videodecoderconfig). If
 [`colorSpace`](#dom-videodecoderconfig-colorspace)
 [exists](https://infra.spec.whatwg.org/#map-exists), the provided values will override any in-band
 values from the bitsream.

[`hardwareAcceleration`], of type [HardwareAcceleration](#enumdef-hardwareacceleration), defaulting to `"no-preference"`
: Hint that configures hardware acceleration for this codec. See
 [`HardwareAcceleration`](#enumdef-hardwareacceleration).

[`optimizeForLatency`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean)

: Hint that the selected decoder *SHOULD* be configured to minimize
 the number of
 [`EncodedVideoChunk`](#encodedvideochunk)s that have to be decoded before a
 [`VideoFrame`](#videoframe) is output.

 [NOTE:] In addition to User Agent and hardware limitations,
 some codec bitstreams require a minimum number of inputs before any
 output can be produced.

[`rotation`], of type [double](https://webidl.spec.whatwg.org/#idl-double), defaulting to `0`
: Sets the
 [`rotation`](#dom-videoframe-rotation) attribute on decoded frames.

[`flip`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`
: Sets the
 [`flip`](#dom-videoframe-flip) attribute on decoded frames.

### 7.7. AudioEncoderConfig

```
dictionary AudioEncoderConfig {
 required DOMString codec;
 [EnforceRange] required unsigned long sampleRate;
 [EnforceRange] required unsigned long numberOfChannels;
 [EnforceRange] unsigned long long bitrate;
 BitrateMode bitrateMode = "variable";
};
```

[NOTE:] Codec-specific extensions to
[`AudioEncoderConfig`](#dictdef-audioencoderconfig) are described in their registrations in the
[\[WEBCODECS-CODEC-REGISTRY\]](#biblio-webcodecs-codec-registry "WebCodecs Codec Registry").

To check if an
[`AudioEncoderConfig`](#dictdef-audioencoderconfig) is a [valid
AudioEncoderConfig], run these steps:

1. If
 [`codec`](#dom-audioencoderconfig-codec) is empty after [stripping leading and trailing
 ASCII
 whitespace](https://infra.spec.whatwg.org/#strip-leading-and-trailing-ascii-whitespace), return `false`.

2. If the
 [`AudioEncoderConfig`](#dictdef-audioencoderconfig) has a codec-specific extension and the
 corresponding registration in the
 [\[WEBCODECS-CODEC-REGISTRY\]](#biblio-webcodecs-codec-registry "WebCodecs Codec Registry")
 defines steps to check whether the extension is a valid extension,
 return the result of running those steps.

3. If
 [`sampleRate`](#dom-audioencoderconfig-samplerate) or
 [`numberOfChannels`](#dom-audioencoderconfig-numberofchannels) are equal to zero, return `false`.

4. Return `true`.

[`codec`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString)
: Contains a [codec string](#codec-string) describing the codec.

[`sampleRate`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long)
: The number of frame samples per second.

[`numberOfChannels`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long)
: The number of audio channels.

[`bitrate`], of type [unsigned long long](https://webidl.spec.whatwg.org/#idl-unsigned-long-long)
: The average bitrate of the encoded audio given in units of bits per
 second.

[`bitrateMode`], of type [BitrateMode](https://w3c.github.io/mediacapture-record/#enumdef-bitratemode), defaulting to `"variable"`

: Configures the encoder to use a
 [`constant`](https://w3c.github.io/mediacapture-record/#dom-bitratemode-constant) or
 [`variable`](https://w3c.github.io/mediacapture-record/#dom-bitratemode-variable) bitrate as defined by
 [\[MEDIASTREAM-RECORDING\]](#biblio-mediastream-recording "MediaStream Recording").

 [NOTE:] Not all audio codecs support specific
 [`BitrateMode`](https://w3c.github.io/mediacapture-record/#enumdef-bitratemode)s, Authors are encouraged to check by calling
 [`isConfigSupported()`](#dom-audioencoder-isconfigsupported) with `config`.

### 7.8. VideoEncoderConfig

```
dictionary VideoEncoderConfig {
 required DOMString codec;
 [EnforceRange] required unsigned long width;
 [EnforceRange] required unsigned long height;
 [EnforceRange] unsigned long displayWidth;
 [EnforceRange] unsigned long displayHeight;
 [EnforceRange] unsigned long long bitrate;
 double framerate;
 HardwareAcceleration hardwareAcceleration = "no-preference";
 AlphaOption alpha = "discard";
 DOMString scalabilityMode;
 VideoEncoderBitrateMode bitrateMode = "variable";
 LatencyMode latencyMode = "quality";
 DOMString contentHint;
};
```

[NOTE:] Codec-specific extensions to
[`VideoEncoderConfig`](#dictdef-videoencoderconfig) are described in their registrations in the
[\[WEBCODECS-CODEC-REGISTRY\]](#biblio-webcodecs-codec-registry "WebCodecs Codec Registry").

To check if a
[`VideoEncoderConfig`](#dictdef-videoencoderconfig) is a [valid
VideoEncoderConfig], run these steps:

1. If
 [`codec`](#dom-videoencoderconfig-codec) is empty after [stripping leading and trailing
 ASCII
 whitespace](https://infra.spec.whatwg.org/#strip-leading-and-trailing-ascii-whitespace), return `false`.

2. If
 [`width`](#dom-videoencoderconfig-width) = 0 or
 [`height`](#dom-videoencoderconfig-height) = 0, return `false`.

3. If
 [`displayWidth`](#dom-videoencoderconfig-displaywidth) = 0 or
 [`displayHeight`](#dom-videoencoderconfig-displayheight) = 0, return `false`.

4. Return `true`.

[`codec`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString)
: Contains a [codec string](#codec-string) in `config`.codec describing the codec.

[`width`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long)

: The encoded width of output
 [`EncodedVideoChunk`](#encodedvideochunk)s in pixels, prior to any display aspect ratio
 adjustments.

 The encoder *MUST* scale any
 [`VideoFrame`](#videoframe) whose
 [`[[visible width]]`](#dom-videoframe-visible-width-slot) differs from this value.

[`height`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long)

: The encoded height of output
 [`EncodedVideoChunk`](#encodedvideochunk)s in pixels, prior to any display aspect ratio
 adjustments.

 The encoder *MUST* scale any
 [`VideoFrame`](#videoframe) whose
 [`[[visible height]]`](#dom-videoframe-visible-height-slot) differs from this value.

<!-- -->

[`displayWidth`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long)
: The intended display width of output
 [`EncodedVideoChunk`](#encodedvideochunk)s in pixels. Defaults to
 [`width`](#dom-videoencoderconfig-width) if not present.

[`displayHeight`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long)
: The intended display height of output
 [`EncodedVideoChunk`](#encodedvideochunk)s in pixels. Defaults to
 [`width`](#dom-videoencoderconfig-width) if not present.

NOTE: Providing a
[`displayWidth`](#dom-videoencoderconfig-displaywidth) or
[`displayHeight`](#dom-videoencoderconfig-displayheight) that differs from
[`width`](#dom-videoencoderconfig-width) and
[`height`](#dom-videoencoderconfig-height) signals that chunks are to be scaled after decoding to
arrive at the final display aspect ratio.

For many codecs this is merely pass-through information, but some codecs
can sometimes include display sizing in the bitstream.

[`bitrate`], of type [unsigned long long](https://webidl.spec.whatwg.org/#idl-unsigned-long-long)

: The average bitrate of the encoded video given in units of bits per
 second.

 [NOTE:] Authors are encouraged to additionally provide a
 [`framerate`](#dom-videoencoderconfig-framerate) to inform rate control.

[`framerate`], of type [double](https://webidl.spec.whatwg.org/#idl-double)
: The expected frame rate in frames per second, if known. This value,
 along with the frame
 [`timestamp`](#dom-videoframe-timestamp), *SHOULD* be used by the video encoder to calculate
 the optimal byte length for each encoded frame. Additionally, the
 value *SHOULD* be considered a target deadline for outputting
 encoding chunks when
 [`latencyMode`](#dom-videoencoderconfig-latencymode) is set to
 [`realtime`](#dom-latencymode-realtime).

[`hardwareAcceleration`], of type [HardwareAcceleration](#enumdef-hardwareacceleration), defaulting to `"no-preference"`
: Hint that configures hardware acceleration for this codec. See
 [`HardwareAcceleration`](#enumdef-hardwareacceleration).

[`alpha`], of type [AlphaOption](#enumdef-alphaoption), defaulting to `"discard"`
: Whether the alpha component of the
 [`VideoFrame`](#videoframe) inputs *SHOULD* be kept or discarded prior to
 encoding. If
 [`alpha`](#dom-videoencoderconfig-alpha) is equal to
 [`discard`](#dom-alphaoption-discard), alpha data is always discarded, regardless of a
 [`VideoFrame`](#videoframe)'s
 [`[[format]]`](#dom-videoframe-format-slot).

[`scalabilityMode`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString)
: An encoding [scalability mode
 identifier](https://www.w3.org/TR/webrtc-svc/#scalabilitymodes*) as defined by
 [\[WebRTC-SVC\]](#biblio-webrtc-svc "Scalable Video Coding (SVC) Extension for WebRTC").

[`bitrateMode`], of type [VideoEncoderBitrateMode](#enumdef-videoencoderbitratemode), defaulting to `"variable"`

: Configures encoding to use one of the rate control modes specified
 by
 [`VideoEncoderBitrateMode`](#enumdef-videoencoderbitratemode).

 [NOTE:] The precise degree of bitrate fluctuation in either
 mode is implementation defined.

[`latencyMode`], of type [LatencyMode](#enumdef-latencymode), defaulting to `"quality"`
: Configures latency related behaviors for this codec. See
 [`LatencyMode`](#enumdef-latencymode).

[`contentHint`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString)

: An encoding [video content
 hint](https://www.w3.org/TR/mst-content-hint/#video-content-hints) as defined by
 [\[mst-content-hint\]](#biblio-mst-content-hint "MediaStreamTrack Content Hints").

 The User Agent *MAY* use this hint to set expectations about
 incoming [`VideoFrame`](#videoframe)s and to improve encoding quality. If using this
 hint:

 - The User Agent *MUST* respect other explicitly set encoding
 options when configuring the encoder, whether they are
 codec-specific encoding options or not.

 - The User Agent *SHOULD* make a best-effort attempt to use
 additional configuration options to improve encoding quality,
 according to the goals defined by the corresponding [video content
 hint](https://www.w3.org/TR/mst-content-hint/#video-content-hints).

 [NOTE:] Some encoder options are implementation specific,
 and mappings between
 [`contentHint`](#dom-videoencoderconfig-contenthint) and those options cannot be prescribed.

 The User Agent *MUST NOT* refuse the configuration if it doesn't
 support this content hint. See
 [`isConfigSupported()`](#dom-videoencoder-isconfigsupported).

### 7.9. Hardware Acceleration

```
enum HardwareAcceleration {
 "no-preference",
 "prefer-hardware",
 "prefer-software",
};
```

When supported, hardware acceleration offloads encoding or decoding to
specialized hardware.
[`prefer-hardware`](#dom-hardwareacceleration-prefer-hardware) and
[`prefer-software`](#dom-hardwareacceleration-prefer-software) are hints. While User Agents *SHOULD* respect these
values when possible, User Agents may ignore these values in some or all
circumstances for any reason.

To prevent fingerprinting, if a User Agent implements
[\[media-capabilities\]](#biblio-media-capabilities "Media Capabilities"),
the User Agent *MUST* ensure rejection or acceptance of a given
[`HardwareAcceleration`](#enumdef-hardwareacceleration) preference reveals no additional information on top of
what is inherent to the User Agent and revealed by
[\[media-capabilities\]](#biblio-media-capabilities "Media Capabilities").
If a User Agent does not implement
[\[media-capabilities\]](#biblio-media-capabilities "Media Capabilities")
for reasons of fingerprinting, they *SHOULD* ignore the
[`HardwareAcceleration`](#enumdef-hardwareacceleration) preference.

NOTE: Good examples of when a User Agent can ignore
[`prefer-hardware`](#dom-hardwareacceleration-prefer-hardware) or
[`prefer-software`](#dom-hardwareacceleration-prefer-software) are for reasons of user privacy or circumstances where
the User Agent determines an alternative setting would better serve the
end user.

Most authors will be best served by using the default of
[`no-preference`](#dom-hardwareacceleration-no-preference). This gives the User Agent flexibility to optimize
based on its knowledge of the system and configuration. A common
strategy will be to prioritize hardware acceleration at higher
resolutions with a fallback to software codecs if hardware acceleration
fails.

Authors are encouraged to carefully weigh the tradeoffs when setting a
hardware acceleration preference. The precise tradeoffs will be
device-specific, but authors can generally expect the following:

- Setting a value of
 [`prefer-hardware`](#dom-hardwareacceleration-prefer-hardware) or
 [`prefer-software`](#dom-hardwareacceleration-prefer-software) can significantly restrict what configurations are
 supported. It can occur that the user's device does not offer
 acceleration for any codec, or only for the most common profiles of
 older codecs. It can also occur that a given User Agent lacks a
 software based codec implementation.

- Hardware acceleration does not simply imply faster encoding /
 decoding. Hardware acceleration often has higher startup latency but
 more consistent throughput performance. Acceleration will generally
 reduce CPU load.

- For decoding, hardware acceleration is often less robust to inputs
 that are mislabeled or violate the relevant codec specification.

- Hardware acceleration will often be more power efficient than purely
 software based codecs.

- For lower resolution content, the overhead added by hardware
 acceleration can yield decreased performance and power efficiency
 compared to purely software based codecs.

Given these tradeoffs, a good example of using \"prefer-hardware\" would
be if an author intends to provide their own software based fallback via
WebAssembly.

Alternatively, a good example of using \"prefer-software\" would be if
an author is especially sensitive to the higher startup latency or
decreased robustness generally associated with hardware acceleration.

[`no-preference`]
: Indicates that the User Agent *MAY* use hardware acceleration if it
 is available and compatible with other aspects of the codec
 configuration.

[`prefer-software`]

: Indicates that the User Agent *SHOULD* prefer a software codec
 implementation. User Agents may ignore this value for any reason.

 [NOTE:] This can cause the configuration to be unsupported
 on platforms where an unaccelerated codec is unavailable or is
 incompatible with other aspects of the codec configuration.

[`prefer-hardware`]

: Indicates that the User Agent *SHOULD* prefer hardware acceleration.
 User Agents may ignore this value for any reason.

 [NOTE:] This can cause the configuration to be unsupported
 on platforms where an accelerated codec is unavailable or is
 incompatible with other aspects of the codec configuration.

### 7.10. Alpha Option

```
enum AlphaOption {
 "keep",
 "discard",
};
```

Describes how the user agent *SHOULD* behave when dealing with alpha
channels, for a variety of different operations.

[`keep`]
: Indicates that the user agent *SHOULD* preserve alpha channel data
 for [`VideoFrame`](#videoframe)s, if it is present.

[`discard`]
: Indicates that the user agent *SHOULD* ignore or remove
 [`VideoFrame`](#videoframe)'s alpha channel data.

### 7.11. Latency Mode

```
enum LatencyMode {
 "quality",
 "realtime"
};
```

[`quality`]

: Indicates that the User Agent *SHOULD* optimize for encoding
 quality. In this mode:

 - User Agents *MAY* increase encoding latency to improve quality.

 - User Agents *MUST* not drop frames to achieve the target
 [`bitrate`](#dom-videoencoderconfig-bitrate) and/or
 [`framerate`](#dom-videoencoderconfig-framerate).

 - [`framerate`](#dom-videoencoderconfig-framerate) *SHOULD* not be used as a target deadline for
 emitting encoded chunks.

[`realtime`]

: Indicates that the User Agent *SHOULD* optimize for low latency. In
 this mode:

 - User Agents *MAY* sacrifice quality to improve latency.

 - User Agents *MAY* drop frames to achieve the target
 [`bitrate`](#dom-videoencoderconfig-bitrate) and/or
 [`framerate`](#dom-videoencoderconfig-framerate).

 - [`framerate`](#dom-videoencoderconfig-framerate) *SHOULD* be used as a target deadline for
 emitting encoded chunks.

### 7.12. Configuration Equivalence

Two dictionaries are [equal dictionaries] if they contain the same keys
and values. For nested dictionaries, apply this definition recursively.

### 7.13. VideoEncoderEncodeOptions

```
dictionary VideoEncoderEncodeOptions {
 boolean keyFrame = false;
};
```

[NOTE:] Codec-specific extensions to
[`VideoEncoderEncodeOptions`](#dictdef-videoencoderencodeoptions) are described in their registrations in the
[\[WEBCODECS-CODEC-REGISTRY\]](#biblio-webcodecs-codec-registry "WebCodecs Codec Registry").

[`keyFrame`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `false`
: A value of `true` indicates that the given frame *MUST* be encoded
 as a key frame. A value of `false` indicates that the User Agent has
 flexibility to decide whether the frame will be encoded as a [key
 frame](#key-chunk).

### 7.14. VideoEncoderBitrateMode

```
enum VideoEncoderBitrateMode {
 "constant",
 "variable",
 "quantizer"
};
```

[`constant`]
: Encode at a constant bitrate. See
 [`bitrate`](#dom-videoencoderconfig-bitrate).

[`variable`]
: Encode using a variable bitrate, allowing more space to be used for
 complex signals and less space for less complex signals. See
 [`bitrate`](#dom-videoencoderconfig-bitrate).

[`quantizer`]
: Encode using a quantizer, that is specified for each video frame in
 codec specific extensions of
 [`VideoEncoderEncodeOptions`](#dictdef-videoencoderencodeoptions).

### 7.15. CodecState

```
enum CodecState {
 "unconfigured",
 "configured",
 "closed"
};
```

[`unconfigured`]
: The codec is not configured for encoding or decoding.

[`configured`]
: A valid configuration has been provided. The codec is ready for
 encoding or decoding.

[`closed`]
: The codec is no longer usable and underlying [system
 resources](#system-resources) have been released.

### 7.16. WebCodecsErrorCallback

```
callback WebCodecsErrorCallback = undefined(DOMException error);
```

## 8. Encoded Media Interfaces (Chunks)

These interfaces represent chunks of encoded media.

### 8.1. EncodedAudioChunk Interface

```
[Exposed=(Window,DedicatedWorker), Serializable]
interface EncodedAudioChunk {
 constructor(EncodedAudioChunkInit init);
 readonly attribute EncodedAudioChunkType type;
 readonly attribute long long timestamp; // microseconds
 readonly attribute unsigned long long? duration; // microseconds
 readonly attribute unsigned long byteLength;

 undefined copyTo(AllowSharedBufferSource destination);
};

dictionary EncodedAudioChunkInit {
 required EncodedAudioChunkType type;
 [EnforceRange] required long long timestamp; // microseconds
 [EnforceRange] unsigned long long duration; // microseconds
 required AllowSharedBufferSource data;
 sequence<ArrayBuffer> transfer = ;
};

enum EncodedAudioChunkType {
 "key",
 "delta",
};
```

#### 8.1.1. Internal Slots

[`[[internal data]]`]

: An array of bytes representing the encoded chunk data.

[`[[type]]`]

: Describes whether the chunk is a [key
 chunk](#key-chunk).

[`[[timestamp]]`]

: The presentation timestamp, given in microseconds.

[`[[duration]]`]

: The presentation duration, given in microseconds.

[`[[byte length]]`]

: The byte length of
 [`[[internal data]]`](#dom-encodedaudiochunk-internal-data-slot).

#### 8.1.2. Constructors

[` EncodedAudioChunk(init) `]

1. If
 `init`.[`transfer`](#dom-encodedaudiochunkinit-transfer) contains more than one reference to the same
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer), then throw a
 [`DataCloneError`](https://webidl.spec.whatwg.org/#datacloneerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

2. For each `transferable` in
 `init`.[`transfer`](#dom-encodedaudiochunkinit-transfer):

 1. If
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached) internal slot is `true`, then throw a
 [`DataCloneError`](https://webidl.spec.whatwg.org/#datacloneerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

3. Let `chunk` be a new
 [`EncodedAudioChunk`](#encodedaudiochunk) object, initialized as follows

 1. Assign `init.type` to
 [`[[type]]`](#dom-encodedaudiochunk-type-slot).

 2. Assign `init.timestamp` to
 [`[[timestamp]]`](#dom-encodedaudiochunk-timestamp-slot).

 3. If `init.duration` exists, assign it to
 [`[[duration]]`](#dom-encodedaudiochunk-duration-slot), or assign `null` otherwise.

 4. Assign `init.data.byteLength` to
 [`[[byte length]]`](#dom-encodedaudiochunk-byte-length-slot);

 5. If
 `init`.[`transfer`](#dom-encodedaudiochunkinit-transfer) contains an
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) referenced by
 `init`.[`data`](#dom-encodedaudiochunkinit-data) the User Agent *MAY* choose to:

 1. Let `resource` be a new [media
 resource](#media-resource) referencing sample data in
 `init`.[`data`](#dom-encodedaudiochunkinit-data).

 6. Otherwise:

 1. Assign a copy of
 `init`.[`data`](#dom-encodedaudiochunkinit-data) to
 [`[[internal data]]`](#dom-encodedaudiochunk-internal-data-slot).

4. For each `transferable` in
 `init`.[`transfer`](#dom-encodedaudiochunkinit-transfer):

 1. Perform
 [DetachArrayBuffer](https://tc39.es/ecma262/#sec-detacharraybuffer)
 on `transferable`

5. Return `chunk`.

#### 8.1.3. Attributes

[`type`], of type [EncodedAudioChunkType](#enumdef-encodedaudiochunktype), readonly

: Returns the value of
 [`[[type]]`](#dom-encodedaudiochunk-type-slot).

[`timestamp`], of type [long long](https://webidl.spec.whatwg.org/#idl-long-long), readonly

: Returns the value of
 [`[[timestamp]]`](#dom-encodedaudiochunk-timestamp-slot).

[`duration`], of type [unsigned long long](https://webidl.spec.whatwg.org/#idl-unsigned-long-long), readonly, nullable

: Returns the value of
 [`[[duration]]`](#dom-encodedaudiochunk-duration-slot).

[`byteLength`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: Returns the value of
 [`[[byte length]]`](#dom-encodedaudiochunk-byte-length-slot).

#### 8.1.4. Methods

[`copyTo(destination)`]

: When invoked, run these steps:

 1. If the
 [`[[byte length]]`](#dom-encodedaudiochunk-byte-length-slot) of this
 [`EncodedAudioChunk`](#encodedaudiochunk) is greater than in `destination`,
 throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 2. Copy the
 [`[[internal data]]`](#dom-encodedaudiochunk-internal-data-slot) into `destination`.

#### 8.1.5. Serialization

The [`EncodedAudioChunk`](#encodedaudiochunk) [serialization steps](https://html.spec.whatwg.org/multipage/structured-data.html#serialization-steps) (with `value`, `serialized`, and `forStorage`) are:

: 1. If `forStorage` is `true`, throw a
 [`DataCloneError`](https://webidl.spec.whatwg.org/#datacloneerror).

 2. For each
 [`EncodedAudioChunk`](#encodedaudiochunk) internal slot in `value`, assign the
 value of each internal slot to a field in
 `serialized` with the same name as the internal slot.

The [`EncodedAudioChunk`](#encodedaudiochunk) [deserialization steps](https://html.spec.whatwg.org/multipage/structured-data.html#deserialization-steps) (with `serialized` and `value`) are:

: 1. For all named fields in `serialized`, assign the
 value of each named field to the
 [`EncodedAudioChunk`](#encodedaudiochunk) internal slot in `value` with the
 same name as the named field.

[NOTE:] Since
[`EncodedAudioChunk`](#encodedaudiochunk)s are immutable, User Agents can choose to implement
serialization using a reference counting model similar to [§ 9.2.6
Transfer and Serialization](#audiodata-transfer-serialization).

### 8.2. EncodedVideoChunk Interface

```
[Exposed=(Window,DedicatedWorker), Serializable]
interface EncodedVideoChunk {
 constructor(EncodedVideoChunkInit init);
 readonly attribute EncodedVideoChunkType type;
 readonly attribute long long timestamp; // microseconds
 readonly attribute unsigned long long? duration; // microseconds
 readonly attribute unsigned long byteLength;

 undefined copyTo(AllowSharedBufferSource destination);
};

dictionary EncodedVideoChunkInit {
 required EncodedVideoChunkType type;
 [EnforceRange] required long long timestamp; // microseconds
 [EnforceRange] unsigned long long duration; // microseconds
 required AllowSharedBufferSource data;
 sequence<ArrayBuffer> transfer = ;
};

enum EncodedVideoChunkType {
 "key",
 "delta",
};
```

#### 8.2.1. Internal Slots

[`[[internal data]]`]

: An array of bytes representing the encoded chunk data.

[`[[type]]`]

: The
 [`EncodedVideoChunkType`](#enumdef-encodedvideochunktype) of this
 [`EncodedVideoChunk`](#encodedvideochunk);

[`[[timestamp]]`]

: The presentation timestamp, given in microseconds.

[`[[duration]]`]

: The presentation duration, given in microseconds.

[`[[byte length]]`]

: The byte length of
 [`[[internal data]]`](#dom-encodedvideochunk-internal-data-slot).

#### 8.2.2. Constructors

[` EncodedVideoChunk(init) `]

1. If
 `init`.[`transfer`](#dom-encodedvideochunkinit-transfer) contains more than one reference to the same
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer), then throw a
 [`DataCloneError`](https://webidl.spec.whatwg.org/#datacloneerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

2. For each `transferable` in
 `init`.[`transfer`](#dom-encodedvideochunkinit-transfer):

 1. If
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached) internal slot is `true`, then throw a
 [`DataCloneError`](https://webidl.spec.whatwg.org/#datacloneerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

3. Let `chunk` be a new
 [`EncodedVideoChunk`](#encodedvideochunk) object, initialized as follows

 1. Assign `init.type` to
 [`[[type]]`](#dom-encodedvideochunk-type-slot).

 2. Assign `init.timestamp` to
 [`[[timestamp]]`](#dom-encodedvideochunk-timestamp-slot).

 3. If duration is present in init, assign `init.duration` to
 [`[[duration]]`](#dom-encodedvideochunk-duration-slot). Otherwise, assign `null` to
 [`[[duration]]`](#dom-encodedvideochunk-duration-slot).

 4. Assign `init.data.byteLength` to
 [`[[byte length]]`](#dom-encodedvideochunk-byte-length-slot);

 5. If
 `init`.[`transfer`](#dom-encodedvideochunkinit-transfer) contains an
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) referenced by
 `init`.[`data`](#dom-encodedvideochunkinit-data) the User Agent *MAY* choose to:

 1. Let `resource` be a new [media
 resource](#media-resource) referencing sample data in
 `init`.[`data`](#dom-encodedvideochunkinit-data).

 6. Otherwise:

 1. Assign a copy of
 `init`.[`data`](#dom-encodedvideochunkinit-data) to
 [`[[internal data]]`](#dom-encodedvideochunk-internal-data-slot).

4. For each `transferable` in
 `init`.[`transfer`](#dom-encodedvideochunkinit-transfer):

 1. Perform
 [DetachArrayBuffer](https://tc39.es/ecma262/#sec-detacharraybuffer)
 on `transferable`

5. Return `chunk`.

#### 8.2.3. Attributes

[`type`], of type [EncodedVideoChunkType](#enumdef-encodedvideochunktype), readonly

: Returns the value of
 [`[[type]]`](#dom-encodedvideochunk-type-slot).

[`timestamp`], of type [long long](https://webidl.spec.whatwg.org/#idl-long-long), readonly

: Returns the value of
 [`[[timestamp]]`](#dom-encodedvideochunk-timestamp-slot).

[`duration`], of type [unsigned long long](https://webidl.spec.whatwg.org/#idl-unsigned-long-long), readonly, nullable

: Returns the value of
 [`[[duration]]`](#dom-encodedvideochunk-duration-slot).

[`byteLength`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: Returns the value of
 [`[[byte length]]`](#dom-encodedvideochunk-byte-length-slot).

#### 8.2.4. Methods

[`copyTo(destination)`]

: When invoked, run these steps:

 1. If
 [`[[byte length]]`](#dom-encodedvideochunk-byte-length-slot) is greater than the
 [`[[byte length]]`](#dom-encodedvideochunk-byte-length-slot) of `destination`, throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 2. Copy the
 [`[[internal data]]`](#dom-encodedvideochunk-internal-data-slot) into `destination`.

#### 8.2.5. Serialization

The [`EncodedVideoChunk`](#encodedvideochunk) [serialization steps](https://html.spec.whatwg.org/multipage/structured-data.html#serialization-steps) (with `value`, `serialized`, and `forStorage`) are:

: 1. If `forStorage` is `true`, throw a
 [`DataCloneError`](https://webidl.spec.whatwg.org/#datacloneerror).

 2. For each
 [`EncodedVideoChunk`](#encodedvideochunk) internal slot in `value`, assign the
 value of each internal slot to a field in
 `serialized` with the same name as the internal slot.

The [`EncodedVideoChunk`](#encodedvideochunk) [deserialization steps](https://html.spec.whatwg.org/multipage/structured-data.html#deserialization-steps) (with `serialized` and `value`) are:

: 1. For all named fields in `serialized`, assign the
 value of each named field to the
 [`EncodedVideoChunk`](#encodedvideochunk) internal slot in `value` with the
 same name as the named field.

[NOTE:] Since
[`EncodedVideoChunk`](#encodedvideochunk)s are immutable, User Agents can choose to implement
serialization using a reference counting model similar to [§ 9.4.7
Transfer and Serialization](#videoframe-transfer-serialization).

## 9. Raw Media Interfaces

These interfaces represent unencoded (raw) media.

### 9.1. Memory Model

#### 9.1.1. Background

This section is non-normative.

Decoded media data *MAY* occupy a large amount of system memory. To
minimize the need for expensive copies, this specification defines a
scheme for reference counting (`clone()` and `close()`).

[NOTE:] Authors are encouraged to call `close()` immediately
when frames are no longer needed.

#### 9.1.2. Reference Counting

A [media resource] is storage for the actual pixel data or the audio sample
data described by a
[`VideoFrame`](#videoframe)
or [`AudioData`](#audiodata).

The [`AudioData`](#audiodata)
[`[[resource reference]]`](#dom-audiodata-resource-reference-slot) and
[`VideoFrame`](#videoframe)
[`[[resource reference]]`](#dom-videoframe-resource-reference-slot) internal slots hold a reference to a [media
resource](#media-resource).

[`VideoFrame`](#videoframe).[`clone()`](#dom-videoframe-clone) and [`AudioData`](#audiodata).[`clone()`](#dom-audiodata-clone) return new objects whose `[[resource reference]]`
points to the same [media
resource](#media-resource) as
the original object.

[`VideoFrame`](#videoframe).[`close()`](#dom-videoframe-close) and [`AudioData`](#audiodata).[`close()`](#dom-audiodata-close) will clear their `[[resource reference]]` slot,
releasing the reference their [media
resource](#media-resource).

A [media resource](#media-resource) *MUST* remain alive at least as long as it continues to
be referenced by a `[[resource reference]]`.

[NOTE:] When a [media
resource](#media-resource) is
no longer referenced by a `[[resource reference]]`, the resource can be
destroyed. User Agents are encouraged to destroy such resources quickly
to reduce memory pressure and facilitate resource reuse.

#### 9.1.3. Transfer and Serialization

This section is non-normative.

[`AudioData`](#audiodata) and
[`VideoFrame`](#videoframe)
are both
[transferable](https://html.spec.whatwg.org/multipage/structured-data.html#transferable-objects)
and
[serializable](https://html.spec.whatwg.org/multipage/structured-data.html#serializable-objects)
objects. Their transfer and serialization steps are defined in [§ 9.2.6
Transfer and Serialization](#audiodata-transfer-serialization) and
[§ 9.4.7 Transfer and Serialization](#videoframe-transfer-serialization)
respectively.

Transferring an [`AudioData`](#audiodata) or
[`VideoFrame`](#videoframe)
moves its `[[resource reference]]` to the destination object and closes
(as in
[`close()`](#dom-audiodata-close)) the source object. Authors *MAY* use this facility to
move an [`AudioData`](#audiodata) or
[`VideoFrame`](#videoframe)
between realms without copying the underlying [media
resource](#media-resource).

Serializing an [`AudioData`](#audiodata) or
[`VideoFrame`](#videoframe)
effectively clones (as in
[`clone()`](#dom-videoframe-clone)) the source object, resulting in two objects that
reference the same [media
resource](#media-resource).
Authors *MAY* use this facility to clone an
[`AudioData`](#audiodata) or
[`VideoFrame`](#videoframe)
to another realm without copying the underlying [media
resource](#media-resource).

### 9.2. AudioData Interface

```
[Exposed=(Window,DedicatedWorker), Serializable, Transferable]
interface AudioData {
 constructor(AudioDataInit init);

 readonly attribute AudioSampleFormat? format;
 readonly attribute float sampleRate;
 readonly attribute unsigned long numberOfFrames;
 readonly attribute unsigned long numberOfChannels;
 readonly attribute unsigned long long duration; // microseconds
 readonly attribute long long timestamp; // microseconds

 unsigned long allocationSize(AudioDataCopyToOptions options);
 undefined copyTo(AllowSharedBufferSource destination, AudioDataCopyToOptions options);
 AudioData clone();
 undefined close();
};

dictionary AudioDataInit {
 required AudioSampleFormat format;
 required float sampleRate;
 [EnforceRange] required unsigned long numberOfFrames;
 [EnforceRange] required unsigned long numberOfChannels;
 [EnforceRange] required long long timestamp; // microseconds
 required BufferSource data;
 sequence<ArrayBuffer> transfer = ;
};
```

#### 9.2.1. Internal Slots

[`[[resource reference]]`]

: A reference to a [media
 resource](#media-resource) that stores the audio sample data for this
 [`AudioData`](#audiodata).

[`[[format]]`]

: The
 [`AudioSampleFormat`](#enumdef-audiosampleformat) used by this
 [`AudioData`](#audiodata). Will be `null` whenever the underlying format does
 not map to an
 [`AudioSampleFormat`](#enumdef-audiosampleformat) or when
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached) is `true`.

[`[[sample rate]]`]

: The sample-rate, in Hz, for this
 [`AudioData`](#audiodata).

[`[[number of frames]]`]

: The number of [frames](#frame) for
 this [`AudioData`](#audiodata).

[`[[number of channels]]`]

: The number of audio channels for this
 [`AudioData`](#audiodata).

[`[[timestamp]]`]

: The presentation timestamp, in microseconds, for this
 [`AudioData`](#audiodata).

#### 9.2.2. Constructors

[` AudioData(init) `]

1. If `init` is not a [valid
 AudioDataInit](#valid-audiodatainit), throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

2. If
 `init`.[`transfer`](#dom-audiodatainit-transfer) contains more than one reference to the same
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer), then throw a
 [`DataCloneError`](https://webidl.spec.whatwg.org/#datacloneerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

3. For each `transferable` in
 `init`.[`transfer`](#dom-audiodatainit-transfer):

 1. If
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached) internal slot is `true`, then throw a
 [`DataCloneError`](https://webidl.spec.whatwg.org/#datacloneerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

4. Let `frame` be a new
 [`AudioData`](#audiodata) object, initialized as follows:

 1. Assign `false` to
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached).

 2. Assign
 `init`.[`format`](#dom-audiodatainit-format) to
 [`[[format]]`](#dom-audiodata-format-slot).

 3. Assign
 `init`.[`sampleRate`](#dom-audiodatainit-samplerate) to
 [`[[sample rate]]`](#dom-audiodata-sample-rate-slot).

 4. Assign
 `init`.[`numberOfFrames`](#dom-audiodatainit-numberofframes) to
 [`[[number of frames]]`](#dom-audiodata-number-of-frames-slot).

 5. Assign
 `init`.[`numberOfChannels`](#dom-audiodatainit-numberofchannels) to
 [`[[number of channels]]`](#dom-audiodata-number-of-channels-slot).

 6. Assign
 `init`.[`timestamp`](#dom-audiodatainit-timestamp) to
 [`[[timestamp]]`](#dom-audiodata-timestamp-slot).

 7. If
 `init`.[`transfer`](#dom-audiodatainit-transfer) contains an
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) referenced by
 `init`.[`data`](#dom-audiodatainit-data) the User Agent *MAY* choose to:

 1. Let `resource` be a new [media
 resource](#media-resource) referencing sample data in
 `data`.

 8. Otherwise:

 1. Let `resource` be a [media
 resource](#media-resource) containing a copy of
 `init`.[`data`](#dom-audiodatainit-data).

 9. Let `resourceReference` be a reference to
 `resource`.

 10. Assign `resourceReference` to
 [`[[resource reference]]`](#dom-audiodata-resource-reference-slot).

5. For each `transferable` in
 `init`.[`transfer`](#dom-audiodatainit-transfer):

 1. Perform
 [DetachArrayBuffer](https://tc39.es/ecma262/#sec-detacharraybuffer)
 on `transferable`

6. Return `frame`.

#### 9.2.3. Attributes

[`format`], of type [AudioSampleFormat](#enumdef-audiosampleformat), readonly, nullable

: The
 [`AudioSampleFormat`](#enumdef-audiosampleformat) used by this
 [`AudioData`](#audiodata). Will be `null` whenever the underlying format does
 not map to a
 [`AudioSampleFormat`](#enumdef-audiosampleformat) or when
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached) is `true`.

 The
 [`format`](#dom-audiodata-format) getter steps are to return
 [`[[format]]`](#dom-audiodata-format-slot).

[`sampleRate`], of type [float](https://webidl.spec.whatwg.org/#idl-float), readonly

: The sample-rate, in Hz, for this
 [`AudioData`](#audiodata).

 The
 [`sampleRate`](#dom-audiodata-samplerate) getter steps are to return
 [`[[sample rate]]`](#dom-audiodata-sample-rate-slot).

[`numberOfFrames`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: The number of [frames](#frame) for
 this [`AudioData`](#audiodata).

 The
 [`numberOfFrames`](#dom-audiodata-numberofframes) getter steps are to return
 [`[[number of frames]]`](#dom-audiodata-number-of-frames-slot).

[`numberOfChannels`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: The number of audio channels for this
 [`AudioData`](#audiodata).

 The
 [`numberOfChannels`](#dom-audiodata-numberofchannels) getter steps are to return
 [`[[number of channels]]`](#dom-audiodata-number-of-channels-slot).

[`timestamp`], of type [long long](https://webidl.spec.whatwg.org/#idl-long-long), readonly

: The presentation timestamp, in microseconds, for this
 [`AudioData`](#audiodata).

 The
 [`numberOfChannels`](#dom-audiodata-numberofchannels) getter steps are to return
 [`[[timestamp]]`](#dom-audiodata-timestamp-slot).

[`duration`], of type [unsigned long long](https://webidl.spec.whatwg.org/#idl-unsigned-long-long), readonly

: The duration, in microseconds, for this
 [`AudioData`](#audiodata).

 The
 [`duration`](#dom-audiodata-duration) getter steps are to:

 1. Let `microsecondsPerSecond` be `1,000,000`.

 2. Let `durationInSeconds` be the result of dividing
 [`[[number of frames]]`](#dom-audiodata-number-of-frames-slot) by
 [`[[sample rate]]`](#dom-audiodata-sample-rate-slot).

 3. Return the product of `durationInSeconds` and
 `microsecondsPerSecond`.

#### 9.2.4. Methods

[`allocationSize(``options``)`]

: Returns the number of bytes required to hold the samples as
 described by `options`.

 When invoked, run these steps:

 1. If
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached) is `true`, throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. Let `copyElementCount` be the result of running the
 [Compute Copy Element
 Count](#compute-copy-element-count) algorithm with `options`.

 3. Let `destFormat` be the value of
 [`[[format]]`](#dom-audiodata-format-slot).

 4. If
 `options`.[`format`](#dom-audiodatacopytooptions-format)
 [exists](https://infra.spec.whatwg.org/#map-exists), assign
 `options`.[`format`](#dom-audiodatacopytooptions-format) to `destFormat`.

 5. Let `bytesPerSample` be the number of bytes per
 sample, as defined by the `destFormat`.

 6. Return the product of multiplying `bytesPerSample` by
 `copyElementCount`.

[`copyTo(``destination``, ``options``)`]

: Copies the samples from the specified plane of the
 [`AudioData`](#audiodata) to the destination buffer.

 When invoked, run these steps:

 1. If
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached) is `true`, throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. Let `copyElementCount` be the result of running the
 [Compute Copy Element
 Count](#compute-copy-element-count) algorithm with `options`.

 3. Let `destFormat` be the value of
 [`[[format]]`](#dom-audiodata-format-slot).

 4. If
 `options`.[`format`](#dom-audiodatacopytooptions-format)
 [exists](https://infra.spec.whatwg.org/#map-exists), assign
 `options`.[`format`](#dom-audiodatacopytooptions-format) to `destFormat`.

 5. Let `bytesPerSample` be the number of bytes per
 sample, as defined by the `destFormat`.

 6. If the product of multiplying `bytesPerSample` by
 `copyElementCount` is greater than
 `destination.byteLength`, throw a
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror).

 7. Let `resource` be the [media
 resource](#media-resource) referenced by
 [`[[resource reference]]`](#dom-audiodata-resource-reference-slot).

 8. Let `planeFrames` be the region of
 `resource` corresponding to
 `options`.[`planeIndex`](#dom-audiodatacopytooptions-planeindex).

 9. Copy elements of `planeFrames` into
 `destination`, starting with the
 [frame](#frame) positioned at
 `options`.[`frameOffset`](#dom-audiodatacopytooptions-frameoffset) and stopping after
 `copyElementCount` samples have been copied. If
 `destFormat` does not equal
 [`[[format]]`](#dom-audiodata-format-slot), convert elements to the
 `destFormat`
 [`AudioSampleFormat`](#enumdef-audiosampleformat) while making the copy.

[`clone()`]

: Creates a new AudioData with a reference to the same [media
 resource](#media-resource).

 When invoked, run these steps:

 1. If
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached) is `true`, throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. Return the result of running the [Clone
 AudioData](#clone-audiodata) algorithm with
 [this](https://webidl.spec.whatwg.org/#this).

[`close()`]

: Clears all state and releases the reference to the [media
 resource](#media-resource). Close is final.

 When invoked, run the [Close
 AudioData](#close-audiodata) algorithm with
 [this](https://webidl.spec.whatwg.org/#this).

#### 9.2.5. Algorithms

[Compute Copy Element Count] (with `options`)

: Run these steps:

 1. Let `destFormat` be the value of
 [`[[format]]`](#dom-audiodata-format-slot).

 2. If
 `options`.[`format`](#dom-audiodatacopytooptions-format)
 [exists](https://infra.spec.whatwg.org/#map-exists), assign
 `options`.[`format`](#dom-audiodatacopytooptions-format) to `destFormat`.

 3. If `destFormat` describes an
 [interleaved](#interleaved)
 [`AudioSampleFormat`](#enumdef-audiosampleformat) and
 `options`.[`planeIndex`](#dom-audiodatacopytooptions-planeindex) is greater than `0`, throw a
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror).

 4. Otherwise, if `destFormat` describes a
 [planar](#planar)
 [`AudioSampleFormat`](#enumdef-audiosampleformat) and if
 `options`.[`planeIndex`](#dom-audiodatacopytooptions-planeindex) is greater or equal to
 [`[[number of channels]]`](#dom-audiodata-number-of-channels-slot), throw a
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror).

 5. If
 [`[[format]]`](#dom-audiodata-format-slot) does not equal `destFormat` and the
 User Agent does not support the requested
 [`AudioSampleFormat`](#enumdef-audiosampleformat) conversion, throw a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException). Conversion to
 [`f32-planar`](#dom-audiosampleformat-f32-planar) *MUST* always be supported.

 6. Let `frameCount` be the number of frames in the plane
 identified by
 `options`.[`planeIndex`](#dom-audiodatacopytooptions-planeindex).

 7. If
 `options`.[`frameOffset`](#dom-audiodatacopytooptions-frameoffset) is greater than or equal to
 `frameCount`, throw a
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror).

 8. Let `copyFrameCount` be the difference of subtracting
 `options`.[`frameOffset`](#dom-audiodatacopytooptions-frameoffset) from `frameCount`.

 9. If
 `options`.[`frameCount`](#dom-audiodatacopytooptions-framecount)
 [exists](https://infra.spec.whatwg.org/#map-exists):

 1. If
 `options`.[`frameCount`](#dom-audiodatacopytooptions-framecount) is greater than
 `copyFrameCount`, throw a
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror).

 2. Otherwise, assign
 `options`.[`frameCount`](#dom-audiodatacopytooptions-framecount) to `copyFrameCount`.

 10. Let `elementCount` be `copyFrameCount`.

 11. If `destFormat` describes an
 [interleaved](#interleaved)
 [`AudioSampleFormat`](#enumdef-audiosampleformat), multiply `elementCount` by
 [`[[number of channels]]`](#dom-audiodata-number-of-channels-slot)

 12. return `elementCount`.

[Clone AudioData] (with `data`)

: Run these steps:

 1. Let `clone` be a new
 [`AudioData`](#audiodata) initialized as follows:

 1. Let `resource` be the [media
 resource](#media-resource) referenced by `data`'s
 [`[[resource reference]]`](#dom-audiodata-resource-reference-slot).

 2. Let `reference` be a new reference to
 `resource`.

 3. Assign `reference` to
 [`[[resource reference]]`](#dom-audiodata-resource-reference-slot).

 4. Assign the values of `data`'s
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached),
 [`[[format]]`](#dom-audiodata-format-slot),
 [`[[sample rate]]`](#dom-audiodata-sample-rate-slot),
 [`[[number of frames]]`](#dom-audiodata-number-of-frames-slot),
 [`[[number of channels]]`](#dom-audiodata-number-of-channels-slot), and
 [`[[timestamp]]`](#dom-audiodata-timestamp-slot) slots to the corresponding slots in
 `clone`.

 2. Return `clone`.

[Close AudioData] (with `data`)

: Run these steps:

 1. Assign `true` to `data`'s
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached) internal slot.

 2. Assign `null` to `data`'s
 [`[[resource reference]]`](#dom-audiodata-resource-reference-slot).

 3. Assign `0` to `data`'s
 [`[[sample rate]]`](#dom-audiodata-sample-rate-slot).

 4. Assign `0` to `data`'s
 [`[[number of frames]]`](#dom-audiodata-number-of-frames-slot).

 5. Assign `0` to `data`'s
 [`[[number of channels]]`](#dom-audiodata-number-of-channels-slot).

 6. Assign `null` to `data`'s
 [`[[format]]`](#dom-audiodata-format-slot).

To check if a [`AudioDataInit`](#dictdef-audiodatainit) is a [valid AudioDataInit], run these steps:

: 1. If
 [`sampleRate`](#dom-audiodatainit-samplerate) less than or equal to `0`, return `false`.

 2. If
 [`numberOfFrames`](#dom-audiodatainit-numberofframes) = `0`, return `false`.

 3. If
 [`numberOfChannels`](#dom-audiodatainit-numberofchannels) = `0`, return `false`.

 4. Verify
 [`data`](#dom-audiodatainit-data) has enough data by running the following steps:

 1. Let `totalSamples` be the product of multiplying
 [`numberOfFrames`](#dom-audiodatainit-numberofframes) by
 [`numberOfChannels`](#dom-audiodatainit-numberofchannels).

 2. Let `bytesPerSample` be the number of bytes per
 sample, as defined by the
 [`format`](#dom-audiodatainit-format).

 3. Let `totalSize` be the product of multiplying
 `bytesPerSample` with `totalSamples`.

 4. Let `dataSize` be the size in bytes of
 [`data`](#dom-audiodatainit-data).

 5. If `dataSize` is less than
 `totalSize`, return false.

 5. Return `true`.

Note: It's expected that
[`AudioDataInit`](#dictdef-audiodatainit)'s
[`data`](#dom-audiodatainit-data)'s memory layout matches the expectations of the
[planar](#planar) or
[interleaved](#interleaved)
[`format`](#dom-audiodatainit-format). There is no real way to verify whether the samples
conform to their
[`AudioSampleFormat`](#enumdef-audiosampleformat).

#### 9.2.6. Transfer and Serialization

The [`AudioData`](#audiodata) [transfer steps](https://html.spec.whatwg.org/multipage/structured-data.html#transfer-steps) (with `value` and `dataHolder`) are:

: 1. If `value`'s
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached) is `true`, throw a
 [`DataCloneError`](https://webidl.spec.whatwg.org/#datacloneerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. For all [`AudioData`](#audiodata) internal slots in `value`, assign
 the value of each internal slot to a field in
 `dataHolder` with the same name as the internal slot.

 3. Run the [Close
 AudioData](#close-audiodata) algorithm with `value`.

The [`AudioData`](#audiodata) [transfer-receiving steps](https://html.spec.whatwg.org/multipage/structured-data.html#transfer-receiving-steps) (with `dataHolder` and `value`) are:

: 1. For all named fields in `dataHolder`, assign the
 value of each named field to the
 [`AudioData`](#audiodata) internal slot in `value` with the
 same name as the named field.

The [`AudioData`](#audiodata) [serialization steps](https://html.spec.whatwg.org/multipage/structured-data.html#serialization-steps) (with `value`, `serialized`, and `forStorage`) are:

: 1. If `value`'s
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached) is `true`, throw a
 [`DataCloneError`](https://webidl.spec.whatwg.org/#datacloneerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. If `forStorage` is `true`, throw a
 [`DataCloneError`](https://webidl.spec.whatwg.org/#datacloneerror).

 3. Let `resource` be the [media
 resource](#media-resource) referenced by `value`'s
 [`[[resource reference]]`](#dom-audiodata-resource-reference-slot).

 4. Let `newReference` be a new reference to
 `resource`.

 5. Assign `newReference` to \|serialized.resource
 reference\|.

 6. For all remaining
 [`AudioData`](#audiodata) internal slots (excluding
 [`[[resource reference]]`](#dom-audiodata-resource-reference-slot)) in `value`, assign the value of
 each internal slot to a field in `serialized` with
 the same name as the internal slot.

The [`AudioData`](#audiodata) [deserialization steps](https://html.spec.whatwg.org/multipage/structured-data.html#deserialization-steps) (with `serialized` and `value`) are:

: 1. For all named fields in `serialized`, assign the
 value of each named field to the
 [`AudioData`](#audiodata) internal slot in `value` with the
 same name as the named field.

#### 9.2.7. AudioDataCopyToOptions

```
dictionary AudioDataCopyToOptions {
 [EnforceRange] required unsigned long planeIndex;
 [EnforceRange] unsigned long frameOffset = 0;
 [EnforceRange] unsigned long frameCount;
 AudioSampleFormat format;
};
```

[`planeIndex`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long)

: The index identifying the plane to copy from.

[`frameOffset`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), defaulting to `0`

: An offset into the source plane data indicating which
 [frame](#frame) to begin copying
 from. Defaults to `0`.

[`frameCount`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long)

: The number of [frames](#frame) to
 copy. If not provided, the copy will include all
 [frames](#frame) in the plane
 beginning with
 [`frameOffset`](#dom-audiodatacopytooptions-frameoffset).

[`format`], of type [AudioSampleFormat](#enumdef-audiosampleformat)

: The output
 [`AudioSampleFormat`](#enumdef-audiosampleformat) for the destination data. If not provided, the
 resulting copy will use
 [this](https://webidl.spec.whatwg.org/#this) AudioData's
 [`[[format]]`](#dom-audiodata-format-slot). Invoking
 [`copyTo()`](#dom-audiodata-copyto) will throw a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) if conversion to the requested format is not
 supported. Conversion from any
 [`AudioSampleFormat`](#enumdef-audiosampleformat) to
 [`f32-planar`](#dom-audiosampleformat-f32-planar) *MUST* always be supported.

 [NOTE:] Authors seeking to integrate with
 [\[WEBAUDIO\]](#biblio-webaudio "Web Audio API")
 can request
 [`f32-planar`](#dom-audiosampleformat-f32-planar) and use the resulting copy to create and
 [`AudioBuffer`](https://webaudio.github.io/web-audio-api/#AudioBuffer) or render via
 [`AudioWorklet`](https://webaudio.github.io/web-audio-api/#AudioWorklet).

### 9.3. Audio Sample Format

An audio sample format describes the numeric type used to represent a
single sample (e.g. 32-bit floating point) and the arrangement of
samples from different channels as either
[interleaved](#interleaved) or
[planar](#planar). The [audio sample
type] refers solely to the numeric type
and interval used to store the data, this is
[`u8`](#dom-audiosampleformat-u8),
[`s16`](#dom-audiosampleformat-s16),
[`s32`](#dom-audiosampleformat-s32), or
[`f32`](#dom-audiosampleformat-f32) for respectively unsigned 8-bits, signed 16-bits,
signed 32-bits, and 32-bits floating point number. The [audio buffer
arrangement](#audio-buffer-arrangement) refers solely to the way the
samples are laid out in memory ([planar](#planar) or [interleaved](#interleaved)).

A [sample] refers
to a single value that is the magnitude of a signal at a particular
point in time in a particular channel.

A [frame] or
(sample-frame) refers to a set of values of all channels of a
multi-channel signal, that happen at the exact same time.

[NOTE:] Consequently, if an audio signal is mono (has only one
channel), a frame and a sample refer to the same thing.

All audio [samples](#sample) in this
specification are using linear pulse-code modulation (Linear PCM):
quantization levels are uniform between values.

[NOTE:] The Web Audio API, that is expected to be used with
this specification, also uses Linear PCM.

```
enum AudioSampleFormat {
 "u8",
 "s16",
 "s32",
 "f32",
 "u8-planar",
 "s16-planar",
 "s32-planar",
 "f32-planar",
};
```

[`u8`]

: [8-bit unsigned integer](https://webidl.spec.whatwg.org/#idl-octet)
 [samples](#sample) with
 [interleaved](#interleaved)
 [channel arrangement](#audio-buffer-arrangement).

[`s16`]

: [16-bit signed integer](https://webidl.spec.whatwg.org/#idl-short)
 [samples](#sample) with
 [interleaved](#interleaved)
 [channel arrangement](#audio-buffer-arrangement).

[`s32`]

: [32-bit signed
 integer](https://webidl.spec.whatwg.org/#idl-long)
 [samples](#sample) with
 [interleaved](#interleaved)
 [channel arrangement](#audio-buffer-arrangement).

[`f32`]

: [32-bit
 float](https://webidl.spec.whatwg.org/#idl-float)
 [samples](#sample) with
 [interleaved](#interleaved)
 [channel arrangement](#audio-buffer-arrangement).

[`u8-planar`]

: [8-bit unsigned integer](https://webidl.spec.whatwg.org/#idl-octet)
 [samples](#sample) with
 [planar](#planar) [channel
 arrangement](#audio-buffer-arrangement).

[`s16-planar`]

: [16-bit signed integer](https://webidl.spec.whatwg.org/#idl-short)
 [samples](#sample) with
 [planar](#planar) [channel
 arrangement](#audio-buffer-arrangement).

[`s32-planar`]

: [32-bit signed
 integer](https://webidl.spec.whatwg.org/#idl-long)
 [samples](#sample) with
 [planar](#planar) [channel
 arrangement](#audio-buffer-arrangement).

[`f32-planar`]

: [32-bit
 float](https://webidl.spec.whatwg.org/#idl-float)
 [samples](#sample) with
 [planar](#planar) [channel
 arrangement](#audio-buffer-arrangement).

#### 9.3.1. Arrangement of audio buffer

When an [`AudioData`](#audiodata) has an
[`AudioSampleFormat`](#enumdef-audiosampleformat) that is [interleaved], the audio samples from different channels
are laid out consecutively in the same buffer, in the order described in
the section [§ 9.3.3 Audio channel ordering](#audio-channel-ordering).
The [`AudioData`](#audiodata) has a single plane, that contains a number of elements
therefore equal to
[`[[number of frames]]`](#dom-audiodata-number-of-frames-slot) \*
[`[[number of channels]]`](#dom-audiodata-number-of-channels-slot).

When an [`AudioData`](#audiodata) has an
[`AudioSampleFormat`](#enumdef-audiosampleformat) that is [planar], the audio samples from different channels
are laid out in different buffers, themselves arranged in an order
described in the section [§ 9.3.3 Audio channel
ordering](#audio-channel-ordering). The
[`AudioData`](#audiodata)
has a number of planes equal to the
[`AudioData`](#audiodata)'s
[`[[number of channels]]`](#dom-audiodata-number-of-channels-slot). Each plane contains
[`[[number of frames]]`](#dom-audiodata-number-of-frames-slot) elements.

[NOTE:] The [Web Audio
API](#biblio-webaudio "Web Audio API") currently
uses
[`f32-planar`](#dom-audiosampleformat-f32-planar) exclusively.

NOTE: The following diagram exemplifies the memory layout of
[planar](#planar) versus
[interleaved](#interleaved)
[`AudioSampleFormat`](#enumdef-audiosampleformat)s

![Graphical representation the memory layout of interleaved and planar
formats](images/planar_interleaved.svg){height="455" width="735"}

#### 9.3.2. Magnitude of the audio samples

The [minimum value] and [maximum value] of an audio sample, for a particular audio
sample type, are the values below which (respectively above which) audio
clipping might occur. They are otherwise regular types, that can hold
values outside this interval during intermediate processing.

The [bias value] for an audio sample type is the value that often
corresponds to the middle of the range (but often the range is not
symmetrical). An audio buffer comprised only of values equal to the
[bias value](#bias-value) is
silent.

[Sample type](#audio-sample-type)

IDL type

[Minimum value](#minimum-value)

[Bias value](#bias-value)

[Maximum value](#maximum-value)

[`u8`](#dom-audiosampleformat-u8)

[octet](https://webidl.spec.whatwg.org/#idl-octet)

0

128

+255

[`s16`](#dom-audiosampleformat-s16)

[short](https://webidl.spec.whatwg.org/#idl-short)

-32768

0

+32767

[`s32`](#dom-audiosampleformat-s32)

[long](https://webidl.spec.whatwg.org/#idl-long)

-2147483648

0

+2147483647

[`f32`](#dom-audiosampleformat-f32)

[float](https://webidl.spec.whatwg.org/#idl-float)

-1.0

0.0

+1.0

[NOTE:] There is no data type that can hold 24 bits of
information conveniently, but audio content using 24-bit samples is
common, so 32-bits integers are commonly used to hold 24-bit content.

[`AudioData`](#audiodata)
containing 24-bit samples *SHOULD* store those samples in
[`s32`](#dom-audiosampleformat-s32) or
[`f32`](#dom-audiosampleformat-f32). When samples are stored in
[`s32`](#dom-audiosampleformat-s32), each sample *MUST* be left-shifted by `8` bits. By
virtue of this process, samples outside of the valid 24-bit range
(\[-8388608, +8388607\]) will be clipped. To avoid clipping and ensure
lossless transport, samples *MAY* be converted to
[`f32`](#dom-audiosampleformat-f32).

[NOTE:] While clipping is unavoidable in
[`u8`](#dom-audiosampleformat-u8),
[`s16`](#dom-audiosampleformat-s16), and
[`s32`](#dom-audiosampleformat-s32) samples due to their storage types, implementations
*SHOULD* take care not to clip internally when handling
[`f32`](#dom-audiosampleformat-f32) samples.

#### 9.3.3. Audio channel ordering

When decoding, the ordering of the audio channels in the resulting
[`AudioData`](#audiodata)
*MUST* be the same as what is present in the
[`EncodedAudioChunk`](#encodedaudiochunk).

When encoding, the ordering of the audio channels in the resulting
[`EncodedAudioChunk`](#encodedaudiochunk) *MUST* be the same as what is preset in the given
[`AudioData`](#audiodata).

In other terms, no channel reordering is performed when encoding and
decoding.

[NOTE:] The container either implies or specifies the channel
mapping: the channel attributed to a particular channel index.

### 9.4. VideoFrame Interface

[NOTE:] [`VideoFrame`](#videoframe) is a
[`CanvasImageSource`](https://html.spec.whatwg.org/multipage/canvas.html#canvasimagesource). A
[`VideoFrame`](#videoframe)
can be passed to any method accepting a
[`CanvasImageSource`](https://html.spec.whatwg.org/multipage/canvas.html#canvasimagesource), including
[`CanvasDrawImage`](https://html.spec.whatwg.org/multipage/canvas.html#canvasdrawimage)'s
[`drawImage()`](https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-drawimage).

```
[Exposed=(Window,DedicatedWorker), Serializable, Transferable]
interface VideoFrame {
 constructor(CanvasImageSource image, optional VideoFrameInit init = );
 constructor(AllowSharedBufferSource data, VideoFrameBufferInit init);

 readonly attribute VideoPixelFormat? format;
 readonly attribute unsigned long codedWidth;
 readonly attribute unsigned long codedHeight;
 readonly attribute DOMRectReadOnly? codedRect;
 readonly attribute DOMRectReadOnly? visibleRect;
 readonly attribute double rotation;
 readonly attribute boolean flip;
 readonly attribute unsigned long displayWidth;
 readonly attribute unsigned long displayHeight;
 readonly attribute unsigned long long? duration; // microseconds
 readonly attribute long long timestamp; // microseconds
 readonly attribute VideoColorSpace colorSpace;

 VideoFrameMetadata metadata();

 unsigned long allocationSize(
 optional VideoFrameCopyToOptions options = );
 Promise<sequence<PlaneLayout>> copyTo(
 AllowSharedBufferSource destination,
 optional VideoFrameCopyToOptions options = );
 VideoFrame clone();
 undefined close();
};

dictionary VideoFrameInit {
 unsigned long long duration; // microseconds
 long long timestamp; // microseconds
 AlphaOption alpha = "keep";

 // Default matches image. May be used to efficiently crop. Will trigger
 // new computation of displayWidth and displayHeight using image's pixel
 // aspect ratio unless an explicit displayWidth and displayHeight are given.
 DOMRectInit visibleRect;

 double rotation = 0;
 boolean flip = false;

 // Default matches image unless visibleRect is provided.
 [EnforceRange] unsigned long displayWidth;
 [EnforceRange] unsigned long displayHeight;

 VideoFrameMetadata metadata;
};

dictionary VideoFrameBufferInit {
 required VideoPixelFormat format;
 required [EnforceRange] unsigned long codedWidth;
 required [EnforceRange] unsigned long codedHeight;
 required [EnforceRange] long long timestamp; // microseconds
 [EnforceRange] unsigned long long duration; // microseconds

 // Default layout is tightly-packed.
 sequence<PlaneLayout> layout;

 // Default visible rect is coded size positioned at (0,0)
 DOMRectInit visibleRect;

 double rotation = 0;
 boolean flip = false;

 // Default display dimensions match visibleRect.
 [EnforceRange] unsigned long displayWidth;
 [EnforceRange] unsigned long displayHeight;

 VideoColorSpaceInit colorSpace;

 sequence<ArrayBuffer> transfer = ;

 VideoFrameMetadata metadata;
};

dictionary VideoFrameMetadata {
 // Possible members are recorded in the VideoFrame Metadata Registry.
};
```

#### 9.4.1. Internal Slots

[`[[resource reference]]`]

: A reference to the [media
 resource](#media-resource) that stores the pixel data for this frame.

[`[[format]]`]

: A
 [`VideoPixelFormat`](#enumdef-videopixelformat) describing the pixel format of the
 [`VideoFrame`](#videoframe). Will be `null` whenever the underlying format does
 not map to a
 [`VideoPixelFormat`](#enumdef-videopixelformat) or when
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached) is `true`.

[`[[coded width]]`]

: Width of the [`VideoFrame`](#videoframe) in pixels, potentially including non-visible
 padding, and prior to considering potential ratio adjustments.

[`[[coded height]]`]

: Height of the
 [`VideoFrame`](#videoframe) in pixels, potentially including non-visible
 padding, and prior to considering potential ratio adjustments.

[`[[visible left]]`]

: The number of pixels defining the left offset of the visible
 rectangle.

[`[[visible top]]`]

: The number of pixels defining the top offset of the visible
 rectangle.

[`[[visible width]]`]

: The width of pixels to include in visible rectangle, starting from
 [`[[visible left]]`](#dom-videoframe-visible-left-slot).

[`[[visible height]]`]

: The height of pixels to include in visible rectangle, starting from
 [`[[visible top]]`](#dom-videoframe-visible-top-slot).

[`[[rotation]]`]

: The rotation to applied to the
 [`VideoFrame`](#videoframe) when rendered, in degrees clockwise. Rotation
 applies before flip.

[`[[flip]]`]

: Whether a horizontal flip is applied to the
 [`VideoFrame`](#videoframe) when rendered. Flip is applied after rotation.

[`[[display width]]`]

: Width of the [`VideoFrame`](#videoframe) when displayed after applying aspect ratio
 adjustments.

[`[[display height]]`]

: Height of the
 [`VideoFrame`](#videoframe) when displayed after applying aspect ratio
 adjustments.

[`[[duration]]`]

: The presentation duration, given in microseconds. The duration is
 copied from the
 [`EncodedVideoChunk`](#encodedvideochunk) corresponding to this
 [`VideoFrame`](#videoframe).

[`[[timestamp]]`]

: The presentation timestamp, given in microseconds. The timestamp is
 copied from the
 [`EncodedVideoChunk`](#encodedvideochunk) corresponding to this
 [`VideoFrame`](#videoframe).

[`[[color space]]`]

: The
 [`VideoColorSpace`](#videocolorspace) associated with this frame.

[`[[metadata]]`]

: The
 [`VideoFrameMetadata`](#dictdef-videoframemetadata) associated with this frame. Possible members are
 recorded in
 [\[webcodecs-video-frame-metadata-registry\]](#biblio-webcodecs-video-frame-metadata-registry "WebCodecs VideoFrame Metadata Registry").
 By design, all
 [`VideoFrameMetadata`](#dictdef-videoframemetadata) properties are serializable.

#### 9.4.2. Constructors

[` VideoFrame(image, init) `]

1. [Check the usability of the image
 argument](https://html.spec.whatwg.org/multipage/canvas.html#check-the-usability-of-the-image-argument). If this throws an exception or returns
 `bad`, then throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

2. If `image` [is not
 origin-clean](https://html.spec.whatwg.org/multipage/canvas.html#the-image-argument-is-not-origin-clean), then throw a
 [`SecurityError`](https://webidl.spec.whatwg.org/#securityerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

3. Let `frame` be a new
 [`VideoFrame`](#videoframe).

4. Switch on `image`:

 [NOTE:] Authors are encouraged to provide a meaningful
 timestamp unless it is implicitly provided by the
 [`CanvasImageSource`](https://html.spec.whatwg.org/multipage/canvas.html#canvasimagesource) at construction. Interfaces that consume
 [`VideoFrame`](#videoframe)s can rely on this value for timing decisions. For
 example,
 [`VideoEncoder`](#videoencoder) can use
 [`timestamp`](#dom-videoframe-timestamp) values to guide rate control (see
 [`framerate`](#dom-videoencoderconfig-framerate)).

 - [`HTMLImageElement`](https://html.spec.whatwg.org/multipage/embedded-content.html#htmlimageelement)

 - [`SVGImageElement`](https://svgwg.org/svg2-draft/embedded.html#InterfaceSVGImageElement)

 1. If
 [`timestamp`](#dom-videoframeinit-timestamp) does not
 [exist](https://infra.spec.whatwg.org/#map-exists) in `init`, throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 2. If `image`'s media data has no [natural
 dimensions](https://drafts.csswg.org/css-images-3/#natural-dimensions) (e.g., it's a vector graphic with no
 specified content size), then throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 3. Let `resource` be a new [media
 resource](#media-resource) containing a copy of `image`'s
 media data. If this is an animated image, `image`'s
 [bitmap
 data](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#concept-imagebitmap-bitmap-data) *MUST* only be taken from the default image
 of the animation (the one that the format defines is to be
 used when animation is not supported or is disabled), or, if
 there is no such image, the first frame of the animation.

 4. Let `codedWidth` and `codedHeight` be
 the width and height of `resource`.

 5. Let `baseRotation` and `baseFlip`
 describe the rotation and flip of `image` relative
 to `resource`.

 6. Let `defaultDisplayWidth` and
 `defaultDisplayHeight` be the [natural
 width](https://drafts.csswg.org/css-images-3/#natural-width) and [natural
 height](https://drafts.csswg.org/css-images-3/#natural-height) of `image`.

 7. Run the [Initialize Frame With
 Resource](#videoframe-initialize-frame-with-resource) algorithm with `init`,
 `frame`, `resource`,
 `codedWidth`, `codedHeight`,
 `baseRotation`, `baseFlip`,
 `defaultDisplayWidth`, and
 `defaultDisplayHeight`.

 - [`HTMLVideoElement`](https://html.spec.whatwg.org/multipage/media.html#htmlvideoelement)

 1. If `image`'s
 [`networkState`](https://html.spec.whatwg.org/multipage/media.html#dom-media-networkstate) attribute is
 [`NETWORK_EMPTY`](https://html.spec.whatwg.org/multipage/media.html#dom-media-network_empty), then throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. Let `currentPlaybackFrame` be the
 [`VideoFrame`](#videoframe) at the [current playback
 position](https://html.spec.whatwg.org/multipage/media.html#current-playback-position).

 3. If
 [`metadata`](#dom-videoframeinit-metadata) does not
 [exist](https://infra.spec.whatwg.org/#map-exists) in `init`, assign
 `currentPlaybackFrame`.[`[[metadata]]`](#dom-videoframe-metadata-slot) to it.

 4. Run the [Initialize Frame From Other
 Frame](#videoframe-initialize-frame-from-other-frame) algorithm with `init`,
 `frame`, and `currentPlaybackFrame`.

 - [`HTMLCanvasElement`](https://html.spec.whatwg.org/multipage/canvas.html#htmlcanvaselement)

 - [`ImageBitmap`](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#imagebitmap)

 - [`OffscreenCanvas`](https://html.spec.whatwg.org/multipage/canvas.html#offscreencanvas)

 1. If
 [`timestamp`](#dom-videoframeinit-timestamp) does not
 [exist](https://infra.spec.whatwg.org/#map-exists) in `init`, throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 2. Let `resource` be a new [media
 resource](#media-resource) containing a copy of `image`'s
 [bitmap
 data](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#concept-imagebitmap-bitmap-data).

 [NOTE:] Implementers are encouraged to avoid a deep
 copy by using reference counting where feasible.

 3. Let `width` be `image.width` and
 `height` be `image.height`.

 4. Run the [Initialize Frame With
 Resource](#videoframe-initialize-frame-with-resource) algorithm with `init`,
 `frame`, `resource`, `width`,
 `height`, `0`, `false`, `width`, and
 `height`.

 - [`VideoFrame`](#videoframe)

 1. Run the [Initialize Frame From Other
 Frame](#videoframe-initialize-frame-from-other-frame) algorithm with `init`,
 `frame`, and `image`.

5. Return `frame`.

[` VideoFrame(data, init) `]

1. If `init` is not a [valid
 VideoFrameBufferInit](#valid-videoframebufferinit), throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

2. Let `defaultRect` be «\[ \"x:\" → `0`, \"y\" → `0`,
 \"width\" →
 `init`.[`codedWidth`](#dom-videoframebufferinit-codedwidth), \"height\" →
 `init`.[`codedWidth`](#dom-videoframebufferinit-codedwidth) \]».

3. Let `overrideRect` be `undefined`.

4. If
 `init`.[`visibleRect`](#dom-videoframebufferinit-visiblerect)
 [exists](https://infra.spec.whatwg.org/#map-exists), assign its value to `overrideRect`.

5. Let `parsedRect` be the result of running the [Parse
 Visible
 Rect](#videoframe-parse-visible-rect) algorithm with `defaultRect`,
 `overrideRect`,
 `init`.[`codedWidth`](#dom-videoframebufferinit-codedwidth),
 `init`.[`codedHeight`](#dom-videoframebufferinit-codedheight), and
 `init`.[`format`](#dom-videoframebufferinit-format).

6. If `parsedRect` is an exception, return
 `parsedRect`.

7. Let `optLayout` be `undefined`.

8. If
 `init`.[`layout`](#dom-videoframebufferinit-layout)
 [exists](https://infra.spec.whatwg.org/#map-exists), assign its value to `optLayout`.

9. Let `combinedLayout` be the result of running the
 [Compute Layout and Allocation
 Size](#videoframe-compute-layout-and-allocation-size) algorithm with `parsedRect`,
 `init`.[`format`](#dom-videoframebufferinit-format), and `optLayout`.

10. If `combinedLayout` is an exception, throw
 `combinedLayout`.

11. If `data.byteLength` is less than `combinedLayout`'s
 [allocationSize](#combined-buffer-layout-allocationsize), throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

12. If
 `init`.[`transfer`](#dom-videoframebufferinit-transfer) contains more than one reference to the same
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer), then throw a
 [`DataCloneError`](https://webidl.spec.whatwg.org/#datacloneerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

13. For each `transferable` in
 `init`.[`transfer`](#dom-videoframebufferinit-transfer):

 1. If
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached) internal slot is `true`, then throw a
 [`DataCloneError`](https://webidl.spec.whatwg.org/#datacloneerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

14. If
 `init`.[`transfer`](#dom-videoframebufferinit-transfer) contains an
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) referenced by `data` the User Agent
 *MAY* choose to:

 1. Let `resource` be a new [media
 resource](#media-resource) referencing pixel data in `data`.

15. Otherwise:

 1. Let `resource` be a new [media
 resource](#media-resource) containing a copy of `data`. Use
 [`visibleRect`](#dom-videoframebufferinit-visiblerect) and
 [`layout`](#dom-videoframebufferinit-layout) to determine where in `data` the
 pixels for each plane reside.

 The User Agent *MAY* choose to allocate `resource`
 with a larger coded size and plane strides to improve memory
 alignment. Increases will be reflected by
 [`codedWidth`](#dom-videoframe-codedwidth) and
 [`codedHeight`](#dom-videoframe-codedheight). Additionally, the User Agent *MAY* use
 [`visibleRect`](#dom-videoframebufferinit-visiblerect) to copy only the visible rectangle. It *MAY*
 also reposition the visible rectangle within
 `resource`. The final position will be reflected by
 [`visibleRect`](#dom-videoframe-visiblerect).

16. For each `transferable` in
 `init`.[`transfer`](#dom-videoframebufferinit-transfer):

 1. Perform
 [DetachArrayBuffer](https://tc39.es/ecma262/#sec-detacharraybuffer)
 on `transferable`

17. Let `resourceCodedWidth` be the coded width of
 `resource`.

18. Let `resourceCodedHeight` be the coded height of
 `resource`.

19. Let `resourceVisibleLeft` be the left offset for the
 visible rectangle of `resource`.

20. Let `resourceVisibleTop` be the top offset for the
 visible rectangle of `resource`.

 (#issue-4948f268) The spec *SHOULD* provide
 definitions (and possibly diagrams) for coded size, visible
 rectangle, and display size. See
 [#166](https://github.com/w3c/webcodecs/issues/166).

21. Let `frame` be a new
 [`VideoFrame`](#videoframe) object initialized as follows:

 1. Assign `resourceCodedWidth`,
 `resourceCodedHeight`,
 `resourceVisibleLeft`, and
 `resourceVisibleTop` to
 [`[[coded width]]`](#dom-videoframe-coded-width-slot),
 [`[[coded height]]`](#dom-videoframe-coded-height-slot),
 [`[[visible left]]`](#dom-videoframe-visible-left-slot), and
 [`[[visible top]]`](#dom-videoframe-visible-top-slot) respectively.

 2. If
 `init`.[`visibleRect`](#dom-videoframebufferinit-visiblerect)
 [exists](https://infra.spec.whatwg.org/#map-exists):

 1. Let `truncatedVisibleWidth` be the value of
 [`visibleRect`](#dom-videoframebufferinit-visiblerect).[`width`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-width) after truncating.

 2. Assign `truncatedVisibleWidth` to
 [`[[visible width]]`](#dom-videoframe-visible-width-slot).

 3. Let `truncatedVisibleHeight` be the value of
 [`visibleRect`](#dom-videoframebufferinit-visiblerect).[`height`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-height) after truncating.

 4. Assign `truncatedVisibleHeight` to
 [`[[visible height]]`](#dom-videoframe-visible-height-slot).

 3. Otherwise:

 1. Assign
 [`[[coded width]]`](#dom-videoframe-coded-width-slot) to
 [`[[visible width]]`](#dom-videoframe-visible-width-slot).

 2. Assign
 [`[[coded height]]`](#dom-videoframe-coded-height-slot) to
 [`[[visible height]]`](#dom-videoframe-visible-height-slot).

 4. Assign the result of running the [Parse
 Rotation](#videoframe-parse-rotation) algorithm, with
 `init`.[`rotation`](#dom-videoframebufferinit-rotation), to
 [`[[rotation]]`](#dom-videoframe-rotation-slot).

 5. Assign
 `init`.[`flip`](#dom-videoframebufferinit-flip) to
 [`[[flip]]`](#dom-videoframe-flip-slot).

 6. If
 [`displayWidth`](#dom-videoframebufferinit-displaywidth) and
 [`displayHeight`](#dom-videoframebufferinit-displayheight)
 [exist](https://infra.spec.whatwg.org/#map-exists) in `init`, assign them to
 [`[[display width]]`](#dom-videoframe-display-width-slot) and
 [`[[display height]]`](#dom-videoframe-display-height-slot) respectively.

 7. Otherwise:

 1. If
 [`[[rotation]]`](#dom-videoframe-rotation-slot) is equal to `0` or `180`:

 1. Assign
 [`[[visible width]]`](#dom-videoframe-visible-width-slot) to
 [`[[display width]]`](#dom-videoframe-display-width-slot).

 2. Assign
 [`[[visible height]]`](#dom-videoframe-visible-height-slot) to
 [`[[display height]]`](#dom-videoframe-display-height-slot).

 2. Otherwise:

 1. Assign
 [`[[visible height]]`](#dom-videoframe-visible-height-slot) to
 [`[[display width]]`](#dom-videoframe-display-width-slot).

 2. Assign
 [`[[visible width]]`](#dom-videoframe-visible-width-slot) to
 [`[[display height]]`](#dom-videoframe-display-height-slot).

 8. Assign `init`'s
 [`timestamp`](#dom-videoframebufferinit-timestamp) and
 [`duration`](#dom-videoframebufferinit-duration) to
 [`[[timestamp]]`](#dom-videoframe-timestamp-slot) and
 [`[[duration]]`](#dom-videoframe-duration-slot) respectively.

 9. Let `colorSpace` be `undefined`.

 10. If
 `init`.[`colorSpace`](#dom-videoframebufferinit-colorspace)
 [exists](https://infra.spec.whatwg.org/#map-exists), assign its value to `colorSpace`.

 11. Assign `init`'s
 [`format`](#dom-videoframebufferinit-format) to
 [`[[format]]`](#dom-videoframe-format-slot).

 12. Assign the result of running the [Pick Color
 Space](#videoframe-pick-color-space) algorithm, with `colorSpace` and
 [`[[format]]`](#dom-videoframe-format-slot), to
 [`[[color space]]`](#dom-videoframe-color-space-slot).

 13. Assign the result of calling [Copy VideoFrame
 metadata](#videoframe-copy-videoframe-metadata) with `init`'s
 [`metadata`](#dom-videoframebufferinit-metadata) to
 `frame`.[`[[metadata]]`](#dom-videoframe-metadata-slot).

22. Return `frame`.

#### 9.4.3. Attributes

[`format`], of type [VideoPixelFormat](#enumdef-videopixelformat), readonly, nullable

: Describes the arrangement of bytes in each plane as well as the
 number and order of the planes. Will be `null` whenever the
 underlying format does not map to a
 [`VideoPixelFormat`](#enumdef-videopixelformat) or when
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached) is `true`.

 The
 [`format`](#dom-videoframe-format) getter steps are to return
 [`[[format]]`](#dom-videoframe-format-slot).

[`codedWidth`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: Width of the [`VideoFrame`](#videoframe) in pixels, potentially including non-visible
 padding, and prior to considering potential ratio adjustments.

 The
 [`codedWidth`](#dom-videoframe-codedwidth) getter steps are to return
 [`[[coded width]]`](#dom-videoframe-coded-width-slot).

[`codedHeight`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: Height of the
 [`VideoFrame`](#videoframe) in pixels, potentially including non-visible
 padding, and prior to considering potential ratio adjustments.

 The
 [`codedHeight`](#dom-videoframe-codedheight) getter steps are to return
 [`[[coded height]]`](#dom-videoframe-coded-height-slot).

[`codedRect`], of type [DOMRectReadOnly](https://drafts.fxtf.org/geometry-1/#domrectreadonly), readonly, nullable

: A
 [`DOMRectReadOnly`](https://drafts.fxtf.org/geometry-1/#domrectreadonly) with
 [`width`](https://drafts.fxtf.org/geometry-1/#dom-domrectreadonly-width) and
 [`height`](https://drafts.fxtf.org/geometry-1/#dom-domrectreadonly-height) matching
 [`codedWidth`](#dom-videoframe-codedwidth) and
 [`codedHeight`](#dom-videoframe-codedheight) and
 [`x`](https://drafts.fxtf.org/geometry-1/#dom-domrectreadonly-x) and
 [`y`](https://drafts.fxtf.org/geometry-1/#dom-domrectreadonly-y) at `(0,0)`. Offered for convenience for use with
 [`allocationSize()`](#dom-videoframe-allocationsize) and
 [`copyTo()`](#dom-videoframe-copyto).

 The
 [`codedRect`](#dom-videoframe-codedrect) getter steps are:

 1. If
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached) is `true`, return `null`.

 2. Let `rect` be a new
 [`DOMRectReadOnly`](https://drafts.fxtf.org/geometry-1/#domrectreadonly), initialized as follows:

 1. Assign `0` to
 [`x`](https://drafts.fxtf.org/geometry-1/#dom-domrectreadonly-x) and
 [`y`](https://drafts.fxtf.org/geometry-1/#dom-domrectreadonly-y).

 2. Assign
 [`[[coded width]]`](#dom-videoframe-coded-width-slot) and
 [`[[coded height]]`](#dom-videoframe-coded-height-slot) to
 [`width`](https://drafts.fxtf.org/geometry-1/#dom-domrectreadonly-width) and
 [`height`](https://drafts.fxtf.org/geometry-1/#dom-domrectreadonly-height) respectively.

 3. Return `rect`.

[`visibleRect`], of type [DOMRectReadOnly](https://drafts.fxtf.org/geometry-1/#domrectreadonly), readonly, nullable

: A
 [`DOMRectReadOnly`](https://drafts.fxtf.org/geometry-1/#domrectreadonly) describing the visible rectangle of pixels for this
 [`VideoFrame`](#videoframe).

 The
 [`visibleRect`](#dom-videoframe-visiblerect) getter steps are:

 1. If
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached) is `true`, return `null`.

 2. Let `rect` be a new
 [`DOMRectReadOnly`](https://drafts.fxtf.org/geometry-1/#domrectreadonly), initialized as follows:

 1. Assign
 [`[[visible left]]`](#dom-videoframe-visible-left-slot),
 [`[[visible top]]`](#dom-videoframe-visible-top-slot),
 [`[[visible width]]`](#dom-videoframe-visible-width-slot), and
 [`[[visible height]]`](#dom-videoframe-visible-height-slot) to
 [`x`](https://drafts.fxtf.org/geometry-1/#dom-domrectreadonly-x),
 [`y`](https://drafts.fxtf.org/geometry-1/#dom-domrectreadonly-y),
 [`width`](https://drafts.fxtf.org/geometry-1/#dom-domrectreadonly-width), and
 [`height`](https://drafts.fxtf.org/geometry-1/#dom-domrectreadonly-height) respectively.

 3. Return `rect`.

[`rotation`], of type [double](https://webidl.spec.whatwg.org/#idl-double), readonly

: The rotation to applied to the VideoFrame when rendered, in degrees
 clockwise. Rotation applies before flip.

 The
 [`rotation`](#dom-videoframe-rotation) getter steps are to return
 [`[[rotation]]`](#dom-videoframe-rotation-slot).

[`flip`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), readonly

: Whether a horizontal flip is applied to the
 [`VideoFrame`](#videoframe) when rendered. Flip applies after rotation.

 The
 [`flip`](#dom-videoframe-flip) getter steps are to return
 [`[[flip]]`](#dom-videoframe-flip-slot).

[`displayWidth`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: Width of the VideoFrame when displayed after applying rotation and
 aspect ratio adjustments.

 The
 [`displayWidth`](#dom-videoframe-displaywidth) getter steps are to return
 [`[[display width]]`](#dom-videoframe-display-width-slot).

[`displayHeight`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: Height of the VideoFrame when displayed after applying rotation and
 aspect ratio adjustments.

 The
 [`displayHeight`](#dom-videoframe-displayheight) getter steps are to return
 [`[[display height]]`](#dom-videoframe-display-height-slot).

[`timestamp`], of type [long long](https://webidl.spec.whatwg.org/#idl-long-long), readonly

: The presentation timestamp, given in microseconds. For decode,
 timestamp is copied from the
 [`EncodedVideoChunk`](#encodedvideochunk) corresponding to this
 [`VideoFrame`](#videoframe). For encode, timestamp is copied to the
 [`EncodedVideoChunk`](#encodedvideochunk)s corresponding to this
 [`VideoFrame`](#videoframe).

 The
 [`timestamp`](#dom-videoframe-timestamp) getter steps are to return
 [`[[timestamp]]`](#dom-videoframe-timestamp-slot).

[`duration`], of type [unsigned long long](https://webidl.spec.whatwg.org/#idl-unsigned-long-long), readonly, nullable

: The presentation duration, given in microseconds. The duration is
 copied from the
 [`EncodedVideoChunk`](#encodedvideochunk) corresponding to this VideoFrame.

 The
 [`duration`](#dom-videoframe-duration) getter steps are to return
 [`[[duration]]`](#dom-videoframe-duration-slot).

[`colorSpace`], of type [VideoColorSpace](#videocolorspace), readonly

: The
 [`VideoColorSpace`](#videocolorspace) associated with this frame.

 The
 [`colorSpace`](#dom-videoframe-colorspace) getter steps are to return
 [`[[color space]]`](#dom-videoframe-color-space-slot).

#### 9.4.4. Internal Structures

A [combined buffer layout] is a
[struct](https://infra.spec.whatwg.org/#struct) that consists of:

- A [allocationSize] (an
 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long))

- A [computedLayouts] (a
 [list](https://infra.spec.whatwg.org/#list) of [computed plane
 layout](#computed-plane-layout) structs).

A [computed plane layout] is a
[struct](https://infra.spec.whatwg.org/#struct) that consists of:

- A [destinationOffset] (an
 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long))

- A [destinationStride] (an
 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long))

- A [sourceTop] (an
 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long))

- A [sourceHeight] (an
 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long))

- A [sourceLeftBytes] (an
 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long))

- A [sourceWidthBytes] (an
 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long))

#### 9.4.5. Methods

[`allocationSize(``options``)`]

: Returns the minimum byte length for a valid destination
 [`BufferSource`](https://webidl.spec.whatwg.org/#BufferSource) to be used with
 [`copyTo()`](#dom-videoframe-copyto) with the given options.

 When invoked, run these steps:

 1. If
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached) is `true`, throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. If
 [`[[format]]`](#dom-videoframe-format-slot) is `null`, throw a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 3. Let `combinedLayout` be the result of running the
 [Parse
 VideoFrameCopyToOptions](#videoframe-parse-videoframecopytooptions) algorithm with `options`.

 4. If `combinedLayout` is an exception, throw
 `combinedLayout`.

 5. Return `combinedLayout`'s
 [allocationSize](#combined-buffer-layout-allocationsize).

[`copyTo(``destination``, ``options``)`]

: Asynchronously copies the planes of this frame into
 `destination` according to `options`. The
 format of the data is
 `options`.[`format`](#dom-videoframecopytooptions-format), if it
 [exists](https://infra.spec.whatwg.org/#map-exists) or
 [this](https://webidl.spec.whatwg.org/#this)
 [`VideoFrame`](#videoframe)'s
 [`format`](#dom-videoframe-format) otherwise.

 [NOTE:] Promises that are returned by several calls to
 [`copyTo()`](#dom-videoframe-copyto) are not guaranteed to resolve in the order they
 were returned.

 When invoked, run these steps:

 1. If
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached) is `true`, return a promise rejected with a
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. If
 [`[[format]]`](#dom-videoframe-format-slot) is `null`, return a promise rejected with a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 3. Let `combinedLayout` be the result of running the
 [Parse
 VideoFrameCopyToOptions](#videoframe-parse-videoframecopytooptions) algorithm with `options`.

 4. If `combinedLayout` is an exception, return a promise
 rejected with `combinedLayout`.

 5. If `destination.byteLength` is less than
 `combinedLayout`'s
 [allocationSize](#combined-buffer-layout-allocationsize), return a promise rejected with a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 6. If
 `options`.[`format`](#dom-videoframecopytooptions-format) is equal to one of
 [`RGBA`](#dom-videopixelformat-rgba),
 [`RGBX`](#dom-videopixelformat-rgbx),
 [`BGRA`](#dom-videopixelformat-bgra),
 [`BGRX`](#dom-videopixelformat-bgrx) then:

 1. Let `newOptions` be the result of running the
 [Clone
 Configuration](#clone-configuration) algorithm with `options`.

 2. Assign `undefined` to
 `newOptions`.[`format`](#dom-videoframecopytooptions-format).

 3. Let `rgbFrame` be the result of running the
 [Convert to RGB
 frame](#videoframe-convert-to-rgb-frame) algorithm with
 [this](https://webidl.spec.whatwg.org/#this),
 `options`.[`format`](#dom-videoframecopytooptions-format), and
 `options`.[`colorSpace`](#dom-videoframecopytooptions-colorspace).

 4. Return the result of calling
 [`copyTo()`](#dom-videoframe-copyto) on `rgbFrame` with
 `destination` and `newOptions`.

 7. Let `p` be a new
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise).

 8. Let `copyStepsQueue` be the result of starting a new
 [parallel
 queue](https://html.spec.whatwg.org/multipage/infrastructure.html#parallel-queue).

 9. Let `planeLayouts` be a new
 [list](https://infra.spec.whatwg.org/#list).

 10. Enqueue the following steps to `copyStepsQueue`:

 1. Let resource be the [media
 resource](#media-resource) referenced by
 [`[[resource reference]]`](#dom-videoframe-resource-reference-slot).

 2. Let `numPlanes` be the number of planes as
 defined by
 [`[[format]]`](#dom-videoframe-format-slot).

 3. Let `planeIndex` be `0`.

 4. While `planeIndex` is less than
 `combinedLayout`'s `numPlanes`:

 1. Let `sourceStride` be the stride of the plane
 in `resource` as identified by
 `planeIndex`.

 2. Let `computedLayout` be the [computed plane
 layout](#computed-plane-layout) in `combinedLayout`'s
 [computedLayouts](#combined-buffer-layout-computedlayouts) at the position of
 `planeIndex`

 3. Let `sourceOffset` be the product of
 multiplying `computedLayout`'s
 [sourceTop](#computed-plane-layout-sourcetop) by `sourceStride`

 4. Add `computedLayout`'s
 [sourceLeftBytes](#computed-plane-layout-sourceleftbytes) to `sourceOffset`.

 5. Let `destinationOffset` be
 `computedLayout`'s
 [destinationOffset](#computed-plane-layout-destinationoffset).

 6. Let `rowBytes` be
 `computedLayout`'s
 [sourceWidthBytes](#computed-plane-layout-sourcewidthbytes).

 7. Let `layout` be a new
 [`PlaneLayout`](#dictdef-planelayout), with
 [`offset`](#dom-planelayout-offset) set to `destinationOffset`
 and
 [`stride`](#dom-planelayout-stride) set to `rowBytes`.

 8. Let `row` be `0`.

 9. While `row` is less than
 `computedLayout`'s
 [sourceHeight](#computed-plane-layout-sourceheight):

 1. Copy `rowBytes` bytes from
 `resource` starting at
 `sourceOffset` to
 `destination` starting at
 `destinationOffset`.

 2. Increment `sourceOffset` by
 `sourceStride`.

 3. Increment `destinationOffset` by
 `computedLayout`'s
 [destinationStride](#computed-plane-layout-destinationstride).

 4. Increment `row` by `1`.

 10. Increment `planeIndex` by `1`.

 11. Append `layout` to `planeLayouts`.

 5. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to resolve `p` with
 `planeLayouts`.

 11. Return `p`.

[`clone()`]

: Creates a new
 [`VideoFrame`](#videoframe) with a reference to the same [media
 resource](#media-resource).

 When invoked, run these steps:

 1. If the value of `frame`'s
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached) internal slot is `true`, throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. Return the result of running the [Clone
 VideoFrame](#clone-videoframe) algorithm with
 [this](https://webidl.spec.whatwg.org/#this).

[`close()`]

: Clears all state and releases the reference to the [media
 resource](#media-resource). Close is final.

 When invoked, run the [Close
 VideoFrame](#close-videoframe) algorithm with
 [this](https://webidl.spec.whatwg.org/#this).

[`metadata()`]

: Gets the
 [`VideoFrameMetadata`](#dictdef-videoframemetadata) associated with this frame.

 When invoked, run these steps:

 1. If
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached) is `true`, throw an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. Return the result of calling [Copy VideoFrame
 metadata](#videoframe-copy-videoframe-metadata) with
 [`[[metadata]]`](#dom-videoframe-metadata-slot).

#### 9.4.6. Algorithms

[Create a VideoFrame] (with `output`, `timestamp`, `duration`, `displayAspectWidth`, `displayAspectHeight`, `colorSpace`, `rotation`, and `flip`)

: 1. Let `frame` be a new
 [`VideoFrame`](#videoframe), constructed as follows:

 1. Assign `false` to
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached).

 2. Let `resource` be the [media
 resource](#media-resource) described by `output`.

 3. Let `resourceReference` be a reference to
 `resource`.

 4. Assign `resourceReference` to
 [`[[resource reference]]`](#dom-videoframe-resource-reference-slot).

 5. If `output` uses a recognized
 [`VideoPixelFormat`](#enumdef-videopixelformat), assign that format to
 [`[[format]]`](#dom-videoframe-format-slot). Otherwise, assign `null` to
 [`[[format]]`](#dom-videoframe-format-slot).

 6. Let `codedWidth` and `codedHeight` be
 the coded width and height of the `output` in
 pixels.

 7. Let `visibleLeft`, `visibleTop`,
 `visibleWidth`, and `visibleHeight` be
 the left, top, width and height for the visible rectangle of
 `output`.

 8. Let `displayWidth` and `displayHeight`
 be the display size of `output` in pixels.

 9. If `displayAspectWidth` and
 `displayAspectHeight` are provided, increase
 `displayWidth` or `displayHeight`
 until the ratio of `displayWidth` to
 `displayHeight` matches the ratio of
 `displayAspectWidth` to
 `displayAspectHeight`.

 10. Assign `codedWidth`, `codedHeight`,
 `visibleLeft`, `visibleTop`,
 `visibleWidth`, `visibleHeight`,
 `displayWidth`, and `displayHeight` to
 [`[[coded width]]`](#dom-videoframe-coded-width-slot),
 [`[[coded height]]`](#dom-videoframe-coded-height-slot),
 [`[[visible left]]`](#dom-videoframe-visible-left-slot),
 [`[[visible top]]`](#dom-videoframe-visible-top-slot),
 [`[[visible width]]`](#dom-videoframe-visible-width-slot), and
 [`[[visible height]]`](#dom-videoframe-visible-height-slot) respectively.

 11. Assign `duration` and `timestamp` to
 [`[[duration]]`](#dom-videoframe-duration-slot) and
 [`[[timestamp]]`](#dom-videoframe-timestamp-slot) respectively.

 12. Assign
 [`[[color space]]`](#dom-videoframe-color-space-slot) with the result of running the [Pick Color
 Space](#videoframe-pick-color-space) algorithm, with `colorSpace` and
 [`[[format]]`](#dom-videoframe-format-slot).

 13. Assign
 [`rotation`](#dom-videoframe-rotation) and
 [`flip`](#dom-videoframe-flip) to `rotation` and
 `flip` respectively.

 2. Return `frame`.

[Pick Color Space] (with `overrideColorSpace` and `format`)

: 1. If `overrideColorSpace` is provided, return a new
 [`VideoColorSpace`](#videocolorspace) constructed with
 `overrideColorSpace`.

 User Agents *MAY* replace `null` members of the provided
 `overrideColorSpace` with guessed values as
 determined by implementer defined heuristics.

 2. Otherwise, if
 [`[[format]]`](#dom-videoframe-format-slot) is an [RGB
 format](#rgb-format) return
 a new instance of the [sRGB Color
 Space](#srgb-color-space)

 3. Otherwise, return a new instance of the [REC709 Color
 Space](#rec709-color-space).

[Validate VideoFrameInit] (with `format`, `codedWidth`, and `codedHeight`):

: 1. If
 [`visibleRect`](#dom-videoframeinit-visiblerect)
 [exists](https://infra.spec.whatwg.org/#map-exists):

 1. Let `validAlignment` be the result of running the
 [Verify Rect Offset
 Alignment](#videoframe-verify-rect-offset-alignment) with `format` and
 `visibleRect`.

 2. If `validAlignment` is `false`, return `false`.

 3. If any attribute of
 [`visibleRect`](#dom-videoframeinit-visiblerect) is negative or not finite, return `false`.

 4. If
 [`visibleRect`](#dom-videoframeinit-visiblerect).[`width`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-width) == `0` or
 [`visibleRect`](#dom-videoframeinit-visiblerect).[`height`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-height) == `0` return `false`.

 5. If
 [`visibleRect`](#dom-videoframeinit-visiblerect).[`y`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-y) +
 [`visibleRect`](#dom-videoframeinit-visiblerect).[`height`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-height) \> `codedHeight`, return
 `false`.

 6. If
 [`visibleRect`](#dom-videoframeinit-visiblerect).[`x`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-x) +
 [`visibleRect`](#dom-videoframeinit-visiblerect).[`width`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-width) \> `codedWidth`, return `false`.

 2. If `codedWidth` = 0 or `codedHeight` =
 0,return `false`.

 3. If only one of
 [`displayWidth`](#dom-videoframeinit-displaywidth) or
 [`displayHeight`](#dom-videoframeinit-displayheight)
 [exists](https://infra.spec.whatwg.org/#map-exists), return `false`.

 4. If
 [`displayWidth`](#dom-videoframeinit-displaywidth) == `0` or
 [`displayHeight`](#dom-videoframeinit-displayheight) == `0`, return `false`.

 5. Return `true`.

To check if a [`VideoFrameBufferInit`](#dictdef-videoframebufferinit) is a [valid VideoFrameBufferInit], run these steps:

: 1. If
 [`codedWidth`](#dom-videoframebufferinit-codedwidth) = 0 or
 [`codedHeight`](#dom-videoframebufferinit-codedheight) = 0,return `false`.

 2. If any attribute of
 [`visibleRect`](#dom-videoframebufferinit-visiblerect) is negative or not finite, return `false`.

 3. If
 [`visibleRect`](#dom-videoframebufferinit-visiblerect).[`y`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-y) +
 [`visibleRect`](#dom-videoframebufferinit-visiblerect).[`height`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-height) \>
 [`codedHeight`](#dom-videoframebufferinit-codedheight), return `false`.

 4. If
 [`visibleRect`](#dom-videoframebufferinit-visiblerect).[`x`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-x) +
 [`visibleRect`](#dom-videoframebufferinit-visiblerect).[`width`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-width) \>
 [`codedWidth`](#dom-videoframebufferinit-codedwidth), return `false`.

 5. If only one of
 [`displayWidth`](#dom-videoframebufferinit-displaywidth) or
 [`displayHeight`](#dom-videoframebufferinit-displayheight)
 [exists](https://infra.spec.whatwg.org/#map-exists), return `false`.

 6. If
 [`displayWidth`](#dom-videoframebufferinit-displaywidth) = 0 or
 [`displayHeight`](#dom-videoframebufferinit-displayheight) = 0, return `false`.

 7. Return `true`.

[Initialize Frame From Other Frame] (with `init`, `frame`, and `otherFrame`)

: 1. Let `format` be
 `otherFrame`.[`format`](#dom-videoframe-format).

 2. If
 `init`.[`alpha`](#dom-videoframeinit-alpha) is
 [`discard`](#dom-alphaoption-discard), assign
 `otherFrame`.[`format`](#dom-videoframe-format)'s [equivalent opaque
 format](#equivalent-opaque-format) `format`.

 3. Let `validInit` be the result of running the
 [Validate
 VideoFrameInit](#validate-videoframeinit) algorithm with `format` and
 `otherFrame`'s
 [`[[coded width]]`](#dom-videoframe-coded-width-slot) and
 [`[[coded height]]`](#dom-videoframe-coded-height-slot).

 4. If `validInit` is `false`, throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 5. Let `resource` be the [media
 resource](#media-resource) referenced by `otherFrame`'s
 [`[[resource reference]]`](#dom-videoframe-resource-reference-slot).

 6. Assign a new reference for `resource` to
 `frame`'s
 [`[[resource reference]]`](#dom-videoframe-resource-reference-slot).

 7. Assign the following attributes from `otherFrame` to
 `frame`:
 [`codedWidth`](#dom-videoframe-codedwidth),
 [`codedHeight`](#dom-videoframe-codedheight),
 [`colorSpace`](#dom-videoframe-colorspace).

 8. Let `defaultVisibleRect` be the result of performing
 the getter steps for
 [`visibleRect`](#dom-videoframe-visiblerect) on `otherFrame`.

 9. Let `baseRotation` and `baseFlip` be
 `otherFrame`'s
 [`[[rotation]]`](#dom-videoframe-rotation-slot) and
 [`[[flip]]`](#dom-videoframe-flip-slot), respectively.

 10. Let `defaultDisplayWidth` and
 `defaultDisplayHeight` be `otherFrame`'s
 [`[[display width]]`](#dom-videoframe-display-width-slot) and
 [`[[display height]]`](#dom-videoframe-display-height-slot), respectively.

 11. Run the [Initialize Visible Rect, Orientation, and Display
 Size](#videoframe-initialize-visible-rect-orientation-and-display-size) algorithm with `init`,
 `frame`, `defaultVisibleRect`,
 `baseRotation`, `baseFlip`,
 `defaultDisplayWidth`, and
 `defaultDisplayHeight`.

 12. If
 [`duration`](#dom-videoframeinit-duration)
 [exists](https://infra.spec.whatwg.org/#map-exists) in `init`, assign it to
 `frame`'s
 [`[[duration]]`](#dom-videoframe-duration-slot). Otherwise, assign
 `otherFrame`.[`duration`](#dom-videoframe-duration) to `frame`'s
 [`[[duration]]`](#dom-videoframe-duration-slot).

 13. If
 [`timestamp`](#dom-videoframeinit-timestamp)
 [exists](https://infra.spec.whatwg.org/#map-exists) in `init`, assign it to
 `frame`'s
 [`[[timestamp]]`](#dom-videoframe-timestamp-slot). Otherwise, assign `otherFrame`'s
 [`timestamp`](#dom-videoframe-timestamp) to `frame`'s
 [`[[timestamp]]`](#dom-videoframe-timestamp-slot).

 14. Assign `format` to
 `frame`.[`[[format]]`](#dom-videoframe-format-slot).

 15. Assign the result of calling [Copy VideoFrame
 metadata](#videoframe-copy-videoframe-metadata) with `init`'s
 [`metadata`](#dom-videoframeinit-metadata) to
 `frame`.[`[[metadata]]`](#dom-videoframe-metadata-slot).

[Initialize Frame With Resource] (with `init`, `frame`, `resource`, `codedWidth`, `codedHeight`, `baseRotation`, `baseFlip`, `defaultDisplayWidth`, and `defaultDisplayHeight`)

: 1. Let `format` be `null`.

 2. If `resource` uses a recognized
 [`VideoPixelFormat`](#enumdef-videopixelformat), assign the
 [`VideoPixelFormat`](#enumdef-videopixelformat) of `resource` to
 `format`.

 3. Let `validInit` be the result of running the
 [Validate
 VideoFrameInit](#validate-videoframeinit) algorithm with `format`,
 `width` and `height`.

 4. If `validInit` is `false`, throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 5. Assign a new reference for `resource` to
 `frame`'s
 [`[[resource reference]]`](#dom-videoframe-resource-reference-slot).

 6. If
 `init`.[`alpha`](#dom-videoframeinit-alpha) is
 [`discard`](#dom-alphaoption-discard), assign `format`'s [equivalent
 opaque
 format](#equivalent-opaque-format) to `format`.

 7. Assign `format` to
 [`[[format]]`](#dom-videoframe-format-slot)

 8. Assign `codedWidth` and `codedHeight` to
 `frame`'s
 [`[[coded width]]`](#dom-videoframe-coded-width-slot) and
 [`[[coded height]]`](#dom-videoframe-coded-height-slot) respectively.

 9. Let `defaultVisibleRect` be a new
 [`DOMRect`](https://drafts.fxtf.org/geometry-1/#domrect) constructed with «\[ \"x:\" → `0`, \"y\" → `0`,
 \"width\" → `codedWidth`, \"height\" →
 `codedHeight` \]»

 10. Run the [Initialize Visible Rect, Orientation, and Display
 Size](#videoframe-initialize-visible-rect-orientation-and-display-size) algorithm with `init`,
 `frame`, `defaultVisibleRect`,
 `defaultDisplayWidth`, and
 `defaultDisplayHeight`.

 11. Assign
 `init`.[`duration`](#dom-videoframeinit-duration) to `frame`'s
 [`[[duration]]`](#dom-videoframe-duration-slot).

 12. Assign
 `init`.[`timestamp`](#dom-videoframeinit-timestamp) to `frame`'s
 [`[[timestamp]]`](#dom-videoframe-timestamp-slot).

 13. If `resource` has a known
 [`VideoColorSpace`](#videocolorspace), assign its value to
 [`[[color space]]`](#dom-videoframe-color-space-slot).

 14. Otherwise, assign a new
 [`VideoColorSpace`](#videocolorspace), constructed with an empty
 [`VideoColorSpaceInit`](#dictdef-videocolorspaceinit), to
 [`[[color space]]`](#dom-videoframe-color-space-slot).

[Initialize Visible Rect, Orientation, and Display Size] (with `init`, `frame`, `defaultVisibleRect`, `baseRotation`, `baseFlip`, `defaultDisplayWidth` and `defaultDisplayHeight`)

: 1. Let `visibleRect` be `defaultVisibleRect`.

 2. If
 `init`.[`visibleRect`](#dom-videoframeinit-visiblerect)
 [exists](https://infra.spec.whatwg.org/#map-exists), assign it to `visibleRect`.

 3. Assign `visibleRect`'s
 [`x`](https://drafts.fxtf.org/geometry-1/#dom-domrect-x),
 [`y`](https://drafts.fxtf.org/geometry-1/#dom-domrect-y),
 [`width`](https://drafts.fxtf.org/geometry-1/#dom-domrect-width), and
 [`height`](https://drafts.fxtf.org/geometry-1/#dom-domrect-height), to `frame`'s
 [`[[visible left]]`](#dom-videoframe-visible-left-slot),
 [`[[visible top]]`](#dom-videoframe-visible-top-slot),
 [`[[visible width]]`](#dom-videoframe-visible-width-slot), and
 [`[[visible height]]`](#dom-videoframe-visible-height-slot) respectively.

 4. Let `rotation` be the result of running the [Parse
 Rotation](#videoframe-parse-rotation) algorithm, with
 `init`.[`rotation`](#dom-videoframeinit-rotation).

 5. Assign the result of running the [Add
 Rotations](#videoframe-add-rotations) algorithm, with `baseRotation`,
 `baseFlip`, and `rotation`, to
 `frame`'s
 [`[[rotation]]`](#dom-videoframe-rotation-slot).

 6. If `baseFlip` is equal to
 `init`.[`flip`](#dom-videoframeinit-flip), assign `false` to `frame`'s
 [`[[flip]]`](#dom-videoframe-flip-slot). Otherwise, assign `true` to
 `frame`'s
 [`[[flip]]`](#dom-videoframe-flip-slot).

 7. If
 [`displayWidth`](#dom-videoframeinit-displaywidth) and
 [`displayHeight`](#dom-videoframeinit-displayheight)
 [exist](https://infra.spec.whatwg.org/#map-exists) in `init`, assign them to
 [`[[display width]]`](#dom-videoframe-display-width-slot) and
 [`[[display height]]`](#dom-videoframe-display-height-slot) respectively.

 8. Otherwise:

 1. If `baseRotation` is equal to `0` or `180`:

 1. Let `widthScale` be the result of dividing
 `defaultDisplayWidth` by
 `defaultVisibleRect`.[`width`](https://drafts.fxtf.org/geometry-1/#dom-domrect-width).

 2. Let `heightScale` be the result of dividing
 `defaultDisplayHeight` by
 `defaultVisibleRect`.[`height`](https://drafts.fxtf.org/geometry-1/#dom-domrect-height).

 2. Otherwise:

 1. Let `widthScale` be the result of dividing
 `defaultDisplayHeight` by
 `defaultVisibleRect`.[`width`](https://drafts.fxtf.org/geometry-1/#dom-domrect-width).

 2. Let `heightScale` be the result of dividing
 `defaultDisplayWidth` by
 `defaultVisibleRect`.[`height`](https://drafts.fxtf.org/geometry-1/#dom-domrect-height).

 3. Let `displayWidth` be
 `|frame|'s {{VideoFrame/[[visible width]]}} * |widthScale|`,
 rounded to the nearest integer.

 4. Let `displayHeight` be
 `|frame|'s {{VideoFrame/[[visible height]]}} * |heightScale|`,
 rounded to the nearest integer.

 5. If `rotation` is equal to `0` or `180`:

 1. Assign `displayWidth` to `frame`'s
 [`[[display width]]`](#dom-videoframe-display-width-slot).

 2. Assign `displayHeight` to
 `frame`'s
 [`[[display height]]`](#dom-videoframe-display-height-slot).

 6. Otherwise:

 1. Assign `displayHeight` to
 `frame`'s
 [`[[display width]]`](#dom-videoframe-display-width-slot).

 2. Assign `displayWidth` to `frame`'s
 [`[[display height]]`](#dom-videoframe-display-height-slot).

[Clone VideoFrame] (with `frame`)

: 1. Let `clone` be a new
 [`VideoFrame`](#videoframe) initialized as follows:

 1. Let `resource` be the [media
 resource](#media-resource) referenced by `frame`'s
 [`[[resource reference]]`](#dom-videoframe-resource-reference-slot).

 2. Let `newReference` be a new reference to
 `resource`.

 3. Assign `newReference` to `clone`'s
 [`[[resource reference]]`](#dom-videoframe-resource-reference-slot).

 4. Assign all remaining internal slots of `frame`
 (excluding
 [`[[resource reference]]`](#dom-videoframe-resource-reference-slot)) to those of the same name in
 `clone`.

 2. Return `clone`.

[Close VideoFrame] (with `frame`)

: 1. Assign `null` to `frame`'s
 [`[[resource reference]]`](#dom-videoframe-resource-reference-slot).

 2. Assign `true` to `frame`'s
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached).

 3. Assign `null` to `frame`'s
 [`format`](#dom-videoframe-format).

 4. Assign `0` to `frame`'s
 [`[[coded width]]`](#dom-videoframe-coded-width-slot),
 [`[[coded height]]`](#dom-videoframe-coded-height-slot),
 [`[[visible left]]`](#dom-videoframe-visible-left-slot),
 [`[[visible top]]`](#dom-videoframe-visible-top-slot),
 [`[[visible width]]`](#dom-videoframe-visible-width-slot),
 [`[[visible height]]`](#dom-videoframe-visible-height-slot),
 [`[[rotation]]`](#dom-videoframe-rotation-slot),
 [`[[display width]]`](#dom-videoframe-display-width-slot), and
 [`[[display height]]`](#dom-videoframe-display-height-slot).

 5. Assign `false` to `frame`'s
 [`[[flip]]`](#dom-videoframe-flip-slot).

 6. Assign a new
 [`VideoFrameMetadata`](#dictdef-videoframemetadata) to
 `frame`.[`[[metadata]]`](#dom-videoframe-metadata-slot).

[Parse Rotation] (with `rotation`)

: 1. Let `alignedRotation` be the nearest multiple of `90`
 to `rotation`, rounding ties towards positive
 infinity.

 2. Let `fullTurns` be the greatest multiple of `360`
 less than or equal to `alignedRotation`.

 3. Return `|alignedRotation| - |fullTurns|`.

[Add Rotations] (with `baseRotation`, `baseFlip`, and `rotation`)

: 1. If `baseFlip` is `false`, let
 `combinedRotation` be `|baseRotation| + |rotation|`.
 Otherwise, let `combinedRotation` be
 `|baseRotation| - |rotation|`.

 2. Let `fullTurns` be the greatest multiple of `360`
 less than or equal to `combinedRotation`.

 3. Return `|combinedRotation| - |fullTurns|`.

[Parse VideoFrameCopyToOptions] (with `options`)

: 1. Let `defaultRect` be the result of performing the
 getter steps for
 [`visibleRect`](#dom-videoframe-visiblerect).

 2. Let `overrideRect` be `undefined`.

 3. If
 `options`.[`rect`](#dom-videoframecopytooptions-rect)
 [exists](https://infra.spec.whatwg.org/#map-exists), assign the value of
 `options`.[`rect`](#dom-videoframecopytooptions-rect) to `overrideRect`.

 4. Let `parsedRect` be the result of running the [Parse
 Visible
 Rect](#videoframe-parse-visible-rect) algorithm with `defaultRect`,
 `overrideRect`,
 [`[[coded width]]`](#dom-videoframe-coded-width-slot),
 [`[[coded height]]`](#dom-videoframe-coded-height-slot), and
 [`[[format]]`](#dom-videoframe-format-slot).

 5. If `parsedRect` is an exception, return
 `parsedRect`.

 6. Let `optLayout` be `undefined`.

 7. If
 `options`.[`layout`](#dom-videoframecopytooptions-layout)
 [exists](https://infra.spec.whatwg.org/#map-exists), assign its value to `optLayout`.

 8. Let `format` be `undefined`.

 9. If
 `options`.[`format`](#dom-videoframecopytooptions-format) does not
 [exist](https://infra.spec.whatwg.org/#map-exists), assign
 [`[[format]]`](#dom-videoframe-format-slot) to `format`.

 10. Otherwise, if
 `options`.[`format`](#dom-videoframecopytooptions-format) is equal to one of
 [`RGBA`](#dom-videopixelformat-rgba),
 [`RGBX`](#dom-videopixelformat-rgbx),
 [`BGRA`](#dom-videopixelformat-bgra),
 [`BGRX`](#dom-videopixelformat-bgrx), then assign
 `options`.[`format`](#dom-videoframecopytooptions-format) to `format`, otherwise return
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror).

 11. Let `combinedLayout` be the result of running the
 [Compute Layout and Allocation
 Size](#videoframe-compute-layout-and-allocation-size) algorithm with `parsedRect`,
 `format`, and `optLayout`.

 12. Return `combinedLayout`.

[Verify Rect Offset Alignment] (with `format` and `rect`)

: 1. If `format` is `null`, return `true`.

 2. Let `planeIndex` be `0`.

 3. Let `numPlanes` be the number of planes as defined by
 `format`.

 4. While `planeIndex` is less than
 `numPlanes`:

 1. Let `plane` be the Plane identified by
 `planeIndex` as defined by `format`.

 2. Let `sampleWidth` be the horizontal [sub-sampling
 factor](#sub-sampling-factor) of each subsample for `plane`.

 3. Let `sampleHeight` be the vertical [sub-sampling
 factor](#sub-sampling-factor) of each subsample for `plane`.

 4. If
 `rect`.[`x`](https://drafts.fxtf.org/geometry-1/#dom-domrectreadonly-x) is not a multiple of
 `sampleWidth`, return `false`.

 5. If
 `rect`.[`y`](https://drafts.fxtf.org/geometry-1/#dom-domrectreadonly-y) is not a multiple of
 `sampleHeight`, return `false`.

 6. Increment `planeIndex` by `1`.

 5. Return `true`.

[Parse Visible Rect] (with `defaultRect`, `overrideRect`, `codedWidth`, `codedHeight`, and `format`)

: 1. Let `sourceRect` be `defaultRect`

 2. If `overrideRect` is not `undefined`:

 1. If either of
 `overrideRect`.[`width`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-width) or
 [`height`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-height) is `0`, return a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 2. If the sum of
 `overrideRect`.[`x`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-x) and
 `overrideRect`.[`width`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-width) is greater than `codedWidth`,
 return a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 3. If the sum of
 `overrideRect`.[`y`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-y) and
 `overrideRect`.[`height`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-height) is greater than `codedHeight`,
 return a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 4. Assign `overrideRect` to `sourceRect`.

 3. Let `validAlignment` be the result of running the
 [Verify Rect Offset
 Alignment](#videoframe-verify-rect-offset-alignment) algorithm with `format` and
 `sourceRect`.

 4. If `validAlignment` is `false`, throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 5. Return `sourceRect`.

[Compute Layout and Allocation Size] (with `parsedRect`, `format`, and `layout`)

: 1. Let `numPlanes` be the number of planes as defined by
 `format`.

 2. If `layout` is not `undefined` and its length does
 not equal `numPlanes`, throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 3. Let `minAllocationSize` be `0`.

 4. Let `computedLayouts` be a new
 [list](https://infra.spec.whatwg.org/#list).

 5. Let `endOffsets` be a new
 [list](https://infra.spec.whatwg.org/#list).

 6. Let `planeIndex` be `0`.

 7. While `planeIndex` \< `numPlanes`:

 1. Let `plane` be the Plane identified by
 `planeIndex` as defined by `format`.

 2. Let `sampleBytes` be the number of bytes per
 sample for `plane`.

 3. Let `sampleWidth` be the horizontal [sub-sampling
 factor](#sub-sampling-factor) of each subsample for `plane`.

 4. Let `sampleHeight` be the vertical [sub-sampling
 factor](#sub-sampling-factor) of each subsample for `plane`.

 5. Let `computedLayout` be a new [computed plane
 layout](#computed-plane-layout).

 6. Set `computedLayout`'s
 [sourceTop](#computed-plane-layout-sourcetop) to the result of the division of truncated
 `parsedRect`.[`y`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-y) by `sampleHeight`, rounded up to
 the nearest integer.

 7. Set `computedLayout`'s
 [sourceHeight](#computed-plane-layout-sourceheight) to the result of the division of truncated
 `parsedRect`.[`height`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-height) by `sampleHeight`, rounded up to
 the nearest integer.

 8. Set `computedLayout`'s
 [sourceLeftBytes](#computed-plane-layout-sourceleftbytes) to the result of the integer division of
 truncated
 `parsedRect`.[`x`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-x) by `sampleWidth`, multiplied by
 `sampleBytes`.

 9. Set `computedLayout`'s
 [sourceWidthBytes](#computed-plane-layout-sourcewidthbytes) to the result of the integer division of
 truncated
 `parsedRect`.[`width`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-width) by `sampleWidth`, multiplied by
 `sampleBytes`.

 10. If `layout` is not `undefined`:

 1. Let `planeLayout` be the
 [`PlaneLayout`](#dictdef-planelayout) in `layout` at position
 `planeIndex`.

 2. If
 `planeLayout`.[`stride`](#dom-planelayout-stride) is less than
 `computedLayout`'s
 [sourceWidthBytes](#computed-plane-layout-sourcewidthbytes), return a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 3. Assign
 `planeLayout`.[`offset`](#dom-planelayout-offset) to `computedLayout`'s
 [destinationOffset](#computed-plane-layout-destinationoffset).

 4. Assign
 `planeLayout`.[`stride`](#dom-planelayout-stride) to `computedLayout`'s
 [destinationStride](#computed-plane-layout-destinationstride).

 11. Otherwise:

 [NOTE:] If an explicit layout was not provided, the
 following steps default to tight packing.

 1. Assign `minAllocationSize` to
 `computedLayout`'s
 [destinationOffset](#computed-plane-layout-destinationoffset).

 2. Assign `computedLayout`'s
 [sourceWidthBytes](#computed-plane-layout-sourcewidthbytes) to `computedLayout`'s
 [destinationStride](#computed-plane-layout-destinationstride).

 12. Let `planeSize` be the product of multiplying
 `computedLayout`'s
 [destinationStride](#computed-plane-layout-destinationstride) and
 [sourceHeight](#computed-plane-layout-sourceheight).

 13. Let `planeEnd` be the sum of
 `planeSize` and `computedLayout`'s
 [destinationOffset](#computed-plane-layout-destinationoffset).

 14. If `planeSize` or `planeEnd` is
 greater than maximum range of
 [`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long), return a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 15. Append `planeEnd` to `endOffsets`.

 16. Assign the maximum of `minAllocationSize` and
 `planeEnd` to `minAllocationSize`.

 [NOTE:] The above step uses a maximum to allow for
 the possibility that user specified plane offsets reorder
 planes.

 17. Let `earlierPlaneIndex` be `0`.

 18. While `earlierPlaneIndex` is less than
 `planeIndex`.

 1. Let `earlierLayout` be
 `computedLayouts[earlierPlaneIndex]`.

 2. If `endOffsets[planeIndex]` is less than or equal to
 `earlierLayout`'s
 [destinationOffset](#computed-plane-layout-destinationoffset) or if `endOffsets[earlierPlaneIndex]`
 is less than or equal to `computedLayout`'s
 [destinationOffset](#computed-plane-layout-destinationoffset), continue.

 [NOTE:] If plane A ends before plane B starts,
 they do not overlap.

 3. Otherwise, return a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 4. Increment `earlierPlaneIndex` by `1`.

 19. Append `computedLayout` to
 `computedLayouts`.

 20. Increment `planeIndex` by `1`.

 8. Let `combinedLayout` be a new [combined buffer
 layout](#combined-buffer-layout), initialized as follows:

 1. Assign `computedLayouts` to
 [computedLayouts](#combined-buffer-layout-computedlayouts).

 2. Assign `minAllocationSize` to
 [allocationSize](#combined-buffer-layout-allocationsize).

 9. Return `combinedLayout`.

[Convert PredefinedColorSpace to VideoColorSpace] (with `colorSpace`)

: 1. Assert: `colorSpace` is equal to one of
 [`srgb`](https://html.spec.whatwg.org/multipage/canvas.html#dom-predefinedcolorspace-srgb) or
 [`display-p3`](https://html.spec.whatwg.org/multipage/canvas.html#dom-predefinedcolorspace-display-p3).

 2. If `colorSpace` is equal to
 [`srgb`](https://html.spec.whatwg.org/multipage/canvas.html#dom-predefinedcolorspace-srgb) return a new instance of the [sRGB Color
 Space](#srgb-color-space)

 3. If `colorSpace` is equal to
 [`display-p3`](https://html.spec.whatwg.org/multipage/canvas.html#dom-predefinedcolorspace-display-p3) return a new instance of the [Display P3 Color
 Space](#display-p3-color-space)

[Convert to RGB frame] (with `frame`, `format` and `colorSpace`)

: 1. This algorithm *MUST* be called only if `format` is
 equal to one of
 [`RGBA`](#dom-videopixelformat-rgba),
 [`RGBX`](#dom-videopixelformat-rgbx),
 [`BGRA`](#dom-videopixelformat-bgra),
 [`BGRX`](#dom-videopixelformat-bgrx).

 2. Let `convertedFrame` be a new
 [`VideoFrame`](#videoframe), constructed as follows:

 1. Assign `false` to
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached).

 2. Assign `format` to
 [`[[format]]`](#dom-videoframe-format-slot).

 3. Let `width` be `frame`'s
 [`[[visible width]]`](#dom-videoframe-visible-width-slot).

 4. Let `height` be `frame`'s
 [`[[visible height]]`](#dom-videoframe-visible-height-slot).

 5. Assign `width`, `height`, 0, 0,
 `width`, `height`, `width`,
 and `height` to
 [`[[coded width]]`](#dom-videoframe-coded-width-slot),
 [`[[coded height]]`](#dom-videoframe-coded-height-slot),
 [`[[visible left]]`](#dom-videoframe-visible-left-slot),
 [`[[visible top]]`](#dom-videoframe-visible-top-slot),
 [`[[visible width]]`](#dom-videoframe-visible-width-slot), and
 [`[[visible height]]`](#dom-videoframe-visible-height-slot) respectively.

 6. Assign `frame`'s
 [`[[duration]]`](#dom-videoframe-duration-slot) and `frame`'s
 [`[[timestamp]]`](#dom-videoframe-timestamp-slot) to
 [`[[duration]]`](#dom-videoframe-duration-slot) and
 [`[[timestamp]]`](#dom-videoframe-timestamp-slot) respectively.

 7. Assign the result of running the [Convert
 PredefinedColorSpace to
 VideoColorSpace](#convert-predefinedcolorspace-to-videocolorspace) algorithm with `colorSpace` to
 [`[[color space]]`](#dom-videoframe-color-space-slot).

 8. Let `resource` be a new [media
 resource](#media-resource) containing the result of conversion of
 [media resource](#media-resource) referenced by `frame`'s
 [`[[resource reference]]`](#dom-videoframe-resource-reference-slot) into a color space and pixel format
 specified by
 [`[[color space]]`](#dom-videoframe-color-space-slot) and
 [`[[format]]`](#dom-videoframe-format-slot) respectively.

 9. Assign the reference to `resource` to
 [`[[resource reference]]`](#dom-videoframe-resource-reference-slot)

 3. Return `convertedFrame`.

[Copy VideoFrame metadata] (with `metadata`)

: 1. Let `metadataCopySerialized` be
 [StructuredSerialize](https://html.spec.whatwg.org/multipage/structured-data.html#structuredserialize)(`metadata`).

 2. Let `metadataCopy` be
 [StructuredDeserialize](https://html.spec.whatwg.org/multipage/structured-data.html#structureddeserialize)(`metadataCopySerialized`,
 [the current
 Realm](https://tc39.es/ecma262/#current-realm)).

 3. Return `metadataCopy`.

The goal of this algorithm is to ensure that metadata owned by a
[`VideoFrame`](#videoframe)
is immutable.

#### 9.4.7. Transfer and Serialization

The [`VideoFrame`](#videoframe) [transfer steps](https://html.spec.whatwg.org/multipage/structured-data.html#transfer-steps) (with `value` and `dataHolder`) are:

: 1. If `value`'s
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached) is `true`, throw a
 [`DataCloneError`](https://webidl.spec.whatwg.org/#datacloneerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. For all [`VideoFrame`](#videoframe) internal slots in `value`, assign
 the value of each internal slot to a field in
 `dataHolder` with the same name as the internal slot.

 3. Run the [Close
 VideoFrame](#close-videoframe) algorithm with `value`.

The [`VideoFrame`](#videoframe) [transfer-receiving steps](https://html.spec.whatwg.org/multipage/structured-data.html#transfer-receiving-steps) (with `dataHolder` and `value`) are:

: 1. For all named fields in `dataHolder`, assign the
 value of each named field to the
 [`VideoFrame`](#videoframe) internal slot in `value` with the
 same name as the named field.

The [`VideoFrame`](#videoframe) [serialization steps](https://html.spec.whatwg.org/multipage/structured-data.html#serialization-steps) (with `value`, `serialized`, and `forStorage`) are:

: 1. If `value`'s
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached) is `true`, throw a
 [`DataCloneError`](https://webidl.spec.whatwg.org/#datacloneerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. If `forStorage` is `true`, throw a
 [`DataCloneError`](https://webidl.spec.whatwg.org/#datacloneerror).

 3. Let `resource` be the [media
 resource](#media-resource) referenced by `value`'s
 [`[[resource reference]]`](#dom-videoframe-resource-reference-slot).

 4. Let `newReference` be a new reference to
 `resource`.

 5. Assign `newReference` to \|serialized.resource
 reference\|.

 6. For all remaining
 [`VideoFrame`](#videoframe) internal slots (excluding
 [`[[resource reference]]`](#dom-videoframe-resource-reference-slot)) in `value`, assign the value of
 each internal slot to a field in `serialized` with
 the same name as the internal slot.

The [`VideoFrame`](#videoframe) [deserialization steps](https://html.spec.whatwg.org/multipage/structured-data.html#deserialization-steps) (with `serialized` and `value`) are:

: 1. For all named fields in `serialized`, assign the
 value of each named field to the
 [`VideoFrame`](#videoframe) internal slot in `value` with the
 same name as the named field.

#### 9.4.8. Rendering

When rendered, for example by
[`CanvasDrawImage`](https://html.spec.whatwg.org/multipage/canvas.html#canvasdrawimage)
[`drawImage()`](https://html.spec.whatwg.org/multipage/canvas.html#dom-context-2d-drawimage), a
[`VideoFrame`](#videoframe)
*MUST* be converted to a color space compatible with the rendering
target, unless color conversion is explicitly disabled.

Color space conversion during
[`ImageBitmap`](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#imagebitmap) construction is controlled by
[`ImageBitmapOptions`](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#imagebitmapoptions)
[`colorSpaceConversion`](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#dom-imagebitmapoptions-colorspaceconversion). Setting this value to
[`"none"`](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#dom-colorspaceconversion-none) disables color space conversion.

The rendering of a
[`VideoFrame`](#videoframe)
is produced from the [media
resource](#media-resource) by
applying any necessary color space conversion, cropping to the
[`visibleRect`](#dom-videoframe-visiblerect), rotating clockwise by
[`rotation`](#dom-videoframe-rotation) degrees, and flipping horizontally if
[`flip`](#dom-videoframe-flip) is `true`.

### 9.5. VideoFrame CopyTo() Options

Options to specify a rectangle of pixels to copy, their format, and the
offset and stride of planes in the destination buffer.

```
dictionary VideoFrameCopyToOptions {
 DOMRectInit rect;
 sequence<PlaneLayout> layout;
 VideoPixelFormat format;
 PredefinedColorSpace colorSpace;
};
```

NOTE: The steps of
[`copyTo()`](#dom-videoframe-copyto) or
[`allocationSize()`](#dom-videoframe-allocationsize) will enforce the following requirements:

- The coordinates of
 [`rect`](#dom-videoframecopytooptions-rect) are sample-aligned as determined by
 [`[[format]]`](#dom-videoframe-format-slot).

- If
 [`layout`](#dom-videoframecopytooptions-layout)
 [exists](https://infra.spec.whatwg.org/#map-exists), a
 [`PlaneLayout`](#dictdef-planelayout) is provided for all planes.

[`rect`], of type [DOMRectInit](https://drafts.fxtf.org/geometry-1/#dictdef-domrectinit)

: A
 [`DOMRectInit`](https://drafts.fxtf.org/geometry-1/#dictdef-domrectinit) describing the rectangle of pixels to copy from the
 [`VideoFrame`](#videoframe). If unspecified, the
 [`visibleRect`](#dom-videoframe-visiblerect) will be used.

 [NOTE:] The coded rectangle can be specified by passing
 [`VideoFrame`](#videoframe)'s
 [`codedRect`](#dom-videoframe-codedrect).

 [NOTE:] The default
 [`rect`](#dom-videoframecopytooptions-rect) does not necessarily meet the sample-alignment
 requirement and can result in
 [`copyTo()`](#dom-videoframe-copyto) or
 [`allocationSize()`](#dom-videoframe-allocationsize) rejecting.

[`layout`], of type sequence\<[PlaneLayout](#dictdef-planelayout)\>

: The
 [`PlaneLayout`](#dictdef-planelayout) for each plane in
 [`VideoFrame`](#videoframe), affording the option to specify an offset and
 stride for each plane in the destination
 [`BufferSource`](https://webidl.spec.whatwg.org/#BufferSource). If unspecified, the planes will be tightly packed.
 It is invalid to specify planes that overlap.

[`format`], of type [VideoPixelFormat](#enumdef-videopixelformat)

: A
 [`VideoPixelFormat`](#enumdef-videopixelformat) for the pixel data in the destination
 [`BufferSource`](https://webidl.spec.whatwg.org/#BufferSource). Potential values are:
 [`RGBA`](#dom-videopixelformat-rgba),
 [`RGBX`](#dom-videopixelformat-rgbx),
 [`BGRA`](#dom-videopixelformat-bgra),
 [`BGRX`](#dom-videopixelformat-bgrx). If it does not
 [exist](https://infra.spec.whatwg.org/#map-exists), the destination
 [`BufferSource`](https://webidl.spec.whatwg.org/#BufferSource) will be in the same format as
 [`format`](#dom-videoframe-format) .

[`colorSpace`], of type [PredefinedColorSpace](https://html.spec.whatwg.org/multipage/canvas.html#predefinedcolorspace)

: A
 [`PredefinedColorSpace`](https://html.spec.whatwg.org/multipage/canvas.html#predefinedcolorspace) that *MUST* be used as a target color space for the
 pixel data in the destination
 [`BufferSource`](https://webidl.spec.whatwg.org/#BufferSource), but only if
 [`format`](#dom-videoframecopytooptions-format) is one of
 [`RGBA`](#dom-videopixelformat-rgba),
 [`RGBX`](#dom-videopixelformat-rgbx),
 [`BGRA`](#dom-videopixelformat-bgra),
 [`BGRX`](#dom-videopixelformat-bgrx), otherwise it is ignored. If it does not
 [exist](https://infra.spec.whatwg.org/#map-exists),
 [`srgb`](https://html.spec.whatwg.org/multipage/canvas.html#dom-predefinedcolorspace-srgb) is used.

### 9.6. DOMRects in VideoFrame

The [`VideoFrame`](#videoframe) interface uses
[`DOMRect`](https://drafts.fxtf.org/geometry-1/#domrect)s to specify the position and dimensions for a rectangle
of pixels.
[`DOMRectInit`](https://drafts.fxtf.org/geometry-1/#dictdef-domrectinit) is used with
[`copyTo()`](#dom-videoframe-copyto) and
[`allocationSize()`](#dom-videoframe-allocationsize) to describe the dimensions of the source rectangle.
[`VideoFrame`](#videoframe)
defines
[`codedRect`](#dom-videoframe-codedrect) and
[`visibleRect`](#dom-videoframe-visiblerect) for convenient copying of the coded size and visible
region respectively.

[NOTE:] VideoFrame pixels are only addressable by integer
numbers. All floating point values provided to
[`DOMRectInit`](https://drafts.fxtf.org/geometry-1/#dictdef-domrectinit) will be truncated.

### 9.7. Plane Layout

A
[`PlaneLayout`](#dictdef-planelayout) is a dictionary specifying the offset and stride of a
[`VideoFrame`](#videoframe)
plane once copied to a
[`BufferSource`](https://webidl.spec.whatwg.org/#BufferSource). A sequence of
[`PlaneLayout`](#dictdef-planelayout)s *MAY* be provided to
[`VideoFrame`](#videoframe)'s
[`copyTo()`](#dom-videoframe-copyto) to specify how the plane is laid out in the destination
[`BufferSource`](https://webidl.spec.whatwg.org/#BufferSource). Alternatively, callers can inspect
[`copyTo()`](#dom-videoframe-copyto)'s returned sequence of
[`PlaneLayout`](#dictdef-planelayout)s to learn the offset and stride for planes as decided
by the User Agent.

```
dictionary PlaneLayout {
 [EnforceRange] required unsigned long offset;
 [EnforceRange] required unsigned long stride;
};
```

[`offset`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long)

: The offset in bytes where the given plane begins within a
 [`BufferSource`](https://webidl.spec.whatwg.org/#BufferSource).

[`stride`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long)

: The number of bytes, including padding, used by each row of the
 plane within a
 [`BufferSource`](https://webidl.spec.whatwg.org/#BufferSource).

### 9.8. Pixel Format

Pixel formats describe the arrangement of bytes in each plane as well as
the number and order of the planes. Each format is described in its own
sub-section.

```
enum VideoPixelFormat {
 // 4:2:0 Y, U, V
 "I420",
 "I420P10",
 "I420P12",
 // 4:2:0 Y, U, V, A
 "I420A",
 "I420AP10",
 "I420AP12",
 // 4:2:2 Y, U, V
 "I422",
 "I422P10",
 "I422P12",
 // 4:2:2 Y, U, V, A
 "I422A",
 "I422AP10",
 "I422AP12",
 // 4:4:4 Y, U, V
 "I444",
 "I444P10",
 "I444P12",
 // 4:4:4 Y, U, V, A
 "I444A",
 "I444AP10",
 "I444AP12",
 // 4:2:0 Y, UV
 "NV12",
 // 4:4:4 RGBA
 "RGBA",
 // 4:4:4 RGBX (opaque)
 "RGBX",
 // 4:4:4 BGRA
 "BGRA",
 // 4:4:4 BGRX (opaque)
 "BGRX",
};
```

[Sub-sampling] is a technique where a single
sample contains information for multiple pixels in the final image.
[Sub-sampling](#sub-sampling) can
be horizontal, vertical or both, and has a [factor], that is the number of final pixels in the image that are
derived from a [sub-sampled](#sub-sampling) sample.

If a
[`VideoFrame`](#videoframe)
is in
[`I420`](#dom-videopixelformat-i420) format, then the very first component of the second
plane (the U plane) corresponds to four pixels, that are the pixels in
the top-left angle of the image. Consequently, the first component of
the second row corresponds to the four pixels below those initial four
top-left pixels. The [sub-sampling
factor](#sub-sampling-factor) is 2 in both the horizontal and vertical direction.

If a
[`VideoPixelFormat`](#enumdef-videopixelformat) has an alpha component, the format's [equivalent opaque
format] is the same
[`VideoPixelFormat`](#enumdef-videopixelformat), without an alpha component. If a
[`VideoPixelFormat`](#enumdef-videopixelformat) does not have an alpha component, it is its own
[equivalent opaque
format](#equivalent-opaque-format).

Integer values are unsigned unless otherwise specified.

[`I420`]

: This format is composed of three distinct planes, one plane of Luma
 and two planes of Chroma, denoted Y, U and V, and present in this
 order. It is also often refered to as Planar YUV 4:2:0.

 The U and V planes are
 [sub-sampled](#sub-sampling)
 horizontally and vertically by a
 [factor](#sub-sampling-factor) of 2 compared to the Y plane.

 Each sample in this format is 8 bits.

 There are
 [`codedWidth`](#dom-videoframe-codedwidth) \*
 [`codedHeight`](#dom-videoframe-codedheight) samples (and therefore bytes) in the Y plane,
 arranged starting at the top left of the image, in
 [`codedHeight`](#dom-videoframe-codedheight) rows of
 [`codedWidth`](#dom-videoframe-codedwidth) samples.

 The U and V planes have a number of rows equal to the result of the
 division of
 [`codedHeight`](#dom-videoframe-codedheight) by 2, rounded up to the nearest integer. Each row
 has a number of samples equal to the result of the division of
 [`codedWidth`](#dom-videoframe-codedwidth) by 2, rounded up to the nearest integer. Samples
 are arranged starting at the top left of the image.

 The visible rectangle offset
 ([`visibleRect`](#dom-videoframe-visiblerect).[`x`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-x) and
 [`visibleRect`](#dom-videoframe-visiblerect).[`y`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-y)) *MUST* be even.

[`I420P10`]

: This format is composed of three distinct planes, one plane of Luma
 and two planes of Chroma, denoted Y, U and V, and present in this
 order.

 The U and V planes are
 [sub-sampled](#sub-sampling)
 horizontally and vertically by a
 [factor](#sub-sampling-factor) of 2 compared to the Y plane.

 Each sample in this format is 10 bits, encoded as a 16-bit integer
 in little-endian byte order.

 There are
 [`codedWidth`](#dom-videoframe-codedwidth) \*
 [`codedHeight`](#dom-videoframe-codedheight) samples in the Y plane, arranged starting at the
 top left of the image, in
 [`codedHeight`](#dom-videoframe-codedheight) rows of
 [`codedWidth`](#dom-videoframe-codedwidth) samples.

 The U and V planes have a number of rows equal to the result of the
 division of
 [`codedHeight`](#dom-videoframe-codedheight) by 2, rounded up to the nearest integer. Each row
 has a number of samples equal to the result of the division of
 [`codedWidth`](#dom-videoframe-codedwidth) by 2, rounded up to the nearest integer. Samples
 are arranged starting at the top left of the image.

 The visible rectangle offset
 ([`visibleRect`](#dom-videoframe-visiblerect).[`x`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-x) and
 [`visibleRect`](#dom-videoframe-visiblerect).[`y`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-y)) *MUST* be even.

[`I420P12`]

: This format is composed of three distinct planes, one plane of Luma
 and two planes of Chroma, denoted Y, U and V, and present in this
 order.

 The U and V planes are
 [sub-sampled](#sub-sampling)
 horizontally and vertically by a
 [factor](#sub-sampling-factor) of 2 compared to the Y plane.

 Each sample in this format is 12 bits, encoded as a 16-bit integer
 in little-endian byte order.

 There are
 [`codedWidth`](#dom-videoframe-codedwidth) \*
 [`codedHeight`](#dom-videoframe-codedheight) samples in the Y plane, arranged starting at the
 top left of the image, in
 [`codedHeight`](#dom-videoframe-codedheight) rows of
 [`codedWidth`](#dom-videoframe-codedwidth) samples.

 The U and V planes have a number of rows equal to the result of the
 division of
 [`codedHeight`](#dom-videoframe-codedheight) by 2, rounded up to the nearest integer. Each row
 has a number of samples equal to the result of the division of
 [`codedWidth`](#dom-videoframe-codedwidth) by 2, rounded up to the nearest integer. Samples
 are arranged starting at the top left of the image.

 The visible rectangle offset
 ([`visibleRect`](#dom-videoframe-visiblerect).[`x`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-x) and
 [`visibleRect`](#dom-videoframe-visiblerect).[`y`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-y)) *MUST* be even.

[`I420A`]

: This format is composed of four distinct planes, one plane of Luma,
 two planes of Chroma, denoted Y, U and V, and one plane of Alpha
 values, all present in this order. It is also often refered to as
 Planar YUV 4:2:0 with an alpha channel.

 The U and V planes are
 [sub-sampled](#sub-sampling)
 horizontally and vertically by a
 [factor](#sub-sampling-factor) of 2 compared to the Y and Alpha planes.

 Each sample in this format is 8 bits.

 There are
 [`codedWidth`](#dom-videoframe-codedwidth) \*
 [`codedHeight`](#dom-videoframe-codedheight) samples (and therefore bytes) in the Y and Alpha
 planes, arranged starting at the top left of the image, in
 [`codedHeight`](#dom-videoframe-codedheight) rows of
 [`codedWidth`](#dom-videoframe-codedwidth) samples.

 The U and V planes have a number of rows equal to the result of the
 division of
 [`codedHeight`](#dom-videoframe-codedheight) by 2, rounded up to the nearest integer. Each row
 has a number of samples equal to the result of the division of
 [`codedWidth`](#dom-videoframe-codedwidth) by 2, rounded up to the nearest integer. Samples
 are arranged starting at the top left of the image.

 The visible rectangle offset
 ([`visibleRect`](#dom-videoframe-visiblerect).[`x`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-x) and
 [`visibleRect`](#dom-videoframe-visiblerect).[`y`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-y)) *MUST* be even.

 [`I420A`](#dom-videopixelformat-i420a)'s [equivalent opaque
 format](#equivalent-opaque-format) is
 [`I420`](#dom-videopixelformat-i420).

[`I420AP10`]

: This format is composed of four distinct planes, one plane of Luma,
 two planes of Chroma, denoted Y, U and V, and one plane of Alpha
 values, all present in this order.

 The U and V planes are
 [sub-sampled](#sub-sampling)
 horizontally and vertically by a
 [factor](#sub-sampling-factor) of 2 compared to the Y and Alpha planes.

 Each sample in this format is 10 bits, encoded as a 16-bit integer
 in little-endian byte order.

 There are
 [`codedWidth`](#dom-videoframe-codedwidth) \*
 [`codedHeight`](#dom-videoframe-codedheight) samples in the Y and Alpha planes, arranged
 starting at the top left of the image, in
 [`codedHeight`](#dom-videoframe-codedheight) rows of
 [`codedWidth`](#dom-videoframe-codedwidth) samples.

 The U and V planes have a number of rows equal to the result of the
 division of
 [`codedHeight`](#dom-videoframe-codedheight) by 2, rounded up to the nearest integer. Each row
 has a number of samples equal to the result of the division of
 [`codedWidth`](#dom-videoframe-codedwidth) by 2, rounded up to the nearest integer. Samples
 are arranged starting at the top left of the image.

 The visible rectangle offset
 ([`visibleRect`](#dom-videoframe-visiblerect).[`x`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-x) and
 [`visibleRect`](#dom-videoframe-visiblerect).[`y`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-y)) *MUST* be even.

 [`I420AP10`](#dom-videopixelformat-i420ap10)'s [equivalent opaque
 format](#equivalent-opaque-format) is
 [`I420P10`](#dom-videopixelformat-i420p10).

[`I420AP12`]

: This format is composed of four distinct planes, one plane of Luma,
 two planes of Chroma, denoted Y, U and V, and one plane of Alpha
 values, all present in this order.

 The U and V planes are
 [sub-sampled](#sub-sampling)
 horizontally and vertically by a
 [factor](#sub-sampling-factor) of 2 compared to the Y and Alpha planes.

 Each sample in this format is 12 bits, encoded as a 16-bit integer
 in little-endian byte order.

 There are
 [`codedWidth`](#dom-videoframe-codedwidth) \*
 [`codedHeight`](#dom-videoframe-codedheight) samples in the Y and Alpha planes, arranged
 starting at the top left of the image, in
 [`codedHeight`](#dom-videoframe-codedheight) rows of
 [`codedWidth`](#dom-videoframe-codedwidth) samples.

 The U and V planes have a number of rows equal to the result of the
 division of
 [`codedHeight`](#dom-videoframe-codedheight) by 2, rounded up to the nearest integer. Each row
 has a number of samples equal to the result of the division of
 [`codedWidth`](#dom-videoframe-codedwidth) by 2, rounded up to the nearest integer. Samples
 are arranged starting at the top left of the image.

 The visible rectangle offset
 ([`visibleRect`](#dom-videoframe-visiblerect).[`x`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-x) and
 [`visibleRect`](#dom-videoframe-visiblerect).[`y`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-y)) *MUST* be even.

 [`I420AP12`](#dom-videopixelformat-i420ap12)'s [equivalent opaque
 format](#equivalent-opaque-format) is
 [`I420P12`](#dom-videopixelformat-i420p12).

[`I422`]

: This format is composed of three distinct planes, one plane of Luma
 and two planes of Chroma, denoted Y, U and V, and present in this
 order. It is also often refered to as Planar YUV 4:2:2.

 The U and V planes are
 [sub-sampled](#sub-sampling)
 horizontally by a
 [factor](#sub-sampling-factor) of 2 compared to the Y plane, and not
 [sub-sampled](#sub-sampling)
 vertically.

 Each sample in this format is 8 bits.

 There are
 [`codedWidth`](#dom-videoframe-codedwidth) \*
 [`codedHeight`](#dom-videoframe-codedheight) samples (and therefore bytes) in the Y and plane,
 arranged starting at the top left of the image, in
 [`codedHeight`](#dom-videoframe-codedheight) rows of
 [`codedWidth`](#dom-videoframe-codedwidth) samples.

 The U and V planes have
 [`codedHeight`](#dom-videoframe-codedheight) rows. Each row has a number of samples equal to the
 result of the division of
 [`codedWidth`](#dom-videoframe-codedwidth) by 2, rounded up to the nearest integer. Samples
 are arranged starting at the top left of the image.

 The visible rectangle horizontal offset
 ([`visibleRect`](#dom-videoframe-visiblerect).[`x`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-x)) *MUST* be even.

[`I422P10`]

: This format is composed of three distinct planes, one plane of Luma
 and two planes of Chroma, denoted Y, U and V, and present in this
 order.

 The U and V planes are
 [sub-sampled](#sub-sampling) horizontally by a
 [factor](#sub-sampling-factor) of 2 compared to the Y plane, and not
 [sub-sampled](#sub-sampling) vertically.

 Each sample in this format is 10 bits, encoded as a 16-bit integer
 in little-endian byte order.

 There are
 [`codedWidth`](#dom-videoframe-codedwidth) \*
 [`codedHeight`](#dom-videoframe-codedheight) samples in the Y plane, arranged starting at the
 top left of the image, in
 [`codedHeight`](#dom-videoframe-codedheight) rows of
 [`codedWidth`](#dom-videoframe-codedwidth) samples.

 The U and V planes have
 [`codedHeight`](#dom-videoframe-codedheight) rows. Each row has a number of samples equal to the
 result of the division of
 [`codedWidth`](#dom-videoframe-codedwidth) by 2, rounded up to the nearest integer. Samples
 are arranged starting at the top left of the image.

 The visible rectangle horizontal offset
 ([`visibleRect`](#dom-videoframe-visiblerect).[`x`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-x)) *MUST* be even.

[`I422P12`]

: This format is composed of three distinct planes, one plane of Luma
 and two planes of Chroma, denoted Y, U and V, and present in this
 order.

 The U and V planes are
 [sub-sampled](#sub-sampling) horizontally by a
 [factor](#sub-sampling-factor) of 2 compared to the Y plane, and not
 [sub-sampled](#sub-sampling) vertically.

 Each sample in this format is 12 bits, encoded as a 16-bit integer
 in little-endian byte order.

 There are
 [`codedWidth`](#dom-videoframe-codedwidth) \*
 [`codedHeight`](#dom-videoframe-codedheight) samples in the Y plane, arranged starting at the
 top left of the image, in
 [`codedHeight`](#dom-videoframe-codedheight) rows of
 [`codedWidth`](#dom-videoframe-codedwidth) samples.

 The U and V planes have
 [`codedHeight`](#dom-videoframe-codedheight) rows. Each row has a number of samples equal to the
 result of the division of
 [`codedWidth`](#dom-videoframe-codedwidth) by 2, rounded up to the nearest integer. Samples
 are arranged starting at the top left of the image.

 The visible rectangle horizontal offset
 ([`visibleRect`](#dom-videoframe-visiblerect).[`x`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-x)) *MUST* be even.

[`I422A`]

: This format is composed of four distinct planes, one plane of Luma,
 two planes of Chroma, denoted Y, U and V, and one plane of Alpha
 values, all present in this order. It is also often refered to as
 Planar YUV 4:2:2 with an alpha channel.

 The U and V planes are
 [sub-sampled](#sub-sampling) horizontally by a
 [factor](#sub-sampling-factor) of 2 compared to the Y and Alpha planes, and not
 [sub-sampled](#sub-sampling) vertically.

 Each sample in this format is 8 bits.

 There are
 [`codedWidth`](#dom-videoframe-codedwidth) \*
 [`codedHeight`](#dom-videoframe-codedheight) samples (and therefore bytes) in the Y and Alpha
 planes, arranged starting at the top left of the image, in
 [`codedHeight`](#dom-videoframe-codedheight) rows of
 [`codedWidth`](#dom-videoframe-codedwidth) samples.

 The U and V planes have
 [`codedHeight`](#dom-videoframe-codedheight) rows. Each row has a number of samples equal to the
 result of the division of
 [`codedWidth`](#dom-videoframe-codedwidth) by 2, rounded up to the nearest integer. Samples
 are arranged starting at the top left of the image.

 The visible rectangle horizontal offset
 ([`visibleRect`](#dom-videoframe-visiblerect).[`x`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-x)) *MUST* be even.

 [`I422A`](#dom-videopixelformat-i422a)'s [equivalent opaque
 format](#equivalent-opaque-format) is
 [`I422`](#dom-videopixelformat-i422).

[`I422AP10`]

: This format is composed of four distinct planes, one plane of Luma,
 two planes of Chroma, denoted Y, U and V, and one plane of Alpha
 values, all present in this order.

 The U and V planes are
 [sub-sampled](#sub-sampling) horizontally by a
 [factor](#sub-sampling-factor) of 2 compared to the Y and Alpha planes, and not
 [sub-sampled](#sub-sampling) vertically.

 Each sample in this format is 10 bits, encoded as a 16-bit integer
 in little-endian byte order.

 There are
 [`codedWidth`](#dom-videoframe-codedwidth) \*
 [`codedHeight`](#dom-videoframe-codedheight) samples in the Y and Alpha planes, arranged
 starting at the top left of the image, in
 [`codedHeight`](#dom-videoframe-codedheight) rows of
 [`codedWidth`](#dom-videoframe-codedwidth) samples.

 The U and V planes have
 [`codedHeight`](#dom-videoframe-codedheight) rows. Each row has a number of samples equal to the
 result of the division of
 [`codedWidth`](#dom-videoframe-codedwidth) by 2, rounded up to the nearest integer. Samples
 are arranged starting at the top left of the image.

 The visible rectangle horizontal offset
 ([`visibleRect`](#dom-videoframe-visiblerect).[`x`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-x)) *MUST* be even.

 [`I422AP10`](#dom-videopixelformat-i422ap10)'s [equivalent opaque
 format](#equivalent-opaque-format) is
 [`I420P10`](#dom-videopixelformat-i420p10).

[`I422AP12`]

: This format is composed of four distinct planes, one plane of Luma,
 two planes of Chroma, denoted Y, U and V, and one plane of Alpha
 values, all present in this order.

 The U and V planes are
 [sub-sampled](#sub-sampling) horizontally by a
 [factor](#sub-sampling-factor) of 2 compared to the Y and Alpha planes, and not
 [sub-sampled](#sub-sampling) vertically.

 Each sample in this format is 12 bits, encoded as a 16-bit integer
 in little-endian byte order.

 There are
 [`codedWidth`](#dom-videoframe-codedwidth) \*
 [`codedHeight`](#dom-videoframe-codedheight) samples in the Y and Alpha planes, arranged
 starting at the top left of the image, in
 [`codedHeight`](#dom-videoframe-codedheight) rows of
 [`codedWidth`](#dom-videoframe-codedwidth) samples.

 The U and V planes have
 [`codedHeight`](#dom-videoframe-codedheight) rows. Each row has a number of samples equal to the
 result of the division of
 [`codedWidth`](#dom-videoframe-codedwidth) by 2, rounded up to the nearest integer. Samples
 are arranged starting at the top left of the image.

 The visible rectangle horizontal offset
 ([`visibleRect`](#dom-videoframe-visiblerect).[`x`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-x)) *MUST* be even.

 [`I422AP10`](#dom-videopixelformat-i422ap10)'s [equivalent opaque
 format](#equivalent-opaque-format) is
 [`I420P10`](#dom-videopixelformat-i420p10).

[`I444`]

: This format is composed of three distinct planes, one plane of Luma
 and two planes of Chroma, denoted Y, U and V, and present in this
 order. It is also often refered to as Planar YUV 4:4:4.

 This format does not use
 [sub-sampling](#sub-sampling).

 Each sample in this format is 8 bits.

 There are
 [`codedWidth`](#dom-videoframe-codedwidth) \*
 [`codedHeight`](#dom-videoframe-codedheight) samples (and therefore bytes) in all three planes,
 arranged starting at the top left of the image, in
 [`codedHeight`](#dom-videoframe-codedheight) rows of
 [`codedWidth`](#dom-videoframe-codedwidth) samples.

[`I444P10`]

: This format is composed of three distinct planes, one plane of Luma
 and two planes of Chroma, denoted Y, U and V, and present in this
 order.

 This format does not use
 [sub-sampling](#sub-sampling).

 Each sample in this format is 10 bits, encoded as a 16-bit integer
 in little-endian byte order.

 There are
 [`codedWidth`](#dom-videoframe-codedwidth) \*
 [`codedHeight`](#dom-videoframe-codedheight) samples in all three planes, arranged starting at
 the top left of the image, in
 [`codedHeight`](#dom-videoframe-codedheight) rows of
 [`codedWidth`](#dom-videoframe-codedwidth) samples.

[`I444P12`]

: This format is composed of three distinct planes, one plane of Luma
 and two planes of Chroma, denoted Y, U and V, and present in this
 order.

 This format does not use
 [sub-sampling](#sub-sampling).

 Each sample in this format is 12 bits, encoded as a 16-bit integer
 in little-endian byte order.

 There are
 [`codedWidth`](#dom-videoframe-codedwidth) \*
 [`codedHeight`](#dom-videoframe-codedheight) samples in all three planes, arranged starting at
 the top left of the image, in
 [`codedHeight`](#dom-videoframe-codedheight) rows of
 [`codedWidth`](#dom-videoframe-codedwidth) samples.

[`I444A`]

: This format is composed of four distinct planes, one plane of Luma,
 two planes of Chroma, denoted Y, U and V, and one plane of Alpha
 values, all present in this order.

 This format does not use
 [sub-sampling](#sub-sampling).

 Each sample in this format is 8 bits.

 There are
 [`codedWidth`](#dom-videoframe-codedwidth) \*
 [`codedHeight`](#dom-videoframe-codedheight) samples (and therefore bytes) in all four planes,
 arranged starting at the top left of the image, in
 [`codedHeight`](#dom-videoframe-codedheight) rows of
 [`codedWidth`](#dom-videoframe-codedwidth) samples.

 [`I444A`](#dom-videopixelformat-i444a)'s [equivalent opaque
 format](#equivalent-opaque-format) is
 [`I444`](#dom-videopixelformat-i444).

[`I444AP10`]

: This format is composed of four distinct planes, one plane of Luma,
 two planes of Chroma, denoted Y, U and V, and one plane of Alpha
 values, all present in this order.

 This format does not use
 [sub-sampling](#sub-sampling).

 Each sample in this format is 10 bits, encoded as a 16-bit integer
 in little-endian byte order.

 There are
 [`codedWidth`](#dom-videoframe-codedwidth) \*
 [`codedHeight`](#dom-videoframe-codedheight) samples in all four planes, arranged starting at
 the top left of the image, in
 [`codedHeight`](#dom-videoframe-codedheight) rows of
 [`codedWidth`](#dom-videoframe-codedwidth) samples.

 [`I444AP10`](#dom-videopixelformat-i444ap10)'s [equivalent opaque
 format](#equivalent-opaque-format) is
 [`I444P10`](#dom-videopixelformat-i444p10).

[`I444AP12`]

: This format is composed of four distinct planes, one plane of Luma,
 two planes of Chroma, denoted Y, U and V, and one plane of Alpha
 values, all present in this order.

 This format does not use
 [sub-sampling](#sub-sampling).

 Each sample in this format is 12 bits, encoded as a 16-bit integer
 in little-endian byte order.

 There are
 [`codedWidth`](#dom-videoframe-codedwidth) \*
 [`codedHeight`](#dom-videoframe-codedheight) samples in all four planes, arranged starting at
 the top left of the image, in
 [`codedHeight`](#dom-videoframe-codedheight) rows of
 [`codedWidth`](#dom-videoframe-codedwidth) samples.

 [`I444AP10`](#dom-videopixelformat-i444ap10)'s [equivalent opaque
 format](#equivalent-opaque-format) is
 [`I444P10`](#dom-videopixelformat-i444p10).

[`NV12`]

: This format is composed of two distinct planes, one plane of Luma
 and then another plane for the two Chroma components. The two planes
 are present in this order, and are refered to as respectively the Y
 plane and the UV plane.

 The U and V components are
 [sub-sampled](#sub-sampling) horizontally and vertically by a
 [factor](#sub-sampling-factor) of 2 compared to the components in the Y planes.

 Each sample in this format is 8 bits.

 There are
 [`codedWidth`](#dom-videoframe-codedwidth) \*
 [`codedHeight`](#dom-videoframe-codedheight) samples (and therefore bytes) in the Y and plane,
 arranged starting at the top left of the image, in
 [`codedHeight`](#dom-videoframe-codedheight) rows of
 [`codedWidth`](#dom-videoframe-codedwidth) samples.

 The UV plane is composed of interleaved U and V values, in a number
 of rows equal to the result of the division of
 [`codedHeight`](#dom-videoframe-codedheight) by 2, rounded up to the nearest integer. Each row
 has a number of elements equal to the result of the division of
 [`codedWidth`](#dom-videoframe-codedwidth) by 2, rounded up to the nearest integer. Each
 element is composed of two Chroma samples, the U and V samples, in
 that order. Samples are arranged starting at the top left of the
 image.

 The visible rectangle offset
 ([`visibleRect`](#dom-videoframe-visiblerect).[`x`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-x) and
 [`visibleRect`](#dom-videoframe-visiblerect).[`y`](https://drafts.fxtf.org/geometry-1/#dom-domrectinit-y)) *MUST* be even.

 :::
 (#example-26ede914) An image in the NV12 pixel format
 that is 16 pixels wide and 10 pixels tall will be arranged like so
 in memory:
 YYYYYYYYYYYYYYYY
 YYYYYYYYYYYYYYYY
 YYYYYYYYYYYYYYYY
 YYYYYYYYYYYYYYYY
 YYYYYYYYYYYYYYYY
 YYYYYYYYYYYYYYYY
 YYYYYYYYYYYYYYYY
 YYYYYYYYYYYYYYYY
 YYYYYYYYYYYYYYYY
 YYYYYYYYYYYYYYYY
 UVUVUVUVUVUVUVUV
 UVUVUVUVUVUVUVUV
 UVUVUVUVUVUVUVUV
 UVUVUVUVUVUVUVUV
 UVUVUVUVUVUVUVUV

 All samples being linear in memory.
 :::

[`RGBA`]

: This format is composed of a single plane, that encodes four
 components: Red, Green, Blue, and an alpha value, present in this
 order.

 Each sample in this format is 8 bits, and each pixel is therefore 32
 bits.

 There are
 [`codedWidth`](#dom-videoframe-codedwidth) \*
 [`codedHeight`](#dom-videoframe-codedheight) \* 4 samples (and therefore bytes) in the single
 plane, arranged starting at the top left of the image, in
 [`codedHeight`](#dom-videoframe-codedheight) rows of
 [`codedWidth`](#dom-videoframe-codedwidth) samples.

 [`RGBA`](#dom-videopixelformat-rgba)'s [equivalent opaque
 format](#equivalent-opaque-format) is
 [`RGBX`](#dom-videopixelformat-rgbx).

[`RGBX`]

: This format is composed of a single plane, that encodes four
 components: Red, Green, Blue, and a padding value, present in this
 order.

 Each sample in this format is 8 bits. The fourth element in each
 pixel is to be ignored, the image is always fully opaque.

 There are
 [`codedWidth`](#dom-videoframe-codedwidth) \*
 [`codedHeight`](#dom-videoframe-codedheight) \* 4 samples (and therefore bytes) in the single
 plane, arranged starting at the top left of the image, in
 [`codedHeight`](#dom-videoframe-codedheight) rows of
 [`codedWidth`](#dom-videoframe-codedwidth) samples.

[`BGRA`]

: This format is composed of a single plane, that encodes four
 components: Blue, Green, Red, and an alpha value, present in this
 order.

 Each sample in this format is 8 bits.

 There are
 [`codedWidth`](#dom-videoframe-codedwidth) \*
 [`codedHeight`](#dom-videoframe-codedheight) \* 4 samples (and therefore bytes) in the single
 plane, arranged starting at the top left of the image, in
 [`codedHeight`](#dom-videoframe-codedheight) rows of
 [`codedWidth`](#dom-videoframe-codedwidth) samples.

 [`BGRA`](#dom-videopixelformat-bgra)'s [equivalent opaque
 format](#equivalent-opaque-format) is
 [`BGRX`](#dom-videopixelformat-bgrx).

[`BGRX`]

: This format is composed of a single plane, that encodes four
 components: Blue, Green, Red, and a padding value, present in this
 order.

 Each sample in this format is 8 bits. The fourth element in each
 pixel is to be ignored, the image is always fully opaque.

 There are
 [`codedWidth`](#dom-videoframe-codedwidth) \*
 [`codedHeight`](#dom-videoframe-codedheight) \* 4 samples (and therefore bytes) in the single
 plane, arranged starting at the top left of the image, in
 [`codedHeight`](#dom-videoframe-codedheight) rows of
 [`codedWidth`](#dom-videoframe-codedwidth) samples.

### 9.9. Video Color Space Interface

```
[Exposed=(Window,DedicatedWorker)]
interface VideoColorSpace {
 constructor(optional VideoColorSpaceInit init = );

 readonly attribute VideoColorPrimaries? primaries;
 readonly attribute VideoTransferCharacteristics? transfer;
 readonly attribute VideoMatrixCoefficients? matrix;
 readonly attribute boolean? fullRange;

 [Default] VideoColorSpaceInit toJSON();
};

dictionary VideoColorSpaceInit {
 VideoColorPrimaries? primaries = null;
 VideoTransferCharacteristics? transfer = null;
 VideoMatrixCoefficients? matrix = null;
 boolean? fullRange = null;
};
```

#### 9.9.1. Internal Slots

[`[[primaries]]`]

: The color primaries.

[`[[transfer]]`]

: The transfer characteristics.

[`[[matrix]]`]

: The matrix coefficients.

[`[[full range]]`]

: Indicates whether full-range color values are used.

#### 9.9.2. Constructors

[` VideoColorSpace(init) `]

1. Let `c` be a new
 [`VideoColorSpace`](#videocolorspace) object, initialized as follows:

 1. Assign `init.primaries` to
 [`[[primaries]]`](#dom-videocolorspace-primaries-slot).

 2. Assign `init.transfer` to
 [`[[transfer]]`](#dom-videocolorspace-transfer-slot).

 3. Assign `init.matrix` to
 [`[[matrix]]`](#dom-videocolorspace-matrix-slot).

 4. Assign `init.fullRange` to
 [`[[full range]]`](#dom-videocolorspace-full-range-slot).

2. Return `c`.

#### 9.9.3. Attributes

[`primaries`], of type [VideoColorPrimaries](#enumdef-videocolorprimaries), readonly, nullable

: The
 [`primaries`](#dom-videocolorspace-primaries) getter steps are to return the value of
 [`[[primaries]]`](#dom-videocolorspace-primaries-slot).

[`transfer`], of type [VideoTransferCharacteristics](#enumdef-videotransfercharacteristics), readonly, nullable

: The
 [`transfer`](#dom-videocolorspace-transfer) getter steps are to return the value of
 [`[[transfer]]`](#dom-videocolorspace-transfer-slot).

[`matrix`], of type [VideoMatrixCoefficients](#enumdef-videomatrixcoefficients), readonly, nullable

: The
 [`matrix`](#dom-videocolorspace-matrix) getter steps are to return the value of
 [`[[matrix]]`](#dom-videocolorspace-matrix-slot).

[`fullRange`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), readonly, nullable

: The
 [`fullRange`](#dom-videocolorspace-fullrange) getter steps are to return the value of
 [`[[full range]]`](#dom-videocolorspace-full-range-slot).

### 9.10. Video Color Primaries

Color primaries describe the color gamut of video samples.

```
enum VideoColorPrimaries {
 "bt709",
 "bt470bg",
 "smpte170m",
 "bt2020",
 "smpte432",
};
```

[`bt709`]
: Color primaries used by BT.709 and sRGB, as described by
 [\[H.273\]](#biblio-h273 "Coding-independent code points for video signal type identification")
 section 8.1 table 2 value 1.

[`bt470bg`]
: Color primaries used by BT.601 PAL, as described by
 [\[H.273\]](#biblio-h273 "Coding-independent code points for video signal type identification")
 section 8.1 table 2 value 5.

[`smpte170m`]
: Color primaries used by BT.601 NTSC, as described by
 [\[H.273\]](#biblio-h273 "Coding-independent code points for video signal type identification")
 section 8.1 table 2 value 6.

[`bt2020`]
: Color primaries used by BT.2020 and BT.2100, as described by
 [\[H.273\]](#biblio-h273 "Coding-independent code points for video signal type identification")
 section 8.1 table 2 value 9.

[`smpte432`]
: Color primaries used by P3 D65, as described by
 [\[H.273\]](#biblio-h273 "Coding-independent code points for video signal type identification")
 section 8.1 table 2 value 12.

### 9.11. Video Transfer Characteristics

Transfer characteristics describe the opto-electronic transfer
characteristics of video samples.

```
enum VideoTransferCharacteristics {
 "bt709",
 "smpte170m",
 "iec61966-2-1",
 "linear",
 "pq",
 "hlg",
};
```

[`bt709`]
: Transfer characteristics used by BT.709, as described by
 [\[H.273\]](#biblio-h273 "Coding-independent code points for video signal type identification")
 section 8.2 table 3 value 1.

[`smpte170m`]
: Transfer characteristics used by BT.601, as described by
 [\[H.273\]](#biblio-h273 "Coding-independent code points for video signal type identification")
 section 8.2 table 3 value 6. (Functionally the same as \"bt709\".)

[`iec61966-2-1`]
: Transfer characteristics used by sRGB, as described by
 [\[H.273\]](#biblio-h273 "Coding-independent code points for video signal type identification")
 section 8.2 table 3 value 13.

[`linear`]
: Transfer characteristics used by linear RGB, as described by
 [\[H.273\]](#biblio-h273 "Coding-independent code points for video signal type identification")
 section 8.2 table 3 value 8.

[`pq`]
: Transfer characteristics used by BT.2100 PQ, as described by
 [\[H.273\]](#biblio-h273 "Coding-independent code points for video signal type identification")
 section 8.2 table 3 value 16.

[`hlg`]
: Transfer characteristics used by BT.2100 HLG, as described by
 [\[H.273\]](#biblio-h273 "Coding-independent code points for video signal type identification")
 section 8.2 table 3 value 18.

### 9.12. Video Matrix Coefficients

Matrix coefficients describe the relationship between sample component
values and color coordinates.

```
enum VideoMatrixCoefficients {
 "rgb",
 "bt709",
 "bt470bg",
 "smpte170m",
 "bt2020-ncl",
};
```

[`rgb`]
: Matrix coefficients used by sRGB, as described by
 [\[H.273\]](#biblio-h273 "Coding-independent code points for video signal type identification")
 section 8.3 table 4 value 0.

[`bt709`]
: Matrix coefficients used by BT.709, as described by
 [\[H.273\]](#biblio-h273 "Coding-independent code points for video signal type identification")
 section 8.3 table 4 value 1.

[`bt470bg`]
: Matrix coefficients used by BT.601 PAL, as described by
 [\[H.273\]](#biblio-h273 "Coding-independent code points for video signal type identification")
 section 8.3 table 4 value 5.

[`smpte170m`]
: Matrix coefficients used by BT.601 NTSC, as described by
 [\[H.273\]](#biblio-h273 "Coding-independent code points for video signal type identification")
 section 8.3 table 4 value 6. (Functionally the same as \"bt470bg\".)

[`bt2020-ncl`]
: Matrix coefficients used by BT.2020 NCL, as described by
 [\[H.273\]](#biblio-h273 "Coding-independent code points for video signal type identification")
 section 8.3 table 4 value 9.

## 10. Image Decoding

### 10.1. Background

::: non-normative
This section is non-normative.

Image codec definitions are typically accompanied by a definition for a
corresponding file format. Hence image decoders often perform both
duties of unpacking (demuxing) as well as decoding the encoded image
data. The WebCodecs
[`ImageDecoder`](#imagedecoder) follows this pattern, which motivates an interface
design that is notably different from that of
[`VideoDecoder`](#videodecoder) and
[`AudioDecoder`](#audiodecoder).

In spite of these differences,
[`ImageDecoder`](#imagedecoder) uses the same [codec processing
model](#codec-processing-model) as the other codec interfaces. Additionally,
[`ImageDecoder`](#imagedecoder) uses the
[`VideoFrame`](#videoframe)
interface to describe decoded outputs.

### 10.2. ImageDecoder Interface

```
[Exposed=(Window,DedicatedWorker), SecureContext]
interface ImageDecoder {
 constructor(ImageDecoderInit init);

 readonly attribute DOMString type;
 readonly attribute boolean complete;
 readonly attribute Promise<undefined> completed;
 readonly attribute ImageTrackList tracks;

 Promise<ImageDecodeResult> decode(optional ImageDecodeOptions options = );
 undefined reset();
 undefined close();

 static Promise<boolean> isTypeSupported(DOMString type);
};
```

#### 10.2.1. Internal Slots

[`[[control message queue]]`]

: A [queue](https://infra.spec.whatwg.org/#queue) of [control
 messages](#control-message) to be performed upon this
 [codec](#codec) instance. See
 [\[\[control message
 queue\]\]](#control-message-queue-slot).

[`[[message queue blocked]]`]

: A boolean indicating when processing the
 [`[[control message queue]]`](#dom-imagedecoder-control-message-queue-slot) is blocked by a pending [control
 message](#control-message). See [\[\[message queue
 blocked\]\]](#message-queue-blocked).

[`[[codec work queue]]`]

: A [parallel
 queue](https://html.spec.whatwg.org/multipage/infrastructure.html#parallel-queue) used for running parallel steps that reference the
 [`[[codec implementation]]`](#dom-imagedecoder-codec-implementation-slot). See [\[\[codec work
 queue\]\]](#codec-work-queue).

[`[[ImageTrackList]]`]

: An
 [`ImageTrackList`](#imagetracklist) describing the tracks found in
 [`[[encoded data]]`](#dom-imagedecoder-encoded-data-slot)

[`[[type]]`]

: A string reflecting the value of the MIME
 [`type`](#dom-imagedecoderinit-type) given at construction.

[`[[complete]]`]

: A boolean indicating whether
 [`[[encoded data]]`](#dom-imagedecoder-encoded-data-slot) is completely buffered.

[`[[completed promise]]`]

: The promise used to signal when
 [`[[complete]]`](#dom-imagedecoder-complete-slot) becomes `true`.

[`[[codec implementation]]`]

: An underlying image decoder implementation provided by the User
 Agent. See [\[\[codec
 implementation\]\]](#codec-implementation).

[`[[encoded data]]`]

: A [byte
 sequence](https://infra.spec.whatwg.org/#byte-sequence) containing the encoded image data to be decoded.

[`[[prefer animation]]`]

: A boolean reflecting the value of
 [`preferAnimation`](#dom-imagedecoderinit-preferanimation) given at construction.

[`[[pending decode promises]]`]

: A list of unresolved promises returned by calls to decode().

[`[[internal selected track index]]`]

: Identifies the image track within
 [`[[encoded data]]`](#dom-imagedecoder-encoded-data-slot) that is used by decoding algorithms.

[`[[tracks established]]`]

: A boolean indicating whether the track list has been established in
 [`[[ImageTrackList]]`](#dom-imagedecoder-imagetracklist-slot).

[`[[closed]]`]

: A boolean indicating that the
 [`ImageDecoder`](#imagedecoder) is in a permanent closed state and can no longer be
 used.

[`[[progressive frame generations]]`]

: A mapping of frame indices to [Progressive Image Frame
 Generations](#progressive-image-frame-generation). The values represent the Progressive Image Frame
 Generation for the
 [`VideoFrame`](#videoframe) which was most recently output by a call to
 [`decode()`](#dom-imagedecoder-decode) with the given frame index.

#### 10.2.2. Constructor

[` ImageDecoder(init) `]

: [NOTE:] Calling
 [`decode()`](#dom-imagedecoder-decode) on the constructed
 [`ImageDecoder`](#imagedecoder) will trigger a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror) if the User Agent does not support
 `type`. Authors are encouraged to first check support by
 calling
 [`isTypeSupported()`](#dom-imagedecoder-istypesupported) with `type`. User Agents don't have to
 support any particular type.

 When invoked, run these steps:

 1. If `init` is not [valid
 ImageDecoderInit](#valid-imagedecoderinit), throw a
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 2. If
 `init`.[`transfer`](#dom-imagedecoderinit-transfer) contains more than one reference to the same
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer), then throw a
 [`DataCloneError`](https://webidl.spec.whatwg.org/#datacloneerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 3. For each `transferable` in
 `init`.[`transfer`](#dom-imagedecoderinit-transfer):

 1. If
 [`[[Detached]]`](https://html.spec.whatwg.org/multipage/structured-data.html#detached) internal slot is `true`, then throw a
 [`DataCloneError`](https://webidl.spec.whatwg.org/#datacloneerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 4. Let `d` be a new
 [`ImageDecoder`](#imagedecoder) object. In the steps below, all mentions of
 [`ImageDecoder`](#imagedecoder) members apply to `d` unless stated
 otherwise.

 5. Assign a new
 [queue](https://infra.spec.whatwg.org/#queue) to
 [`[[control message queue]]`](#dom-imagedecoder-control-message-queue-slot).

 6. Assign `false` to
 [`[[message queue blocked]]`](#dom-imagedecoder-message-queue-blocked-slot).

 7. Assign the result of starting a new [parallel
 queue](https://html.spec.whatwg.org/multipage/infrastructure.html#parallel-queue) to
 [`[[codec work queue]]`](#dom-imagedecoder-codec-work-queue-slot).

 8. Assign
 [`[[ImageTrackList]]`](#dom-imagedecoder-imagetracklist-slot) a new
 [`ImageTrackList`](#imagetracklist) initialized as follows:

 1. Assign a new
 [list](https://infra.spec.whatwg.org/#list) to
 [`[[track list]]`](#dom-imagetracklist-track-list-slot).

 2. Assign `-1` to
 [`[[selected index]]`](#dom-imagetracklist-selected-index-slot).

 9. Assign
 [`type`](#dom-imagedecoderinit-type) to
 [`[[type]]`](#dom-imagedecoder-type-slot).

 10. Assign `null` to
 [`[[codec implementation]]`](#dom-imagedecoder-codec-implementation-slot).

 11. If `init.preferAnimation`
 [exists](https://infra.spec.whatwg.org/#map-exists), assign `init.preferAnimation` to the
 [`[[prefer animation]]`](#dom-imagedecoder-prefer-animation-slot) internal slot. Otherwise, assign \'null\' to
 [`[[prefer animation]]`](#dom-imagedecoder-prefer-animation-slot) internal slot.

 12. Assign a new
 [list](https://infra.spec.whatwg.org/#list) to
 [`[[pending decode promises]]`](#dom-imagedecoder-pending-decode-promises-slot).

 13. Assign `-1` to
 [`[[internal selected track index]]`](#dom-imagedecoder-internal-selected-track-index-slot).

 14. Assign `false` to
 [`[[tracks established]]`](#dom-imagedecoder-tracks-established-slot).

 15. Assign `false` to
 [`[[closed]]`](#dom-imagedecoder-closed-slot).

 16. Assign a new
 [map](https://infra.spec.whatwg.org/#ordered-map) to
 [`[[progressive frame generations]]`](#dom-imagedecoder-progressive-frame-generations-slot).

 17. If `init`'s
 [`data`](#dom-imagedecoderinit-data) member is of type
 [`ReadableStream`](https://streams.spec.whatwg.org/#readablestream):

 1. Assign a new
 [list](https://infra.spec.whatwg.org/#list) to
 [`[[encoded data]]`](#dom-imagedecoder-encoded-data-slot).

 2. Assign `false` to
 [`[[complete]]`](#dom-imagedecoder-complete-slot)

 3. [Queue a control
 message](#enqueues-a-control-message) to [configure the image
 decoder](#configure-the-image-decoder) with `init`.

 4. [Process the control message
 queue](#process-the-control-message-queue).

 5. Let `reader` be the result of [getting a
 reader](https://streams.spec.whatwg.org/#readablestream-get-a-reader) for
 [`data`](#dom-imagedecoderinit-data).

 6. In parallel, perform the [Fetch Stream Data
 Loop](#imagedecoder-fetch-stream-data-loop) on `d` with `reader`.

 18. Otherwise:

 1. Assert that `init.data` is of type
 [`BufferSource`](https://webidl.spec.whatwg.org/#BufferSource).

 2. If
 `init`.[`transfer`](#dom-imagedecoderinit-transfer) contains an
 [`ArrayBuffer`](https://webidl.spec.whatwg.org/#idl-ArrayBuffer) referenced by
 `init`.[`data`](#dom-imagedecoderinit-data) the User Agent *MAY* choose to:

 1. Let
 [`[[encoded data]]`](#dom-imagedecoder-encoded-data-slot) reference bytes in `data`
 representing an encoded image.

 3. Otherwise:

 1. Assign a copy of `init.data` to
 [`[[encoded data]]`](#dom-imagedecoder-encoded-data-slot).

 4. Assign `true` to
 [`[[complete]]`](#dom-imagedecoder-complete-slot).

 5. Resolve
 [`[[completed promise]]`](#dom-imagedecoder-completed-promise-slot).

 6. Queue a control message to [configure the image
 decoder](#configure-the-image-decoder) with `init`.

 7. Queue a control message to [decode track
 metadata](#decode-track-metadata).

 8. [Process the control message
 queue](#process-the-control-message-queue).

 19. For each `transferable` in
 `init`.[`transfer`](#dom-imagedecoderinit-transfer):

 1. Perform
 [DetachArrayBuffer](https://tc39.es/ecma262/#sec-detacharraybuffer)
 on `transferable`

 20. return `d`.

 [Running a control
 message](#running-a-control-message) to [configure the image
 decoder] means running these steps:

 1. Let `supported` be the result of running the [Check
 Type
 Support](#imagedecoder-check-type-support) algorithm with `init.type`.

 2. If `supported` is `false`, run the [Close
 ImageDecoder](#imagedecoder-close-imagedecoder) algorithm with a
 [`NotSupportedError`](https://webidl.spec.whatwg.org/#notsupportederror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and return `"processed"`.

 3. Otherwise, assign the
 [`[[codec implementation]]`](#dom-imagedecoder-codec-implementation-slot) internal slot with an implementation supporting
 `init.type`

 4. Assign `true` to
 [`[[message queue blocked]]`](#dom-imagedecoder-message-queue-blocked-slot).

 5. Enqueue the following steps to the
 [`[[codec work queue]]`](#dom-imagedecoder-codec-work-queue-slot):

 1. Configure
 [`[[codec implementation]]`](#dom-imagedecoder-codec-implementation-slot) in accordance with the values given for
 [`colorSpaceConversion`](#dom-imagedecoderinit-colorspaceconversion),
 [`desiredWidth`](#dom-imagedecoderinit-desiredwidth), and
 [`desiredHeight`](#dom-imagedecoderinit-desiredheight).

 2. Assign `false` to
 [`[[message queue blocked]]`](#dom-imagedecoder-message-queue-blocked-slot).

 3. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to [Process the control message
 queue](#process-the-control-message-queue).

 6. Return `"processed"`.

 [Running a control
 message](#running-a-control-message) to [decode track metadata] means running these
 steps:

 1. Enqueue the following steps to the
 [`[[codec work queue]]`](#dom-imagedecoder-codec-work-queue-slot):

 1. Run the [Establish
 Tracks](#imagedecoder-establish-tracks) algorithm.

#### 10.2.3. Attributes

[`type`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString), readonly

: A string reflecting the value of the MIME
 [`type`](#dom-imagedecoderinit-type) given at construction.

 The
 [`type`](#dom-imagedecoder-type) getter steps are to return
 [`[[type]]`](#dom-imagedecoder-type-slot).

[`complete`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), readonly

: Indicates whether
 [`[[encoded data]]`](#dom-imagedecoder-encoded-data-slot) is completely buffered.

 The
 [`complete`](#dom-imagedecoder-complete) getter steps are to return
 [`[[complete]]`](#dom-imagedecoder-complete-slot).

[`completed`], of type Promise\<[undefined](https://webidl.spec.whatwg.org/#idl-undefined)\>, readonly

: The promise used to signal when
 [`complete`](#dom-imagedecoder-complete) becomes `true`.

 The
 [`completed`](#dom-imagedecoder-completed) getter steps are to return
 [`[[completed promise]]`](#dom-imagedecoder-completed-promise-slot).

[`tracks`], of type [ImageTrackList](#imagetracklist), readonly

: Returns a
 [live](https://html.spec.whatwg.org/multipage/infrastructure.html#live)
 [`ImageTrackList`](#imagetracklist), which provides metadata for the available tracks
 and a mechanism for selecting a track to decode.

 The
 [`tracks`](#dom-imagedecoder-tracks) getter steps are to return
 [`[[ImageTrackList]]`](#dom-imagedecoder-imagetracklist-slot).

#### 10.2.4. Methods

[`decode(options)`]

: Enqueues a control message to decode the frame according to
 `options`.

 When invoked, run these steps:

 1. If
 [`[[closed]]`](#dom-imagedecoder-closed-slot) is `true`, return a
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) rejected with an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. If
 [`[[ImageTrackList]]`](#dom-imagedecoder-imagetracklist-slot)'s
 [`[[selected index]]`](#dom-imagetracklist-selected-index-slot) is \'-1\', return a
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) rejected with an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 3. If `options` is `undefined`, assign a new
 [`ImageDecodeOptions`](#dictdef-imagedecodeoptions) to `options`.

 4. Let `promise` be a new
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise).

 5. Append `promise` to
 [`[[pending decode promises]]`](#dom-imagedecoder-pending-decode-promises-slot).

 6. [Queue a control
 message](#enqueues-a-control-message) to decode the image with `options`,
 and `promise`.

 7. [Process the control message
 queue](#process-the-control-message-queue).

 8. Return `promise`.

 [Running a control
 message](#running-a-control-message) to decode the image means running these steps:

 1. Enqueue the following steps to the
 [`[[codec work queue]]`](#dom-imagedecoder-codec-work-queue-slot):

 1. Wait for
 [`[[tracks established]]`](#dom-imagedecoder-tracks-established-slot) to become `true`.

 2. If
 `options`.[`completeFramesOnly`](#dom-imagedecodeoptions-completeframesonly) is `false` and the image is a [Progressive
 Image](#progressive-image) for which the User Agent supports
 progressive decoding, run the [Decode Progressive
 Frame](#imagedecoder-decode-progressive-frame) algorithm with
 `options`.[`frameIndex`](#dom-imagedecodeoptions-frameindex) and `promise`.

 3. Otherwise, run the [Decode Complete
 Frame](#imagedecoder-decode-complete-frame) algorithm with
 `options`.[`frameIndex`](#dom-imagedecodeoptions-frameindex) and `promise`.

[`reset()`]

: Immediately aborts all pending work.

 When invoked, run the [Reset
 ImageDecoder](#imagedecoder-reset-imagedecoder) algorithm with an
 [`AbortError`](https://webidl.spec.whatwg.org/#aborterror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

[`close()`]

: Immediately aborts all pending work and releases system resources.
 Close is final.

 When invoked, run the [Close
 ImageDecoder](#imagedecoder-close-imagedecoder) algorithm with an
 [`AbortError`](https://webidl.spec.whatwg.org/#aborterror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

[`isTypeSupported(type)`]

: Returns a promise indicating whether the provided config is
 supported by the User Agent.

 When invoked, run these steps:

 1. If `type` is not a [valid image MIME
 type](#valid-image-mime-type), return a
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise) rejected with
 [`TypeError`](https://webidl.spec.whatwg.org/#exceptiondef-typeerror).

 2. Let `p` be a new
 [`Promise`](https://webidl.spec.whatwg.org/#idl-promise).

 3. In parallel, resolve `p` with the result of running
 the [Check Type
 Support](#imagedecoder-check-type-support) algorithm with `type`.

 4. Return `p`.

#### 10.2.5. Algorithms

[Fetch Stream Data Loop] (with `reader`)

: Run these steps:

 1. Let `readRequest` be the following [read
 request](https://streams.spec.whatwg.org/#read-request).

 [chunk steps](https://streams.spec.whatwg.org/#read-request-chunk-steps), given `chunk`

 : 1. If
 [`[[closed]]`](#dom-imagedecoder-closed-slot) is `true`, abort these steps.

 2. If `chunk` is not a Uint8Array object, [queue
 a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the [Close
 ImageDecoder](#imagedecoder-close-imagedecoder) algorithm with a
 [`DataError`](https://webidl.spec.whatwg.org/#dataerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException) and abort these steps.

 3. Let `bytes` be the byte sequence represented
 by the Uint8Array object.

 4. Append `bytes` to the
 [`[[encoded data]]`](#dom-imagedecoder-encoded-data-slot) internal slot.

 5. If
 [`[[tracks established]]`](#dom-imagedecoder-tracks-established-slot) is `false`, run the [Establish
 Tracks](#imagedecoder-establish-tracks) algorithm.

 6. Otherwise, run the [Update
 Tracks](#imagedecoder-update-tracks) algorithm.

 7. Run the [Fetch Stream Data
 Loop](#imagedecoder-fetch-stream-data-loop) algorithm with `reader`.

 [close steps](https://streams.spec.whatwg.org/#read-request-close-steps)

 : 1. Assign `true` to
 [`[[complete]]`](#dom-imagedecoder-complete-slot)

 2. Resolve
 [`[[completed promise]]`](#dom-imagedecoder-completed-promise-slot).

 [error steps](https://streams.spec.whatwg.org/#read-request-error-steps)

 : 1. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the [Close
 ImageDecoder](#imagedecoder-close-imagedecoder) algorithm with a
 [`NotReadableError`](https://webidl.spec.whatwg.org/#notreadableerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException)

 2. Read a chunk from `reader` given
 `readRequest`.

[Establish Tracks]

: Run these steps:

 1. Assert
 [`[[tracks established]]`](#dom-imagedecoder-tracks-established-slot) is `false`.

 2. If
 [`[[encoded data]]`](#dom-imagedecoder-encoded-data-slot) does not contain enough data to determine the
 number of tracks:

 1. If
 [`complete`](#dom-imagedecoder-complete) is `true`, [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the [Close
 ImageDecoder](#imagedecoder-close-imagedecoder) algorithm with a
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 2. Abort these steps.

 3. If the number of tracks is found to be `0`, [queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to run the [Close
 ImageDecoder](#imagedecoder-close-imagedecoder) algorithm and abort these steps.

 4. Let `newTrackList` be a new
 [list](https://infra.spec.whatwg.org/#list).

 5. For each `image track` found in
 [`[[encoded data]]`](#dom-imagedecoder-encoded-data-slot):

 1. Let `newTrack` be a new
 [`ImageTrack`](#imagetrack), initialized as follows:

 1. Assign
 [this](https://webidl.spec.whatwg.org/#this) to
 [`[[ImageDecoder]]`](#dom-imagetrack-imagedecoder-slot).

 2. Assign
 [`tracks`](#dom-imagedecoder-tracks) to
 [`[[ImageTrackList]]`](#dom-imagetrack-imagetracklist-slot).

 3. If `image track` is found to be animated,
 assign `true` to `newTrack`'s
 [`[[animated]]`](#dom-imagetrack-animated-slot) internal slot. Otherwise, assign
 `false`.

 4. If `image track` is found to describe a frame
 count, assign that count to `newTrack`'s
 [`[[frame count]]`](#dom-imagetrack-frame-count-slot) internal slot. Otherwise, assign `0`.

 [NOTE:] If
 [this](https://webidl.spec.whatwg.org/#this) was constructed with
 [`data`](#dom-imagedecoderinit-data) as a
 [`ReadableStream`](https://streams.spec.whatwg.org/#readablestream), the
 [`frameCount`](#dom-imagetrack-framecount) can change as additional bytes are
 appended to
 [`[[encoded data]]`](#dom-imagedecoder-encoded-data-slot). See the [Update
 Tracks](#imagedecoder-update-tracks) algorithm.

 5. If `image track` is found to describe a
 repetition count, assign that count to
 [`[[repetition count]]`](#dom-imagetrack-repetition-count-slot) internal slot. Otherwise, assign `0`.

 [NOTE:] A value of `Infinity` indicates
 infinite repetitions.

 6. Assign `false` to `newTrack`'s
 [`[[selected]]`](#dom-imagetrack-selected-slot) internal slot.

 2. Append `newTrack` to `newTrackList`.

 6. Let `selectedTrackIndex` be the result of running the
 [Get Default Selected Track
 Index](#imagedecoder-get-default-selected-track-index) algorithm with `newTrackList`.

 7. Let `selectedTrack` be the track at position
 `selectedTrackIndex` within
 `newTrackList`.

 8. Assign `true` to `selectedTrack`'s
 [`[[selected]]`](#dom-imagetrack-selected-slot) internal slot.

 9. Assign `selectedTrackIndex` to
 [`[[internal selected track index]]`](#dom-imagedecoder-internal-selected-track-index-slot).

 10. Assign `true` to
 [`[[tracks established]]`](#dom-imagedecoder-tracks-established-slot).

 11. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to perform the following steps:

 1. Assign `newTrackList` to the
 [`tracks`](#dom-imagedecoder-tracks)
 [`[[track list]]`](#dom-imagetracklist-track-list-slot) internal slot.

 2. Assign `selectedTrackIndex` to
 [`tracks`](#dom-imagedecoder-tracks)
 [`[[selected index]]`](#dom-imagetracklist-selected-index-slot).

 3. Resolve
 [`[[ready promise]]`](#dom-imagetracklist-ready-promise-slot).

[Get Default Selected Track Index] (with `trackList`)

: Run these steps:

 1. If
 [`[[encoded data]]`](#dom-imagedecoder-encoded-data-slot) identifies a [Primary Image
 Track](#primary-image-track):

 1. Let `primaryTrack` be the
 [`ImageTrack`](#imagetrack) from `trackList` that describes
 the [Primary Image
 Track](#primary-image-track).

 2. Let `primaryTrackIndex` be position of
 `primaryTrack` within `trackList`.

 3. If
 [`[[prefer animation]]`](#dom-imagedecoder-prefer-animation-slot) is `null`, return
 `primaryTrackIndex`.

 4. If
 `primaryTrack`.[`animated`](#dom-imagetrack-animated) equals
 [`[[prefer animation]]`](#dom-imagedecoder-prefer-animation-slot), return `primaryTrackIndex`.

 2. If any [`ImageTrack`](#imagetrack)s in `trackList` have
 [`animated`](#dom-imagetrack-animated) equal to
 [`[[prefer animation]]`](#dom-imagedecoder-prefer-animation-slot), return the position of the earliest such track
 in `trackList`.

 3. Return `0`.

[Update Tracks]

: A [track update struct] is a
 [struct](https://infra.spec.whatwg.org/#struct) that consists of a [track
 index]
 ([`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long)) and a [frame
 count]
 ([`unsigned long`](https://webidl.spec.whatwg.org/#idl-unsigned-long)).

 Run these steps:

 1. Assert
 [`[[tracks established]]`](#dom-imagedecoder-tracks-established-slot) is `true`.

 2. Let `trackChanges` be a new
 [list](https://infra.spec.whatwg.org/#list).

 3. Let `trackList` be a copy of
 [`tracks`](#dom-imagedecoder-tracks)\'
 [`[[track list]]`](#dom-imagetracklist-track-list-slot).

 4. For each `track` in `trackList`:

 1. Let `trackIndex` be the position of
 `track` in `trackList`.

 2. Let `latestFrameCount` be the frame count as
 indicated by
 [`[[encoded data]]`](#dom-imagedecoder-encoded-data-slot) for the track corresponding to
 `track`.

 3. Assert that `latestFrameCount` is greater than or
 equal to `track.frameCount`.

 4. If `latestFrameCount` is greater than
 `track.frameCount`:

 1. Let `change` be a [track update
 struct](#track-update-struct) whose [track
 index](#track-update-struct-track-index) is `trackIndex` and [frame
 count](#track-update-struct-frame-count) is `latestFrameCount`.

 2. Append `change` to
 `tracksChanges`.

 5. If `tracksChanges` [is
 empty](https://infra.spec.whatwg.org/#list-is-empty), abort these steps.

 6. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to perform the following steps:

 1. For each `update` in `trackChanges`:

 1. Let `updateTrack` be the
 [`ImageTrack`](#imagetrack) at position `update.trackIndex` within
 [`tracks`](#dom-imagedecoder-tracks)\'
 [`[[track list]]`](#dom-imagetracklist-track-list-slot).

 2. Assign `update.frameCount` to `updateTrack`'s
 [`[[frame count]]`](#dom-imagetrack-frame-count-slot).

[Decode Complete Frame] (with `frameIndex` and `promise`)

: 1. Assert that
 [`[[tracks established]]`](#dom-imagedecoder-tracks-established-slot) is `true`.

 2. Assert that
 [`[[internal selected track index]]`](#dom-imagedecoder-internal-selected-track-index-slot) is not `-1`.

 3. Let `encodedFrame` be the encoded frame identified by
 `frameIndex` and
 [`[[internal selected track index]]`](#dom-imagedecoder-internal-selected-track-index-slot).

 4. Wait for any of the following conditions to be true (whichever
 happens first):

 1. [`[[encoded data]]`](#dom-imagedecoder-encoded-data-slot) contains enough bytes to completely decode
 `encodedFrame`.

 2. [`[[encoded data]]`](#dom-imagedecoder-encoded-data-slot) is found to be malformed.

 3. [`complete`](#dom-imagedecoder-complete) is `true`.

 4. [`[[closed]]`](#dom-imagedecoder-closed-slot) is `true`.

 5. If
 [`[[encoded data]]`](#dom-imagedecoder-encoded-data-slot) is found to be malformed, run the [Fatally
 Reject Bad
 Data](#imagedecoder-fatally-reject-bad-data) algorithm and abort these steps.

 6. If
 [`[[encoded data]]`](#dom-imagedecoder-encoded-data-slot) does not contain enough bytes to completely
 decode `encodedFrame`, run the [Reject Infeasible
 Decode](#imagedecoder-reject-infeasible-decode) algorithm with `promise` and abort
 these steps.

 7. Attempt to use
 [`[[codec implementation]]`](#dom-imagedecoder-codec-implementation-slot) to decode `encodedFrame`.

 8. If decoding produces an error, run the [Fatally Reject Bad
 Data](#imagedecoder-fatally-reject-bad-data) algorithm and abort these steps.

 9. If
 [`[[progressive frame generations]]`](#dom-imagedecoder-progressive-frame-generations-slot) contains an entry keyed by
 `frameIndex`, remove the entry from the map.

 10. Let `output` be the decoded image data emitted by
 [`[[codec implementation]]`](#dom-imagedecoder-codec-implementation-slot) corresponding to `encodedFrame`.

 11. Let `decodeResult` be a new
 [`ImageDecodeResult`](#dictdef-imagedecoderesult) initialized as follows:

 1. Assign \'true\' to
 [`complete`](#dom-imagedecoderesult-complete).

 2. Let `duration` be the presentation duration for
 `output` as described by
 `encodedFrame`. If `encodedFrame` does
 not have a duration, assign `null` to `duration`.

 3. Let `timestamp` be the presentation timestamp for
 `output` as described by
 `encodedFrame`. If `encodedFrame` does
 not have a timestamp:

 1. If `encodedFrame` is a still image assign `0`
 to `timestamp`.

 2. If `encodedFrame` is a constant rate animated
 image and `duration` is not `null`, assign
 `|frameIndex| * |duration|` to `timestamp`.

 3. If a `timestamp` can otherwise be trivially
 generated from metadata without further decoding, assign
 that to `timestamp`.

 4. Otherwise, assign `0` to `timestamp`.

 4. If
 [`[[encoded data]]`](#dom-imagedecoder-encoded-data-slot) contains orientation metadata describe it
 as `rotation` and `flip`, otherwise
 set `rotation` to 0 and `flip` to
 false.

 5. Assign
 [`image`](#dom-imagedecoderesult-image) with the result of running the [Create a
 VideoFrame](#create-a-videoframe) algorithm with `output`,
 `timestamp`, `duration`,
 `rotation`, and `flip`.

 12. Run the [Resolve
 Decode](#imagedecoder-resolve-decode) algorithm with `promise` and
 `decodeResult`.

[Decode Progressive Frame] (with `frameIndex` and `promise`)

: 1. Assert that
 [`[[tracks established]]`](#dom-imagedecoder-tracks-established-slot) is `true`.

 2. Assert that
 [`[[internal selected track index]]`](#dom-imagedecoder-internal-selected-track-index-slot) is not `-1`.

 3. Let `encodedFrame` be the encoded frame identified by
 `frameIndex` and
 [`[[internal selected track index]]`](#dom-imagedecoder-internal-selected-track-index-slot).

 4. Let `lastFrameGeneration` be `null`.

 5. If
 [`[[progressive frame generations]]`](#dom-imagedecoder-progressive-frame-generations-slot) contains a map entry with the key
 `frameIndex`, assign the value of the map entry to
 `lastFrameGeneration`.

 6. Wait for any of the following conditions to be true (whichever
 happens first):

 1. [`[[encoded data]]`](#dom-imagedecoder-encoded-data-slot) contains enough bytes to decode
 `encodedFrame` to produce an output whose
 [Progressive Image Frame
 Generation](#progressive-image-frame-generation) exceeds `lastFrameGeneration`.

 2. [`[[encoded data]]`](#dom-imagedecoder-encoded-data-slot) is found to be malformed.

 3. [`complete`](#dom-imagedecoder-complete) is `true`.

 4. [`[[closed]]`](#dom-imagedecoder-closed-slot) is `true`.

 7. If
 [`[[encoded data]]`](#dom-imagedecoder-encoded-data-slot) is found to be malformed, run the [Fatally
 Reject Bad
 Data](#imagedecoder-fatally-reject-bad-data) algorithm and abort these steps.

 8. Otherwise, if
 [`[[encoded data]]`](#dom-imagedecoder-encoded-data-slot) does not contain enough bytes to decode
 `encodedFrame` to produce an output whose
 [Progressive Image Frame
 Generation](#progressive-image-frame-generation) exceeds `lastFrameGeneration`, run
 the [Reject Infeasible
 Decode](#imagedecoder-reject-infeasible-decode) algorithm with `promise` and abort
 these steps.

 9. Attempt to use
 [`[[codec implementation]]`](#dom-imagedecoder-codec-implementation-slot) to decode `encodedFrame`.

 10. If decoding produces an error, run the [Fatally Reject Bad
 Data](#imagedecoder-fatally-reject-bad-data) algorithm and abort these steps.

 11. Let `output` be the decoded image data emitted by
 [`[[codec implementation]]`](#dom-imagedecoder-codec-implementation-slot) corresponding to `encodedFrame`.

 12. Let `decodeResult` be a new
 [`ImageDecodeResult`](#dictdef-imagedecoderesult).

 13. If `output` is the final full-detail progressive
 output corresponding to `encodedFrame`:

 1. Assign `true` to `decodeResult`'s
 [`complete`](#dom-imagedecoderesult-complete).

 2. If
 [`[[progressive frame generations]]`](#dom-imagedecoder-progressive-frame-generations-slot) contains an entry keyed by
 `frameIndex`, remove the entry from the map.

 14. Otherwise:

 1. Assign `false` to `decodeResult`'s
 [`complete`](#dom-imagedecoderesult-complete).

 2. Let `frameGeneration` be the [Progressive Image
 Frame
 Generation](#progressive-image-frame-generation) for `output`.

 3. Add a new entry to
 [`[[progressive frame generations]]`](#dom-imagedecoder-progressive-frame-generations-slot) with key `frameIndex` and value
 `frameGeneration`.

 15. Let `duration` be the presentation duration for
 `output` as described by `encodedFrame`.
 If `encodedFrame` does not describe a duration,
 assign `null` to `duration`.

 16. Let `timestamp` be the presentation timestamp for
 `output` as described by `encodedFrame`.
 If `encodedFrame` does not have a timestamp:

 1. If `encodedFrame` is a still image assign `0` to
 `timestamp`.

 2. If `encodedFrame` is a constant rate animated
 image and `duration` is not `null`, assign
 `|frameIndex| * |duration|` to `timestamp`.

 3. If a `timestamp` can otherwise be trivially
 generated from metadata without further decoding, assign
 that to `timestamp`.

 4. Otherwise, assign `0` to `timestamp`.

 17. If
 [`[[encoded data]]`](#dom-imagedecoder-encoded-data-slot) contains orientation metadata describe it as
 `rotation` and `flip`, otherwise set
 `rotation` to 0 and `flip` to false.

 18. Assign
 [`image`](#dom-imagedecoderesult-image) with the result of running the [Create a
 VideoFrame](#create-a-videoframe) algorithm with `output`,
 `timestamp`, `duration`,
 `rotation`, and `flip`.

 19. Remove `promise` from
 [`[[pending decode promises]]`](#dom-imagedecoder-pending-decode-promises-slot).

 20. Resolve `promise` with `decodeResult`.

[Resolve Decode] (with `promise` and `result`)

: 1. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to perform these steps:

 1. If
 [`[[closed]]`](#dom-imagedecoder-closed-slot), abort these steps.

 2. Assert that `promise` is an element of
 [`[[pending decode promises]]`](#dom-imagedecoder-pending-decode-promises-slot).

 3. Remove `promise` from
 [`[[pending decode promises]]`](#dom-imagedecoder-pending-decode-promises-slot).

 4. Resolve `promise` with `result`.

[Reject Infeasible Decode] (with `promise`)

: 1. Assert that
 [`complete`](#dom-imagedecoder-complete) is `true` or
 [`[[closed]]`](#dom-imagedecoder-closed-slot) is `true`.

 2. If
 [`complete`](#dom-imagedecoder-complete) is `true`, let `exception` be a
 [`RangeError`](https://webidl.spec.whatwg.org/#exceptiondef-rangeerror). Otherwise, let `exception` be an
 [`InvalidStateError`](https://webidl.spec.whatwg.org/#invalidstateerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

 3. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to perform these steps:

 1. If
 [`[[closed]]`](#dom-imagedecoder-closed-slot), abort these steps.

 2. Assert that `promise` is an element of
 [`[[pending decode promises]]`](#dom-imagedecoder-pending-decode-promises-slot).

 3. Remove `promise` from
 [`[[pending decode promises]]`](#dom-imagedecoder-pending-decode-promises-slot).

 4. Reject `promise` with `exception`.

[Fatally Reject Bad Data]

: 1. [Queue a
 task](https://html.spec.whatwg.org/multipage/webappapis.html#queue-a-task) to perform these steps:

 1. If
 [`[[closed]]`](#dom-imagedecoder-closed-slot), abort these steps.

 2. Run the [Close
 ImageDecoder](#imagedecoder-close-imagedecoder) algorithm with an
 [`EncodingError`](https://webidl.spec.whatwg.org/#encodingerror)
 [`DOMException`](https://webidl.spec.whatwg.org/#idl-DOMException).

[Check Type Support] (with `type`)

: 1. If the User Agent can provide a codec to support decoding
 `type`, return `true`.

 2. Otherwise, return `false`.

[Reset ImageDecoder] (with `exception`)

: 1. Signal
 [`[[codec implementation]]`](#dom-imagedecoder-codec-implementation-slot) to abort any active decoding operation.

 2. For each `decodePromise` in
 [`[[pending decode promises]]`](#dom-imagedecoder-pending-decode-promises-slot):

 1. Reject `decodePromise` with
 `exception`.

 2. Remove `decodePromise` from
 [`[[pending decode promises]]`](#dom-imagedecoder-pending-decode-promises-slot).

[Close ImageDecoder] (with `exception`)

: 1. Run the [Reset
 ImageDecoder](#imagedecoder-reset-imagedecoder) algorithm with `exception`.

 2. Assign `true` to
 [`[[closed]]`](#dom-imagedecoder-closed-slot).

 3. Clear
 [`[[codec implementation]]`](#dom-imagedecoder-codec-implementation-slot) and release associated [system
 resources](#system-resources).

 4. If
 [`[[ImageTrackList]]`](#dom-imagedecoder-imagetracklist-slot) is empty, reject
 [`[[ready promise]]`](#dom-imagetracklist-ready-promise-slot) with `exception`. Otherwise perform
 these steps,

 1. Remove all entries from
 [`[[ImageTrackList]]`](#dom-imagedecoder-imagetracklist-slot).

 2. Assign `-1` to
 [`[[ImageTrackList]]`](#dom-imagedecoder-imagetracklist-slot)'s
 [`[[selected index]]`](#dom-imagetracklist-selected-index-slot).

 5. If
 [`[[complete]]`](#dom-imagedecoder-complete-slot) is false resolve
 [`[[completed promise]]`](#dom-imagedecoder-completed-promise-slot) with `exception`.

### 10.3. ImageDecoderInit Interface

```
typedef (AllowSharedBufferSource or ReadableStream) ImageBufferSource;
dictionary ImageDecoderInit {
 required DOMString type;
 required ImageBufferSource data;
 ColorSpaceConversion colorSpaceConversion = "default";
 [EnforceRange] unsigned long desiredWidth;
 [EnforceRange] unsigned long desiredHeight;
 boolean preferAnimation;
 sequence<ArrayBuffer> transfer = ;
};
```

To determine if an
[`ImageDecoderInit`](#dictdef-imagedecoderinit) is a [valid ImageDecoderInit], run these steps:

1. If `type` is not a [valid image MIME
 type](#valid-image-mime-type), return `false`.

2. If `data` is of type
 [`ReadableStream`](https://streams.spec.whatwg.org/#readablestream) and the ReadableStream is
 [disturbed](https://streams.spec.whatwg.org/#is-readable-stream-disturbed) or
 [locked](https://streams.spec.whatwg.org/#readablestream-locked), return `false`.

3. If `data` is of type
 [`BufferSource`](https://webidl.spec.whatwg.org/#BufferSource):

 1. If `data` is
 \[[detached](https://webidl.spec.whatwg.org/#buffersource-detached)\], return false.

 2. If `data` [is
 empty](https://infra.spec.whatwg.org/#list-is-empty), return `false`.

4. If
 [`desiredWidth`](#dom-imagedecoderinit-desiredwidth)
 [exists](https://infra.spec.whatwg.org/#map-exists) and
 [`desiredHeight`](#dom-imagedecoderinit-desiredheight) does not exist, return `false`.

5. If
 [`desiredHeight`](#dom-imagedecoderinit-desiredheight)
 [exists](https://infra.spec.whatwg.org/#map-exists) and
 [`desiredWidth`](#dom-imagedecoderinit-desiredwidth) does not exist, return `false`.

6. Return `true`.

A [valid image MIME type] is a string that is a [valid MIME type
string](https://mimesniff.spec.whatwg.org/#valid-mime-type) and for which the `type`, per Section 8.3.1 of
[\[RFC9110\]](#biblio-rfc9110 "HTTP Semantics"), is
`image`.

[`type`], of type [DOMString](https://webidl.spec.whatwg.org/#idl-DOMString)

: String containing the MIME type of the image file to be decoded.

[`data`], of type [ImageBufferSource](#typedefdef-imagebuffersource)

: [`BufferSource`](https://webidl.spec.whatwg.org/#BufferSource) or
 [`ReadableStream`](https://streams.spec.whatwg.org/#readablestream) of bytes representing an encoded image file as
 described by
 [`type`](#dom-imagedecoderinit-type).

[`colorSpaceConversion`], of type [ColorSpaceConversion](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#colorspaceconversion), defaulting to `"default"`

: Controls whether decoded outputs\' color space is converted or
 ignored, as defined by
 [`colorSpaceConversion`](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#dom-imagebitmapoptions-colorspaceconversion) in
 [`ImageBitmapOptions`](https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#imagebitmapoptions).

[`desiredWidth`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long)

: Indicates a desired width for decoded outputs. Implementation is
 best effort; decoding to a desired width *MAY* not be supported by
 all formats/ decoders.

[`desiredHeight`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long)

: Indicates a desired height for decoded outputs. Implementation is
 best effort; decoding to a desired height *MAY* not be supported by
 all formats/decoders.

[`preferAnimation`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean)

: For images with multiple tracks, this indicates whether the initial
 track selection *SHOULD* prefer an animated track.

 [NOTE:] See the [Get Default Selected Track
 Index](#imagedecoder-get-default-selected-track-index) algorithm.

### 10.4. ImageDecodeOptions Interface

```
dictionary ImageDecodeOptions {
 [EnforceRange] unsigned long frameIndex = 0;
 boolean completeFramesOnly = true;
};
```

[`frameIndex`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), defaulting to `0`

: The index of the frame to decode.

[`completeFramesOnly`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), defaulting to `true`

: For [Progressive
 Images](#progressive-image), a value of `false` indicates that the decoder
 *MAY* output an
 [`image`](#dom-imagedecoderesult-image) with reduced detail. Each subsequent call to
 [`decode()`](#dom-imagedecoder-decode) for the same
 [`frameIndex`](#dom-imagedecodeoptions-frameindex) will resolve to produce an image with a higher
 [Progressive Image Frame
 Generation](#progressive-image-frame-generation) (more image detail) than the previous call, until
 finally the full-detail image is produced.

 If
 [`completeFramesOnly`](#dom-imagedecodeoptions-completeframesonly) is assigned `true`, or if the image is not a
 [Progressive Image](#progressive-image), or if the User Agent does not support progressive
 decoding for the given image type, calls to
 [`decode()`](#dom-imagedecoder-decode) will only resolve once the full detail image is
 decoded.

 :::
 NOTE: For [Progressive
 Images](#progressive-image), setting
 [`completeFramesOnly`](#dom-imagedecodeoptions-completeframesonly) to `false` can be used to offer users a preview an
 image that is still being buffered from the network (via the
 [`data`](#dom-imagedecoderinit-data)
 [`ReadableStream`](https://streams.spec.whatwg.org/#readablestream)).
 Upon decoding the full detail image, the
 [`ImageDecodeResult`](#dictdef-imagedecoderesult)'s
 [`complete`](#dom-imagedecoderesult-complete) will be set to true.
 :::

### 10.5. ImageDecodeResult Interface

```
dictionary ImageDecodeResult {
 required VideoFrame image;
 required boolean complete;
};
```

[`image`], of type [VideoFrame](#videoframe)

: The decoded image.

[`complete`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean)

: Indicates whether
 [`image`](#dom-imagedecoderesult-image) contains the final full-detail output.

 [NOTE:]
 [`complete`](#dom-imagedecoderesult-complete) is always `true` when
 [`decode()`](#dom-imagedecoder-decode) is invoked with
 [`completeFramesOnly`](#dom-imagedecodeoptions-completeframesonly) set to `true`.

### 10.6. ImageTrackList Interface

```
[Exposed=(Window,DedicatedWorker), SecureContext]
interface ImageTrackList {
 getter ImageTrack (unsigned long index);

 readonly attribute Promise<undefined> ready;
 readonly attribute unsigned long length;
 readonly attribute long selectedIndex;
 readonly attribute ImageTrack? selectedTrack;
};
```

#### 10.6.1. Internal Slots

[`[[ready promise]]`]

: The promise used to signal when the
 [`ImageTrackList`](#imagetracklist) has been populated with
 [`ImageTrack`](#imagetrack)s.

 [NOTE:]
 [`ImageTrack`](#imagetrack)
 [`frameCount`](#dom-imagetrack-framecount) can receive subsequent updates until
 [`complete`](#dom-imagedecoder-complete) is `true`.

[`[[track list]]`]

: The list of [`ImageTrack`](#imagetrack)s describe by this
 [`ImageTrackList`](#imagetracklist).

[`[[selected index]]`]

: The index of the selected track in
 [`[[track list]]`](#dom-imagetracklist-track-list-slot). A value of `-1` indicates that no track is
 selected. The initial value is `-1`.

#### 10.6.2. Attributes

[`ready`], of type Promise\<[undefined](https://webidl.spec.whatwg.org/#idl-undefined)\>, readonly

: The
 [`ready`](#dom-imagetracklist-ready) getter steps are to return the
 [`[[ready promise]]`](#dom-imagetracklist-ready-promise-slot).

[`length`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: The
 [`length`](#dom-imagetracklist-length) getter steps are to return the length of
 [`[[track list]]`](#dom-imagetracklist-track-list-slot).

[`selectedIndex`], of type [long](https://webidl.spec.whatwg.org/#idl-long), readonly

: The
 [`selectedIndex`](#dom-imagetracklist-selectedindex) getter steps are to return
 [`[[selected index]]`](#dom-imagetracklist-selected-index-slot);

[`selectedTrack`], of type [ImageTrack](#imagetrack), readonly, nullable

: The
 [`selectedTrack`](#dom-imagetracklist-selectedtrack) getter steps are:

 1. If
 [`[[selected index]]`](#dom-imagetracklist-selected-index-slot) is `-1`, return `null`.

 2. Otherwise, return the ImageTrack from
 [`[[track list]]`](#dom-imagetracklist-track-list-slot) at the position indicated by
 [`[[selected index]]`](#dom-imagetracklist-selected-index-slot).

### 10.7. ImageTrack Interface

```
[Exposed=(Window,DedicatedWorker), SecureContext]
interface ImageTrack {
 readonly attribute boolean animated;
 readonly attribute unsigned long frameCount;
 readonly attribute unrestricted float repetitionCount;
 attribute boolean selected;
};
```

#### 10.7.1. Internal Slots

[`[[ImageDecoder]]`]

: The [`ImageDecoder`](#imagedecoder) instance that constructed this
 [`ImageTrack`](#imagetrack).

[`[[ImageTrackList]]`]

: The
 [`ImageTrackList`](#imagetracklist) instance that lists this
 [`ImageTrack`](#imagetrack).

[`[[animated]]`]

: Indicates whether this track contains an animated image with
 multiple frames.

[`[[frame count]]`]

: The number of frames in this track.

[`[[repetition count]]`]

: The number of times the animation is intended to repeat.

[`[[selected]]`]

: Indicates whether this track is selected for decoding.

#### 10.7.2. Attributes

[`animated`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean), readonly

: The
 [`animated`](#dom-imagetrack-animated) getter steps are to return the value of
 [`[[animated]]`](#dom-imagetrack-animated-slot).

 [NOTE:] This attribute provides an early indication that
 [`frameCount`](#dom-imagetrack-framecount) will ultimately exceed 0 for images where the
 [`frameCount`](#dom-imagetrack-framecount) starts at `0` and later increments as new chunks of
 the
 [`ReadableStream`](https://streams.spec.whatwg.org/#readablestream)
 [`data`](#dom-imagedecoderinit-data) arrive.

[`frameCount`], of type [unsigned long](https://webidl.spec.whatwg.org/#idl-unsigned-long), readonly

: The
 [`frameCount`](#dom-imagetrack-framecount) getter steps are to return the value of
 [`[[frame count]]`](#dom-imagetrack-frame-count-slot).

[`repetitionCount`], of type [unrestricted float](https://webidl.spec.whatwg.org/#idl-unrestricted-float), readonly

: The
 [`repetitionCount`](#dom-imagetrack-repetitioncount) getter steps are to return the value of
 [`[[repetition count]]`](#dom-imagetrack-repetition-count-slot).

[`selected`], of type [boolean](https://webidl.spec.whatwg.org/#idl-boolean)

: The
 [`selected`](#dom-imagetrack-selected) getter steps are to return the value of
 [`[[selected]]`](#dom-imagetrack-selected-slot).

 The
 [`selected`](#dom-imagetrack-selected) setter steps are:

 1. If
 [`[[ImageDecoder]]`](#dom-imagetrack-imagedecoder-slot)'s
 [`[[closed]]`](#dom-imagedecoder-closed-slot) slot is `true`, abort these steps.

 2. Let `newValue` be [the given
 value](https://webidl.spec.whatwg.org/#the-given-value).

 3. If `newValue` equals
 [`[[selected]]`](#dom-imagetrack-selected-slot), abort these steps.

 4. Assign `newValue` to
 [`[[selected]]`](#dom-imagetrack-selected-slot).

 5. Let `parentTrackList` be
 [`[[ImageTrackList]]`](#dom-imagetrack-imagetracklist-slot)

 6. Let `oldSelectedIndex` be the value of
 `parentTrackList`
 [`[[selected index]]`](#dom-imagetracklist-selected-index-slot).

 7. If `oldSelectedIndex` is not `-1`:

 1. Let `oldSelectedTrack` be the
 [`ImageTrack`](#imagetrack) in `parentTrackList`
 [`[[track list]]`](#dom-imagetracklist-track-list-slot) at the position of
 `oldSelectedIndex`.

 2. Assign `false` to `oldSelectedTrack`
 [`[[selected]]`](#dom-imagetrack-selected-slot)

 8. If `newValue` is `true`, let
 `selectedIndex` be the index of
 [this](https://webidl.spec.whatwg.org/#this)
 [`ImageTrack`](#imagetrack) within `parentTrackList`'s
 [`[[track list]]`](#dom-imagetracklist-track-list-slot). Otherwise, let `selectedIndex` be
 `-1`.

 9. Assign `selectedIndex` to
 `parentTrackList`
 [`[[selected index]]`](#dom-imagetracklist-selected-index-slot).

 10. Run the [Reset
 ImageDecoder](#imagedecoder-reset-imagedecoder) algorithm on
 [`[[ImageDecoder]]`](#dom-imagetrack-imagedecoder-slot).

 11. [Queue a control
 message](#enqueues-a-control-message) to
 [`[[ImageDecoder]]`](#dom-imagetrack-imagedecoder-slot)'s [control message
 queue](#control-message-queue) to update the internal selected track index
 with `selectedIndex`.

 12. [Process the control message
 queue](#process-the-control-message-queue) belonging to
 [`[[ImageDecoder]]`](#dom-imagetrack-imagedecoder-slot).

 [Running a control
 message](#running-a-control-message) to update the internal selected track index means
 running these steps:

 1. Enqueue the following steps to
 [`[[ImageDecoder]]`](#dom-imagetrack-imagedecoder-slot)'s
 [`[[codec work queue]]`](#dom-imagedecoder-codec-work-queue-slot):

 1. Assign `selectedIndex` to
 [`[[internal selected track index]]`](#dom-imagedecoder-internal-selected-track-index-slot).

 2. Remove all entries from
 [`[[progressive frame generations]]`](#dom-imagedecoder-progressive-frame-generations-slot).

## 11. Resource Reclamation

When resources are constrained, a User Agent *MAY* proactively reclaim
codecs. This is particularly true in the case where hardware codecs are
limited, and shared accross web pages or platform apps.

To [reclaim a codec], a User Agent *MUST* run the appropriate close algorithm
(amongst [Close
AudioDecoder](#close-audiodecoder), [Close
AudioEncoder](#close-audioencoder), [Close
VideoDecoder](#close-videodecoder) and [Close
VideoEncoder](#close-videoencoder)) with a
[`QuotaExceededError`](https://webidl.spec.whatwg.org/#quotaexceedederror).

The rules governing when a codec may be reclaimed depend on whether the
codec is an [active](#active-codec) or [inactive](#inactive-codec) codec and/or a
[background](#background-codec) codec.

An [active codec] is a codec that has made progress
on the [\[\[codec work
queue\]\]](#codec-work-queue) in the past `10 seconds`.

[NOTE:] A reliable sign of the working queue's progress is a
call to `output()` callback.

An [inactive codec] is any codec that does not
meet the definition of an [active
codec](#active-codec).

A [background codec] is a codec whose
[`ownerDocument`](https://dom.spec.whatwg.org/#dom-node-ownerdocument) (or [owner
set](https://html.spec.whatwg.org/multipage/workers.html#concept-WorkerGlobalScope-owner-set)'s
[`Document`](https://dom.spec.whatwg.org/#document), for codecs in workers) has a
[`hidden`](https://html.spec.whatwg.org/multipage/interaction.html#dom-document-hidden) attribute equal to `true`.

A User Agent *MUST* only [reclaim a
codec](#reclaim-a-codec) that
is either an [inactive codec](#inactive-codec), a [background
codec](#background-codec),
or both. A User Agent *MUST NOT* reclaim a codec that is both
[active](#active-codec) and in
the foreground, i.e. not a [background
codec](#background-codec).

Additionally, User Agents *MUST NOT* reclaim an
[active](#active-codec)
[background](#background-codec) codec if it is:

- An encoder, e.g. an
 [`AudioEncoder`](#audioencoder) or
 [`VideoEncoder`](#videoencoder).

 [NOTE:] This prevents long running encode tasks from being
 interrupted.

- An [`AudioDecoder`](#audiodecoder) or
 [`VideoDecoder`](#videodecoder), when there is, respectively, an
 [active](#active-codec)
 [`AudioEncoder`](#audioencoder) or
 [`VideoEncoder`](#videoencoder) in the same [global
 object](https://html.spec.whatwg.org/multipage/webappapis.html#global-object).

 [NOTE:] This prevents prevents breaking long running
 transcoding tasks.

- An [`AudioDecoder`](#audiodecoder), when its tab is audibly playing audio.

## 12. Security Considerations

::::: non-normative
This section is non-normative.

The primary security impact is that features of this API make it easier
for an attacker to exploit vulnerabilities in the underlying platform
codecs. Additionally, new abilities to configure and control the codecs
can allow for new exploits that rely on a specific configuration and/or
sequence of control operations.

Platform codecs are historically an internal detail of APIs like
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement),
[\[WEBAUDIO\]](#biblio-webaudio "Web Audio API"),
and
[\[WebRTC\]](#biblio-webrtc "WebRTC: Real-Time Communication in Browsers").
In this way, it has always been possible to attack the underlying codecs
by using malformed media files/streams and invoking the various API
control methods.

For example, you can send any stream to a decoder by first wrapping that
stream in a media container (e.g. mp4) and setting that as the
[`src`](https://html.spec.whatwg.org/multipage/media.html#dom-media-src) of an
[`HTMLMediaElement`](https://html.spec.whatwg.org/multipage/media.html#htmlmediaelement). You can then cause the underlying video decoder to be
[`reset()`](#dom-videodecoder-reset) by setting a new value for `<video>.currentTime`.

WebCodecs makes such attacks easier by exposing low level control when
inputs are provided and direct access to invoke the codec control
methods. This also affords attackers the ability to invoke sequences of
control methods that were not previously possible via the higher level
APIs.

The Working Group expects User Agents to mitigate this risk by
extensively fuzzing their implementation with random inputs and control
method invocations. Additionally, User Agents are encouraged to isolate
their underlying codecs in processes with restricted privileges
(sandbox) as a barrier against successful exploits being able to read
user data.

An additional concern is exposing the underlying codecs to input
mutation race conditions, such as allowing a site to mutate a codec
input or output while the underlying codec is still operating on that
data. This concern is mitigated by ensuring that input and output
interfaces are immutable.

## 13. Privacy Considerations

:::: non-normative
This section is non-normative.

The primary privacy impact is an increased ability to fingerprint users
by querying for different codec capabilities to establish a codec
feature profile. Much of this profile is already exposed by existing
APIs. Such profiles are very unlikely to be uniquely identifying, but
can be used with other metrics to create a fingerprint.

An attacker can accumulate a codec feature profile by calling
`IsConfigSupported()` methods with a number of different configuration
dictionaries. Similarly, an attacker can attempt to `configure()` a
codec with different configuration dictionaries and observe which
configurations are accepted.

Attackers can also use existing APIs to establish much of the codec
feature profile. For example, the
[\[media-capabilities\]](#biblio-media-capabilities "Media Capabilities")
[`decodingInfo()`](https://w3c.github.io/media-capabilities/#dom-mediacapabilities-decodinginfo) API describes what types of decoders are supported and
its
[`powerEfficient`](https://w3c.github.io/media-capabilities/#dom-mediacapabilitiesinfo-powerefficient) attribute can signal when a decoder uses hardware
acceleration. Similarly, the
[\[WebRTC\]](#biblio-webrtc "WebRTC: Real-Time Communication in Browsers")
[`getCapabilities()`](https://w3c.github.io/webrtc-pc/#dom-rtcrtpsender-getcapabilities) API can be used to determine what types of encoders are
supported and the
[`getStats()`](https://w3c.github.io/webrtc-pc/#widl-RTCPeerConnection-getStats-Promise-RTCStatsReport--MediaStreamTrack-selector) API can be used to determine when an encoder uses
hardware acceleration. WebCodecs will expose some additional information
in the form of low level codec features.

A codec feature profile alone is unlikely to be uniquely identifying.
Underlying codecs are often implemented entirely in software (be it part
of the User Agent binary or part of the operating system), such that all
users who run that software will have a common set of capabilities.
Additionally, underlying codecs are often implemented with hardware
acceleration, but such hardware is mass produced and devices of a
particular class and manufacture date (e.g. flagship phones manufactured
in 2020) will often have common capabilities. There will be outliers
(some users can be running outdated versions of software codecs or use a
rare mix of custom assembled hardware), but most of the time a given
codec feature profile is shared by a large group of users.

Segmenting groups of users by codec feature profile still amounts to a
bit of entropy that can be combined with other metrics to uniquely
identify a user. User Agents *MAY* partially mitigate this by returning
an error whenever a site attempts to exhaustively probe for codec
capabilities. Additionally, User Agents *MAY* implement a \"privacy
budget\", which depletes as authors use WebCodecs and other identifying
APIs. Upon exhaustion of the privacy budget, codec capabilities could be
reduced to a common baseline or prompt for user approval.

## 14. Best Practices for Authors Using WebCodecs

::: non-normative
This section is non-normative.

While WebCodecs internally operates on background threads, authors
working with realtime media or in contended main thread environments are
encouraged to ensure their media pipelines operate in worker contexts
entirely independent of the main thread where possible. For example,
realtime media processing of
[`VideoFrame`](#videoframe)s are generally to be done in a worker context.

The main thread has significant potential for high contention and jank
that can go unnoticed in development, yet degrade inconsistently across
devices and User Agents in the field \-- potentially dramatically
impacting the end user experience. Ensuring the media pipeline is
decoupled from the main thread helps provide a smooth experience for end
users.

Authors using the main thread for their media pipeline ought to be sure
of their target frame rates, main thread workload, how their application
will be embedded, and the class of devices their users will be using.

## 15. Acknowledgements

The editors would like to thank Alex Russell, Chris Needham, Dale
Curtis, Dan Sanders, Eugene Zemtsov, Francois Daoust, Guido Urdaneta,
Harald Alvestrand, Jan-Ivar Bruaroey, Jer Noble, Mark Foltz, Peter
Thatcher, Steve Anton, Matt Wolenetz, Rijubrata Bhaumik, Thomas
Guilbert, Tuukka Toivonen, and Youenn Fablet for their contributions to
this specification. Thank you also to the many others who contributed to
the specification, including through their participation on the mailing
list and in the issues.

The Working Group dedicates this specification to our colleague Bernard
Aboba.
