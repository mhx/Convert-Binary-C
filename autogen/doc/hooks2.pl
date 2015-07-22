use Convert::Binary::C; #-8<-
use Data::Dumper; #-8<-
$Data::Dumper::Indent = 1; #-8<-

sub obj_pack { $_[0] }
sub obj_unpack { $_[0] }
@protos = qw( A B C );

$c = Convert::Binary::C->new(ByteOrder => 'BigEndian')->parse(<<'#-8<-');
typedef unsigned short u_16;
typedef u_16 ObjectType, ProtocolId;
struct Proto {
  ProtocolId *p_proto;
};
#-8<-

$c->tag('ObjectType', Hooks => {
          pack   => \&obj_pack,
          unpack => \&obj_unpack
        });

$c->tag('ProtocolId', Hooks => {
          unpack => sub { $protos[$_[0]] }
        });

$c->tag('ProtocolId', Hooks => {
          unpack_ptr => [sub {
                           sprintf "$_[0]:{0x%X}", $_[1]
                         },
                         $c->arg('TYPE', 'DATA')
                        ],
        });

#-8<-

$c->untag('ProtocolId', 'Hooks');

#-8<-

$c->tag('ObjectType', Hooks => { pack => undef });

