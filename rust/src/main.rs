use redis::{Commands, RedisError};
use serde::{Deserialize, Serialize};
use std::time::SystemTime;
use csv::Writer;
use math::round;

#[derive(Debug, Serialize, Deserialize)]
struct Message {
  index: i32,
  wday: u8,
  payload: String,
  price: f32,
  user_id: i32,

  #[serde(default)]
  total: f32,
}

impl Message {
  const DISCOUNTS: [f32; 7] = [0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 30.0];

  pub fn from_redis(result: Result<Vec<String>, RedisError>) -> Option<Message> {
    match result {
      Ok(payload) => {
        match payload.get(1) {
          Some(encoded) => {
            match serde_json::from_str(encoded) {
              Ok(decoded) => decoded,
              _ => None,
            }
          },
          _ => None
        }
      },
      _ => None,
    }
  }

  pub fn update_discount(&mut self) {
    let discount = Self::DISCOUNTS[self.wday as usize] / 100.0;
    self.total = round::half_up((self.price * (1.0 - discount)).into(), 2) as f32;
  }

  pub fn signature(self) -> String {
    let encoded = serde_json::to_string(&self).unwrap();
    let digest = md5::compute(encoded);
    return format!("{:x}", digest);
  }
}

fn now() -> String {
  let elapsed = SystemTime::now().duration_since(SystemTime::UNIX_EPOCH).unwrap();
  return format!("{}", elapsed.as_millis());
}

fn process_events() {
  let client = redis::Client::open("redis://127.0.0.1/").unwrap();
  let mut con = client.get_connection().unwrap();
  let mut csv_file = Writer::from_path(format!("../output/rust-{}.csv", now())).unwrap();

  loop {
    let encoded = con.brpop("events_queue", 5);
    match Message::from_redis(encoded) {
      Some(mut decoded) => {
        decoded.update_discount();
        csv_file.write_record(&[now(), format!("{}", decoded.index), decoded.signature()]);
      },
      None => break,
    }
  }
}

fn main() {
  process_events();
}
