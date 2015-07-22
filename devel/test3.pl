#!/usr/bin/perl -w
use strict;
use Convert::Binary::C;
use Data::Dumper;

my @inc = qw(
  /usr/lib/gcc-lib/i486-suse-linux/2.95.3/include
  /usr/include
);

my $p = new Convert::Binary::C Include => [@inc];

$p->parse( <<'ENDC' );
#include <stdio.h>
#include <jpeglib.h>

typedef struct husel musel;

struct fusel {
  musel *dusel;
};
ENDC

print Data::Dumper->Dump(
        [[$p->enum], [$p->struct], [$p->typedef]],
        [qw(*enum *struct *typedef)]
      );

print Data::Dumper->Dump(
        [[$p->enums], [$p->structs], [$p->typedefs]],
        [qw(*enums *structs *typedefs)]
      );

$^W=0;

my @s = $p->structs;
my @t = $p->typedefs;

printf "%08X %s\n", $p->sizeof($_), $_ for @s;
printf "%08X %s\n", $p->sizeof($_), $_ for @t;
