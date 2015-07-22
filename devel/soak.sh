#!/bin/bash
export ONLY_FAST_TESTS=1
SOAK=../../Devel-PPPort/Current/soak
PRE="/tmp/perl/install/*"
POST="bin/perl5*"
PERLS="$PRE/perl5.00[45]*/$POST $PRE/perl-5*/$POST"
$SOAK $PERLS
