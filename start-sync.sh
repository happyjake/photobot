#!/bin/bash
until /root/photobot/sync.rb; do
  echo "crashed with exit code $?.  restart in 10 seconds..." >&2
  sleep 10
done
