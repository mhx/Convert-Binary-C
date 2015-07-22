use Convert::Binary::C;

#---------------------------------------------
# Create a new object and parse embedded code
#---------------------------------------------
my $c = Convert::Binary::C->new->parse( <<ENDC );

enum Month { JAN, FEB, MAR, APR, MAY, JUN,
             JUL, AUG, SEP, OCT, NOV, DEC };

struct Date {
  int        year;
  enum Month month;
  int        day;
};

ENDC

#-----------------------------------------------
# Pack Perl data structure into a binary string
#-----------------------------------------------
my $date = { year => 2002, month => 'DEC', day => 24 };

my $packed = $c->pack( 'Date', $date );
