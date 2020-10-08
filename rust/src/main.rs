use std::time::SystemTime;
use std::env;
use std::collections::VecDeque;
use std::sync::Arc;

use redis::{Commands, RedisError};
use serde::{Deserialize, Serialize};
use csv::Writer;
use math::round;

use tokio::sync::mpsc;
use tokio::stream::Stream;
use core::pin::Pin;

use futures::stream::poll_fn;
use futures::task::Poll;

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

  // let (snd, mut rcv) = mpsc::channel(4096);

  // let mut tasks = vec![];

  // for _ in 0..8 {
  //   let mut snd2 = snd.clone();

  //   let handle = tokio::spawn(async move {
  //     let client = redis::Client::open(redis_path()).unwrap();
  //     let mut con = client.get_connection().unwrap();

  //     loop {
  //       let encoded = con.brpop("events_queue", 5);
  //       match Message::from_redis(encoded) {
  //         Some(mut message) => {
  //           if let Err(_) = snd2.send(Some(message.csv_row())).await {
  //             break;
  //           }
  //         },
  //         None => {
  //           break;
  //         },
  //       }
  //     }
  //   });

  //   tasks.push(handle);
  // }

  // tokio::spawn(async move {
  //   let mut snd3 = snd.clone();

  //   for task in tasks {
  //     if let Err(_) = task.await {
  //       println!("Task failed.");
  //     }
  //   }

  //   snd3.send(None).await
  // });

  // let mut csv_file = Writer::from_path(format!("../output/rust-{}.csv", now())).unwrap();

  // loop {
  //   if let Some(msg) = rcv.recv().await {
  //     match msg {
  //       Some(row) => {
  //         csv_file.write_record(row).unwrap();
  //       },
  //       None => {
  //         rcv.close();
  //         break;
  //       }
  //     }
  //   }
  // }

  // println!("Done.");

// struct MessageStream {
//   conn: redis::Connection,
//   queue: VecDeque<Option<Message>>,
// }

// impl Stream for MessageStream {
//   type Item = Message;

//   fn poll_next(self: Pin<&mut Self>, cx: &mut Context) -> Poll<Option<Self::Item>> {
//     let local = self.into_ref();

//     tokio::spawn(async move {
//       let encoded = local.conn.brpop("events_queue", 5);
//       let decoded = Message::from_redis(encoded);

//       local.queue.push_back(decoded);
//     });

//     match local.queue.pop_front() {
//       Some(payload) => {
//         match payload {
//           Some(msg) => Poll::Ready(Some(msg)),
//           None => Poll::Ready(None)
//         }
//       },
//       None => Poll::Pending
//     }
//   }
// }

#[tokio::main]
async fn main() {
  let client = redis::Client::open(redis_path()).unwrap();
  let conn = client.get_connection().unwrap();

  let mut queue = Arc::new(VecDeque::new());

  let stream = poll_fn(move |_| -> Poll<Option<Message>> {

    tokio::spawn(async move {
      let encoded = conn.brpop("events_queue", 5);
      let decoded = Message::from_redis(encoded);

      queue.push_back(decoded);
    });

    match queue.pop_front() {
      Some(payload) => {
        match payload {
          Some(msg) => Poll::Ready(Some(msg)),
          None => Poll::Ready(None)
        }
      },
      None => Poll::Pending
    }
  });
}
