################################################################################
#
# MODULE: Convert::Binary::C
#
################################################################################
#
# DESCRIPTION: Convert::Binary::C Perl extension module
#
################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2003/01/07 21:23:36 +0000 $
# $Revision: 33 $
# $Snapshot: /Convert-Binary-C/0.07 $
# $Source: /lib/Convert/Binary/C.pm $
#
################################################################################
# 
# Copyright (c) 2002-2003 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
# 
################################################################################

package Convert::Binary::C;

use strict;
use DynaLoader;
use Carp;
use vars qw( @ISA $VERSION $XS_VERSION $AUTOLOAD );

@ISA = qw(DynaLoader);

$VERSION    = sprintf '%.2f', 0.01*('$Revision: 33 $' =~ /(\d+)/)[0];
$XS_VERSION =  do { my @r = '$Snapshot: /Convert-Binary-C/0.07 $'
                            =~ /(\d+\.\d+(?:_\d+)?)/;
                    @r ? $r[0] : '9.99' },

bootstrap Convert::Binary::C $XS_VERSION;

# Unfortunately, XS AUTOLOAD isn't supported
# by stable perl distributions before 5.8.0.

sub AUTOLOAD
{
  my $self = shift;
  my $opt = $AUTOLOAD;
  ref $self or croak "$self is not an object";
  $opt =~ s/.*://;
  $opt =~ /^[A-Z]/ or croak "Invalid method $opt called";
  @_ <= 1 or croak "$opt cannot take more than one argument";
  unless( @_ or defined wantarray ) {
    carp "Useless use of $opt in void context";
    return;
  }
  $opt = eval { $self->configure( $opt, @_ ) };
  $@ =~ s/\s+at.*?C\.pm.*//s, croak $@ if $@;
  $opt;
}

1;

__END__

=head1 NAME

Convert::Binary::C - Binary Data Conversion using C Types

=head1 SYNOPSIS

=head2 Simple

  use Convert::Binary::C;
  
  #---------------------------------------------
  # Create a new object and parse embedded code
  #---------------------------------------------
  my $c = Convert::Binary::C->new->parse( <<ENDC );
  
  enum Month { JAN, FEB, MAR, APR, MAY, JUN,
               JUL, AUG, SEP, OCT, NOV, DEC };
  
  struct Date {
    int        year;
    enum Month month;
    int        day;
  };
  
  ENDC
  
  #-----------------------------------------------
  # Pack Perl data structure into a binary string
  #-----------------------------------------------
  my $date = { year => 2002, month => 'DEC', day => 24 };
  
  my $packed = $c->pack( 'Date', $date );

=head2 Advanced

  use Convert::Binary::C;
  use Data::Dumper;
  
  #---------------------
  # Create a new object
  #---------------------
  my $c = new Convert::Binary::C ByteOrder => 'BigEndian';
  
  #---------------------------------------------------
  # Add include paths and global preprocessor defines
  #---------------------------------------------------
  $c->Include( '/usr/lib/gcc-lib/i486-suse-linux/2.95.3/include',
               '/usr/include' )
    ->Define( qw( __USE_POSIX __USE_ISOC99=1 ) );
  
  #----------------------------------
  # Parse the 'time.h' header file
  #----------------------------------
  $c->parse_file( 'time.h' );
  
  #---------------------------------------
  # See which files the object depends on
  #---------------------------------------
  print Dumper( [keys %{$c->dependencies}] );
  
  #-----------------------------------------------------------
  # See if struct timespec is defined and dump its definition
  #-----------------------------------------------------------
  if( $c->def( 'struct timespec' ) ) {
    print Dumper( $c->struct( 'timespec' ) );
  }
  
  #-------------------------------
  # Create some binary dummy data
  #-------------------------------
  my $data = "binaryteststring";
  
  #--------------------------------------------------------
  # Unpack $data according to 'struct timespec' definition
  #--------------------------------------------------------
  if( length($data) >= $c->sizeof( 'timespec' ) ) {
    my $perl = $c->unpack( 'timespec', $data );
    print Dumper( $perl );
  }
  
  #--------------------------------------------------------
  # See which member lies at offset 5 of 'struct timespec'
  #--------------------------------------------------------
  my $member = $c->member( 'timespec', 5 );
  print "member( 'timespec', 5 ) = '$member'\n";

=head1 DESCRIPTION

Convert::Binary::C is a preprocessor and parser for C type
definitions. It is highly configurable and should support
arbitrarily complex data structures. Its object-oriented
interface has L<C<pack>|/"pack"> and L<C<unpack>|/"unpack"> methods
that act as replacements for
Perl's L<C<pack>|perlfunc/"pack"> and L<C<unpack>|perlfunc/"unpack"> and
allow to use the C types instead of a string representation
of the data structure for conversion of binary data from and
to Perl's complex data structures.

Actually, what Convert::Binary::C does is not very different
from what a C compiler does, just that it doesn't compile the
source code into an object file or executable, but only parses
the code and allows Perl to use the enumerations, structs, unions
and typedefs that have been defined within your C source for binary
data conversion, similar to
Perl's L<C<pack>|perlfunc/"pack"> and L<C<unpack>|perlfunc/"unpack">.

Beyond that, the module offers a lot of convenience methods
to retrieve information about the C types that have been parsed.

=head2 Background and History

In late 2000 I wrote a realtime debugging interface for an
embedded medical device that allowed me to send out data from
that device over its integrated ethernet adapter.
The interface was C<printf()>-like, so you could easily send
out strings or numbers. But you could also send out what I
called I<arbitrary data>, which was intended for arbitrary
blocks of the device's memory.

Another part of this realtime debugger was a Perl application
running on my workstation that gathered all the messages that
were sent out from the embedded device. It printed all the
strings an numbers, and hexdumped the arbitrary data.
However, manually parsing a couple of 300 byte hexdumps of a
complex C structure is not only frustrating, but also error-prone
and time consuming.

Using L<C<unpack>|perlfunc/"unpack"> to retrieve the contents
of a C structure works fine for small structures and if you
don't have to deal with struct member alignment. But otherwise,
maintaining such code can be as awful as deciphering hexdumps.

As I didn't find anything to solve my problem on the CPAN,
I wrote a little module that translated simple C structs
into L<C<unpack>|perlfunc/"unpack"> strings. It worked, but
it was slow. And since it couldn't deal with struct member
alignment, I soon found myself adding padding bytes everywhere.
So again, I had to maintain two sources, and changing one of
them forced me to touch the other one.

All in all, this little module seemed to make my task a bit
easier, but it was far from being what I was thinking of:

=over 2

=item *

A module that could directly use the source I've been coding
for the embedded device without any modifications.

=item *

A module that could be configured to match the properties 
of the different compilers and target platforms I was using.

=item *

A module that was fast enough to decode a great amount of
binary data even on my slow workstation.

=back

I didn't know how to accomplish these tasks until I read something
about XS. At least, it seemed as if it could solve my performance
problems. However, writing a C parser in C isn't easier than it is
in Perl. But writing a C preprocessor from scratch is even worse.

Fortunately enough, after a few weeks of searching I found both,
a lean, open-source C preprocessor library, and a reusable YACC
grammar for ANSI-C. That was the beginning of the development of
Convert::Binary::C in late 2001.

Now, I'm successfully using the module in my embedded environment
since long before it appeared on CPAN. From my point of view, it
is exactly what I had in mind. It's fast, flexible, easy to use
and portable. It doesn't require external programs or other Perl
modules.

=head2 About this document

This document describes how to use Convert::Binary::C. A lot of
different features are presented, and the example code sometimes
uses Perl's more advanced language elements. If your experience
with Perl is rather limited, you should know how to use Perl's
very good documentation system.

To look up one of the manpages, use the L<C<perldoc>|perldoc> command.
For example,

  perldoc perl

will show you Perl's main manpage. To look up a specific Perl
function, use C<perldoc -f>:

  perldoc -f map

gives you more information about the L<C<map>|perlfunc/"map"> function.
You can also search the FAQ using C<perldoc -q>:

  perldoc -q array

will give you everything you ever wanted to know about Perl
arrays. But now, let's go on with some real stuff!

=head2 Why Convert::Binary::C?

Say you want to pack (or unpack) data according to the following
C structure:

  struct foo {
    char ary[3];
    unsigned short baz;
    int bar;
  };

You could of course use
Perl's L<C<pack>|perlfunc/"pack"> and L<C<unpack>|perlfunc/"unpack"> functions:

  @ary = (1, 2, 3);
  $baz = 40000;
  $bar = -4711;
  $binary = pack 'c3 S i', @ary, $baz, $bar;

But this implies that the struct members are byte aligned. If
they were long aligned (which is the default for most compilers),
you'd have to write

  $binary = pack 'c3 x S x2 i', @ary, $baz, $bar;

which doesn't really increase readability.

Now imagine that you need to pack the data for a completely
different architecture with different byte order. You would
look into the L<C<pack>|perlfunc/"pack"> manpage again and
perhaps come up with this:

  $binary = pack 'c3 x n x2 N', @ary, $baz, $bar;

However, if you try to unpack C<$foo> again, your signed values
have turned into unsigned ones.

All this can still be managed with Perl. But imagine your
structures get more complex? Imagine you need to support
different platforms? Imagine you need to make changes to
the structures? You'll not only have to change the C source
but also dozens of L<C<pack>|perlfunc/"pack"> strings in
your Perl code. This is no fun. And Perl should be fun.

Now, wouldn't it be great if you could just read in the C
source you've already written and use all the types defined
there for packing and unpacking? That's what Convert::Binary::C
does.

=head2 Creating a Convert::Binary::C object

To use Convert::Binary::C just say

  use Convert::Binary::C;

to load the module. Its interface is completely object
oriented, so it doesn't export any functions.

Next, you need to create a new Convert::Binary::C object. This
can be done by either

  $c = Convert::Binary::C->new;

or

  $c = new Convert::Binary::C;

You can optionally pass configuration options to
the L<constructor|/"new"> as described in the next section.

=head2 Configuring the object

To configure a Convert::Binary::C object, you can either call
the L<C<configure>|/"configure"> method or directly pass the configuration
options to the L<constructor|/"new">. If you want to change byte order
and alignment, you can use

  $c->configure( ByteOrder => 'LittleEndian',
                 Alignment => 2 );

or you can change the construction code to

  $c = new Convert::Binary::C ByteOrder => 'LittleEndian',
                              Alignment => 2;

Either way, the object will now know that it should use
little endian (Intel) byte order and 2-byte struct member
alignment for packing and unpacking.

Alternatively, you can use the option names as names of
methods to configure the object, like:

  $c->ByteOrder( 'LittleEndian' );

You can also retrieve information about the current
configuration of a Convert::Binary::C object. For details,
see the section about the L<C<configure>|/"configure"> method.

=head2 Parsing C code

Convert::Binary::C allows two ways of parsing C source. Either
by parsing external C header or C source files:

  $c->parse_file( 'header.h' );

Or by parsing C code embedded in your script:

  $c->parse( <<'CCODE' );
  struct foo {
    char ary[3];
    unsigned short baz;
    int bar;
  };
  CCODE

Now the object C<$c> will know everything about C<struct foo>.
The example above uses a so-called here-document. It allows to
easily embed multiline strings in your code. You can find more
about here-documents in L<perldata> or L<perlop>.

Since the L<C<parse>|/"parse"> and L<C<parse_file>|/"parse_file"> methods
throw an exception when a parse error occurs, you usually want to catch
these in an C<eval> block:

  eval { $c->parse_file('header.h') };
  if( $@ ) {
    # do something appropriate
  }

Perl's special C<$@> variable will contain an empty string (which
evaluates to a false value in boolean context) on success or
an error string on failure.

As another feature, L<C<parse>|/"parse"> and L<C<parse_file>|/"parse_file"> return
a reference to their object on success, just like L<C<configure>|/"configure"> does
when you're configuring the object. This will allow you to write constructs
like this:

  my $c = eval {
    Convert::Binary::C->new( Include => ['/usr/include'] )
                      ->parse_file( 'header.h' )
  };
  if( $@ ) {
    # do something appropriate
  }

=head2 Packing and unpacking

Convert::Binary::C has two methods, L<C<pack>|/"pack"> and L<C<unpack>|/"unpack">,
that act similar to the functions of same denominator in Perl.
To perform the packing described in the example above,
you could write:

  $data = {
    ary => [1, 2, 3],
    baz => 40000,
    bar => -4711,
  };
  $binary = $c->pack( 'foo', $data );

Unpacking will work exactly the same way, just that
the L<C<unpack>|/"unpack"> method will take a byte string as its input
and will return a reference to a (possibly very complex)
Perl data structure.

  $binary = from_memory();
  $data = $c->unpack( 'foo', $binary );

You can now easily access all of the values:

  print "foo.ary[1] = $data->{ary}[1]\n";

Or you can even more conveniently use
the L<Data::Dumper|Data::Dumper> module:

  use Data::Dumper;
  print Dumper( $data );

The output would look something like this:

  $VAR1 = {
    'bar' => -271,
    'baz' => 5000,
    'ary' => [
      42,
      48,
      100
    ]
  };

=head2 Preprocessor configuration

Convert::Binary::C uses Thomas Pornin's C<ucpp> as an internal
C preprocessor. It is compliant to ISO-C99, so you don't have
to worry about using even weird preprocessor constructs in
your code.

If your C source contains includes or depends upon preprocessor
defines, you may need to configure the internal preprocessor.
Use the C<Include> and C<Define> configuration options for that:

  $c->configure( Include => ['/usr/include',
                             '/home/mhx/include'],
                 Define  => [qw( NDEBUG FOO=42 )] );

If your code uses system includes, it is most likely
that you will need to define the symbols that are usually
defined by the compiler.

On some operating systems, the system includes require the
preprocessor to predefine a certain set of assertions.
Assertions are supported by C<ucpp>, and you can define them
either in the source code using C<#assert> or as a property
of the Convert::Binary::C object using C<Assert>:

  $c->configure( Assert => ['predicate(answer)'] );

=head2 Supported pragma directives

Convert::Binary::C supports the C<pack> pragma to locally override
struct member alignment. The supported syntax is as follows:

=over 4

=item #pragma pack( ALIGN )

Sets the new alignment to ALIGN.

=item #pragma pack

Resets the alignment to its original value.

=item #pragma pack( push, ALIGN )

Saves the current alignment on a stack and sets the new
alignment to ALIGN.

=item #pragma pack( pop )

Restores the alignment to the last value saved on the
stack.

=back

  /*  Example assumes sizeof( short ) == 2, sizeof( long ) == 4.  */
  
  #pragma pack(1)
  
  struct nopad {
    char a;               /* no padding bytes between 'a' and 'b' */
    long b;
  };
  
  #pragma pack            /* reset to "native" alignment          */
  
  #pragma pack( push, 2 )
  
  struct pad {
    char    a;            /* one padding byte between 'a' and 'b' */
    long    b;
  
  #pragma pack( push, 1 )
  
    struct {
      char  c;            /* no padding between 'c' and 'd'       */
      short d;
    }       e;            /* sizeof( e ) == 3                     */
  
  #pragma pack( pop );    /* back to pack( 2 )                    */
  
    long    f;            /* one padding byte between 'e' and 'f' */
  };
  
  #pragma pack( pop );    /* back to "native"                     */

The C<pack> pragma as it is currently implemented only affects
the I<maximum> struct member alignment. There are compilers
that also allow to specify the I<minimum> struct member
alignment. This is not supported by Convert::Binary::C.

=head2 Automatic configuration using C<ccconfig>

As there are over 20 different configuration options, setting
all of them correctly can be a lengthy and tedious task.

The L<C<ccconfig>|ccconfig> script, which is bundled with this
module, aims at automatically determining the correct compiler
configuration by testing the compiler executable. It works for
both, native and cross compilers.

=head1 METHODS

=head2 new

=over 8

=item C<new>

=item C<new> OPTION1 =E<gt> VALUE1, OPTION2 =E<gt> VALUE2, ...

The constructor is used to create a new Convert::Binary::C object.
You can simply use

  $c = new Convert::Binary::C;

without additional arguments to create an object, or you can
optionally pass any arguments to the constructor that are
described for the L<C<configure>|/"configure"> method.

=back

=head2 configure

=over 8

=item C<configure>

=item C<configure> OPTION

=item C<configure> OPTION1 =E<gt> VALUE1, OPTION2 =E<gt> VALUE2, ...

This method can be used to configure an existing Convert::Binary::C
object or to retrieve its current configuration.

To configure the object, the list of options consists of key
and value pairs and must therefore contain an even number of
elements. L<C<configure>|/"configure"> (and also L<C<new>|/"new"> if
used with configuration options) will throw an exception if you
pass an odd number of elements. Configuration will normally look
like this:

  $c->configure( ByteOrder => 'BigEndian', IntSize => 2 );

To retrieve the current value of a configuration option, you
must pass a single argument to L<C<configure>|/"configure"> that
holds the name of the option, just like

  $order = $c->configure( 'ByteOrder' );

If you want to get the values of all configuration options at
once, you can call L<C<configure>|/"configure"> without any
arguments and it will return a reference to a hash table that
holds the whole object configuration. This can be conveniently
used with the L<Data::Dumper|Data::Dumper> module, for example:

  use Convert::Binary::C;
  use Data::Dumper;
  
  $c = new Convert::Binary::C Define  => ['DEBUGGING', 'FOO=123'],
                              Include => ['/usr/include'];
  
  print Dumper( $c->configure );

This will print something like this:

  $VAR1 = {
    'Define' => [
      'DEBUGGING',
      'FOO=123'
    ],
    'ByteOrder' => 'LittleEndian',
    'LongSize' => 4,
    'IntSize' => 4,
    'ShortSize' => 2,
    'HasMacroVAARGS' => 1,
    'Assert' => [],
    'UnsignedChars' => 0,
    'DoubleSize' => 8,
    'EnumType' => 'Integer',
    'PointerSize' => 4,
    'EnumSize' => 4,
    'DisabledKeywords' => [],
    'FloatSize' => 4,
    'LongLongSize' => 8,
    'Alignment' => 1,
    'LongDoubleSize' => 12,
    'KeywordMap' => {},
    'HasCPPComments' => 1,
    'Include' => [
      '/usr/include'
    ],
    'Warnings' => 0
  };

Since you may not always want to write a L<C<configure>|/"configure"> call
when you only want to change a single configuration item, you can
use any configuration option name as a method name, like:

  $c->ByteOrder( 'LittleEndian' ) if $c->IntSize < 4;

(Yes, the example doesn't make very much sense... ;-)

However, you should keep in mind that configuration methods
that can take lists (namely C<Include>, C<Define> and C<Assert>,
but not C<DisabledKeywords>) may behave slightly different than
their L<C<configure>|/"configure"> equivalent.
If you pass these methods a single argument that is an array
reference, the current list will be B<replaced> by the new one,
which is just the behaviour of the
corresponding L<C<configure>|/"configure"> call.
So the following are equivalent:

  $c->configure( Define => ['foo', 'bar=123'] );
  $c->Define( ['foo', 'bar=123'] );

But if you pass a list of strings instead of an array reference
(which cannot be done when using L<C<configure>|/"configure">),
the new list items are B<appended> to the current list, so

  $c = new Convert::Binary::C Include => ['/include'];
  $c->Include( '/usr/include', '/usr/local/include' );
  print Dumper( $c->Include );
  
  $c->Include( ['/usr/local/include'] );
  print Dumper( $c->Include );

will first print all three include paths, but finally
only C</usr/local/include> will be configured:

  $VAR1 = [
    '/include',
    '/usr/include',
    '/usr/local/include'
  ];
  $VAR1 = [
    '/usr/local/include'
  ];

Furthermore, configuration methods can be chained together,
as they return a reference to their object if called as a
set method. So, if you like, you can configure your object
like this:

  $c = Convert::Binary::C->new( IntSize => 4 )
         ->Define( qw( __DEBUG__ DB_LEVEL=3 ) )
         ->ByteOrder( 'BigEndian' );
  
  $c->configure( EnumType => 'Both', Alignment => 4 )
    ->Include( '/usr/include', '/usr/local/include' );

In the example above, C<qw( ... )> is the word list quoting
operator. It returns a list of all non-whitespace sequences,
and is especially useful for configuring preprocessor defines
or assertions. The following assignments are equivalent:

  @array = ('one', 'two', 'three');
  @array = qw(one two three);

You can configure the following options. Unknown options, as well
as invalid values for an option, will cause the object to throw
exceptions.

=over 4

=item C<IntSize> =E<gt> 0 | 1 | 2 | 4 | 8

Set the number of bytes that are occupied by an integer. This is
in most cases 2 or 4. If you set it to zero, the size of an
integer on the host system will be used. This is also the
default.

=item C<ShortSize> =E<gt> 0 | 1 | 2 | 4 | 8

Set the number of bytes that are occupied by a short integer.
Although integers explicitly declared as C<short> should be
always 16 bit, there are compilers that make a short
8 bit wide. If you set it to zero, the size of a short
integer on the host system will be used. This is also the
default.

=item C<LongSize> =E<gt> 0 | 1 | 2 | 4 | 8

Set the number of bytes that are occupied by a long integer.
If set to zero, the size of a long integer on the host system
will be used. This is also the default.

=item C<LongLongSize> =E<gt> 0 | 1 | 2 | 4 | 8

Set the number of bytes that are occupied by a long long
integer. If set to zero, the size of a long long integer
on the host system, or 8, will be used. This is also the
default.

=item C<FloatSize> =E<gt> 0 | 1 | 2 | 4 | 8 | 12 | 16

Set the number of bytes that are occupied by a single
precision floating point value.
If you set it to zero, the size of a C<float> on the
host system will be used. This is also the default.
Values can only be packed and unpacked if the size
matches the native size of a C<float>.

=item C<DoubleSize> =E<gt> 0 | 1 | 2 | 4 | 8 | 12 | 16

Set the number of bytes that are occupied by a double
precision floating point value.
If you set it to zero, the size of a C<double> on the
host system will be used. This is also the default.
Values can only be packed and unpacked if the size
matches the native size of a C<double>.

=item C<LongDoubleSize> =E<gt> 0 | 1 | 2 | 4 | 8 | 12 | 16

Set the number of bytes that are occupied by a double
precision floating point value.
If you set it to zero, the size of a C<long double> on
the host system, or 12 will be used. This is also the
default. Values can only be packed and unpacked if the
size matches the native size of a C<long double>.

=item C<PointerSize> =E<gt> 0 | 1 | 2 | 4 | 8

Set the number of bytes that are occupied by a pointer. This is
in most cases 2 or 4. If you set it to zero, the size of a
pointer on the host system will be used. This is also the
default.

=item C<EnumSize> =E<gt> -1 | 0 | 1 | 2 | 4 | 8

Set the number of bytes that are occupied by an enumeration type.
On most systems, this is equal to the size of an integer,
which is also the default. However, for some compilers, the
size of an enumeration type depends on the size occupied by the
largest enumerator. So the size may vary between 1 and 8. If you
have

  enum foo {
    ONE = 100, TWO = 200
  };

this will occupy one byte because the enum can be represented
as an unsigned one-byte value. However,

  enum foo {
    ONE = -100, TWO = 200
  };

will occupy two bytes, because the -100 forces the type to
be signed, and 200 doesn't fit into a signed one-byte value.
Therefore, the type used is a signed two-byte value.
If this is the behaviour you need, set the EnumSize to C<0>.

Some compilers try to follow this strategy, but don't care
whether the enumeration has signed values or not. They always
declare an enum as signed. On such a compiler, given

  enum one { ONE = -100, TWO = 100 };
  enum two { ONE =  100, TWO = 200 };

enum C<one> will occupy only one byte, while enum C<two>
will occupy two bytes, even though it could be represented
by a unsigned one-byte value. If this is the behaviour of
your compiler, set EnumSize to C<-1>.

=item C<Alignment> =E<gt> 1 | 2 | 4 | 8 | 16

Set the struct member alignment. This option controls where
padding bytes are inserted between struct members. It globally
sets the alignment for all structs/unions. However, this can
be overridden from within the source code with the
common C<pack> pragma as explained in L<"Supported pragma directives">.
The default alignment is 1, which means no padding bytes are
inserted.

The C<Alignment> option is similar to the C<-Zp[n]> option
of the Intel compiler. It globally specifies the maximum
boundary to which struct members are aligned. Consider the
following structure and the sizes
of C<char>, C<short>, C<long> and C<double> being 1, 2, 4
and 8, respectively.

  struct align {
    char   a;
    short  b, c;
    long   d;
    double e;
  };

With an alignment of 1 (the default), the struct members would
be packed tightly:

  0   1   2   3   4   5   6   7   8   9  10  11  12
  +---+---+---+---+---+---+---+---+---+---+---+---+
  | a |   b   |   c   |       d       |             ...
  +---+---+---+---+---+---+---+---+---+---+---+---+
  
     12  13  14  15  16  17
      +---+---+---+---+---+
  ...     e               |
      +---+---+---+---+---+

With an alignment of 2, the struct members larger than one byte
would be aligned to 2-byte boundaries, which results in a single
padding byte between C<a> and C<b>.

  0   1   2   3   4   5   6   7   8   9  10  11  12
  +---+---+---+---+---+---+---+---+---+---+---+---+
  | a | * |   b   |   c   |       d       |         ...
  +---+---+---+---+---+---+---+---+---+---+---+---+
  
     12  13  14  15  16  17  18
      +---+---+---+---+---+---+
  ...         e               |
      +---+---+---+---+---+---+

With an alignment of 4, the struct members of size 2 would be
aligned to 2-byte boundaries and larger struct members would
be aligned to 4-byte boundaries:

  0   1   2   3   4   5   6   7   8   9  10  11  12
  +---+---+---+---+---+---+---+---+---+---+---+---+
  | a | * |   b   |   c   | * | * |       d       | ...
  +---+---+---+---+---+---+---+---+---+---+---+---+
  
     12  13  14  15  16  17  18  19  20
      +---+---+---+---+---+---+---+---+
  ... |               e               |
      +---+---+---+---+---+---+---+---+

This layout of the struct members allows the compiler to generate
optimized code because aligned members can be accessed more easily
by the underlying architecture.

Finally, setting the alignment to 8 will align C<double>s to
8-byte boundaries:

  0   1   2   3   4   5   6   7   8   9  10  11  12
  +---+---+---+---+---+---+---+---+---+---+---+---+
  | a | * |   b   |   c   | * | * |       d       | ...
  +---+---+---+---+---+---+---+---+---+---+---+---+
  
     12  13  14  15  16  17  18  19  20  21  22  23  24
      +---+---+---+---+---+---+---+---+---+---+---+---+
  ... | * | * | * | * |               e               |
      +---+---+---+---+---+---+---+---+---+---+---+---+

Further increasing the alignment does not alter the layout of
our structure, as only members larger that 8 bytes would be
affected.

The alignment of a structure depends on its largest member and
on the setting of the C<Alignment> option. With C<Alignment> set
to 2, a structure holding a C<long> would be aligned to a 2-byte
boundary, while a structure containing only C<char>s would have
no alignment restrictions.

Here's another example. Assuming 8-byte alignment, the following
two structs will both have a size of 16 bytes:

  struct one {
    char   c;
    double d;
  };
  
  struct two {
    double d;
    char   c;
  };

This is clear for C<struct one>, because the member C<d> has to
be aligned to an 8-byte boundary, and thus 7 padding bytes are
inserted after C<c>. But for C<struct two>, the padding bytes
are inserted I<at the end> of the structure, which doesn't make
much sense immediately. However, it makes perfect sense if you
think about an array of C<struct two>. Each C<double> has to be
aligned to an 8-byte boundary, an thus each array element would
have to occupy 16 bytes. With that in mind, it would be strange
if a C<struct two> variable would have a different size. And it
would make the widely used construct

  struct two array[] = { {1.0, 0}, {2.0, 1} };
  int elements = sizeof(array) / sizeof(struct two);

impossible.

The alignment behaviour described here seems to be common for all
compilers. However, not all compilers have an option to configure
their default alignment.

=item C<ByteOrder> =E<gt> 'BigEndian' | 'LittleEndian'

Set the byte order for integers larger than a single byte.
Little endian (Intel, least significant byte first) and
big endian (Motorola, most significant byte first) byte
order are supported. The default byte order is the same as
the byte order of the host system.

=item C<EnumType> =E<gt> 'Integer' | 'String' | 'Both'

This option controls the type that enumeration constants
will have in data structures returned by the L<C<unpack>|/"unpack"> method.
If you have the following definitions:

  typedef enum {
    SUNDAY, MONDAY, TUESDAY, WEDNESDAY,
    THURSDAY, FRIDAY, SATURDAY
  } Weekday;
   
  typedef enum {
    JANUARY, FEBRUARY, MARCH, APRIL, MAY, JUNE, JULY,
    AUGUST, SEPTEMBER, OCTOBER, NOVEMBER, DECEMBER
  } Month;
   
  typedef struct {
    int     year;
    Month   month;
    int     day;
    Weekday weekday;
  } Date;

and a byte string that holds a packed Date struct,
then you'll get the following results from a call
to the L<C<unpack>|/"unpack"> method.

=over 4

=item C<Integer>

Enumeration constants are returned as plain integers. This
is fast, but may be not very useful. It is also the default.

  $date = {
    'weekday' => 1,
    'month' => 0,
    'day' => 7,
    'year' => 2002
  };

=item C<String>

Enumeration constants are returned as strings. This will
create a string constant for every unpacked enumeration
constant and thus consumes more time and memory. However,
the result may be more useful.

  $date = {
    'weekday' => 'MONDAY',
    'month' => 'JANUARY',
    'day' => 7,
    'year' => 2002
  };

=item C<Both>

Enumeration constants are returned as double typed scalars.
If evaluated in string context, the enumeration constant
will be a string, if evaluated in numeric context, the
enumeration constant will be an integer.

  $date = $c->EnumType('Both')->unpack('Date', $binary);
  
  printf "Weekday = %s (%d)\n\n", $date->{weekday},
                                  $date->{weekday};
  
  if( $date->{month} == 0 ) {
    print "It's $date->{month}, happy new year!\n\n";
  }
  
  print Dumper( $date );

This will print:

  Weekday = MONDAY (1)
  
  It's JANUARY, happy new year!
  
  $VAR1 = {
    'weekday' => 'MONDAY',
    'month' => 'JANUARY',
    'day' => 7,
    'year' => 2002
  };

=back

=item C<DisabledKeywords> =E<gt> [ KEYWORDS ]

This option allows you to selectively deactivate certain
keywords in the C parser. Some C compilers don't have
the complete ANSI keyword set, i.e. they don't recognize
the keywords C<const> or C<void>, for example. If you do

  typedef int void;

on such a compiler, this will usually be ok. But if you
parse this with an ANSI compiler, it will be a syntax
error. To parse the above code correctly, you have to
disable the C<void> keyword in the Convert::Binary::C
parser:

  $c->DisabledKeywords( [qw( void )] );

If Convert::Binary::C is built with the C99 feature
enabled (which is the default), the parser will recognize
the keywords C<inline> and C<restrict>. If your compiler
doesn't have these new keywords, it usually doesn't matter.
Only if you're using the keywords as identifiers, like in

  typedef struct inline {
    int a, b;
  } restrict;

you'll have to disable the ANSI-C99 keywords:

  $c->DisabledKeywords( [qw( inline restrict )] );

The parser allows you to disable the following keywords:

  auto
  const
  double
  enum
  extern
  float
  inline
  long
  register
  restrict
  short
  signed
  static
  unsigned
  void
  volatile

=item C<KeywordMap> =E<gt> { KEYWORD =E<gt> TOKEN, ... }

This option allows you to add new keywords to the parser.
These new keywords can either be mapped to existing tokens
or simply ignored. For example, recent versions of the GNU
compiler recognize the keywords C<__signed__> and C<__extension__>.
The first one obviously is a synonym for C<signed>, while
the second one is only a marker for a language extension.

Using the preprocessor, you could of course do the following:

  $c->Define( qw( __signed__=signed __extension__= ) );

However, the preprocessor symbols could be undefined or
redefined in the code, and

  #ifdef __signed__
  # undef __signed__
  #endif
  
  typedef __extension__ __signed__ long long s_quad;

would generate a parse error, because C<__signed__> is an
unexpected identifier.

Instead of utilizing the preprocessor, you'll have to create
mappings for the new keywords directly in the parser
using C<KeywordMap>. In the above example, you want to
map C<__signed__> to the builtin C keyword C<signed> and
ignore C<__extension__>. This could be done with the following
code:

  $c->KeywordMap( {
                    __signed__    => 'signed',
                    __extension__ => undef,
                  } );

You can specify any valid identifier as hash key, and either
a valid C keyword or C<undef> as hash value.  
Having configured the object that way, you could parse even

  #ifdef __signed__
  # undef __signed__
  #endif
  
  typedef __extension__ __signed__ long long s_quad;

without problems.

Note that C<KeywordMap> and C<DisabledKeywords> perfectly work
together. You could, for example, disable the C<signed> keyword,
but still have C<__signed__> mapped to the original C<signed> token:

  $c->configure( DisabledKeywords => [ 'signed' ],
                 KeywordMap       => { __signed__  => 'signed' } );

This would allow you to define

  typedef __signed__ long signed;

which would normally be a syntax error because C<signed> cannot
be used as an identifier.

=item C<UnsignedChars> =E<gt> 0 | 1

Use this boolean option if you want characters
to be unsigned if specified without an
explicit C<signed> or C<unsigned> type specifier.
By default, characters are signed.

=item C<Warnings> =E<gt> 0 | 1

Use this boolean option if you want warnings to be issued
during the parsing of source code. Currently, warnings
are only reported by the preprocessor, so don't expect
the output to cover everything.

By default, warnings are turned off and only errors will be
reported. However, even these errors are turned off if
you run without the C<-w> flag.

=item C<HasCPPComments> =E<gt> 0 | 1

Use this option to turn C++ comments on or off. By default,
C++ comments are enabled. Disabling C++ comments may be
necessary if your code includes strange things like:

  one = 4 //* <- divide */ 4;
  two = 2;

With C++ comments, the above will be interpreted as

  one = 4
  two = 2;

which will obviously be a syntax error, but without
C++ comments, it will be interpreted as

  one = 4 / 4;
  two = 2;

which is correct.

=item C<HasMacroVAARGS> =E<gt> 0 | 1

Use this option to turn the C<__VA_ARGS__> macro expansion
on or off. If this is enabled (which is the default), you can use
variable length argument lists in your preprocessor macros.

  #define DEBUG( ... )  fprintf( stderr, __VA_ARGS__ )

There's normally no reason to turn that feature off.

=item C<Include> =E<gt> [ INCLUDES ]

Use this option to set the include path for the internal
preprocessor. The option value is a reference to an array
of strings, each string holding a directory that should
be searched for includes.

=item C<Define> =E<gt> [ DEFINES ]

Use this option to define symbols in the preprocessor.
The option value is, again, a reference to an array of
strings. Each string can be either just a symbol or an
assignment to a symbol. This is completely equivalent
to what the C<-D> option does for most preprocessors.

The following will define the symbol C<FOO> and
define C<BAR> to be C<12345>:

  $c->configure( Define => [qw(FOO BAR=12345)] );

=item C<Assert> =E<gt> [ ASSERTIONS ]

Use this option to make assertions in the preprocessor.
If you don't know what assertions are, don't be
concerned, since they're deprecated anyway. They
are, however, used in some system's include files.
The value is an array reference, just like for the
macro definitions. Only the way the assertions are
defined is a bit different and mimics the way they
are defined with the C<#assert> directive:

  $c->configure( Assert => ['foo(bar)'] );

=back

You can reconfigure all options even after you have
parsed some code. The changes will be applied to the
already parsed definitions. This works as long as array
lengths are not affected by the changes. If you have
Alignment and IntSize set to 4 and parse code like
this

  typedef struct {
    char abc;
    int  day;
  } foo;
  
  struct bar {
    foo  zap[2*sizeof(foo)];
  };

the array C<zap> in C<struct bar> will obviously have
16 elements. If you reconfigure the alignment to 1 now,
the size of C<foo> is now 5 instead of 8. While the
alignment is adjusted correctly, the number of elements
in array C<zap> will still be 16 and will not be changed
to 10.

=back

=head2 parse

=over 8

=item C<parse> CODE

Parses a string of valid C code. All enumeration, compound
and type definitions are extracted. You can call
the L<C<parse>|/"parse"> and L<C<parse_file>|/"parse_file"> methods
as often as you like to add further definitions to the
Convert::Binary::C object.

L<C<parse>|/"parse"> will throw an exception if an error occurs.
On success, the method returns a reference to its object.

See L<"Parsing C code"> for an example.

=back

=head2 parse_file

=over 8

=item C<parse_file> FILE

Parses a C source file. All enumeration, compound and type
definitions are extracted. You can call
the L<C<parse>|/"parse"> and L<C<parse_file>|/"parse_file"> methods
as often as you like to add further definitions to the
Convert::Binary::C object.

L<C<parse_file>|/"parse_file"> will throw an exception if an error
occurs. On success, the method returns a reference to its object.

See L<"Parsing C code"> for an example.

You must be aware that the preprocessor is reset with every call
to L<C<parse>|/"parse"> or L<C<parse_file>|/"parse_file">.
Also, you may use types previously defined, but you are not allowed
to redefine types.

When you're parsing C source files instead of C header
files, note that local definitions are ignored. This means
that type definitions hidden within functions will not be
recognized by Convert::Binary::C. This is necessary
because different functions (even different blocks within
the same function) can define types with the same name:

  void my_func( int i )
  {
    if( i < 10 ) {
      enum digit { ONE, TWO, THREE } x = ONE;
      printf("%d, %d\n", i, x);
    }
    else {
      enum digit { THREE, TWO, ONE } x = ONE;
      printf("%d, %d\n", i, x);
    }
  }

The above is a valid piece of C code, but it's not possible
for Convert::Binary::C to distinguish between the different
definitions of C<enum digit>, as they're only defined
locally within the corresponding block.

=back

=head2 clean

=over 8

=item C<clean>

Clears all information that has been collected during previous
calls to L<C<parse>|/"parse"> or L<C<parse_file>|/"parse_file">.
You can use this method if you want to parse some entirely
different code, but with the same configuration.

The L<C<clean>|/"clean"> method returns a reference to its object.

=back

=head2 clone

=over 8

=item C<clone>

Makes the object return an exact independent copy of itself.

  $c = new Convert::Binary::C Include => ['/usr/include'];
  $c->parse_file( 'definitions.c' );
  $clone = $c->clone;

The above code is technically equivalent (Mostly. Actually,
using L<C<sourcify>|/"sourcify"> and L<C<parse>|/"parse"> might alter
the order of the parsed data, which would make methods such
as L<C<compound>|/"compound"> return the definitions in a different
order.) to:

  $c = new Convert::Binary::C Include => ['/usr/include'];
  $c->parse_file( 'definitions.c' );
  $clone = new Convert::Binary::C %{$c->configure};
  $clone->parse( $c->sourcify );

Using L<C<clone>|/"clone"> is just a lot faster.

=back

=head2 def

=over 8

=item C<def> TYPE

If you need to know if a definition for a certain type
exists, use this method. You pass it the name of an enum,
struct, union or typedef, and it will return a non-empty
string being either C<"enum">, C<"struct">, C<"union">,
or C<"typedef"> if there's a definition for the type in
question, an empty string if there's no such definition,
or C<undef> if the name is completely unknown.

  use Convert::Binary::C;
  
  my $c = Convert::Binary::C->new->parse( <<'ENDC' );
  
  typedef struct __not  not;
  typedef struct __not *ptr;
  
  struct foo {
    enum bar *xxx;
  };
  
  ENDC
  
  for my $type ( qw( not ptr foo bar xxx ) ) {
    my $def = $c->def( $type );
    printf "\$c->def( '$type' )  =>  %s\n",
           defined $def ? "'$def'" : 'undef';
  }

The following would be returned by the L<C<def>|/"def"> method:

  $c->def( 'not' )  =>  ''
  $c->def( 'ptr' )  =>  'typedef'
  $c->def( 'foo' )  =>  'struct'
  $c->def( 'bar' )  =>  ''
  $c->def( 'xxx' )  =>  undef

So, if L<C<def>|/"def"> returns a non-empty string, you can safely use
any other method with that type's name.

In cases where the typedef namespace overlaps with the
namespace of enums/structs/unions, the L<C<def>|/"def"> method
will give preference to the typedef and will thus return
the string C<"typedef">.

=back

=head2 pack

=over 8

=item C<pack> TYPE, DATA

=item C<pack> TYPE, DATA, STRING

Use this method to pack a complex data structure into a
binary string according to a type definition that has been
previously parsed. DATA must be a scalar matching the
type definition. C structures and unions are represented
by references to Perl hashes, C arrays by references to
Perl arrays.

  use Convert::Binary::C;
  use Data::Dumper;
  use Data::Hexdumper;
  
  $c = Convert::Binary::C->new( ByteOrder => 'BigEndian',
                                LongSize  => 4,
                                ShortSize => 2 )
                         ->parse( <<'ENDC' );
  struct test {
    char    ary[3];
    union {
      short word[2];
      long  quad;
    }       uni;
  };
  ENDC

Hashes don't have to contain a key for each compound member
and arrays may be truncated:

  $binary = $c->pack( 'test', { ary => [1, 2], uni => { quad => 42 } } );

Elements not defined in the Perl data structure will be
set to zero in the packed byte string. On success, the
packed byte string is returned.

  print hexdump( data => $binary );

The above code would print:

    0x0000 : 01 02 00 00 00 00 2A                            : ......*

You could also use L<C<unpack>|/"unpack"> and dump the data structure.

  $unpacked = $c->unpack( 'test', $binary );
  print Data::Dumper->Dump( [$unpacked], ['unpacked'] );

This would print:

  $unpacked = {
    'uni' => {
      'word' => [
        0,
        42
      ],
      'quad' => 42
    },
    'ary' => [
      1,
      2,
      0
    ]
  };

If TYPE refers to a compound object, you may pack any
member of that compound object. Simply add a member string
to the type name, just as you would access the member in
C:

  $array = $c->pack( 'test.ary', [1, 2, 3] );
  print hexdump( data => $array );
  
  $value = $c->pack( 'test.uni.word[1]', 2 );
  print hexdump( data => $value );

This would give you:

    0x0000 : 01 02 03                                        : ...
    0x0000 : 00 02                                           : ..

Call L<C<pack>|/"pack"> with the optional STRING argument if you want
to use an existing binary string to insert the data.
If called in a void context, L<C<pack>|/"pack"> will directly
modify the string you passed as the third argument.
Otherwise, a copy of the string is created, and L<C<pack>|/"pack"> will
modify and return the copy, so the original string
will remain unchanged.

The 3-argument version may be useful if you want to change
only a few members of a complex data structure without
having to L<C<unpack>|/"unpack"> everything, change the members, and
then L<C<pack>|/"pack"> again (which could waste lots of memory
and CPU cycles). So, instead of doing something like

  $test = $c->unpack( 'test', $binary );
  $test->{uni}{quad} = 4711;
  $new = $c->pack( 'test', $test );

to change the C<uni.quad> member of C<$packed>, you
could simply do either

  $new = $c->pack( 'test', { uni => { quad => 4711 } }, $binary );

or

  $c->pack( 'test', { uni => { quad => 4711 } }, $binary );

while the latter would directly modify C<$packed>.
Besides this code being a lot shorter (and perhaps even
more readable), it can be significantly faster if you're
dealing with really big data blocks.

If the length of the input string is less than the size
required by the type, the string (or its copy) is
extended and the extended part is initialized to zero.
If the length is more than the size required by the type,
the string is kept at that length, and also a copy would
be an exact copy of that string.

  $too_short = pack "C*", (1 .. 4);
  $too_long  = pack "C*", (1 .. 20);
  
  $c->pack( 'test', { uni => { quad => 0x4711 } }, $too_short );
  print "too_short:\n", hexdump( data => $too_short );
  
  $copy = $c->pack( 'test', { uni => { quad => 0x4711 } }, $too_long );
  print "\ncopy:\n", hexdump( data => $copy );

This would print:

  too_short:
    0x0000 : 01 02 03 00 00 47 11                            : .....G.
  
  copy:
    0x0000 : 01 02 03 00 00 47 11 08 09 0A 0B 0C 0D 0E 0F 10 : .....G..........
    0x0010 : 11 12 13 14                                     : ....

=back

=head2 unpack

=over 8

=item C<unpack> TYPE, STRING

Use this method to unpack a binary string and create an
arbitrarily complex Perl data structure based on a
previously parsed type definition.

  use Convert::Binary::C;
  use Data::Dumper;
  
  $c = Convert::Binary::C->new( ByteOrder => 'BigEndian',
                                LongSize  => 4,
                                ShortSize => 2 )
                         ->parse( <<'ENDC' );
  struct test {
    char    ary[3];
    union {
      short word[2];
      long  quad;
    }       uni;
  };
  ENDC
  
  # Generate some binary dummy data
  $binary = pack "C*", (1 .. $c->sizeof('test'));

On failure, e.g. if the specified type cannot be found, the
method will throw an exception. On success, a reference to
a complex Perl data structure is returned, which can directly
be dumped using the L<Data::Dumper|Data::Dumper> module:

  $unpacked = $c->unpack( 'test', $binary );
  print Dumper( $unpacked );

This would print:

  $VAR1 = {
    'uni' => {
      'word' => [
        1029,
        1543
      ],
      'quad' => 67438087
    },
    'ary' => [
      1,
      2,
      3
    ]
  };

If TYPE refers to a compound object, you may unpack any
member of that compound object. Simply add a member string
to the type name, just as you would access the member in
C:

  $binary2 = substr $binary, $c->offsetof('test', 'uni.word');
  
  $unpack1 = $unpacked->{uni}{word};
  $unpack2 = $c->unpack( 'test.uni.word', $binary2 );
  
  print Data::Dumper->Dump( [$unpack1, $unpack2], [qw(unpack1 unpack2)] );

You will find that the output is exactly the same for
both C<$unpack1> and C<$unpack2>:

  $unpack1 = [
    1029,
    1543
  ];
  $unpack2 = [
    1029,
    1543
  ];

=back

=head2 sizeof

=over 8

=item C<sizeof> TYPE

This method will return the size of a C type in bytes.
If it cannot find the type, it will throw an exception.

If the type defines some kind of compound object, you
may ask for the size of a member of that compound object:

  $size = $c->sizeof( 'test.uni.word[1]' );
  $size == 2 or die;

This would set C<$size> to C<2>.

=back

=head2 member

=over 8

=item C<member> TYPE, OFFSET

You can use this method if you want to retrieve the name,
and optionally the type, of the member that is located at
a specific offset for a previously parsed type.

  use Convert::Binary::C;
  use Data::Dumper;
  
  $c = Convert::Binary::C->new( Alignment => 4, EnumSize => 4 )
                         ->parse( <<'ENDC' );
  typedef struct {
    char abc;
    long day;
    int *ptr;
  } week;
   
  struct test {
    week zap[8];
  };
  ENDC
  
  for my $offset ( 24, 39, 69, 99 ) {
    print "\$c->member( 'test', $offset )";
    my $member = eval { $c->member( 'test', $offset ) };
    print $@ ? "\n$@" : " => '$member'\n";
  }

This will print:

  $c->member( 'test', 24 ) => 'zap[2].abc'
  $c->member( 'test', 39 ) => 'zap[3]+3'
  $c->member( 'test', 69 ) => 'zap[5].ptr+1'
  $c->member( 'test', 99 )
  Offset 99 out of range (0 <= offset < 96) 

The output of the first iteration is obvious. The
member C<zap[2].abc> is located at offset 16 of C<struct test>.

In the second iteration, the offset points into a region
of padding bytes, thus no member of C<week> can be
named and instead of a member name the offset
relative to C<zap[3]> is appended.

In the third iteration, the offset points to C<zap[5].ptr>.
However, C<zap[5].ptr> is located at 44, not at 45,
and thus the remaining offset of 1 is also appended.

The last iteration causes an exception because the offset
of 99 is not valid for C<struct test> since the size
of C<struct test> is only 96.

In list context, the L<C<member>|/"member"> method will also
return the member's type:

  for my $offset ( 24, 39, 69 ) {
    print "\$c->member( 'test', $offset ) => ";
    my($member, $type) = $c->member( 'test', $offset );
    printf "('$member', %s)\n", defined $type ? "'$type'" : 'undef';
  }

If the offset points to a region of padding bytes, the
type will be C<undef>. If the type is a pointer,
a C<"*"> string will be returned.

  $c->member( 'test', 24 ) => ('zap[2].abc', 'char')
  $c->member( 'test', 39 ) => ('zap[3]+3', undef)
  $c->member( 'test', 69 ) => ('zap[5].ptr+1', '*')

If the type cannot be expressed as a string, a reference to
a definition of that type will be returned. Actually, this
can only be the case for inlined, unnamed enums:

  $c->parse( <<'ENDC' );
  struct inlined {
    long dummy;
    enum { INSIDE } inside;
  };
  ENDC
  
  ($member, $type) = $c->member( 'inlined', 6 );
  print Data::Dumper->Dump( [$member, $type], [qw(member type)] );

This will print:

  $member = 'inside+2';
  $type = {
    'enumerators' => {
      'INSIDE' => 0
    },
    'sign' => 0
  };

Have a look at the L<C<enum>|/"enum"> method for details on how to
interpret the returned data structure.

You can additionally specify a member for the type passed
as the first argument:

  ($member,$type) = $c->member('test.zap[2]', 6);
  print "('$member', '$type')\n";

This will print:

  ('day+2', 'long')

While the behaviour for C<struct>s is quite obvious, the behaviour
for C<union>s is rather tricky. As an single offset usually references
more than one member of a union, there are certain rules that the
algorithm uses for determining the I<best> member.

=over 2

=item *

The first non-compound member that is referenced without an offset
has the highest priority.

=item *

If no member is referenced without an offset, the first non-compound
member that is referenced with an offset will be returned.

=item *

Otherwise the first padding region that is encountered will be taken.

=back

As an example, given 4-byte-alignment and the union

  union choice {
    struct {
      char  color[2];
      long  size;
      char  taste;
    }       apple;
    char    grape[3];
    struct {
      long  weight;
      short price[3];
    }       melon;
  };

the L<C<member>|/"member"> method would return the following:

  Offset   Member               Type
  --------------------------------------
     0     apple.color[0]       'char'
     1     apple.color[1]       'char'
     2     grape[2]             'char'
     3     melon.weight+3       'long'
     4     apple.size           'long'
     5     apple.size+1         'long'
     6     melon.price[1]       'short'
     7     apple.size+3         'long'
     8     apple.taste          'char'
     9     melon.price[2]+1     'short'
    10     apple+10             undef
    11     apple+11             undef

It's like having a stack of all the union members and looking through
the stack for the shiniest piece you can see. The beginning of a member
(denoted by uppercase letters) is always shinier than the rest of a
member, while padding regions (denoted by dashes) aren't shiny at all.

  Offset   0   1   2   3   4   5   6   7   8   9  10  11
  -------------------------------------------------------
  apple   (C) (C)  -   -  (S) (s)  s  (s) (T)  -  (-) (-)
  grape    G   G  (G)
  melon    W   w   w  (w)  P   p  (P)  p   P  (p)  -   -

If you look through that stack from top to bottom, you'll end up at
the parenthesized members.

=back

=head2 offsetof

=over 8

=item C<offsetof> TYPE, MEMBER

You can think of L<C<offsetof>|/"offsetof"> as being the reverse of
the L<C<member>|/"member"> method. Given the L<C<member>|/"member"> example
code above,

  @args = (
    ['test',        'zap[5].day'  ],
    ['test.zap[2]', 'day'         ],
    ['test',        'zap[5].day+1'],
  );
  
  for( @args ) {
    printf "\$c->offsetof( '%s', '%s' )", @$_;
    my $offset = eval { $c->offsetof( @$_ ) };
    print $@ ? "\n$@" : " => $offset\n";
  }

will print:

  $c->offsetof( 'test', 'zap[5].day' ) => 64
  $c->offsetof( 'test.zap[2]', 'day' ) => 4
  $c->offsetof( 'test', 'zap[5].day+1' )
  Invalid character '+' (0x2B) in struct member expression 

The first iteration will simply show that the offset
of C<zap[5].day> is 64 relative to the beginning
of C<struct test>.

You may additionally specify a member for the type
passed as the first argument, as shown in the second
iteration.

Since the C<+n> syntax isn't allowed by L<C<offsetof>|/"offsetof">, the
third iteration will not print C<45>, but rather cause
an exception because of an invalid character being used.

=back

=head2 dependencies

=over 8

=item C<dependencies>

After some code has been parsed using either
the L<C<parse>|/"parse"> or L<C<parse_file>|/"parse_file"> methods,
the L<C<dependencies>|/"dependencies"> method can be used to
retrieve information about all files that the object
depends on, i.e. all files that have been parsed.

The method returns a hash reference. Each key is the
name of a file, so you could use

  @files = keys %{$c->dependencies};

to retrieve a list of these files. The values are
again hash references, each of which holds the size,
modification time (mtime), and change time (ctime)
of the file at the moment it was parsed.

  use Convert::Binary::C;
  use Data::Dumper;
  
  #----------------------------------------------------------
  # Create object, set include path, parse 'string.h' header
  #----------------------------------------------------------
  my $c = Convert::Binary::C->new
          ->Include( '/usr/lib/gcc-lib/i486-suse-linux/2.95.3/include',
                     '/usr/include' )
          ->parse_file( 'string.h' );
  
  #----------------------------------------------------------
  # Get dependencies of the object, extract dependency files
  #----------------------------------------------------------
  my $depend = $c->dependencies;
  my @files  = keys %$depend;
  
  #-----------------------------
  # Dump dependencies and files
  #-----------------------------
  print Data::Dumper->Dump( [$depend, \@files],
                         [qw( depend   *files )] );

The above code would print something like this:

  $depend = {
    '/usr/include/features.h' => {
      'ctime' => 1034791519,
      'mtime' => 1033737983,
      'size' => 10679
    },
    '/usr/include/sys/cdefs.h' => {
      'ctime' => 1034791520,
      'mtime' => 1033738026,
      'size' => 6540
    },
    '/usr/include/gnu/stubs.h' => {
      'ctime' => 1034791519,
      'mtime' => 1033738050,
      'size' => 882
    },
    '/usr/include/string.h' => {
      'ctime' => 1034791520,
      'mtime' => 1033738022,
      'size' => 13914
    },
    '/usr/lib/gcc-lib/i486-suse-linux/2.95.3/include/stddef.h' => {
      'ctime' => 1004697846,
      'mtime' => 989593995,
      'size' => 9834
    }
  };
  @files = (
    '/usr/include/features.h',
    '/usr/include/sys/cdefs.h',
    '/usr/include/gnu/stubs.h',
    '/usr/include/string.h',
    '/usr/lib/gcc-lib/i486-suse-linux/2.95.3/include/stddef.h'
  );

=back

=head2 sourcify

=over 8

=item C<sourcify>

Returns a string that holds the C code necessary to
represent all parsed C data structures.

  use Convert::Binary::C;
  
  $c = new Convert::Binary::C;
  $c->parse( <<'END' );
  
  #define NUMBER 42
  
  typedef struct _mytype mytype;
  
  struct _mytype {
    union {
      int         iCount;
      enum count *pCount;
    } counter;
  #pragma pack( push, 1 )
    struct {
      char string[NUMBER];
      int  array[NUMBER/sizeof(int)];
    } storage;
  #pragma pack( pop )
    mytype *next;
  };
  
  enum count { ZERO, ONE, TWO, THREE };
  
  END
  
  print $c->sourcify;

The above code would print something like this:

  /* typedef predeclarations */
  
  typedef struct _mytype mytype;
  
  /* defined enums */
  
  enum count
  {
  	ZERO,
  	ONE,
  	TWO,
  	THREE
  };
  
  
  /* defined structs and unions */
  
  struct _mytype
  {
  	union
  	{
  		int iCount;
  		enum count *pCount;
  	} counter;
  #pragma pack( push, 1 )
  	struct
  	{
  		char string[42];
  		int array[10];
  	}
  #pragma pack( pop )
  	storage;
  	mytype *next;
  };

The purpose of the L<C<sourcify>|/"sourcify"> method is to enable some
kind of platform-independent caching. The C code generated
by L<C<sourcify>|/"sourcify"> can be parsed by a standard C compiler, as well
as of course the Convert::Binary::C parser. However, it might
be significantly shorter than the code that has originally
been parsed. When parsing a typical header file, it's
easily possible that you need to open dozens of other files
that are included from that file, and end up parsing several
hundred kilobytes of C code. Since most of it is usually
preprocessor directives, function prototypes and comments,
the L<C<sourcify>|/"sourcify"> function strips this down to a few kilobytes.
Saving the L<C<sourcify>|/"sourcify"> string and parsing it next time instead
of the original code may be a lot faster.

=back

The following methods can be used to retrieve information about the
definitions that have been parsed. The examples given in the description
for L<C<enum>|/"enum">, L<C<compound>|/"compound"> and L<C<typedef>|/"typedef"> all
assume this piece of C code has been parsed:

  typedef unsigned long U32;
  
  enum __socket_type
  {
    SOCK_STREAM    = 1,
    SOCK_DGRAM     = 2,
    SOCK_RAW       = 3,
    SOCK_RDM       = 4,
    SOCK_SEQPACKET = 5,
    SOCK_PACKET    = 10
  };
  
  struct STRUCT_SV {
    void *sv_any;
    U32	sv_refcnt;
    U32	sv_flags;
  };
  
  typedef union {
    int abc[2];
    struct xxx {
      int a;
      int b;
    }   ab[3][4];
  } test;

=head2 enum_names

=over 8

=item C<enum_names>

Returns a list of identifiers of all defined enumeration
objects. Enumeration objects don't necessarily have an
identifier, so something like

  enum { A, B, C };

will obviously not appear in the list returned by
the L<C<enum_names>|/"enum_names"> method. Also, enumerations
that are not defined within the source code - like in

  struct foo {
    enum weekday *pWeekday;
    unsigned long year;
  };

where only a pointer to the C<weekday> enumeration object is used - will
not be returned, even though they have an identifier. So for the above two
enumerations, L<C<enum_names>|/"enum_names"> will return an empty list:

  @names = $c->enum_names;

The only way to retrieve a list of all enumeration identifiers
is to use the L<C<enum>|/"enum"> method without additional
arguments. You can get a list of all enumeration objects
that have an identifier by using

  @enums = map { $_->{identifier} || () } $c->enum;

but these may not have a definition. Thus, the two arrays would
look like this:

  @names = ();
  @enums = ('weekday');

The L<C<def>|/"def"> method returns a true value for all identifiers returned
by L<C<enum_names>|/"enum_names">.

=back

=head2 enum

=over 8

=item enum

=item C<enum> LIST

Returns a list of references to hashes containing
detailed information about all enumerations that
have been parsed.

If a list of enumeration identifiers is passed to the
method, the returned list will only contain hash
references for those enumerations.

If an enumeration identifier cannot be found, a
warning is issued and the returned list will contain
an undefined value at that position.

In scalar context, the number of enumerations will
be returned as long as the number of arguments to
the method call is not 1. In the latter case, a
hash reference holding information for the enumeration
will be returned.

The list returned by the L<C<enum>|/"enum"> method looks similar
to this:

  @enum = (
    {
      'enumerators' => {
        'SOCK_STREAM' => 1,
        'SOCK_RAW' => 3,
        'SOCK_SEQPACKET' => 5,
        'SOCK_RDM' => 4,
        'SOCK_PACKET' => 10,
        'SOCK_DGRAM' => 2
      },
      'identifier' => '__socket_type',
      'sign' => 0
    }
  );

=over 4

=item C<identifier>

holds the enumeration identifier. This key is not
present if the enumeration has no identifier.

=item C<enumerators>

is a reference to a hash table that holds
all enumerators of the enumeration.

=item C<sign>

is a boolean indicating if the enumeration is
signed (i.e. has negative values).

=back

One useful application may be to create a hash table that
holds all enumerators of all defined enumerations:

  %enum = map %{ $_->{enumerators} || {} }, $c->enum;

The C<%enum> hash table would then be:

  %enum = (
    'SOCK_STREAM' => 1,
    'SOCK_RAW' => 3,
    'SOCK_SEQPACKET' => 5,
    'SOCK_RDM' => 4,
    'SOCK_DGRAM' => 2,
    'SOCK_PACKET' => 10
  );

=back

=head2 compound_names

=over 8

=item C<compound_names>

Returns a list of identifiers of all structs and unions
(compound data structures) that are defined in the parsed
source code. Like enumerations, compounds don't need to
have an identifier, nor do they need to be defined.

Again, the only way to retrieve information about all
struct and union objects is to use the L<C<compound>|/"compound"> method
and don't pass it any arguments. If you should need a
list of all struct and union identifiers, you can use:

  @compound = map { $_->{identifier} || () } $c->compound;

The L<C<def>|/"def"> method returns a true value for all identifiers returned
by L<C<compound_names>|"compound_names">.

If you need the names of only the structs or only the unions, use
the L<C<struct_names>|/"struct_names"> and L<C<union_names>|/"union_names"> methods
respectively.

=back

=head2 compound

=over 8

=item C<compound>

=item C<compound> LIST

Returns a list of references to hashes containing
detailed information about all compounds (structs and
unions) that have been parsed.

If a list of struct/union identifiers is passed to the
method, the returned list will only contain hash
references for those compounds.

If an identifier cannot be found, a warning is issued
and the returned list will contain an undefined value
at that position.

In scalar context, the number of compounds will
be returned as long as the number of arguments to
the method call is not 1. In the latter case, a
hash reference holding information for the compound
will be returned.

The list returned by the L<C<compound>|/"compound"> method looks similar
to this:

  @compound = (
    {
      'identifier' => 'STRUCT_SV',
      'align' => 1,
      'pack' => 0,
      'type' => 'struct',
      'declarations' => [
        {
          'declarators' => [
            {
              'declarator' => '*sv_any',
              'size' => 4,
              'offset' => 0
            }
          ],
          'type' => 'void'
        },
        {
          'declarators' => [
            {
              'declarator' => 'sv_refcnt',
              'size' => 4,
              'offset' => 4
            }
          ],
          'type' => 'U32'
        },
        {
          'declarators' => [
            {
              'declarator' => 'sv_flags',
              'size' => 4,
              'offset' => 8
            }
          ],
          'type' => 'U32'
        }
      ],
      'size' => 12
    },
    {
      'identifier' => 'xxx',
      'align' => 1,
      'pack' => 0,
      'type' => 'struct',
      'declarations' => [
        {
          'declarators' => [
            {
              'declarator' => 'a',
              'size' => 4,
              'offset' => 0
            }
          ],
          'type' => 'int'
        },
        {
          'declarators' => [
            {
              'declarator' => 'b',
              'size' => 4,
              'offset' => 4
            }
          ],
          'type' => 'int'
        }
      ],
      'size' => 8
    },
    {
      'align' => 1,
      'pack' => 0,
      'type' => 'union',
      'declarations' => [
        {
          'declarators' => [
            {
              'declarator' => 'abc[2]',
              'size' => 8,
              'offset' => 0
            }
          ],
          'type' => 'int'
        },
        {
          'declarators' => [
            {
              'declarator' => 'ab[3][4]',
              'size' => 96,
              'offset' => 0
            }
          ],
          'type' => 'struct xxx'
        }
      ],
      'size' => 96
    }
  );

=over 4

=item C<identifier>

holds the struct or union identifier. This
key is not present if the compound has no identifier.

=item C<type>

is either 'struct' or 'union'.

=item C<size>

is the size of the struct or union.

=item C<align>

is the alignment of the struct or union.

=item C<pack>

is the struct member alignment if the compound
is packed, or zero otherwise.

=item C<declarations>

is an array of hash references describing each struct
declaration:

=over 4

=item C<type>

is the type of the struct declaration. This may be a
string or a reference to a hash describing the type.

=item C<declarators>

is an array of hashes describing each declarator:

=over 4

=item C<declarator>

is a string representation of the declarator.

=item C<offset>

is the offset of the struct member represented by
the current declarator relative to the beginning
of the struct or union.

=item C<size>

is the size occupied by the struct member represented
by the current declarator.

=back

=back

=back

It may be useful to have separate lists for structs and
unions. One way to retrieve such lists would be to use

  push @{$_->{type} eq 'union' ? \@unions : \@structs}, $_
      for $c->compound;

However, you should use the L<C<struct>|/"struct"> and L<C<union>|/"union"> methods,
which is a lot simpler:

  @structs = $c->struct;
  @unions  = $c->union;

=back

=head2 struct_names

=over 8

=item C<struct_names>

Returns a list of all defined struct identifiers.
This is equivalent to calling L<C<compound_names>|"compound_names">, just that
it only returns the names of the struct identifiers and
doesn't return the names of the union identifiers.

=back

=head2 struct

=over 8

=item C<struct>

=item C<struct> LIST

Like the L<C<compound>|/"compound"> method, but only allows for structs.

=back

=head2 union_names

=over 8

=item C<union_names>

Returns a list of all defined union identifiers.
This is equivalent to calling L<C<compound_names>|"compound_names">, just that
it only returns the names of the union identifiers and
doesn't return the names of the struct identifiers.

=back

=head2 union

=over 8

=item C<union>

=item C<union> LIST

Like the L<C<compound>|/"compound"> method, but only allows for unions.

=back

=head2 typedef_names

=over 8

=item C<typedef_names>

Returns a list of all defined typedef identifiers. Typedefs
that do not specify a type that you could actually work with
will not be returned.

The L<C<def>|/"def"> method returns a true value for all identifiers returned
by L<C<typedef_names>|/"typedef_names">.

=back

=head2 typedef

=over 8

=item C<typedef>

=item C<typedef> LIST

Returns a list of references to hashes containing
detailed information about all typedefs that have
been parsed.

If a list of typedef identifiers is passed to the
method, the returned list will only contain hash
references for those typedefs.

If an identifier cannot be found, a warning is issued
and the returned list will contain an undefined value
at that position.

In scalar context, the number of typedefs will
be returned as long as the number of arguments to
the method call is not 1. In the latter case, a
hash reference holding information for the typedef
will be returned.

The list returned by the L<C<typedef>|/"typedef"> method looks similar
to this:

  @typedef = (
    {
      'declarator' => 'U32',
      'type' => 'unsigned long'
    },
    {
      'declarator' => 'test',
      'type' => {
        'align' => 1,
        'pack' => 0,
        'type' => 'union',
        'declarations' => [
          {
            'declarators' => [
              {
                'declarator' => 'abc[2]',
                'size' => 8,
                'offset' => 0
              }
            ],
            'type' => 'int'
          },
          {
            'declarators' => [
              {
                'declarator' => 'ab[3][4]',
                'size' => 96,
                'offset' => 0
              }
            ],
            'type' => 'struct xxx'
          }
        ],
        'size' => 96
      }
    }
  );

=over 4

=item C<declarator>

is the type declarator.

=item C<type>

is the type specification. This may be a string
or a reference to a hash describing the type.
See L<C<enum>|/"enum"> and L<C<compound>|/"compound"> for
a description on how to interpret this hash.

=back

=back

=head1 FUNCTIONS

=head2 Convert::Binary::C::feature

=over 8

=item C<feature> STRING

Checks if Convert::Binary::C was built with certain features.
For example,

  print "debugging version"
      if Convert::Binary::C::feature( 'debug' );

will check if Convert::Binary::C was built with debugging support
enabled. The C<feature> function returns C<1> if the feature is
enabled, C<0> if the feature is disabled, and C<undef> if the
feature is unknown. Currently the only features that can be checked
are C<debug>, C<threads> and C<c99>. The latter will check if some
extensions of the ANSI-C99 standard are enabled.

You can enable or disable certain features at compile time of the
module by using the

  perl Makefile.PL enable-feature disable-feature

syntax.

=back

=head1 DEBUGGING

Like perl itself, Convert::Binary::C can be compiled with debugging
support that can then be selectively enabled at runtime. You can
specify whether you like to build Convert::Binary::C with debugging
support or not by explicitly giving an argument to F<Makefile.PL>.
Use

  perl Makefile.PL enable-debug

to enable debugging, or

  perl Makefile.PL disable-debug

to disable debugging. The default will depend on how your perl
binary was built. If it was built with C<-DDEBUGGING>,
Convert::Binary::C will be built with debugging support, too.

Once you have built Convert::Binary::C with debugging support, you
can use the following syntax to enable debug output. Instead of

  use Convert::Binary::C;

you simply say

  use Convert::Binary::C debug => 'all';

which will enable all debug output. However, I don't recommend
to enable all debug output, because that can be a fairly large
amount. Instead of saying C<all>, you can pass a string that
consists of one or more of the following characters:

  m   enable memory allocation tracing
  M   enable memory allocation & assertion tracing
  
  h   enable hash table debugging
  H   enable hash table dumps
  
  d   enable debug output from the XS module
  c   enable debug output from the ctlib
  t   enable debug output about type objects
  
  l   enable debug output from the C lexer
  p   enable debug output from the C parser
  r   enable debug output from the #pragma parser
  
  y   enable debug output from yacc (bison)

So the following might give you a brief overview of what's
going on inside Convert::Binary::C:

  use Convert::Binary::C debug => 'dct';

When you want to debug memory allocation using

  use Convert::Binary::C debug => 'm';

you can use the Perl script F<check_alloc.pl> that resides
in the F<ctlib/util/tool> directory to extract statistics
about memory usage and information about memory leaks from
the resulting debug output.

By default, all debug output is written to C<stderr>. You
can, however, redirect the debug output to a file with
the C<debugfile> option:

  use Convert::Binary::C debug     => 'dcthHm',
                         debugfile => './debug.out';

If the file cannot be opened, you'll receive a warning and
the output will go the C<stderr> way again.

If Convert::Binary::C is built without debugging support,
passing the C<debug> or C<debugfile> options will cause
a warning to be issued.

=head1 BITFIELDS

Bitfields are currently not supported by Convert::Binary::C,
because I generally don't use them. I plan to support them
in a later release, when I will have found an easy way of integrating
them into the module.

Whenever a method has to deal with bitfields, it will issue
a warning message that bitfields are unsupported. Thus, you
may use bitfields in your C source code, but you won't be
annoyed with warning messages unless you really use a type
that actually contains bitfields in a method call
like L<C<sizeof>|/"sizeof"> or L<C<pack>|/"pack">.

While bitfields are not appropriately handled by the conversion
routines yet, they are already parsed correctly. This means
that you can reliably use the declarator fields as returned
by the L<C<struct>|/"struct"> or L<C<typedef>|/"typedef"> methods.
Given the following source

  struct bitfield {
    int seven:7;
    int :1;
    int four:4, :0;
    int integer;
  };

a call to L<C<struct>|/"struct"> will return

  @struct = (
    {
      'identifier' => 'bitfield',
      'align' => 1,
      'pack' => 0,
      'type' => 'struct',
      'declarations' => [
        {
          'declarators' => [
            {
              'declarator' => 'seven:7'
            }
          ],
          'type' => 'int'
        },
        {
          'declarators' => [
            {
              'declarator' => ':1'
            }
          ],
          'type' => 'int'
        },
        {
          'declarators' => [
            {
              'declarator' => 'four:4'
            },
            {
              'declarator' => ':0'
            }
          ],
          'type' => 'int'
        },
        {
          'declarators' => [
            {
              'declarator' => 'integer',
              'size' => 4,
              'offset' => 0
            }
          ],
          'type' => 'int'
        }
      ],
      'size' => 4
    }
  );

No size/offset keys will be returned for bitfield entries.
Also, the size of a structure containing bitfields is not
valid, as bitfields internally do not increase the size
of a structure yet.

=head1 MULTITHREADING

Convert::Binary::C was designed to be thread-safe.

Since the used preprocessor unfortunately isn't
re-entrant, source code parsing using
the L<C<parse>|/"parse"> and L<C<parse_file>|/"parse_file"> methods
is locked, so don't expect these routines to run in parallel
on multithreaded perls.

=head1 CREDITS

=over 2

=item *

My love Jennifer for always being there, for filling my life with
joy and last but not least for proofreading the documentation.

=item *

Michael J. Hohmann E<lt>mjh@scientist.deE<gt> for endless discussions
on our way to and back home from work, and for making me think
about supporting L<C<pack>|/"pack"> and L<C<unpack>|/"unpack"> for
compound members.

=item *

Thorsten Jens E<lt>thojens@gmx.deE<gt> for testing the package
on various platforms.

=item *

Mark Overmeer E<lt>mark@overmeer.netE<gt> for suggesting the
module name and giving invaluable feedback.

=item *

Thomas Pornin E<lt>pornin@bolet.orgE<gt> for his
excellent C<ucpp> preprocessor library.

=item *

Marc Rosenthal for his suggestions and support.

=item *

James Roskind, as his C parser was a great starting point to fix
all the problems I had with my original parser based only on the
ANSI ruleset.

=item *

Steffen Zimmermann for a prolific discussion on the cloning
algorithm.

=back

=head1 BUGS

I'm sure there are still lots of bugs in the code for this
module. If you find any bugs, Convert::Binary::C doesn't
seem to build on your system or any of its tests fail, please
send a mail to E<lt>mhx@cpan.orgE<gt>.

=head1 TODO

If you're interested in what I currently plan to improve
(or fix), have a look at the F<TODO> file.

=head1 POSTCARDS

If you're using my module and like it, you can show your appreciation
by sending me a postcard from where you live. I won't urge you to do it,
it's completely up to you. To me, this is just a very nice way of
receiving feedback about my work. Please send your postcard to:

  Marcus Holland-Moritz
  Kuppinger Weg 28
  71116 Gaertringen
  GERMANY

=head1 COPYRIGHT

Copyright (c) 2002-2003 Marcus Holland-Moritz. All rights reserved.
This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

The C<ucpp> library is (c) 1998-2002 Thomas Pornin. For licence
and redistribution details refer to F<ctlib/ucpp/README>.

Portions copyright (c) 1989, 1990 James A. Roskind.

Some of the include files used for the F<t/106_parse.t> test
script are (c) 1991-1999, 2000, 2001 Free Software Foundation,
Inc. They are neither required to create the binary nor linked
to the source code of this module in any other way.

=head1 SEE ALSO

L<ccconfig>, L<perl>, L<perldata>, L<perlop>, L<perlvar> and L<Data::Dumper>.

=cut
