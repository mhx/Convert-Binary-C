#!/usr/bin/perl -w
use strict;
use Convert::Binary::C;

sub a2s ($) { join '', map chr, @{$_[0]} }

my $gif = Convert::Binary::C->new;
$gif->parse( <<'ENDSTRUCT' );
struct gif_size { 
  char   blah[6];
  short  width;
  short  height;
};
ENDSTRUCT

my($size,$buffer);

format STDOUT_TOP =
Filename          Header   Width  Height
----------------------------------------
.

format STDOUT =
@<<<<<<<<<<<<<<<< @<<<<<<< @<<<<< @<<<<<
$_, a2s $size->{blah}, @$size{'width','height'}
.

while( <*.gif> ) {
  open F, "<$_" or die $!; binmode F;
  read F, $buffer, $gif->sizeof('gif_size');
  close F;
  $size = $gif->unpack('gif_size', $buffer);
  write;
}
