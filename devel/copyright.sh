#!/bin/bash
FROM='-2013 Marcus'
TO='-2015 Marcus'
for i in `grep -lEIr "Copyright.*$FROM.*Holland" . | grep -v ppport.h`; do
  echo $i
  perl -i.bak -pe "/Copyright.*Holland/ and s/$FROM/$TO/g" $i
done
