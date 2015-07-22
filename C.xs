/*******************************************************************************
*
* MODULE: C.xs
*
********************************************************************************
*
* DESCRIPTION: XS Interface for Convert::Binary::C Perl extension module
*
********************************************************************************
*
* $Project: /Convert-Binary-C $
* $Author: mhx $
* $Date: 2002/08/21 14:12:05 +0100 $
* $Revision: 12 $
* $Snapshot: /Convert-Binary-C/0.02 $
* $Source: /C.xs $
*
********************************************************************************
*
* Copyright (c) 2002 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or
* modify it under the same terms as Perl itself.
*
*******************************************************************************/

/*===== GLOBAL INCLUDES ======================================================*/

#include "EXTERN.h"

#if !( PERL_REVISION == 5 && PERL_VERSION >= 6 )
#define _XOPEN_SOURCE
#endif

#include "perl.h"
#include "XSUB.h"


/*===== LOCAL INCLUDES =======================================================*/

#include "util/memalloc.h"
#include "util/list.h"
#include "util/hash.h"
#include "arch.h"
#include "ctdebug.h"
#include "ctparse.h"
#include "cpperr.h"


/*===== DEFINES ==============================================================*/

#define XSCLASS "Convert::Binary::C"

/*-------------------------------------*/
/* some quick paranoid checks first... */
/*-------------------------------------*/

#if (defined I8SIZE && I8SIZE != 1) || \
    (defined U8SIZE && U8SIZE != 1)
#error "Your I8/U8 doesn't seem to have 8 bits..."
#endif

#if (defined I16SIZE && I16SIZE != 2) || \
    (defined U16SIZE && U16SIZE != 2)
#error "Your I16/U16 doesn't seem to have 16 bits..."
#endif

#if (defined I32SIZE && I32SIZE != 4) || \
    (defined U32SIZE && U32SIZE != 4)
#error "Your I32/U32 doesn't seem to have 32 bits..."
#endif

/*---------------*/
/* some defaults */
/*---------------*/

#ifndef DEFAULT_PTR_SIZE
#define DEFAULT_PTR_SIZE    sizeof( void * )
#elif   DEFAULT_PTR_SIZE != 1 && \
        DEFAULT_PTR_SIZE != 2 && \
        DEFAULT_PTR_SIZE != 4
#error "DEFAULT_PTR_SIZE is invalid!"
#endif

#ifndef DEFAULT_ENUM_SIZE
#define DEFAULT_ENUM_SIZE   sizeof( int )
#elif   DEFAULT_ENUM_SIZE != 0 && \
        DEFAULT_ENUM_SIZE != 1 && \
        DEFAULT_ENUM_SIZE != 2 && \
        DEFAULT_ENUM_SIZE != 4
#error "DEFAULT_ENUM_SIZE is invalid!"
#endif

#ifndef DEFAULT_INT_SIZE
#define DEFAULT_INT_SIZE    sizeof( int )
#elif   DEFAULT_INT_SIZE != 1 && \
        DEFAULT_INT_SIZE != 2 && \
        DEFAULT_INT_SIZE != 4
#error "DEFAULT_INT_SIZE is invalid!"
#endif

#ifndef DEFAULT_SHORT_SIZE
#define DEFAULT_SHORT_SIZE  sizeof( short )
#elif   DEFAULT_SHORT_SIZE != 1 && \
        DEFAULT_SHORT_SIZE != 2 && \
        DEFAULT_SHORT_SIZE != 4
#error "DEFAULT_SHORT_SIZE is invalid!"
#endif

#ifndef DEFAULT_LONG_SIZE
#define DEFAULT_LONG_SIZE   sizeof( long )
#elif   DEFAULT_LONG_SIZE != 1 && \
        DEFAULT_LONG_SIZE != 2 && \
        DEFAULT_LONG_SIZE != 4
#error "DEFAULT_LONG_SIZE is invalid!"
#endif

#ifndef DEFAULT_FLOAT_SIZE
#define DEFAULT_FLOAT_SIZE   sizeof( float )
#elif   DEFAULT_FLOAT_SIZE != 1 && \
        DEFAULT_FLOAT_SIZE != 2 && \
        DEFAULT_FLOAT_SIZE != 4 && \
        DEFAULT_FLOAT_SIZE != 8
#error "DEFAULT_FLOAT_SIZE is invalid!"
#endif

#ifndef DEFAULT_DOUBLE_SIZE
#define DEFAULT_DOUBLE_SIZE   sizeof( double )
#elif   DEFAULT_DOUBLE_SIZE != 1 && \
        DEFAULT_DOUBLE_SIZE != 2 && \
        DEFAULT_DOUBLE_SIZE != 4 && \
        DEFAULT_DOUBLE_SIZE != 8
#error "DEFAULT_DOUBLE_SIZE is invalid!"
#endif

#ifndef DEFAULT_ALIGNMENT
#define DEFAULT_ALIGNMENT   1
#elif   DEFAULT_ALIGNMENT != 1 && \
        DEFAULT_ALIGNMENT != 2 && \
        DEFAULT_ALIGNMENT != 4 && \
        DEFAULT_ALIGNMENT != 8
#error "DEFAULT_ALIGNMENT is invalid!"
#endif

#ifndef DEFAULT_ENUMTYPE
#define DEFAULT_ENUMTYPE    ET_INTEGER
#endif

/*-----------------------------*/
/* some stuff for older perl's */
/*-----------------------------*/

/*   <HACK>   */

#if !( PERL_REVISION == 5 && PERL_VERSION >= 6 )

typedef double NV;

#ifndef newSVuv
#define newSVuv( x ) ((UV) (x)) >= (1 << 31)  \
                     ? newSVnv( ((NV) (x)) )  \
                     : newSViv( ((IV) (x)) )
#endif

#ifndef SvPV_nolen
char *SvPV_nolen( SV *sv )
{
  STRLEN len;
  return SvPV( sv, len );
}
#endif

#ifndef sv_vcatpvf
void sv_vcatpvf( SV *sv, const char *pat, va_list *args )
{
  sv_vcatpvfn( sv, pat, strlen(pat), args, NULL, 0, NULL );
}
#endif

#endif

/*   </HACK>   */

/*-----------------------------------------*/
/* prevent a warning when the pointer size */
/* is less than the size of an IV          */
/*-----------------------------------------*/

#if PTRSIZE < IVSIZE
#if PTRSIZE == 4
#define CAST_IV_TO_PTRSIZE (u_32)
#elif PTRSIZE == 2
#define CAST_IV_TO_PTRSIZE (u_16)
#else
#error Unsupported pointer size!
#endif
#else
#define CAST_IV_TO_PTRSIZE
#endif

/*----------------------------------------------------------*/
/* reading/writing integers in big/little endian byte order */
/* depending on the native byte order of the system         */
/*----------------------------------------------------------*/

#ifdef NATIVE_BIG_ENDIAN

/*--------------------*/
/* big endian systems */
/*--------------------*/

#ifndef DEFAULT_BYTEORDER
#define DEFAULT_BYTEORDER   BO_BIG_ENDIAN
#endif

#define GET_LE_WORD( ptr )                                                     \
          ( ( (U16) *( (U8 *) ((ptr)+0) ) <<  0)                               \
          | ( (U16) *( (U8 *) ((ptr)+1) ) <<  8)                               \
          )

#define GET_LE_LONG( ptr )                                                     \
          ( ( (U32) *( (U8 *) ((ptr)+0) ) <<  0)                               \
          | ( (U32) *( (U8 *) ((ptr)+1) ) <<  8)                               \
          | ( (U32) *( (U8 *) ((ptr)+2) ) << 16)                               \
          | ( (U32) *( (U8 *) ((ptr)+3) ) << 24)                               \
          )

#define GET_BE_WORD( ptr )  ( *( (U16 *) (ptr) ) )

#define GET_BE_LONG( ptr )  ( *( (U32 *) (ptr) ) )

#define SET_LE_WORD( ptr, value )                                              \
        do {                                                                   \
          register U16 v = value;                                              \
          *((U8 *) ((ptr)+0)) = (U8) (v >>  0) & 0xFF;                         \
          *((U8 *) ((ptr)+1)) = (U8) (v >>  8) & 0xFF;                         \
        } while(0)

#define SET_LE_LONG( ptr, value )                                              \
        do {                                                                   \
          register U32 v = value;                                              \
          *((U8 *) ((ptr)+0)) = (U8) (v >>  0) & 0xFF;                         \
          *((U8 *) ((ptr)+1)) = (U8) (v >>  8) & 0xFF;                         \
          *((U8 *) ((ptr)+2)) = (U8) (v >> 16) & 0xFF;                         \
          *((U8 *) ((ptr)+3)) = (U8) (v >> 24) & 0xFF;                         \
        } while(0)

#define SET_BE_WORD( ptr, value ) \
          *( (U16 *) (ptr) ) = (U16) value

#define SET_BE_LONG( ptr, value ) \
          *( (U32 *) (ptr) ) = (U32) value

#else /* ! NATIVE_BIG_ENDIAN */

/*-----------------------*/
/* little endian systems */
/*-----------------------*/

#ifndef DEFAULT_BYTEORDER
#define DEFAULT_BYTEORDER   BO_LITTLE_ENDIAN
#endif

#define GET_BE_WORD( ptr )                                                     \
          ( ( (U16) *( (U8 *) ((ptr)+0) ) <<  8)                               \
          | ( (U16) *( (U8 *) ((ptr)+1) ) <<  0)                               \
          )

#define GET_BE_LONG( ptr )                                                     \
          ( ( (U32) *( (U8 *) ((ptr)+0) ) << 24)                               \
          | ( (U32) *( (U8 *) ((ptr)+1) ) << 16)                               \
          | ( (U32) *( (U8 *) ((ptr)+2) ) <<  8)                               \
          | ( (U32) *( (U8 *) ((ptr)+3) ) <<  0)                               \
          )

#define GET_LE_WORD( ptr )  ( *( (U16 *) (ptr) ) )

#define GET_LE_LONG( ptr )  ( *( (U32 *) (ptr) ) )

#define SET_BE_WORD( ptr, value )                                              \
        do {                                                                   \
          register U16 v = (U16) value;                                        \
          *((U8 *) ((ptr)+0)) = (U8) (v >>  8) & 0xFF;                         \
          *((U8 *) ((ptr)+1)) = (U8) (v >>  0) & 0xFF;                         \
        } while(0)

#define SET_BE_LONG( ptr, value )                                              \
        do {                                                                   \
          register U32 v = (U32) value;                                        \
          *((U8 *) ((ptr)+0)) = (U8) (v >> 24) & 0xFF;                         \
          *((U8 *) ((ptr)+1)) = (U8) (v >> 16) & 0xFF;                         \
          *((U8 *) ((ptr)+2)) = (U8) (v >>  8) & 0xFF;                         \
          *((U8 *) ((ptr)+3)) = (U8) (v >>  0) & 0xFF;                         \
        } while(0)

#define SET_LE_WORD( ptr, value ) \
          *( (U16 *) (ptr) ) = (U16) value

#define SET_LE_LONG( ptr, value ) \
          *( (U32 *) (ptr) ) = (U32) value

#endif /* NATIVE_BIG_ENDIAN */

/*---------------------------------------------------------*/
/* macros used by pack/unpack routines for getting/setting */
/* different types of data in a byte buffer                */
/*---------------------------------------------------------*/

#define GET_WORD( byteorder, ptr ) \
          ( (byteorder) == BO_BIG_ENDIAN ? GET_BE_WORD(ptr) : GET_LE_WORD(ptr) )

#define SET_WORD( byteorder, ptr, value )                                      \
          do {                                                                 \
            if( (byteorder) == BO_BIG_ENDIAN )                                 \
              SET_BE_WORD( ptr, value );                                       \
            else                                                               \
              SET_LE_WORD( ptr, value );                                       \
          } while(0)

#define GET_LONG( byteorder, ptr ) \
          ( (byteorder) == BO_BIG_ENDIAN ? GET_BE_LONG(ptr) : GET_LE_LONG(ptr) )

#define SET_LONG( byteorder, ptr, value )                                      \
          do {                                                                 \
            if( (byteorder) == BO_BIG_ENDIAN )                                 \
              SET_BE_LONG( ptr, value );                                       \
            else                                                               \
              SET_LE_LONG( ptr, value );                                       \
          } while(0)

#define GET_SIZE( dest, class, size, sign )                                    \
          do {                                                                 \
            switch( size ) {                                                   \
              case 1: dest = *((sign ## 8 *)(class)->bufptr); break;           \
              case 2: dest = (sign ## 16)                                      \
                             GET_WORD( (class)->byteOrder,                     \
                                       (class)->bufptr ); break;               \
              case 4: dest = (sign ## 32)                                      \
                             GET_LONG( (class)->byteOrder,                     \
                                       (class)->bufptr ); break;               \
            }                                                                  \
          } while(0)

#define SET_SIZE( src, class, size )                                           \
          do {                                                                 \
            switch( size ) {                                                   \
              case 1: *((class)->bufptr) = (U8) src;      break;               \
              case 2: SET_WORD( (class)->byteOrder,                            \
                                (class)->bufptr, src );   break;               \
              case 4: SET_LONG( (class)->byteOrder,                            \
                                (class)->bufptr, src );   break;               \
            }                                                                  \
          } while(0)

/*-------------------------------------------*/
/* floats and doubles can only be accessed   */
/* in native format (at least at the moment) */
/*-------------------------------------------*/

#define GET_DOUBLE( dest, class, size ) \
          dest = (size) == sizeof(double) ? *((double *)(class)->bufptr) : 0.0

#define SET_DOUBLE( src, class, size )                                         \
          do {                                                                 \
            if( (size) == sizeof(double) )                                     \
              *((double *)(class)->bufptr) = src;                              \
          } while(0)

#define GET_FLOAT( dest, class, size ) \
          dest = (size) == sizeof(float) ? *((float *)(class)->bufptr) : 0.0

#define SET_FLOAT( src, class, size )                                          \
          do {                                                                 \
            if( (size) == sizeof(float) )                                      \
              *((float *)(class)->bufptr) = (float) src;                       \
          } while(0)

/*--------------------------------*/
/* macros for buffer manipulation */
/*--------------------------------*/

#define ALIGN_BUFFER( pCTC, align )                                            \
          do {                                                                 \
            unsigned _align = (unsigned)(align) > (pCTC)->alignment            \
                            ? (pCTC)->alignment : (align);                     \
            if( (pCTC)->buf.pos % _align ) {                                   \
              _align -= (pCTC)->buf.pos % _align;                              \
              (pCTC)->buf.pos += _align;                                       \
              (pCTC)->bufptr  += _align;                                       \
            }                                                                  \
          } while(0)

#define CHECK_BUFFER( pCTC, size )                                             \
          do {                                                                 \
            if( (pCTC)->buf.pos + (size) > (pCTC)->buf.length ) {              \
              (pCTC)->dataTooShortFlag = 1;                                    \
              (pCTC)->buf.pos = (pCTC)->buf.length;                            \
              return &PL_sv_undef;                                             \
            }                                                                  \
          } while(0)

#define INC_BUFFER( class, size )                                              \
          do {                                                                 \
            (class)->buf.pos += size;                                          \
            (class)->bufptr  += size;                                          \
          } while(0)

/*--------------------------------------------------*/
/* macros to create SV's/HV's with constant strings */
/*--------------------------------------------------*/

#define NEW_SV_PV_CONST( str ) \
          newSVpvn( str, sizeof(str)/sizeof(char)-1 )

#define HV_STORE_CONST( hash, key, value ) \
          hv_store( hash, key, sizeof(key)/sizeof(char)-1, value, 0 )

/*--------------------------------------*/
/* macros for different checks/warnings */
/*--------------------------------------*/

#if defined G_WARN_ON && defined G_WARN_ALL_ON
#define PERL_WARNINGS_ON (PL_dowarn & (G_WARN_ON | G_WARN_ALL_ON))
#else
#define PERL_WARNINGS_ON  PL_dowarn
#endif

#define WARN( args )  do {                                                     \
                        if( PERL_WARNINGS_ON )                                 \
                          warn args;                                           \
                      } while(0)

#define NO_PARSE_DATA (   THIS->cpi.enums    == NULL \
                       || THIS->cpi.structs  == NULL \
                       || THIS->cpi.typedefs == NULL \
                      )

#define CHECK_PARSE_DATA( method )                                             \
          do {                                                                 \
            if( NO_PARSE_DATA )                                                \
              croak( "Call to " #method " without parse data" );               \
          } while(0)

#define WARN_VOID_CONTEXT( method ) \
            WARN(( "Useless use of " #method " in void context" ))

#define CHECK_VOID_CONTEXT( method )                                           \
          do {                                                                 \
            if( GIMME_V == G_VOID ) {                                          \
              WARN_VOID_CONTEXT( method );                                     \
              XSRETURN_EMPTY;                                                  \
            }                                                                  \
          } while(0)

#define WARN_BITFIELDS( method, type ) \
          WARN(( "Bitfields are unsupported in " #method "('%s')", type ))

#define WARN_UNSAFE( method, type ) \
          WARN(( "Unsafe values used in " #method "('%s')", type ))

#define WARN_FLAGS( method, type, flags )                                      \
          do {                                                                 \
            if( (flags) & T_HASBITFIELD )                                      \
              WARN_BITFIELDS( method, type );                                  \
            else if( (flags) & T_UNSAFE_VAL )                                  \
              WARN_UNSAFE( method, type );                                     \
          } while(0)

#define CROAK_UNDEF_STRUCT( ptr )                                              \
	  croak( "Got no definition for '%s %s'",                              \
	         ptr->tflags & T_UNION ? "union" : "struct",                   \
	         ptr->identifier )

#define WARN_UNDEF_STRUCT( ptr )                                               \
	  warn( "Got no definition for '%s %s'",                               \
	        ptr->tflags & T_UNION ? "union" : "struct",                    \
	        ptr->identifier )

/*----------------------------*/
/* checks if an SV is defined */
/*----------------------------*/

#define DEFINED( sv ) ( (sv) != NULL && (sv) != &PL_sv_undef )

/*---------------*/
/* other defines */
/*---------------*/

#define DEFAULT_HT_SIZE_ENUMERATORS  9U  /* 512 buckets */
#define DEFAULT_HT_SIZE_ENUMS        7U  /* 128 buckets */
#define DEFAULT_HT_SIZE_STRUCTS      8U  /* 256 buckets */
#define DEFAULT_HT_SIZE_TYPEDEFS     8U  /* 256 buckets */

/*-----------------*/
/* debugging stuff */
/*-----------------*/

#ifdef CTYPE_DEBUGGING

#define DBG_CTXT_FMT "%s"

#define DBG_CTXT_ARG (GIMME_V == G_VOID   ? ""   : \
                     (GIMME_V == G_SCALAR ? "$=" : \
                     (GIMME_V == G_ARRAY  ? "@=" : \
                                            "?="   \
                     )))

#endif

/*----------------------*/
/* PerlIO related stuff */
/*----------------------*/

#ifdef PerlIO
typedef PerlIO * DebugStream;
#else
typedef FILE * DebugStream;
#endif

#ifndef PERLIO_IS_STDIO
# ifdef fprintf
#  undef fprintf
# endif
# define fprintf PerlIO_printf
# ifdef vfprintf
#  undef vfprintf
# endif
# define vfprintf PerlIO_vprintf
# ifdef stderr
#  undef stderr
# endif
# define stderr PerlIO_stderr()
# ifdef fopen
#  undef fopen
# endif
# define fopen PerlIO_open
# ifdef fclose
#  undef fclose
# endif
# define fclose PerlIO_close
#endif


/*===== TYPEDEFS =============================================================*/

typedef struct {
  char         *bufptr;
  unsigned      alignment;
  int           dataTooShortFlag;
  Buffer        buf;
  CParseConfig  cfg;
  CParseInfo    cpi;
  enum {
    BO_BIG_ENDIAN, BO_LITTLE_ENDIAN
  }             byteOrder;
  enum {
    ET_INTEGER, ET_STRING, ET_BOTH
  }             enumType;
} CBC;

typedef struct {
  enum {
    TYP_ENUM,
    TYP_STRUCT,
    TYP_TYPEDEF
  } type;
  union {
    EnumSpecifier *pEnum;
    Struct        *pStruct;
    Typedef       *pTypedef;
  } spec;
} TypePointer;

typedef struct {
  const int   value;
  const char *string;
} StringOption;


/*===== STATIC FUNCTION PROTOTYPES ===========================================*/

#ifdef CTYPE_DEBUGGING
static void debug_vprintf( char *f, va_list l );
static void debug_printf( char *f, ... );
static void debug_printf_ctlib( char *f, ... );
static void SetDebugOptions( char *dbopts );
static void SetDebugFile( char *dbfile );
#endif

static void DumpSV( SV *buf, int level, SV *sv );

static void fatal( char *f, ... );
static void *ct_newstr( void );
static void ct_scatf( void *p, char *f, ... );
static void ct_vscatf( void *p, char *f, va_list l );
static void ct_warn( void *p );
static void ct_fatal( void *p );

static char *string_new_fromSV( SV *sv );
static void string_delete( char *sv );

static void CroakGTI( ErrorGTI error, char *name, int warnOnly );

static SV *GetPointer( CBC *THIS );
static SV *GetStruct( CBC *THIS, Struct *pStruct );
static SV *GetEnum( CBC *THIS, EnumSpecifier *pEnumSpec );
static SV *GetBasicType( CBC *THIS, u_32 flags );
static SV *GetTypedef( CBC *THIS, Typedef *pTypedef );
static SV *GetType( CBC *THIS, TypeSpec *pTS,
                    Declarator *pDecl, int dimension );

static void SetPointer( CBC *THIS, SV *sv );
static void SetStruct( CBC *THIS, Struct *pStruct, SV *sv );
static void SetEnum( CBC *THIS, EnumSpecifier *pEnumSpec, SV *sv );
static void SetBasicType( CBC *THIS, u_32 flags, SV *sv );
static void SetTypedef( CBC *THIS, Typedef *pTypedef, SV *sv, char *name );
static void SetType( CBC *THIS, TypeSpec *pTS, Declarator *pDecl,
                     int dimension, SV *sv, char *name );

static SV *GetTypeSpec( TypeSpec *pTSpec );
static SV *GetTypedefSpec( Typedef *pTypedef );

static SV *GetEnumerators( LinkedList enumerators );
static SV *GetEnumSpec( EnumSpecifier *pEnumSpec );

static SV *GetDeclarators( LinkedList declarators );
static SV *GetStructDeclarations( LinkedList declarations );
static SV *GetStructSpec( Struct *pStruct );

static void GetStructMember( Struct *pStruct, int offset, SV *sv, int dotflag );
static SV *GetOffsetOf( Struct *pStruct, const char *member );

static int GetTypePointer( CBC *THIS, const char *name, TypePointer *pTYP );
static int IsTypedefDefined( Typedef *pTypedef );

static int CheckIntegerOption( const IV *options, int count, SV *sv,
                               IV *value, const char *name );
static const StringOption *GetStringOption( const StringOption *options, int count,
                                            int value, SV *sv, const char *name );
static void HandleStringList( char *option, LinkedList list, SV *sv, SV **rval );
static int  HandleOption( CBC *THIS, SV *opt, SV *sv_val, SV **rval );
static SV  *GetConfiguration( CBC *THIS );
static void UpdateConfiguration( CBC *THIS );


/*===== EXTERNAL VARIABLES ===================================================*/

/*===== GLOBAL VARIABLES =====================================================*/

/*===== STATIC VARIABLES =====================================================*/

#ifdef CTYPE_DEBUGGING
static DebugStream gs_DB_stream;
#endif

#ifdef CBC_THREAD_SAFE
static perl_mutex gs_parse_mutex;
#endif

/*===== STATIC FUNCTIONS =====================================================*/

/*******************************************************************************
*
*   ROUTINE: DumpSV
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Dumps an SV similar to (but a lot simpler than) Devel::Peek's
*              Dump function, but instead of writing to the debug output, it
*              returns a Perl string that can be used for further processing.
*              Currently, the only useful information is the reference count.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

#define INDENT for(i=0;i<level;i++) sv_catpv(buf,"  ")

static void DumpSV( SV *buf, int level, SV *sv )
{
  I32 i;
  char *str;
  svtype type = SvTYPE( sv );

  switch( type ) {
    case SVt_NULL: str = "NULL"; break;
    case SVt_IV:   str = "IV";   break;
    case SVt_NV:   str = "NV";   break;
    case SVt_RV:   str = "RV";   break;
    case SVt_PV:   str = "PV";   break;
    case SVt_PVIV: str = "PVIV"; break;
    case SVt_PVNV: str = "PVNV"; break;
    case SVt_PVMG: str = "PVMG"; break;
    case SVt_PVBM: str = "PVBM"; break;
    case SVt_PVLV: str = "PVLV"; break;
    case SVt_PVAV: str = "PVAV"; break;
    case SVt_PVHV: str = "PVHV"; break;
    case SVt_PVCV: str = "PVCV"; break;
    case SVt_PVGV: str = "PVGV"; break;
    case SVt_PVFM: str = "PVFM"; break;
    case SVt_PVIO: str = "PVIO"; break;
    default      : str = "UNKNOWN";
  }

  INDENT; level++;
  sv_catpvf( buf, "SV = %s @ 0x%x (REFCNT = %d)\n", str, sv, SvREFCNT(sv) );

  switch( type ) {
    case SVt_RV:
      DumpSV( buf, level, SvRV( sv ) );
      break;

    case SVt_PVAV:
      {
        AV *av = (AV *) sv;
        I32 c, n;
        for( c=0, n=av_len(av); c<=n; ++c ) {
          SV **p = av_fetch( av, c, 0 );
          if( p ) {
            INDENT;
            sv_catpvf( buf, "index = %d\n", c );
            DumpSV( buf, level, *p );
          }
        }
      }
      break;

    case SVt_PVHV:
      {
        HV *hv = (HV *) sv;
        SV *v; I32 len;
        hv_iterinit( hv );
        while( (v = hv_iternextsv( hv, &str, &len )) != 0 ) {
          INDENT;
          sv_catpv( buf, "key = \"" );
          sv_catpvn( buf, str, len );
          sv_catpv( buf, "\"\n" );
          DumpSV( buf, level, v );
        }
      }
      break;

    default:
      /* nothing */
      break;
  }
}

#undef INDENT

/*******************************************************************************
*
*   ROUTINE: fatal
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Write fatal error to standard error and abort().
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static void fatal( char *f, ... )
{
  va_list l;
  SV *sv = sv_2mortal( newSVpvn( "", 0 ) );

  va_start( l, f );

  sv_catpv( sv,
  "============================================\n"
  "     FATAL ERROR in " XSCLASS "!\n"
  "--------------------------------------------\n"
  );

  sv_vcatpvf( sv, f, &l );
  
  sv_catpv( sv,
  "\n"
  "--------------------------------------------\n"
  "  please report this error to mhx@cpan.org\n"
  "============================================\n"
  );

  va_end( l );

  fprintf( stderr, "%s", SvPVX( sv ) );

  abort();
}

/*******************************************************************************
*
*   ROUTINE: ct_*
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: These functions are used to build arbitrary strings within the
*              ctlib routines and to provide an interface to perl's warn().
*
*******************************************************************************/

static void *ct_newstr( void )
{
  return (void *) sv_2mortal( newSVpvn( "", 0 ) );
}

static void ct_scatf( void *p, char *f, ... )
{
  va_list l;
  va_start( l, f );
  sv_vcatpvf( (SV*)p, f, &l );
  va_end( l );
}

static void ct_vscatf( void *p, char *f, va_list l )
{
  sv_vcatpvf( (SV*)p, f, &l );
}

static void ct_warn( void *p )
{
  WARN(( "%s", SvPV_nolen( (SV*)p ) ));
}

static void ct_fatal( void *p )
{
  fatal( "%s", SvPV_nolen( (SV*)p ) );
}

/*******************************************************************************
*
*   ROUTINE: string_new_fromSV
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: May 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static char *string_new_fromSV( SV *sv )
{
  char *cpy = NULL;

  if( sv != NULL ) {
    char  *str;
    STRLEN len;

    str = SvPV( sv, len );
    len++;

    New( 0, cpy, len, char );
    Copy( str, cpy, len, char );
  }

  return cpy;
}

/*******************************************************************************
*
*   ROUTINE: string_delete
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: May 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static void string_delete( char *str )
{
  Safefree( str );
}

/*******************************************************************************
*
*   ROUTINE: CroakGTI
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static void CroakGTI( ErrorGTI error, char *name, int warnOnly )
{
  char *errstr = NULL;

  switch( error ) {
    case GTI_NO_ERROR:
      return;

    case GTI_TYPEDEF_IS_NULL:
      errstr = "NULL pointer to typedef";
      break;

    case GTI_NO_ENUM_SIZE:
      errstr = "Got no enum size";
      break;

    case GTI_NO_STRUCT_DECL:
      errstr = "Got no struct declarations";
      break;

    case GTI_STRUCT_IS_NULL:
      errstr = "NULL pointer to struct/union";
      break;

    default:
      if( name )
        fatal( "Unknown error %d in resolution of '%s'", error, name );
      else
        fatal( "Unknown error %d in resolution of typedef", error );
      break;
  }

  if( warnOnly ) {
    if( name )
      WARN(( "%s in resolution of '%s'", errstr, name ));
    else
      WARN(( "%s in resolution of typedef", errstr ));
  }
  else {
    if( name )
      croak( "%s in resolution of '%s'", errstr, name );
    else
      croak( "%s in resolution of typedef", errstr );
  }
}

/*******************************************************************************
*
*   ROUTINE: SetPointer
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static void SetPointer( CBC *THIS, SV *sv )
{
  int size = THIS->cfg.ptr_size ? THIS->cfg.ptr_size : sizeof( void * );

  CT_DEBUG( MAIN, (XSCLASS "::SetPointer( THIS=0x%08X, sv=0x%08X )", THIS, sv) );

  ALIGN_BUFFER( THIS, size );

  if( DEFINED( sv ) && ! SvROK( sv ) ) {
    UV ptrval = SvUV( sv );
    CT_DEBUG( MAIN, ("SvUV( sv ) = %u", ptrval) );
    SET_SIZE( ptrval, THIS, size );
  }

  INC_BUFFER( THIS, size );
}

/*******************************************************************************
*
*   ROUTINE: SetStruct
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static void SetStruct( CBC *THIS, Struct *pStruct, SV *sv )
{
  StructDeclaration *pStructDecl;
  Declarator        *pDecl;

  char *bufptr;
  int   pos;

  CT_DEBUG( MAIN, (XSCLASS "::SetStruct( THIS=0x%08X, pStruct=0x%08X, sv=0x%08X )",
            THIS, pStruct, sv) );

  if( THIS->buf.pos % pStruct->align ) {
    int corr = pStruct->align - THIS->buf.pos % pStruct->align;

    THIS->buf.pos += corr;
    THIS->bufptr  += corr;
  }

  bufptr = THIS->bufptr;
  pos    = THIS->buf.pos;

  if( DEFINED( sv ) ) {
    SV *hash;

    if( SvROK( sv ) && SvTYPE( hash = SvRV(sv) ) == SVt_PVHV ) {
      HV *h = (HV *) hash;
      int old_align;

      if( pStruct->pack ) {
        old_align = THIS->alignment;
        THIS->alignment = pStruct->pack;
      }
  
      LL_foreach( pStructDecl, pStruct->declarations )
        LL_foreach( pDecl, pStructDecl->declarators ) {
          SV **e = hv_fetch( h, pDecl->identifier,
                             strlen(pDecl->identifier), 0 );

          SetType( THIS, &pStructDecl->type, pDecl, 0,
                   e ? *e : NULL, pDecl->identifier );
    
          if( pStruct->tflags & T_UNION ) {
            THIS->bufptr  = bufptr;
            THIS->buf.pos = pos;
          }
        }
  
      if( pStruct->pack )
        THIS->alignment = old_align;
    }
  }

  THIS->bufptr  = bufptr + pStruct->size;
  THIS->buf.pos = pos    + pStruct->size;
}

/*******************************************************************************
*
*   ROUTINE: SetEnum
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static void SetEnum( CBC *THIS, EnumSpecifier *pEnumSpec, SV *sv )
{
  int size = THIS->cfg.enum_size ? THIS->cfg.enum_size : pEnumSpec->size;
  IV value = 0;

  CT_DEBUG( MAIN, (XSCLASS "::SetEnum( THIS=0x%08X, pEnumSpec=0x%08X, sv=0x%08X )",
            THIS, pEnumSpec, sv) );

  /* TODO: add some checks (range, perhaps even value) */

  ALIGN_BUFFER( THIS, size );
  
  if( DEFINED( sv ) && ! SvROK( sv ) ) {
    if( SvIOK( sv ) ) {
      value = SvIVX( sv );
    }
    else {
      Enumerator *pEnum = NULL;
  
      if( SvPOK( sv ) ) {
        STRLEN len;
        char *str = SvPV( sv, len );
  
        pEnum = HT_get( THIS->cpi.htEnumerators, str, len, 0 );
        
        if( pEnum ) {
          if( IS_UNSAFE_VAL( pEnum->value ) )
            WARN(( "Enumerator value '%s' is unsafe", str ));
          value = pEnum->value.iv;
        }
      }
  
      if( pEnum == NULL )
        value = SvIV( sv );
    }
  
    CT_DEBUG( MAIN, ("value(sv) = %d", value) );
  
    SET_SIZE( value, THIS, size );
  }

  INC_BUFFER( THIS, size );
}

/*******************************************************************************
*
*   ROUTINE: SetBasicType
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static void SetBasicType( CBC *THIS, u_32 flags, SV *sv )
{
  int size;

  CT_DEBUG( MAIN, (XSCLASS "::SetBasicType( THIS=0x%08X, flags=0x%08X, sv=0x%08X )",
            THIS, flags, sv) );

#define LOAD_SIZE( type ) \
        size = THIS->cfg.type ## _size ? THIS->cfg.type ## _size : sizeof(type)

  if( flags & T_VOID )  /* XXX: do we want void ? */
    size = 1;
  else if( flags & T_CHAR ) {
    size = 1;
    if( (flags & (T_SIGNED|T_UNSIGNED)) == 0 &&
        (THIS->cfg.flags & CHARS_ARE_UNSIGNED) )
      flags |= T_UNSIGNED;
  }
  else if( flags & T_FLOAT )  LOAD_SIZE( float );
  else if( flags & T_DOUBLE ) LOAD_SIZE( double );
  else if( flags & T_SHORT )  LOAD_SIZE( short );
  else if( flags & T_LONG )   LOAD_SIZE( long );
  else                        LOAD_SIZE( int );

#undef LOAD_SIZE

  ALIGN_BUFFER( THIS, size );

  if( DEFINED( sv ) && ! SvROK( sv ) ) {
    if( flags & (T_DOUBLE | T_FLOAT) ) {
      NV value = SvNV( sv );
  
      CT_DEBUG( MAIN, ("SvNV( sv ) = %f", value) );
  
      if( flags & T_DOUBLE )
        SET_DOUBLE( value, THIS, size );
      else /* T_FLOAT */
        SET_FLOAT( value, THIS, size );
    }
    else {
      if( flags & T_UNSIGNED ) {
        UV value = SvUV( sv );
        CT_DEBUG( MAIN, ("SvUV( sv ) = %u", value) );
        SET_SIZE( value, THIS, size );
      }
      else {
        IV value = SvIV( sv );
        CT_DEBUG( MAIN, ("SvIV( sv ) = %d", value) );
        SET_SIZE( value, THIS, size );
      }
    }
  }

  INC_BUFFER( THIS, size );
}

/*******************************************************************************
*
*   ROUTINE: SetTypedef
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static void SetTypedef( CBC *THIS, Typedef *pTypedef, SV *sv, char *name )
{
  CT_DEBUG( MAIN, (XSCLASS "::SetTypedef( THIS=0x%08X, pTypedef=0x%08X, "
                    "sv=0x%08X, name='%s' )", THIS, pTypedef, sv, name) );

  SetType( THIS, &pTypedef->type, pTypedef->pDecl, 0, sv, name );
}

/*******************************************************************************
*
*   ROUTINE: SetType
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static void SetType( CBC *THIS, TypeSpec *pTS, Declarator *pDecl,
                     int dimension, SV *sv, char *name )
{
  CT_DEBUG( MAIN, (XSCLASS "::SetType( THIS=0x%08X, pTS=0x%08X, pDecl=0x%08X, "
            "dimension=%d, sv=0x%08X, name='%s' )",
            THIS, pTS, pDecl, dimension, sv, name) );

  if( dimension < LL_size( pDecl->array ) ) {
    SV *ary;

    if( sv && SvROK( sv ) && SvTYPE( ary = SvRV(sv) ) == SVt_PVAV ) {
      long i, s = ((Value *) LL_get( pDecl->array, dimension ))->iv;
      AV *a = (AV *) ary;
    
      for( i = 0; i < s; ++i ) {
        SV **e = av_fetch( a, i, 0 );
        SetType( THIS, pTS, pDecl, dimension+1, e ? *e : NULL, name );
      }
    }
    else {
      unsigned size, align;
      int dim;
      ErrorGTI err;

      if( sv )
        WARN(( "'%s' should be an array reference", name ));

      err = GetTypeInfo( &THIS->cfg, pTS, NULL, &size, &align, NULL, NULL );
      if( err != GTI_NO_ERROR )
        CroakGTI( err, name, 1 );

      ALIGN_BUFFER( THIS, align );

      dim = LL_size( pDecl->array );

      while( dim-- > dimension )
        size *= ((Value *) LL_get( pDecl->array, dim ))->iv;

      INC_BUFFER( THIS, size );
    }
  }
  else {
    if( pDecl->pointer_flag ) {
      if( sv && SvROK( sv ) )
        WARN(( "'%s' should be a scalar value", name ));
      SetPointer( THIS, sv );
    }
    else if( pDecl->bitfield_size >= 0 ) {
      /* unsupported */
    }
    else if( pTS->tflags & T_TYPE ) {
      SetTypedef( THIS, pTS->ptr, sv, name );
    }
    else if( pTS->tflags & (T_STRUCT|T_UNION) ) {
      Struct *pStruct = pTS->ptr;
      if( pStruct->declarations == NULL ) {
        WARN_UNDEF_STRUCT( pStruct );
        return;
      }
      else {
        if( sv && !(SvROK( sv ) && SvTYPE( SvRV(sv) ) == SVt_PVHV) )
          WARN(( "'%s' should be a hash reference", name ));
        SetStruct( THIS, pStruct, sv );
      }
    }
    else {
      if( sv && SvROK( sv ) )
        WARN(( "'%s' should be a scalar value", name ));

      if( pTS->tflags & T_ENUM )
        SetEnum( THIS, pTS->ptr, sv );
      else
        SetBasicType( THIS, pTS->tflags, sv );
    }
  }
}

/*******************************************************************************
*
*   ROUTINE: GetPointer
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static SV *GetPointer( CBC *THIS )
{
  UV ptrval;
  int size = THIS->cfg.ptr_size ? THIS->cfg.ptr_size : sizeof( void * );

  CT_DEBUG( MAIN, (XSCLASS "::GetPointer( THIS=0x%08X )", THIS) );

  ALIGN_BUFFER( THIS, size );
  CHECK_BUFFER( THIS, size );
  GET_SIZE( ptrval, THIS, size, U );
  INC_BUFFER( THIS, size );

  return newSVuv( ptrval );
}

/*******************************************************************************
*
*   ROUTINE: GetStruct
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static SV *GetStruct( CBC *THIS, Struct *pStruct )
{
  StructDeclaration *pStructDecl;
  Declarator        *pDecl;
  HV                *h = newHV();

  char *bufptr;
  int   pos, old_align;

  CT_DEBUG( MAIN, (XSCLASS "::GetStruct( THIS=0x%08X, pStruct=0x%08X )",
            THIS, pStruct) );

  if( THIS->buf.pos % pStruct->align ) {
    int corr = pStruct->align - THIS->buf.pos % pStruct->align;

    THIS->buf.pos += corr;
    THIS->bufptr  += corr;
  }

  bufptr = THIS->bufptr;
  pos    = THIS->buf.pos;

  if( pStruct->pack ) {
    old_align = THIS->alignment;
    THIS->alignment = pStruct->pack;
  }

  LL_foreach( pStructDecl, pStruct->declarations )
    LL_foreach( pDecl, pStructDecl->declarators ) {
      hv_store( h, pDecl->identifier, strlen(pDecl->identifier),
                GetType( THIS, &pStructDecl->type, pDecl, 0 ), 0 );

      if( pStruct->tflags & T_UNION ) {
        THIS->bufptr  = bufptr;
        THIS->buf.pos = pos;
      }
    }

  if( pStruct->pack )
    THIS->alignment = old_align;

  THIS->bufptr  = bufptr + pStruct->size;
  THIS->buf.pos = pos    + pStruct->size;

  return newRV_noinc( (SV *) h );
}

/*******************************************************************************
*
*   ROUTINE: GetEnum
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static SV *GetEnum( CBC *THIS, EnumSpecifier *pEnumSpec )
{
  Enumerator *pEnum;
  int size = THIS->cfg.enum_size ? THIS->cfg.enum_size : pEnumSpec->size;
  IV value;
  SV *sv;

  CT_DEBUG( MAIN, (XSCLASS "::GetEnum( THIS=0x%08X, pEnumSpec=0x%08X )",
            THIS, pEnumSpec) );

  ALIGN_BUFFER( THIS, size );
  CHECK_BUFFER( THIS, size );

  if( pEnumSpec->tflags & T_SIGNED ) /* TODO: handle signed/unsigned correctly */
    GET_SIZE( value, THIS, size, I );
  else
    GET_SIZE( value, THIS, size, U );

  INC_BUFFER( THIS, size );

  if( THIS->enumType == ET_INTEGER )
    return newSViv( value );

  LL_foreach( pEnum, pEnumSpec->enumerators )
    if( pEnum->value.iv == value )
      break;

  if( pEnumSpec->tflags & T_UNSAFE_VAL ) {
    if( pEnumSpec->identifier[0] != '\0' )
      WARN(( "Enumeration '%s' contains unsafe values", pEnumSpec->identifier ));
    else
      WARN(( "Enumeration contains unsafe values" ));
  }

  switch( THIS->enumType ) {
    case ET_BOTH:
      sv = newSViv( value );
      if( pEnum )
        sv_setpv( sv, pEnum->identifier );
      else
        sv_setpvf( sv, "<ENUM:%d>", value );
      SvIOK_on( sv );
      break;

    case ET_STRING:
      if( pEnum )
        sv = newSVpv( pEnum->identifier, 0 );
      else
        sv = newSVpvf( "<ENUM:%d>", value );
      break;

    default:
      fatal( "Invalid enum type (%d) in GetEnum()!", THIS->enumType );
      break;
  }

  return sv;
}

/*******************************************************************************
*
*   ROUTINE: GetBasicType
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static SV *GetBasicType( CBC *THIS, u_32 flags )
{
  int size;
  SV *sv;

  CT_DEBUG( MAIN, (XSCLASS "::GetBasicType( THIS=0x%08X, flags=0x%08X )",
            THIS, flags) );

  CT_DEBUG( MAIN, ("buffer.pos=%d, buffer.length=%d",
            THIS->buf.pos, THIS->buf.length) );

#define LOAD_SIZE( type ) \
        size = THIS->cfg.type ## _size ? THIS->cfg.type ## _size : sizeof(type)

  if( flags & T_VOID )  /* XXX: do we want void ? */
    size = 1;
  else if( flags & T_CHAR ) {
    size = 1;
    if( (flags & (T_SIGNED|T_UNSIGNED)) == 0 &&
        (THIS->cfg.flags & CHARS_ARE_UNSIGNED) )
      flags |= T_UNSIGNED;
  }
  else if( flags & T_FLOAT )  LOAD_SIZE( float );
  else if( flags & T_DOUBLE ) LOAD_SIZE( double );
  else if( flags & T_SHORT )  LOAD_SIZE( short );
  else if( flags & T_LONG )   LOAD_SIZE( long );
  else                        LOAD_SIZE( int );

#undef LOAD_SIZE

  ALIGN_BUFFER( THIS, size );
  CHECK_BUFFER( THIS, size );

  if( flags & (T_FLOAT | T_DOUBLE) ) {
    NV value;
    if( flags & T_FLOAT )
      GET_FLOAT( value, THIS, size );
    else
      GET_DOUBLE( value, THIS, size );
    sv = newSVnv( value );
  }
  else if( flags & T_UNSIGNED ) {
    UV value;
    GET_SIZE( value, THIS, size, U );
    sv = newSVuv( value );
  }
  else {
    IV value;
    GET_SIZE( value, THIS, size, I );
    sv = newSViv( value );
  }

  INC_BUFFER( THIS, size );

  return sv;
}

/*******************************************************************************
*
*   ROUTINE: GetTypedef
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static SV *GetTypedef( CBC *THIS, Typedef *pTypedef )
{
  CT_DEBUG( MAIN, (XSCLASS "::GetTypedef( THIS=0x%08X, pTypedef=0x%08X )",
            THIS, pTypedef) );

  return GetType( THIS, &pTypedef->type, pTypedef->pDecl, 0 );
}

/*******************************************************************************
*
*   ROUTINE: GetType
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static SV *GetType( CBC *THIS, TypeSpec *pTS,
                    Declarator *pDecl, int dimension )
{
  CT_DEBUG( MAIN, (XSCLASS "::GetType( THIS=0x%08X, pTS=0x%08X, "
            "pDecl=0x%08X, dimension=%d )", THIS, pTS, pDecl, dimension) );

  if( dimension < LL_size( pDecl->array ) ) {
    AV *a = newAV();
    long s = ((Value *) LL_get( pDecl->array, dimension ))->iv;

    while( s-- > 0 )
      av_push( a, GetType( THIS, pTS, pDecl, dimension+1 ) );

    return newRV_noinc( (SV *) a );
  }
  else {
    if( pDecl->pointer_flag )              return GetPointer( THIS );
    if( pDecl->bitfield_size >= 0 )        return &PL_sv_undef;  /* unsupported */
    if( pTS->tflags & T_TYPE )             return GetTypedef( THIS, pTS->ptr );
    if( pTS->tflags & (T_STRUCT|T_UNION) ) {
      Struct *pStruct = pTS->ptr;
      if( pStruct->declarations == NULL ) {
        WARN_UNDEF_STRUCT( pStruct );
        return &PL_sv_undef;
      }
      return GetStruct( THIS, pTS->ptr );
    }
    if( pTS->tflags & T_ENUM )             return GetEnum( THIS, pTS->ptr );

    return GetBasicType( THIS, pTS->tflags );
  }
}

/*******************************************************************************
*
*   ROUTINE: GetTypeSpec
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static SV *GetTypeSpec( TypeSpec *pTSpec )
{
  u_32 flags = pTSpec->tflags;

  if( flags & T_TYPE ) {
    Typedef *pTypedef= (Typedef *) pTSpec->ptr;

    if( pTypedef && pTypedef->pDecl->identifier[0] )
      return newSVpv( pTypedef->pDecl->identifier, 0 );
    else
      return NEW_SV_PV_CONST("<NULL>");
  }

  if( flags & T_ENUM ) {
    EnumSpecifier *pEnumSpec = (EnumSpecifier *) pTSpec->ptr;

    if( pEnumSpec ) {
      if( pEnumSpec->identifier[0] )
        return newSVpvf( "enum %s", pEnumSpec->identifier );
      else
        return GetEnumSpec( pEnumSpec );
    }
    else {
      return NEW_SV_PV_CONST("enum <NULL>");
    }
  }

  if( flags & (T_STRUCT|T_UNION) ) {
    Struct *pStruct = (Struct *) pTSpec->ptr;
    char *type = flags & T_UNION ? "union" : "struct";

    if( pStruct ) {
      if( pStruct->identifier[0] )
        return newSVpvf( "%s %s", type, pStruct->identifier );
      else
        return GetStructSpec( pStruct );
    }
    else {
      return newSVpvf( "%s <NULL>", type );
    }
  }

  {
    struct { u_32 flag; char *str; } *pSpec, spec[] = {
      {T_SIGNED,   "signed"  },
      {T_UNSIGNED, "unsigned"},
      {T_SHORT,    "short"   },
      {T_LONG,     "long"    },
      {T_VOID,     "void"    },
      {T_CHAR,     "char"    },
      {T_INT ,     "int"     },
      {T_FLOAT ,   "float"   },
      {T_DOUBLE ,  "double"  },
      {0,          NULL      }
    };
    SV *sv = NULL;
    pSpec = spec;

    while( pSpec->flag ) {
      if( pSpec->flag & flags ) {
        if( sv )
          sv_catpvf( sv, " %s", pSpec->str );
        else
          sv = newSVpv( pSpec->str, 0 );
      }
      pSpec++;
    }

    return sv ? sv : NEW_SV_PV_CONST("<NULL>");
  }
}

/*******************************************************************************
*
*   ROUTINE: GetTypedefSpec
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static SV *GetTypedefSpec( Typedef *pTypedef )
{
  Declarator *pDecl = pTypedef->pDecl;
  Value *pValue;

  HV *hv = newHV();
  SV *sv = newSVpvf( "%s%s", pDecl->pointer_flag ? "*" : "",
                             pDecl->identifier );

  LL_foreach( pValue, pDecl->array )
    sv_catpvf( sv, "[%d]", pValue->iv );

  HV_STORE_CONST( hv, "declarator", sv );
  HV_STORE_CONST( hv, "type", GetTypeSpec( &pTypedef->type ) );

  return newRV_noinc( (SV *) hv );
}

/*******************************************************************************
*
*   ROUTINE: GetEnumerators
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static SV *GetEnumerators( LinkedList enumerators )
{
  Enumerator *pEnum;
  HV *hv = newHV();

  LL_foreach( pEnum, enumerators )
    hv_store( hv, pEnum->identifier, strlen( pEnum->identifier ),
                  newSViv( pEnum->value.iv ), 0 );

  return newRV_noinc( (SV *) hv );
}

/*******************************************************************************
*
*   ROUTINE: GetEnumSpec
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static SV *GetEnumSpec( EnumSpecifier *pEnumSpec )
{
  HV *hv = newHV();
  
  if( pEnumSpec->identifier[0] ) {
    HV_STORE_CONST( hv, "identifier", newSVpv( pEnumSpec->identifier, 0 ) );
  }

  if( pEnumSpec->enumerators ) {
    HV_STORE_CONST( hv, "size", newSViv( pEnumSpec->size ) );
    HV_STORE_CONST( hv, "sign", newSViv( pEnumSpec->tflags & T_SIGNED ? 1 : 0 ) );
    HV_STORE_CONST( hv, "enumerators", GetEnumerators( pEnumSpec->enumerators ) );
  }

  return newRV_noinc( (SV *) hv );
}

/*******************************************************************************
*
*   ROUTINE: GetDeclarators
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static SV *GetDeclarators( LinkedList declarators )
{
  Declarator *pDecl;
  AV *av = newAV();

  LL_foreach( pDecl, declarators ) {
    HV *hv = newHV();
    Value *pValue;

    if( pDecl->bitfield_size >= 0 ) {
      HV_STORE_CONST( hv, "declarator", newSVpvf( "%s:%d",
                      pDecl->identifier[0] != '\0' ? pDecl->identifier : "",
                      pDecl->bitfield_size ) );
    }
    else {
      SV *sv = newSVpvf( "%s%s", pDecl->pointer_flag ? "*" : "",
                                 pDecl->identifier );

      LL_foreach( pValue, pDecl->array )
        sv_catpvf( sv, "[%d]", pValue->iv );

      HV_STORE_CONST( hv, "declarator", sv );
      HV_STORE_CONST( hv, "offset", newSViv( pDecl->offset ) );
      HV_STORE_CONST( hv, "size", newSViv( pDecl->size ) );
    }

    av_push( av, newRV_noinc( (SV *) hv ) );
  }

  return newRV_noinc( (SV *) av );
}

/*******************************************************************************
*
*   ROUTINE: GetStructDeclarations
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static SV *GetStructDeclarations( LinkedList declarations )
{
  StructDeclaration *pStructDecl;
  AV *av = newAV();

  LL_foreach( pStructDecl, declarations ) {
    HV *hv = newHV();

    HV_STORE_CONST( hv, "type", GetTypeSpec( &pStructDecl->type ) );
    HV_STORE_CONST( hv, "declarators",
                        GetDeclarators( pStructDecl->declarators ) );
    
    av_push( av, newRV_noinc( (SV *) hv ) );
  }

  return newRV_noinc( (SV *) av );
}

/*******************************************************************************
*
*   ROUTINE: GetStructSpec
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static SV *GetStructSpec( Struct *pStruct )
{
  HV *hv = newHV();
  SV *type;
  
  if( pStruct->identifier[0] ) {
    HV_STORE_CONST( hv, "identifier",
                  newSVpv( pStruct->identifier, 0 ) );
  }

  if( pStruct->tflags & T_UNION )
    type = NEW_SV_PV_CONST("union");
  else
    type = NEW_SV_PV_CONST("struct");

  HV_STORE_CONST( hv, "type", type );

  if( pStruct->declarations ) {
    HV_STORE_CONST( hv, "size", newSViv( pStruct->size ) );
    HV_STORE_CONST( hv, "align", newSViv( pStruct->align ) );
    HV_STORE_CONST( hv, "pack", newSViv( pStruct->pack ) );

    HV_STORE_CONST( hv, "declarations",
                        GetStructDeclarations( pStruct->declarations ) );
  }

  return newRV_noinc( (SV *) hv );
}

/*******************************************************************************
*
*   ROUTINE: GetStructMember
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static void GetStructMember( Struct *pStruct, int offset, SV *sv, int dotflag )
{
  StructDeclaration *pStructDecl;
  Declarator *pDecl = NULL;
  Value *pValue;
  int size, index;

  if( pStruct->declarations == NULL ) {
    WARN_UNDEF_STRUCT( pStruct );
    return;
  }

  LL_foreach( pStructDecl, pStruct->declarations ) {
    LL_foreach( pDecl, pStructDecl->declarators ) {
      if( pDecl->offset > offset ) {
        sv_catpvf( sv, "+%d", offset );
        return;
      }

      if( pDecl->offset <= offset && offset < pDecl->offset+pDecl->size )
        break;
    }
    if( pDecl )
      break;
  }

  if( pDecl == NULL ) {
    sv_catpvf( sv, "+%d", offset );
    return;
  }

  if( pDecl->identifier[0] != '\0' ) {
    if( dotflag )
      sv_catpv( sv, "." );

    sv_catpv( sv, pDecl->identifier );
  }

  offset -= pDecl->offset;
  size = pDecl->size;

  LL_foreach( pValue, pDecl->array ) {
    size /= pValue->iv;
    index = offset/size;
    sv_catpvf( sv, "[%d]", index );
    offset -= index*size;
  }

  pStruct = NULL;

  if( ! pDecl->pointer_flag ) {
    if( pStructDecl->type.tflags & T_TYPE ) {
      Typedef *pTypedef = (Typedef *) pStructDecl->type.ptr;
  
      while( ! pTypedef->pDecl->pointer_flag
            && pTypedef->type.tflags & T_TYPE )
        pTypedef = (Typedef *) pTypedef->type.ptr;
  
      if( ! pTypedef->pDecl->pointer_flag
         && pTypedef->type.tflags & (T_STRUCT|T_UNION) )
        pStruct = (Struct *) pTypedef->type.ptr;
    }
    else if( pStructDecl->type.tflags & (T_STRUCT|T_UNION) )
      pStruct = (Struct *) pStructDecl->type.ptr;
  }

  if( pStruct )
    GetStructMember( pStruct, offset, sv, 1 );
  else if( offset > 0 )
    sv_catpvf( sv, "+%d", offset );
}

/*******************************************************************************
*
*   ROUTINE: GetOffsetOf
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

#define TRUNC_ELEM                                         \
          do {                                             \
            if( strlen( elem ) > 20 ) {                    \
              elem[17] = elem[18] = elem[19] = '.';        \
              elem[20] = '\0';                             \
            }                                              \
          } while(0)

static SV *GetOffsetOf( Struct *pStruct, const char *member )
{
  const char        *c, *ixstr;
  char              *e, *elem;
  int                size, level;
  UV                 offset;
  Declarator        *pDecl;
  StructDeclaration *pStructDecl;
  char              *err, errbuf[100];

  enum {
    ST_MEMBER,
    ST_INDEX,
    ST_FINISH_INDEX,
    ST_SEARCH
  }                  state;

  New( 0, elem, strlen(member)+1, char );

  err    = NULL;
  c      = member;
  state  = ST_MEMBER;
  offset = 0;

  for(;;) {
    CT_DEBUG( MAIN, ("state = %d \"%s\"", state, c) );

    while( *c && isSPACE( *c ) ) c++;

    if( *c == '\0' )
      break;

    switch( state ) {
      case ST_MEMBER:
        if( !(isALPHA(*c) || *c == '_') ) {
          err = "Struct members must start with a character or an underscore";
          goto error;
        }

        e = elem;
        do *e++ = *c++; while( *c && (isALNUM(*c) || *c == '_') );
        *e = '\0';

        CT_DEBUG( MAIN, ("MEMBER: \"%s\"", elem) );

        pDecl = NULL;

        LL_foreach( pStructDecl, pStruct->declarations ) {
          LL_foreach( pDecl, pStructDecl->declarators ) {
            if( strEQ( pDecl->identifier, elem ) )
              break;
          }
          if( pDecl )
            break;
        }

        if( pDecl == NULL ) {
          TRUNC_ELEM;
          (void) sprintf( err = errbuf, "Cannot find struct member '%s'", elem );
          goto error;
        }

        offset += pDecl->offset;
        size    = pDecl->size;
        level   = 0;

        state = ST_SEARCH;
        break;

      case ST_INDEX:
        if( !isDIGIT( *c ) ) {
          err = "Array indices must be constant decimal values";
          goto error;
        }

        ixstr = c++;
        while( *c && isDIGIT(*c) ) c++;

        state = ST_FINISH_INDEX;
        break;

      case ST_FINISH_INDEX:
        if( *c++ != ']' ) {
          err = "Index operator not terminated correctly";
          goto error;
        }

        if( level >= LL_size( pDecl->array ) ) {
          TRUNC_ELEM;
          (void) sprintf( err = errbuf,
                          "Cannot use '%s' as a %d-dimensional array",
                          elem, level+1 );
          goto error;
        }
        else {
          int index, dim;

          index = atoi( ixstr );
          dim   = ((Value *) LL_get( pDecl->array, level ))->iv;

          CT_DEBUG( MAIN, ("INDEX: \"%d\"", index) );

          if( index >= dim ) {
            (void) sprintf( err = errbuf,
                            "Cannot use index %d into array of size %d",
                            index, dim );
            goto error;
          }

          size   /= dim;
          offset += index * size;
          level++;
        }

        state = ST_SEARCH;
        break;

      case ST_SEARCH:
        switch( *c ) {
          case '.':
            if( pDecl->pointer_flag ) {
              (void) strcpy( elem, c );
              TRUNC_ELEM;
              (void) sprintf( err = errbuf,
                              "Cannot access member '%s' of pointer type",
                              c );
              goto error;
            }
            else if( level < LL_size( pDecl->array ) ) {
              (void) strcpy( elem, c );
              TRUNC_ELEM;
              (void) sprintf( err = errbuf,
                              "Cannot access member '%s' of array type",
                              c );
              goto error;
            }
            else if( pStructDecl->type.tflags & T_TYPE ) {
              Typedef *pTypedef = (Typedef *) pStructDecl->type.ptr;
        
              while( ! pTypedef->pDecl->pointer_flag
                    && pTypedef->type.tflags & T_TYPE )
                pTypedef = (Typedef *) pTypedef->type.ptr;
          
              if( ! pTypedef->pDecl->pointer_flag
                 && pTypedef->type.tflags & (T_STRUCT|T_UNION) ) {
                pStruct = (Struct *) pTypedef->type.ptr;
              }
              else {
                (void) strcpy( elem, c );
                TRUNC_ELEM;
                (void) sprintf( err = errbuf,
                                "Cannot access member '%s' of non-compound type",
                                c );
                goto error;
              }
            }
            else if( pStructDecl->type.tflags & (T_STRUCT|T_UNION) ) {
              pStruct = (Struct *) pStructDecl->type.ptr;
            }
            else {
              (void) strcpy( elem, c );
              TRUNC_ELEM;
              (void) sprintf( err = errbuf,
                              "Cannot access member '%s' of non-compound type",
                              c );
              goto error;
            }
            state = ST_MEMBER;
            break;

          case '[':
            if( level == 0 && LL_size( pDecl->array ) == 0 ) {
              TRUNC_ELEM;
              (void) sprintf( err = errbuf,
                              "Cannot use '%s' as an array",
                              elem );
              goto error;
            }
            state = ST_INDEX;
            break;

          default:
            (void) sprintf( err = errbuf,
                            "Invalid character '%c' (0x%02X) in "
                            "struct member expression",
                            *c, (int) *c );
            goto error;
        }
        c++;
        break;
    }
  }

  if( state != ST_SEARCH ) {
    err = "Incomplete struct member expression";
    goto error;
  }

  error:
  Safefree( elem );

  if( err != NULL )
    croak( "%s", err );

  return newSVuv( offset );
}

#undef TRUNC_ELEM

/*******************************************************************************
*
*   ROUTINE: GetTypePointer
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static int GetTypePointer( CBC *THIS, const char *name, TypePointer *pTYP )
{
  const char *c = name;

  if( pTYP == NULL )
    return 0;

  while( *c && !isSPACE( *c ) ) c++;

  if( *c ) {
    while( *c && isSPACE( *c ) ) c++;

    if( ! *c )
      return 0;

    if( name[0] == 's' &&
        name[1] == 't' &&
        name[2] == 'r' &&
        name[3] == 'u' &&
        name[4] == 'c' &&
        name[5] == 't' &&
        isSPACE( name[6] ) )
    {
      pTYP->type = TYP_STRUCT;
      pTYP->spec.pStruct = HT_get( THIS->cpi.htStructs, c, 0, 0 );

      if( pTYP->spec.pStruct && (pTYP->spec.pStruct->tflags & T_STRUCT) )
        return 1;
      
      pTYP->spec.pStruct = NULL;
      return 0;
    }

    if( name[0] == 'u' &&
        name[1] == 'n' &&
        name[2] == 'i' &&
        name[3] == 'o' &&
        name[4] == 'n' &&
        isSPACE( name[5] ) )
    {
      pTYP->type = TYP_STRUCT;
      pTYP->spec.pStruct = HT_get( THIS->cpi.htStructs, c, 0, 0 );

      if( pTYP->spec.pStruct && (pTYP->spec.pStruct->tflags & T_UNION) )
        return 1;
      
      pTYP->spec.pStruct = NULL;
      return 0;
    }

    if( name[0] == 'e' &&
        name[1] == 'n' &&
        name[2] == 'u' &&
        name[3] == 'm' &&
        isSPACE( name[4] ) )
    {
      pTYP->type = TYP_ENUM;
      pTYP->spec.pEnum = HT_get( THIS->cpi.htEnums, c, 0, 0 );
      return pTYP->spec.pEnum != NULL;
    }

    return 0;
  }

  pTYP->spec.pTypedef = HT_get( THIS->cpi.htTypedefs, name, 0, 0 );

  if( pTYP->spec.pTypedef ) {
    pTYP->type = TYP_TYPEDEF;
    return 1;
  }

  pTYP->spec.pStruct = HT_get( THIS->cpi.htStructs, name, 0, 0 );

  if( pTYP->spec.pStruct ) {
    pTYP->type = TYP_STRUCT;
    return 1;
  }

  pTYP->spec.pEnum = HT_get( THIS->cpi.htEnums, name, 0, 0 );

  if( pTYP->spec.pEnum ) {
    pTYP->type = TYP_ENUM;
    return 1;
  }

  return 0;
}

/*******************************************************************************
*
*   ROUTINE: IsTypedefDefined
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static int IsTypedefDefined( Typedef *pTypedef )
{
  if( pTypedef->pDecl->pointer_flag )
    return 1;

  while( pTypedef->type.tflags & T_TYPE ) {
    pTypedef = (Typedef *) pTypedef->type.ptr;
    if( pTypedef->pDecl->pointer_flag )
      return 1;
  }

  if( pTypedef->type.tflags & (T_STRUCT|T_UNION) )
    return ((Struct*)pTypedef->type.ptr)->declarations != NULL;

  if( pTypedef->type.tflags & T_ENUM )
    return ((EnumSpecifier*)pTypedef->type.ptr)->enumerators != NULL;

  return 1;
}

/*******************************************************************************
*
*   ROUTINE: debug_*
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION: Debug output routines.
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

#ifdef CTYPE_DEBUGGING
static void debug_vprintf( char *f, va_list l )
{
  vfprintf( gs_DB_stream, f, l );
}

static void debug_printf( char *f, ... )
{
  va_list l;
  va_start( l, f );
  vfprintf( gs_DB_stream, f, l );
  va_end( l );
}

static void debug_printf_ctlib( char *f, ... )
{
  va_list l;
  va_start( l, f );
  debug_printf( "DBG: " );
  vfprintf( gs_DB_stream, f, l );
  debug_printf( "\n" );
  va_end( l );
}
#endif

/*******************************************************************************
*
*   ROUTINE: SetDebugOptions
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

#ifdef CTYPE_DEBUGGING
static void SetDebugOptions( char *dbopts )
{
  unsigned long memflags, hashflags, dbgflags;

  if( strEQ( dbopts, "all" ) ) {
    memflags = hashflags = dbgflags = 0xFFFFFFFF;
  }
  else {
    memflags = hashflags = dbgflags = 0;

    while( *dbopts ) {
      switch( *dbopts ) {
        case 'm': memflags  |= DB_MEMALLOC_TRACE;  break;
        case 'M': memflags  |= DB_MEMALLOC_TRACE
                            |  DB_MEMALLOC_ASSERT; break;

        case 'h': hashflags |= DB_HASH_MAIN;       break;

        case 'd': dbgflags  |= DB_CTYPE_MAIN;      break;
        case 'p': dbgflags  |= DB_CTYPE_PARSER;    break;
        case 'l': dbgflags  |= DB_CTYPE_CLEXER;    break;
        case 'y': dbgflags  |= DB_CTYPE_YACC;      break;
        case 'r': dbgflags  |= DB_CTYPE_PRAGMA;    break;
        case 'c': dbgflags  |= DB_CTYPE_CTLIB;     break;
        case 'H': dbgflags  |= DB_CTYPE_HASH;      break;
        case 't': dbgflags  |= DB_CTYPE_TYPE;      break;

        default:
          croak( "Unknown debug option '%c'", *dbopts );
          break;
      }
      dbopts++;
    }
  }

  if( ! SetDebugMemAlloc( debug_printf, memflags ) )
    fatal( "Cannot enable memory debugging" );

  if( ! SetDebugHash( debug_printf, hashflags ) )
    fatal( "Cannot enable hash debugging" );

  if( ! SetDebugCType( debug_printf_ctlib, debug_vprintf, dbgflags ) )
    fatal( "Cannot enable debugging" );
}
#endif

/*******************************************************************************
*
*   ROUTINE: SetDebugFile
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

#ifdef CTYPE_DEBUGGING
static void SetDebugFile( char *dbfile )
{
  if( gs_DB_stream != stderr && gs_DB_stream != NULL ) {
    fclose( gs_DB_stream );
    gs_DB_stream = NULL;
  }

  gs_DB_stream = dbfile ? fopen( dbfile, "w" ) : stderr;

  if( gs_DB_stream == NULL ) {
    WARN(( "Cannot open '%s', defaulting to stderr", dbfile ));
    gs_DB_stream = stderr;
  }
}
#endif

/*******************************************************************************
*
*   ROUTINE: CheckIntegerOption
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static int CheckIntegerOption( const IV *options, int count, SV *sv,
                               IV *value, const char *name )
{
  const IV *opt = options;
  int n = count;

  if( SvROK( sv ) ) {
    croak( "%s must be an integer value, not a reference", name );
    return 0;
  }

  *value = SvIV( sv );

  while( n-- )
    if( *value == *opt++ )
      return 1;

  if( name ) {
    SV *str = sv_2mortal( newSVpvn( "", 0 ) );

    for( n = 0; n < count; n++ )
      sv_catpvf( str, "%d%s", *options++, n <  count-2 ? ", " :
                                          n == count-2 ? " or " : "" );

    croak( "%s must be %s, not %d", name, SvPV_nolen( str ), *value );
  }

  return 0;
}

/*******************************************************************************
*
*   ROUTINE: GetStringOption
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

#define GET_STR_OPTION( name, value, sv )                                \
          GetStringOption( name ## Option, sizeof( name ## Option ) /    \
                           sizeof( StringOption ), value, sv, #name )

static const StringOption *GetStringOption( const StringOption *options, int count,
                                            int value, SV *sv, const char *name )
{
  char *string = NULL;

  if( sv ) {
    if( SvROK( sv ) )
      croak( "%s must be a string value, not a reference", name );
    else
      string = SvPV_nolen( sv );
  }

  if( string ) {
    const StringOption *opt = options;
    int n = count;

    while( n-- ) {
      if( strEQ( string, opt->string ) )
        return opt;
      opt++;
    }

    if( name ) {
      SV *str = sv_2mortal( newSVpvn( "", 0 ) );

      for( n = 0; n < count; n++ ) {
        sv_catpv( str, (options++)->string );
        if( n < count-2 )
          sv_catpv( str, "', '" );
        else if( n == count-2 )
          sv_catpv( str, "' or '" );
      }

      croak( "%s must be '%s', not '%s'", name, SvPV_nolen( str ), string );
    }
  }
  else {
    while( count-- ) {
      if( value == options->value )
        return options;
      options++;
    }

    fatal("Inconsistent data detected in GetStringOption()!");
  }

  return NULL;
}

/*******************************************************************************
*
*   ROUTINE: HandleStringList
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static void HandleStringList( char *option, LinkedList list, SV *sv, SV **rval )
{
  char *str;

  if( sv ) {
    LL_flush( list, (LLDestroyFunc) string_delete ); 

    if( SvROK( sv ) ) {
      sv = SvRV( sv );
      if( SvTYPE( sv ) == SVt_PVAV ) {
        AV *av = (AV *) sv;
        SV **pSV;
        int i, max = av_len( av );
  
        for( i=0; i<=max; ++i ) {
          if( (pSV = av_fetch( av, i, 0 )) != NULL )
            LL_push( list, string_new_fromSV( *pSV ) );
          else
            fatal( "NULL returned by av_fetch() in HandleStringList()" );
        }
      }
      else
        croak( "%s wants an array reference", option );
    }
    else
      croak( "%s wants a reference to an array of strings", option );
  }

  if( rval ) {
    AV *av = newAV();

    LL_foreach( str, list )
      av_push( av, newSVpv( str, 0 ) );

    *rval = newRV_noinc( (SV *) av );
  }
}

/*******************************************************************************
*
*   ROUTINE: HandleOption
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static const StringOption ByteOrderOption[] = {
  { BO_BIG_ENDIAN,    "BigEndian"    },
  { BO_LITTLE_ENDIAN, "LittleEndian" }
};

static const StringOption EnumTypeOption[] = {
  { ET_INTEGER, "Integer" },
  { ET_STRING,  "String"  },
  { ET_BOTH,    "Both"    }
};

static const StringOption HashSizeOption[] = {
  { -2, "Tiny"   },
  { -1, "Small"  },
  {  0, "Normal" },
  {  1, "Large"  },
  {  2, "Huge"   }
};

static const IV PointerSizeOption[] = { 0, 1, 2, 4    };
static const IV EnumSizeOption[]    = { 0, 1, 2, 4    };
static const IV IntSizeOption[]     = { 0, 1, 2, 4    };
static const IV ShortSizeOption[]   = { 0, 1, 2, 4    };
static const IV LongSizeOption[]    = { 0, 1, 2, 4    };
static const IV FloatSizeOption[]   = { 0, 1, 2, 4, 8 };
static const IV DoubleSizeOption[]  = { 0, 1, 2, 4, 8 };
static const IV AlignmentOption[]   = {    1, 2, 4, 8 };

#define START_OPTIONS                                                          \
          int changes = 0;                                                     \
          char *option = SvPV_nolen( opt );                                    \
          if( SvROK( opt ) ) {                                                 \
            croak( "Option name must be a string, not a reference" );          \
          }

#define END_OPTIONS                                                            \
          else {                                                               \
            croak( "Invalid option '%s'", option );                            \
          }                                                                    \
          return changes;

#define OPTION( name )                                                         \
          else if( strEQ( option, #name ) )

#define UPDATE( option, val )                                                  \
          if( (IV) THIS->option != val ) {                                     \
            THIS->option = val;                                                \
            changes = 1;                                                       \
          }

#define FLAG_OPTION( name, flag )                                              \
          else if( strEQ( option, #name ) ) {                                  \
            if( sv_val ) {                                                     \
              if( SvROK( sv_val ) )                                            \
                croak( #name " must be a boolean value, not a reference" );    \
              else if( (THIS->cfg.flags & flag) !=                             \
                       (SvIV(sv_val) ? flag : 0) ) {                           \
                THIS->cfg.flags ^= flag;                                       \
                changes = 1;                                                   \
              }                                                                \
            }                                                                  \
            if( rval )                                                         \
              *rval = newSViv( THIS->cfg.flags & flag ? 1 : 0 );               \
          }

#define IVAL_OPTION( name, config )                                            \
          else if( strEQ( option, #name ) ) {                                  \
            if( sv_val ) {                                                     \
              IV val;                                                          \
              if( CheckIntegerOption( name ## Option, sizeof( name ## Option ) \
                                    / sizeof( IV ), sv_val, &val, #name ) ) {  \
                UPDATE( cfg.config, val );                                     \
              }                                                                \
            }                                                                  \
            if( rval )                                                         \
              *rval = newSViv( THIS->cfg.config );                             \
          }

#define STRLIST_OPTION( name, config )                                         \
          else if( strEQ( option, #name ) ) {                                  \
            HandleStringList( #name, THIS->cfg.config, sv_val, rval );         \
            changes = sv_val != NULL;                                          \
          }

static int HandleOption( CBC *THIS, SV *opt, SV *sv_val, SV **rval )
{
  START_OPTIONS

  FLAG_OPTION( HasVOID,        HAS_VOID_KEYWORD   )
  FLAG_OPTION( UnsignedChars,  CHARS_ARE_UNSIGNED )
  FLAG_OPTION( Warnings,       ISSUE_WARNINGS     )

#ifdef ANSIC99_EXTENSIONS

  FLAG_OPTION( HasC99Keywords, HAS_C99_KEYWORDS )
  FLAG_OPTION( HasCPPComments, HAS_CPP_COMMENTS )
  FLAG_OPTION( HasMacroVAARGS, HAS_MACRO_VAARGS )

#endif

  STRLIST_OPTION( Include, includes   )
  STRLIST_OPTION( Define,  defines    )
  STRLIST_OPTION( Assert,  assertions )

  IVAL_OPTION( PointerSize, ptr_size    )
  IVAL_OPTION( EnumSize,    enum_size   )
  IVAL_OPTION( IntSize,     int_size    )
  IVAL_OPTION( ShortSize,   short_size  )
  IVAL_OPTION( LongSize,    long_size   )
  IVAL_OPTION( FloatSize,   float_size  )
  IVAL_OPTION( DoubleSize,  double_size )
  IVAL_OPTION( Alignment,   alignment   )

  OPTION( ByteOrder ) {
    if( sv_val ) {
      const StringOption *pOpt = GET_STR_OPTION( ByteOrder, 0, sv_val );
      UPDATE( byteOrder, pOpt->value );
    }
    if( rval ) {
      const StringOption *pOpt = GET_STR_OPTION( ByteOrder, THIS->byteOrder, NULL );
      *rval = newSVpv( pOpt->string, 0 );
    }
  }

  OPTION( EnumType ) {
    if( sv_val ) {
      const StringOption *pOpt = GET_STR_OPTION( EnumType, 0, sv_val );
      UPDATE( enumType, pOpt->value );
    }
    if( rval ) {
      const StringOption *pOpt = GET_STR_OPTION( EnumType, THIS->enumType, NULL );
      *rval = newSVpv( pOpt->string, 0 );
    }
  }

  OPTION( HashSize ) {
    if( sv_val ) {
      const StringOption *pOpt = GET_STR_OPTION( HashSize, 0, sv_val );

      if( THIS->cfg.htSizeEnums != DEFAULT_HT_SIZE_ENUMS + pOpt->value ) {
        THIS->cfg.htSizeEnumerators = DEFAULT_HT_SIZE_ENUMERATORS + pOpt->value;
        THIS->cfg.htSizeEnums       = DEFAULT_HT_SIZE_ENUMS       + pOpt->value;
        THIS->cfg.htSizeStructs     = DEFAULT_HT_SIZE_STRUCTS     + pOpt->value;
        THIS->cfg.htSizeTypedefs    = DEFAULT_HT_SIZE_TYPEDEFS    + pOpt->value;
        changes = 1;
      }
    }
    if( rval ) {
      const StringOption *pOpt = GET_STR_OPTION( HashSize, THIS->cfg.htSizeEnums
                                                 - DEFAULT_HT_SIZE_ENUMS, NULL );
      *rval = newSVpv( pOpt->string, 0 );
    }
  }

  END_OPTIONS
}

#undef START_OPTIONS
#undef END_OPTIONS
#undef OPTION
#undef UPDATE
#undef FLAG_OPTION
#undef IVAL_OPTION
#undef STRLIST_OPTION

/*******************************************************************************
*
*   ROUTINE: GetConfiguration
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

#define FLAG_OPTION( name, flag )                                              \
          sv = newSViv( THIS->cfg.flags & flag ? 1 : 0 );                      \
          HV_STORE_CONST( hv, #name, sv );

#define STRLIST_OPTION( name, config )                                         \
          HandleStringList( #name, THIS->cfg.config, NULL, &sv );              \
          HV_STORE_CONST( hv, #name, sv );

#define IVAL_OPTION( name, config )                                            \
          sv = newSViv( THIS->cfg.config );                                    \
          HV_STORE_CONST( hv, #name, sv );

#define STRING_OPTION( name, value )                                           \
          sv = newSVpv( GET_STR_OPTION( name, value, NULL )->string, 0 );      \
          HV_STORE_CONST( hv, #name, sv );

static SV *GetConfiguration( CBC *THIS )
{
  HV *hv = newHV();
  SV *sv;

  FLAG_OPTION( HasVOID,        HAS_VOID_KEYWORD   )
  FLAG_OPTION( UnsignedChars,  CHARS_ARE_UNSIGNED )
  FLAG_OPTION( Warnings,       ISSUE_WARNINGS     )

#ifdef ANSIC99_EXTENSIONS

  FLAG_OPTION( HasC99Keywords, HAS_C99_KEYWORDS )
  FLAG_OPTION( HasCPPComments, HAS_CPP_COMMENTS )
  FLAG_OPTION( HasMacroVAARGS, HAS_MACRO_VAARGS )

#endif

  STRLIST_OPTION( Include, includes   )
  STRLIST_OPTION( Define,  defines    )
  STRLIST_OPTION( Assert,  assertions )

  IVAL_OPTION( PointerSize, ptr_size    )
  IVAL_OPTION( EnumSize,    enum_size   )
  IVAL_OPTION( IntSize,     int_size    )
  IVAL_OPTION( ShortSize,   short_size  )
  IVAL_OPTION( LongSize,    long_size   )
  IVAL_OPTION( FloatSize,   float_size  )
  IVAL_OPTION( DoubleSize,  double_size )
  IVAL_OPTION( Alignment,   alignment   )

  STRING_OPTION( ByteOrder, THIS->byteOrder )
  STRING_OPTION( EnumType,  THIS->enumType  )
  STRING_OPTION( HashSize,  THIS->cfg.htSizeEnums - DEFAULT_HT_SIZE_ENUMS );

  return newRV_noinc( (SV *) hv );
}

#undef FLAG_OPTION
#undef STRLIST_OPTION
#undef IVAL_OPTION
#undef STRING_OPTION

/*******************************************************************************
*
*   ROUTINE: UpdateConfiguration
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
*   CHANGED BY:                                   ON:
*
********************************************************************************
*
* DESCRIPTION:
*
*   ARGUMENTS:
*
*     RETURNS:
*
*******************************************************************************/

static void UpdateConfiguration( CBC *THIS )
{
  if( THIS->cpi.structs ) {
    ResetParseInfo( &THIS->cpi );
    UpdateParseInfo( &THIS->cpi, &THIS->cfg );
  }
}


/*===== XS FUNCTIONS =========================================================*/

MODULE = Convert::Binary::C		PACKAGE = Convert::Binary::C		

PROTOTYPES: ENABLE

################################################################################
#
#   CONSTRUCTOR
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
#   CHANGED BY:                                   ON:
#
################################################################################
#
# DESCRIPTION:
#
#   ARGUMENTS:
#
#     RETURNS:
#
################################################################################

CBC *
CBC::new( ... )
	CODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::new", DBG_CTXT_ARG) );

		if( items % 2 == 0 )
		  croak( "Number of configuration arguments to new must be equal" );
		else {
		  int i;

		  Newz( 0, RETVAL, 1, CBC );

		  RETVAL->bufptr     = NULL;
		  RETVAL->buf.buffer = NULL;
		  RETVAL->buf.length = 0;
		  RETVAL->buf.pos    = 0;

		  RETVAL->cfg.includes          = LL_new();
		  RETVAL->cfg.defines           = LL_new();
		  RETVAL->cfg.assertions        = LL_new();
		  RETVAL->cfg.ptr_size          = DEFAULT_PTR_SIZE;
		  RETVAL->cfg.enum_size         = DEFAULT_ENUM_SIZE;
		  RETVAL->cfg.int_size          = DEFAULT_INT_SIZE;
		  RETVAL->cfg.short_size        = DEFAULT_SHORT_SIZE;
		  RETVAL->cfg.long_size         = DEFAULT_LONG_SIZE;
		  RETVAL->cfg.float_size        = DEFAULT_LONG_SIZE;
		  RETVAL->cfg.double_size       = DEFAULT_LONG_SIZE;
		  RETVAL->cfg.alignment         = DEFAULT_ALIGNMENT;
		  RETVAL->cfg.htSizeEnumerators = DEFAULT_HT_SIZE_ENUMERATORS;
		  RETVAL->cfg.htSizeEnums       = DEFAULT_HT_SIZE_ENUMS;
		  RETVAL->cfg.htSizeStructs     = DEFAULT_HT_SIZE_STRUCTS;
		  RETVAL->cfg.htSizeTypedefs    = DEFAULT_HT_SIZE_TYPEDEFS;
		  RETVAL->cfg.flags             = HAS_VOID_KEYWORD
#ifdef ANSIC99_EXTENSIONS
	                                        | HAS_C99_KEYWORDS
		                                | HAS_CPP_COMMENTS
		                                | HAS_MACRO_VAARGS
#endif
		                                ;
		  RETVAL->byteOrder             = DEFAULT_BYTEORDER;
		  RETVAL->enumType              = DEFAULT_ENUMTYPE;

		  InitParseInfo( &RETVAL->cpi );

		  for( i = 1; i < items; i += 2 )
		    (void) HandleOption( RETVAL, ST(i), ST(i+1), NULL );
		}

	OUTPUT:
		RETVAL

################################################################################
#
#   DESTRUCTOR
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
#   CHANGED BY:                                   ON:
#
################################################################################
#
# DESCRIPTION:
#
#   ARGUMENTS:
#
#     RETURNS:
#
################################################################################

void
CBC::DESTROY()
	CODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::DESTROY", DBG_CTXT_ARG) );

		FreeParseInfo( &THIS->cpi );
		LL_destroy( THIS->cfg.includes,   (LLDestroyFunc) string_delete );
		LL_destroy( THIS->cfg.defines,    (LLDestroyFunc) string_delete );
		LL_destroy( THIS->cfg.assertions, (LLDestroyFunc) string_delete );
		Safefree( THIS );

################################################################################
#
#   METHOD: configure
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
#   CHANGED BY:                                   ON:
#
################################################################################
#
# DESCRIPTION:
#
#   ARGUMENTS:
#
#     RETURNS:
#
################################################################################

SV *
CBC::configure( ... )
	CODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::configure", DBG_CTXT_ARG) );

		if( items <= 2 && GIMME_V == G_VOID ) {
		  WARN_VOID_CONTEXT( configure );
		  XSRETURN_EMPTY;
		}
		else if( items == 1 )
		  RETVAL = GetConfiguration( THIS );
                else if( items == 2 )
		  (void) HandleOption( THIS, ST(1), NULL, &RETVAL );
		else if( items % 2 ) {
		  int i, changes = 0;

		  for( i = 1; i < items; i += 2 )
		    if( HandleOption( THIS, ST(i), ST(i+1), NULL ) )
		      changes = 1;

		  if( changes )
		    UpdateConfiguration( THIS );

		  XSRETURN_EMPTY;
		}
		else
		  croak( "Invalid number of arguments to configure" );

	OUTPUT:
		RETVAL

################################################################################
#
#   MACRO: STRLIST_CONFIG
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
#   CHANGED BY:                                   ON:
#
################################################################################
#
# DESCRIPTION: Macro used for Include / Define / Assert methods
#
################################################################################

#define STRLIST_CONFIG( name, config )                                         \
        {                                                                      \
          int i, hasRval;                                                      \
          SV *rval, *inval;                                                    \
                                                                               \
          CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::" #name, DBG_CTXT_ARG) );   \
          hasRval = GIMME_V != G_VOID;                                         \
                                                                               \
          if( !hasRval && items <= 1 ) {                                       \
            WARN_VOID_CONTEXT( name );                                         \
            XSRETURN_EMPTY;                                                    \
          }                                                                    \
                                                                               \
          if( items > 1 && !SvROK( ST(1) ) ) {                                 \
            inval = NULL;                                                      \
                                                                               \
            for( i = 1; i < items; ++i ) {                                     \
              if( SvROK( ST(i) ) )                                             \
                croak( "Argument %d to " #name " must not be a reference", i );\
                                                                               \
              LL_push( THIS->cfg.config,                                       \
                       string_new_fromSV( ST(i) ) );                           \
            }                                                                  \
          }                                                                    \
          else {                                                               \
            if( items > 2 )                                                    \
              croak( "Invalid number of arguments to " #name );                \
                                                                               \
            inval = items == 2 ? ST(1) : NULL;                                 \
          }                                                                    \
                                                                               \
          if( inval || hasRval )                                               \
            HandleStringList( #name, THIS->cfg.config, inval,                  \
                                     hasRval ? &rval : NULL );                 \
                                                                               \
          if( !hasRval )                                                       \
            XSRETURN_EMPTY;                                                    \
                                                                               \
          XPUSHs( sv_2mortal( rval ) );                                        \
          XSRETURN( 1 );                                                       \
        }

################################################################################
#
#   METHOD: Include
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
#   CHANGED BY:                                   ON:
#
################################################################################

void
CBC::Include( ... )
	PPCODE:
		STRLIST_CONFIG( Include, includes )

################################################################################
#
#   METHOD: Define
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
#   CHANGED BY:                                   ON:
#
################################################################################

void
CBC::Define( ... )
	PPCODE:
		STRLIST_CONFIG( Define, defines )

################################################################################
#
#   METHOD: Assert
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
#   CHANGED BY:                                   ON:
#
################################################################################

void
CBC::Assert( ... )
	PPCODE:
		STRLIST_CONFIG( Assert, assertions )

################################################################################
#
#   METHOD: parse
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
#   CHANGED BY:                                   ON:
#
################################################################################
#
# DESCRIPTION:
#
#   ARGUMENTS:
#
#     RETURNS:
#
################################################################################

void
CBC::parse( code )
	char *code

	PREINIT:
		Buffer buf;
		int rval;

	CODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::parse", DBG_CTXT_ARG) );

		buf.buffer = code;
		buf.length = strlen( code );
		buf.pos    = 0;
#ifdef CBC_THREAD_SAFE
		MUTEX_LOCK( &gs_parse_mutex );
#endif
		rval = ParseBuffer( NULL, &buf, &THIS->cpi, &THIS->cfg );
#ifdef CBC_THREAD_SAFE
		MUTEX_UNLOCK( &gs_parse_mutex );
#endif
		if( rval == 0 )
		  croak( "%s", THIS->cpi.errstr );

		UpdateParseInfo( &THIS->cpi, &THIS->cfg );

################################################################################
#
#   METHOD: parse_file
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
#   CHANGED BY:                                   ON:
#
################################################################################
#
# DESCRIPTION:
#
#   ARGUMENTS:
#
#     RETURNS:
#
################################################################################

void
CBC::parse_file( file )
	char *file

	PREINIT:
		int rval;

	CODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::parse_file", DBG_CTXT_ARG) );
#ifdef CBC_THREAD_SAFE
		MUTEX_LOCK( &gs_parse_mutex );
#endif
		rval = ParseBuffer( file, NULL, &THIS->cpi, &THIS->cfg );
#ifdef CBC_THREAD_SAFE
		MUTEX_UNLOCK( &gs_parse_mutex );
#endif
		if( rval == 0 )
		  croak( "%s", THIS->cpi.errstr );

	        UpdateParseInfo( &THIS->cpi, &THIS->cfg );

################################################################################
#
#   METHOD: def
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
#   CHANGED BY:                                   ON:
#
################################################################################
#
# DESCRIPTION:
#
#   ARGUMENTS:
#
#     RETURNS:
#
################################################################################

int
CBC::def( type )
	char *type

	PREINIT:
		TypePointer tp;

	CODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::def( '%s' )", DBG_CTXT_ARG, type) );

		CHECK_PARSE_DATA( def );
		CHECK_VOID_CONTEXT( def );

		if( GetTypePointer( THIS, type, &tp ) == 0 )
		  XSRETURN_UNDEF;

		switch( tp.type ) {
		  case TYP_TYPEDEF:
		    RETVAL = IsTypedefDefined( tp.spec.pTypedef ) ? 1 : 0;
		    break;

		  case TYP_STRUCT:
		    RETVAL = tp.spec.pStruct->declarations ? 1 : 0;
		    break;

		  case TYP_ENUM:
		    RETVAL = tp.spec.pEnum->enumerators ? 1 : 0;
		    break;

		  default:
		    fatal("GetTypePointer returned an invalid type (%d) in "
                          XSCLASS "::def( '%s' )", tp.type, type);
		    break;
		}

	OUTPUT:
		RETVAL

################################################################################
#
#   METHOD: pack
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
#   CHANGED BY:                                   ON:
#
################################################################################
#
# DESCRIPTION:
#
#   ARGUMENTS:
#
#     RETURNS:
#
################################################################################

SV *
CBC::pack( type, data, string = NULL )
	char *type
	SV *data
	SV *string

	PREINIT:
		STRLEN size;
		char *buffer;
		TypePointer tp;
		u_32 flags = 0;

	CODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::pack( '%s' )",
		                 DBG_CTXT_ARG, type) );

		CHECK_PARSE_DATA( pack );

		if( string == NULL && GIMME_V == G_VOID ) {
		  WARN_VOID_CONTEXT( pack );
		  XSRETURN_EMPTY;
		}

		if( string != NULL && ! SvPOK( string ) )
		  croak( "Type of arg 3 to pack must be string" );

		if( GetTypePointer( THIS, type, &tp ) == 0 )
		  croak( "Cannot find '%s'", type );

		switch( tp.type ) {
		  case TYP_TYPEDEF:
		    {
		      ErrorGTI err;
		      err = GetTypeInfo( &THIS->cfg, &tp.spec.pTypedef->type,
                                         tp.spec.pTypedef->pDecl, &size, NULL,
		                         NULL, &flags );
		      if( err != GTI_NO_ERROR )
		        CroakGTI( err, type, 0 );
		    }
		    break;
		  case TYP_STRUCT:
		    if( tp.spec.pStruct->declarations == NULL )
		      CROAK_UNDEF_STRUCT( tp.spec.pStruct );
		    size = tp.spec.pStruct->size;
		    flags = tp.spec.pStruct->tflags & (T_HASBITFIELD | T_UNSAFE_VAL);
		    break;
		  case TYP_ENUM:
		    size = THIS->cfg.enum_size ? THIS->cfg.enum_size : tp.spec.pEnum->size;
		    break;
		  default:
		    fatal("GetTypePointer returned an invalid type (%d) in "
                          XSCLASS "::pack( '%s' ), line", tp.type, type, __LINE__);
		    break;
		}

		if( flags )
		  WARN_FLAGS( pack, type, flags );

		if( string == NULL ) {
		  RETVAL = newSV( size );
		  SvPOK_only( RETVAL );
		  SvCUR_set( RETVAL, size );
		  buffer = SvPVX( RETVAL );
		  Zero( buffer, size, char );
		}
		else {
		  STRLEN len = SvCUR( string );
		  STRLEN max = size > len ? size : len;

		  if( GIMME_V == G_VOID ) {
		    RETVAL = &PL_sv_undef;
		    buffer = SvGROW( string, size+1 );
		    SvCUR_set( string, max );
		  }
                  else {
		    RETVAL = newSV( max );
		    SvPOK_only( RETVAL );
		    buffer = SvPVX( RETVAL );
		    SvCUR_set( RETVAL, max );
		    Copy( SvPVX(string), buffer, len, char );
		  }

		  if( size > len )
		    Zero( buffer+len, size-len, char );
		}

		THIS->bufptr     =
		THIS->buf.buffer = buffer;
		THIS->buf.length = size;
		THIS->buf.pos    = 0;
		THIS->alignment  = THIS->cfg.alignment;

		switch( tp.type ) {
		  case TYP_TYPEDEF:
		    SetTypedef( THIS, tp.spec.pTypedef, data, type );
		    break;
		  case TYP_STRUCT:
		    SetStruct( THIS, tp.spec.pStruct, data );
		    break;
		  case TYP_ENUM:
		    SetEnum( THIS, tp.spec.pEnum, data );
		    break;
		  default:
		    fatal("GetTypePointer returned an invalid type (%d) in "
                          XSCLASS "::pack( '%s' ), line %d", tp.type, type, __LINE__);
		    break;
		}

	OUTPUT:
		RETVAL

################################################################################
#
#   METHOD: unpack
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
#   CHANGED BY:                                   ON:
#
################################################################################
#
# DESCRIPTION:
#
#   ARGUMENTS:
#
#     RETURNS:
#
################################################################################

SV *
CBC::unpack( type, string )
	char *type
	SV *string

	PREINIT:
		STRLEN len;
		TypePointer tp;
		u_32 flags = 0;

	CODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::unpack( '%s' )",
		                 DBG_CTXT_ARG, type) );

		CHECK_PARSE_DATA( unpack );
		CHECK_VOID_CONTEXT( unpack );

		if( !SvPOK( string ) )
		  croak( "Type of arg 2 to unpack must be string" );

		if( GetTypePointer( THIS, type, &tp ) == 0 )
		  croak( "Cannot find '%s'", type );

		switch( tp.type ) {
		  case TYP_TYPEDEF:
		    {
		      ErrorGTI err;
		      err = GetTypeInfo( &THIS->cfg, &tp.spec.pTypedef->type,
                                         tp.spec.pTypedef->pDecl, NULL, NULL,
		                         NULL, &flags );
		      if( err != GTI_NO_ERROR )
		        CroakGTI( err, type, 0 );
		    }
		    break;
		  case TYP_STRUCT:
		    if( tp.spec.pStruct->declarations == NULL )
		      CROAK_UNDEF_STRUCT( tp.spec.pStruct );
		    flags = tp.spec.pStruct->tflags & (T_HASBITFIELD | T_UNSAFE_VAL);
		    break;
		  case TYP_ENUM:
		    break;
		  default:
		    fatal("GetTypePointer returned an invalid type (%d) in "
                          XSCLASS "::pack( '%s' ), line", tp.type, type, __LINE__);
		    break;
		}

		if( flags )
		  WARN_FLAGS( unpack, type, flags );

                THIS->bufptr     =
		THIS->buf.buffer = SvPV( string, len );
		THIS->buf.pos    = 0;
		THIS->buf.length = len;

		THIS->alignment  = THIS->cfg.alignment;

		THIS->dataTooShortFlag = 0;

		switch( tp.type ) {
		  case TYP_TYPEDEF:
		    RETVAL = GetTypedef( THIS, tp.spec.pTypedef );
		    break;
		  case TYP_STRUCT:
		    RETVAL = GetStruct( THIS, tp.spec.pStruct );
		    break;
		  case TYP_ENUM:
		    RETVAL = GetEnum( THIS, tp.spec.pEnum );
		    break;
		  default:
		    fatal("GetTypePointer returned an invalid type (%d) in "
                          XSCLASS "::unpack( '%s' )", tp.type, type);
		    break;
		}

		if( THIS->dataTooShortFlag )
		  WARN(( "Data too short" ));

	OUTPUT:
		RETVAL

################################################################################
#
#   METHOD: sizeof
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
#   CHANGED BY:                                   ON:
#
################################################################################
#
# DESCRIPTION:
#
#   ARGUMENTS:
#
#     RETURNS:
#
################################################################################

SV *
CBC::sizeof( type )
	char *type

	PREINIT:
		unsigned size = 0;
		TypePointer tp;
		u_32 flags = 0;

	CODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::sizeof( '%s' )",
		                 DBG_CTXT_ARG, type) );

		CHECK_PARSE_DATA( sizeof );
		CHECK_VOID_CONTEXT( sizeof );

		if( GetTypePointer( THIS, type, &tp ) == 0 )
		  croak( "Cannot find '%s'", type );

		switch( tp.type ) {
		  case TYP_TYPEDEF:
		    {
		      ErrorGTI err;
		      err = GetTypeInfo( &THIS->cfg, &tp.spec.pTypedef->type,
                                         tp.spec.pTypedef->pDecl, &size, NULL,
		                         NULL, &flags );
		      if( err != GTI_NO_ERROR )
		        CroakGTI( err, type, 0 );
		    }
		    break;
		  case TYP_STRUCT:
		    if( tp.spec.pStruct->declarations == NULL )
		      CROAK_UNDEF_STRUCT( tp.spec.pStruct );
		    size = tp.spec.pStruct->size;
		    flags = tp.spec.pStruct->tflags & (T_HASBITFIELD | T_UNSAFE_VAL);
		    break;
		  case TYP_ENUM:
		    size = THIS->cfg.enum_size ? THIS->cfg.enum_size : tp.spec.pEnum->size;
		    break;
		  default:
		    fatal("GetTypePointer returned an invalid type (%d) in "
                          XSCLASS "::sizeof( '%s' )", tp.type, type);
		    break;
		}

		if( flags )
		  WARN_FLAGS( sizeof, type, flags );

		RETVAL = newSVuv( size );

	OUTPUT:
		RETVAL

################################################################################
#
#   METHOD: offsetof
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
#   CHANGED BY:                                   ON:
#
################################################################################
#
# DESCRIPTION:
#
#   ARGUMENTS:
#
#     RETURNS:
#
################################################################################

SV *
CBC::offsetof( type, member )
	char *type
	char *member

	PREINIT:
		TypePointer tp;
		Struct *pStruct = NULL;

	CODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::offsetof( '%s', '%s' )",
		                 DBG_CTXT_ARG, type, member) );

		CHECK_PARSE_DATA( offsetof );
		CHECK_VOID_CONTEXT( offsetof );

		if( GetTypePointer( THIS, type, &tp ) == 0 )
		  croak( "Cannot find '%s'", type );

		switch( tp.type ) {
		  case TYP_TYPEDEF:
		    {
		      Typedef *pTypedef = tp.spec.pTypedef;
		      ErrorGTI err;

		      err = GetTypeInfo( &THIS->cfg, &pTypedef->type,
                                         pTypedef->pDecl, NULL, NULL,
		                         NULL, NULL );

		      if( err != GTI_NO_ERROR )
		        CroakGTI( err, type, 0 );

		      while( ! pTypedef->pDecl->pointer_flag
		            && pTypedef->type.tflags & T_TYPE )
		        pTypedef = (Typedef *) pTypedef->type.ptr;

		      if( ! pTypedef->pDecl->pointer_flag
		         && pTypedef->type.tflags & (T_STRUCT|T_UNION) )
		        pStruct = (Struct *) pTypedef->type.ptr;
		      else {
		        if( pTypedef->pDecl->pointer_flag )
		          croak( "Cannot use offsetof on a pointer type" );
		        else if( pTypedef->type.tflags & T_ENUM )
		          croak( "Cannot use offsetof on an enum" );
		        else
		          croak( "Cannot use offsetof on a basic type" );
		      }
		    }
		    break;

		  case TYP_STRUCT:
		    pStruct = tp.spec.pStruct;
		    break;

		  case TYP_ENUM:
		    croak( "Cannot use offsetof on an enum" );
		    break;

		  default:
		    fatal("GetTypePointer returned an invalid type (%d) in "
                          XSCLASS "::offsetof( '%s', '%s' )", tp.type, type, member);
		    break;
		}

		if( pStruct->tflags & (T_HASBITFIELD | T_UNSAFE_VAL) )
		  WARN_FLAGS( offsetof, type, pStruct->tflags );

		if( pStruct->declarations == NULL )
		  CROAK_UNDEF_STRUCT( pStruct );

		RETVAL = GetOffsetOf( pStruct, member );

	OUTPUT:
		RETVAL

################################################################################
#
#   METHOD: member
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
#   CHANGED BY:                                   ON:
#
################################################################################
#
# DESCRIPTION:
#
#   ARGUMENTS:
#
#     RETURNS:
#
################################################################################

SV *
CBC::member( type, offset )
	char *type
	int offset

	PREINIT:
		TypePointer tp;
		Struct *pStruct = NULL;

	CODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::member( '%s', %d )",
		                 DBG_CTXT_ARG, type, offset) );

		CHECK_PARSE_DATA( member );
		CHECK_VOID_CONTEXT( member );

		if( GetTypePointer( THIS, type, &tp ) == 0 )
		  croak( "Cannot find '%s'", type );

		switch( tp.type ) {
		  case TYP_TYPEDEF:
		    {
		      Typedef *pTypedef = tp.spec.pTypedef;
		      ErrorGTI err;

		      err = GetTypeInfo( &THIS->cfg, &pTypedef->type,
                                         pTypedef->pDecl, NULL, NULL,
		                         NULL, NULL );

		      if( err != GTI_NO_ERROR )
		        CroakGTI( err, type, 0 );

		      while( ! pTypedef->pDecl->pointer_flag
		            && pTypedef->type.tflags & T_TYPE )
		        pTypedef = (Typedef *) pTypedef->type.ptr;
		      
		      if( ! pTypedef->pDecl->pointer_flag
		         && pTypedef->type.tflags & (T_STRUCT|T_UNION) )
		        pStruct = (Struct *) pTypedef->type.ptr;
		      else {
		        if( pTypedef->pDecl->pointer_flag )
		          croak( "Cannot use member on a pointer type" );
		        else if( pTypedef->type.tflags & T_ENUM )
		          croak( "Cannot use member on an enum" );
		        else
		          croak( "Cannot use member on a basic type" );
		      }
		    }
		    break;

		  case TYP_STRUCT:
		    pStruct = tp.spec.pStruct;
		    break;

		  case TYP_ENUM:
		    croak( "Cannot use member on an enum" );
		    break;

		  default:
		    fatal("GetTypePointer returned an invalid type (%d) in "
                          XSCLASS "::member( '%s', '%d' )", tp.type, type, offset);
		    break;
		}

		if( pStruct->tflags & (T_HASBITFIELD | T_UNSAFE_VAL) )
		  WARN_FLAGS( member, type, pStruct->tflags );

		if( pStruct->declarations == NULL )
		  CROAK_UNDEF_STRUCT( pStruct );

		if( offset < 0 || offset >= (int) pStruct->size )
		  croak( "Offset %d out of range (0 <= offset < %d)",
                         offset, pStruct->size );

		RETVAL = newSVpv( "", 0 );
		GetStructMember( pStruct, offset, RETVAL, 0 );

	OUTPUT:
		RETVAL

################################################################################
#
#   METHOD: enum_names
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
#   CHANGED BY:                                   ON:
#
################################################################################
#
# DESCRIPTION:
#
#   ARGUMENTS:
#
#     RETURNS:
#
################################################################################

void
CBC::enum_names()
	PREINIT:
		EnumSpecifier *pEnumSpec;
		int count = 0;
		U32 context;

	PPCODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::enum_names", DBG_CTXT_ARG) );

		CHECK_PARSE_DATA( enum_names );
		CHECK_VOID_CONTEXT( enum_names );

		context = GIMME_V;

		LL_foreach( pEnumSpec, THIS->cpi.enums ) {
		  if( pEnumSpec->identifier[0] && pEnumSpec->enumerators ) {
		    if( context == G_ARRAY )
		      XPUSHs( sv_2mortal( newSVpv( pEnumSpec->identifier, 0 ) ) );
		    ++count;
		  }
		}

		if( context == G_ARRAY )
		  XSRETURN( count );
		else
		  XSRETURN_IV( count );

################################################################################
#
#   METHOD: enum
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
#   CHANGED BY:                                   ON:
#
################################################################################
#
# DESCRIPTION:
#
#   ARGUMENTS:
#
#     RETURNS:
#
################################################################################

void
CBC::enum( ... )
	PREINIT:
		EnumSpecifier *pEnumSpec;
		U32 context;

	PPCODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::enum", DBG_CTXT_ARG) );

		CHECK_PARSE_DATA( enum );
		CHECK_VOID_CONTEXT( enum );

		context = GIMME_V;

		if( context == G_SCALAR && items != 2 )
		  XSRETURN_IV( items > 1 ? items-1 : LL_size( THIS->cpi.enums ) );

		if( items > 1 ) {
		  int i;

		  for( i = 1; i < items; ++i ) {
		    char *name = SvPV_nolen( ST(i) );

		    pEnumSpec = HT_get( THIS->cpi.htEnums, name, 0, 0 );

		    if( pEnumSpec )
		      PUSHs( sv_2mortal( GetEnumSpec( pEnumSpec ) ) );
		    else {
		      WARN(( "Cannot find enum '%s'", name ));
		      PUSHs( &PL_sv_undef );
		    }
		  }

		  XSRETURN( items-1 );
		}
		else {
		  int size = LL_size( THIS->cpi.enums );

		  if( size <= 0 )
		    XSRETURN_EMPTY;

		  EXTEND( SP, size );

		  LL_foreach( pEnumSpec, THIS->cpi.enums )
		    PUSHs( sv_2mortal( GetEnumSpec( pEnumSpec ) ) );

		  XSRETURN( size );
		}

################################################################################
#
#   METHOD: compound_names / struct_names / union_names
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Aug 2002
#   CHANGED BY:                                   ON:
#
################################################################################
#
# DESCRIPTION:
#
#   ARGUMENTS:
#
#     RETURNS:
#
################################################################################

#define COMPOUND_NAMES_PREINIT                                                 \
          Struct *pStruct;                                                     \
          int count = 0;                                                       \
          U32 context

#define COMPOUND_NAMES_PPCODE( rout, mask )                                    \
        do {                                                                   \
          CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::" # rout, DBG_CTXT_ARG) );  \
                                                                               \
          CHECK_PARSE_DATA( rout );                                            \
          CHECK_VOID_CONTEXT( rout );                                          \
                                                                               \
          context = GIMME_V;                                                   \
                                                                               \
          LL_foreach( pStruct, THIS->cpi.structs )                             \
            if(    pStruct->identifier[0]                                      \
                && pStruct->declarations                                       \
                && (pStruct->tflags & (mask))                                  \
              ) {                                                              \
              if( context == G_ARRAY )                                         \
                XPUSHs( sv_2mortal( newSVpv( pStruct->identifier, 0 ) ) );     \
              count++;                                                         \
            }                                                                  \
                                                                               \
          if( context == G_ARRAY )                                             \
            XSRETURN( count );                                                 \
          else                                                                 \
            XSRETURN_IV( count );                                              \
        } while(0)

void
CBC::compound_names()
	PREINIT:
		COMPOUND_NAMES_PREINIT;

	PPCODE:
		COMPOUND_NAMES_PPCODE( compound_names, T_STRUCT | T_UNION );

void
CBC::struct_names()
	PREINIT:
		COMPOUND_NAMES_PREINIT;

	PPCODE:
		COMPOUND_NAMES_PPCODE( struct_names, T_STRUCT );

void
CBC::union_names()
	PREINIT:
		COMPOUND_NAMES_PREINIT;

	PPCODE:
		COMPOUND_NAMES_PPCODE( union_names, T_UNION );

#undef COMPOUND_NAMES_PREINIT
#undef COMPOUND_NAMES_PPCODE

################################################################################
#
#   METHOD: compound / struct / union
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Aug 2002
#   CHANGED BY:                                   ON:
#
################################################################################
#
# DESCRIPTION:
#
#   ARGUMENTS:
#
#     RETURNS:
#
################################################################################

#define COMPOUND_PREINIT                                                       \
          Struct *pStruct;                                                     \
          U32 context

#define COMPOUND_PPCODE( rout, mask )                                          \
        do {                                                                   \
          CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::" # rout, DBG_CTXT_ARG) );  \
                                                                               \
          CHECK_PARSE_DATA( rout );                                            \
          CHECK_VOID_CONTEXT( rout );                                          \
                                                                               \
          context = GIMME_V;                                                   \
                                                                               \
          if( context == G_SCALAR && items != 2 ) {                            \
            if( items > 1 )                                                    \
              XSRETURN_IV( items-1 );                                          \
            else if( mask == 0 )                                               \
              XSRETURN_IV( LL_size( THIS->cpi.structs ) );                     \
            else {                                                             \
              int count = 0;                                                   \
                                                                               \
              LL_foreach( pStruct, THIS->cpi.structs )                         \
                if( (mask) && (pStruct->tflags & (mask)) )                     \
                  count++;                                                     \
                                                                               \
              XSRETURN_IV( count );                                            \
            }                                                                  \
          }                                                                    \
                                                                               \
          if( items > 1 ) {                                                    \
            int i;                                                             \
                                                                               \
            for( i = 1; i < items; ++i ) {                                     \
              char *name = SvPV_nolen( ST(i) );                                \
                                                                               \
              pStruct = HT_get( THIS->cpi.htStructs, name, 0, 0 );             \
                                                                               \
              if( pStruct && (pStruct->tflags & (mask)) )                      \
                PUSHs( sv_2mortal( GetStructSpec( pStruct ) ) );               \
              else {                                                           \
                WARN(( "Cannot find " # rout " '%s'", name ));                 \
                PUSHs( &PL_sv_undef );                                         \
              }                                                                \
            }                                                                  \
                                                                               \
            XSRETURN( items-1 );                                               \
          }                                                                    \
          else {                                                               \
            int count = 0;                                                     \
                                                                               \
            LL_foreach( pStruct, THIS->cpi.structs )                           \
              if( (mask) && (pStruct->tflags & (mask)) ) {                     \
                XPUSHs( sv_2mortal( GetStructSpec( pStruct ) ) );              \
                count++;                                                       \
              }                                                                \
                                                                               \
            XSRETURN( count );                                                 \
          }                                                                    \
        } while(0)

void
CBC::compound( ... )
	PREINIT:
		COMPOUND_PREINIT;

	PPCODE:
		COMPOUND_PPCODE( compound, T_STRUCT | T_UNION );

void
CBC::struct( ... )
	PREINIT:
		COMPOUND_PREINIT;

	PPCODE:
		COMPOUND_PPCODE( struct, T_STRUCT );

void
CBC::union( ... )
	PREINIT:
		COMPOUND_PREINIT;

	PPCODE:
		COMPOUND_PPCODE( union, T_UNION );

#undef COMPOUND_PREINIT
#undef COMPOUND_PPCODE

################################################################################
#
#   METHOD: typedef_names
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
#   CHANGED BY:                                   ON:
#
################################################################################
#
# DESCRIPTION:
#
#   ARGUMENTS:
#
#     RETURNS:
#
################################################################################

void
CBC::typedef_names()
	PREINIT:
		Typedef *pTypedef;
		int count = 0;
		U32 context;

	PPCODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::typedef_names", DBG_CTXT_ARG) );

		CHECK_PARSE_DATA( typedef_names );
		CHECK_VOID_CONTEXT( typedef_names );

		context = GIMME_V;

		LL_foreach( pTypedef, THIS->cpi.typedefs )
		  if( IsTypedefDefined( pTypedef ) ) {
		    if( context == G_ARRAY )
		      XPUSHs( sv_2mortal( newSVpv( pTypedef->pDecl->identifier, 0 ) ) );
		    ++count;
		  }

		if( context == G_ARRAY )
		  XSRETURN( count );
		else
		  XSRETURN_IV( count );

################################################################################
#
#   METHOD: typedef
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2002
#   CHANGED BY:                                   ON:
#
################################################################################
#
# DESCRIPTION:
#
#   ARGUMENTS:
#
#     RETURNS:
#
################################################################################

void
CBC::typedef( ... )
	PREINIT:
		Typedef *pTypedef;
		U32 context;

	PPCODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::typedef", DBG_CTXT_ARG) );

		CHECK_PARSE_DATA( typedef );
		CHECK_VOID_CONTEXT( typedef );

		context = GIMME_V;

		if( context == G_SCALAR && items != 2 )
		  XSRETURN_IV( items > 1 ? items-1 : LL_size( THIS->cpi.typedefs ) );

		if( items > 1 ) {
		  int i;

		  for( i = 1; i < items; ++i ) {
		    char *name = SvPV_nolen( ST(i) );

		    pTypedef = HT_get( THIS->cpi.htTypedefs, name, 0, 0 );

		    if( pTypedef )
		      PUSHs( sv_2mortal( GetTypedefSpec( pTypedef ) ) );
		    else {
		      WARN(( "Cannot find typedef '%s'", name ));
		      PUSHs( &PL_sv_undef );
		    }
		  }

		  XSRETURN( items-1 );
		}
		else {
		  int size = LL_size( THIS->cpi.typedefs );

		  if( size <= 0 )
		    XSRETURN_EMPTY;

		  EXTEND( SP, size );

		  LL_foreach( pTypedef, THIS->cpi.typedefs )
		    PUSHs( sv_2mortal( GetTypedefSpec( pTypedef ) ) );

		  XSRETURN( size );
		}

################################################################################

#   FUNCTION: import
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
#   CHANGED BY:                                   ON:
#
################################################################################
#
# DESCRIPTION: Handle global features, currently only debugging support.
#
#   ARGUMENTS:
#
#     RETURNS:
#
################################################################################

#define WARN_NO_DEBUGGING  0x00000001

void
import( ... )
	PREINIT:
		int i;
		U32 wflags;

	CODE:
		wflags = 0;

		if( strNE( SvPV_nolen( ST(0) ), XSCLASS ) )
		  croak( "The first argument to import must be the module name" );
		else if( items % 2 == 0 )
		  croak( "You must pass an even number of module arguments" );
		else {
		  for( i = 1; i < items; i += 2 ) {
		    char *opt = SvPV_nolen( ST(i) );
		    char *arg = SvPV_nolen( ST(i+1) );

		    if( strEQ( opt, "debug" ) ) {
#ifdef CTYPE_DEBUGGING
		      SetDebugOptions( arg );
#else
		      wflags |= WARN_NO_DEBUGGING;
#endif
		    }
		    else if( strEQ( opt, "debugfile" ) ) {
#ifdef CTYPE_DEBUGGING
		      SetDebugFile( arg );
#else
		      wflags |= WARN_NO_DEBUGGING;
#endif
		    }
		    else
		      croak( "Invalid module option '%s'", opt );
		  }

		  if( wflags & WARN_NO_DEBUGGING )
		    warn( XSCLASS " not compiled with debugging support" );
		}

#undef WARN_NO_DEBUGGING

################################################################################
#
#   FUNCTION: feature
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
#   CHANGED BY:                                   ON:
#
################################################################################
#
# DESCRIPTION: Check if the module was compiled with a certain feature.
#
#   ARGUMENTS:
#
#     RETURNS:
#
################################################################################

int
feature( feat )
	char *feat

	CODE:
		if( strEQ( feat, "c99" ) )
#ifdef ANSIC99_EXTENSIONS
		  RETVAL = 1;
#else
		  RETVAL = 0;
#endif
		else if( strEQ( feat, "debug" ) )
#ifdef CTYPE_DEBUGGING
		  RETVAL = 1;
#else
		  RETVAL = 0;
#endif
		else if( strEQ( feat, "threads" ) )
#ifdef CBC_THREAD_SAFE
		  RETVAL = 1;
#else
		  RETVAL = 0;
#endif
		else
		  XSRETURN_UNDEF;

	OUTPUT:
		RETVAL

################################################################################
#
#   FUNCTION: __DUMP__
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
#   CHANGED BY:                                   ON:
#
################################################################################
#
# DESCRIPTION: Internal function used for reference count checks.
#
#   ARGUMENTS:
#
#     RETURNS:
#
################################################################################

SV *
__DUMP__( val )
	SV *val

	CODE:
		RETVAL = newSVpvn( "", 0 );
		DumpSV( RETVAL, 0, val );

	OUTPUT:
		RETVAL


################################################################################
#
#   BOOTCODE
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
#   CHANGED BY:                                   ON:
#
################################################################################

BOOT:
		{
		  PrintFunctions f;
		  f.newstr = ct_newstr;
		  f.scatf  = ct_scatf;
		  f.vscatf = ct_vscatf;
		  f.warn   = ct_warn;
		  f.error  = ct_warn;
		  f.fatal  = ct_fatal;
		  SetPrintFunctions( &f );
#ifdef CBC_THREAD_SAFE
		  MUTEX_INIT( &gs_parse_mutex );
#endif
#ifdef CTYPE_DEBUGGING
		  gs_DB_stream = stderr;
#endif
		}

