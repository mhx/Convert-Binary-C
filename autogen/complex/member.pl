#!/usr/bin/perl -w
use strict;

my $align = shift;
my %member = %{eval do {local $/; <>}};
my $first = 1;
my $CC = $ENV{CC} || 'gcc';

print "$align => {\n";
for my $type ( keys %member ) {
  if( $first ) { $first = 0 }
  else { print ",\n" }
  do_it($type, $member{$type});
}
print "},\n";

exit 0;

sub wrap
{
  my $text = shift;
  $text;
}

sub do_it
{
  my($type, $members) = @_;
  my $exe  = "./_mem_tmp_";
  my $file = "$exe.c";

  print STDERR "Building C program...\n";

  my $size  = $members->[-1][1];
  my $count = @$members;

  my $init = join ",\n", map {
               sprintf '  { "%s", %d, %d, %d, %d }',
                       $_->[0], $_->[1], $_->[2], $_->[2]+$_->[1], $_->[3] || 0
             } @$members;

  open TEMP, ">$file" or die "$file: $!\n";
  print TEMP <<ENDC;
#include <stdio.h>
#include <string.h>

#define SIZE  $size
#define COUNT $count

typedef struct {
  char *name;
  long  size;
  long  offset;
  long  end;
  int   basic;
} Member;

static const Member m[COUNT] = {
$init
};

static void find_member( long offset, Member *pBest )
{
  const Member *best[COUNT];
  long          best_sp = 0;
  long          i;

  for( i = 0; i < COUNT; ++i ) {
    if( m[i].offset <= offset && offset < m[i].end ) {
      if( m[i].offset == offset && m[i].basic ) {
        pBest->name   = m[i].name;
        pBest->offset = 0;
        return;
      }
      best[best_sp++] = &m[i];
    }
  }

  for( i = 0; i < best_sp; ++i ) {
    if( best[i]->basic ) {
      pBest->name   = best[i]->name;
      pBest->offset = offset - best[i]->offset;
      return;
    }
  }

  for( i = 1; i < best_sp; ++i )
    if( best[i]->name[0] == best[0]->name[0] )
      if( strncmp( best[0]->name+1, best[i]->name+1, strlen( best[0]->name )-1 ) == 0 )
        best[0] = best[i];

  pBest->name   = best[0]->name;
  pBest->offset = offset - best[0]->offset;
}

int main( void )
{
  long offset;
  Member best;

  for( offset = 0; offset < SIZE; ++offset ) {
    if( (offset-1) % 100 == 0 )
      fprintf(stderr, "$type: \%d/\%d\\r", offset+1, SIZE);
    find_member( offset, &best );
    if( best.offset )
      printf( "\%s+\%d\\n", best.name, best.offset );
    else
      printf( "\%s\\n", best.name );
  }
  fprintf(stderr, "$type: \%d/\%d\\n", SIZE, SIZE);

  return 1;
}
ENDC
  close TEMP;

  print STDERR "Running C compiler...\n";
  system "$CC -O3 -o $exe $file" and die "Ooops, $CC failed: $!\n";
  -e $exe or die "Got no executable...\n";

  print STDERR "Running program...\n";
  my @members = `$exe`;
  chomp @members;

  print STDERR "Deleting intermediate files...\n";
  unlink $exe, $file;

  print STDERR "Simplifying...\n";
  my $i = 0;
  for my $m ( @members ) {
    ($i-1) % 100 == 0 and printf STDERR "$type: %d/$size\r", $i+1;

    if( $m =~ /^([^+]+)\+(\d+)$/ && $members[$i-$2] eq "'$1'" ) {
      $m = $2;
    }
    else {
      $m = "'$m'";
    }

    $i++;
  }
  print STDERR "$type: $size/$size\n";

  print STDERR "Dumping members...\n";
  my $text = join ',', @members;
  $text =~ s/(.{2,159}(?:,|$))/$1\n/g;
  print "$type=>[\n", $text, "]";

  print STDERR "Done!\n";
}
