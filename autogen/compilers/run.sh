#!/bin/bash

COMPILER=$1
case "$2" in
	'')
		OUT=$COMPILER
		;;
	*)
		OUT=$2
		;;
esac

PERL=/usr/bin/perl
PLARGS="-I../../blib/lib -I../../blib/arch"
CCCONFIG="../../bin/ccconfig --quiet"

# $PERL $PLARGS $CCCONFIG --cc $COMPILER >$OUT.cfg
$PERL $PLARGS compile.pl --cc $COMPILER --cfgfile $OUT.cfg --binfile $OUT.bin --datafile $OUT.dat
