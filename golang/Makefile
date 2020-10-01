build:
	docker build --no-cache -t redis_crunch_challenge_go .
	docker container run --name redis_crunch_challenge_go_1 redis_crunch_challenge_go
	docker cp redis_crunch_challenge_go_1:/app/main .
	docker rm -f redis_crunch_challenge_go_1
