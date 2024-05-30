use std::time::SystemTime;
use std::env;
use std::thread;

use fred::prelude::*;
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
struct Payload {
  index: i32,
  wday: usize,
  payload: String,
  price: f32,
  user_id: i32,

  #[serde(default)]
  total: f32,
}

impl Payload {
  const DISCOUNTS: [f32; 7] = [0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 30.0];

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

#[derive(Debug)]
enum Message {
  Decoded(Payload),
  Row(Vec<String>),
  Timeout,
  Error,
  Done,
}

impl Message {
  pub fn from_redis(encoded: Result<Vec<String>, RedisError>) -> Self {
    match encoded {
      Ok(mut value) => {
        let first = value.pop().unwrap();
        let payload = serde_json::from_str(&first).unwrap();

        Message::Decoded(payload)
      },
      Err(err) => match err.kind() {
        RedisErrorKind::Timeout => Message::Timeout,
        _ => Message::Error
      },
    }
  }
}

#[tokio::main]
async fn main() {
  let (snd, rcv) = bounded(4096);

  let mut tasks = JoinSet::new();
  let workers_count = workers_count();

  println!("Starting writer...");
  let writer = tokio::spawn(async move {
    let mut csv_file = Writer::from_path(format!("/scripts/output/rust-{}.csv", now())).unwrap();

    for message in rcv.iter() {
      match message {
        Message::Row(row) => {
          csv_file.write_record(row).unwrap();
        },
        Message::Done => break,
        _ => unreachable!()
      }
    }
  });

  println!("Starting workers...");
  for idx in 0..(workers_count * 8) {
    let snd2 = snd.clone();

    tasks.spawn(async move {
      print!("{}... ", idx);
      let config = RedisConfig::from_url(&redis_path()).unwrap();
      let client = Builder::from_config(config).build().unwrap();
      client.init().await.unwrap();

      loop {
        let item: Result<Vec<String>, RedisError> = client.brpop("events_queue", 5.0).await;

        match Message::from_redis(item) {
          Message::Decoded(mut payload) => {
            let message = Message::Row(payload.csv_row());

            snd2.send(message).unwrap()
          },

          Message::Timeout | Message::Error => break,
          Message::Row(_) => unreachable!("can't pull row from redis"),
          Message::Done => unreachable!("workers terminate before writer"),
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

    snd3.send(Message::Done).unwrap();
  });

  monitor.await.unwrap();
  writer.await.unwrap();

  println!("Done.");
}
