typedef struct {
  union {
    i_64   i;
  }        val;
  enum {
    INT,
  }        type;
} OpVal;

/  OP_DIV
-  OP_SUB
+  OP_ADD
<  OP_LT
<= OP_LEQ
<< OP_SHL
>  OP_GT
>= OP_GEQ
>> OP_SHR
== OP_EQ
~  OP_BNOT
!= OP_NEQ
&  OP_BAND
&& OP_LAND
|  OP_BOR
|| OP_LOR
%  OP_MOD
*  OP_MUL
^  OP_BXOR
!  OP_LNOT

#define OP_NEG( result, value )
