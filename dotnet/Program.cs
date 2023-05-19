using System;
using System.IO;
using System.Text;
using System.Text.Json;
using System.Security.Cryptography;
using System.Globalization;

using CsvHelper;
using CsvHelper.Configuration;
using StackExchange.Redis;

var host = Environment.GetEnvironmentVariable("REDIS_HOST") ?? "redis";
var redis = ConnectionMultiplexer.Connect(host).GetDatabase();

var filepath = String.Format("/scripts/output/dotnet-{0}.csv", UnixNow());

var config = new CsvConfiguration(CultureInfo.InvariantCulture) {
  HasHeaderRecord = false,
};

var options = new JsonSerializerOptions {
  WriteIndented = false
};

long UnixNow() => DateTimeOffset.UtcNow.ToUnixTimeSeconds();
Message DecodeItem(RedisValue item) => JsonSerializer.Deserialize<Message>((string) item);

using (var writer = new StreamWriter(filepath))
using (var output = new CsvWriter(writer, config)) {
  var done = false;

  while (!done) {
    var item = redis.ListRightPop("events_queue");

    if (item.HasValue) {
      var decoded = DecodeItem(item);
      var signature = ProcessItem(decoded);

      output.WriteRecord(new { Timestamp = UnixNow(), Index = decoded.index, Signature = signature });
      output.NextRecord();
    } else {
      done = true;
    }
  }
}

Console.WriteLine("Done.");

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

public class Message
{
    public int index { get; set; }
    public int wday { get; set; }
    public string payload { get; set; }
    public double price { get; set; }
    public int user_id { get; set; }

    public double total { get; set; } = 0;
}
