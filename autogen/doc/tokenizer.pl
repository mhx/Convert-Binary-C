use lib '../../ctlib'; #-8<-
use Tokenizer;

$t = new Tokenizer tokfnc => sub { "return \U$_[0];\n" };

$t->addtokens( '', qw( bar baz for ) );
$t->addtokens( 'DIRECTIVE', qw( foo ) );

print $t->makeswitch;
