#!/usr/bin/perl -w
use IO::File;
use File::Find;
use Data::Dumper;
use Text::Wrap;
use strict;

my @gcc = splice @ARGV;
my(%assert, %define, @def, $ass);
my $ccc = do { local $/; <> };

my($pre,$def,$asrt,$post) = $ccc =~ /
                                      (.*?)
                                      ^sub \s* _preset_names \s*
                                      ^{\s*
                                        (.*?)
                                        \s*
                                      ^}\s*
                                      ^sub \s* _assert \s*
                                      ^{\s*
                                        (.*?)
                                        \s*
                                      ^}.*?
                                      ^(.*)
                                    /smx;

@def = eval $def;
$ass = eval $asrt;

@define{@def} = map { { $_ => 1 } } @def;
$assert{$_} = { map { $_ => 1 } @{$ass->{$_}} } for keys %$ass;

find( { wanted => \&getsym, no_chdir => 1 }, @gcc );

for my $key ( keys %define ) {
  for( lc $key, uc $key ) {
    if( exists $define{$_} ) {
      my $src = delete $define{$_};
      $define{$key}{$_} = $src->{$_} for keys %$src;
    }
  }
}

my $defines = wrap( ' 'x4, ' 'x4, sort {lc $a cmp lc $b} keys %define );

my $asserts = join ",\n", map {
  my $a = wrap( ' 'x6, ' 'x6, sort {lc $a cmp lc $b} keys %{$assert{$_}} );
  "    '$_' => [qw(\n$a\n    )]"
} sort {lc $a cmp lc $b} keys %assert;

print $pre;
print <<END;
sub _preset_names
{
  qw(
$defines
  )
}

sub _assert
{
  {
$asserts
  }
}
END
print $post;

exit 0;

sub getsym
{
  /\.h$/ or return;
  my $fh = new IO::File $_ or return;
  my $file = do { local $/; <$fh> };
  my $id = '[a-zA-Z_]\w*';

  $file =~ s{\\\s*$/}{}g;

  for( split $/, $file ) {
    my($line) = /^\s*#\s*define[^"]+\"([^"]+)\"/ or next;
    $line =~ /-[DA]/ or next;
    for( $line =~ /(-D$id|-A$id=[\w\$]+)/g ) {
      if( my($sym) = /^-D($id)/ ) {
        my $key = $sym;
        $key =~ /^_+\d/
        or $key =~ s/^__($id)__$/$1/
        or $key =~ s/^__($id)$/$1/
        or $key =~ s/^_($id)$/$1/;
        for( lc $key, uc $key ) {
          if( exists $define{$_} ) {
            my $src = delete $define{$_};
            $define{$key}{$_} = $src->{$_} for keys %$src;
          }
        }
        $define{$key}{$sym}++;
      }
      elsif( my($q,$a) = /^-A($id)=(\w+)$/ ) {
        $q =~ /^___/ or $assert{$q}{$a}++;
      }
    }
  }
}
