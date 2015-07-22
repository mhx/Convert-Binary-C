use Convert::Binary::C; #-8<-
use Data::Dumper; #-8<-
$Data::Dumper::Indent = 1; #-8<-

sub rout { @_ };

$c = Convert::Binary::C->new(ByteOrder => 'BigEndian')->parse(<<'#-8<-');
typedef char type;
#-8<-

# Attach 'Format' and 'Hooks' tags
$c->tag('type', Format => 'String', Hooks => { pack => \&rout });

$c->untag('type', 'Format');  # Remove only 'Format' tag
$c->untag('type');            # Remove all tags

#-8<-

$c->tag('type', Format => 'String', Hooks => { pack => \&rout }); #-8<-

$tags = $c->tag('type');

$dump = Data::Dumper->new([$tags], ['tags']); #-8<-
$dump->Seen({ '*rout' => \&rout }); #-8<-
print $dump->Dump; #-8<-

