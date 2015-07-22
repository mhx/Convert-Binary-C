################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2003/01/01 11:30:01 +0000 $
# $Revision: 8 $
# $Snapshot: /Convert-Binary-C/0.11 $
# $Source: /t/114_cache.t $
#
################################################################################
# 
# Copyright (c) 2002-2003 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
# 
################################################################################

use Test;
use Convert::Binary::C @ARGV;
use Convert::Binary::C::Cached;

$^W = 1;

BEGIN {
  plan tests => 64;
}

eval { require Data::Dumper }; $Data_Dumper = $@;
eval { require IO::File };     $IO_File = $@;

if( $Data_Dumper or $IO_File ) {
  my $req;
  $req = 'IO::File' if $IO_File;
  $req = 'Data::Dumper' if $Data_Dumper;
  $req = 'Data::Dumper and IO::File' if $Data_Dumper && $IO_File;
  skip( "skip: caching requires $req", 0 ) for 1 .. 61;
  # silence the memory test ;-)
  eval { Convert::Binary::C->new->parse("enum { XXX };") };
  exit;
}

*main::copy = sub {
  my($from, $to) = @_;
  -e $to and unlink $to || die $!;
  my $fh = new IO::File;
  my $th = new IO::File;
  local $/;
  $fh->open("<$from")
    and binmode $fh
    and $th->open(">$to")
    and binmode $th
    or die $!;
  $th->print( $fh->getline );
  $fh->close
   and $th->close
   or die $!;
  -e $to or die $!;
};

$cache = 't/cache.cbc';

#------------------------------------------------------------------------------

# check some basic stuff first

-e $cache and unlink $cache || die $!;

eval {
  $c = new Convert::Binary::C::Cached Cache   => [$cache],
                                      Include => ['t/cache'];
};
ok( $@, qr/Cache must be a string value, not a reference at \Q$0/ );

eval {
  $c = new Convert::Binary::C::Cached Cache   => $cache,
                                      Include => ['t/cache'];
};
ok($@,'',"failed to create Convert::Binary::C::Cached object");

eval {
  $c->parse( 'enum { XXX };' );
};
ok($@,'',"failed to parse code");

eval {
  $c->parse_file( 't/include/include.c' );
};
ok( $@, qr/Cannot parse more than once for cached objects at \Q$0/ );


#------------------------------------------------------------------------------

# check what happens if the cache file cannot be created

eval {
  $c = new Convert::Binary::C::Cached Cache   => 'abc/def/ghi/jkl/mno.pqr',
                                      Include => ['t/cache'];
};
ok($@,'',"failed to create Convert::Binary::C::Cached object");

eval {
  $c->parse( 'enum { XXX };' );
};
ok( $@, qr/Cannot open 'abc\/def\/ghi\/jkl\/mno\.pqr':\s*.*?\s*at \Q$0/ );

#------------------------------------------------------------------------------

-e $cache and unlink $cache || die $!;
cleanup();

# copy initial set of files

copy( qw( t/cache/cache.1   t/cache/cache.h   ) );
copy( qw( t/cache/header.1  t/cache/header.h  ) );
copy( qw( t/cache/sub/dir.1 t/cache/sub/dir.h ) );

# create reference object

@config = (
  Include    => ['t/cache'],
  KeywordMap => {'__inline__' => 'inline', '__restrict__' => undef },
);

eval { $r = new Convert::Binary::C @config };
ok($@,'',"failed to create reference Convert::Binary::C object");

push @config, Cache => $cache;

eval { $c = new Convert::Binary::C::Cached @config };
ok($@,'',"failed to create Convert::Binary::C::Cached object");

eval {
  $c->parse_file( 't/cache/cache.h' );
  $r->parse_file( 't/cache/cache.h' );
};
ok($@,'',"failed to parse files");

# object shouldn't be using the cache file
ok( $c->__uses_cache, 0, "object is using cache file" );

# check if both objects are equivalent
ok( compare( $r, $c ) );

ok( -e $cache );

#------------------------------------------------------------------------------

# this new object should now use the cache file

eval { $c = new Convert::Binary::C::Cached @config };
ok($@,'',"failed to create Convert::Binary::C::Cached object");

eval {
  $c->parse_file( 't/cache/cache.h' );
};
ok($@,'',"failed to parse files");

# object should be using the cache file
ok( $c->__uses_cache, 1, "object isn't using cache file" );

ok( compare( $r, $c ) );

#------------------------------------------------------------------------------

# check if a changes in the files are detected

for( qw( t/cache/sub/dir t/cache/header t/cache/cache ) ) {
  # 'dir' files are the same size, so check by timestamp
  /dir/ and sleep 2;
  copy( "$_.2", "$_.h" );
  /dir/ and sleep 2;

  eval { $c = new Convert::Binary::C::Cached @config };
  ok($@,'',"failed to create Convert::Binary::C::Cached object");

  eval {
    $r->clean->parse_file( 't/cache/cache.h' );
    $c->parse_file( 't/cache/cache.h' );
  };
  ok($@,'',"failed to parse files");

  # can't use cache
  ok( $c->__uses_cache, 0, "object is using cache file" );

  ok( compare( $r, $c ) );

  eval { $c = new Convert::Binary::C::Cached @config };
  ok($@,'',"failed to create Convert::Binary::C::Cached object");

  eval {
    $c->parse_file( 't/cache/cache.h' );
  };
  ok($@,'',"failed to parse files");

  # should use cache
  ok( $c->__uses_cache, 1, "object is not using cache file" );

  ok( compare( $r, $c ) );
}

#------------------------------------------------------------------------------

# changing the way we're parsing should trigger re-parsing

eval { $c = new Convert::Binary::C::Cached @config };
ok($@,'',"failed to create Convert::Binary::C::Cached object");

eval {
  $r->clean->parse( <<'ENDC' );
#include "cache.h"
ENDC
  $c->parse( <<'ENDC' );
#include "cache.h"
ENDC
};
ok($@,'',"failed to parse");

# can't use cache
ok( $c->__uses_cache, 0, "object is using cache file" );

ok( compare( $r, $c ) );

eval { $c = new Convert::Binary::C::Cached @config };
ok($@,'',"failed to create Convert::Binary::C::Cached object");

eval {
  $c->parse( <<'ENDC' );
#include "cache.h"
ENDC
};
ok($@,'',"failed to parse files");

# should use cache
ok( $c->__uses_cache, 1, "object is not using cache file" );

ok( compare( $r, $c ) );

#------------------------------------------------------------------------------

# changing the embedded code should trigger re-parsing

eval { $c = new Convert::Binary::C::Cached @config };
ok($@,'',"failed to create Convert::Binary::C::Cached object");

eval {
  $r->clean->parse( <<'ENDC' );
#define FOO
#include "cache.h"
ENDC
  $c->parse( <<'ENDC' );
#define FOO
#include "cache.h"
ENDC
};
ok($@,'',"failed to parse");

# can't use cache
ok( $c->__uses_cache, 0, "object is using cache file" );

ok( compare( $r, $c ) );

eval { $c = new Convert::Binary::C::Cached @config };
ok($@,'',"failed to create Convert::Binary::C::Cached object");

eval {
  $c->parse( <<'ENDC' );
#define FOO
#include "cache.h"
ENDC
};
ok($@,'',"failed to parse files");

# should use cache
ok( $c->__uses_cache, 1, "object is not using cache file" );

ok( compare( $r, $c ) );

#------------------------------------------------------------------------------

# changing the configuration should trigger re-parsing

push @config, Define => ['BAR'];

eval { $c = new Convert::Binary::C::Cached @config };
ok($@,'',"failed to create Convert::Binary::C::Cached object");

eval {
  $r->clean->Define(['BAR'])->parse( <<'ENDC' );
#define FOO
#include "cache.h"
ENDC
  $c->parse( <<'ENDC' );
#define FOO
#include "cache.h"
ENDC
};
ok($@,'',"failed to parse");

# can't use cache
ok( $c->__uses_cache, 0, "object is using cache file" );

ok( compare( $r, $c ) );

eval { $c = new Convert::Binary::C::Cached @config };
ok($@,'',"failed to create Convert::Binary::C::Cached object");

eval {
  $c->parse( <<'ENDC' );
#define FOO
#include "cache.h"
ENDC
};
ok($@,'',"failed to parse files");

# should use cache
ok( $c->__uses_cache, 1, "object is not using cache file" );

ok( compare( $r, $c ) );

#------------------------------------------------------------------------------

-e $cache and unlink $cache || die $!;
cleanup();

sub cleanup {
  for( qw( t/cache/cache.h t/cache/header.h t/cache/sub/dir.h ) ) {
    -e and unlink || die $!;
  }
}

sub compare {
  my($ref, $obj) = @_;

  my $refcfg = $ref->configure;
  my $objcfg = $obj->configure;

  delete $_->{Cache} for $refcfg, $objcfg;

  print "# compare configurations...\n";
  use Data::Dumper;
  print Dumper( $refcfg, $objcfg );
  reccmp( $refcfg, $objcfg ) or return 0;

  my $refdep = $ref->dependencies;
  my $objdep = $obj->dependencies;

  print "# compare dependencies...\n";
  reccmp( $refdep, $objdep ) or return 0;

  for( qw( enum_names compound_names struct_names union_names typedef_names ) ) {
    print "# compare $_ method...\n";
    reccmp( [sort $ref->$_()], [sort $obj->$_()] ) or return 0;
  }

  for my $meth ( qw( enum compound struct union typedef ) ) {
    print "# compare $meth method...\n";
    my $i;
    my %ref = map { ($i = $_->{identifier} || $_->{declarator}) ? ($i => $_) : (); } $ref->$meth();
    my %obj = map { ($i = $_->{identifier} || $_->{declarator}) ? ($i => $_) : (); } $obj->$meth();
    reccmp( [sort keys %ref], [sort keys %obj] ) or return 0;
    reccmp( [@ref{sort keys %ref}], [@obj{sort keys %obj}] ) or return 0;
  }

  return 1;
}

sub reccmp
{
  my($ref, $val) = @_;

  unless( defined $ref and defined $val ) {
    return defined($ref) == defined($val);
  }

  ref $ref or return $ref eq $val;

  if( ref $ref eq 'ARRAY' ) {
    @$ref == @$val or return 0;
    for( 0..$#$ref ) {
      reccmp( $ref->[$_], $val->[$_] ) or return 0;
    }
  }
  elsif( ref $ref eq 'HASH' ) {
    @{[keys %$ref]} == @{[keys %$val]} or return 0;
    for( keys %$ref ) {
      reccmp( $ref->{$_}, $val->{$_} ) or return 0;
    }
  }
  else { return 0 }

  return 1;
}
