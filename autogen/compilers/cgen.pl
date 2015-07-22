#!/usr/bin/perl -w
use strict;
use constant MAXREC => 6; # 5
use constant NTYPES => 1;
use Data::Dumper;

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

srand 66;

my $id = 'test';

$typedef{$id} = GetType( 0, 'STRUCT' );

push @typedefs, $id;

my %str = (
  TYPEDEFS => &TypedefString,
  DEBUG    => '', # Dumper(\%typedef),
);

write_template( 'test.h', <<ENDTEMPLATE );
[[TYPEDEFS]]
ENDTEMPLATE

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

sub indent
{
  my($indent, $str) = @_;
  $str =~ s/^/$indent/gm;
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

    # if( ref $h->{type}[1] and exists $h->{type}[1]{'pack'} ) {
    #   $str .= "\n#pragma pack( push, $h->{type}[1]{'pack'} )\n";
    # }

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

    # if( ref $h->{type}[1] and exists $h->{type}[1]{'pack'} ) {
    #   $str .= "#pragma pack( pop )\n\n";
    # }
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
    ['signed char',        'd'  ],
    ['unsigned char',      'u'  ],
    ['signed short',       'hd' ],
    ['unsigned short',     'hu' ],
    ['signed char',        'd'  ],
    ['unsigned char',      'u'  ],
    ['signed short',       'hd' ],
    ['unsigned short',     'hu' ],
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

  for( 0 .. 1 + rand 5 ) {
    if( $rec+1 >= MAXREC or rand(2) > 1 ) {
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
        type => GetType( $rec+1, 'UNION', ('STRUCT')x2 ),
      }
    }
  }

  my %s = ( members => \@struct );

  \%s;
}
