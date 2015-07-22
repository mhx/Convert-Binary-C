################################################################################
#
# MODULE: Convert::Binary::C::Cached
#
################################################################################
#
# DESCRIPTION: Cached version of Convert::Binary::C module
#
################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2002/11/28 11:30:58 +0000 $
# $Revision: 6 $
# $Snapshot: /Convert-Binary-C/0.05 $
# $Source: /lib/Convert/Binary/C/Cached.pm $
#
################################################################################
# 
# Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
# 
################################################################################

package Convert::Binary::C::Cached;

use strict;
use Convert::Binary::C;
use Carp;
use vars qw( @ISA $VERSION );

@ISA = qw(Convert::Binary::C);

$VERSION = sprintf '%.2f', 0.01*('$Revision: 6 $' =~ /(\d+)/)[0];

my %cache;

sub new
{
  my $class = shift;
  my $self = $class->SUPER::new;

  $cache{"$self"} = {
    cache      => undef,
    parsed     => 0,
    uses_cache => 0,
  };

  @_ % 2 and croak "Number of configuration arguments to new must be equal";

  @_ and $self->configure( @_ );

  return $self;
}

sub configure
{
  my $self = shift;

  if( @_ < 2 and not defined wantarray ) {
    $^W and carp "Useless use of configure in void context";
    return;
  }

  my $c = $cache{"$self"};

  if( @_ == 0 ) {
    my $cfg = $self->SUPER::configure;
    $cfg->{Cache} = $c->{cache};
    return $cfg;
  }
  elsif( @_ == 1 and $_[0] eq 'Cache' ) {
    return $c->{cache};
  }

  my @args;

  if( @_ == 1 ) {
    @args = @_;
  }
  elsif( @_ % 2 == 0 ) {
    while( @_ ) {
      my %arg = splice @_, 0, 2;
      if( exists $arg{Cache} ) {
        if( $c->{parsed} ) {
          croak 'Cache cannot be configured after parsing';
        }
        elsif( ref $arg{Cache} ) {
          croak 'Cache must be a string value, not a reference';
        }
        else {
          if( defined $arg{Cache} ) {
            eval { require Data::Dumper };
            if( $@ ) {
              $^W and carp "Cannot load Data::Dumper, disabling cache";
              undef $arg{Cache};
            }
            eval { require IO::File };
            if( $@ ) {
              $^W and carp "Cannot load IO::File, disabling cache";
              undef $arg{Cache};
            }
          }
          $c->{cache} = $arg{Cache};
        }
      }
      else { push @args, %arg }
    }
  }

  my $opt = $self;

  if( @args ) {
    $opt = eval { $self->SUPER::configure( @args ) };
    $@ =~ s/\s+at.*?Cached\.pm.*//s, croak $@ if $@;
  }

  $opt;
}

sub clean
{
  my $self = shift;

  $cache{"$self"} = {
    cache      => $cache{"$self"}{cache},
    parsed     => 0,
    uses_cache => 0,
  };

  $self->SUPER::clean;
}

sub clone
{
  my $self = shift;
  my $s = $cache{"$self"};

  $s->{parsed} or croak "Call to clone without parse data";

  unless( defined wantarray ) {
    $^W and carp "Useless use of clone in void context";
    return;
  }

  my $c;
  my $clone = $self->SUPER::clone;

  for( keys %$s ) {
    $c->{$_} = ref $_ eq 'ARRAY' ? [@{$s->{$_}}] : $s->{$_};
  }

  $cache{"$clone"} = $c;

  $clone;
}

sub parse_file
{
  my $self = shift;
  eval { $self->__parse( 'file', $_[0] ) };
  $@ =~ s/\s+at.*?Cached\.pm.*//s, croak $@ if $@;
}

sub parse
{
  my $self = shift;
  eval { $self->__parse( 'code', $_[0] ) };
  $@ =~ s/\s+at.*?Cached\.pm.*//s, croak $@ if $@;
}

sub dependencies
{
  my $self = shift;
  my $c = $cache{"$self"};

  $c->{parsed} or croak "Call to dependencies without parse data";

  unless( defined wantarray ) {
    $^W and carp "Useless use of dependencies in void context";
    return;
  }

  $c->{files} || $self->SUPER::dependencies;
}

sub DESTROY
{
  my $self = shift;
  delete $cache{"$self"};
  $self->SUPER::DESTROY;
}

sub __uses_cache
{
  my $self = shift;
  $cache{"$self"}{uses_cache};
}

sub __parse
{
  my $self = shift;
  my $c = $cache{"$self"};

  if( defined $c->{cache} ) {
    $c->{parsed} and croak "Cannot parse more than once for cached objects";
  
    $c->{$_[0]} = $_[1];
  
    if( $self->__can_use_cache ) {
      eval { $self->SUPER::parse_file( $c->{cache} ) };
      unless( $@ ) {
        $c->{parsed}     = 1;
        $c->{uses_cache} = 1;
        return;
      }
      $self->clean;
    }
  }

  $c->{parsed} = 1;

  my @warnings;
  {
    local $SIG{__WARN__} = sub { push @warnings, $_[0] };

    if( $_[0] eq 'file' ) {
      $self->SUPER::parse_file( $_[1] );
    }
    else {
      $self->SUPER::parse( $_[1] );
    }
  }

  for( @warnings ) {
    s/\s+at.*?Cached\.pm.*//s;
    carp $_;
  }

  defined $c->{cache} and $self->__save_cache;
}

sub __can_use_cache
{
  my $self = shift;
  my $c = $cache{"$self"};
  my $fh = new IO::File;

  -e $c->{cache} and -s _ or return 0;

  unless( $fh->open( $c->{cache} ) ) {
    $^W and carp "Cannot open '$c->{cache}': $!";
    return 0;
  }

  my %config = do {
    defined( my $config = <$fh> ) or return 0;
    $config =~ /^#if\s+0/ or return 0;
    local $/ = $/.'#endif';
    chomp( $config = <$fh> );
    $config =~ s/^\*//gms;
    eval $config;
  };

  my $what = exists $c->{code} ? 'code' : 'file';

  exists $config{$what}
      and $config{$what} eq $c->{$what}
      and __reccmp( $config{cfg}, $self->configure )
      or return 0;

  while( my($file, $spec) = each %{$config{files}} ) {
    -e $file or return 0;
    my($size, $mtime, $ctime) = (stat(_))[7,9,10];
    $spec->{size} == $size
      and $spec->{mtime} == $mtime
      and $spec->{ctime} == $ctime
      or return 0;
  }

  $c->{files} = $config{files};

  return 1;
}

sub __save_cache
{
  my $self = shift;
  my $c = $cache{"$self"};
  my $fh = new IO::File;

  $fh->open( ">$c->{cache}" ) or croak "Cannot open '$c->{cache}': $!";

  my $what = exists $c->{code} ? 'code' : 'file';

  my $config = Data::Dumper->new( [{ $what  => $c->{$what},
                                     cfg    => $self->configure,
                                     files  => $self->SUPER::dependencies,
                                  }], ['*'] )->Indent(1)->Dump;
  $config =~ s/[^(]*//;
  $config =~ s/^/*/gms;

  print $fh "#if 0\n", $config, "#endif\n\n",
            do { local $^W; $self->sourcify };
}

sub __reccmp
{
  my($ref, $val) = @_;

  ref $ref or return $ref eq $val;

  if( ref $ref eq 'ARRAY' ) {
    @$ref == @$val or return 0;
    for( 0..$#$ref ) {
      __reccmp( $ref->[$_], $val->[$_] ) or return 0;
    }
  }
  elsif( ref $ref eq 'HASH' ) {
    @{[keys %$ref]} == @{[keys %$val]} or return 0;
    for( keys %$ref ) {
      __reccmp( $ref->{$_}, $val->{$_} ) or return 0;
    }
  }
  else { return 0 }

  return 1;
}

1;

__END__

=head1 NAME

Convert::Binary::C::Cached - Caching for Convert::Binary::C

=head1 SYNOPSIS

  use Convert::Binary::C::Cached;
  
  $c = new Convert::Binary::C::Cached
               ByteOrder => 'BigEndian',
               Alignment => 8,
               Cache     => '/tmp/foo.cache';
  
  $c->configure( Include => ['/usr/include'],
                 Define  => ['FOOBAR=12345'] );
  
  $c->parse_file( $file );
  $c->Alignment( 2 );
  
  $p = $c->unpack( 'MyType', $data );
  $s = $c->sizeof( 'BigType' );
  $m = $c->member( 'AnotherType', 5 );

=head1 DESCRIPTION

Convert::Binary::C::Cached simply adds caching capability to
Convert::Binary::C. You can use it in just the same way that
you would use Convert::Binary::C. The interface is exactly
the same, which is why the example above is just the same.

To use the caching capability, you must pass the C<Cache> option
to the constructor. If you don't pass it, you will receive
an ordinary Convert::Binary::C object. The argument to
the C<Cache> option is the file that is used for caching
this object.

The caching algorithm automatically detects when the cache
file cannot be used and the original code has to be parsed.
In that case, the cache file is updated. An update of the
cache file can be triggered by one or more of the following
factors:

=over 2

=item *

The cache file doesn't exist, which is obvious.

=item *

The cache file is corrupt, i.e. cannot be parsed.

=item *

The object's configuration has changed.

=item *

The embedded code for a C<parse> method call has changed.

=item *

At least one of the files that the object depends on
does not exist or has a different size or a different
modification or change timestamp.

=back

=head1 LIMITATIONS

You cannot call C<parse> or C<parse_file> more that once
when using a Convert::Binary::C::Cached object. This isn't
a big problem, as you usually don't call them multiple times.

If a dependency file changes, but the change affects neither
the size nor the timestamps of that file, the caching
algorithm cannot detect that an update is required.

=head1 BUGS

Well, see L<LIMITATIONS> above... ;-)

=head1 COPYRIGHT

Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Convert::Binary::C>.

=cut

