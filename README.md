# Usage in docker:

## 1. Populate:
```bash
/scripts/populate
```

## 2. Run the language implementation (see below)
## 3. Compute stats (e.g. ruby):
```bash
/scripts/stats ruby
```

# Implementations:

## Ruby

```bash
./runner.sh <processes_count> <threads_count>
```

## Golang

```bash
go build main
WORKERS=<workers_count> ./main
```

## Node

```bash
npm install
node index.js # or node index-workers.js
```

## Rust

```bash
cargo build --release
./target/release/rust
```

## Clojure

```bash
clj -m main
```

## Elixir

```bash
elixir worker.exs
```
Default processes count - 400, to overload it set `PROCESSES_COUNT` env variable.

## C

```bash
make
./build/worker
```
