#define ABC_SIZE 2
#define MULTIPLY(x, y) ((x)*(y))

#ifdef ABC_SIZE
# define DEFINED
#else
# define NOT_DEFINED
#endif

typedef unsigned long U32;
typedef void *any;

enum __socket_type
{
  SOCK_STREAM    = 1,
  SOCK_DGRAM     = 2,
  SOCK_RAW       = 3,
  SOCK_RDM       = 4,
  SOCK_SEQPACKET = 5,
  SOCK_PACKET    = 10
};

struct STRUCT_SV {
  void *sv_any;
  U32   sv_refcnt;
  U32   sv_flags;
};

typedef union {
  int abc[ABC_SIZE];
  struct xxx {
    int a;
    int b;
  }   ab[3][4];
  any ptr;
} test;
