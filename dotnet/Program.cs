using System;
using System.IO;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Globalization;

using CsvHelper;
using CsvHelper.Configuration;
using StackExchange.Redis;

var host = Environment.GetEnvironmentVariable("REDIS_HOST") ?? "redis";
var redis = ConnectionMultiplexer.Connect(host).GetDatabase();

var workers = Environment.GetEnvironmentVariable("WORKERS");
var threads = workers == null ? Environment.ProcessorCount : Int32.Parse(workers);

var filepath = String.Format("/scripts/output/dotnet-{0}.csv", UnixNow());

var config = new CsvConfiguration(CultureInfo.InvariantCulture) {
  HasHeaderRecord = false,
};

var options = new JsonSerializerOptions {
  WriteIndented = false
};

long UnixNow() => DateTimeOffset.UtcNow.ToUnixTimeSeconds();
Message DecodeItem(RedisValue item) => JsonSerializer.Deserialize<Message>((string) item);

var channel = new ConcurrentQueue<(Kind, Message)>();

var writer = new Thread(WriterWorker);
writer.Start(channel);

var readers = new List<Thread>(threads);
for (int i = 0; i < threads; i++) {
  var thread = new Thread(ReaderWorker);
  thread.Start(channel);
  readers.Add(thread);
}

foreach (var thread in readers) {
  thread.Join();
}

writer.Join();

Console.WriteLine("Done.");

void ReaderWorker(Object ctx) {
  var queue = (ConcurrentQueue<(Kind, Message)>) ctx;

  var done = false;

  while (!done) {
    var item = redis.ListRightPop("events_queue");

    if (item.HasValue) {
      queue.Enqueue((Kind.Message, DecodeItem(item)));
    } else {
      queue.Enqueue((Kind.Done, null));
      done = true;
    }
  }
};

void WriterWorker(Object ctx) {
  var queue = (ConcurrentQueue<(Kind, Message)>) ctx;

  using (var writer = new StreamWriter(filepath))
  using (var output = new CsvWriter(writer, config)) {
    var done = 0;

    while (done < threads) {
      (Kind, Message) payload;

      if (queue.TryDequeue(out payload)) {
        (Kind kind, Message message) = payload;

        if (kind == Kind.Message) {
          var signature = ProcessItem(message);
          output.WriteRecord(new { Timestamp = UnixNow(), Index = message.index, Signature = signature });
          output.NextRecord();
        } else if (kind == Kind.Done) {
          done += 1;
        }
      }
    }
  }
}

string ProcessItem(Message message) {
  var discount = message.wday switch {
    0 => 0.0,
    1 => 5.0,
    2 => 10.0,
    3 => 15.0,
    4 => 20.0,
    5 => 25.0,
    6 => 30.0,
  };

  var price = message.price * ( 1.0 - ( discount / 100.0 ));

  message.total = Math.Round(price, 2, MidpointRounding.AwayFromZero);

  var updated = JsonSerializer.Serialize(message, options);

  var hash = MD5.Create().ComputeHash(Encoding.UTF8.GetBytes(updated));
  return Convert.ToHexString(hash).ToLower();
};

enum Kind {
  Message,
  Done,
}

class Message {
    public int index { get; set; }
    public int wday { get; set; }
    public string payload { get; set; }
    public double price { get; set; }
    public int user_id { get; set; }

    public double total { get; set; } = 0;
}
