## Test environment
AWS EC2 t3.large
2 CPU
8 GB RAM

# Rust
```bash
WORKERS=4 docker-compose run rust

Avg items/s- 25515
Min items/s- 21514
Max items/s- 26136
```

# Golang
```bash
WORKERS=4 docker-compose run golang

Avg items/s- 24589
Min items/s- 19337
Max items/s- 25273
```

# Ruby
```bash
WORKERS=2 THREADS=2 docker-compose run ruby

Avg items/s- 9007
Min items/s- 6492
Max items/s- 9385
```

# Ruby V2
```bash
WORKERS=2 THREADS=2 docker-compose run ruby_v2

Avg items/s- 13473
Min items/s- 10306
Max items/s- 14039
```

# NodeJS (Workers)
```bash
WORKERS=1 THREADS=4 docker-compose run node_workers

Avg items/s- 12351
Min items/s- 5541
Max items/s- 13251
```
