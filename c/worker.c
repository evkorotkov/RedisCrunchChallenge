# include <stdio.h>
# include <stdlib.h>
# include <string.h>
# include <time.h>
# include <math.h>
# include <hiredis/hiredis.h>
# include <cjson/cJSON.h>
# include <openssl/md5.h>

#define BUF_SIZE 64 * 1024

struct BufferedWriter {
  FILE *io;
  char buf[BUF_SIZE];
  int bytes_written;
};

struct BufferedWriter* init_buffered_writer(const char *filename) {
  struct BufferedWriter *bw = malloc(sizeof *bw);

  bw->io = fopen(filename, "w");
  bw->bytes_written = 0;

  return bw;
}

void flush_buffer(struct BufferedWriter *bw) {
  if (bw->bytes_written > 0) {
    int bytes_written = fwrite(bw->buf, 1, bw->bytes_written, bw->io);

    bw->bytes_written = 0;
  }
}

void write_buffered(struct BufferedWriter *bw, const char *format, ...) {
  va_list args;
  va_start(args, format);

  int n = vsnprintf(bw->buf + bw->bytes_written, BUF_SIZE - bw->bytes_written, format, args);

  if (n >= BUF_SIZE - bw->bytes_written) {
    flush_buffer(bw);
    if (n >= BUF_SIZE) {
      vfprintf(bw->io, format, args);
    } else {
      va_start(args, format);
      vsnprintf(bw->buf, BUF_SIZE, format, args);
      bw->bytes_written = strlen(bw->buf);
    }
  } else {
    bw->bytes_written += n;
    if (bw->bytes_written >= BUF_SIZE) {
      flush_buffer(bw);
    }
  }

  va_end(args);
}

void close_buffered_writer(struct BufferedWriter *bw) {
  flush_buffer(bw);
  fclose(bw->io);
  free(bw);
}

static float DISCOUNTS[] = {0.0, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3};

void calculate_signature(char *string, char *checksum) {
  MD5_CTX ctx;
  unsigned char digest[MD5_DIGEST_LENGTH];
  int i;

  MD5_Init(&ctx);
  MD5_Update(&ctx, string, strlen(string));
  MD5_Final(digest, &ctx);

  for (i = 0; i < MD5_DIGEST_LENGTH; i++) {
    sprintf(&checksum[i*2], "%02x", (unsigned int)digest[i]);
  }
}

void update_total(cJSON* json, float price, int wday) {
  float total = roundf(price * (1 - DISCOUNTS[wday]) * 100) / 100;
  char total_buffer[20];
  snprintf(total_buffer, 20, "%.2f", total);

  int len = strlen(total_buffer);
  if (len > 1 && total_buffer[len - 1] == '0' && total_buffer[len - 3] == '.') {
    total_buffer[len - 1] = '\0';
  }

  cJSON_AddRawToObject(json, "total", total_buffer);
}

void process_event(char* event, struct BufferedWriter* bw) {
  cJSON *json = cJSON_Parse(event);
  const int wday = cJSON_GetObjectItemCaseSensitive(json, "wday")->valueint;
  const int index = cJSON_GetObjectItemCaseSensitive(json, "index")->valueint;
  const float price = cJSON_GetObjectItemCaseSensitive(json, "price")->valuedouble;
  update_total(json, price, wday);

  char* dumped = cJSON_PrintBuffered(json, 120, 0);
  char signature[MD5_DIGEST_LENGTH * 2 + 1];
  calculate_signature(dumped, signature);
  write_buffered(bw, "%ld,%i,%s\n", time(NULL), index, signature);

  free(dumped);
  cJSON_Delete(json);
}

int main() {
  char filename[64];
  sprintf(filename, "/scripts/output/c-%ld.csv", time(NULL));
  struct BufferedWriter *bw = init_buffered_writer(filename);

  char* redis_host = getenv("REDIS_HOST");
  if ((redis_host != NULL) && (redis_host[0] == '\0')) {
    redis_host = "localhost";
  }

  redisContext *redis = redisConnect(redis_host, 6379);

  if (redis != NULL && redis->err) {
    printf("Error: %s\n", redis->errstr);
  } else {
    printf("Connected to Redis\n");
  }

  redisReply *reply;

  while (1) {
    reply = redisCommand(redis, "BRPOP events_queue 5");

    if (reply->type == REDIS_REPLY_NIL) {
      break;
    }

    process_event(reply->element[1]->str,  bw);

    freeReplyObject(reply);
  }

  redisFree(redis);
  close_buffered_writer(bw);

  return 0;
}
