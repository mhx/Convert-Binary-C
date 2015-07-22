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
# $Date: 2002/08/21 14:58:23 +0100 $
# $Revision: 9 $
# $Snapshot: /Convert-Binary-C/0.02 $
# $Source: /lib/Convert/Binary/C.pm $
#
################################################################################
# 
# Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
# 
################################################################################

package Convert::Binary::C;

use strict;
use DynaLoader;
use Carp;
use vars qw( @ISA $VERSION $AUTOLOAD );

@ISA = qw(DynaLoader);
$VERSION = do{my@r='$Snapshot: /Convert-Binary-C/0.02 $'=~/(\d+\.\d+)/;@r?$r[0]:'9.99'};

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
  @_ <= 1 or croak "$opt can't take more than one argument";
  unless( @_ or defined wantarray ) {
    carp "Useless use of $opt in void context";
    return;
  }
  eval { $opt = $self->configure( $opt, @_ ) };
  $@ =~ s/\s+at.*?C\.pm.*//s, croak $@ if $@;
  $opt;
}

1;

__END__

=head1 NAME

Convert::Binary::C - Binary Data Conversion using C Types

=head1 SYNOPSIS

  use Convert::Binary::C;
  
  $c = new Convert::Binary::C ByteOrder => 'BigEndian',
                              Alignment => 8;
  
  $c->configure( Include => ['/usr/include'],
                 Define  => ['FOOBAR=12345'] );
  
  $c->parse_file( $file );
  $c->Alignment( 2 );
  
  $p = $c->unpack( 'MyType', $data );
  $s = $c->sizeof( 'BigType' );
  $m = $c->member( 'AnotherType', 5 );

=head1 DESCRIPTION

Convert::Binary::C is a preprocessor and parser for C type
definitions. It is highly configurable and should support
arbitrarily complex data structures. Its OO interface has pack
and unpack methods that act as replacements for Perl's pack
and unpack and allow to use the C types instead of a string
representation of the data structure for conversion of binary
data from and to Perl's complex data structures.

Actually, what Convert::Binary::C does is not very different
from what a C compiler does, just that it doesn't compile the
source code into an object file or executable, but only parses
the code and allows Perl to use the enumerations, structs and
typedefs that have been defined within your C source for binary
data conversion, similar to Perl's pack and unpack.

Beyond that, the module offers a lot of convenience methods
to retrieve information about the C types that have been parsed.

=head2 Why Convert::Binary::C?

Say you want to pack (or unpack) data according to the following
C structure:

  struct foo {
    char ary[3];
    unsigned short baz;
    int bar;
  };

You could of course use Perl's C<pack> and C<unpack> functions:

  @ary = (1, 2, 3);
  $baz = 40000;
  $bar = -4711;
  $foo = pack 'c3 S i', @ary, $baz, $bar;

But this implies that the struct members are byte aligned. If
they were long aligned (which is the default for most compilers),
you'd have to write

  $foo = pack 'c3 x S x2 i', @ary, $baz, $bar;

which doesn't really increase readability.

Now imagine that you need to pack the data for a completely
different architecture with different byte order. You would
look into the C<pack> manpage again and perhaps come up with
this:

  $foo = pack 'c3 x n x2 N', @ary, $baz, $bar;

However, if you try to unpack $foo again, your signed values
have turned into unsigned ones.

All this can still be managed with Perl. But imagine your
structures get more complex? Imagine you need to support
different platforms? Imagine you need to make changes to
the structures? You'll not only have to change the C source
but also dozens of C<pack> strings in your Perl code. This
is no fun. And Perl should be fun.

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

  $obj = Convert::Binary::C->new;

or

  $obj = new Convert::Binary::C;

You can optionally pass configuration options to the
constructor as described in the next section.

=head2 Configuring the object

To configure a Convert::Binary::C object, you can either call
the C<configure> method or directly pass the configuration
options to the constructor. If you want to change byte order
and alignment, you can use

  $obj->configure( ByteOrder => 'LittleEndian',
                   Alignment => 2 );

or you can change the construction code to

  $obj = new Convert::Binary::C ByteOrder => 'LittleEndian',
                                Alignment => 2;

Either way, the object will now know that it should use
little endian (Intel) byte order and 2-byte struct member
alignment for packing and unpacking.

Alternatively, you can use the option names as names of
methods to configure the object, like:

  $obj->ByteOrder( 'LittleEndian' );

You can also retrieve information about the current
configuration of a Convert::Binary::C object. For details,
see the section about the C<configure> method.

=head2 Parsing C code

Convert::Binary::C allows two ways of parsing C source. Either
by parsing external C source files:

  $obj->parse_file( 'foo.h' );

Or by parsing C code embedded in your script:

  $obj->parse( <<'CCODE' );
  struct foo {
    char ary[3];
    unsigned short baz;
    int bar;
  };
  CCODE

Now $obj will know about the C<foo> struct.

=head2 Packing and unpacking

Convert::Binary::C has two methods, C<pack> and C<unpack>,
that act similar to the functions of same denominator in Perl.
To perform the packing described in the example above,
you could write:

  $data = {
    ary => [1, 2, 3],
    baz => 40000,
    bar => -4711,
  };
  $foo = $obj->pack( 'foo', $data );

Unpacking will work exactly the same way, just that the
C<unpack> method will take a byte string as its input and
will return a reference to a (possibly very complex) Perl
data structure.

=head2 Preprocessor configuration

Convert::Binary::C uses Thomas Pornin's B<ucpp> as an internal
C preprocessor. It is compliant to ISO-C99, so you don't have
to worry about using even weird preprocessor constructs in
your code.

If your C source contains includes or depends upon preprocessor
defines, you may need to configure the internal preprocessor.
Use the C<Include> and C<Define> configuration options for that:

  $obj->configure( Include => ['/usr/include',
                               '/home/mhx/include'],
                   Define  => [qw(NDEBUG FOO=42)] );

If your code uses system includes, it is most likely the case
that you will need to define the symbols that are usually
defined by the compiler.

=head2 Supported pragma directives

Convert::Binary::C supports the pack pragma to locally override
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

=head1 METHODS

=head2 new

=over 8

=item new

=item new OPTION1 =E<gt> VALUE1, OPTION2 =E<gt> VALUE2, ...

The constructor is used to create a new Convert::Binary::C object.
You can simply use

  $obj = new Convert::Binary::C;

without additional arguments to create an object, or you can
optionally pass any arguments to the constructor that are
described for the C<configure> method.

=back

=head2 configure

=over 8

=item configure

=item configure OPTION

=item configure OPTION1 =E<gt> VALUE1, OPTION2 =E<gt> VALUE2, ...

This method can be used to configure an existing Convert::Binary::C
object or to retrieve its current configuration.

To configure the object, the list of options consists of key and
value pairs and must therefore contain an even number of elements.
C<configure> (and also C<new> if used with configuration options)
will throw an exception if you pass an odd number of elements.
Configuration will normally look like this:

  $obj->configure( ByteOrder => 'BigEndian', IntSize => 2 );

To retrieve the current value of a configuration option, you
must pass a single argument to C<configure> that holds the name
of the option, just like

  $order = $obj->configure( 'ByteOrder' );

If you want to get the values of all configuration options at
once, you can call C<configure> without any arguments and it
will return a reference to a hash table that holds the whole
object configuration. This can be conveniently used with the
Data::Dumper module, for example:

  print Dumper( $obj->configure );

This will print something like this:

  $VAR1 = {
            'UnsignedChars' => 0,
            'ShortSize' => 2,
            'EnumType' => 'Integer',
            'EnumSize' => 4,
            'Include' => [
                           '/usr/include'
                         ],
            'DoubleSize' => 4,
            'FloatSize' => 4,
            'HasCPPComments' => 1,
            'Alignment' => 1,
            'Define' => [
                          'DEBUGGING',
                          'FOO=123'
                        ],
            'HasC99Keywords' => 1,
            'HasMacroVAARGS' => 1,
            'HashSize' => 'Normal',
            'LongSize' => 4,
            'HasVOID' => 1,
            'Warnings' => 0,
            'ByteOrder' => 'LittleEndian',
            'Assert' => [],
            'IntSize' => 4,
            'PointerSize' => 4
          };

Since you may not always want to write a configure call when
you only want to change a single configuration item, you can
use any configuration option name as a method name, like:

  $obj->ByteOrder( 'LittleEndian' ) if $obj->IntSize < 4;

(Yes, the example doesn't make very much sense...)

However, you should keep in mind that configuration methods
that can take lists (namely C<Include>, C<Define> and C<Assert>)
may behave slightly different than their C<configure> equivalent.
If you pass these methods a single argument that is an array
reference, the current list will be B<replaced> by the new one,
which is just the behaviour of the corresponding C<configure>
call. So the following are equivalent:

  $obj->configure( Define => ['foo', 'bar=123'] );
  $obj->Define( ['foo', 'bar=123'] );

But if you pass a list of strings instead of an array reference
(which cannot be done when using C<configure>), the new list
items are B<appended> to the current list, so

  $obj = new Convert::Binary::C Include => ['/include'];
  $obj->Include( '/usr/include', '/usr/local/include' );
  print Dumper( $obj->Include );
  $obj->Include( ['/usr/local/include'] );
  print Dumper( $obj->Include );

will first print all three include paths, but finally only

  /usr/local/include

will be configured.

You can configure the following options. Unknown options, as well
as invalid values for an option, will cause the object to throw
exceptions.

=over 4

=item IntSize =E<gt> 0 | 1 | 2 | 4

Set the number of bytes that are occupied by an integer. This is
in most cases 2 or 4. If you set it to zero, the size of an
integer on the host system will be used. This is also the
default.

=item ShortSize =E<gt> 0 | 1 | 2 | 4

Set the number of bytes that are occupied by a short integer.
Although integers explicitly declared as C<short> should be
always 16 bit, there are weird compilers that make a short
8 bit wide. If you set it to zero, the size of a short
integer on the host system will be used. This is also the
default.

=item LongSize =E<gt> 0 | 1 | 2 | 4

Set the number of bytes that are occupied by a long integer.
Integers explicitly declared as C<long> should always be
32 bit wide. However, for the sake of completeness, you can
adjust the size. If you set it to zero, the size of a long
integer on the host system will be used. This is also the
default.

=item FloatSize =E<gt> 0 | 1 | 2 | 4 | 8

Set the number of bytes that are occupied by a single
precision floating point value.
If you set it to zero, the size of a C<float> on the
host system will be used. This is also the default.
Values can only be packed and unpacked if the size
matches the native size of a C<float>.

=item DoubleSize =E<gt> 0 | 1 | 2 | 4 | 8

Set the number of bytes that are occupied by a double
precision floating point value.
If you set it to zero, the size of a C<double> on the
host system will be used. This is also the default.
Values can only be packed and unpacked if the size
matches the native size of a C<double>.

=item PointerSize =E<gt> 0 | 1 | 2 | 4

Set the number of bytes that are occupied by a pointer. This is
in most cases 2 or 4. If you set it to zero, the size of a
pointer on the host system will be used. This is also the
default.

=item EnumSize =E<gt> 0 | 1 | 2 | 4

Set the number of bytes that are occupied by an enumeration type.
On most systems, this is equal to the size of an integer,
which is also the default. However, for some compilers, the
size of an enumeration type depends on the size occupied by the
largest enumerator. So the size may vary between 1 and 4. If you
have

  enum foo {
    ONE = 100, TWO = 200
  };

this will occupy one byte because the enum can be represented
as an C<unsigned char>. However,

  enum foo {
    ONE = -100, TWO = 200
  };

will occupy two bytes, because 200 doesn't fit into
a C<signed char> and therefore the type used is
a C<signed short>. If this is the behaviour you need,
set the EnumSize to zero.

=item Alignment =E<gt> 1 | 2 | 4 | 8

Set the struct member alignment. This option controls where
padding bytes are inserted between struct members. It globally
sets the alignment for all structs/unions. However, this can
be overridden from within the source code with the common pack
pragma as explained in L<Supported pragma directives>.
The default alignment is 1, which means no padding bytes are
inserted.

=item ByteOrder =E<gt> 'BigEndian' | 'LittleEndian'

Set the byte order for integers larger than a single byte.
Little endian (Intel, least significant byte first) and
big endian (Motorola, most significant byte first) byte
order are supported. The default byte order is the same as
the byte order of the host system.

=item EnumType =E<gt> 'Integer' | 'String' | 'Both'

This option controls the type that enumeration constants
will have in data structures returned by the C<unpack>
method. If you have the following definitions:

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
to the C<unpack> method:

=over 4

=item Integer

Enumeration constants are returned as plain integers. This
is fast, but may be not very useful. It is also the default.

  {
    year    => 2002,
    month   => 0,
    day     => 7,
    weekday => 1
  }

=item String

Enumeration constants are returned as strings. This will
create a string constant for every unpacked enumeration
constant and thus consume more time and memory. However,
the result may be more useful.

  {
    year    => 2002,
    month   => 'JANUARY',
    day     => 7,
    weekday => 'MONDAY'
  }

=item Both

Enumeration constants are returned as double typed scalars.
If evaluated in string context, the enumeration constant
will be a string, if evaluated in numeric context, the
enumeration constant will be an integer. This seems to be
the most useful, but unfortunately if you want to dump the
data structures with Data::Dumper, you will see only the
integer values.

=back

=item HasVOID =E<gt> 0 | 1

Use this boolean option to turn the recognition of the
C<void> keyword on or off. The keyword is turned on by
default. However, there are still compilers out there
that will not recognize C<void> as a keyword. If someone
then does a

  typedef int void;

the Convert::Binary::C parser will obviously choke if it
treats C<void> as a keyword.

=item UnsignedChars =E<gt> 0 | 1

Use this boolean option if you want characters to be
unsigned if specified without an explicit C<signed> or
C<unsigned> type specifier. By default, characters are
signed.

=item Warnings =E<gt> 0 | 1

Use this boolean option if you want warnings to be issued
during the parsing of source code. Currently, warnings
are only reported by the preprocessor, so don't expect
the output to cover everything.

By default, this is turned off and only errors will be
reported. However, even these errors are turned off if
you run without the C<-w> flag.

=item HasC99Keywords =E<gt> 0 | 1

Use this boolean option to turn the recognition of the
new keywords introduced by the ANSI C99 standard on and
off. The following keywords are additionally recognized
by default:

  inline
  restrict

This option has no effect on the rules that are used by
the Convert::Binary::C parser. It will only allow you to
use the above keywords as type names or identifiers.

=item HasCPPComments =E<gt> 0 | 1

Use this option to turn C++ comments on or off. By default,
C++ comments are enabled. Disabling C++ comments may be
neccessary if your code includes strange things like:

  one = 4 //* <- divide */ 4;
  two = 2;

With C++ comments, the above will be interpreted as

  one = 4
  two = 2;

which will obviously create a parse error, but without
C++ comments, it will be interpreted as

  one = 4 / 4;
  two = 2;

which is correct.

=item HasMacroVAARGS =E<gt> 0 | 1

Use this option to turn the C<__VA_ARGS__> macro expansion
on or off. If this is enabled (the default), you can use
variable length argument lists in your preprocessor macros.

  #define DEBUG( ... )  fprintf( stderr, __VA_ARGS__ )

There's normally no reason to turn that feature off.

=item Include =E<gt> [ INCLUDES ]

Use this option to set the include path for the internal
preprocessor. The option value is a reference to an array
of strings, each string holding a directory that should
be searched for includes.

=item Define =E<gt> [ DEFINES ]

Use this option to define symbols in the preprocessor.
The option value is, again, a reference to an array of
strings. Each string can be either just a symbol or an
assignment to a symbol. This is completely equivalent
to what the C<-D> option does for most preprocessors.

The following will define the symbol C<FOO> and
define C<BAR> to be C<12345>:

  $obj->configure( Define => [qw(FOO BAR=12345)] );

=item Assert =E<gt> [ ASSERTIONS ]

Use this option to make assertions in the preprocessor.
If you don't know what assertions are don't be
concerned, since they're deprecated anyway. They
are, however, used in some system's include files.
The value is an array reference, just like for the
macro definitions. Only the way the assertions are
defined is a bit different and mimics the way they
are defined with the C<#assert> directive:

  $obj->configure( Assert => ['foo(bar)'] );

=item HashSize =E<gt> 'Tiny' | 'Small' | 'Normal' | 'Large' | 'Huge'

This is a special setting and you hardly need to change
it. It controls the size of the hash tables used by
Convert::Binary::C internally.

While small hash tables consume less memory, larger
hash tables might be faster. Unless you parse really
huge files (with a few thousands of typedefs or struct
definitions or several thousands of enumeration constants)
you can leave it as is. If the files you're parsing
are rather small and you have only little memory, you may
adjust this setting to C<Small> or C<Tiny>.

If you go from C<Tiny> to C<Huge>, each step will double
the memory requirements. However, the normal case will
consume only slightly more than 4k of memory per object.

=back

You can reconfigure all options even after you have
parsed some code. The changes will be applied to the
already parsed definitions. This works as long as array
lengths are not affected by the changes. If you have
alignment and integer size set to 4 and parse code like
this

  typedef struct {
    char abc;
    int  day;
  } foo;
   
  struct bar {
    foo  zap[2*sizeof(foo)];
  };

the array C<zap> in struct C<bar> will obviously have
16 elements. If you reconfigure the alignment to 1 now,
the size of C<foo> is now 5 instead of 8. While the
alignment is adjusted correctly, the number of elements
in array C<zap> will still be 16 and will not be changed
to 10.

=back

=head2 parse

=over 8

=item parse CODE

Parses a string of valid C code. All enumeration, struct
and type definitions are extracted. You can call
the C<parse> and C<parse_file> methods as often as you like
to add further definitions to the Convert::Binary::C object.
You must be aware that the preprocessor is reset with
every call. You may use types previously defined, but
you are not allowed to redefine types.

C<parse> will throw an exception in case an error occurs.

=back

=head2 parse_file

=over 8

=item parse_file FILE

Parses a C source file. All enumeration, struct and
type definitions are extracted. You can call
the C<parse> and C<parse_file> methods as often
as you like to add further definitions to the
Convert::Binary::C object.
You must be aware that the preprocessor is reset with
every call. You may use types previously defined, but
you are not allowed to redefine types.

C<parse_file> will throw an exception in case an error occurs.

=back

=head2 def

=over 8

=item def TYPE

If you need to know if a definition for a certain type
exists, use this method. You pass it the name of an enum,
struct/union or typedef, and it will return 1 if there's
a definition for the type in question, or 0 if there's no
such definition, or C<undef> if the name is completely
unknown. So after parsing

  typedef struct __not  not;
  typedef struct __not *ptr;
  
  struct foo {
    enum bar *xxx;
  };

the following would be returned by the C<def> method:

  $p->def( 'not' )  =>  0
  $p->def( 'ptr' )  =>  1
  $p->def( 'foo' )  =>  1
  $p->def( 'bar' )  =>  0
  $p->def( 'xxx' )  =>  undef

So, if C<def> is 1, you can safely use any other method
with that type's name.

=back

=head2 pack

=over 8

=item pack TYPE, DATA

=item pack TYPE, DATA, STRING

Use this method to pack a complex data structure into a
byte string according to a type definition that has been
previously parsed. DATA must be a scalar matching the
type definition. C structures and unions are represented
by references to Perl hashes, C arrays by references to
Perl arrays. Note that hashes need not contain a key for
each struct member and arrays may be truncated.

Elements not defined in the Perl data structure will be
set to zero in the packed byte string. On success, the
packed byte string is returned.

Call C<pack> with the optional STRING argument if you
want to use an existing string to insert the data.
If called in a void context, C<pack> will directly
modify the string you passed as the third argument.
Otherwise, a copy of the string is created, and C<pack>
will modify and return the copy, so the original string
will remain unchanged.

The 3-argument version may be useful if you want to change
only a few members of a complex data structure without
having to C<unpack> everything, change the members, and
then C<unpack> again (which could waste lots of memory
and CPU cycles). So, instead of doing something like

  $foo = $obj->unpack( 'foo', $str );
  $foo->{bar} = -7;
  $foo->{baz} = 42;
  $str = $obj->pack( 'foo', $foo );

to change the C<bar> and C<baz> members of $foo, you
could simply do either

  $obj->pack( 'foo', { bar => -7, baz => 42 }, $str );

or

  $new = $obj->pack( 'foo', { bar => -7, baz => 42 }, $str );

while the latter would not change $str, but store the
modified string in $new. Besides this code being a lot
shorter (and perhaps even more readable), it can be
significantly faster if you're dealing with really
big data blocks.

If the length of the input string is less than the size
required by the type, the string (or its copy) is
extended and the extended part is initialized to zero.
If the length is more than the size required by the type,
the string is kept at that length, and also a copy would
be an exact copy of that string.

=back

=head2 unpack

=over 8

=item unpack TYPE, STRING

Use this method to unpack a byte string and create an
arbitrarily complex Perl data structure based on a
previously parsed type definition.

On failure, e.g. if the specified type cannot be found,
the method will throw an exception. On success, a
reference to a complex Perl data structure is returned.

=back

=head2 sizeof

=over 8

=item sizeof TYPE

This method will return the size of a C type in bytes.
If it cannot find the type, it will throw an exception.

=back

=head2 member

=over 8

=item member TYPE, OFFSET

You can use this method if you want to retrieve the name
of the member that is located at a specific offset for a
previously parsed type.

  $c = new Convert::Binary::C Alignment => 4;
   
  $c->parse( <<'CCODE' );
  typedef struct {
    char abc;
    long day;
  } foo;
   
  struct bar {
    foo  zap[2*sizeof(foo)];
  };
  CCODE
   
  print $c->member( 'bar', 16 );  # "zap[2].abc"
  print $c->member( 'bar', 27 );  # "zap[3]+3"
  print $c->member( 'bar', 45 );  # "zap[5].day+1"
  print $c->member( 'bar', 150 ); #  => exception

The output of the first line is obvious. The
member C<zap[2].abc> is located at offset 16 of
type C<bar>.

In the second line, the offset points into a region
of padding bytes, thus no member of C<foo> can be
named and instead of a member name the offset
relative to C<zap[3]> is appended.

In the third line, the offset points to C<zap[5].day>.
However, C<zap[5].day> is located at 44, not at 45,
and thus the remaining offset of 1 is also appended.

The last line causes an exception because the offset
of 150 is not valid for struct C<bar> since the size
of struct C<bar> is only 128.

=back

=head2 offsetof

=over 8

=item offsetof TYPE, MEMBER

You can think of C<offsetof> as being the reverse of
the C<member> method. Given the above example code,

  print $c->offsetof( 'bar', 'zap[5].day' );

will print C<44>. Note that the C<+n> syntax isn't
allowed by C<offsetof>, so

  print $c->offsetof( 'bar', 'zap[5].day+1' );

would not print C<45>, but rather cause an exception
because an invalid character is being used in the
expression.

=back

The following methods can be used to retrieve information
about the definitions that have been parsed.

The examples given in the following description all
assume the following piece of C code has been parsed.

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

=over 8

=back

=head2 enum_names

=over 8

=item enum_names

Returns a list of identifiers of all defined enumeration
objects. Enumeration objects don't neccessarily have an
identifier, so something like

  enum { A, B, C };

will obviously not appear in the list returned by
the C<enum_names> method. Also, enumerations that are not
defined within the source code - like in

  struct foo {
    enum weekday *pWeekday;
    unsigned long year;
  }

where only a pointer to the C<weekday> enumeration object
is used - will not be returned, even though they have an
identifier.

The only way to retrieve a list of all enumeration
objects is to use the C<enum> method without additional
arguments. You can get a list of all enumeration objects
that have an identifier by using

  @enum = map { $_->{identifier} || () } $p->enum;

but these may not have a definition.

The C<def> method returns 1 for all identifiers returned
by C<enum_names>.

=back

=head2 enum

=over 8

=item enum

=item enum LIST

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

The list returned by the C<enum> method looks similar
to this:

  @enum = (
    {
      'identifier' => '__socket_type',
      'enumerators' => {
        'SOCK_RAW' => 3,
        'SOCK_DGRAM' => 2,
        'SOCK_STREAM' => 1,
        'SOCK_SEQPACKET' => 5,
        'SOCK_RDM' => 4,
        'SOCK_PACKET' => 10
      },
      'sign' => 0,
      'size' => 1
    }
  );

=over 4

=item identifier

holds the enumeration identifier. This key is not
present if the enumeration has no identifier.

=item enumerators

is a reference to a hash table that holds
all enumerators of the enumeration.

=item sign

is a boolean indicating if the enumeration is
signed.

=item size

is the size in bytes needed to store any enumerator of
that enumeration. This does B<not> need to be the size
that is actually occupied by an enum. Only if C<EnumSize>
is configured to C<0>, these are identical.

=back

One useful application may be to create a hash table that
holds all enumerators of all defined enumerations:

  %enum = map %{$_->{enumerators}||{}}, $p->enum;

=back

=head2 compound_names

=over 8

=item compound_names

Returns a list of identifiers of all structs and unions
(compound data structures) that are defined in the parsed
source code. Like enumerations, compounds don't need to
have an identifier, nor do they need to be defined.

Again, the only way to retrieve information about all
struct and union objects is to use the C<compound> method
and don't pass it any arguments. If you should need a
list of all struct and union identifiers, you can use:

  @structs = map { $_->{identifier} || () } $p->compound;

The C<def> method returns 1 for all identifiers returned
by C<compound_names>.

If you need the names of only the structs or only the
unions, use the C<struct_names> and C<union_names> methods
respectively.

=back

=head2 compound

=over 8

=item compound

=item compound LIST

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

The list returned by the C<compound> method looks similar
to this:

  @struct = (
    {
      'declarations' => [
        {
          'declarators' => [
            {
              'declarator' => '*sv_any',
              'offset' => 0,
              'size' => 4
            }
          ],
          'type' => 'void'
        },
        {
          'declarators' => [
            {
              'declarator' => 'sv_refcnt',
              'offset' => 4,
              'size' => 4
            }
          ],
          'type' => 'U32'
        },
        {
          'declarators' => [
            {
              'declarator' => 'sv_flags',
              'offset' => 8,
              'size' => 4
            }
          ],
          'type' => 'U32'
        }
      ],
      'pack' => 0,
      'align' => 4,
      'size' => 12,
      'identifier' => 'STRUCT_SV',
      'type' => 'struct'
    },
    {
      'declarations' => [
        {
          'declarators' => [
            {
              'declarator' => 'a',
              'offset' => 0,
              'size' => 4
            }
          ],
          'type' => 'int'
        },
        {
          'declarators' => [
            {
              'declarator' => 'b',
              'offset' => 4,
              'size' => 4
            }
          ],
          'type' => 'int'
        }
      ],
      'pack' => 0,
      'align' => 4,
      'size' => 8,
      'identifier' => 'xxx',
      'type' => 'struct'
    },
    {
      'declarations' => [
        {
          'declarators' => [
            {
              'declarator' => 'abc[2]',
              'offset' => 0,
              'size' => 8
            }
          ],
          'type' => 'int'
        },
        {
          'declarators' => [
            {
              'declarator' => 'ab[3][4]',
              'offset' => 0,
              'size' => 96
            }
          ],
          'type' => 'struct xxx'
        }
      ],
      'pack' => 0,
      'align' => 4,
      'size' => 96,
      'type' => 'union'
    }
  );

=over 4

=item identifier

holds the struct or union identifier. This
key is not present if the compound has no identifier.

=item type

is either 'struct' or 'union'.

=item size

is the size of the struct or union.

=item align

is the alignment of the struct or union.

=item pack

is the struct member alignment if the compound
is packed, or zero otherwise.

=item declarations

is an array of hash references describing each struct
declaration:

=over 4

=item type

is the type of the struct declaration. This may be a
string or a reference to a hash describing the type.

=item declarators

is an array of hashes describing each declarator:

=over 4

=item declarator

is a string representation of the declarator.

=item offset

is the offset of the struct member represented by
the current declarator relative to the beginning
of the struct or union.

=item size

is the size occupied by the struct member represented
by the current declarator.

=back

=back

=back

It may be useful to have separate lists for structs and
unions. One way to retrieve such lists would be to use

  map {
    push @{$_->{type} eq 'union' ? \@unions : \@structs}, $_
  } $p->compound;

However, you should use the C<struct> and C<union>
methods, which is a lot simpler:

  @structs = $p->struct;
  @unions  = $p->union;

=back

=head2 struct_names

=over 8

=item struct_names

Returns a list of all defined struct identifiers.
This is equivalent to calling C<compound_names>, just that
it only returns the names of the struct identifiers and
doesn't return the names of the union identifiers.

=back

=head2 struct

=over 8

=item struct

Like the C<compound> method, but only allows for structs.

=back

=head2 union_names

=over 8

=item union_names

Returns a list of all defined union identifiers.
This is equivalent to calling C<compound_names>, just that
it only returns the names of the union identifiers and
doesn't return the names of the struct identifiers.

=back

=head2 union

=over 8

=item union

Like the C<compound> method, but only allows for unions.

=back

=head2 typedef_names

=over 8

=item typedef_names

Returns a list of all defined typedef identifiers. Typedefs
that do not specify a type that you could actually work with
will not be returned.

The C<def> method returns 1 for all identifiers returned
by C<typedef_names>.

=back

=head2 typedef

=over 8

=item typedef

=item typedef LIST

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

The list returned by the C<typedef> method looks similar
to this:

  @typedef = (
    {
      'declarator' => 'U32',
      'type' => 'unsigned long'
    },
    {
      'declarator' => 'test',
      'type' => {
        'declarations' => [
          {
            'declarators' => [
              {
                'declarator' => 'abc[2]',
                'offset' => 0,
                'size' => 8
              }
            ],
            'type' => 'int'
          },
          {
            'declarators' => [
              {
                'declarator' => 'ab[3][4]',
                'offset' => 0,
                'size' => 96
              }
            ],
            'type' => 'struct xxx'
          }
        ],
        'pack' => 0,
        'align' => 4,
        'size' => 96,
        'type' => 'union'
      }
    }
  );

=over 4

=item declarator

is the type declarator.

=item type

is the type specification. This may be a string
or a reference to a hash describing the type.

=back

=back

=head1 FUNCTIONS

=head2 Convert::Binary::C::feature

=over 8

=item feature STRING

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
in a later release, when I found an easy way of integrating
them into the module.

Whenever a method has to deal with bitfields, it will issue
a warning message that bitfields are unsupported. Thus, you
may use bitfields in your C source code, but you won't be
annoyed with warning messages unless you really use a type
that actually contains bitfields in a method call
like C<sizeof> or C<pack>.

While bitfields are not appropriately handled by the conversion
routines yet, they are already parsed correctly. This means
that you can reliably use the declarator fields as returned
by the C<struct> or C<typedef> methods. Given the following
source

  struct bitfield {
    int seven:7;
    int :1;
    int four:4, :0;
    int integer;
  };

a call to C<struct> will return

  @struct = (
    {
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
              'offset' => 0,
              'size' => 4
            }
          ],
          'type' => 'int'
        }
      ],
      'pack' => 0,
      'align' => 1,
      'size' => 4,
      'identifier' => 'bitfield',
      'type' => 'struct'
    }
  );

No size/offset keys will be returned for bitfield entries.
Also, the size of a structure containing bitfields is not
valid, as bitfields internally do not increase the size
of a structure yet.

=head1 MULTITHREADING

Convert::Binary::C was designed to be thread-safe.

Since the used preprocessor unfortunately isn't re-entrant,
source code parsing using the C<parse> and C<parse_file>
methods is locked, so don't expect these routines to run
in parallel on multithreaded perls.

=head1 CREDITS

=over 2

=item *

Thomas Pornin E<lt>pornin@bolet.orgE<gt> for his excellent
ucpp preprocessor library.

=item *

Mark Overmeer E<lt>mark@overmeer.netE<gt> for suggesting the
module name and giving invaluable feedback.

=item *

Frederic Fabbro E<lt>ffreddo@ibelgique.comE<gt> for testing
the package and offering continuous help and feedback.

=item *

Thorsten Jens E<lt>thojens@gmx.deE<gt> for testing the package
on various platforms.

=item *

James Roskind, as his C parser was a great starting point to fix
all the problems I had with my orignal parser based only on the
ANSI ruleset.

=back

=head1 BUGS

I'm sure there are still lots of bugs in the code for this
module. Also, the functionality is not yet as complete as I
wish it were. If you find any bugs, Convert::Binary::C doesn't
seem to build on your system or any of its tests fail, please
send a mail to E<lt>mhx@cpan.orgE<gt>.

=head1 TODO

If you're interested in what I currently plan to improve
(or fix), have a look at the F<TODO> file.

=head1 COPYRIGHT

Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

The ucpp library is (c) Thomas Pornin 1999, 2000. For licence
and redistribution details refer to F<ctlib/ucpp/README>.

Portions copyright (c) 1989, 1990 James A. Roskind.

Some of the include files used for the F<t/parse.t> test
script are (c) 1991-1999, 2000, 2001 Free Software Foundation,
Inc. They are neither required to create the binary nor linked
to the source code of this module in any other way.
