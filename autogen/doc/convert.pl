#!/usr/bin/perl -w
use strict;
use Pod::Tree::MyHTML;

my %files = (
  '../../lib/Convert/Binary/C.pm'        => 'Convert-Binary-C.html',
  '../../lib/Convert/Binary/C/Cached.pm' => 'Convert-Binary-C-Cached.html',
  '../../bin/ccconfig'                   => 'ccconfig.html',
  '../../ctlib/Tokenizer.pm'             => 'Tokenizer.html',
);

for( keys %files ) {
  Pod::Tree::MyHTML->new( $_, $files{$_} )->translate;
}
