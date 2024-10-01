#!/bin/bash
FROM='-2020 Marcus'
TO='-2024 Marcus'
for i in `grep -lEIr "Copyright.*$FROM.*Holland" . | grep -v ppport.h`; do
  echo $i
  perl -i'' -pe "/Copyright.*Holland/ and s/$FROM/$TO/g" $i
done
