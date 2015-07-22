#!/bin/bash
if ! wll $1 | grep -v unlocked >/dev/null ; then
  echo "$1 is not locked"
  if wco -q -t \"\" -l $1 ; then
    echo "locked $1"
  else
    echo "failed to lock $1"
    exit 1
  fi
fi
exit 0
