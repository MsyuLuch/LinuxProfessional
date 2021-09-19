#!/bin/bash

LOCKFILE=/tmp/lockfile

if [[ -f $LOCKFILE ]]
then
  echo "Lockfile exists, try again later..." >&2
  exit 1
fi
  echo "Process is running ( PID: $$ )" > $LOCKFILE
  trap 'rm -f $LOCKFILE' EXIT

  sh ./script_test.sh access.log 8 5 all


