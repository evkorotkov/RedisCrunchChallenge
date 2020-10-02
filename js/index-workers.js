const { Worker, isMainThread } = require('worker_threads');

const os = require('os');
const path = require('path');
const fs = require('fs');

const csvWriter = require('csv-write-stream');

const writer = csvWriter({ sendHeaders: false, headers: ['ts', 'idx', 'signature'] });
const filepath = path.resolve(__filename, '..', `../output/js-${Date.now()}.csv`);
writer.pipe(fs.createWriteStream(filepath, { flags: 'w+' }));

const workers = os.cpus().map(() => {
  return new Promise((resolve, reject) => {
    const worker = new Worker(path.resolve(__dirname, './worker.js'));

    worker.on('message', (row) => writer.write(row));

    worker.on('exit', (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`Worked died with code: ${code}`));
      }
    });

    worker.on('error', reject);

    worker.postMessage('start');
  });
});

Promise.all(workers).then(() => process.exit());
