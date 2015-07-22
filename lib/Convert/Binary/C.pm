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
# $Date: 2004/08/22 21:43:33 +0100 $
# $Revision: 65 $
# $Snapshot: /Convert-Binary-C/0.55 $
# $Source: /lib/Convert/Binary/C.pm $
#
################################################################################
#
# Copyright (c) 2002-2004 Marcus Holland-Moritz. All rights reserved.
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

$VERSION = do { my @r = '$Snapshot: /Convert-Binary-C/0.55 $' =~ /(\d+\.\d+(?:_\d+)?)/; @r ? $r[0] : '9.99' };

bootstrap Convert::Binary::C $VERSION;

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
  my @warn;
  {
    local $SIG{__WARN__} = sub { push @warn, $_[0] };
    $opt = eval { $self->configure( $opt, @_ ) };
  }
  for my $w ( @warn ) {
    $w =~ s/\s+at.*?C\.pm.*//s;
    carp $w;
  }
  if( $@ ) {
    $@ =~ s/\s+at.*?C\.pm.*//s;
    croak $@;
  }
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
  $c->Include( '/usr/lib/gcc-lib/i686-pc-linux-gnu/3.3.3/include',
               '/usr/include' )
    ->Define( qw( __USE_POSIX __USE_ISOC99=1 ) );
  
  #----------------------------------
  # Parse the 'time.h' header file
  #----------------------------------
  $c->parse_file( 'time.h' );
  
  #---------------------------------------
  # See which files the object depends on
  #---------------------------------------
  print Dumper( [$c->dependencies] );
  
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

In late 2000 I wrote a real-time debugging interface for an
embedded medical device that allowed me to send out data from
that device over its integrated Ethernet adapter.
The interface was C<printf()>-like, so you could easily send
out strings or numbers. But you could also send out what I
called I<arbitrary data>, which was intended for arbitrary
blocks of the device's memory.

Another part of this real-time debugger was a Perl application
running on my workstation that gathered all the messages that
were sent out from the embedded device. It printed all the
strings and numbers, and hex-dumped the arbitrary data.
However, manually parsing a couple of 300 byte hex-dumps of a
complex C structure is not only frustrating, but also error-prone
and time consuming.

Using L<C<unpack>|perlfunc/"unpack"> to retrieve the contents
of a C structure works fine for small structures and if you
don't have to deal with struct member alignment. But otherwise,
maintaining such code can be as awful as deciphering hex-dumps.

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

=head2 Why use Convert::Binary::C?

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
easily embed multi-line strings in your code. You can find more
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

=head1 UNDERSTANDING TYPES

This section covers one of the fundamental features of
Convert::Binary::C. It's how I<type expressions>, referred to
as TYPEs in the L<method reference|/"METHODS">, are handled
by the module.

Many of the methods,
namely L<C<pack>|/"pack">, L<C<unpack>|/"unpack">, L<C<sizeof>|/"sizeof">, L<C<typeof>|/"typeof">, L<C<member>|/"member"> and L<C<offsetof>|/"offsetof">,
are passed a TYPE to operate on as their first argument.

=head2 Standard Types

These are trivial. Standard types are simply enum names, struct
names, union names, or typedefs. Almost every method that wants
a TYPE will accept a standard type.

For enums, structs and unions, the prefixes C<enum>, C<struct> and C<union> are
optional. However, if a typedef with the same name exists, like in

  struct foo {
    int bar;
  };
  
  typedef int foo;

you will have to use the prefix to distinguish between the
struct and the typedef. Otherwise, a typedef is always given
preference.

=head2 Basic Types

Basic types, or atomic types, are C<int> or C<char>, for example.
It's possible to use these basic types without having parsed any
code. You can simply do

  $c = new Convert::Binary::C;
  $size = $c->sizeof( 'unsigned long' );
  $data = $c->pack( 'short int', 42 );

Even though the above works fine, it is not possible to define
more complex types on the fly, so

  $size = $c->sizeof( 'struct { int a, b; }' );

will result in an error.

Basic types are not supported by all methods. For example, it makes
no sense to use L<C<member>|/"member"> or L<C<offsetof>|/"offsetof"> on
a basic type. Using L<C<typeof>|/"typeof"> isn't very useful, but
supported.

=head2 Member Expressions

This is by far the most complex part, depending on the complexity of
your data structures. Any L<standard type|/"Standard Types"> that
defines a compound or an array may be followed by a member expression
to select only a certain part of the data type. Say you have parsed the
following C code:

  struct foo {
    long type;
    struct {
      short x, y;
    } array[20];
  };
  
  typedef struct foo matrix[8][8];

You may want to know the size of the C<array> member of C<struct foo>.
This is quite easy:

  print $c->sizeof( 'foo.array' ), " bytes";

will print

  80 bytes

depending of course on the C<ShortSize> you configured.

If you wanted to unpack only a single column of C<matrix>, that's
easy as well (and of course it doesn't matter which index you use):

  $column = $c->unpack( 'matrix[2]', $data );

Member expressions can be arbitrarily complex:

  $type = $c->typeof( 'matrix[2][3].array[7].y' );
  print "the type is $type";

will, for example, print

  the type is short

Member expressions are also used as the second argument
to L<C<offsetof>|/"offsetof">.

=head2 Offsets

Members returned by the L<C<member>|/"member"> method have an optional
offset suffix to indicate that the given offset doesn't point to the
start of that member. For example,

  $member = $c->member( 'matrix', 1431 );
  print $member;

will print

  [2][1].type+3

If you would use this as a member expression, like in

  $size = $c->sizeof( "matrix $member" );

the offset suffix will simply be ignored. Actually, it will be
ignored for all methods if it's used in the first argument.

When used in the second argument to L<C<offsetof>|/"offsetof">,
it will usually do what you mean, i. e. the offset suffix, if
present, will be considered when determining the offset. This
behaviour ensures that

  $member = $c->member( 'foo', 43 );
  $offset = $c->offsetof( 'foo', $member );
  print "'$member' is located at offset $offset of struct foo";

will always correctly set C<$offset>:

  '.array[9].y+1' is located at offset 43 of struct foo

If this is not what you mean, e. g. because you want to know the
offset where the member returned by L<C<member>|/"member"> starts,
you just have to remove the suffix:

  $member =~ s/\+\d+$//;
  $offset = $c->offsetof( 'foo', $member );
  print "'$member' starts at offset $offset of struct foo";

This would then print:

  '.array[9].y' starts at offset 42 of struct foo

=head1 USING HOOKS

Hooks are a new feature and in this early state are considered
experimental. That means that both interface and behaviour may
be subject to incompatible changes. Nevertheless hooks are quite
interesting and can be extremely useful, so read on!

Using hooks, you can easily override the
way L<C<pack>|/"pack"> and L<C<unpack>|/"unpack"> handle data.
If you define hooks for a certain data type, each time this
data type is processed the corresponding hook will be called
to allow you to modify the data.

=head2 Basic hooks

Here's an example. Let's assume the following C code has been
parsed:

  typedef unsigned long u_32;
  typedef u_32 ProtoId;
  typedef ProtoId MyProtoId;
  
  struct MsgHeader {
    MyProtoId id;
    u_32      len;
  };
  
  struct String {
    u_32 len;
    char buf[];
  };

You could now use the types above and, for example, unpack
binary data representing a C<MsgHeader> like this:

  $msg_header = $c->unpack('MsgHeader', $data);

This would give you:

  $msg_header = {
    'len' => 13,
    'id' => 42
  };

Instead of dealing with C<ProtoId>'s as integers, you would
rather like to have them as clear text. You could provide
subroutines to convert between clear text and integers:

  %proto = (
    CATS      =>    1,
    DOGS      =>   42,
    HEDGEHOGS => 4711,
  );
  
  %rproto = reverse %proto;
  
  sub ProtoId_unpack {
    $rproto{$_[0]} || 'unknown protocol'
  }
  
  sub ProtoId_pack {
    $proto{$_[0]} or die 'unknown protocol'
  }

The hooks feature allows you to register these subroutines
using the L<C<add_hooks>|/"add_hooks"> method:

  $c->add_hooks(ProtoId => { pack   => \&ProtoId_pack,
                             unpack => \&ProtoId_unpack });

Doing exactly the same unpack on C<MsgHeader> again would
now return:

  $msg_header = {
    'len' => 13,
    'id' => 'DOGS'
  };

Actually, if you don't need the reverse operation, you don't even
have to register a C<pack> hook. Or, even better, you can have a
more intelligent C<unpack> hook that creates a dual-typed variable:

  use Scalar::Util qw(dualvar);
  
  sub ProtoId_unpack2 {
    dualvar $_[0], $rproto{$_[0]} || 'unknown protocol'
  }
  
  $c->add_hooks(ProtoId => { unpack => \&ProtoId_unpack2 });
  
  $msg_header = $c->unpack('MsgHeader', $data);

Just as before, this would print

  $msg_header = {
    'len' => 13,
    'id' => 'DOGS'
  };

but without requiring a C<pack> hook for packing, at least as
long as you keep the variable dual-typed.

Hooks are called with exactly one argument, which is the data
that should be processed. They are called in scalar context and
expected to return the processed data.

To get rid of registered hooks, you can use either
the L<C<delete_hooks>|/"delete_hooks"> method

  $c->delete_hooks('ProtoId');

or L<C<delete_all_hooks>|/"delete_all_hooks">:

  $c->delete_all_hooks;

Of course, hooks are not restricted to handling integer values.
You could just as well add hooks for the C<String> struct from
the code above. A useful example would be to have these hooks:

  sub string_unpack {
    my $s = shift;
    pack "c$s->{len}", @{$s->{buf}};
  }
  
  sub string_pack {
    my $s = shift;
    return {
      len => length $s,
      buf => [ unpack 'c*', $s ],
    }
  }

While you would normally get the following output when unpacking
a C<String>

  $string = {
    'len' => 12,
    'buf' => [
      72,
      101,
      108,
      108,
      111,
      32,
      87,
      111,
      114,
      108,
      100,
      33
    ]
  };

you could just register the hooks using

  $c->add_hooks(String => { pack   => \&string_pack,
                            unpack => \&string_unpack });

and you would get a nice human-readable string:

  $string = 'Hello World!';

Packing a string turns out to be just as easy:

  use Data::Hexdumper;
  
  $data = $c->pack('String', 'Just another Perl hacker,');
  
  print hexdump(data => $data);

This would print:

    0x0000 : 00 00 00 19 4A 75 73 74 20 61 6E 6F 74 68 65 72 : ....Just.another
    0x0010 : 20 50 65 72 6C 20 68 61 63 6B 65 72 2C          : .Perl.hacker,

=head2 Advanced hooks

But hooks are even more powerful. You can customize the arguments
that are passed to your hooks and you can use L<C<arg>|/"arg"> to
pass certain special arguments, such as the name of the type that
is currently being processed by the hook.

The following example shows how it is easily possible to peek into
the perl internals using hooks.

  use Config;
  
  $c = new Convert::Binary::C %CC, OrderMembers => 1;
  $c->Include(["$Config{archlib}/CORE", @{$c->Include}]);
  $c->parse(<<ENDC);
  #include "EXTERN.h"
  #include "perl.h"
  ENDC
  
  $c->add_hooks($_ => { unpack_ptr => [\&unpack_ptr,
                                       $c->arg(qw(SELF TYPE DATA))] })
      for qw( XPVAV XPVHV MAGIC MGVTBL HV );

First, we add the perl core include path and parse F<perl.h>. Then,
we add an C<unpack_ptr> hook for a couple of the internal data types.

The C<unpack_ptr> and C<pack_ptr> hooks are called whenever a pointer
to a certain data structure is processed. This is by far the most
experimental part of the hooks feature, as this includes B<any> kind
of pointer. There's no way for the hook to know the difference between
a plain pointer, or a pointer to a pointer, or a pointer to an array
(this is because the difference doesn't matter anywhere else in
Convert::Binary::C).

But the hook above makes use of another very interesting feature: It
uses L<C<arg>|/"arg"> to pass special arguments to the hook subroutine.
Usually, the hook subroutine is simply passed a single data argument.
But using the above definition, it'll get a reference to the calling
object (C<SELF>), the name of the type being processed (C<TYPE>) and
the data (C<DATA>).

But how does our hook look like?

  sub unpack_ptr {
    my($self, $type, $ptr) = @_;
    $ptr or return '<NULL>';
    my $size = $self->sizeof($type);
    $self->unpack($type, unpack("P$size", pack('I', $ptr)));
  }

As you can see, the hook is rather simple. First, it receives the
arguments mentioned above. It performs a quick check if the pointer
is C<NULL> and shouldn't be processed any further. Next, it determines
the size of the type being processed. And finally, it'll just use
the C<P>I<n> unpack template to read from that memory location and
recursively call L<C<unpack>|/"unpack"> to unpack the type. (And yes,
this may of course again call other hooks.)

Now, let's test that:

  my $ref = bless ["Boo!"], "Foo::Bar";
  my $ptr = hex(("$ref" =~ /\(0x([[:xdigit:]]+)\)$/)[0]);
  
  print Dumper(unpack_ptr($c, 'AV', $ptr));

Just for the fun of it, we create a blessed array reference. But how
do we get a pointer to the corresponding C<AV>? This is rather easy,
as the address of the C<AV> is just the hex value that appears when
using the array reference in string context. So we just grab that and
turn it into decimal. All that's left to do is just call our hook,
as it can already handle C<AV> pointers. And this is what we get:

  $VAR1 = {
    'sv_any' => {
      'xav_array' => '137956408',
      'xav_fill' => '0',
      'xav_max' => '0',
      'xof_off' => '0',
      'xnv_nv' => '0',
      'xmg_magic' => '<NULL>',
      'xmg_stash' => {
        'sv_any' => {
          'xhv_array' => '0',
          'xhv_fill' => '0',
          'xhv_max' => '7',
          'xhv_keys' => '0',
          'xnv_nv' => '0',
          'xmg_magic' => '<NULL>',
          'xmg_stash' => '<NULL>',
          'xhv_riter' => '-1',
          'xhv_eiter' => '0',
          'xhv_pmroot' => '0',
          'xhv_name' => '138060312'
        },
        'sv_refcnt' => '2',
        'sv_flags' => '536870923'
      },
      'xav_alloc' => '137956408',
      'xav_arylen' => '0',
      'xav_flags' => '1'
    },
    'sv_refcnt' => '1',
    'sv_flags' => '4106'
  };

Even though it is rather easy to do such stuff using C<unpack_ptr> hooks,
you should really know what you're doing and do it with extreme care
because of the limitations mentioned above. It's really easy to run into
segmentation faults when you're dereferencing pointers that are not yours.

=head2 Performance

Using hooks isn't for free. In performance-critical applications
you have to keep in mind that hooks are actually perl subroutines
and that they are called once for every value of a registered
type that is being packed or unpacked. If only about 10% of the
values require hooks to be called, you'll hardly notice the
difference (if your hooks are implemented efficiently, that is).
But if all values would require hooks to be called, that alone
could easily make packing and unpacking very slow.

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

Which will print something like this:

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
    'Include' => [
      '/usr/include'
    ],
    'HasCPPComments' => 1,
    'Warnings' => 0,
    'CompoundAlignment' => 1,
    'OrderMembers' => 0
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
default unless overridden by C<CBC_DEFAULT_INT_SIZE> at compile time.

=item C<ShortSize> =E<gt> 0 | 1 | 2 | 4 | 8

Set the number of bytes that are occupied by a short integer.
Although integers explicitly declared as C<short> should be
always 16 bit, there are compilers that make a short
8 bit wide. If you set it to zero, the size of a short
integer on the host system will be used. This is also the
default unless overridden by C<CBC_DEFAULT_SHORT_SIZE> at compile
time.

=item C<LongSize> =E<gt> 0 | 1 | 2 | 4 | 8

Set the number of bytes that are occupied by a long integer.
If set to zero, the size of a long integer on the host system
will be used. This is also the default unless overridden
by C<CBC_DEFAULT_LONG_SIZE> at compile time.

=item C<LongLongSize> =E<gt> 0 | 1 | 2 | 4 | 8

Set the number of bytes that are occupied by a long long
integer. If set to zero, the size of a long long integer
on the host system, or 8, will be used. This is also the
default unless overridden by C<CBC_DEFAULT_LONG_LONG_SIZE> at
compile time.

=item C<FloatSize> =E<gt> 0 | 1 | 2 | 4 | 8 | 12 | 16

Set the number of bytes that are occupied by a single
precision floating point value.
If you set it to zero, the size of a C<float> on the
host system will be used. This is also the default unless
overridden by C<CBC_DEFAULT_FLOAT_SIZE> at compile time.
For details on floating point support,
see L<"FLOATING POINT VALUES">.

=item C<DoubleSize> =E<gt> 0 | 1 | 2 | 4 | 8 | 12 | 16

Set the number of bytes that are occupied by a double
precision floating point value.
If you set it to zero, the size of a C<double> on the
host system will be used. This is also the default unless
overridden by C<CBC_DEFAULT_DOUBLE_SIZE> at compile time.
For details on floating point support,
see L<"FLOATING POINT VALUES">.

=item C<LongDoubleSize> =E<gt> 0 | 1 | 2 | 4 | 8 | 12 | 16

Set the number of bytes that are occupied by a double
precision floating point value.
If you set it to zero, the size of a C<long double> on
the host system, or 12 will be used. This is also the
default unless overridden by C<CBC_DEFAULT_LONG_DOUBLE_SIZE> at compile
time. For details on floating point support,
see L<"FLOATING POINT VALUES">.

=item C<PointerSize> =E<gt> 0 | 1 | 2 | 4 | 8

Set the number of bytes that are occupied by a pointer. This is
in most cases 2 or 4. If you set it to zero, the size of a
pointer on the host system will be used. This is also the
default unless overridden by C<CBC_DEFAULT_PTR_SIZE> at compile time.

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

=item C<Alignment> =E<gt> 0 | 1 | 2 | 4 | 8 | 16

Set the struct member alignment. This option controls where
padding bytes are inserted between struct members. It globally
sets the alignment for all structs/unions. However, this can
be overridden from within the source code with the
common C<pack> pragma as explained in L<"Supported pragma directives">.
The default alignment is 1, which means no padding bytes are
inserted. A setting of C<0> means I<native> alignment, i.e.
the alignment of the system that Convert::Binary::C has been
compiled on. You can determine the native properties using
the L<C<native>|/"native"> function.

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
no alignment restrictions. (Unfortunately, that's not the whole
story. See the C<CompoundAlignment> option for details.)

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

=item C<CompoundAlignment> =E<gt> 0 | 1 | 2 | 4 | 8 | 16

Usually, the alignment of a compound (i.e. a C<struct> or
a C<union>) depends only on its largest member and on the setting
of the C<Alignment> option. There are, however, architectures and
compilers where compounds can have different alignment constraints.

For most platforms and compilers, the alignment constraint for
compounds is 1 byte. That is, on most platforms

  struct onebyte {
    char byte;
  };

will have an alignment of 1 and also a size of 1. But if you take
an ARM architecture, the above C<struct onebyte> will have an
alignment of 4, and thus also a size of 4. 

You can configure this by setting C<CompoundAlignment> to 4. This
will ensure that the alignment of compounds is always 4.

Setting C<CompoundAlignment> to C<0> means I<native> compound
alignment, i.e. the compound alignment of the system that
Convert::Binary::C has been compiled on. You can determine the
native properties using the L<C<native>|/"native"> function.

There are also compilers for certain platforms that allow you to
adjust the compound alignment. If you're not aware of the fact
that your compiler/architecture has a compound alignment other
than 1, strange things can happen. If, for example, the compound
alignment is 2 and you have something like

  typedef unsigned char U8;
  
  struct msg_head {
    U8 cmd;
    struct {
      U8 hi;
      U8 low;
    } crc16;
    U8 len;
  };

there will be one padding byte inserted before the
embedded C<crc16> struct and after the C<len> member, which
is most probably not what was intended:

  0     1     2     3     4     5     6
  +-----+-----+-----+-----+-----+-----+
  | cmd |  *  | hi  | low | len |  *  |
  +-----+-----+-----+-----+-----+-----+

Note that both C<#pragma pack> and the C<Alignment> option can
override C<CompoundAlignment>. If you set C<CompoundAlignment> to
4, but C<Alignment> to 2, compounds will actually be aligned on
2-byte boundaries.

=item C<ByteOrder> =E<gt> 'BigEndian' | 'LittleEndian'

Set the byte order for integers larger than a single byte.
Little endian (Intel, least significant byte first) and
big endian (Motorola, most significant byte first) byte
order are supported. The default byte order is the same as
the byte order of the host system unless overridden
by C<CBC_DEFAULT_BYTEORDER> at compile time.

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

By default, the Convert::Binary::C parser will recognize
the keywords C<inline> and C<restrict>. If your compiler
doesn't have these new keywords, it usually doesn't matter.
Only if you're using the keywords as identifiers, like in

  typedef struct inline {
    int a, b;
  } restrict;

you'll have to disable these ISO-C99 keywords:

  $c->DisabledKeywords( [qw( inline restrict )] );

The parser allows you to disable the following keywords:

  asm
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
map C<__signed__> to the built-in C keyword C<signed> and
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

=item C<OrderMembers> =E<gt> 0 | 1

When using L<C<unpack>|/"unpack"> on compounds and
iterating over the returned hash, the order of the
compound members is generally not preserved due to
the nature of hash tables. It is not even guaranteed
that the order is the same between different runs of
the same program. This can be very annoying if you
simply use to dump your data structures and the
compound members always show up in a different order.

By setting C<OrderMembers> to a non-zero value, all
hashes returned by L<C<unpack>|/"unpack"> are tied to
a class that preserves the order of the hash keys.
This way, all compound members will be returned in
the correct order just as they are defined in your C
code.

  use Convert::Binary::C;
  use Data::Dumper;
  
  $c = Convert::Binary::C->new->parse( <<'ENDC' );
  struct test {
    char one;
    char two;
    struct {
      char never;
      char change;
      char this;
      char order;
    } three;
    char four;
  };
  ENDC
  
  $data = "Convert";
  
  $u1 = $c->unpack( 'test', $data );
  $c->OrderMembers(1);
  $u2 = $c->unpack( 'test', $data );
  
  print Data::Dumper->Dump( [$u1, $u2], [qw(u1 u2)] );

This will print something like:

  $u1 = {
    'three' => {
      'change' => 118,
      'order' => 114,
      'this' => 101,
      'never' => 110
    },
    'one' => 67,
    'two' => 111,
    'four' => 116
  };
  $u2 = {
    'one' => '67',
    'two' => '111',
    'three' => {
      'never' => '110',
      'change' => '118',
      'this' => '101',
      'order' => '114'
    },
    'four' => '116'
  };

To be able to use this option, you have to install
either the L<Tie::Hash::Indexed|Tie::Hash::Indexed> or
the L<Tie::IxHash|Tie::IxHash> module. If both are
installed, Convert::Binary::C will give preference
to L<Tie::Hash::Indexed|Tie::Hash::Indexed> because
it's faster.

When using this option, you should keep in mind that
tied hashes are significantly slower and consume
more memory than ordinary hashes, even when the class
they're tied to is implemented efficiently. So don't
turn this option on if you don't have to.

You can also influence hash member ordering by using
the L<C<CBC_ORDER_MEMBERS>|/"CBC_ORDER_MEMBERS"> environment
variable.

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

=item C<def> NAME

=item C<def> TYPE

If you need to know if a definition for a certain type name
exists, use this method. You pass it the name of an enum,
struct, union or typedef, and it will return a non-empty
string being either C<"enum">, C<"struct">, C<"union">,
or C<"typedef"> if there's a definition for the type in
question, an empty string if there's no such definition,
or C<undef> if the name is completely unknown. If the
type can be interpreted as a basic type, C<"basic"> will
be returned.

If you pass in a L<TYPE|/"UNDERSTANDING TYPES">, the output
will be slightly different. If the specified member exists,
the L<C<def>|/"def"> method will return C<"member">. If the
member doesn't exist, or if the type cannot have members, the
empty string will be returned. Again, if the name of the type
is completely unknown, C<undef> will be returned. This may be
useful if you want to check if a certain member exists within
a compound, for example.

  use Convert::Binary::C;
  
  my $c = Convert::Binary::C->new->parse( <<'ENDC' );
  
  typedef struct __not  not;
  typedef struct __not *ptr;
  
  struct foo {
    enum bar *xxx;
  };
  
  typedef int quad[4];
  
  ENDC
  
  for my $type ( qw( not ptr foo bar xxx foo.xxx foo.abc
                     xxx.yyy quad quad[3] quad[4] short[1] ),
                 'unsigned long' )
  {
    my $def = $c->def( $type );
    printf "%-14s  =>  %s\n", $type, defined $def
                                     ? "'$def'" : 'undef';
  }

The following would be returned by the L<C<def>|/"def"> method:

  not             =>  ''
  ptr             =>  'typedef'
  foo             =>  'struct'
  bar             =>  ''
  xxx             =>  undef
  foo.xxx         =>  'member'
  foo.abc         =>  ''
  xxx.yyy         =>  undef
  quad            =>  'typedef'
  quad[3]         =>  'member'
  quad[4]         =>  ''
  short[1]        =>  undef
  unsigned long   =>  'basic'

So, if L<C<def>|/"def"> returns a non-empty string, you can safely use
any other method with that type's name or with that member expression.

In cases where the typedef namespace overlaps with the
namespace of enums/structs/unions, the L<C<def>|/"def"> method
will give preference to the typedef and will thus return
the string C<"typedef">. You could however force interpretation
as an enum, struct or union by putting C<"enum">, C<"struct">
or C<"union"> in front of the type's name.

=back

=head2 pack

=over 8

=item C<pack> TYPE

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
set to zero in the packed byte string. If you pass C<undef> as
or simply omit the second parameter, the whole string will be
initialized with zero bytes. On success, the packed byte
string is returned.

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

If L<TYPE|/"UNDERSTANDING TYPES"> refers to a compound object,
you may pack any member of that compound object. Simply add
a L<member expression|/"Member Expressions"> to the type
name, just as you would access the member in C:

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
      long *quad;
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

If L<TYPE|/"UNDERSTANDING TYPES"> refers to a compound object,
you may unpack any member of that compound object. Simply add
a L<member expression|/"Member Expressions"> to the type
name, just as you would access the member in C:

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

When L<C<unpack>|/"unpack"> is called in list context, it will
unpack as many elements as possible from STRING, including zero
if STRING is not long enough.

=back

=head2 sizeof

=over 8

=item C<sizeof> TYPE

This method will return the size of a C type in bytes.
If it cannot find the type, it will throw an exception.

If the type defines some kind of compound object, you may
ask for the size of a L<member|/"Member Expressions"> of
that compound object:

  $size = $c->sizeof( 'test.uni.word[1]' );

This would set C<$size> to C<2>.

=back

=head2 typeof

=over 8

=item C<typeof> TYPE

This method will return the type of a C member.
While this only makes sense for compound types, it's legal
to also use it for non-compound types.
If it cannot find the type, it will throw an exception.

The L<C<typeof>|/"typeof"> method can be used on any
valid L<member|/"Member Expressions">, even on arrays or
unnamed types. It will always return a string that holds
the name (or in case of unnamed types only the class) of
the type, optionally followed by a C<'*'> character to
indicate it's a pointer type, and optionally followed by
one or more array dimensions if it's an array type. If
the type is a bitfield, the type name is followed by a
colon and the number of bits.

  struct test {
    char    ary[3];
    union {
      short word[2];
      long *quad;
    }       uni;
    struct {
      unsigned short six:6;
      unsigned short ten:10;
    }       bits;
  };

Given the above C code has been parsed, calls
to L<C<typeof>|/"typeof"> would return the following
values:

  $c->typeof('test')             => 'struct test'
  $c->typeof('test.ary')         => 'char [3]'
  $c->typeof('test.uni')         => 'union'
  $c->typeof('test.uni.quad')    => 'long *'
  $c->typeof('test.uni.word')    => 'short [2]'
  $c->typeof('test.uni.word[1]') => 'short'
  $c->typeof('test.bits')        => 'struct'
  $c->typeof('test.bits.six')    => 'unsigned short :6'
  $c->typeof('test.bits.ten')    => 'unsigned short :10'

=back

=head2 offsetof

=over 8

=item C<offsetof> TYPE, MEMBER

You can use L<C<offsetof>|/"offsetof"> just like the C macro
of same denominator. It will simply return the offset (in bytes)
of L<MEMBER|/"Member Expressions"> relative to L<TYPE|/"UNDERSTANDING TYPES">.

  use Convert::Binary::C;
  
  $c = Convert::Binary::C->new( Alignment   => 4
                              , LongSize    => 4
                              , PointerSize => 4
                              )
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
  
  @args = (
    ['test',        'zap[5].day'  ],
    ['test.zap[2]', 'day'         ],
    ['test',        'zap[5].day+1'],
  );
  
  for( @args ) {
    my $offset = eval { $c->offsetof( @$_ ) };
    printf "\$c->offsetof( '%s', '%s' ) => $offset\n", @$_;
  }

The final loop will print:

  $c->offsetof( 'test', 'zap[5].day' ) => 64
  $c->offsetof( 'test.zap[2]', 'day' ) => 4
  $c->offsetof( 'test', 'zap[5].day+1' ) => 65

=over 2

=item *

The first iteration simply shows that the offset
of C<zap[5].day> is 64 relative to the beginning
of C<struct test>.

=item *

You may additionally specify a member for the type
passed as the first argument, as shown in the second
iteration.

=item *

Even the L<offset suffix|/"Offsets"> is supported
by L<C<offsetof>|/"offsetof">, so the third iteration
will correctly print 65.

=back

Unlike the C macro, L<C<offsetof>|/"offsetof"> also works
on array types.

  $offset = $c->offsetof( 'test.zap', '[3].ptr+2' );
  print "offset = $offset";

This will print:

  offset = 46

If L<TYPE|/"UNDERSTANDING TYPES"> is a
compound, L<MEMBER|/"Member Expressions"> may
optionally be prefixed with a dot, so

  printf "offset = %d\n", $c->offsetof( 'week', 'day' );
  printf "offset = %d\n", $c->offsetof( 'week', '.day' );

are both equivalent and will print

  offset = 4
  offset = 4

This allows to

=over 2

=item *

use the C macro style, without a leading dot, and

=item *

directly use the output of the L<C<member>|/"member"> method,
which includes a leading dot for compound types, as input for
the L<MEMBER|/"Member Expressions"> argument.

=back

=back

=head2 member

=over 8

=item C<member> TYPE

=item C<member> TYPE, OFFSET

You can think of L<C<member>|/"member"> as being the reverse
of the L<C<offsetof>|/"offsetof"> method. However, as this is
more complex, there's no equivalent to L<C<member>|/"member"> in
the C language.

Usually this method is used if you want to retrieve the name of
the member that is located at a specific offset of a previously
parsed type.

  use Convert::Binary::C;
  
  $c = Convert::Binary::C->new( Alignment   => 4
                              , LongSize    => 4
                              , PointerSize => 4
                              )
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
    print $@ ? "\n  exception: $@" : " => '$member'\n";
  }

This will print:

  $c->member( 'test', 24 ) => '.zap[2].abc'
  $c->member( 'test', 39 ) => '.zap[3]+3'
  $c->member( 'test', 69 ) => '.zap[5].ptr+1'
  $c->member( 'test', 99 )
    exception: Offset 99 out of range (0 <= offset < 96) 

=over 2

=item *

The output of the first iteration is obvious. The
member C<zap[2].abc> is located at offset 24 of C<struct test>.

=item *

In the second iteration, the offset points into a region
of padding bytes and thus no member of C<week> can be
named. Instead of a member name the offset relative
to C<zap[3]> is appended.

=item *

In the third iteration, the offset points to C<zap[5].ptr>.
However, C<zap[5].ptr> is located at 68, not at 69,
and thus the remaining offset of 1 is also appended.

=item *

The last iteration causes an exception because the offset
of 99 is not valid for C<struct test> since the size
of C<struct test> is only 96.

=back

You can additionally specify a member for the type passed
as the first argument:

  $member = $c->member('test.zap[2]', 6);
  print $member;

This will print:

  .day+2

Like L<C<offsetof>|/"offsetof">, L<C<member>|/"member"> also
works on array types:

  $member = $c->member('test.zap', 42);
  print $member;

This will print:

  [3].day+2

While the behaviour for C<struct>s is quite obvious, the behaviour
for C<union>s is rather tricky. As a single offset usually references
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

the L<C<member>|/"member"> method would return what is shown in
the I<Member> column of the following table. The I<Type> column
shows the result of the L<C<typeof>|/"typeof"> method when passing
the corresponding member.

  Offset   Member               Type
  --------------------------------------
     0     .apple.color[0]      'char'
     1     .apple.color[1]      'char'
     2     .grape[2]            'char'
     3     .melon.weight+3      'long'
     4     .apple.size          'long'
     5     .apple.size+1        'long'
     6     .melon.price[1]      'short'
     7     .apple.size+3        'long'
     8     .apple.taste         'char'
     9     .melon.price[2]+1    'short'
    10     .apple+10            'struct'
    11     .apple+11            'struct'

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

Alternatively, if you're not only interested in the I<best> member,
you can call L<C<member>|/"member"> in list context, which makes it
return I<all> members referenced by the given offset.

  Offset   Member               Type
  --------------------------------------
     0     .apple.color[0]      'char'
           .grape[0]            'char'
           .melon.weight        'long'
     1     .apple.color[1]      'char'
           .grape[1]            'char'
           .melon.weight+1      'long'
     2     .grape[2]            'char'
           .melon.weight+2      'long'
           .apple+2             'struct'
     3     .melon.weight+3      'long'
           .apple+3             'struct'
     4     .apple.size          'long'
           .melon.price[0]      'short'
     5     .apple.size+1        'long'
           .melon.price[0]+1    'short'
     6     .melon.price[1]      'short'
           .apple.size+2        'long'
     7     .apple.size+3        'long'
           .melon.price[1]+1    'short'
     8     .apple.taste         'char'
           .melon.price[2]      'short'
     9     .melon.price[2]+1    'short'
           .apple+9             'struct'
    10     .apple+10            'struct'
           .melon+10            'struct'
    11     .apple+11            'struct'
           .melon+11            'struct'

The first member returned is always the I<best> member. The other
members are sorted according to the rules given above. This means
that members referenced without an offset are followed by members
referenced with an offset. Padding regions will be at the end.

If OFFSET is not given in the method call, L<C<member>|/"member"> will
return a list of I<all> possible members of L<TYPE|/"UNDERSTANDING TYPES">.

  print "$_\n" for $c->member( 'choice' );

This will print:

  .apple.color[0]
  .apple.color[1]
  .apple.size
  .apple.taste
  .grape[0]
  .grape[1]
  .grape[2]
  .melon.weight
  .melon.price[0]
  .melon.price[1]
  .melon.price[2]

In scalar context, the number of possible members is returned.

=back

=head2 initializer

=over 8

=item C<initializer> TYPE

=item C<initializer> TYPE, DATA

The L<C<initializer>|/"initializer"> method can be used retrieve
an initializer string for a certain L<TYPE|/"UNDERSTANDING TYPES">.
This can be useful if you have to initialize only a couple of
members in a huge compound type or if you simply want to generate
initializers automatically.

  struct date {
    unsigned year : 12;
    unsigned month:  4;
    unsigned day  :  5;
    unsigned hour :  5;
    unsigned min  :  6;
  };
  
  typedef struct {
    enum { DATE, QWORD } type;
    short number;
    union {
      struct date   date;
      unsigned long qword;
    } choice;
  } data;

Given the above code has been parsed

  $init = $c->initializer( 'data' );
  print "data x = $init;\n";

would print the following:

  data x = {
  	0,
  	0,
  	{
  		{
  			0,
  			0,
  			0,
  			0,
  			0
  		}
  	}
  };

You could directly put that into a C program, although it probably
isn't very useful yet. It becomes more useful if you actually specify
how you want to initialize the type:

  $data = {
    type   => 'QWORD',
    choice => {
      date  => { month => 12, day => 24 },
      qword => 4711,
    },
    stuff => 'yes?',
  };
  
  $init = $c->initializer( 'data', $data );
  print "data x = $init;\n";

This would print the following:

  data x = {
  	QWORD,
  	0,
  	{
  		{
  			0,
  			12,
  			24,
  			0,
  			0
  		}
  	}
  };

As only the first member of a C<union> can be initialized, C<choice.qword> is
ignored. You will not be warned about the fact that you probably tried
to initialize a member other than the first. This is considered
a feature, because it allows you to use L<C<unpack>|/"unpack"> to generate
the initializer data:

  $data = $c->unpack( 'data', $binary );
  $init = $c->initializer( 'data', $data );

Since L<C<unpack>|/"unpack"> unpacks all union members, you would
otherwise have to delete all but the first one previous to feeding
it into L<C<initializer>|/"initializer">.

Also, C<stuff> is ignored, because it actually isn't a member
of C<data>. You won't be warned about that either.

=back

=head2 dependencies

=over 8

=item C<dependencies>

After some code has been parsed using either
the L<C<parse>|/"parse"> or L<C<parse_file>|/"parse_file"> methods,
the L<C<dependencies>|/"dependencies"> method can be used to
retrieve information about all files that the object
depends on, i.e. all files that have been parsed.

In scalar context, the method returns a hash reference.
Each key is the name of a file. The values are again hash
references, each of which holds the size, modification
time (mtime), and change time (ctime) of the file at the
moment it was parsed.

  use Convert::Binary::C;
  use Data::Dumper;
  
  #----------------------------------------------------------
  # Create object, set include path, parse 'string.h' header
  #----------------------------------------------------------
  my $c = Convert::Binary::C->new
          ->Include( '/usr/lib/gcc-lib/i686-pc-linux-gnu/3.3.3/include',
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
      'ctime' => 1092288224,
      'mtime' => 1092288215,
      'size' => 10792
    },
    '/usr/include/sys/cdefs.h' => {
      'ctime' => 1092288222,
      'mtime' => 1092288215,
      'size' => 8600
    },
    '/usr/include/gnu/stubs.h' => {
      'ctime' => 1092288221,
      'mtime' => 1092288215,
      'size' => 818
    },
    '/usr/lib/gcc-lib/i686-pc-linux-gnu/3.3.3/include/stddef.h' => {
      'ctime' => 1086789971,
      'mtime' => 1086789970,
      'size' => 12695
    },
    '/usr/include/string.h' => {
      'ctime' => 1092288224,
      'mtime' => 1092288215,
      'size' => 15011
    }
  };
  @files = (
    '/usr/include/features.h',
    '/usr/include/sys/cdefs.h',
    '/usr/include/gnu/stubs.h',
    '/usr/lib/gcc-lib/i686-pc-linux-gnu/3.3.3/include/stddef.h',
    '/usr/include/string.h'
  );

In list context, the method returns the names of all
files that have been parsed, i.e. the following lines
are equivalent:

  @files = keys %{$c->dependencies};
  @files = $c->dependencies;

=back

=head2 sourcify

=over 8

=item C<sourcify>

=item C<sourcify> CONFIG

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
  	} storage;
  #pragma pack( pop )
  	mytype *next;
  };

The purpose of the L<C<sourcify>|/"sourcify"> method is to enable
some kind of platform-independent caching. The C code generated
by L<C<sourcify>|/"sourcify"> can be parsed by a standard C compiler,
as well as of course the Convert::Binary::C parser. However, it might
be significantly shorter than the code that has originally been parsed.
When parsing a typical header file, it's easily possible that you need
to open dozens of other files that are included from that file, and
end up parsing several hundred kilobytes of C code. Since most of it
is usually preprocessor directives, function prototypes and comments,
the L<C<sourcify>|/"sourcify"> function strips this down to a few
kilobytes. Saving the L<C<sourcify>|/"sourcify"> string and parsing
it next time instead of the original code may be a lot faster.

The L<C<sourcify>|/"sourcify"> method takes a hash reference as an
optional argument. It can be used to tweak the method's output.
The following options can be configured.

=over 4

=item C<Context> =E<gt> 0 | 1

Turns preprocessor context information on or off. If this is turned
on, L<C<sourcify>|/"sourcify"> will insert C<#line> preprocessor
directives in its output. So in the above example

  print $c->sourcify( { Context => 1 } );

would print:

  /* typedef predeclarations */
  
  typedef struct _mytype mytype;
  
  /* defined enums */
  
  
  #line 20 "[buffer]"
  enum count
  {
  	ZERO,
  	ONE,
  	TWO,
  	THREE
  };
  
  
  /* defined structs and unions */
  
  
  #line 6 "[buffer]"
  struct _mytype
  {
  #line 7 "[buffer]"
  	union
  	{
  		int iCount;
  		enum count *pCount;
  	} counter;
  #pragma pack( push, 1 )
  #line 12 "[buffer]"
  	struct
  	{
  		char string[42];
  		int array[10];
  	} storage;
  #pragma pack( pop )
  	mytype *next;
  };

Note that C<"[buffer]"> refers to the here-doc buffer when
using L<C<parse>|/"parse">.

=back

=back

The following methods can be used to retrieve information about the
definitions that have been parsed. The examples given in the description
for L<C<enum>|/"enum">, L<C<compound>|/"compound"> and L<C<typedef>|/"typedef"> all
assume this piece of C code has been parsed:

  typedef unsigned long U32;
  typedef void *any;
  
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
    U32   sv_refcnt;
    U32   sv_flags;
  };
  
  typedef union {
    int abc[2];
    struct xxx {
      int a;
      int b;
    }   ab[3][4];
    any ptr;
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
references for those enumerations. The enumeration
identifiers may optionally be prefixed by C<enum>.

If an enumeration identifier cannot be found, a
warning is issued and the returned list will contain
an undefined value at that position.

In scalar context, the number of enumerations will
be returned as long as the number of arguments to
the method call is not 1. In the latter case, a
hash reference holding information for the enumeration
will be returned.

The list returned by the L<C<enum>|/"enum"> method looks
similar to this:

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
      'context' => 'definitions.c(4)',
      'sign' => 0
    }
  );

=over 4

=item C<identifier>

holds the enumeration identifier. This key is not
present if the enumeration has no identifier.

=item C<context>

is the context in which the enumeration is defined. This
is the filename followed by the line number in parentheses.

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
references for those compounds. The identifiers may
optionally be prefixed by C<struct> or C<union>,
which limits the search to the specified kind of
compound.

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
      'context' => 'definitions.c(14)',
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
      'context' => 'definitions.c(22)',
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
      'context' => 'definitions.c(20)',
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
        },
        {
          'declarators' => [
            {
              'declarator' => 'ptr',
              'size' => 4,
              'offset' => 0
            }
          ],
          'type' => 'any'
        }
      ],
      'size' => 96
    }
  );

=over 4

=item C<identifier>

holds the struct or union identifier. This
key is not present if the compound has no identifier.

=item C<context>

is the context in which the struct or union is defined. This
is the filename followed by the line number in parentheses.

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
This is equivalent to calling L<C<compound_names>|"compound_names">, just
that it only returns the names of the struct identifiers and
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
This is equivalent to calling L<C<compound_names>|"compound_names">, just
that it only returns the names of the union identifiers and
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
      'declarator' => '*any',
      'type' => 'void'
    },
    {
      'declarator' => 'test',
      'type' => {
        'align' => 1,
        'context' => 'definitions.c(20)',
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
          },
          {
            'declarators' => [
              {
                'declarator' => 'ptr',
                'size' => 4,
                'offset' => 0
              }
            ],
            'type' => 'any'
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

=head2 add_hooks

=over 8

=item C<add_hooks> TYPE =E<gt> { HOOK =E<gt> SUB, HOOK =E<gt> [SUB, ARGS], ... }, ...

This method allows you to register subroutines as hooks.
Hooks are called whenever a certain C<TYPE> is packed or
unpacked. Hooks are currently considered an experimental
feature.

You can register hooks for all types except for basic types.
This means you cannot register a hook for C<int>. C<TYPE> is
the type you want to register a hook for. C<HOOK> can be one
of the following:

  pack
  unpack
  pack_ptr
  unpack_ptr

C<'pack'> and C<'unpack'> hooks are called when processing
their C<TYPE>, while C<'pack_ptr'> and C<'unpack_ptr'> hooks
are called when processing pointers to their C<TYPE>.

C<SUB> is a reference to a subroutine that takes one input
argument, processes it and returns one output argument.
Alternatively, you can pass custom arguments to the hook by
passing an array reference instead of C<SUB> that holds the
subroutine reference in the first element and the arguments
to be passed to the subroutine as the other elements. With
the latter alternative, you can even pass special arguments
to the hook using L<C<arg>|/"arg">.

You can register hooks for as many types as you like with
one call to L<C<add_hooks>|/"add_hooks">:

  $c->add_hooks(ObjectType => { pack   => \&obj_pack,
                                unpack => \&obj_unpack },
                ProtocolId => { unpack => sub {
                                  $protos[$_[0]]
                                },
                                unpack_ptr => [sub {
                                  sprintf "$_[0]:{0x%X}", $_[1]
                                }, $c->arg('TYPE', 'DATA')] });

To remove registered hooks, use
either L<C<delete_hooks>|/"delete_hooks"> or L<C<delete_all_hooks>|/"delete_all_hooks">.

You can also use L<C<add_hooks>|/"add_hooks"> to update
hooks for types already registered. To remove only a single
subroutine, pass C<undef> instead of a subroutine reference.

  $c->add_hooks(ObjectType => { pack => undef });

If all subroutines are removed, the whole hook is removed.

L<C<add_hooks>|/"add_hooks"> will throw an exception if an
error occurs. On success, the method returns a reference to
its object.

See L<"USING HOOKS"> for examples on how to use hooks.

=back

=head2 delete_hooks

=over 8

=item C<delete_hooks> LIST

Deletes the hooks for all types passed in.

  $c->delete_hooks(qw(ObjectType ProtocolId));

L<C<delete_hooks>|/"delete_hooks"> will throw an exception if an
error occurs. On success, the method returns a reference to
its object.

=back

=head2 delete_all_hooks

=over 8

=item C<delete_all_hooks>

Removes all registered hooks and returns a reference to its object.

=back

=head2 arg

=over 8

=item C<arg> 'ARG', ...

Creates placeholders for special arguments to be passed to hook
subroutines. These arguments are currently:

=over 4

=item C<SELF>

A reference to the calling Convert::Binary::C object. This may be
useful if you need to work with the object inside the hook.

=item C<TYPE>

The name of the type that is currently being processed by the hook.

=item C<DATA>

The data argument that is usually passed to the hook.

=item C<HOOK>

The type of the hook as which the hook has been called,
e.g. C<pack> or C<unpack_ptr>.

=back

L<C<arg>|/"arg"> will return a placeholder for each argument it is
being passed.

=back

=head1 FUNCTIONS

You can alternatively call the following functions as methods
on Convert::Binary::C objects.

=head2 Convert::Binary::C::feature

=over 8

=item C<feature> STRING

Checks if Convert::Binary::C was built with certain features.
For example,

  print "debugging version"
      if Convert::Binary::C::feature('debug');

will check if Convert::Binary::C was built with debugging support
enabled. The C<feature> function returns C<1> if the feature is
enabled, C<0> if the feature is disabled, and C<undef> if the
feature is unknown. Currently the only features that can be checked
are C<ieeefp>, C<debug> and C<threads>.

You can enable or disable certain features at compile time of the
module by using the

  perl Makefile.PL enable-feature disable-feature

syntax.

=back

=head2 Convert::Binary::C::native

=over 8

=item C<native>

=item C<native> STRING

Returns the value of a property of the native system that
Convert::Binary::C was built on. For example,

  $size = Convert::Binary::C::native('IntSize');

will fetch the size of an C<int> on the native system.
The following properties can be queried:

  Alignment
  ByteOrder
  CompoundAlignment
  DoubleSize
  EnumSize
  FloatSize
  IntSize
  LongDoubleSize
  LongLongSize
  LongSize
  PointerSize
  ShortSize

You can also call L<C<native>|/"native"> without arguments,
in which case it will return a reference to a hash with all
properties, like:

  $native = {
    'ByteOrder' => 'LittleEndian',
    'LongSize' => 4,
    'IntSize' => 4,
    'ShortSize' => 2,
    'FloatSize' => 4,
    'Alignment' => 4,
    'LongLongSize' => 8,
    'LongDoubleSize' => 12,
    'DoubleSize' => 8,
    'EnumSize' => 4,
    'CompoundAlignment' => 1,
    'PointerSize' => 4
  };

The contents of that hash are suitable for passing them to
the L<C<configure>|/"configure"> method.

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
amount.

=head2 Debugging options

Instead of saying C<all>, you can pass a string that
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

=head2 Redirecting debug output

By default, all debug output is written to C<stderr>. You
can, however, redirect the debug output to a file with
the C<debugfile> option:

  use Convert::Binary::C debug     => 'dcthHm',
                         debugfile => './debug.out';

If the file cannot be opened, you'll receive a warning and
the output will go the C<stderr> way again.

Alternatively, you can use the environment
variables L<C<CBC_DEBUG_OPT>|/"CBC_DEBUG_OPT"> and L<C<CBC_DEBUG_FILE>|/"CBC_DEBUG_FILE"> to
turn on debug output.

If Convert::Binary::C is built without debugging support,
passing the C<debug> or C<debugfile> options will cause
a warning to be issued. The corresponding environment
variables will simply be ignored.

=head1 ENVIRONMENT

=head2 C<CBC_ORDER_MEMBERS>

Setting this variable to a non-zero value will globally
turn on hash key ordering for compound members. Have a
look at the C<OrderMembers> option for details.

Setting the variable to the name of a perl module will
additionally use this module instead of the predefined
modules for member ordering to tie the hashes to.

=head2 C<CBC_DEBUG_OPT>

If Convert::Binary::C is built with debugging
support, you can use this variable to specify
the L<debugging options|/"Debugging options">.

=head2 C<CBC_DEBUG_FILE>

If Convert::Binary::C is built with debugging support,
you can use this variable to L<redirect|/"Redirecting debug output"> the
debug output to a file.

=head2 C<CBC_DISABLE_PARSER>

This variable is intended purely for development. Setting
it to a non-zero value disables the Convert::Binary::C parser,
which means that no information is collected from the file
or code that is parsed. However, the preprocessor will run,
which is useful for benchmarking the preprocessor.

=head1 FLEXIBLE ARRAY MEMBERS AND INCOMPLETE TYPES

Flexible array members are a feature introduced with ISO-C99.
It's a common problem that you have a variable length data
field at the end of a structure, for example an array of
characters at the end of a message struct. ISO-C99 allows
you to write this as:

  struct message {
    long header;
    char data[];
  };

The advantage is that you clearly indicate that the size
of the appended data is variable, and that the C<data> member
doesn't contribute to the size of the C<message> structure.

When packing or unpacking data, Convert::Binary::C deals with
flexible array members as if their length was adjustable. For
example, L<C<unpack>|/"unpack"> will adapt the length of the
array depending on the input string:

  $msg1 = $c->unpack('message', 'abcdefg');
  $msg2 = $c->unpack('message', 'abcdefghijkl');

The following data is unpacked:

  $msg1 = {
    'data' => [
      101,
      102,
      103
    ],
    'header' => 1633837924
  };
  $msg2 = {
    'data' => [
      101,
      102,
      103,
      104,
      105,
      106,
      107,
      108
    ],
    'header' => 1633837924
  };

Similarly, pack will adjust the length of the output string
according to the data you feed in:

  use Data::Hexdumper;
  
  $msg = {
    header => 4711,
    data   => [0x10, 0x20, 0x30, 0x40, 0x77..0x88],
  };
  
  $data = $c->pack('message', $msg);
  
  print hexdump(data => $data);

This would print:

    0x0000 : 00 00 12 67 10 20 30 40 77 78 79 7A 7B 7C 7D 7E : ...g..0@wxyz{|}~
    0x0010 : 7F 80 81 82 83 84 85 86 87 88                   : ..........

Incomplete types such as

  typedef unsigned long array[];

are handled in exactly the same way. Thus, you can easily

  $array = $c->unpack('array', '?'x20);

which will unpack the following array:

  $array = [
    1061109567,
    1061109567,
    1061109567,
    1061109567,
    1061109567
  ];

=head1 FLOATING POINT VALUES

When using Convert::Binary::C to handle floating point values,
you have to be aware of some limitations.

You're usually safe if all your platforms are using the IEEE
floating point format. During the Convert::Binary::C build
process, the C<ieeefp> feature will automatically be enabled
if the host is using IEEE floating point. You can check for
this feature at runtime using
the L<C<feature>|/"Convert::Binary::C::feature"> function:

  if (Convert::Binary::C::feature('ieeefp')) {
    # do something
  }

When IEEE floating point support is enabled, the module can
also handle floating point values of a different byteorder.

If your host platform is not using IEEE floating point,
the C<ieeefp> feature will be disabled. Convert::Binary::C
then will be more restrictive, refusing to handle any
non-native floating point values.

However, Convert::Binary::C cannot detect the floating point
format used by your target platform. It can only try to
prevent problems in obvious cases. If you know your target
platform has a completely different floating point format,
don't use floating point conversion at all.

Whenever Convert::Binary::C detects that it cannot properly
do floating point value conversion, it will issue a warning
and will not attempt to convert the floating point value.

=head1 BITFIELDS

Bitfields are currently not supported by Convert::Binary::C,
because I generally don't use them. I plan to support them
in a later release, when I will have found an easy way of
integrating them into the module.

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
      'context' => 'bitfields.c(1)',
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

=head1 INHERITANCE

If you wish to derive a new class from Convert::Binary::C,
this is relatively easy. Despite their XS implementation,
Convert::Binary::C objects are actually blessed hash
references.

The XS data is stored in a read-only hash value for the
key that is the empty string. So it is safe to use any
non-empty hash key when deriving your own class.
In addition, Convert::Binary::C does quite a lot of checks
to detect corruption in the object hash.

If you store private data in the hash, you should override
the C<clone> method and provide the necessary code to clone
your private data. You'll have to call C<SUPER::clone>, but
this will only clone the Convert::Binary::C part of the object.

For an example of a derived class, you can have a look at
Convert::Binary::C::Cached.

=head1 PORTABILITY

Convert::Binary::C should build and run on most of the
platforms that Perl runs on:

=over 4

=item *

Various Linux systems

=item *

Various BSD systems

=item *

HP-UX

=item *

Compaq/HP Tru64 Unix

=item *

Mac-OS X

=item *

Cygwin

=item *

Windows 98/NT/2000/XP

=back

Also, many architectures are supported:

=over 4

=item *

Various Intel Pentium and Itanium systems

=item *

Various Alpha systems

=item *

HP PA-RISC

=item *

Power-PC

=item *

StrongARM

=back

The module should build with any perl binary from 5.5.3
up to the latest development version.

=head1 COMPARISON WITH SIMILAR MODULES

Most of the time when you're really looking for
Convert::Binary::C you'll actually end up finding
one of the following modules. Some of them have
different goals, so it's probably worth pointing
out the differences.

=head2 C::Include

Like Convert::Binary::C, this module aims at doing
conversion from an to binary data based on C types.
However, its configurability is very limited compared
to Convert::Binary::C. Also, it does not parse all C
code correctly. It's slower than Convert::Binary::C,
doesn't have a preprocessor. On the plus side, it's
written in pure Perl.

=head2 C::DynaLib::Struct

This module doesn't allow you to reuse your C source
code. One main goal of Convert::Binary::C was to avoid
code duplication or, even worse, having to maintain
different representations of your data structures.
Like C::Include, C::DynaLib::Struct is rather limited
in its configurability.

=head2 Win32::API::Struct

This module has a special purpose. It aims at building
structs for interfacing Perl code with Windows API code.

=head1 CREDITS

=over 2

=item *

My love Jennifer for always being there, for filling my life with
joy and last but not least for proofreading the documentation.

=item *

Alain Barbet E<lt>alian@cpan.orgE<gt> for testing and debugging
support.

=item *

Mitchell N. Charity for giving me pointers into various
interesting directions.

=item *

Alexis Denis for making me improve (externally) and simplify
(internally) floating point support. He can also be blamed
(indirectly) for the L<C<initializer>|/"initializer"> method,
as I need it in my effort to support bitfields some day.

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

Gisbert W. Selke for spotting some interesting bugs and providing
extensive reports.

=item *

Steffen Zimmermann for a prolific discussion on the cloning
algorithm.

=back

=head1 BUGS

I'm sure there are still lots of bugs in the code for this
module. If you find any bugs, Convert::Binary::C doesn't
seem to build on your system or any of its tests fail, please
use the CPAN Request Tracker at L<http://rt.cpan.org/> to
create a ticket for the module. Alternatively, just send a
mail to E<lt>mhx@cpan.orgE<gt>.

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

If you feel that sending a postcard is too much effort, you maybe
want to rate the module at L<http://cpanratings.perl.org/>.

=head1 COPYRIGHT

Copyright (c) 2002-2004 Marcus Holland-Moritz. All rights reserved.
This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

The C<ucpp> library is (c) 1998-2002 Thomas Pornin. For license
and redistribution details refer to F<ctlib/ucpp/README>.

Portions copyright (c) 1989, 1990 James A. Roskind.

The include files located in F<t/include/include>, which are used
in some of the test scripts are (c) 1991-1999, 2000, 2001 Free Software
Foundation, Inc. They are neither required to create the binary nor
linked to the source code of this module in any other way.

=head1 SEE ALSO

See L<ccconfig>, L<perl>, L<perldata>, L<perlop>, L<perlvar>, L<Data::Dumper> and L<Scalar::Util>.

=cut


