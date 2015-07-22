#!/usr/bin/perl -w
use strict;
use constant MAXREC => 3;
use constant NTYPES => 4;
use constant NDATA  => 3324;
use Data::Dumper;

unless( @ARGV ) {
  print "use constant NTYPES => @{[NTYPES]};\n";
  exit;
}

my $alignment = shift;

my(%typedef, @typedefs);

{
  my $identifier = "aa";

  sub next_id() {
    my $id;
    $id = $identifier++;
    $id = $identifier++ if $id eq 'if' || $id eq 'do' || $id eq 'asm' || $id eq 'for';
    $id;
  }
}

srand 12;

for( 1 .. NTYPES ) {
  my $id = &next_id;
  $typedef{$id} = GetType( 0, 'STRUCT', 'UNION' );
  push @typedefs, $id;
}

my %str = (
  TYPEDEFS => &TypedefString,
  PACK     => "#pragma pack( $alignment )",
  DEFINES  => "#define NDATA @{[NDATA]}\n#define ALIGNMENT $alignment\n",
  DECLS    => &DeclString,
  MEMBER   => &MemberString,
  SIZEOF   => &SizeofString,
  MEMCPY   => &MemcpyString,
  DATA     => &DataString,
  DATAGEN  => &DatagenString,
  DUMP     => &DumpString,
  DEBUG    => '', # Dumper(\%typedef),
);

$str{EXTDECLS} = $str{DECLS};
$str{EXTDECLS} =~ s/^/extern /mg;

write_template( 'test.c', do {local $/; <DATA>} );

write_template( 'test.h', <<'__TEST_H' );
#ifndef TEST_H__
#define TEST_H__

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stddef.h>

/*
[[DEBUG]]
*/

[[PACK]]

[[TYPEDEFS]]

[[DEFINES]]

extern int i[100][10];
[[EXTDECLS]]

#endif
__TEST_H

print STDERR "All C files generated!\n";

exit 0;

sub write_template
{
  my($file,$code,$noexpand) = @_;

  unless( defined $noexpand and $noexpand ) {
    my $alt = join '|', keys %str;
    $code =~ s!^(.*)(?:\[\[($alt)\]\]|<<($alt)>>)!
               indent( $1, defined($2) ? $str{$2} : perlcode($str{$3}) )
             !egm;
  }
  
  open OUT, ">$file" or die "$file: $!\n";
  print OUT $code;
  close OUT;
}

sub MergePrintf
{
  my $code = shift;
  my $printf = 'printf\(\s*"[^"\\\\]*(?:\\\\.[^"\\\\]*)*"\s*(?:,[^;]+)?\);';
  $code =~ s{($printf(?:\s*$printf)+)}{_merged($1)}egs;
  $code;
}

sub _merged
{
  my $p = shift;
  my(@fmt, @args);
  while( $p =~ /printf\(\s*("[^"\\]*(?:\\.[^"\\]*)*")\s*(?:,\s*([^;]+))?\);/g ) {
    push @fmt, $1;
    defined $2 and push @args, $2;
  }

  my $rv = "printf( @fmt";
  @args and $rv .= ",\n" . join(",\n", @args);
  $rv . " );\n";
}

sub indent
{
  my($indent, $str) = @_;
  $str =~ s/^/$indent/gm;
  $str;
}

sub perlcode
{
  my $str = shift;
  $str =~ s/[\"\'\\]/\\$&/g;
  $str =~ s/^.*/"$&\\n"/gm;
  "printf( \"%s\",\n".$str."\n);\n";
}

sub MemcpyString
{
  my $str = '';

  for my $id ( @typedefs ) {
    $str .= <<EOS;
if( sizeof( $id ) <= NDATA ) {
  memcpy( &v$id, data, sizeof( $id ) );
}
else {
  fprintf( stderr, "NDATA too small (NDATA=%d, sizeof($id)=%d)\\n", NDATA, sizeof( $id ) );
  abort();
}
EOS
  }

  $str;
}

sub DatagenString
{
<<DATAGEN;
\$SEED = 0;
\$data = pack 'C*', map { (\$SEED = ((\$SEED+13)*2869) % 8191) % 256 } 1..@{[NDATA]};
DATAGEN
}

sub DataString
{
  my @data;
  my $SEED = 0;

  $#data = NDATA - 1;
  $_ = ($SEED = (($SEED+13)*2869) % 8191) % 256 for @data;

  my $str = '';

  while( @data ) {
    $str .= '  ' . join(', ', map {sprintf "%3d", $_} splice @data, 0, 16);
    $str .= ",\n" if @data;
  }

  $str;
}

sub MemberString
{
  my $str = qq[printf("{\\n");\n];

  for my $id ( @typedefs ) {
    my $temp = MergePrintf(
                   qq[printf("$id => \[\\n");\n]
                 . MemberStruct( "v$id", $typedef{$id}[1], 0, '' )
                 . qq[printf("['', %d, 0],\\n\],\\n", sizeof($id));\n]
               );

    write_template( "_sub_member_$id.c", <<__MEMBER, 1 );
#include "test.h"

void _member_$id()
{
$temp
}
__MEMBER

    $str .= "(void) _member_$id();\n";
  }

  $str.qq[printf("}\\n");\n];
}

sub DumpString
{
  my $str = '';
  my $first = 1;

  for my $id ( @typedefs ) {
    my $temp = '';
    if( $first ) { $first = 0 } else { $temp .= qq[printf(",\\n");\n] }
    $temp = MergePrintf(
                $temp . qq[printf("$id=>{\\n");\n]
              . DumpStruct( "v$id", $typedef{$id}[1], 0, '' )
              . qq[printf("}");\n]
            );

    write_template( "_sub_content_$id.c", <<__CONTENT, 1 );
#include "test.h"

void _content_$id()
{
$temp
}
__CONTENT

    $str .= "(void) _content_$id();\n";
  }

  $str;
}

sub MemberStruct
{
  my($id,$s,$level,$cind) = @_;
  my $str = '';
  my $ident;
  my $ci;

  for my $h ( @{$s->{members}} ) {

    if( exists $h->{decl} ) {

      for my $decl ( @{$h->{decl}} ) {

        $ci = $cind;

        $ident = "$id.$decl->{ident}";

        for my $d ( 0..$#{$decl->{dim}} ) {
          $ci = $cind . '  'x$d;
          $ident .= "[i[$level][$d]]";

          $str .= <<ENDFOR;
${ci}for( i[$level][$d] = 0; i[$level][$d] < $decl->{dim}[$d]; ++i[$level][$d] ) {
ENDFOR
        }

        $ci .= '  ' if @{$decl->{dim}};

        {
          my($type, $field) = $ident =~ /^v([^\.]+)\.(.*)$/;
          my $id = $field;
          my @ix = $id =~ /\[(i\[\d+\]\[\d+\])\]/g;
          my $isbasic = $h->{type}[0] eq 'type' || ref($h->{type}[1]) ? 0 : 1;
          $id =~ s/\[i\[\d+\]\[\d+\]\]/[\%d]/g;
          $str .= join ', ', qq[${ci}printf("['$id', %d, %d, $isbasic],\\n"], @ix,
                  qq[sizeof($ident), offsetof($type, $field));\n];
        }

        if( $h->{type}[0] eq 'type' ) {
          $str .= MemberStruct( $ident, $typedef{$h->{type}[1]}[1], $level+1, $ci );
        }
        elsif( ref $h->{type}[1] ) {
          $str .= MemberStruct( $ident, $h->{type}[1], $level+1, $ci );
        }

        for my $d ( reverse 0..$#{$decl->{dim}} ) {
          $ci = $cind . '  'x$d;

          $str .= <<ENDFOR;
${ci}}
ENDFOR
        }

      }

    }
    else {

      $str .= MemberStruct( $id, $h->{type}[1], $level, $cind );

    }

  }

  $str;
}

sub DumpStruct
{
  my($id,$s,$level,$cind) = @_;
  my $str = '';
  my $ident;
  my $first = 1;
  my $ci;

  for my $h ( @{$s->{members}} ) {

    if( exists $h->{decl} ) {

      for my $decl ( @{$h->{decl}} ) {

        $ci = $cind;

        if( $first ) { $first = 0 } else { $str .= qq[${ci}printf(",\\n");\n] }

        $str .= qq[${ci}printf("$decl->{ident}=>");\n];

        $ident = "$id.$decl->{ident}";

        for my $d ( 0..$#{$decl->{dim}} ) {
          $ci = $cind . '  'x$d;
          $ident .= "[i[$level][$d]]";

          $str .= <<ENDFOR;
${ci}printf("[");
${ci}for( i[$level][$d] = 0; i[$level][$d] < $decl->{dim}[$d]; ++i[$level][$d] ) {
${ci}if( i[$level][$d] > 0 ) { printf(","); }
ENDFOR
        }

        $ci .= '  ' if @{$decl->{dim}};

        if( $h->{type}[0] eq 'type' ) {
          $str .= qq[${ci}printf("{\\n");\n];
          $str .= DumpStruct( $ident, $typedef{$h->{type}[1]}[1], $level+1, $ci );
          $str .= qq[${ci}printf("}");\n];
        }
        elsif( ref $h->{type}[1] ) {
          $str .= qq[${ci}printf("{\\n");\n];
          $str .= DumpStruct( $ident, $h->{type}[1], $level+1, $ci );
          $str .= qq[${ci}printf("}");\n];
        }
        else {
          if( $h->{type}[1] =~ /ll/ ) {
            $str .= qq[${ci}printf("'\%$h->{type}[1]'", $ident);\n];
          }
          else {
            $str .= qq[${ci}printf("\%$h->{type}[1]", $ident);\n];
          }
        }

        for my $d ( reverse 0..$#{$decl->{dim}} ) {
          $ci = $cind . '  'x$d;

          $str .= <<ENDFOR;
${ci}}
${ci}printf("]");
ENDFOR
        }

      }

    }
    else {

      if( $first ) { $first = 0 } else { $str .= qq[${cind}printf(",\\n");\n] }
      $str .= DumpStruct( $id, $h->{type}[1], $level, $cind );

    }

  }

  $str;
}

sub SizeofString
{
  my $cstr = join ",", map "$_=>\%d", @typedefs;
  my $size = join ", ", map "sizeof($_)", @typedefs;
  qq[printf("$cstr\\n", $size);\n];
}

sub DeclString
{
  my $str = '';

  for my $id ( @typedefs ) {
    $str .= "$id v$id;\n";
  }

  $str;
}

sub TypedefString
{
  my $str = '';

  for my $id ( @typedefs ) {
    $str .= "typedef ";
  
    if( $typedef{$id}[0] eq 'type' ) {
      $str .= $typedef{$id}[1];
    }
    else {
      if( ref $typedef{$id}[1] ) {
        $str .= $typedef{$id}[0];
        $str .= ' ';
        $str .= Struct( $typedef{$id}[1], 0 );
      }
      else {
        $str .= $typedef{$id}[0];
      }
    }
  
    $str .= " $id;\n\n";
  }

  $str;
}

sub Struct
{
  my($s,$l) = @_;
  my $n;

  my $indent = '  'x$l;

  my $str = "{\n\n";

  for my $h ( @{$s->{members}} ) {

    if( ref $h->{type}[1] and exists $h->{type}[1]{'pack'} ) {
      $str .= "\n#pragma pack( push, $h->{type}[1]{'pack'} )\n";
    }

    if( $h->{type}[0] eq 'type' ) {
      $str .= $indent . '  ' . $h->{type}[1];
      $n = length $h->{type}[1];
    }
    else {
      if( ref $h->{type}[1] ) {
        $str .= $indent . '  ' . $h->{type}[0] . ' ';
        $str .= Struct( $h->{type}[1], $l+1 );
        $n = 1;
      }
      else {
        $str .= $indent . '  ' . $h->{type}[0];
        $n = length $h->{type}[0];
      }
    }

    if( exists $h->{decl} ) {
      $n = $n>=20 ? 1 : 20-$n;
      $str .= ' 'x$n;

      $str .= join ', ', map {
                local $" = '][';
                "$_->{ident}" .
                ( @{$_->{dim}} ? "[@{$_->{dim}}]" : '' )
              } @{$h->{decl}};
    }

    $str .= ";\n";

    if( ref $h->{type}[1] and exists $h->{type}[1]{'pack'} ) {
      $str .= "#pragma pack( pop )\n\n";
    }
  }

  $str . "\n" . $indent . "}";
}

sub GetType
{
  my($rec, @spec) = @_;

  my @basic = (
    ['signed char',        'd'  ],
    ['unsigned char',      'u'  ],
    ['signed short',       'hd' ],
    ['unsigned short',     'hu' ],
    ['signed long',        'ld' ],
    ['unsigned long',      'lu' ],
    ['signed long long',   'lld'],
    ['unsigned long long', 'llu'],
    ['int',                'd'  ],
    ['unsigned',           'u'  ],
  );

  my @struct = (
    ['struct',         \&GetStruct],
  );

  my @union = (
    ['union',          \&GetStruct],
  );

  my @typedef = (
    ['type',           sub { $typedefs[rand @typedefs] }],
  );

  my @type = ();
  my %spec = (BASIC => 0, TYPEDEF => 0, UNION => 0, STRUCT => 0);

  $spec{$_}++ for @spec;

  push @type, (@basic)   x $spec{BASIC};
  if( $rec < MAXREC ) {
    push @type, (@struct)   x $spec{STRUCT};
    push @type, (@union)    x $spec{UNION};
    push @type, (@typedef)  x $spec{TYPEDEF};
  }

  my @t;

  do {
    @t = @{$type[rand @type]};
    $t[1] = $t[1]->( $rec ) if ref $t[1];
  } while not defined $t[1];

  \@t;
}

sub GetStruct
{
  my $rec = shift;

  my @struct;

  for( 0 .. 3 + rand 5 ) {
    if( $rec+1 >= MAXREC or rand(3) > 1 ) {
      push @struct, {
        type => GetType( $rec+1, 'BASIC', ('STRUCT')x4, ('UNION')x2, 'TYPEDEF' ),
        decl => [
          map { {
            ident => &next_id,
            dim   => [map 1+int rand 3, 1 .. (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                                              0,0,0,0,0,0,0,0,1,1,2,2,2,2,3,4)[rand (32 + ($rec+1) - MAXREC)]],
          } } 1 .. (1,1,1,1,1,1,2,2,2,3)[rand 10]
        ]
      }
    }
    else {
      push @struct, {
        type => GetType( $rec+1, ('UNION')x2, 'STRUCT' ),
      }
    }
  }

  my %s = ( members => \@struct );

  if( rand(3) < 1 ) {
    $s{'pack'} = (1,2,4)[rand 3];
  }

  \%s;
}

__DATA__

#include "test.h"

unsigned char data[NDATA] = {
[[DATA]]
};

int i[100][10];
[[DECLS]]

static void _typedefs()
{
  printf("\n$types = <<'ENDTYPES';\n");
  <<TYPEDEFS>>
  printf("ENDTYPES\n\n");
}

static void _datagen()
{
  <<DATAGEN>>
}

static void _member()
{
  [[MEMBER]]
}

static void _sizeof()
{
  printf("sizeof => {\n");
  [[SIZEOF]]
  printf("},\n");
}

static void _memcpy()
{
  [[MEMCPY]]
}

void _content()
{
  printf("content => {\n");
  [[DUMP]]
  printf("}\n");
}

int main( int argc, char **argv )
{
  if( argc > 1 ) {
    if( strcmp( "types", argv[1] ) == 0 ) {
      _typedefs();
    }
    else if( strcmp( "data", argv[1] ) == 0 ) {
      _datagen();
    }
    else if( strcmp( "member", argv[1] ) == 0 ) {
      _member();
    }
  }
  else {
    printf("%d => {\n", ALIGNMENT);
    _sizeof();
    _memcpy();
    _content();
    printf("},\n");
  }

  return 0;
}
