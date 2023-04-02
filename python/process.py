from concurrent import futures
from hashlib import md5
from multiprocessing import Queue
from os import environ
from time import time

import redisio
from msgspec import Struct
from msgspec.json import Decoder, Encoder

DISCOUNTS_MAP = [0, 5, 10, 15, 20, 25, 30]


class Event(Struct):
    index: int
    wday: int
    payload: str
    price: float
    user_id: int
    total: float | None = None


def worker(num, host, port):
    print(f"Starting worker {num+1}...")
    _dec = Decoder(Event).decode
    _enc = Encoder().encode
    _discounts = tuple(d / 100.0 for d in DISCOUNTS_MAP)
    redis = redisio.Redis(host=host, port=port)
    while response := redis("BRPOP", "events_queue", 5).next():
        event = _dec(response[1])
        event.total = round(event.price - event.price * _discounts[event.wday], 2)
        md5_hash = md5(_enc(event)).hexdigest()
        queue.put(f"{event.index},{md5_hash}\n")
    queue.put(None)
    print(f"Worker {num} finished")


def event_writer(workers):
    print("Started writer...", flush=True)
    finished = 0
    result_file = f"/scripts/output/python-{int(time())}.csv"
    with open(result_file, "w", encoding="utf8") as csv:
        while finished < workers:
            item = queue.get()
            if item is not None:
                csv.write(f"{int(time())},{item}")
            else:
                finished += 1


if __name__ == "__main__":
    num_workers = int(environ.get("WORKERS", 4))
    redis_host = environ.get("REDIS_HOST", "redis")
    redis_port = int(environ.get("REDIS_PORT", "6379"))
    queue = Queue(1024)
    with futures.ProcessPoolExecutor(max_workers=num_workers + 1) as executor:
        print(f"Starting {num_workers} workers and writer")
        ff = [executor.submit(event_writer, num_workers)]
        ff += [executor.submit(worker, num, redis_host, redis_port) for num in range(num_workers)]
        futures.wait(ff)
