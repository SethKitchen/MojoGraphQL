// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

//! The tokio-tungstenite baseline of `ws/echo-roundtrip`.
//!
//! A tokio-tungstenite 0.30 server on a tokio runtime with one thread. It
//! echoes each text message. It prints `PORT <n>` and serves until it is
//! killed. `bench/gql_ws/_wsload.mojo` drives it.

use std::io::Write;

use futures_util::{SinkExt, StreamExt};
use tokio::net::TcpListener;
use tokio_tungstenite::tungstenite::Message;

fn main() {
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .unwrap();
    runtime.block_on(async {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let port = listener.local_addr().unwrap().port();
        println!("PORT {}", port);
        std::io::stdout().flush().unwrap();
        loop {
            let (stream, _) = listener.accept().await.unwrap();
            stream.set_nodelay(true).unwrap();
            tokio::task::spawn(async move {
                let Ok(mut ws) = tokio_tungstenite::accept_async(stream).await else {
                    return;
                };
                while let Some(Ok(message)) = ws.next().await {
                    if let Message::Text(text) = message {
                        if ws.send(Message::Text(text)).await.is_err() {
                            return;
                        }
                    }
                }
            });
        }
    });
}
