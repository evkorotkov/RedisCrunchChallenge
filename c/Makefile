worker: worker.c
	LDFLAGS=-L/usr/local/opt/openssl/lib \
	CPPFLAGS=-I/usr/local/opt/openssl/include \
	gcc worker.c -lhiredis -lcjson -lssl -lcrypto -o build/worker
