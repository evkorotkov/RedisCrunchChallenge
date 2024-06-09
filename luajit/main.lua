local hiredis = require("hiredis")
local json = require("cjson")
local openssl = require("openssl")
local inspect = require("inspect")

json.encode_keep_buffer()

local function p(table)
  print(inspect(table))
end

local function unix_now()
  return os.time(os.date("!*t"))
end

local conn = hiredis.connect("redis", 6379)
local md5 = openssl.digest.get('md5')

local function receive(prod)
  return coroutine.resume(prod)
end

local function send(x)
  coroutine.yield(x)
end

local function producer()
  return coroutine.create(function()
    while true do
      local reply = conn:command("BRPOP", "events_queue", "5")
      local unwrapped = hiredis.unwrap_reply(reply)

      if unwrapped == hiredis.NIL then break end

      send(unwrapped[2])
    end
  end)
end

local function processor(prod)
  return coroutine.create(function()
    while true do
      local status, update = receive(prod)
      if not status then break end

      local data = json.decode(update)
      local total = math.floor(data["price"] * (1 - DISCOUNTS[data["wday"] + 1]) * 100) / 100;

      -- it's impossible to keep keys order when encode a table
      local encoded = string.format(
        "{\"index\": %s,\"wday\":%s,\"payload\":\"%s\",\"price\":%s,\"user_id\":%s,\"total\":%s}",
        json.encode(data["index"]),
        json.encode(data["wday"]),
        json.encode(data["payload"]),
        json.encode(data["price"]),
        json.encode(data["user_id"]),
        json.encode(total)
      )
      local mdc = md5:new()
      mdc:update(encoded)
      local signature = mdc:final()
      local result = string.format("%i,%i,%s\n", unix_now(), data["index"], signature)

      send(result)
    end
  end)
end

DISCOUNTS = { 0.0, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3 }

local function writer(prod, file)
  while true do
    local status, data = receive(prod)
    if not status then break end

    file:write(data)
  end
end

local file = io.open(string.format("/scripts/output/luajit-%i.csv", unix_now()), "a")

writer(processor(producer()), file)

file:close()
