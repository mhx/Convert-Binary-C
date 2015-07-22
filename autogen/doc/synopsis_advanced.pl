use Convert::Binary::C;
use Data::Dumper;

#---------------------
# Create a new object
#---------------------
my $c = new Convert::Binary::C ByteOrder => 'BigEndian';

#---------------------------------------------------
# Add include paths and global preprocessor defines
#---------------------------------------------------
$c->Include( '/usr/lib/gcc-lib/i686-pc-linux-gnu/3.3.5/include',
             '/usr/include' )
  ->Define( qw( __USE_POSIX __USE_ISOC99=1 ) );

#----------------------------------
# Parse the 'time.h' header file
#----------------------------------
$c->parse_file( 'time.h' );

#---------------------------------------
# See which files the object depends on
#---------------------------------------
print Dumper( [$c->dependencies] );

#-----------------------------------------------------------
# See if struct timespec is defined and dump its definition
#-----------------------------------------------------------
if( $c->def( 'struct timespec' ) ) {
  print Dumper( $c->struct( 'timespec' ) );
}

#-------------------------------
# Create some binary dummy data
#-------------------------------
my $data = "binaryteststring";

#--------------------------------------------------------
# Unpack $data according to 'struct timespec' definition
#--------------------------------------------------------
if( length($data) >= $c->sizeof( 'timespec' ) ) {
  my $perl = $c->unpack( 'timespec', $data );
  print Dumper( $perl );
}

#--------------------------------------------------------
# See which member lies at offset 5 of 'struct timespec'
#--------------------------------------------------------
my $member = $c->member( 'timespec', 5 );
print "member( 'timespec', 5 ) = '$member'\n";
