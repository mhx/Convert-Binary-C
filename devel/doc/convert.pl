#!/usr/bin/perl -w
use strict;
use Pod::Tree::MyHTML;
use Data::Dumper;

my $src = "../../lib/Convert/Binary/C.pm";
my $dest = "Convert-Binary-C.html";

my $html = new Pod::Tree::MyHTML $src, $dest;
$html->translate;
