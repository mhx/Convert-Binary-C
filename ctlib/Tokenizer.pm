################################################################################
#
# MODULE: Tokenizer
#
################################################################################
#
# DESCRIPTION: Generate C source for fast keyword tokenizer
#
################################################################################
#
# $Project: /Convert-Binary-C $
# $Author: mhx $
# $Date: 2003/02/24 07:21:26 +0000 $
# $Revision: 10 $
# $Snapshot: /Convert-Binary-C/0.11 $
# $Source: /ctlib/Tokenizer.pm $
#
################################################################################
# 
# Copyright (c) 2002-2003 Marcus Holland-Moritz. All rights reserved.
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
# 
################################################################################

package Tokenizer;
use strict;
use vars '$VERSION';

$VERSION = sprintf '%.2f', 0.01*('$Revision: 10 $' =~ /(\d+)/)[0];

sub new
{
  my $class = shift;
  bless {
    tokstr => 'tokstr',
    ulabel => 'unknown',
    endtok => "'\\0'",
    tokfnc => sub { "return $_[0];\n" },
    tokens => {},
    @_
  }, $class;
}

sub addtokens
{
  my($self, $pre, @token) = @_;
  for( @token ) {
    $self->{tokens}{$_} = $pre;
  }
  $self;
}

sub makeswitch
{
  my $self = shift;
  __makeit__( $self, 0, 0, %{$self->{tokens}} );
}

sub __makeit__
{
  my($self, $level, $pre_flag, %t, %tok) = @_;
  my $indent = '    'x$level;

  %t or return '';

  if( keys(%t) == 1 ) {
    my($token) = keys %t;

    if( $level > length $token ) {
      my $rvs = sprintf "%-50s/* %-10s */\n", $indent."{", $token;
      my $code = $self->{tokfnc}->($token);
      $code =~ s/^/$indent  /mg;
      return $rvs.$code.$indent."}\n\n";
    }

    my $rvs = $indent . "if( " . join( '', map {
              $self->{tokstr}."[".($level++)."] == '$_' &&\n$indent    "
              } (substr($token, $level) =~ /(.)/g) ) .
              $self->{tokstr}."[$level] == $self->{endtok} )\n".
              sprintf "%-50s/* %-10s */\n", $indent."{", $token;

    my $code = $self->{tokfnc}->($token);
    $code =~ s/^/$indent  /mg;

    return $rvs.$code.$indent."}\n\n".$indent."goto $self->{ulabel};\n";
  }

  for( keys %t ) {
    my $c = substr $_, $level, 1;
    $tok{$c ? "'$c'" : $self->{endtok}}{$_} = $t{$_};
  }

  my $rvs = $indent."switch( $self->{tokstr}\[$level] )\n".$indent."{\n";
  my $nlflag = 0;

  for( sort keys %tok ) {
    my %seen;
    my @pre = grep { !$seen{$_}++ } values %{$tok{$_}};
    my $clear_pre_flag = 0;

    $nlflag and $rvs .= "\n";

    if( $pre_flag == 0 && @pre == 1 && $pre[0] ) {
      $rvs .= "#if defined $pre[0]\n";
      $pre_flag = $clear_pre_flag = 1;
    }

    $rvs .= $indent."  case $_:\n" .
            $self->__makeit__( $level+1, $pre_flag, %{$tok{$_}} );

    if( $clear_pre_flag ) {
      $rvs .= "#endif /* defined $pre[0] */\n";
      $pre_flag = 0;
    }

    $nlflag = 1;
  }

  $rvs."\n".$indent."  default:\n".
  $indent."    goto $self->{ulabel};\n".
  $indent."}\n";
}

1;

__END__

=head1 NAME

Tokenizer - Generate C source for fast keyword tokenizer

=head1 SYNOPSIS

  use Tokenizer;
  
  $t = new Tokenizer tokfnc => sub { "return \U$_[0];\n" };
  
  $t->addtokens( '', qw( bar baz for ) );
  $t->addtokens( 'DIRECTIVE', qw( foo ) );
  
  print $t->makeswitch;

=head1 DESCRIPTION

The Tokenizer module provides a small class for creating the
essential ANSI C source code for a fast keyword tokenizer.

The generated code is optimized for speed. On the ANSI-C
keyword set, it's 2-3 times faster than equivalent code
generated with the C<gprof> utility.

The above example would print the following C source code:

  switch( tokstr[0] )
  {
    case 'b':
      switch( tokstr[1] )
      {
        case 'a':
          switch( tokstr[2] )
          {
            case 'r':
              if( tokstr[3] == '\0' )
              {                                     /* bar        */
                return BAR;
              }
  
              goto unknown;
  
            case 'z':
              if( tokstr[3] == '\0' )
              {                                     /* baz        */
                return BAZ;
              }
  
              goto unknown;
  
            default:
              goto unknown;
          }
  
        default:
          goto unknown;
      }
  
    case 'f':
      switch( tokstr[1] )
      {
        case 'o':
          switch( tokstr[2] )
          {
  #if defined DIRECTIVE
            case 'o':
              if( tokstr[3] == '\0' )
              {                                     /* foo        */
                return FOO;
              }
  
              goto unknown;
  #endif /* defined DIRECTIVE */
  
            case 'r':
              if( tokstr[3] == '\0' )
              {                                     /* for        */
                return FOR;
              }
  
              goto unknown;
  
            default:
              goto unknown;
          }
  
        default:
          goto unknown;
      }
  
    default:
      goto unknown;
  }

So the generated code only includes the main switch statement for
the tokenizer. You can configure most of the generated code to fit
for your application.

=head1 CONFIGURATION

=head2 tokfnc => SUBROUTINE

A reference to the subroutine that returns the code for each token
match. The only parameter to the subroutine is the token string.

This is the default subroutine:

  tokfnc => sub { "return $_[0];\n" }

=head2 tokstr => STRING

Identifier of the C character array that contains the token string.
The default is C<tokstr>.

=head2 ulabel => STRING

Label that should be jumped to via C<goto> if there's no keyword
matching the token. The default is C<unknown>.

=head2 endtok => STRING

Character that defines the end of each token. The default is the
null character C<'\0'>.

=head1 ADDING KEYWORDS

You can add tokens using the C<addtokens> method. The first parameter
is the name of a preprocessor define if you want the code generated
for the following tokens to be dependent upon that define. If you
don't want that dependency, pass an empty string. Following is a list
of all keyword tokens.

=head1 GENERATING THE CODE

The C<makeswitch> method will return a string with the tokenizer
switch statement.

=head1 AUTHOR

Marcus Holland-Moritz E<lt>mhx@cpan.orgE<gt>

=head1 BUGS

I hope none, since the code is pretty short.
Perhaps lack of functionality ;-)

=head1 COPYRIGHT

Copyright (c) 2002-2003, Marcus Holland-Moritz. All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
