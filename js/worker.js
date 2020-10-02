const { parentPort } = require('worker_threads');
const crypto = require('crypto');

const Redis = require('ioredis');
const redis = new Redis();

const hash = (payload) => crypto.createHash('md5').update(payload).digest('hex');

const discounts = [
  0,
  5,
  10,
  15,
  20,
  25,
  30
];

const round = (val) => Math.round(val * 100) / 100;

const processEvent = evt => {
  const discount = (discounts[evt.wday] || 0) / 100;
  evt.total = round(evt.price * (1 - discount));

  return hash(JSON.stringify(evt));
};

const processEvents = async () => {
  let running = true;

  while (running) {
    const response = await redis.brpop('events_queue', 5);
    if (response) {

      const [_, evt] = response;
      if (evt) {
        const parsed = JSON.parse(evt);
        const signature = processEvent(parsed);
        parentPort.postMessage([Date.now(), parsed.index, signature]);
      } else {
        running = false;
      }

    } else {
      running = false;
    }
  }
};

parentPort.once('message', () => processEvents().then(() => process.exit(0)));
