use std::time::SystemTime;
use std::env;
use std::thread;

use redis::{AsyncCommands, RedisError};
use serde::{Deserialize, Serialize};
use csv::Writer;
use math::round;

use crossbeam_channel::bounded;
use tokio::task::JoinSet;

fn now() -> String {
  let elapsed = SystemTime::now().duration_since(SystemTime::UNIX_EPOCH).unwrap();
  return format!("{}", elapsed.as_millis());
}

fn redis_path() -> String {
  match env::var("REDIS_HOST") {
    Ok(host) => format!("redis://{}/", host),
    Err(_) => "redis://127.0.0.1/".to_string(),
  }
}

fn workers_count() -> usize {
  match env::var("WORKERS") {
    Ok(val) => val.parse::<usize>().unwrap(),
    Err(_) => thread::available_parallelism().unwrap().get(),
  }
}

#[derive(Debug, Serialize, Deserialize)]
struct Message {
  index: i32,
  wday: usize,
  payload: String,
  price: f32,
  user_id: i32,

  #[serde(default)]
  total: f32,
}

impl Message {
  const DISCOUNTS: [f32; 7] = [0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 30.0];

  pub fn from_redis(result: Result<Vec<String>, RedisError>) -> Option<Message> {
    let payload = result.ok()?;
    let encoded = payload.get(1)?;
    return serde_json::from_str(encoded).ok();
  }

  pub fn update_discount(&mut self) {
    let discount = Self::DISCOUNTS[self.wday] / 100.0;
    let price = self.price * (1.0 - discount);
    self.total = round::half_up(price.into(), 2) as f32;
  }

  pub fn signature(&self) -> String {
    let encoded = serde_json::to_string(&self).unwrap();
    let digest = md5::compute(encoded);
    return format!("{:x}", digest);
  }

  pub fn csv_row(&mut self) -> Vec<String> {
    self.update_discount();
    let signature = self.signature();
    return vec![now(), format!("{}", self.index), signature];
  }
}

#[tokio::main]
async fn main() {
  let (snd, rcv) = bounded(1024);

  let mut tasks = JoinSet::new();
  let workers_count = workers_count();

  let writer = tokio::spawn(async move {
    println!("Writer is up...");
    let mut csv_file = Writer::from_path(format!("/scripts/output/rust-{}.csv", now())).unwrap();

    for row in rcv.iter().flatten() {
      csv_file.write_record(row).unwrap();
    }
  });

  for idx in 0..(workers_count * 16) {
    let snd2 = snd.clone();

    tasks.spawn(async move {
      println!("Worker {} is up...", idx);
      let client = redis::Client::open(redis_path()).unwrap();
      let mut con = client.get_multiplexed_tokio_connection().await.unwrap();

      loop {
        let encoded = con.brpop("events_queue", 5.0).await;

        match Message::from_redis(encoded) {
          Some(mut message) => {
            let row = message.csv_row();

            if (snd2.send(Some(row))).is_err() {
              break;
            }
          },

          None => break,
        }
      }
    });
  }

  let monitor = tokio::spawn(async move {
    let snd3 = snd.clone();

    while let Some(res) = tasks.join_next().await {
      if res.is_err() {
        println!("Task failed.");
      }
    }

    snd3.send(None).unwrap();
  });

  monitor.await.unwrap();
  writer.await.unwrap();

  println!("Done.");
}
