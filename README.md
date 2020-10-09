# Usage

```bash
redis-cli --eval populate.lua
```

```bash
./stats_last.sh <ruby | js | etc..>
```

## Ruby

```bash
./ruby/runner.sh <processes_count> <threads_count>
```

## Golang

```bash
cd golang/
make build
WORKERS=<workers_count> ./main
```

## Node

```bash
cd js
npm install
node index.js # or node index-workers.js
```

## Rust

```bash
cd rust
cargo build --release
./target/release/rust
```

## Clojure

```bash
cd clojure
clj -m main
```


## Elixir

```elixir
cd elixir
mix deps.get
mix deps.compile

# Supported process modes: genstage, flow, broadway
mix process --mode <process_mode>
```
