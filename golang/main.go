package main

import (
  "context"
  "crypto/md5"
  "encoding/csv"
  "encoding/hex"
  "encoding/json"
  "fmt"
  "github.com/go-redis/redis/v8"
  "math"
  "os"
  "strconv"
  "sync"
  "time"
  "runtime"
)

type Event struct {
  Index   int     `json:"index"`
  Wday    int     `json:"wday"`
  Payload string  `json:"payload"`
  Price   float32 `json:"price"`
  UserId  int     `json:"user_id"`
  Total   float32 `json:"total"`
}

var ctx = context.Background()

const key = "events_queue"

var discountMap = map[int]float32{
  0: 0.0,
  1: 5.0,
  2: 10.0,
  3: 15.0,
  4: 20.0,
  5: 25.0,
  6: 30.0,
}

type LockedWriter struct {
  mutex  sync.Mutex
  Writer csv.Writer
}

func getEnv(key string, defaultValue string) string {
  if value, ok := os.LookupEnv(key); ok {
    return value
  }

  return defaultValue
}

func (lw *LockedWriter) Write(s []string) {
  lw.mutex.Lock()
  defer lw.mutex.Unlock()
  lw.Writer.Write(s)
}

func (lw *LockedWriter) Flush() {
  lw.mutex.Lock()
  defer lw.mutex.Unlock()
  lw.Writer.Flush()
}

func GetMD5Hash(text []byte) string {
  hasher := md5.New()
  hasher.Write(text)

  return hex.EncodeToString(hasher.Sum(nil))
}

func worker(wg *sync.WaitGroup, rdb *redis.Client, writer *LockedWriter, id int) {
  for {
    result, err := rdb.BLPop(ctx, 5*time.Second, key).Result()

    if err != nil {
      break
    }

    handleEvent(result[1], writer)
  }

  fmt.Println("Finishing worker", id)
  wg.Done()
}

func handleEvent(raw_event string, writer *LockedWriter) {
  var event Event

  json.Unmarshal([]byte(raw_event), &event)
  discount := discountMap[event.Wday]
  total := float64(event.Price * (1 - (discount / 100.0)))
  event.Total = float32(math.Round(total*100) / 100)

  jsonString, _ := json.Marshal(event)
  signature := GetMD5Hash(jsonString)

  writer.Write([]string{strconv.FormatInt(time.Now().Unix(), 10), strconv.Itoa(event.Index), signature})
}

func main() {
  var (
    redis_host = getEnv("REDIS_HOST", "localhost")
    workers    = getEnv("WORKERS", fmt.Sprintf("%d", runtime.NumCPU()))
  )

  rdb := redis.NewClient(&redis.Options{
    Addr:     redis_host + ":6379",
    Password: "",
    DB:       0,
  })

  file_name := fmt.Sprintf("/scripts/output/golang-%d.csv", time.Now().Unix())
  file, _ := os.OpenFile(file_name, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
  defer file.Close()

  writer := LockedWriter{Writer: *csv.NewWriter(file), mutex: sync.Mutex{}}
  defer writer.Flush()

  var wg sync.WaitGroup
  w_count, _ := strconv.Atoi(workers)

  for w := 1; w <= w_count; w++ {
    fmt.Println("Starting worker:", w)
    wg.Add(1)

    go worker(&wg, rdb, &writer, w)
  }

  wg.Wait()
}
