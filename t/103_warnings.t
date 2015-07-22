################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2003/04/20 04:16:16 +0100 $
# $Revision: 21 $
# $Snapshot: /Convert-Binary-C/0.13 $
# $Source: /t/103_warnings.t $
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

BEGIN { plan tests => 3382 }

my($code, $data);
$code = do { local $/; <DATA> };
$data = "abcd";

eval_test(q{

  $p->configure;                                           # (1) Useless use of configure in void context

  $p->member( 'xxx', 666 );                                # (E) Call to member without parse data
  $p->def( 'xxx' );                                        # (1) Useless use of def in void context
  $p->pack( 'xxx', {foo=>123} );                           # (1) Useless use of pack in void context
  $p->unpack( 'xxx', 'yyy' );                              # (1) Useless use of unpack in void context
  $p->sizeof( 'xxx' );                                     # (1) Useless use of sizeof in void context
  $p->typeof( 'xxx' );                                     # (1) Useless use of typeof in void context
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

  $p->parse_file( '' );                                    # (E) Cannot find input file ''
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

  $x = $p->pack( 'signed int', 1 );                        # no warning
  $x = $p->unpack( 'signed int', $x );                     # no warning
  $x = $p->sizeof( 'long long' );                          # no warning
  $x = $p->typeof( 'long double' );                        # no warning

  $p->parse( $code );                                      # (1) macro ... FOO ... redefined
                                                           # (2) (warning) ... trailing garbage in #assert
                                                           # (1) void assertion in #assert
                                                           # (1) syntax error for assertion in #if
                                                           # (1) file ... not_here.h ... not found
                                                           # (2) (warning) ... trailing garbage in #ifdef
                                                           # (1) unmatched #endif
                                                           # (1) rogue #else
                                                           # (1) rogue #elif
                                                           # (1) unknown cpp directive '#foobar'

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
  $p->FloatSize( 13 );                                     # (E) FloatSize must be 0, 1, 2, 4, 8, 12 or 16, not 13
  $p->FloatSize( 1 );                                      # no warning

  $x = $p->def( '' );                                      # no warning
  $x = $p->def( 'notthere' );                              # no warning
  $x = $p->def( 'notthere.yyy' );                          # (1) Ignoring potential member expression ('.yyy') after type name
  $x = $p->def( 'xxx.yyy' );                               # (1) Ignoring potential member expression ('.yyy') after type name
  $x = $p->def( 'xxx[yyy]' );                              # (1) Ignoring potential array expression ('[yyy]') after type name
  $x = $p->def( 'xxx **' );                                # (1) Ignoring garbage ('**') after type name

  $p->pack( 'xxx', 'yyy' );                                # (1) Useless use of pack in void context
  $x = $p->pack( '', 1 );                                  # (E) Cannot find ''
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

  $x = $p->pack( 'test.foo', 23 );                         # (1) 'test.foo' should be an array reference
  $x = $p->pack( 'test.foo', {} );                         # (1) 'test.foo' should be an array reference
  $x = $p->pack( 'test.foo', sub { 1 } );                  # (1) 'test.foo' should be an array reference
  $x = $p->pack( 'test.bar', [] );                         # (1) 'test.bar' should be a scalar value
  $x = $p->pack( 'test.xxx', {} );                         # (1) 'test.xxx' should be a scalar value

  $p->unpack( 'test', $data );                             # (1) Useless use of unpack in void context
  $x = $p->unpack( '', $data );                            # (E) Cannot find ''
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

  $x = $p->unpack( 'multiple', 'x'x100 );                  # (1) Member 'a' used more than once in struct multiple defined in [buffer](71)
                                                           # (1) Member 'b' used more than once in union defined in [buffer](75)

  $p->sizeof( 'na' );                                      # (1) Useless use of sizeof in void context
  $x = $p->sizeof( '' );                                   # (E) Cannot find ''
  $x = $p->sizeof( 'na' );                                 # (E) Cannot find 'na'
  $x = $p->sizeof( 'long =' );                             # (E) Cannot find 'long ='
  $x = $p->sizeof( 'nodef' );                              # (E) Got no struct declarations in resolution of 'nodef'
  $x = $p->sizeof( 'xxx' );                                # (E) Got no definition for 'union xxx'
  $x = $p->sizeof( 'hasbf' );                              # (1) Bitfields are unsupported in sizeof('hasbf')
  $x = $p->sizeof( 't_unsafe' );                           # (1) Unsafe values used in sizeof('t_unsafe')
  $x = $p->sizeof( 's_unsafe' );                           # (1) Unsafe values used in sizeof('s_unsafe')
  $x = $p->sizeof( 'enum enu . foo' );                     # (E) Cannot access member '. foo' of non-compound type
  $x = $p->sizeof( 'enumtype.foo' );                       # (E) Cannot access member '.foo' of non-compound type
  $x = $p->sizeof( 'ptrtype.foo' );                        # (E) Cannot access member '.foo' of pointer type
  $x = $p->sizeof( 'basic.foo' );                          # (E) Cannot access member '.foo' of non-compound type
  $x = $p->sizeof( 'enumtype [0]' );                       # (E) Cannot use type as an array
  $x = $p->sizeof( 'test.666' );                           # (E) Struct members must start with a character or an underscore
  $x = $p->sizeof( 'test.foo.d' );                         # (E) Cannot access member '.d' of array type
  $x = $p->sizeof( 'test.bar.d' );                         # (E) Cannot access member '.d' of non-compound type
  $x = $p->sizeof( 'test.yyy.d' );                         # (E) Cannot access member '.d' of pointer type
  $x = $p->sizeof( 'test.ptr.d' );                         # (E) Cannot access member '.d' of pointer type
  $x = $p->sizeof( 'test.xxx[1]' );                        # (E) Cannot use 'xxx' as an array
  $x = $p->sizeof( 'test.bar[1]' );                        # (E) Cannot use 'bar' as an array
  $x = $p->sizeof( 'test.bar()' );                         # (E) Invalid character '(' (0x28) in struct member expression
  $x = $p->sizeof( 'test.bar+' );                          # (E) Invalid character '+' (0x2B) in struct member expression
  $x = $p->sizeof( 'test.bar+a' );                         # (E) Invalid character '+' (0x2B) in struct member expression
  $x = $p->sizeof( 'test.bar a' );                         # (E) Invalid character 'a' (0x61) in struct member expression
  $x = $p->sizeof( 'test bar' );                           # (E) Invalid character 'b' (0x62) in struct member expression
  $x = $p->sizeof( 'test.bar+1' );                         # no warning
  $x = $p->sizeof( 'test.foo[1][2' );                      # (E) Incomplete struct member expression
  $x = $p->sizeof( 'test.foo[1][2].d' );                   # (E) Cannot find struct member 'd'
  $x = $p->sizeof( 'test.foo[a]' );                        # (E) Array indices must be constant decimal values
  $x = $p->sizeof( 'test.foo[0x1]' );                      # (E) Index operator not terminated correctly
  $x = $p->sizeof( 'test.foo[2]' );                        # (E) Cannot use index 2 into array of size 2
  $x = $p->sizeof( 'test.foo[1][2][0]' );                  # (E) Cannot use 'foo' as a 3-dimensional array

  $p->typeof( 'na' );                                      # (1) Useless use of typeof in void context
  $x = $p->typeof( '' );                                   # (E) Cannot find ''
  $x = $p->typeof( 'na' );                                 # (E) Cannot find 'na'
  $x = $p->typeof( 'nodef' );                              # (E) Got no struct declarations in resolution of 'nodef'
  $x = $p->typeof( 'xxx' );                                # (E) Got no definition for 'union xxx'
  $x = $p->typeof( 'enum enu . foo' );                     # (E) Cannot access member '. foo' of non-compound type
  $x = $p->typeof( 'enumtype.foo' );                       # (E) Cannot access member '.foo' of non-compound type
  $x = $p->typeof( 'ptrtype.foo' );                        # (E) Cannot access member '.foo' of pointer type
  $x = $p->typeof( 'basic.foo' );                          # (E) Cannot access member '.foo' of non-compound type
  $x = $p->typeof( 'enumtype [0]' );                       # (E) Cannot use type as an array
  $x = $p->typeof( 'test.666' );                           # (E) Struct members must start with a character or an underscore
  $x = $p->typeof( 'test.foo.d' );                         # (E) Cannot access member '.d' of array type
  $x = $p->typeof( 'test.bar.d' );                         # (E) Cannot access member '.d' of non-compound type
  $x = $p->typeof( 'test.yyy.d' );                         # (E) Cannot access member '.d' of pointer type
  $x = $p->typeof( 'test.ptr.d' );                         # (E) Cannot access member '.d' of pointer type
  $x = $p->typeof( 'test.xxx[1]' );                        # (E) Cannot use 'xxx' as an array
  $x = $p->typeof( 'test.bar[1]' );                        # (E) Cannot use 'bar' as an array
  $x = $p->typeof( 'test.bar()' );                         # (E) Invalid character '(' (0x28) in struct member expression
  $x = $p->typeof( 'test.bar+' );                          # (E) Invalid character '+' (0x2B) in struct member expression
  $x = $p->typeof( 'test.bar+a' );                         # (E) Invalid character '+' (0x2B) in struct member expression
  $x = $p->typeof( 'test.bar+1' );                         # no warning
  $x = $p->typeof( 'test.foo[1][2' );                      # (E) Incomplete struct member expression
  $x = $p->typeof( 'test.foo[1][2].d' );                   # (E) Cannot find struct member 'd'
  $x = $p->typeof( 'test.foo[a]' );                        # (E) Array indices must be constant decimal values
  $x = $p->typeof( 'test.foo[0x1]' );                      # (E) Index operator not terminated correctly
  $x = $p->typeof( 'test.foo[2]' );                        # (E) Cannot use index 2 into array of size 2
  $x = $p->typeof( 'test.foo[1][2][0]' );                  # (E) Cannot use 'foo' as a 3-dimensional array

  $p->offsetof( 'xxx', 666 );                              # (1) Useless use of offsetof in void context
  $x = $p->offsetof( '', 666 );                            # (E) Cannot find ''
  $x = $p->offsetof( 'abc', 666 );                         # (E) Cannot find 'abc'
  $x = $p->offsetof( 'nodef', 666 );                       # (E) Got no struct declarations in resolution of 'nodef'
  $x = $p->offsetof( 'xxx', 666 );                         # (E) Got no definition for 'union xxx'
  $x = $p->offsetof( 'ptrtype', '666' );                   # (E) Invalid character '6' (0x36) in struct member expression
  $x = $p->offsetof( 'basic', '666' );                     # (E) Invalid character '6' (0x36) in struct member expression
  $x = $p->offsetof( 'enu', '666' );                       # (E) Invalid character '6' (0x36) in struct member expression
  $x = $p->offsetof( 'ptrtype', 'a66' );                   # (E) Cannot access member '.a66' of pointer type
  $x = $p->offsetof( 'basic', 'a66' );                     # (E) Cannot access member '.a66' of non-compound type
  $x = $p->offsetof( 'enu', 'a66' );                       # (E) Cannot access member '.a66' of non-compound type
  $x = $p->offsetof( 'long int', 'a66' );                  # (E) Cannot access member '.a66' of non-compound type
  $x = $p->offsetof( 'test', 'foo[0][0].666' );            # (E) Struct members must start with a character or an underscore
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

  $x = $p->offsetof( 'test.bar', 'foo' );                  # (E) Cannot access member '.foo' of non-compound type
  $x = $p->offsetof( 'test.arx[3][4]', 'uni[3].str.c' );   # (E) Cannot find struct member 'arx'
  $x = $p->offsetof( 'test.ary[3][4]', 'uni[3].str.c' );   # (E) Cannot use index 3 into array of size 3
  $x = $p->offsetof( 'test.ary[2][4]', 'uni[3].str.c' );   # (E) Cannot use index 4 into array of size 4
  $x = $p->offsetof( 'test.ary[2][3]', 'uni[6].str.c' );   # (E) Cannot use index 6 into array of size 5
  $x = $p->offsetof( 'test.ary[2][3]', 'uni[1].str.c' );   # (E) Cannot find struct member 'c'
  $x = $p->offsetof( 'test.ary[2][3].uni.a', 'xxx' );      # (E) Cannot access member '.a' of array type
  $x = $p->offsetof( 'test.ary[2][3].uni', 'xxx' );        # (E) Cannot access member '.xxx' of array type
  $x = $p->offsetof( 'test.ary[2][3]', 'uni.xxx' );        # (E) Cannot access member '.xxx' of array type
  $x = $p->offsetof( 'test.ary[2][3].uni[0].a', 'xxx' );   # (E) Cannot access member '.xxx' of non-compound type
  $x = $p->offsetof( 'test.ary[2][3].uni[0].str.a', 'b' ); # (E) Cannot access member '.b' of pointer type

  $x = $p->offsetof( 'test.ary[2][2]', 'uni' );            # no warning
  $x = $p->offsetof( 'test.ary[2][2]', '' );               # (1) Empty string passed as member expression
  $x = $p->offsetof( 'test.ary[2][2]', "\t " );            # (1) Empty string passed as member expression

  $p->member( 'xxx', 6666 );                               # (1) Useless use of member in void context
  $x = $p->member( '', 6666 );                             # (E) Cannot find ''
  $x = $p->member( 'abc', 6666 );                          # (E) Cannot find 'abc'
  $x = $p->member( 'nodef', 6666 );                        # (E) Got no struct declarations in resolution of 'nodef'
  $x = $p->member( 'xxx', 6666 );                          # (E) Got no definition for 'union xxx'
  $x = $p->member( 'ptrtype', 6666 );                      # (E) Cannot use member on a pointer type
  $x = $p->member( 'basic', 6666 );                        # (E) Cannot use member on a basic type
  $x = $p->member( 'long long', 6666 );                    # (E) Cannot use member on a basic type
  $x = $p->member( 'enu', 6666 );                          # (E) Cannot use member on an enum
  $x = $p->member( 'test', 6666 );                         # (E) Offset 6666 out of range
  $x = $p->member( 'test', -10 );                          # (E) Offset -10 out of range
  $x = $p->member( 'hasbf', 1 );                           # (1) Bitfields are unsupported in member('hasbf')
  $x = $p->member( 's_unsafe', 1 );                        # (1) Unsafe values used in member('s_unsafe')

  $x = $p->member( 'test.bar', 6666 );                     # (E) Cannot use member on a basic type
  $x = $p->member( 'test.arx[3][4]', 6666 );               # (E) Cannot find struct member 'arx'
  $x = $p->member( 'test.ary[3][4]', 6666 );               # (E) Cannot use index 3 into array of size 3
  $x = $p->member( 'test.ary[2][4]', 6666 );               # (E) Cannot use index 4 into array of size 4
  $x = $p->member( 'test.ary[2][3]', 6666 );               # (E) Offset 6666 out of range
  $x = $p->member( 'test.ary[2][3].uni.a', 6666 );         # (E) Cannot access member '.a' of array type
  $x = $p->member( 'test.ary[2][3].uni', 0 );              # no error
  $x = $p->member( 'test.ary[2][3].uni[0].a', 6666 );      # (E) Cannot use member on an enum
  $x = $p->member( 'test.ary[2][3].uni[0].str.a', 6666 );  # (E) Cannot use member on a pointer type

  $p->enum_names;                                          # (1) Useless use of enum_names in void context
  $p->enum;                                                # (1) Useless use of enum in void context
  $x = $p->enum( 'na' );                                   # (1) Cannot find enum 'na'
  $x = $p->enum( 'enum na' );                              # (1) Cannot find enum 'na'
  @x = $p->enum( 'enu', '' );                              # (1) Cannot find enum ''
  $x = $p->enum( 'enum enu' );                             # no warning

  $p->compound_names;                                      # (1) Useless use of compound_names in void context
  $p->compound;                                            # (1) Useless use of compound in void context
  @x = $p->compound( 'na', '' );                           # (1) Cannot find compound 'na'
                                                           # (1) Cannot find compound ''
  $x = $p->compound( 'union na' );                         # (1) Cannot find union 'na'
  $x = $p->compound( 'struct na' );                        # (1) Cannot find struct 'na'
  $x = $p->compound( '__hasbf' );                          # no warning
  $x = $p->compound( 'test' );                             # no warning
  $x = $p->compound( 'struct __hasbf' );                   # (1) Cannot find struct '__hasbf'
  $x = $p->compound( 'union test' );                       # (1) Cannot find union 'test'
  $x = $p->compound( 'union __hasbf' );                    # no warning
  $x = $p->compound( 'struct test' );                      # no warning

  $p->struct_names;                                        # (1) Useless use of struct_names in void context
  $p->struct;                                              # (1) Useless use of struct in void context
  $x = $p->struct( 'na' );                                 # (1) Cannot find struct 'na'
  $x = $p->struct( 'union na' );                           # (1) Cannot find struct 'union na'
  $x = $p->struct( 'struct na' );                          # (1) Cannot find struct 'na'
  $x = $p->struct( '__hasbf' );                            # (1) Cannot find struct '__hasbf'
  $x = $p->struct( 'struct test' );                        # no warning

  $p->union_names;                                         # (1) Useless use of union_names in void context
  $p->union;                                               # (1) Useless use of union in void context
  $x = $p->union( 'na' );                                  # (1) Cannot find union 'na'
  $x = $p->union( 'union na' );                            # (1) Cannot find union 'na'
  $x = $p->union( 'struct na' );                           # (1) Cannot find union 'struct na'
  $x = $p->union( 'test' );                                # (1) Cannot find union 'test'
  $x = $p->union( 'union __hasbf' );                       # no warning

  $p->typedef_names;                                       # (1) Useless use of typedef_names in void context
  $p->typedef;                                             # (1) Useless use of typedef in void context
  @x = $p->typedef( 'na', '' );                            # (1) Cannot find typedef 'na'
                                                           # (1) Cannot find typedef ''

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

struct multiple {
  long       a;
  char       b;
  short      a;
  union {
    int      c;
    unsigned b;
  };
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

#endif

#else

#elif 1

#foobar

