use Convert::Binary::C;

$c = new Convert::Binary::C;
$c->parse( <<'END' );

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
