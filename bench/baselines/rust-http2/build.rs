// Copyright (c) 2026 Seth Kitchen, PE
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

//! Find the source of the pinned h2 crate in the cargo registry, and write
//! a module file that compiles its `src/hpack` and `src/ext.rs` into the
//! `h2-hpack` program. h2 keeps `hpack` private, so this is the only way to
//! time h2's own encoder and decoder.

use std::env;
use std::fs;
use std::path::PathBuf;

const H2: &str = "h2-0.4.20";

fn main() {
    let home = env::var("CARGO_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from(env::var("HOME").unwrap()).join(".cargo"));
    let registry = home.join("registry").join("src");
    let mut source = None;
    for entry in fs::read_dir(&registry).expect("no cargo registry") {
        let candidate = entry.unwrap().path().join(H2);
        if candidate.join("src").join("hpack").is_dir() {
            source = Some(candidate.join("src"));
        }
    }
    let source = source.expect("h2 0.4.20 is not in the cargo registry");
    let out = PathBuf::from(env::var("OUT_DIR").unwrap()).join("h2_src.rs");
    let text = format!(
        "#[path = {:?}]\npub mod hpack;\n#[path = {:?}]\npub mod ext;\n",
        source.join("hpack").join("mod.rs"),
        source.join("ext.rs"),
    );
    fs::write(out, text).unwrap();
    println!("cargo:rerun-if-changed=build.rs");
}
