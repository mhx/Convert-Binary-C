#!/usr/bin/perl -w
use strict;
use constant MAXREC => 3;
use constant NTYPES => 4;
use constant NDATA  => 2420;
use Data::Dumper;

unless( @ARGV ) {
  print "use constant NTYPES => @{[NTYPES]};\n";
  exit;
}

my $alignment = shift;

my %typedef;
{
  my $identifier = "aa";

  sub next_id() {
    my $id;
    $id = $identifier++;
    $id = $identifier++ if $id eq 'if' || $id eq 'do';
    $id;
  }
}

srand 2;

$typedef{&next_id} = GetType( 0, 'COMPOUND' ) for 1 .. NTYPES;

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
  DEBUG    => Dumper(\%typedef),
);

my $code = do {local $/; <DATA>};

$code =~ s/^(.*)\[\[$_\]\]/indent($1,$str{$_})/egm for keys %str;
$code =~ s/^(.*)<<$_>>/indent($1,perlcode($str{$_}))/egm for keys %str;

print $code;

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

  for my $id ( sort keys %typedef ) {
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

  for my $id ( sort keys %typedef ) {
    $str .= qq[printf("$id => \[\\n");\n];
    $str .= MemberStruct( "v$id", $typedef{$id}[1], 0, '' );
    $str .= qq[printf("['', %d, 0],\\n", sizeof($id));\n];
    $str .= qq[printf("\],\\n");\n];
  }

  $str.qq[printf("}\\n");\n];
}

sub MemberStruct
{
  my($id,$s,$level,$cind) = @_;
  my $str = '';
  my $ident;
  my $ci;

  for my $h ( @$s ) {
    $ci = $cind;

    $ident = "$id.$h->{ident}";

    for my $d ( 0..$#{$h->{dim}} ) {
      $ci = $cind . '  'x$d;
      $ident .= "[i[$level][$d]]";

      $str .= <<ENDFOR;
${ci}for( i[$level][$d] = 0; i[$level][$d] < $h->{dim}[$d]; ++i[$level][$d] ) {
ENDFOR
    }

    $ci .= '  ' if @{$h->{dim}};

    if( $h->{type}[0] eq 'type' ) {
      $str .= MemberStruct( $ident, $typedef{$h->{type}[1]}[1], $level+1, $ci );
    }
    elsif( ref $h->{type}[1] ) {
      $str .= MemberStruct( $ident, $h->{type}[1], $level+1, $ci );
    }

    {
      my($type, $field) = $ident =~ /^v([^\.]+)\.(.*)$/;
      my $id = $field;
      my @ix = $id =~ /\[(i\[\d+\]\[\d+\])\]/g;
      $id =~ s/\[i\[\d+\]\[\d+\]\]/[\%d]/g;
      $str .= join ', ', qq[${ci}printf("['$id', %d, %d],\\n"], @ix,
              qq[sizeof($ident), offsetof($type, $field));\n];
    }

    for my $d ( reverse 0..$#{$h->{dim}} ) {
      $ci = $cind . '  'x$d;

      $str .= <<ENDFOR;
${ci}}
ENDFOR
    }
  }

  $str;
}

sub DumpString
{
  my $str = '';
  my $first = 1;

  for my $id ( sort keys %typedef ) {
    if( $first ) { $first = 0 } else { $str .= qq[printf(",\\n");\n] }
    $str .= qq[printf("$id=>{\\n");\n];
    $str .= DumpStruct( "v$id", $typedef{$id}[1], 0, '' );
    $str .= qq[printf("}");\n];
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

  for my $h ( @$s ) {
    $ci = $cind;

    if( $first ) { $first = 0 } else { $str .= qq[${ci}printf(",\\n");\n] }

    $str .= qq[${ci}printf("$h->{ident}=>");\n];

    $ident = "$id.$h->{ident}";

    for my $d ( 0..$#{$h->{dim}} ) {
      $ci = $cind . '  'x$d;
      $ident .= "[i[$level][$d]]";

      $str .= <<ENDFOR;
${ci}printf("[");
${ci}for( i[$level][$d] = 0; i[$level][$d] < $h->{dim}[$d]; ++i[$level][$d] ) {
${ci}if( i[$level][$d] > 0 )
${ci}  printf(",");
ENDFOR
    }

    $ci .= '  ' if @{$h->{dim}};

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
      $str .= qq[${ci}printf("\%$h->{type}[1]", $ident);\n];
    }

    for my $d ( reverse 0..$#{$h->{dim}} ) {
      $ci = $cind . '  'x$d;

      $str .= <<ENDFOR;
${ci}}
${ci}printf("]");
ENDFOR
    }
  }

  $str;
}

sub SizeofString
{
  my $str = '';

  for my $id ( sort keys %typedef ) {
    $str .= qq[printf("$id=>%d,\\n", sizeof($id));\n];
  }

  $str;
}

sub DeclString
{
  my $str = '';

  for my $id ( sort keys %typedef ) {
    $str .= "$id v$id;\n";
  }

  $str;
}

sub TypedefString
{
  my $str = '';

  for my $id ( sort keys %typedef ) {
    $str .= "typedef ";
  
    if( $typedef{$id}[0] eq 'type' ) {
      $str .= $typedef{$id}[1];
    }
    else {
      $str .= $typedef{$id}[0];
      if( ref $typedef{$id}[1] ) {
        $str .= ' ';
        $str .= Struct( $typedef{$id}[1], 0 );
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

  for my $h ( @$s ) {
    $str .= $indent;

    if( $h->{type}[0] eq 'type' ) {
      $str .= '  ' . $h->{type}[1];
      $n = length $h->{type}[1];
    }
    else {
      $str .= '  ' . $h->{type}[0];
      $n = length $h->{type}[0];
      if( ref $h->{type}[1] ) {
        $str .= ' ';
        $str .= Struct( $h->{type}[1], $l+1 );
        $n = 1;
      }
    }

    $n = $n>=16 ? 1 : 16-$n;

    $str .= ' 'x$n . $h->{ident};
    $str .= "[$_]" for @{$h->{dim}};
    $str .= ";\n";
  }

  $str . "\n" . $indent . "}";
}

sub GetType
{
  my($rec, @spec) = @_;

  my @basic = (
    ['signed char',    'd'],
    ['unsigned char',  'u'],
    ['signed short',   'hd'],
    ['unsigned short', 'hu'],
    ['signed long',    'ld'],
    ['unsigned long',  'lu'],
    ['int',            'd'],
    ['unsigned',       'u'],
  );

  my @compound = (
    ['struct',         \&GetStruct],
    ['struct',         \&GetStruct],
    ['union',          \&GetStruct],
  );

  my @typedef = (
    ['type',           sub { (keys %typedef)[rand scalar keys %typedef] }],
  );

  my @type = ();

  push @type, @basic    for grep /^BASIC$/, @spec;
  if( $rec < MAXREC ) {
    push @type, @compound for grep /^COMPOUND$/, @spec;
    push @type, @typedef  for grep /^TYPEDEF$/, @spec;
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
    push @struct, {
      type  => GetType( $rec+1, 'BASIC', ('COMPOUND')x2, 'TYPEDEF' ),
      ident => &next_id,
      dim   => [map 1+int rand 3, 1 .. (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                                        0,0,0,0,0,0,0,0,1,1,2,2,2,2,3,4)[rand (32 + ($rec+1) - MAXREC)]],
    }
  }

  \@struct;
}

__DATA__

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

unsigned char data[NDATA] = {
[[DATA]]
};

int main( int argc, char **argv )
{
  int i[100][10];
  [[DECLS]]

  if( argc > 1 ) {
    if( strcmp( "types", argv[1] ) == 0 ) {
      printf("\n$types = <<'ENDTYPES';\n");
      <<TYPEDEFS>>
      printf("ENDTYPES\n\n");
    }
    else if( strcmp( "data", argv[1] ) == 0 ) {
      <<DATAGEN>>
    }
    else if( strcmp( "member", argv[1] ) == 0 ) {
      [[MEMBER]]
    }
  }
  else {
    printf("%d => {\n", ALIGNMENT);

    printf("sizeof => {\n");
    [[SIZEOF]]
    printf("},\n");

    [[MEMCPY]]

    printf("content => {\n");
    [[DUMP]]
    printf("}\n");

    printf("},\n");
  }

  return 0;
}
