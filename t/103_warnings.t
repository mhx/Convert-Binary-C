################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2002/12/11 13:58:02 +0000 $
# $Revision: 9 $
# $Snapshot: /Convert-Binary-C/0.06 $
# $Source: /t/103_warnings.t $
#
################################################################################
# 
# Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
# 
################################################################################

use Test;
use Convert::Binary::C @ARGV;
use Convert::Binary::C::Cached;

$^W = 1;

BEGIN { plan tests => 2202 }

my($code, $data);
$code = do { local $/; <DATA> };
$data = "abcd";

eval_test(q{

  $p->configure;                                           # (1) Useless use of configure in void context

  $p->member( 'xxx', 666 );                                # (E) Call to member without parse data
  $p->def( 'xxx' );                                        # (E) Call to def without parse data
  $p->pack( 'xxx', {foo=>123} );                           # (E) Call to pack without parse data
  $p->unpack( 'xxx', 'yyy' );                              # (E) Call to unpack without parse data
  $p->sizeof( 'xxx' );                                     # (E) Call to sizeof without parse data
  $p->offsetof( 'xxx', 'yyy' );                            # (E) Call to offsetof without parse data
  $p->member( 'xxx', 123 );                                # (E) Call to member without parse data
  $p->enum_names;                                          # (E) Call to enum_names without parse data
  $p->enum;                                                # (E) Call to enum without parse data
  $p->compound_names;                                      # (E) Call to compound_names without parse data
  $p->compound;                                            # (E) Call to compound without parse data
  $p->struct_names;                                        # (E) Call to struct_names without parse data
  $p->struct;                                              # (E) Call to struct without parse data
  $p->union_names;                                         # (E) Call to union_names without parse data
  $p->union;                                               # (E) Call to union without parse data
  $p->typedef_names;                                       # (E) Call to typedef_names without parse data
  $p->typedef;                                             # (E) Call to typedef without parse data
  $p->dependencies;                                        # (E) Call to dependencies without parse data
  $p->sourcify;                                            # (E) Call to sourcify without parse data

  $p->parse_file( 'foobar.c' );                            # (E) Cannot find input file 'foobar.c'

  $p->Define(qw( DEFINE=3 DEFINE=2 ), '=');
  $p->parse('');                                           # (1) macro ... DEFINE ... redefined
                                                           # (1) void macro name
  $p->Define([]);

  $p->Assert(qw{ PRED(answer) 1(foo) SYNTAX) UNFINISHED( });
  $p->parse('');                                           # (1) illegal assertion name for #assert
                                                           # (1) syntax error in #assert
                                                           # (1) unfinished #assert
  $p->Assert([]);

  $p->parse( $code );                                      # (1) macro ... FOO ... redefined
                                                           # (2) (warning) ... trailing garbage in #assert
                                                           # (1) void assertion in #assert
                                                           # (1) syntax error for assertion in #if
                                                           # (1) file ... not_here.h ... not found
                                                           # (2) (warning) ... trailing garbage in #ifdef

  $p->def( 'xxx' );                                        # (1) Useless use of def in void context
  $p->dependencies;                                        # (1) Useless use of dependencies in void context
  $p->sourcify;                                            # (1) Useless use of sourcify in void context
  $p->clone;                                               # (1) Useless use of clone in void context

  $p->configure( Include => 'Boo' );                       # (E) Include wants a reference to an array of strings
  $p->Include( { Boo => 'Boo' } );                         # (E) Include wants an array reference
  $p->Include( 'Boo', ['Boo'] );                           # (E) Argument 2 to Include must not be a reference
  $p->Include( ['Boo'], ['Boo'] );                         # (E) Invalid number of arguments to Include
  $p->ByteOrder( ['Boo'] );                                # (E) ByteOrder must be a string value, not a reference
  $p->ByteOrder( 'Boo' );                                  # (E) ByteOrder must be 'BigEndian' or 'LittleEndian', not 'Boo'
  $p->FloatSize( [1] );                                    # (E) FloatSize must be an integer value, not a reference
  $p->FloatSize( 13 );                                     # (E) FloatSize must be 0, 1, 2, 4, 8 or 12, not 13
  $p->FloatSize( 1 );                                      # no warning

  $p->pack( 'xxx', 'yyy' );                                # (1) Useless use of pack in void context
  $x = $p->pack( 'na', 'yyy' );                            # (E) Cannot find 'na'
  $x = $p->pack( 'nodef', 'yyy' );                         # (E) Got no struct declarations in resolution of 'nodef'
  $x = $p->pack( 'xxx', 'yyy' );                           # (E) Got no definition for 'union xxx'
  $p->pack( 'na', 'yyy', $data );                          # (E) Cannot find 'na'
  $x = $p->pack( 'hasbf', {} );                            # (1) Bitfields are unsupported in pack('hasbf')
  $x = $p->pack( 't_unsafe', [] );                         # (1) Unsafe values used in pack('t_unsafe')
  $x = $p->pack( 's_unsafe', {} );                         # (1) Unsafe values used in pack('s_unsafe')
  $x = $p->pack( 'nonnative', 0 );                         # (1) Cannot pack non-native floating point values
  $p->pack( 'enum enu', 'A', ['xxxx'] );                   # (E) Type of arg 3 to pack must be string
  $p->pack( 'enum enu', 'A', 'xxxx' );                     # (E) Modification of a read-only value attempted
  $x = $p->pack( 'enum enu', 'A', 'xxxx' );                # no warning

  $p->unpack( 'test', $data );                             # (1) Useless use of unpack in void context
  $x = $p->unpack( 'na', $data );                          # (E) Cannot find 'na'
  $x = $p->unpack( 'nodef', $data );                       # (E) Got no struct declarations in resolution of 'nodef'
  $x = $p->unpack( 'xxx', $data );                         # (E) Got no definition for 'union xxx'
  $x = $p->unpack( 'test', $data );                        # (1) Data too short
  $x = $p->unpack( 'hasbf', $data );                       # (1) Bitfields are unsupported in unpack('hasbf')
  $x = $p->unpack( 't_unsafe', $data );                    # (1) Unsafe values used in unpack('t_unsafe')
                                                           # (1) Data too short
  $x = $p->unpack( 's_unsafe', $data );                    # (1) Unsafe values used in unpack('s_unsafe')
                                                           # (1) Data too short
  $x = $p->unpack( 'nonnative', 'x' );                     # (1) Cannot unpack non-native floating point values

  $p->sizeof( 'na' );                                      # (1) Useless use of sizeof in void context
  $x = $p->sizeof( 'na' );                                 # (E) Cannot find 'na'
  $x = $p->sizeof( 'nodef' );                              # (E) Got no struct declarations in resolution of 'nodef'
  $x = $p->sizeof( 'xxx' );                                # (E) Got no definition for 'union xxx'
  $x = $p->sizeof( 'hasbf' );                              # (1) Bitfields are unsupported in sizeof('hasbf')
  $x = $p->sizeof( 't_unsafe' );                           # (1) Unsafe values used in sizeof('t_unsafe')
  $x = $p->sizeof( 's_unsafe' );                           # (1) Unsafe values used in sizeof('s_unsafe')
  $x = $p->sizeof( 'enum enu . foo' );                     # (E) An enum does not have members
  $x = $p->sizeof( 'enumtype.foo' );                       # (E) An enum does not have members
  $x = $p->sizeof( 'ptrtype.foo' );                        # (E) A pointer type does not have members
  $x = $p->sizeof( 'basic.foo' );                          # (E) A basic type does not have members
  $x = $p->sizeof( 'enumtype [0]' );                       # (E) Invalid character '[' (0x5B) in struct member expression
  $x = $p->sizeof( 'test.666' );                           # (E) Struct members must start with a character or an underscore
  $x = $p->sizeof( 'test.foo.d' );                         # (E) Cannot access member '.d' of array type
  $x = $p->sizeof( 'test.bar.d' );                         # (E) Cannot access member '.d' of non-compound type
  $x = $p->sizeof( 'test.yyy.d' );                         # (E) Cannot access member '.d' of pointer type
  $x = $p->sizeof( 'test.ptr.d' );                         # (E) Cannot access member '.d' of pointer type
  $x = $p->sizeof( 'test.xxx[1]' );                        # (E) Cannot use 'xxx' as an array
  $x = $p->sizeof( 'test.bar[1]' );                        # (E) Cannot use 'bar' as an array
  $x = $p->sizeof( 'test.bar()' );                         # (E) Invalid character '(' (0x28) in struct member expression
  $x = $p->sizeof( 'test.foo[1][2' );                      # (E) Incomplete struct member expression
  $x = $p->sizeof( 'test.foo[1][2].d' );                   # (E) Cannot find struct member 'd'
  $x = $p->sizeof( 'test.foo[a]' );                        # (E) Array indices must be constant decimal values
  $x = $p->sizeof( 'test.foo[0x1]' );                      # (E) Index operator not terminated correctly
  $x = $p->sizeof( 'test.foo[2]' );                        # (E) Cannot use index 2 into array of size 2
  $x = $p->sizeof( 'test.foo[1][2][0]' );                  # (E) Cannot use 'foo' as a 3-dimensional array

  $p->offsetof( 'xxx', 666 );                              # (1) Useless use of offsetof in void context
  $x = $p->offsetof( 'abc', 666 );                         # (E) Cannot find 'abc'
  $x = $p->offsetof( 'nodef', 666 );                       # (E) Got no struct declarations in resolution of 'nodef'
  $x = $p->offsetof( 'xxx', 666 );                         # (E) Got no definition for 'union xxx'
  $x = $p->offsetof( 'ptrtype', 666 );                     # (E) Cannot use offsetof on a pointer type
  $x = $p->offsetof( 'basic', '666' );                     # (E) Cannot use offsetof on a basic type
  $x = $p->offsetof( 'enu', '666' );                       # (E) Cannot use offsetof on an enum
  $x = $p->offsetof( 'test', '666' );                      # (E) Struct members must start with a character or an underscore
  $x = $p->offsetof( 'test', 'foo.d' );                    # (E) Cannot access member '.d' of array type
  $x = $p->offsetof( 'test', 'bar.d' );                    # (E) Cannot access member '.d' of non-compound type
  $x = $p->offsetof( 'test', 'yyy.d' );                    # (E) Cannot access member '.d' of pointer type
  $x = $p->offsetof( 'test', 'ptr.d' );                    # (E) Cannot access member '.d' of pointer type
  $x = $p->offsetof( 'test', 'xxx[1]' );                   # (E) Cannot use 'xxx' as an array
  $x = $p->offsetof( 'test', 'bar[1]' );                   # (E) Cannot use 'bar' as an array
  $x = $p->offsetof( 'test', 'bar()' );                    # (E) Invalid character '(' (0x28) in struct member expression
  $x = $p->offsetof( 'test', 'foo[1][2' );                 # (E) Incomplete struct member expression
  $x = $p->offsetof( 'test', 'foo[1][2].d' );              # (E) Cannot find struct member 'd'
  $x = $p->offsetof( 'test', 'foo[a]' );                   # (E) Array indices must be constant decimal values
  $x = $p->offsetof( 'test', 'foo[0x1]' );                 # (E) Index operator not terminated correctly
  $x = $p->offsetof( 'test', 'foo[2]' );                   # (E) Cannot use index 2 into array of size 2
  $x = $p->offsetof( 'test', 'foo[1][2][0]' );             # (E) Cannot use 'foo' as a 3-dimensional array
  $x = $p->offsetof( 'hasbf', 'nobf' );                    # (1) Bitfields are unsupported in offsetof('hasbf')
  $x = $p->offsetof( 's_unsafe', 'foo' );                  # (1) Unsafe values used in offsetof('s_unsafe')

  $x = $p->offsetof( 'test.arx[3][4]', 'uni[3].str.c' );   # (E) Cannot find struct member 'arx'
  $x = $p->offsetof( 'test.ary[3][4]', 'uni[3].str.c' );   # (E) Cannot use index 3 into array of size 3
  $x = $p->offsetof( 'test.ary[2][4]', 'uni[3].str.c' );   # (E) Cannot use index 4 into array of size 4
  $x = $p->offsetof( 'test.ary[2][3]', 'uni[6].str.c' );   # (E) Cannot use index 6 into array of size 5
  $x = $p->offsetof( 'test.ary[2][3]', 'uni[1].str.c' );   # (E) Cannot find struct member 'c'
  $x = $p->offsetof( 'test.ary[2][3].uni.a', 'xxx' );      # (E) Cannot access member '.a' of array type
  $x = $p->offsetof( 'test.ary[2][3].uni', 'xxx' );        # (E) Cannot use offsetof on an array type
  $x = $p->offsetof( 'test.ary[2][3]', 'uni.xxx' );        # (E) Cannot access member '.xxx' of array type
  $x = $p->offsetof( 'test.ary[2][3].uni[0].a', 'xxx' );   # (E) Cannot use offsetof on an enum
  $x = $p->offsetof( 'test.ary[2][3].uni[0].str.a', 'b' ); # (E) Cannot use offsetof on a pointer type

  $p->member( 'xxx', 6666 );                               # (1) Useless use of member in void context
  $x = $p->member( 'abc', 6666 );                          # (E) Cannot find 'abc'
  $x = $p->member( 'nodef', 6666 );                        # (E) Got no struct declarations in resolution of 'nodef'
  $x = $p->member( 'xxx', 6666 );                          # (E) Got no definition for 'union xxx'
  $x = $p->member( 'ptrtype', 6666 );                      # (E) Cannot use member on a pointer type
  $x = $p->member( 'basic', 6666 );                        # (E) Cannot use member on a basic type
  $x = $p->member( 'enu', 6666 );                          # (E) Cannot use member on an enum
  $x = $p->member( 'test', 6666 );                         # (E) Offset 6666 out of range
  $x = $p->member( 'hasbf', 1 );                           # (1) Bitfields are unsupported in member('hasbf')
  $x = $p->member( 's_unsafe', 1 );                        # (1) Unsafe values used in member('s_unsafe')

  $x = $p->member( 'test.arx[3][4]', 6666 );               # (E) Cannot find struct member 'arx'
  $x = $p->member( 'test.ary[3][4]', 6666 );               # (E) Cannot use index 3 into array of size 3
  $x = $p->member( 'test.ary[2][4]', 6666 );               # (E) Cannot use index 4 into array of size 4
  $x = $p->member( 'test.ary[2][3]', 6666 );               # (E) Offset 6666 out of range
  $x = $p->member( 'test.ary[2][3].uni.a', 6666 );         # (E) Cannot access member '.a' of array type
  $x = $p->member( 'test.ary[2][3].uni', 6666 );           # (E) Cannot use member on an array type
  $x = $p->member( 'test.ary[2][3].uni[0].a', 6666 );      # (E) Cannot use member on an enum
  $x = $p->member( 'test.ary[2][3].uni[0].str.a', 6666 );  # (E) Cannot use member on a pointer type

  $p->enum_names;                                          # (1) Useless use of enum_names in void context
  $p->enum;                                                # (1) Useless use of enum in void context
  $x = $p->enum( 'na' );                                   # (1) Cannot find enum 'na'

  $p->compound_names;                                      # (1) Useless use of compound_names in void context
  $p->compound;                                            # (1) Useless use of compound in void context
  $x = $p->compound( 'na' );                               # (1) Cannot find compound 'na'

  $p->struct_names;                                        # (1) Useless use of struct_names in void context
  $p->struct;                                              # (1) Useless use of struct in void context
  $x = $p->struct( 'na' );                                 # (1) Cannot find struct 'na'

  $p->union_names;                                         # (1) Useless use of union_names in void context
  $p->union;                                               # (1) Useless use of union in void context
  $x = $p->union( 'na' );                                  # (1) Cannot find union 'na'

  $p->typedef_names;                                       # (1) Useless use of typedef_names in void context
  $p->typedef;                                             # (1) Useless use of typedef in void context
  $x = $p->typedef( 'na' );                                # (1) Cannot find typedef 'na'

  $x = $p->pack( 'e_unsafe', 'SAFE' );                     # no warning
  $x = $p->pack( 'e_unsafe', 'GOOD' );                     # no warning
  $x = $p->pack( 'e_unsafe', 'UNSAFE' );                   # (1) Enumerator value 'UNSAFE' is unsafe
  $x = $p->pack( 'e_unsafe', 'BAD' );                      # (1) Enumerator value 'BAD' is unsafe

  $p->EnumType( 'Integer' );
  $x = $p->unpack( 'e_unsafe', $data );                    # no warning
  $p->EnumType( 'String' );
  $x = $p->unpack( 'e_unsafe', $data );                    # (1) Enumeration 'e_unsafe' contains unsafe values
  $p->EnumType( 'Both' );
  $x = $p->unpack( 'e_unsafe', $data );                    # (1) Enumeration 'e_unsafe' contains unsafe values

}, [0 .. 2], [qw( Convert::Binary::C Convert::Binary::C::Cached )]);

sub eval_test
{
  my($test, $levels, $classes) = @_;
  my(@warn, $p);

  $SIG{__WARN__} = sub { push @warn, shift };

  my @tests;

  for( split $/, $test ) {
    print "# $_\n";
    /^\s*$/ and next;
    /^\s*\/\// and next;
    my($c, $l, $w) = /^(.*;)?(?:\s*#(?:\s*\(([E\d])\))?\s*(.*?))?\s*$/;
    print "# [$c] [$l] [$w]\n";
    if( defined $c ) {
      push @tests, { code => $c, warnings => [] };
    }
    if( @tests && defined $l ) {
      $w = quotemeta $w;
      $w =~ s/(?:\\\s)+(?:\\\.){3}(?:\\\s)+/.*/g;
      if( $l eq 'E' ) {
        $tests[-1]{error} = qr/$w/;
      }
      else {
        push @{$tests[-1]{warnings}}, { level => $l, regex => qr/$w.*?\s+at\s+\(eval\s+\d+\)/ };
      }
    }
  }

  for $class ( @$classes ) {
    for $level ( @$levels ) {
      $^W = $level ? 1 : 0;
      eval { $p = $class->new( Warnings => $level == 2 ) };
      ok($@, '', "failed to create $class object");

      for my $t ( @tests ) {
        my @warnings = map { $_->{level} <= $level ? $_->{regex} : () } @{$t->{warnings}};
        @warn = ();
        print "# evaluating code: $t->{code}\n";
        eval $t->{code};
        if( $@ ) {
          my $err = $@;
          $err =~ s/^/#     /gms;
          $err =~ s/[\r\n]+$//gms;
          print "#   error:\n$err\n";
        }
        if( exists $t->{error} ) {
          ok($@, $t->{error}, "wrong error");
        }
        else {
          ok($@, '', "failed to evaluate code");
        }
        chomp @warn;
        if( @warn ) {
          printf "#   got %d warning(s):\n", scalar @warn;
          for( @warn ) {
            s/^/#     /gms;
            s/[\r\n]+$//gms;
            print "$_\n";
          }
        }
        else {
          print "#   got no warnings\n";
        }
        ok( scalar @warn, scalar @warnings, "got more/less warnings than expected" );
        if( @warn != @warnings ) {
          for( 0 .. ($#warnings > $#warn ? $#warnings : $#warn) ) {
            print "# (", $_+1, ") '", $warn[$_] || 'undef',
                  "' =~ /", $warnings[$_] || 'undef', "/\n";
          }
        }
        ok( $warn[$_], $warnings[$_] ) for 0 .. $#warnings;
      }
    }
  }

  $SIG{__WARN__} = 'DEFAULT';
}

__DATA__

#define FOO 1
#define FOO 2

#assert TEST(assertion)
#assert THIS(is) garbage
#assert VOID()

#if #TEST (assertion)
  typedef struct __nodef nodef;
#endif

#if #TEST (nothing)
#  error "boo!"
#endif

#if #TEST ()
  /* this is a syntax error */
#endif

#include <not_here.h>

#ifdef FOO BLABLA
#endif

typedef union __hasbf hasbf;

typedef struct ptrstruct *ptrtype;

typedef int basic;

typedef float nonnative;

typedef enum enu enumtype;

enum enu { A };

struct test {
  enum yyy  *xxx;
  union xxx *yyy;
  ptrtype   *ptr;
  int      (*test[2])[3];
  struct {
    int a;
    int b[2];
    int c[2][3];
  }          foo[2][3];
  struct {
    int a;
    union {
      enum enu a;
      struct {
        long *a;
        char b[10];
      }      str;
    }        uni[5];
  }          ary[3][4];
  int        bar;
};

union __hasbf {
  struct {
    int a:1;
    int b:2;
    int c:3;
    int :10;
  } bf;
  unsigned short nobf;
};

enum e_unsafe {
  SAFE = 42,
  GOOD,
  UNSAFE = sizeof( union __hasbf ),
  BAD
};

typedef int t_unsafe[(char)600];  /* cast makes it unsafe */

struct s_unsafe {
  int foo[BAD];  /* uuuhhh!! */
};

