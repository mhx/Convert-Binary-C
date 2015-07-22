use Convert::Binary::C;

#-8<-

$c = Convert::Binary::C->new;

#-8<-

$c = new Convert::Binary::C;

#-8<-

$c->configure(ByteOrder => 'LittleEndian',
              Alignment => 2);

#-8<-

$c = new Convert::Binary::C ByteOrder => 'LittleEndian',
                            Alignment => 2;

#-8<-

$c->ByteOrder('LittleEndian');

#-8<-

$c->parse_file('header.h');

#-8<-

$c->clean; #-8<-

$c->parse(<<'CCODE');
struct foo {
  char ary[3];
  unsigned short baz;
  int bar;
};
CCODE

#-8<-

$c->clean; #-8<-

eval { $c->parse_file('header.h') };
if ($@) {
  # handle error appropriately
}

#-8<-

my $c = eval {
  Convert::Binary::C->new(Include => ['/usr/include'])
                    ->parse_file('header.h')
};
if ($@) {
  # handle error appropriately
}

#-8<-

$data = {
  ary => [1, 2, 3],
  baz => 40000,
  bar => -4711,
};
$binary = $c->pack('foo', $data);

#-8<-

$binary = get_data_from_memory();
$data = $c->unpack('foo', $binary);

#-8<-

print "foo.ary[1] = $data->{ary}[1]\n";

print "#-8<-\n";

#-8<-

use Data::Dumper;
$Data::Dumper::Indent = 1; #-8<-
print Dumper($data);

#-8<-

sub get_data_from_memory {
  $c->pack('foo', {
    ary => [42, 48, 100],
    baz => 5000,
    bar => -271,
  });
};
