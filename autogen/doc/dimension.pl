use Convert::Binary::C; #-8<-
use Data::Dumper; #-8<-
$Data::Dumper::Indent = 0; #-8<-

$c = Convert::Binary::C->new(ByteOrder => 'BigEndian', IntSize => 4)->parse(<<'#-8<-');
struct c_message
{
  unsigned count;
  char data[1];
};
#-8<-

$c->parse(<<'#-8<-');
struct c99_message
{
  unsigned count;
  char data[];
};
#-8<-

$data = pack 'NC*', 3, 1..8;
$uc   = $c->unpack('c_message', $data);
$uc99 = $c->unpack('c99_message', $data);

print Data::Dumper->Dump([$uc], [qw(uc)]), "\n"; #-8<-
print Data::Dumper->Dump([$uc99], [qw(uc99)]), "\n"; #-8<-
print "#-8<-\n";

#-8<-

$c->tag('c_message.data', Dimension => '*');

#-8<-

$uc = $c->unpack('c_message', $data);

print Data::Dumper->Dump([$uc], [qw(uc)]), "\n"; #-8<-
print "#-8<-\n";

#-8<-

$c->tag('c_message.data', Dimension => '5');

$uc = $c->unpack('c_message', $data);  #-8<-
print Data::Dumper->Dump([$uc], [qw(uc)]), "\n"; #-8<-
print "#-8<-\n";

#-8<-

$c->tag('c_message.data', Dimension => 'count');

$uc = $c->unpack('c_message', $data);  #-8<-
print Data::Dumper->Dump([$uc], [qw(uc)]), "\n"; #-8<-
print "#-8<-\n";

#-8<-

$c->parse(<<ENDC);
struct msg_header
{
  unsigned len[2];
};

struct more_complex
{
  struct msg_header hdr;
  char data[];
};
ENDC

$data = pack 'NNC*', 42, 7, 1 .. 10;

$c->tag('more_complex.data', Dimension => 'hdr.len[1]');

$u = $c->unpack('more_complex', $data);

$Data::Dumper::Indent = 1; #-8<-
print Data::Dumper->Dump([$u], [qw(u)]); #-8<-
print "#-8<-\n";

#-8<-

$c->parse(<<ENDC);
typedef unsigned short short_array[];
ENDC

$c->tag('short_array', Dimension => '5');

$u = $c->unpack('short_array', $data);

$Data::Dumper::Indent = 0; #-8<-
print Data::Dumper->Dump([$u], [qw(u)]), "\n"; #-8<-
print "#-8<-\n";

#-8<-

sub get_size
{
  my $m = shift;
  return $m->{hdr}{len}[0] / $m->{hdr}{len}[1];
}

$c->tag('more_complex.data', Dimension => \&get_size);

$u = $c->unpack('more_complex', $data);

$Data::Dumper::Indent = 1; #-8<-
print Data::Dumper->Dump([$u], [qw(u)]); #-8<-
print "#-8<-\n";

