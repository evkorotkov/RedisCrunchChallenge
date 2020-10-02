#!/bin/bash

file_name=$(ls output | grep ${1} | tail -n 1)
echo "File: ${file_name}"

ruby stats.rb output/$file_name
