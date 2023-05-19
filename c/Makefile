worker: worker.c
	LDFLAGS=-L/usr/local/opt/openssl/lib \
	CPPFLAGS=-I/usr/local/opt/openssl/include \
	gcc worker.c -O3 -march=native -lhiredis -lcjson -lssl -lcrypto -o build/worker
