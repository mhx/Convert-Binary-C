use Convert::Binary::C; #-8<-
use Data::Dumper; #-8<-
$Data::Dumper::Indent = 1; $^W = 0; #-8<-

sub obj_pack { $_[0] }
sub obj_unpack { $_[0] }
@protos = qw( A B C );

$c = Convert::Binary::C->new(ByteOrder => 'BigEndian')->parse( <<'#-8<-' );
typedef unsigned short u_16;
typedef u_16 ObjectType, ProtocolId;
#-8<-

$c->add_hooks(ObjectType => { pack   => \&obj_pack,
                              unpack => \&obj_unpack },
              ProtocolId => { unpack => sub {
                                          $protos[$_[0]]
                                        } });

#-8<-

$c->add_hooks(ObjectType => { pack => undef });

#-8<-

$c->delete_hooks(qw(ObjectType ProtocolId));

