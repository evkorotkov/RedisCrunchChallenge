use std::time::SystemTime;
use std::env;
use std::thread;

use redis::{Commands, RedisError};
use serde::{Deserialize, Serialize};
use csv::Writer;
use math::round;

use tokio::sync::mpsc;

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
  let (snd, mut rcv) = mpsc::channel(4096);

  let mut tasks = vec![];
  let workers_count = workers_count();

  for idx in 0..workers_count {
    println!("Starting worker {}...", idx);
    let snd2 = snd.clone();

    let handle = tokio::spawn(async move {
      let client = redis::Client::open(redis_path()).unwrap();
      let mut con = client.get_connection().unwrap();

      loop {
        let encoded = con.brpop("events_queue", 5);
        match Message::from_redis(encoded) {
          Some(mut message) => {
            if let Err(_) = snd2.send(Some(message.csv_row())).await {
              break;
            }
          },
          None => {
            break;
          },
        }
      }
    });

    tasks.push(handle);
  }

  tokio::spawn(async move {
    let snd3 = snd.clone();

    for task in tasks {
      if let Err(_) = task.await {
        println!("Task failed.");
      }
    }

    snd3.send(None).await
  });

  let mut csv_file = Writer::from_path(format!("/scripts/output/rust-{}.csv", now())).unwrap();

  loop {
    if let Some(msg) = rcv.recv().await {
      if let Some(row) = msg {
        csv_file.write_record(row).unwrap();
      } else {
        rcv.close();
        break;
      }
    }
  }

  println!("Done.");
}
