#!/bin/bash
FROM='-2009 Marcus'
TO='-2011 Marcus'
for i in `grep -lEIr "Copyright.*$FROM.*Holland" . | grep -v ppport.h`; do
  echo $i
  wco -l -t '' $i
  perl -i.bak -pe "/Copyright.*Holland/ and s/$FROM/$TO/g" $i
done
