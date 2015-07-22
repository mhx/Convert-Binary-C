
struct basic {
  unsigned int a:9;
  unsigned int b:2;
  unsigned int  :3;
  unsigned int c:2;
  unsigned int d;
};

---------------------------------------

struct uchar {
  unsigned char  a:1;
  unsigned char  b:1;
  unsigned char  c:1;
  unsigned char  d:1;
  unsigned int   e;
};

---------------------------------------

struct ushort {
  unsigned short a:1;
  unsigned short b:1;
  unsigned short c:1;
  unsigned short d:1;
  unsigned int   e;
};

---------------------------------------

struct uint {
  unsigned int   a:1;
  unsigned int   b:1;
  unsigned int   c:1;
  unsigned int   d:1;
  unsigned char  e;
};

---------------------------------------

struct ulong {
  unsigned long  a:1;
  unsigned long  b:1;
  unsigned long  c:1;
  unsigned long  d:1;
  unsigned char  e;
};

---------------------------------------

struct umixed {
  unsigned char  a:1;
  unsigned short b:1;
  unsigned int   c:1;
  unsigned long  d:1;
  unsigned char  e;
};

---------------------------------------

struct smixed {
  signed char  a:1;
  signed short b:1;
  signed int   c:1;
  signed long  d:1;
  signed int   e;
};

---------------------------------------

struct mixed {
  unsigned char  a:1;
  signed   char  b:1;
  unsigned short c:1;
  signed   short d:1;
  unsigned int   e:1;
  signed   int   f:1;
  unsigned long  g:1;
  signed   long  h:1;
  unsigned char  i;
};

---------------------------------------

struct force_align1 {
  unsigned char a:1;
  unsigned char b:1;
  unsigned char  :0;
  unsigned char c:1;
  unsigned int  d;
};

---------------------------------------

struct force_align2 {
  unsigned char  a:2;
  unsigned char  b:2;
  unsigned char   :0;
  unsigned char  c:2;
  unsigned short d;
};

---------------------------------------

struct mixed1 {
  unsigned int a:1;
  unsigned int b:1;
  unsigned int  :0;
  unsigned int c:1;
  signed   int d:1;
  signed   int e:1;
  signed   int  :0;
  signed   int f:1;
  int          g:1;
  int          h:1;
  int           :0;
  int          i:1;
  long         j;
};

---------------------------------------

struct mixed2 {
  unsigned int a:2;
  unsigned int b:2;
  unsigned int  :0;
  unsigned int c:2;
  signed   int d:2;
  signed   int e:2;
  signed   int  :0;
  signed   int f:2;
  int          g:2;
  int          h:2;
  int           :0;
  int          i:2;
  int          j;
};

---------------------------------------

struct uch_wrap {
  unsigned char a:3;
  unsigned char b:3;
  unsigned char c:3;
  unsigned char d:3;
  unsigned char e:3;
  unsigned char f:3;
  unsigned char g:3;
  unsigned char h:3;
  unsigned char i:3;
  unsigned char j:3;
  unsigned char k:3;
  unsigned char l:3;
  unsigned char m:3;
  short         n;
};

---------------------------------------

struct int_wrap {
  int a:3;
  int b:3;
  int c:3;
  int d:3;
  int e:3;
  int f:3;
  int g:3;
  int h:3;
  int i:3;
  int j:3;
  int k:3;
  int l:3;
  int m:3;
  int n;
};

---------------------------------------

struct umixed3 {
  unsigned char  a:3;
  unsigned char  b:3;
  unsigned int   c:3;
  unsigned char  d:3;
  unsigned short e:3;
  unsigned char  f:3;
  unsigned long  g;
};

---------------------------------------

struct umixed_no_pack {
  unsigned char  a:3;
  unsigned char  b:3;
  unsigned short c:3;
  unsigned int   d:28;
  unsigned char  e:3;
  unsigned char  f:2;
  unsigned short g:13;
  signed   int   h;
};

---------------------------------------

#if defined PACK_PAREN
#pragma pack( 1 )
#elif defined PACK_NO_PAREN
#pragma pack 1
#endif
struct umixed_pack_1 {
  unsigned char  a:3;
  unsigned char  b:3;
  unsigned short c:3;
  unsigned int   d:28;
  unsigned char  e:3;
  unsigned char  f:2;
  unsigned short g:13;
  unsigned char  h;
};

---------------------------------------

#if defined PACK_PAREN
#pragma pack( 2 )
#elif defined PACK_NO_PAREN
#pragma pack 2
#endif
struct umixed_pack_2 {
  unsigned char  a:3;
  unsigned char  b:3;
  unsigned short c:3;
  unsigned int   d:28;
  unsigned char  e:3;
  unsigned char  f:2;
  unsigned short g:13;
  unsigned char  h;
};

---------------------------------------

#if defined PACK_PAREN
#pragma pack( 4 )
#elif defined PACK_NO_PAREN
#pragma pack 4
#endif
struct umixed_pack_4 {
  unsigned char  a:3;
  unsigned char  b:3;
  unsigned short c:3;
  unsigned int   d:28;
  unsigned char  e:3;
  unsigned char  f:2;
  unsigned short g:13;
  unsigned char  h;
};

---------------------------------------

typedef int foo;

struct mixed_no_pack {
  unsigned int  a:3;
  signed   int  b:3;
  foo           c:3;
  unsigned char d:3;
  signed   char e:3;
  unsigned int  f:3;
  int            :0;
  unsigned char g:3;
  signed   char h:3;
  unsigned int  i:3;
  char          j;
  unsigned char k:3;
  signed   char l:3;
  unsigned int  m:3;
  unsigned char n;
};

---------------------------------------

typedef int foo;

#if defined PACK_PAREN
#pragma pack( 1 )
#elif defined PACK_NO_PAREN
#pragma pack 1
#endif
struct mixed_pack_1 {
  unsigned int  a:3;
  signed   int  b:3;
  foo           c:3;
  unsigned char d:3;
  signed   char e:3;
  unsigned int  f:3;
  int            :0;
  unsigned char g:3;
  signed   char h:3;
  unsigned int  i:3;
  char          j;
  unsigned char k:3;
  signed   char l:3;
  unsigned int  m:3;
  unsigned char n;
};

---------------------------------------

typedef int foo;

#if defined PACK_PAREN
#pragma pack( 2 )
#elif defined PACK_NO_PAREN
#pragma pack 2
#endif
struct mixed_pack_2 {
  unsigned int  a:3;
  signed   int  b:3;
  foo           c:3;
  unsigned char d:3;
  signed   char e:3;
  unsigned int  f:3;
  int            :0;
  unsigned char g:3;
  signed   char h:3;
  unsigned int  i:3;
  char          j;
  unsigned char k:3;
  signed   char l:3;
  unsigned int  m:3;
  unsigned char n;
};

---------------------------------------

typedef int foo;
enum en_u { UE0, UE1, UE2, UE3, UE4, UE5, UE6, UE7 };
enum en_s { SEM4=-4, SEM3, SEM2, SEM1, SE0, SE1, SE2, SE3 };

#if defined PACK_PAREN
#pragma pack( 1 )
#elif defined PACK_NO_PAREN
#pragma pack 1
#endif
struct enum_pack_1 {
  unsigned int  a:3;
  signed   int  b:3;
  foo           c:3;
  unsigned char d:3;
  enum en_u     e:3;
  unsigned int  f:3;
  int            :0;
  unsigned char g:3;
  signed   char h:3;
  enum en_s     i:3;
  char          j;
  unsigned char k:3;
  signed   char l:3;
  unsigned int  m:3;
  unsigned char n;
};

---------------------------------------

typedef int foo;
enum en_u { UE0, UE1, UE2, UE3, UE4, UE5, UE6, UE7 };
enum en_s { SEM4=-4, SEM3, SEM2, SEM1, SE0, SE1, SE2, SE3 };

#if defined PACK_PAREN
#pragma pack( 2 )
#elif defined PACK_NO_PAREN
#pragma pack 2
#endif
struct enum_pack_2 {
  unsigned int  a:3;
  signed   int  b:3;
  foo           c:3;
  unsigned char d:3;
  enum en_u     e:3;
  unsigned int  f:3;
  int            :0;
  unsigned char g:3;
  signed   char h:3;
  enum en_s     i:3;
  char          j;
  unsigned char k:3;
  signed   char l:3;
  unsigned int  m:3;
  unsigned char n;
};

---------------------------------------

struct toobig {
  unsigned char  a:2;
  unsigned char  b:7;
  short           :0;
  unsigned short c:2;
  unsigned short d:15;
  int             :0;
  unsigned int   e:2;
  unsigned int   f:31;
  unsigned char  g;
};

---------------------------------------

#if defined PACK_PAREN
#pragma pack( 1 )
#elif defined PACK_NO_PAREN
#pragma pack 1
#endif
struct toobig_pack_1 {
  unsigned char  a:2;
  unsigned char  b:7;
  short           :0;
  unsigned short c:2;
  unsigned short d:15;
  int             :0;
  unsigned int   e:2;
  unsigned int   f:31;
  unsigned char  g;
};


---------------------------------------

#if defined PACK_PAREN
#pragma pack( 2 )
#elif defined PACK_NO_PAREN
#pragma pack 2
#endif
struct toobig_pack_1 {
  unsigned char  a:2;
  unsigned char  b:7;
  short           :0;
  unsigned short c:2;
  unsigned short d:15;
  int             :0;
  unsigned int   e:2;
  unsigned int   f:31;
  unsigned char  g;
};

---------------------------------------

#if defined PACK_PAREN
#pragma pack( 4 )
#elif defined PACK_NO_PAREN
#pragma pack 4
#endif
struct toobig_pack_1 {
  unsigned char  a:2;
  unsigned char  b:7;
  short           :0;
  unsigned short c:2;
  unsigned short d:15;
  int             :0;
  unsigned int   e:2;
  unsigned int   f:31;
  unsigned char  g;
};

