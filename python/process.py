import io
import os
import time
import hashlib
from concurrent import futures

import msgspec
import redisio

DISCOUNTS_MAP = [0, 5, 10, 15, 20, 25, 30]


class Event(msgspec.Struct):
    index: int
    wday: int
    payload: str
    price: float
    user_id: int
    total: float | None = None


def worker():
    _dec = msgspec.json.Decoder(Event).decode
    _enc = msgspec.json.Encoder().encode
    _discounts = tuple(d / 100.0 for d in DISCOUNTS_MAP)
    _buf = io.BytesIO()
    redis = redisio.Redis(host="redis", port=6379)
    while response := redis("BRPOP", "events_queue", 5).next():
        event = _dec(response[1])
        event.total = round(event.price - event.price * _discounts[event.wday], 2)
        md5 = hashlib.md5(_enc(event)).hexdigest()
        _buf.write(f"{int(time.time())},{event.index},{md5}\n".encode())
    return _buf


if __name__ == "__main__":
    result_file = f"/scripts/output/python-{int(time.time())}.csv"
    num_workers = int(os.environ.get("WORKERS", 4))
    with open(result_file, "wb") as csv:
        with futures.ProcessPoolExecutor(max_workers=num_workers) as executor:
            print(f"Starting {num_workers} workers")
            ff = [executor.submit(worker) for _ in range(num_workers)]
            for future in futures.as_completed(ff):
                print(f"Worker {ff.index(future)} finished")
                b = future.result()
                b.seek(0)
                csv.write(b.read())
