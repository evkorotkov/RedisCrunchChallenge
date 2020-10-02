const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const csvWriter = require('csv-write-stream')

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

const writer = csvWriter({ sendHeaders: false, headers: ['ts', 'idx', 'signature'] });
const filepath = path.resolve(__filename, '..', `../output/js-${Date.now()}.csv`);
writer.pipe(fs.createWriteStream(filepath, { flags: 'w+' }));

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
        writer.write([Date.now(), parsed.index, signature]);
      } else {
        running = false;
      }

    } else {
      running = false;
    }
  }

  writer.end();
};

processEvents()
  .then(() => process.exit())
  .catch(e => {
    console.error(e);
    process.exit();
  });
