use Convert::Binary::C;
use Data::Dumper;
$Data::Dumper::Indent = 1; #-8<-

#----------------------------------------------------------
# Create object, set include path, parse 'string.h' header
#----------------------------------------------------------
my $c = Convert::Binary::C->new
        ->Include( '/usr/lib/gcc-lib/i686-pc-linux-gnu/3.2.2/include',
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

#-8<-

@files = keys %{$c->dependencies};
