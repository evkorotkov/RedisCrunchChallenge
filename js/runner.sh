#!/bin/bash

processes="${1:-2}"
threads="${2:-2}"

for ((i = 1; i <= $processes; i++ )); do
  node index-workers.js $threads  &
done

wait
