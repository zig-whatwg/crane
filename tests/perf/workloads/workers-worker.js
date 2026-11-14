// The worker of workers.html: one message in, one out. 'work' allocates 4,000 arrays of 1,024
// numbers and keeps every second one until it answers; anything else answers at once.
onmessage = (e) => {
  if (e.data !== 'work') { postMessage(0); return; }
  const kept = [];
  let sink = 0;
  for (let i = 0; i < 4000; i++) {
    const a = new Array(1024).fill(i);
    if (i % 2 === 0) kept.push(a);
    sink += a[i % 1024];
  }
  postMessage(sink + kept.length);
};
