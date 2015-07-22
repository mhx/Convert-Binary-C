#!/usr/bin/perl -w
use strict;

my %files;
my $lines = 0;
my $errors = 0;
my $warnings = 0;

while( <> ) {
  my(@lines, $pre, $file, $exec, $sec, $str);

  print STDERR "\r$0: processing input line ", ++$lines;

  if( /^(.*?)\$\$(.*?)(?:\s*\[(\d+)\])?\$\$\s*$/ ) {
    ($pre, $file, $sec) = ($1, $2, $3);
    unless( -e $file ) {
      print STDERR "\n$0: (ERROR) cannot find $file!\n";
      $errors++;
      next;
    }
    exists $files{$file} or $files{$file} = 0;
    if( open my $fh, $file ) {
      @lines = <$fh>;
      close $fh;
    }
    else {
      print STDERR "\n$0: ($file) $!\n";
      $errors++;
      next;
    }
  }
  elsif( /^(.*?)\@\@(\s*(\S+).*?)(?:\s*\[(\d+)\])?\@\@\s*$/ ) {
    ($pre, $exec, $file, $sec) = ($1, $2, $3, $4);
    unless( -e $file ) {
      print STDERR "\n$0: (ERROR) cannot find $file!\n";
      $errors++;
      next;
    }
    $files{$file}++;
    @lines = `$^X -w -I../../blib/lib -I../../blib/arch $exec`;
  }
  else { print; next }

  if( defined $sec ) {
    my($cur, @tmp) = (1);

    for( @lines ) {
      if( /^#-+8<-+/ ) {
        last if ++$cur > $sec;
        next;
      }
      if( $cur == $sec ) {
        push @tmp, $_;
      }
    }

    if( $sec > $cur ) {
      my $where = defined $exec ? " output of" : '';
      print STDERR "\n$0: (ERROR) no section [$sec] in$where file $file\n";
      $errors++;
      next;
    }

    @lines = @tmp;
  }

  @lines = map { /#-+8<-+/ ? () : $_ } @lines;

  pop @lines while @lines && $lines[-1] =~ /^\s*$/;
  shift @lines while @lines && $lines[0] =~ /^\s*$/;

  unless( @lines ) {
    my $where = defined $exec ? " output of" : '';
    print STDERR "\n$0: (WARNING) empty section [$sec] in$where file $file\n";
    $warnings++;
    next;
  }

  $str = join '', @lines;

  print indent($pre, $str);
}

print STDERR "\n";

for( grep { !$files{$_} and /\.pl$/ } keys %files ) {
  print STDERR "$0: checking script '$_'\n";
  if( system "$^X -I../../blib/lib -I../../blib/arch $_ >/dev/null 2>&1" ) {
    print STDERR "$0: (WARNING) $_ died!\n";
    $warnings++;
  }
}

print STDERR "$0: $errors error(s), $warnings warning(s)\n";

exit( $errors );

sub indent
{
  my($indent, $str) = @_;
  $str =~ s/^/$indent/gm;
  $str;
}

