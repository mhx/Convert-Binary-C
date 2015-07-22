use Convert::Binary::C;

$c = new Convert::Binary::C;
$c->parse( <<'END' );

#define ADD(a, b) ((a) + (b))
#define NUMBER 42

typedef struct _mytype mytype;

struct _mytype {
  union {
    int         iCount;
    enum count *pCount;
  } counter;
#pragma pack( push, 1 )
  struct {
    char string[NUMBER];
    int  array[NUMBER/sizeof(int)];
  } storage;
#pragma pack( pop )
  mytype *next;
};

enum count { ZERO, ONE, TWO, THREE };

END

print $c->sourcify;

#-8<-
print "#-8<-\n";

print $c->sourcify( { Context => 1 } );

#-8<-
print "#-8<-\n";

print $c->sourcify( { Defines => 1 } );

