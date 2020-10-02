-- redis-cli --eval populate.lua

redis.call("DEL", "events_queue")

for i = 1, 1000000, 1 do
  redis.call("LPUSH", "events_queue", "{\"index\":"..i..",\"wday\":"..math.fmod(i,7)..",\"payload\":\"Lorem ipsum dolor sit amet\",\"price\":100000.0,\"user_id\":"..10000000 + i.."}")
end

return "Ok!"
