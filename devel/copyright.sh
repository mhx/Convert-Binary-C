#!/bin/bash
FROM='-2011 Marcus'
TO='-2013 Marcus'
for i in `grep -lEIr "Copyright.*$FROM.*Holland" . | grep -v ppport.h`; do
  echo $i
  perl -i.bak -pe "/Copyright.*Holland/ and s/$FROM/$TO/g" $i
done
