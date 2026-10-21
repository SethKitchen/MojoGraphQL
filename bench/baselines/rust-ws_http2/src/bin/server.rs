// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

// A WebSocket echo server over HTTP/2 (RFC 8441): h2 0.4.20 with the
// extended CONNECT, h2c with prior knowledge, one tokio thread. Each
// `:protocol websocket` stream gets 200; tungstenite 0.30.0 reads the
// frames of its DATA, and each text message goes back on the stream.
// The server prints `PORT <n>` first, for the Mojo load generator.

use std::io::{ErrorKind, Read, Write};

use bytes::Bytes;
use h2::ext::Protocol;
use tokio::net::TcpListener;
use tungstenite::protocol::Role;
use tungstenite::{Message, WebSocket};

/// The bytes of one stream: what arrived, and what goes out.
#[derive(Default)]
struct Memory {
    input: Vec<u8>,
    at: usize,
    output: Vec<u8>,
}

impl Read for Memory {
    fn read(&mut self, buf: &mut [u8]) -> std::io::Result<usize> {
        if self.at == self.input.len() {
            self.input.clear();
            self.at = 0;
            return Err(ErrorKind::WouldBlock.into());
        }
        let n = buf.len().min(self.input.len() - self.at);
        buf[..n].copy_from_slice(&self.input[self.at..self.at + n]);
        self.at += n;
        Ok(n)
    }
}

impl Write for Memory {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        self.output.extend_from_slice(buf);
        Ok(buf.len())
    }

    fn flush(&mut self) -> std::io::Result<()> {
        Ok(())
    }
}

async fn tunnel(
    mut body: h2::RecvStream,
    mut send: h2::SendStream<Bytes>,
) {
    let mut ws = WebSocket::from_raw_socket(Memory::default(), Role::Server, None);
    while let Some(Ok(data)) = body.data().await {
        let _ = body.flow_control().release_capacity(data.len());
        ws.get_mut().input.extend_from_slice(&data);
        loop {
            match ws.read() {
                Ok(Message::Text(text)) => {
                    if ws.send(Message::Text(text)).is_err() {
                        return;
                    }
                }
                Ok(_) => {}
                Err(tungstenite::Error::Io(e)) if e.kind() == ErrorKind::WouldBlock => break,
                Err(_) => return,
            }
        }
        let out = std::mem::take(&mut ws.get_mut().output);
        if !out.is_empty() && send.send_data(Bytes::from(out), false).is_err() {
            return;
        }
    }
}

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
                let mut builder = h2::server::Builder::new();
                builder.enable_connect_protocol();
                let Ok(mut conn) = builder.handshake::<_, Bytes>(stream).await else {
                    return;
                };
                while let Some(Ok((request, mut respond))) = conn.accept().await {
                    let websocket = request.extensions().get::<Protocol>()
                        .map(|p| p.as_str() == "websocket")
                        .unwrap_or(false);
                    let status = if websocket { 200 } else { 404 };
                    let response = http::Response::builder().status(status).body(()).unwrap();
                    let Ok(send) = respond.send_response(response, !websocket) else {
                        continue;
                    };
                    if websocket {
                        tokio::task::spawn(tunnel(request.into_body(), send));
                    }
                }
            });
        }
    });
}
