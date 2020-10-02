use redis::{Commands, RedisError};
use serde::Deserialize;

#[derive(Debug, Deserialize)]
struct Message {
  #[serde(default)]
  total: f32,
  wday: u8,

  price: f32,
  index: i32,
  user_id: i32,
  payload: String,
}

impl Message {
  const discounts: [f32; 7] = [0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 30.0];

  pub fn from_redis(result: Result<Vec<String>, RedisError>) -> Option<Message> {
    match result {
      Ok(payload) => {
        let encoded = payload.get(1).unwrap();

        match serde_json::from_str(encoded) {
          Ok(decoded) => decoded,
          _ => None,
        }
      },
      _ => None,
    }
  }

  pub fn update_discount(&mut self) {
    let discount = Self::discounts[self.wday as usize] / 100.0;
    self.total = self.price * (1.0 - discount);
  }
}

fn process_events() {
  let client = redis::Client::open("redis://127.0.0.1/").unwrap();
  let mut con = client.get_connection().unwrap();

  loop {
    let encoded = con.brpop("events_queue", 5);
    match Message::from_redis(encoded) {
      Some(mut decoded) => {
        decoded.update_discount();

        println!("{:?}", decoded);
      },
      None => break,
    }
  }
}

fn main() {
  process_events();
}
