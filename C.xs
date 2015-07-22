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
* $Date: 2003/02/27 18:27:04 +0000 $
* $Revision: 53 $
* $Snapshot: /Convert-Binary-C/0.12 $
* $Source: /C.xs $
*
********************************************************************************
*
* Copyright (c) 2002-2003 Marcus Holland-Moritz. All rights reserved.
* This program is free software; you can redistribute it and/or modify
* it under the same terms as Perl itself.
*
********************************************************************************
*
*         "All you have to do is to decide what you are going to do
*          with the time that is given to you."     -- Gandalf
*
*******************************************************************************/


/*===== GLOBAL INCLUDES ======================================================*/

#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>


/*===== LOCAL INCLUDES =======================================================*/

#include "util/ccattr.h"
#include "util/memalloc.h"
#include "util/list.h"
#include "util/hash.h"
#include "arch.h"
#include "byteorder.h"
#include "ctdebug.h"
#include "ctparse.h"
#include "cpperr.h"
#include "fileinfo.h"
#include "parser.h"


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
#define DEFAULT_PTR_SIZE    CTLIB_POINTER_SIZE
#elif   DEFAULT_PTR_SIZE != 1 && \
        DEFAULT_PTR_SIZE != 2 && \
        DEFAULT_PTR_SIZE != 4 && \
        DEFAULT_PTR_SIZE != 8
#error "DEFAULT_PTR_SIZE is invalid!"
#endif

#ifndef DEFAULT_ENUM_SIZE
#define DEFAULT_ENUM_SIZE    sizeof( int )
#elif   DEFAULT_ENUM_SIZE != 0 && \
        DEFAULT_ENUM_SIZE != 1 && \
        DEFAULT_ENUM_SIZE != 2 && \
        DEFAULT_ENUM_SIZE != 4 && \
        DEFAULT_ENUM_SIZE != 8
#error "DEFAULT_ENUM_SIZE is invalid!"
#endif

#ifndef DEFAULT_INT_SIZE
#define DEFAULT_INT_SIZE    CTLIB_int_SIZE
#elif   DEFAULT_INT_SIZE != 1 && \
        DEFAULT_INT_SIZE != 2 && \
        DEFAULT_INT_SIZE != 4 && \
        DEFAULT_INT_SIZE != 8
#error "DEFAULT_INT_SIZE is invalid!"
#endif

#ifndef DEFAULT_SHORT_SIZE
#define DEFAULT_SHORT_SIZE    CTLIB_short_SIZE
#elif   DEFAULT_SHORT_SIZE != 1 && \
        DEFAULT_SHORT_SIZE != 2 && \
        DEFAULT_SHORT_SIZE != 4 && \
        DEFAULT_SHORT_SIZE != 8
#error "DEFAULT_SHORT_SIZE is invalid!"
#endif

#ifndef DEFAULT_LONG_SIZE
#define DEFAULT_LONG_SIZE    CTLIB_long_SIZE
#elif   DEFAULT_LONG_SIZE != 1 && \
        DEFAULT_LONG_SIZE != 2 && \
        DEFAULT_LONG_SIZE != 4 && \
        DEFAULT_LONG_SIZE != 8
#error "DEFAULT_LONG_SIZE is invalid!"
#endif

#ifndef DEFAULT_LONG_LONG_SIZE
#define DEFAULT_LONG_LONG_SIZE    CTLIB_long_long_SIZE
#elif   DEFAULT_LONG_LONG_SIZE != 1 && \
        DEFAULT_LONG_LONG_SIZE != 2 && \
        DEFAULT_LONG_LONG_SIZE != 4 && \
        DEFAULT_LONG_LONG_SIZE != 8
#error "DEFAULT_LONG_LONG_SIZE is invalid!"
#endif

#ifndef DEFAULT_FLOAT_SIZE
#define DEFAULT_FLOAT_SIZE    CTLIB_float_SIZE
#elif   DEFAULT_FLOAT_SIZE != 1  && \
        DEFAULT_FLOAT_SIZE != 2  && \
        DEFAULT_FLOAT_SIZE != 4  && \
        DEFAULT_FLOAT_SIZE != 8  && \
        DEFAULT_FLOAT_SIZE != 12 && \
        DEFAULT_FLOAT_SIZE != 16
#error "DEFAULT_FLOAT_SIZE is invalid!"
#endif

#ifndef DEFAULT_DOUBLE_SIZE
#define DEFAULT_DOUBLE_SIZE    CTLIB_double_SIZE
#elif   DEFAULT_DOUBLE_SIZE != 1  && \
        DEFAULT_DOUBLE_SIZE != 2  && \
        DEFAULT_DOUBLE_SIZE != 4  && \
        DEFAULT_DOUBLE_SIZE != 8  && \
        DEFAULT_DOUBLE_SIZE != 12 && \
        DEFAULT_DOUBLE_SIZE != 16
#error "DEFAULT_DOUBLE_SIZE is invalid!"
#endif

#ifndef DEFAULT_LONG_DOUBLE_SIZE
#define DEFAULT_LONG_DOUBLE_SIZE    CTLIB_long_double_SIZE
#elif   DEFAULT_LONG_DOUBLE_SIZE != 1  && \
        DEFAULT_LONG_DOUBLE_SIZE != 2  && \
        DEFAULT_LONG_DOUBLE_SIZE != 4  && \
        DEFAULT_LONG_DOUBLE_SIZE != 8  && \
        DEFAULT_LONG_DOUBLE_SIZE != 12 && \
        DEFAULT_LONG_DOUBLE_SIZE != 16
#error "DEFAULT_LONG_DOUBLE_SIZE is invalid!"
#endif

#ifndef DEFAULT_ALIGNMENT
#define DEFAULT_ALIGNMENT    1
#elif   DEFAULT_ALIGNMENT != 1  && \
        DEFAULT_ALIGNMENT != 2  && \
        DEFAULT_ALIGNMENT != 4  && \
        DEFAULT_ALIGNMENT != 8  && \
        DEFAULT_ALIGNMENT != 16
#error "DEFAULT_ALIGNMENT is invalid!"
#endif

#ifndef DEFAULT_ENUMTYPE
#define DEFAULT_ENUMTYPE    ET_INTEGER
#endif

#ifndef DEFAULT_BYTEORDER
#ifdef NATIVE_BIG_ENDIAN
#define DEFAULT_BYTEORDER   BO_BIG_ENDIAN
#else
#define DEFAULT_BYTEORDER   BO_LITTLE_ENDIAN
#endif
#endif

/*-----------------------------*/
/* some stuff for older perl's */
/*-----------------------------*/

/*   <HACK>   */

#if !( PERL_REVISION == 5 && PERL_VERSION >= 6 )

typedef double NV;

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

#ifdef IVdf
# define IVdf_cast
#else
# define IVdf "ld"
# define IVdf_cast (long)
#endif

#ifdef UVuf
# define UVuf_cast
#else
# define UVuf "lu"
# define UVuf_cast (unsigned long)
#endif

#ifdef NVff
# define NVff_cast
#else
# define NVff "lf"
# define NVff_cast (double)
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

/*-------------------------------------------*/
/* floats and doubles can only be accessed   */
/* in native format (at least at the moment) */
/*-------------------------------------------*/

#ifdef CAN_UNALIGNED_ACCESS

#define GET_FPVAL( type, dest, class, size )                                   \
          do {                                                                 \
            if( (size) == sizeof(type) )                                       \
              dest = *((type *)(class)->bufptr);                               \
            else {                                                             \
              WARN(("Cannot unpack non-native floating point values"));        \
              dest = 0.0;                                                      \
            }                                                                  \
          } while(0)

#define SET_FPVAL( type, src, class, size )                                    \
          do {                                                                 \
            if( (size) == sizeof(type) )                                       \
              *((type *)(class)->bufptr) = src;                                \
            else                                                               \
              WARN(("Cannot pack non-native floating point values"));          \
          } while(0)

#else

#define GET_FPVAL( type, dest, class, size )                                   \
          do {                                                                 \
            if( (size) == sizeof(type) ) {                                     \
              register void *p = (void *)(class)->bufptr;                      \
              if( ((unsigned long) p) % sizeof(type) ) {                       \
                type fpval;                                                    \
                Copy( p, &fpval, 1, type );                                    \
                dest = (NV) fpval;                                             \
              }                                                                \
              else                                                             \
                dest = (NV) *((type *) p);                                     \
            }                                                                  \
            else {                                                             \
              WARN(("Cannot unpack non-native floating point values"));        \
              dest = 0.0;                                                      \
            }                                                                  \
          } while(0)

#define SET_FPVAL( type, src, class, size )                                    \
          do {                                                                 \
            if( (size) == sizeof(type) ) {                                     \
              register void *p = (void *)(class)->bufptr;                      \
              if( ((unsigned long) p) % sizeof(type) ) {                       \
                type fpval = (type) src;                                       \
                Copy( &fpval, p, 1, type );                                    \
              }                                                                \
              else                                                             \
                *((type *) p) = (type) src;                                    \
            }                                                                  \
            else                                                               \
              WARN(("Cannot pack non-native floating point values"));          \
          } while(0)

#endif

/*--------------------------------*/
/* macros for buffer manipulation */
/*--------------------------------*/

#define ALIGN_BUFFER( pCTC, align )                                            \
          do {                                                                 \
            unsigned _align = (unsigned)(align) > (pCTC)->alignment            \
                            ? (pCTC)->alignment : (align);                     \
            if( (pCTC)->align_base % _align ) {                                \
              _align -= (pCTC)->align_base % _align;                           \
              (pCTC)->align_base += _align;                                    \
              (pCTC)->buf.pos    += _align;                                    \
              (pCTC)->bufptr     += _align;                                    \
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
            (class)->align_base += size;                                       \
            (class)->buf.pos    += size;                                       \
            (class)->bufptr     += size;                                       \
          } while(0)

/*--------------------------------------------------*/
/* macros to create SV's/HV's with constant strings */
/*--------------------------------------------------*/

#define NEW_SV_PV_CONST( str ) \
          newSVpvn( str, sizeof(str)/sizeof(char)-1 )

#define HV_STORE_CONST( hash, key, value )                                     \
        do {                                                                   \
          SV *_val = value;                                                    \
          if( hv_store( hash, key, sizeof(key)/sizeof(char)-1,                 \
                        _val, 0 ) == NULL )                                    \
            sv_dec( _val );                                                    \
        } while(0)

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

#define NO_PARSE_DATA (   THIS->cpi.enums         == NULL                      \
                       || THIS->cpi.structs       == NULL                      \
                       || THIS->cpi.typedef_lists == NULL                      \
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
	         (ptr)->tflags & T_UNION ? "union" : "struct",                 \
	         (ptr)->identifier )

#define WARN_UNDEF_STRUCT( ptr )                                               \
	  warn( "Got no definition for '%s %s'",                               \
	        (ptr)->tflags & T_UNION ? "union" : "struct",                  \
	        (ptr)->identifier )

/*------------------------------------------------*/
/* this is needed quite often for unnamed structs */
/*------------------------------------------------*/

#define FOLLOW_AND_CHECK_TSPTR( pTS )                                          \
        do {                                                                   \
          if( (pTS)->tflags & T_TYPE ) {                                       \
            Typedef *_pT = (Typedef *) (pTS)->ptr;                             \
            for(;;) {                                                          \
              /* TODO: check array and pointer flag */                         \
              if( _pT && _pT->pType->tflags & T_TYPE )                         \
                _pT = (Typedef *) _pT->pType->ptr;                             \
              else                                                             \
                break;                                                         \
            }                                                                  \
            (pTS) = _pT->pType;                                                \
          }                                                                    \
                                                                               \
          if( ((pTS)->tflags & (T_STRUCT | T_UNION)) == 0 )                    \
            fatal("Unnamed member was not struct or union (type=0x%08X) "      \
                  "in %s line %d", (pTS)->tflags, __FILE__, __LINE__);         \
                                                                               \
          if( (pTS)->ptr == NULL )                                             \
            fatal("Type pointer to struct/union was NULL in %s line %d",       \
                  __FILE__, __LINE__);                                         \
        } while(0)

/*-------------------------*/
/* get the size of an enum */
/*-------------------------*/

#define GET_ENUM_SIZE( pES ) \
          (THIS->cfg.enum_size > 0 ? THIS->cfg.enum_size \
                                 : (pES)->sizes[-THIS->cfg.enum_size]) 

/*----------------------------*/
/* checks if an SV is defined */
/*----------------------------*/

#define DEFINED( sv ) ( (sv) != NULL && (sv) != &PL_sv_undef )

/*---------------*/
/* other defines */
/*---------------*/

#define T_ALREADY_DUMPED  T_USER_FLAG_1

#define F_NEWLINE         0x00000001
#define F_KEYWORD         0x00000002
#define F_DONT_EXPAND     0x00000004

/*-----------------*/
/* debugging stuff */
/*-----------------*/

#ifdef CTYPE_DEBUGGING

#define DBG_CTXT_FMT "%s"

#define DBG_CTXT_ARG (GIMME_V == G_VOID   ? "0=" : \
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

typedef enum { GSMS_NONE, GSMS_PAD, GSMS_HIT_OFF, GSMS_HIT } GSMSRV;

typedef struct {
  StructDeclaration *pStructDecl;
  Declarator        *pDecl;
} GSMSInfo;

typedef struct {
  char         *bufptr;
  unsigned      alignment;
  unsigned      align_base;
  int           dataTooShortFlag;
  Buffer        buf;
  CParseConfig  cfg;
  CParseInfo    cpi;
  ArchSpecs     as;
  enum {
    ET_INTEGER, ET_STRING, ET_BOTH
  }             enumType;
} CBC;

typedef struct {
  const int   value;
  const char *string;
} StringOption;

typedef struct {
  TypeSpec    type;
  Declarator *pDecl;
  unsigned    level;
  unsigned    offset;
  unsigned    size;
  u_32        flags;
} MemberInfo;


/*===== STATIC FUNCTION PROTOTYPES ===========================================*/

#ifdef CTYPE_DEBUGGING
static void debug_vprintf( char *f, va_list *l );
static void debug_printf( char *f, ... );
static void debug_printf_ctlib( char *f, ... );
static void SetDebugOptions( char *dbopts );
static void SetDebugFile( char *dbfile );

static void DumpSV( SV *buf, int level, SV *sv );
#endif

static void fatal( char *f, ... ) __attribute__(( __noreturn__ ));
static void *ct_newstr( void );
static void ct_scatf( void *p, char *f, ... );
static void ct_vscatf( void *p, char *f, va_list *l );
static void ct_warn( void *p );
static void ct_fatal( void *p ) __attribute__(( __noreturn__ ));

static char *string_new( const char *str );
static char *string_new_fromSV( SV *sv );
static void string_delete( char *sv );

static void CroakGTI( ErrorGTI error, const char *name, int warnOnly );

static SV *GetPointer( CBC *THIS );
static SV *GetStruct( CBC *THIS, Struct *pStruct, HV *hash );
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

static void GetBasicTypeSpecString( SV **sv, u_32 flags );

static void AddIndent( SV *s, int level );

static void CheckDefineType( SV *str, TypeSpec *pTS );

static void AddTypeSpecStringRec( SV *str, SV *s, TypeSpec *pTS, int level, U32 *pFlags );
static void AddEnumSpecStringRec( SV *str, SV *s, EnumSpecifier *pES, int level, U32 *pFlags );
static void AddStructSpecStringRec( SV *str, SV *s, Struct *pStruct, int level, U32 *pFlags );

static void AddTypedefListDeclString( SV *str, TypedefList *pTDL );
static void AddTypedefListSpecString( SV *str, TypedefList *pTDL );
static void AddEnumSpecString( SV *str, EnumSpecifier *pES );
static void AddStructSpecString( SV *str, Struct *pStruct );

static SV *GetParsedDefinitionsString( CParseInfo *pCPI );

static SV *GetTypeSpec( TypeSpec *pTSpec );
static SV *GetTypedefSpec( Typedef *pTypedef );

static SV *GetEnumerators( LinkedList enumerators );
static SV *GetEnumSpec( EnumSpecifier *pEnumSpec );

static SV *GetDeclarators( LinkedList declarators );
static SV *GetStructDeclarations( LinkedList declarations );
static SV *GetStructSpec( Struct *pStruct );

static GSMSRV AppendStructMemberStringRec( StructDeclaration *pStructDecl, Declarator *pDecl,
                                           int offset, int realoffset, SV *sv, int dotflag,
                                           GSMSInfo *pInfo );
static GSMSRV GetStructMemberStringRec( Struct *pStruct, int offset, int realoffset,
                                        SV *sv, int dotflag, GSMSInfo *pInfo );
static void GetStructMemberString( Struct *pStruct, int offset, SV *sv, SV **pType );

static int SearchStructMember( Struct *pStruct, const char *elem,
                               StructDeclaration **ppSD, Declarator **ppD );
static void GetStructMember( Struct *pStruct, const char *member, MemberInfo *pMI );

static void *GetTypePointer( CBC *THIS, const char *name, const char **pEOS );
static int GetMemberInfo( CBC *THIS, const char *name, MemberInfo *pMI );
static int IsTypedefDefined( Typedef *pTypedef );

static int CheckIntegerOption( const IV *options, int count, SV *sv,
                               IV *value, const char *name );
static const StringOption *GetStringOption( const StringOption *options, int count,
                                            int value, SV *sv, const char *name );
static LinkedList CloneStringList( LinkedList list );
static void HandleStringList( const char *option, LinkedList list, SV *sv, SV **rval );
static void DisabledKeywords( LinkedList *current, SV *sv, SV **rval, u_32 *pKeywordMask );
static void KeywordMap( HashTable *current, SV *sv, SV **rval );
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

static int gs_DisableParser;

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

#ifdef CTYPE_DEBUGGING

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
  sv_catpvf( buf, "SV = %s @ %p (REFCNT = %d)\n", str, sv, SvREFCNT(sv) );

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

#endif

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

static void ct_vscatf( void *p, char *f, va_list *l )
{
  sv_vcatpvf( (SV*)p, f, l );
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
*   ROUTINE: string_new
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
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

static char *string_new( const char *str )
{
  char *cpy = NULL;

  if( str != NULL ) {
    int len = strlen( str ) + 1;
    New( 0, cpy, len, char );
    Copy( str, cpy, len, char );
  }

  return cpy;
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

static void CroakGTI( ErrorGTI error, const char *name, int warnOnly )
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
*   ROUTINE: StoreIntSV
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
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

static void StoreIntSV( CBC *THIS, unsigned size, unsigned sign, SV *sv )
{
  IntValue iv;

  iv.sign   = sign;

  if( SvPOK( sv ) )
    iv.string = SvPVX( sv );
  else {
    iv.string = NULL;

    if( sign ) {
      IV val = SvIV( sv );
      CT_DEBUG( MAIN, ("SvIV( sv ) = %" IVdf, IVdf_cast val) );
#ifdef NATIVE_64_BIT_INTEGER
      iv.value.s = val;
#else
      iv.value.s.h = 0;
      iv.value.s.l = val;
#endif
    }
    else {
      UV val = SvUV( sv );
      CT_DEBUG( MAIN, ("SvUV( sv ) = %" UVuf, UVuf_cast val) );
#ifdef NATIVE_64_BIT_INTEGER
      iv.value.u = val;
#else
      iv.value.u.h = 0;
      iv.value.u.l = val;
#endif
    }
  }

  store_integer( size, THIS->bufptr, &THIS->as, &iv );
}

/*******************************************************************************
*
*   ROUTINE: FetchIntSV
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
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

#ifdef NATIVE_64_BIT_INTEGER
#define __SIZE_LIMIT sizeof( IV )
#else
#define __SIZE_LIMIT sizeof( iv.value.u.l )
#endif

#ifdef newSVuv
#define __TO_UV( x ) newSVuv( (UV) (x) )
#else
#define __TO_UV( x ) newSViv( (IV) (x) )
#endif

static SV *FetchIntSV( CBC *THIS, unsigned size, unsigned sign )
{
  IntValue iv;
  char buffer[32];

  /*
   *  Whew, I guess that could be done better,
   *  but at least it's working...
   */

#ifdef newSVuv

  iv.string = size > __SIZE_LIMIT ? buffer : NULL;

#else  /* older perls don't have newSVuv */

  iv.string =   size  > __SIZE_LIMIT
            || (size == __SIZE_LIMIT && !sign)
            ? buffer : NULL;

#endif

  fetch_integer( size, sign, THIS->bufptr, &THIS->as, &iv );

  if( iv.string )
    return newSVpv( iv.string, 0 );

#ifdef NATIVE_64_BIT_INTEGER
  return sign ? newSViv( iv.value.s          ) : __TO_UV( iv.value.u   );
#else
  return sign ? newSViv( (i_32) iv.value.s.l ) : __TO_UV( iv.value.u.l );
#endif
}

#undef __SIZE_LIMIT
#undef __TO_UV

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
  unsigned size = THIS->cfg.ptr_size ? THIS->cfg.ptr_size : sizeof( void * );

  CT_DEBUG( MAIN, (XSCLASS "::SetPointer( THIS=%p, sv=%p )", THIS, sv) );

  ALIGN_BUFFER( THIS, size );

  if( DEFINED( sv ) && ! SvROK( sv ) )
    StoreIntSV( THIS, size, 0, sv );

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
  char              *bufptr;
  long               pos;
  unsigned           old_align, old_base;

  CT_DEBUG( MAIN, (XSCLASS "::SetStruct( THIS=%p, pStruct=%p, sv=%p )",
            THIS, pStruct, sv) );

  ALIGN_BUFFER( THIS, pStruct->align );

  bufptr           = THIS->bufptr;
  pos              = THIS->buf.pos;
  old_align        = THIS->alignment;
  old_base         = THIS->align_base;
  THIS->alignment  = pStruct->pack ? pStruct->pack : THIS->cfg.alignment;
  THIS->align_base = 0;

  if( DEFINED( sv ) ) {
    SV *hash;

    if( SvROK( sv ) && SvTYPE( hash = SvRV(sv) ) == SVt_PVHV ) {
      HV *h = (HV *) hash;

      LL_foreach( pStructDecl, pStruct->declarations ) {
        if( pStructDecl->declarators ) {
          LL_foreach( pDecl, pStructDecl->declarators ) {
            SV **e = hv_fetch( h, pDecl->identifier,
                               strlen(pDecl->identifier), 0 );

            SetType( THIS, &pStructDecl->type, pDecl, 0,
                     e ? *e : NULL, pDecl->identifier );
    
            if( pStruct->tflags & T_UNION ) {
              THIS->bufptr  = bufptr;
              THIS->buf.pos = pos;
              THIS->align_base = 0;
            }
          }
        }
        else {
          TypeSpec *pTS = &pStructDecl->type;

          FOLLOW_AND_CHECK_TSPTR( pTS );

          SetStruct( THIS, (Struct *) pTS->ptr, sv );

          if( pStruct->tflags & T_UNION ) {
            THIS->bufptr     = bufptr;
            THIS->buf.pos    = pos;
            THIS->align_base = 0;
          }
        }
      }
    }
  }
  
  THIS->alignment  = old_align;
  THIS->align_base = old_base + pStruct->size;
  THIS->bufptr     = bufptr   + pStruct->size;
  THIS->buf.pos    = pos      + pStruct->size;
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
  unsigned size = GET_ENUM_SIZE( pEnumSpec );
  IV value = 0;

  CT_DEBUG( MAIN, (XSCLASS "::SetEnum( THIS=%p, pEnumSpec=%p, sv=%p )",
            THIS, pEnumSpec, sv) );

  /* TODO: add some checks (range, perhaps even value) */

  ALIGN_BUFFER( THIS, size );
  
  if( DEFINED( sv ) && ! SvROK( sv ) ) {
    IntValue iv;

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
  
    CT_DEBUG( MAIN, ("value(sv) = %" IVdf, IVdf_cast value) );
  
    iv.string = NULL;
    iv.sign = value < 0;

#ifdef NATIVE_64_BIT_INTEGER
    iv.value.s = value;
#else
    iv.value.s.h = value < 0 ? -1 : 0;
    iv.value.s.l = value;
#endif
    store_integer( size, THIS->bufptr, &THIS->as, &iv );
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
  unsigned size;

  CT_DEBUG( MAIN, (XSCLASS "::SetBasicType( THIS=%p, flags=0x%08lX, sv=%p )",
            THIS, (unsigned long) flags, sv) );

  CT_DEBUG( MAIN, ("buffer.pos=%lu, buffer.length=%lu",
            THIS->buf.pos, THIS->buf.length) );

#define LOAD_SIZE( type ) \
        size = THIS->cfg.type ## _size ? THIS->cfg.type ## _size : CTLIB_ ## type ## _SIZE

  if( flags & T_VOID )  /* XXX: do we want void ? */
    size = 1;
  else if( flags & T_CHAR ) {
    size = 1;
    if( (flags & (T_SIGNED|T_UNSIGNED)) == 0 &&
        (THIS->cfg.flags & CHARS_ARE_UNSIGNED) )
      flags |= T_UNSIGNED;
  }
  else if( (flags & (T_LONG|T_DOUBLE)) == (T_LONG|T_DOUBLE) )
    LOAD_SIZE( long_double );
  else if( flags & T_LONGLONG ) LOAD_SIZE( long_long );
  else if( flags & T_FLOAT )    LOAD_SIZE( float );
  else if( flags & T_DOUBLE )   LOAD_SIZE( double );
  else if( flags & T_SHORT )    LOAD_SIZE( short );
  else if( flags & T_LONG )     LOAD_SIZE( long );
  else                          LOAD_SIZE( int );

#undef LOAD_SIZE

  ALIGN_BUFFER( THIS, size );

  if( DEFINED( sv ) && ! SvROK( sv ) ) {
    if( flags & (T_DOUBLE | T_FLOAT) ) {
      NV value = SvNV( sv );
  
      CT_DEBUG( MAIN, ("SvNV( sv ) = %" NVff, NVff_cast value) );
  
      if( flags & T_DOUBLE ) {
        if( (flags & T_LONG) == 0 )
          SET_FPVAL( double, value, THIS, size );
        else {
#ifdef HAVE_LONG_DOUBLE
          SET_FPVAL( long double, value, THIS, size );
#else
          WARN(("Cannot pack long doubles"));
#endif
        }
      }
      else /* T_FLOAT */
        SET_FPVAL( float, value, THIS, size );
    }
    else {
      StoreIntSV( THIS, size, (flags & T_UNSIGNED) == 0, sv );
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
  CT_DEBUG( MAIN, (XSCLASS "::SetTypedef( THIS=%p, pTypedef=%p, sv=%p, name='%s' )",
                   THIS, pTypedef, sv, name) );

  SetType( THIS, pTypedef->pType, pTypedef->pDecl, 0, sv, name );
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
  CT_DEBUG( MAIN, (XSCLASS "::SetType( THIS=%p, pTS=%p, pDecl=%p, "
            "dimension=%d, sv=%p, name='%s' )",
            THIS, pTS, pDecl, dimension, sv, name) );

  if( pDecl && dimension < LL_count( pDecl->array ) ) {
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

      dim = LL_count( pDecl->array );

      while( dim-- > dimension )
        size *= ((Value *) LL_get( pDecl->array, dim ))->iv;

      INC_BUFFER( THIS, size );
    }
  }
  else {
    if( pDecl && pDecl->pointer_flag ) {
      if( sv && SvROK( sv ) )
        WARN(( "'%s' should be a scalar value", name ));
      SetPointer( THIS, sv );
    }
    else if( pDecl && pDecl->bitfield_size >= 0 ) {
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

      CT_DEBUG( MAIN, ("SET '%s' @ %lu", pDecl ? pDecl->identifier : "", THIS->buf.pos ) );

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
  SV *sv;
  unsigned size = THIS->cfg.ptr_size ? THIS->cfg.ptr_size : sizeof( void * );

  CT_DEBUG( MAIN, (XSCLASS "::GetPointer( THIS=%p )", THIS) );

  ALIGN_BUFFER( THIS, size );
  CHECK_BUFFER( THIS, size );

  sv = FetchIntSV( THIS, size, 0 );

  INC_BUFFER( THIS, size );

  return sv;
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

static SV *GetStruct( CBC *THIS, Struct *pStruct, HV *hash )
{
  StructDeclaration *pStructDecl;
  Declarator        *pDecl;
  HV                *h;
  char              *bufptr;
  long               pos;
  unsigned           old_align, old_base;

  CT_DEBUG( MAIN, (XSCLASS "::GetStruct( THIS=%p, pStruct=%p, hash=%p )",
            THIS, pStruct, hash) );

  h = hash ? hash : newHV();

  ALIGN_BUFFER( THIS, pStruct->align );

  bufptr           = THIS->bufptr;
  pos              = THIS->buf.pos;
  old_align        = THIS->alignment;
  old_base         = THIS->align_base;
  THIS->alignment  = pStruct->pack ? pStruct->pack : THIS->cfg.alignment;
  THIS->align_base = 0;

  LL_foreach( pStructDecl, pStruct->declarations ) {
    if( pStructDecl->declarators ) {
      LL_foreach( pDecl, pStructDecl->declarators ) {
        U32 klen = strlen(pDecl->identifier);

        if( hv_exists( h, pDecl->identifier, klen ) ) {
          WARN(("Member '%s' used more than once in %s%s%s defined in %s(%d)",
                pDecl->identifier,
                pStruct->tflags & T_UNION ? "union" : "struct",
                pStruct->identifier[0] != '\0' ? " " : "",
                pStruct->identifier[0] != '\0' ? pStruct->identifier : "",
                pStruct->context.pFI->name, pStruct->context.line));
        }
        else {
          SV *value = GetType( THIS, &pStructDecl->type, pDecl, 0 );
          if( hv_store( h, pDecl->identifier, klen, value, 0 ) == NULL )
            sv_dec( value );
        }

        if( pStruct->tflags & T_UNION ) {
          THIS->bufptr     = bufptr;
          THIS->buf.pos    = pos;
          THIS->align_base = 0;
        }
      }
    }
    else {
      TypeSpec *pTS = &pStructDecl->type;

      FOLLOW_AND_CHECK_TSPTR( pTS );

      (void) GetStruct( THIS, (Struct *) pTS->ptr, h );

      if( pStruct->tflags & T_UNION ) {
        THIS->bufptr     = bufptr;
        THIS->buf.pos    = pos;
        THIS->align_base = 0;
      }
    }
  }

  THIS->alignment  = old_align;
  THIS->align_base = old_base + pStruct->size;
  THIS->bufptr     = bufptr   + pStruct->size;
  THIS->buf.pos    = pos      + pStruct->size;

  return hash ? NULL : newRV_noinc( (SV *) h );
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
  unsigned size = GET_ENUM_SIZE( pEnumSpec );
  IV value;
  SV *sv;

  CT_DEBUG( MAIN, (XSCLASS "::GetEnum( THIS=%p, pEnumSpec=%p )", THIS, pEnumSpec) );

  ALIGN_BUFFER( THIS, size );
  CHECK_BUFFER( THIS, size );

  if( pEnumSpec->tflags & T_SIGNED ) { /* TODO: handle signed/unsigned correctly */
    IntValue iv;
    iv.string = NULL;
    fetch_integer( size, 1, THIS->bufptr, &THIS->as, &iv );
#ifdef NATIVE_64_BIT_INTEGER
    value = iv.value.s;
#else
    value = (i_32) iv.value.s.l;
#endif
  }
  else {
    IntValue iv;
    iv.string = NULL;
    fetch_integer( size, 0, THIS->bufptr, &THIS->as, &iv );
#ifdef NATIVE_64_BIT_INTEGER
    value = iv.value.u;
#else
    value = iv.value.u.l;
#endif
  }

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
        sv_setpvf( sv, "<ENUM:%" IVdf ">", IVdf_cast value );
      SvIOK_on( sv );
      break;

    case ET_STRING:
      if( pEnum )
        sv = newSVpv( pEnum->identifier, 0 );
      else
        sv = newSVpvf( "<ENUM:%" IVdf ">", IVdf_cast value );
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
  unsigned size;
  SV *sv;

  CT_DEBUG( MAIN, (XSCLASS "::GetBasicType( THIS=%p, flags=0x%08lX )",
                   THIS, (unsigned long) flags) );

  CT_DEBUG( MAIN, ("buffer.pos=%lu, buffer.length=%lu",
                   THIS->buf.pos, THIS->buf.length) );

#define LOAD_SIZE( type ) \
        size = THIS->cfg.type ## _size ? THIS->cfg.type ## _size : CTLIB_ ## type ## _SIZE

  if( flags & T_VOID )  /* XXX: do we want void ? */
    size = 1;
  else if( flags & T_CHAR ) {
    size = 1;
    if( (flags & (T_SIGNED|T_UNSIGNED)) == 0 &&
        (THIS->cfg.flags & CHARS_ARE_UNSIGNED) )
      flags |= T_UNSIGNED;
  }
  else if( (flags & (T_LONG|T_DOUBLE)) == (T_LONG|T_DOUBLE) )
    LOAD_SIZE( long_double );
  else if( flags & T_LONGLONG ) LOAD_SIZE( long_long );
  else if( flags & T_FLOAT )    LOAD_SIZE( float );
  else if( flags & T_DOUBLE )   LOAD_SIZE( double );
  else if( flags & T_SHORT )    LOAD_SIZE( short );
  else if( flags & T_LONG )     LOAD_SIZE( long );
  else                          LOAD_SIZE( int );

#undef LOAD_SIZE

  ALIGN_BUFFER( THIS, size );
  CHECK_BUFFER( THIS, size );

  if( flags & (T_FLOAT | T_DOUBLE) ) {
    NV value;

    if( flags & T_DOUBLE ) {
      if( (flags & T_LONG) == 0 )
        GET_FPVAL( double, value, THIS, size );
      else {
#ifdef HAVE_LONG_DOUBLE
        GET_FPVAL( long double, value, THIS, size );
#else
        WARN(("Cannot unpack long doubles"));
        value = 0.0;
#endif
      }
    }
    else
      GET_FPVAL( float, value, THIS, size );

    sv = newSVnv( value );
  }
  else {
    sv = FetchIntSV( THIS, size, (flags & T_UNSIGNED) == 0 );
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
  CT_DEBUG( MAIN, (XSCLASS "::GetTypedef( THIS=%p, pTypedef=%p )",
            THIS, pTypedef) );

  return GetType( THIS, pTypedef->pType, pTypedef->pDecl, 0 );
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
  CT_DEBUG( MAIN, (XSCLASS "::GetType( THIS=%p, pTS=%p, pDecl=%p, dimension=%d )",
                   THIS, pTS, pDecl, dimension) );

  if( pDecl && dimension < LL_count( pDecl->array ) ) {
    AV *a = newAV();
    long i, s = ((Value *) LL_get( pDecl->array, dimension ))->iv;

    av_extend( a, s-1 );

    for( i=0; i<s; ++i )
      av_store( a, i, GetType( THIS, pTS, pDecl, dimension+1 ) );

    return newRV_noinc( (SV *) a );
  }
  else {
    if( pDecl && pDecl->pointer_flag )       return GetPointer( THIS );
    if( pDecl && pDecl->bitfield_size >= 0 ) return &PL_sv_undef;  /* unsupported */
    if( pTS->tflags & T_TYPE )               return GetTypedef( THIS, pTS->ptr );
    if( pTS->tflags & (T_STRUCT|T_UNION) ) {
      Struct *pStruct = pTS->ptr;
      if( pStruct->declarations == NULL ) {
        WARN_UNDEF_STRUCT( pStruct );
        return &PL_sv_undef;
      }
      return GetStruct( THIS, pTS->ptr, NULL );
    }

    CT_DEBUG( MAIN, ("GET '%s' @ %lu", pDecl ? pDecl->identifier : "", THIS->buf.pos ) );

    if( pTS->tflags & T_ENUM )             return GetEnum( THIS, pTS->ptr );

    return GetBasicType( THIS, pTS->tflags );
  }
}

/*******************************************************************************
*
*   ROUTINE: GetBasicTypeSpecString
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Sep 2002
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

static void GetBasicTypeSpecString( SV **sv, u_32 flags )
{
  struct { u_32 flag; char *str; } *pSpec, spec[] = {
    {T_SIGNED,   "signed"  },
    {T_UNSIGNED, "unsigned"},
    {T_SHORT,    "short"   },
    {T_LONGLONG, "long"    },
    {T_LONG,     "long"    },
    {T_VOID,     "void"    },
    {T_CHAR,     "char"    },
    {T_INT ,     "int"     },
    {T_FLOAT ,   "float"   },
    {T_DOUBLE ,  "double"  },
    {0,          NULL      }
  };
  int first = 1;

  CT_DEBUG( MAIN, (XSCLASS "::GetBasicTypeSpecString( sv=%p, flags=0x%08lX )",
                   sv, (unsigned long) flags) );

  for( pSpec = spec; pSpec->flag; ++pSpec ) {
    if( pSpec->flag & flags ) {
      if( *sv )
        sv_catpvf( *sv, first ? "%s" : " %s", pSpec->str );
      else
        *sv = newSVpv( pSpec->str, 0 );

      first = 0;
    }
  }
}

#define INDENT                     \
        do {                       \
          if( level > 0 )          \
            AddIndent( s, level ); \
        } while(0)

/*******************************************************************************
*
*   ROUTINE: AddIndent
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
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

static void AddIndent( SV *s, int level )
{
#define MAXINDENT 16
  static const char tab[MAXINDENT] = "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t";

#ifndef CBC_DONT_CLAMP_TO_MAXINDENT
  if( level > MAXINDENT )
    level = MAXINDENT;
#else
  while( level > MAXINDENT ) {
    sv_catpvn( s, tab, MAXINDENT );
    level -= MAXINDENT;
  }
#endif

  sv_catpvn( s, tab, level );
#undef MAXINDENT
}

/*******************************************************************************
*
*   ROUTINE: CheckDefineType
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
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

static void CheckDefineType( SV *str, TypeSpec *pTS )
{
  u_32 flags = pTS->tflags;

  CT_DEBUG( MAIN, (XSCLASS "::CheckDefineType( pTS=(tflags=0x%08lX, ptr=%p) )",
                   (unsigned long) pTS->tflags, pTS->ptr) );

  if( flags & T_TYPE ) {
    Typedef *pTypedef= (Typedef *) pTS->ptr;

    while( ! pTypedef->pDecl->pointer_flag
          && pTypedef->pType->tflags & T_TYPE )
      pTypedef = (Typedef *) pTypedef->pType->ptr;

    if( pTypedef->pDecl->pointer_flag )
      return;

    pTS   = pTypedef->pType;
    flags = pTS->tflags;
  }

  if( flags & T_ENUM ) {
    EnumSpecifier *pES = (EnumSpecifier *) pTS->ptr;

    if( pES && (pES->tflags & T_ALREADY_DUMPED) == 0 )
      AddEnumSpecString( str, pES );
  }
  else if( flags & (T_STRUCT|T_UNION) ) {
    Struct *pStruct = (Struct *) pTS->ptr;

    if( pStruct && (pStruct->tflags & T_ALREADY_DUMPED) == 0 )
      AddStructSpecString( str, pStruct );
  }
}

/*******************************************************************************
*
*   ROUTINE: AddTypeSpecStringRec
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
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

#define CHECK_SET_KEYWORD                                  \
        do {                                               \
          if( pFlags && (*pFlags & F_KEYWORD) )            \
            sv_catpv( s, " " );                            \
          else                                             \
            INDENT;                                        \
          if( pFlags ) {                                   \
            *pFlags &= ~F_NEWLINE;                         \
            *pFlags |= F_KEYWORD;                          \
          }                                                \
        } while(0)

static void AddTypeSpecStringRec( SV *str, SV *s, TypeSpec *pTS, int level, U32 *pFlags )
{
  u_32 flags = pTS->tflags;

  CT_DEBUG( MAIN, (XSCLASS "::AddTypeSpecStringRec( pTS=(tflags=0x%08lX, ptr=%p),"
                           " level=%d, pFlags=%p (0x%08lX) )",
                   (unsigned long) pTS->tflags, pTS->ptr, level, pFlags,
                   (unsigned long) (pFlags ? *pFlags : 0)) );

  if( flags & T_TYPE ) {
    Typedef *pTypedef= (Typedef *) pTS->ptr;

    if( pTypedef && pTypedef->pDecl->identifier[0] ) {
      CHECK_SET_KEYWORD;
      sv_catpv( s, pTypedef->pDecl->identifier );
    }
  }
  else if( flags & T_ENUM ) {
    EnumSpecifier *pES = (EnumSpecifier *) pTS->ptr;

    if( pES ) {
      if( pES->identifier[0] && ((pES->tflags & T_ALREADY_DUMPED) ||
                                 (*pFlags & F_DONT_EXPAND)) ) {
        CHECK_SET_KEYWORD;
        sv_catpvf( s, "enum %s", pES->identifier );
      }
      else
        AddEnumSpecStringRec( str, s, pES, level, pFlags );
    }
  }
  else if( flags & (T_STRUCT|T_UNION) ) {
    Struct *pStruct = (Struct *) pTS->ptr;

    if( pStruct ) {
      if( pStruct->identifier[0] && ((pStruct->tflags & T_ALREADY_DUMPED) ||
                                     (*pFlags & F_DONT_EXPAND)) ) {
        CHECK_SET_KEYWORD;
        sv_catpvf( s, "%s %s", flags & T_UNION ? "union" : "struct", pStruct->identifier );
      }
      else
        AddStructSpecStringRec( str, s, pStruct, level, pFlags );
    }
  }
  else {
    CHECK_SET_KEYWORD;
    GetBasicTypeSpecString( &s, flags );
  }
}

#undef CHECK_SET_KEYWORD

/*******************************************************************************
*
*   ROUTINE: AddEnumSpecStringRec
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
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

static void AddEnumSpecStringRec( SV *str, SV *s, EnumSpecifier *pES, int level, U32 *pFlags )
{
  CT_DEBUG( MAIN, (XSCLASS "::AddEnumSpecStringRec( pES=(identifier=\"%s\"),"
                           " level=%d, pFlags=%p (0x%08lX) )",
                   pES->identifier, level, pFlags,
                   (unsigned long) (pFlags ? *pFlags : 0)) );

  pES->tflags |= T_ALREADY_DUMPED;

#ifndef CBC_NO_SOURCIFY_CONTEXT
  if( pFlags && (*pFlags & F_NEWLINE) == 0 ) {
    sv_catpv( s, "\n" );
    *pFlags &= ~F_KEYWORD;
    *pFlags |= F_NEWLINE;
  }
  sv_catpvf( s, "#line %lu \"%s\"\n", pES->context.line, pES->context.pFI->name );
#endif

  if( pFlags && (*pFlags & F_KEYWORD) )
    sv_catpv( s, " " );
  else
    INDENT;

  if( pFlags )
    *pFlags &= ~(F_NEWLINE|F_KEYWORD);

  sv_catpv( s, "enum" );
  if( pES->identifier[0] )
    sv_catpvf( s, " %s", pES->identifier );

  if( pES->enumerators ) {
    Enumerator *pEnum;
    int         first = 1;
    Value       lastVal;

    sv_catpv( s, "\n" );
    INDENT;
    sv_catpv( s, "{" );

    LL_foreach( pEnum, pES->enumerators ) {
      if( !first )
        sv_catpv( s, "," );

      sv_catpv( s, "\n" );
      INDENT;

      if(   ( first && pEnum->value.iv == 0)
         || (!first && pEnum->value.iv == lastVal.iv + 1 )
        )
        sv_catpvf( s, "\t%s", pEnum->identifier );
      else
        sv_catpvf( s, "\t%s = %ld", pEnum->identifier, pEnum->value.iv );

      if( first )
        first = 0;

      lastVal = pEnum->value;
    }

    sv_catpv( s, "\n" );
    INDENT;
    sv_catpv( s, "}" );
  }
}

/*******************************************************************************
*
*   ROUTINE: AddStructSpecStringRec
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
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

static void AddStructSpecStringRec( SV *str, SV *s, Struct *pStruct, int level, U32 *pFlags )
{
  CT_DEBUG( MAIN, (XSCLASS "::AddStructSpecStringRec( pStruct=(identifier=\"%s\", "
                           "pack=%d, tflags=0x%08lX), level=%d, pFlags=%p (0x%08lX) )",
                   pStruct->identifier, pStruct->pack, (unsigned long) pStruct->tflags,
                   level, pFlags, (unsigned long) (pFlags ? *pFlags : 0)) );

  pStruct->tflags |= T_ALREADY_DUMPED;

  if( pStruct->declarations && pStruct->pack ) {
    if( pFlags && (*pFlags & F_NEWLINE) == 0 ) {
      sv_catpv( s, "\n" );
      *pFlags &= ~F_KEYWORD;
      *pFlags |= F_NEWLINE;
    }
    sv_catpvf( s, "#pragma pack( push, %u )\n", pStruct->pack );
  }

#ifndef CBC_NO_SOURCIFY_CONTEXT
  if( pFlags && (*pFlags & F_NEWLINE) == 0 ) {
    sv_catpv( s, "\n" );
    *pFlags &= ~F_KEYWORD;
    *pFlags |= F_NEWLINE;
  }
  sv_catpvf( s, "#line %lu \"%s\"\n", pStruct->context.line, pStruct->context.pFI->name );
#endif

  if( pFlags && (*pFlags & F_KEYWORD) )
    sv_catpv( s, " " );
  else
    INDENT;

  if( pFlags )
    *pFlags &= ~(F_NEWLINE|F_KEYWORD);

  sv_catpv( s, pStruct->tflags & T_STRUCT ? "struct" : "union" );

  if( pStruct->identifier[0] )
    sv_catpvf( s, " %s", pStruct->identifier );

  if( pStruct->declarations ) {
    StructDeclaration *pStructDecl;

    sv_catpv( s, "\n" );
    INDENT;
    sv_catpv( s, "{\n" );

    LL_foreach( pStructDecl, pStruct->declarations ) {
      Declarator *pDecl;
      int first = 1, need_def = 0;
      U32 flags = F_NEWLINE;

      LL_foreach( pDecl, pStructDecl->declarators )
        if( pDecl->pointer_flag == 0 ) {
          need_def = 1;
	  break;
	}

      if( !need_def )
        flags |= F_DONT_EXPAND;

      AddTypeSpecStringRec( str, s, &pStructDecl->type, level+1, &flags );

      flags &= ~F_DONT_EXPAND;

      if( flags & F_NEWLINE )
        AddIndent( s, level+1 );
      else if( pStructDecl->declarators )
        sv_catpv( s, " " );

      LL_foreach( pDecl, pStructDecl->declarators ) {
        Value *pValue;

        if( first )
          first = 0;
        else
          sv_catpv( s, ", " );

        if( pDecl->bitfield_size >= 0 ) {
          sv_catpvf( s, "%s:%d", pDecl->identifier[0] != '\0' ? pDecl->identifier : "",
                                 pDecl->bitfield_size );
        }
        else {
          sv_catpvf( s, "%s%s", pDecl->pointer_flag ? "*" : "",
                                pDecl->identifier );

          LL_foreach( pValue, pDecl->array )
            sv_catpvf( s, "[%ld]", pValue->iv );
        }
      }

      sv_catpv( s, ";\n" );

      if( need_def )
        CheckDefineType( str, &pStructDecl->type );
    }

    INDENT;
    sv_catpv( s, "}" );
  }

  if( pStruct->declarations && pStruct->pack ) {
    sv_catpv( s, "\n#pragma pack( pop )\n" );
    if( pFlags )
      *pFlags |= F_NEWLINE;
  }
}

/*******************************************************************************
*
*   ROUTINE: AddTypedefListDeclString
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
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

static void AddTypedefListDeclString( SV *str, TypedefList *pTDL )
{
  Typedef *pTypedef;
  int first = 1;

  CT_DEBUG( MAIN, (XSCLASS "::AddTypedefListDeclString( pTDL=%p )", pTDL) );

  LL_foreach( pTypedef, pTDL->typedefs ) {
    Declarator *pDecl = pTypedef->pDecl;
    Value *pValue;

    if( first )
      first = 0;
    else
      sv_catpv( str, ", " );

    sv_catpvf( str, "%s%s", pDecl->pointer_flag ? "*" : "", pDecl->identifier );

    LL_foreach( pValue, pDecl->array )
      sv_catpvf( str, "[%ld]", pValue->iv );
  }
}

/*******************************************************************************
*
*   ROUTINE: AddTypedefListSpecString
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
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

static void AddTypedefListSpecString( SV *str, TypedefList *pTDL )
{
  SV *s = newSVpv( "typedef", 0 );
  U32 flags = F_KEYWORD;

  CT_DEBUG( MAIN, (XSCLASS "::AddTypedefListSpecString( pTDL=%p )", pTDL) );

  AddTypeSpecStringRec( str, s, &pTDL->type, 0, &flags );

  if( (flags & F_NEWLINE) == 0 )
    sv_catpv( s, " " );

  AddTypedefListDeclString( s, pTDL );

  sv_catpv( s, ";\n" );
  sv_catsv( str, s );

  sv_dec( s );
}

/*******************************************************************************
*
*   ROUTINE: AddEnumSpecString
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
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

static void AddEnumSpecString( SV *str, EnumSpecifier *pES )
{
  SV *s = newSVpvn( "", 0 );

  CT_DEBUG( MAIN, (XSCLASS "::AddEnumSpecString( pES=%p )", pES) );

  AddEnumSpecStringRec( str, s, pES, 0, NULL );
  sv_catpv( s, ";\n" );
  sv_catsv( str, s );

  sv_dec( s );
}

/*******************************************************************************
*
*   ROUTINE: AddStructSpecString
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
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

static void AddStructSpecString( SV *str, Struct *pStruct )
{
  SV *s = newSVpvn( "", 0 );

  CT_DEBUG( MAIN, (XSCLASS "::AddStructSpecString( pStruct=%p )", pStruct) );

  AddStructSpecStringRec( str, s, pStruct, 0, NULL );
  sv_catpv( s, ";\n" );
  sv_catsv( str, s );

  sv_dec( s );
}

#undef INDENT

/*******************************************************************************
*
*   ROUTINE: GetParsedDefinitionsString
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
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

static SV *GetParsedDefinitionsString( CParseInfo *pCPI )
{
  TypedefList   *pTDL;
  EnumSpecifier *pES;
  Struct        *pStruct;
  int            fTypedefPre = 0, fTypedef = 0, fEnum = 0,
                 fStruct = 0, fUndefEnum = 0, fUndefStruct = 0;

  SV *s = newSVpvn( "", 0 );

  CT_DEBUG( MAIN, (XSCLASS "::GetParsedDefinitionsString( pCPI=%p )", pCPI) );

  /* typedef predeclarations */

  LL_foreach( pTDL, pCPI->typedef_lists ) {
    u_32 tflags = pTDL->type.tflags;
  
    if( (tflags & (T_ENUM|T_STRUCT|T_UNION|T_TYPE)) == 0 ) {
      if( !fTypedefPre ) {
        sv_catpv( s, "/* typedef predeclarations */\n\n" );
        fTypedefPre = 1;
      }
      AddTypedefListSpecString( s, pTDL );
    }
    else {
      char *what = NULL, *ident;
 
      if( tflags & T_ENUM ) {
        EnumSpecifier *pES = (EnumSpecifier *) pTDL->type.ptr;
        if( pES && pES->identifier[0] != '\0' ) {
          what  = "enum";
          ident = pES->identifier;
        }
      }
      else if( tflags & (T_STRUCT|T_UNION) ) {
        Struct *pStruct = (Struct *) pTDL->type.ptr;
        if( pStruct && pStruct->identifier[0] != '\0' ) {
          what  = pStruct->tflags & T_STRUCT ? "struct" : "union";
          ident = pStruct->identifier;
        }
      }

      if( what != NULL ) {
        if( !fTypedefPre ) {
          sv_catpv( s, "/* typedef predeclarations */\n\n" );
          fTypedefPre = 1;
        }
        sv_catpvf( s, "typedef %s %s ", what, ident );
        AddTypedefListDeclString( s, pTDL );
        sv_catpv( s, ";\n" );
      }
    }
  }

  /* typedefs */

  LL_foreach( pTDL, pCPI->typedef_lists )
    if( pTDL->type.ptr != NULL )
      if(   (   (pTDL->type.tflags & T_ENUM)
              && ((EnumSpecifier *) pTDL->type.ptr)->identifier[0] == '\0'
            )
         || (   (pTDL->type.tflags & (T_STRUCT|T_UNION))
              && ((Struct *) pTDL->type.ptr)->identifier[0] == '\0'
            )
         || (pTDL->type.tflags & T_TYPE)
        ) {
        if( !fTypedef ) {
          sv_catpv( s, "\n\n/* typedefs */\n\n" );
          fTypedef = 1;
        }
        AddTypedefListSpecString( s, pTDL );
        sv_catpv( s, "\n" );
      }
 
  /* defined enums */
 
  LL_foreach( pES, pCPI->enums )
    if(   pES->enumerators
       && (pES->tflags & (T_ALREADY_DUMPED)) == 0
      ) {
      if( !fEnum ) {
        sv_catpv( s, "\n/* defined enums */\n\n" );
        fEnum = 1;
      }
      AddEnumSpecString( s, pES );
      sv_catpv( s, "\n" );
    }
 
  /* defined structs and unions */
 
  LL_foreach( pStruct, pCPI->structs )
    if(   pStruct->declarations
       && pStruct->identifier[0]
       && (pStruct->tflags & (T_ALREADY_DUMPED)) == 0
      ) {
      if( !fStruct ) {
        sv_catpv( s, "\n/* defined structs and unions */\n\n" );
        fStruct = 1;
      }
      AddStructSpecString( s, pStruct );
      sv_catpv( s, "\n" );
    }
 
  /* undefined enums */
 
  LL_foreach( pES, pCPI->enums ) {
    if(    pES->enumerators   == NULL
       &&  pES->identifier[0] != '\0'
       && (pES->tflags & (T_HASTYPEDEF|T_ALREADY_DUMPED)) == 0
      ) {
      if( !fUndefEnum ) {
        sv_catpv( s, "\n/* undefined enums */\n\n" );
        fUndefEnum = 1;
      }
      sv_catpvf( s, "enum %s;\n\n", pES->identifier );
    }
 
    pES->tflags &= ~T_ALREADY_DUMPED;
  }
 
  /* undefined structs and unions */
 
  LL_foreach( pStruct, pCPI->structs ) {
    if( (pStruct->tflags & T_ALREADY_DUMPED) == 0 ) {
      if(   pStruct->declarations
         || (   pStruct->identifier[0] != '\0'
             && (pStruct->tflags & T_HASTYPEDEF) == 0
            )
        ) {
        if( !fUndefStruct ) {
          sv_catpv( s, "\n/* undefined/unnamed structs and unions */\n\n" );
          fUndefStruct = 1;
        }
        AddStructSpecString( s, pStruct );
        sv_catpv( s, "\n" );
      }
    }

    pStruct->tflags &= ~T_ALREADY_DUMPED;
  }

  return s;
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
    SV *sv = NULL;

    GetBasicTypeSpecString( &sv, flags );

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
    sv_catpvf( sv, "[%ld]", pValue->iv );

  HV_STORE_CONST( hv, "declarator", sv );
  HV_STORE_CONST( hv, "type", GetTypeSpec( pTypedef->pType ) );

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

  LL_foreach( pEnum, enumerators ) {
    SV *val = newSViv( pEnum->value.iv );
    if( hv_store( hv, pEnum->identifier, strlen( pEnum->identifier ),
                  val, 0 ) == NULL )
      sv_dec( val );
  }

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
    HV_STORE_CONST( hv, "sign", newSViv( pEnumSpec->tflags & T_SIGNED ? 1 : 0 ) );
    HV_STORE_CONST( hv, "enumerators", GetEnumerators( pEnumSpec->enumerators ) );
  }

  HV_STORE_CONST( hv, "context", newSVpvf( "%s(%lu)", pEnumSpec->context.pFI->name,
                                                      pEnumSpec->context.line ) );

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
        sv_catpvf( sv, "[%ld]", pValue->iv );

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

    if( pStructDecl->declarators ) {
      HV_STORE_CONST( hv, "declarators",
                          GetDeclarators( pStructDecl->declarators ) );
    }

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

  HV_STORE_CONST( hv, "context", newSVpvf( "%s(%lu)", pStruct->context.pFI->name,
                                                      pStruct->context.line ) );

  return newRV_noinc( (SV *) hv );
}

/*******************************************************************************
*
*   ROUTINE: AppendStructMemberString
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2003
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

static GSMSRV AppendStructMemberStringRec( StructDeclaration *pStructDecl,
                                           Declarator *pDecl,
                                           int offset, int realoffset,
                                           SV *sv, int dotflag, GSMSInfo *pInfo )
{
  Struct *pStruct;
  Value  *pValue;
  int     index, size;

  CT_DEBUG( MAIN, ("AppendStructMemberStringRec( off=%d, roff=%d, dot=%d )",
                   offset, realoffset, dotflag) );

  if( pDecl->identifier[0] != '\0' ) {
    if( dotflag ) {
      CT_DEBUG( MAIN, ("Appending dot") );
      sv_catpv( sv, "." );
    }

    CT_DEBUG( MAIN, ("Appending identifier [%s]", pDecl->identifier) );
    sv_catpv( sv, pDecl->identifier );
  }

  offset -= pDecl->offset;
  size    = pDecl->size;

  LL_foreach( pValue, pDecl->array ) {
    size /= pValue->iv;
    index = offset/size;
    CT_DEBUG( MAIN, ("Appending array size [%d]", index) );
    sv_catpvf( sv, "[%d]", index );
    offset -= index*size;
  }

  realoffset = offset;

  pStruct = NULL;

  if( ! pDecl->pointer_flag ) {
    if( pStructDecl->type.tflags & T_TYPE ) {
      Typedef *pTypedef = (Typedef *) pStructDecl->type.ptr;
  
      while( ! pTypedef->pDecl->pointer_flag
            && pTypedef->pType->tflags & T_TYPE )
        pTypedef = (Typedef *) pTypedef->pType->ptr;
  
      if( ! pTypedef->pDecl->pointer_flag
         && pTypedef->pType->tflags & (T_STRUCT|T_UNION) )
        pStruct = (Struct *) pTypedef->pType->ptr;
    }
    else if( pStructDecl->type.tflags & (T_STRUCT|T_UNION) )
      pStruct = (Struct *) pStructDecl->type.ptr;
  }

  if( pStruct )
    return GetStructMemberStringRec( pStruct, offset, realoffset, sv, 1, pInfo );

  if( pInfo ) {
    pInfo->pDecl       = pDecl;
    pInfo->pStructDecl = pStructDecl;
  }

  if( offset > 0 ) {
    CT_DEBUG( MAIN, ("Appending type offset [+%d]", realoffset) );
    sv_catpvf( sv, "+%d", realoffset );
    return GSMS_HIT_OFF;
  }

  return GSMS_HIT;
}

/*******************************************************************************
*
*   ROUTINE: GetStructMemberStringRec
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2003
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

static GSMSRV GetStructMemberStringRec( Struct *pStruct, int offset, int realoffset,
                                        SV *sv, int dotflag, GSMSInfo *pInfo )
{
  StructDeclaration *pStructDecl;
  Declarator        *pDecl;
  SV                *tmpSV, *bestSV;
  GSMSInfo           bestInfo;
  int                best, isUnion;

  CT_DEBUG( MAIN, ("GetStructMemberStringRec( off=%d, roff=%d, dot=%d )",
                   offset, realoffset, dotflag) );

  if( pInfo ) {
    bestInfo.pDecl       = NULL;
    bestInfo.pStructDecl = NULL;
  }

  if( pStruct->declarations == NULL ) {
    WARN_UNDEF_STRUCT( pStruct );
    return 0;
  }

  if( (isUnion = pStruct->tflags & T_UNION) != 0 ) {
    best   = GSMS_NONE;
    bestSV = NULL;
    tmpSV  = NULL;
  }

  LL_foreach( pStructDecl, pStruct->declarations ) {
    CT_DEBUG( MAIN, ("Current StructDecl: offset=%d size=%d decl=%p",
                     pStructDecl->offset, pStructDecl->size,
                     pStructDecl->declarators) );

    if( pStructDecl->offset > offset ) {
      /* This cannot be a union, so bestSV and tmpSV are not used */
      CT_DEBUG( MAIN, ("Padding region found, exiting") );
      sv_catpvf( sv, "+%d", realoffset );
      return GSMS_PAD;
    }

    if(   pStructDecl->offset <= offset
       && offset < pStructDecl->offset+pStructDecl->size
      ) {
      CT_DEBUG( MAIN, ("Member possilbly within current StructDecl "
                       "( %d <= %d < %d )", pStructDecl->offset, offset,
                       pStructDecl->offset+pStructDecl->size) );

      if( pStructDecl->declarators == NULL ) {
        TypeSpec *pTS;

        CT_DEBUG( MAIN, ("Current StructDecl is an unnamed %s",
                         isUnion ? "union" : "struct") );

        pTS = &pStructDecl->type;
        FOLLOW_AND_CHECK_TSPTR( pTS );

        if( isUnion ) {
          GSMSRV rval;

          if( tmpSV == NULL )
            tmpSV = newSVpvn( "", 0 );
          else
            sv_setpvn( tmpSV, "", 0 );

          rval = GetStructMemberStringRec( (Struct *) pTS->ptr, offset,
                                           realoffset, tmpSV, dotflag, pInfo );

          if( rval > best ) {
            CT_DEBUG( MAIN, ("New member [%s] has better ranking (%d) than "
                             "old member [%s] (%d)", SvPV_nolen(tmpSV), rval,
                             bestSV ? SvPV_nolen(bestSV) : "", best ) );

            best = rval;

            if( pInfo )
              bestInfo = *pInfo;

            if( bestSV ) {
              SV *t;
              t      = tmpSV;
              tmpSV  = bestSV;
              bestSV = t;
            }
            else {
              bestSV = tmpSV;
              tmpSV  = NULL;
            }
          }

          if( best == GSMS_HIT ) {
            CT_DEBUG( MAIN, ("Hit struct member without offset") );
            goto handle_union_end;
          }
        }
        else /* not isUnion */ {
          return GetStructMemberStringRec( (Struct *) pTS->ptr,
                                           offset - pStructDecl->offset,
                                           realoffset, sv, dotflag, pInfo );
        }
      }
      else {
        LL_foreach( pDecl, pStructDecl->declarators ) {
          CT_DEBUG( MAIN, ("Current Declarator [%s]: offset=%d size=%d",
                           pDecl->identifier, pDecl->offset, pDecl->size) );

          if( pDecl->offset > offset ) {
            /* This cannot be a union, so bestSV and tmpSV are not used */
            CT_DEBUG( MAIN, ("Padding region found, exiting") );
            sv_catpvf( sv, "+%d", realoffset );
            return GSMS_PAD;
          }

          if( pDecl->offset <= offset && offset < pDecl->offset+pDecl->size ) {
            CT_DEBUG( MAIN, ("Member possibly within current Declarator [%s] "
                             "( %d <= %d < %d )",
                             pDecl->identifier, pDecl->offset, offset,
                             pDecl->offset+pDecl->size ) );

            if( isUnion ) {
              GSMSRV rval;

              if( tmpSV == NULL )
                tmpSV = newSVpvn( "", 0 );
              else
                sv_setpvn( tmpSV, "", 0 );

              rval = AppendStructMemberStringRec( pStructDecl, pDecl, offset,
                                                  realoffset, tmpSV, dotflag, pInfo );

              if( rval > best ) {
                CT_DEBUG( MAIN, ("New member [%s] has better ranking (%d) than "
                                 "old member [%s] (%d)", SvPV_nolen(tmpSV), rval,
                                 bestSV ? SvPV_nolen(bestSV) : "", best ) );

                best = rval;

                if( pInfo )
                  bestInfo = *pInfo;

                if( bestSV ) {
                  SV *t;
                  t      = tmpSV;
                  tmpSV  = bestSV;
                  bestSV = t;
                }
                else {
                  bestSV = tmpSV;
                  tmpSV  = NULL;
                }
              }

              if( best == GSMS_HIT ) {
                CT_DEBUG( MAIN, ("Hit struct member without offset") );
                goto handle_union_end;
              }
            }
            else /* not isUnion */ {
              return AppendStructMemberStringRec( pStructDecl, pDecl, offset,
                                                  realoffset, sv, dotflag, pInfo );
            }
          }
        }
      }
    }
  }

  CT_DEBUG( MAIN, ("End of %s reached", isUnion ? "union" : "struct") );

  if( !isUnion || bestSV == NULL ) {
    CT_DEBUG( MAIN, ("Padding region found, exiting") );
    sv_catpvf( sv, "+%d", realoffset );
    return GSMS_PAD;
  }

handle_union_end:

  if( ! isUnion )
    fatal( "not a union!" );

  if( bestSV == NULL )
    fatal( "bestSV not set!" );

  sv_catsv( sv, bestSV );

  sv_dec( bestSV );

  if( tmpSV )
    sv_dec( tmpSV );

  if( pInfo )
    *pInfo = bestInfo;

  return best;
}

/*******************************************************************************
*
*   ROUTINE: GetStructMemberString
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2003
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

static void GetStructMemberString( Struct *pStruct, int offset, SV *sv, SV **pType )
{
  GSMSInfo info;
  GSMSRV rval;

  CT_DEBUG( MAIN, ("GetStructMemberString( off=%d )", offset) );

  info.pStructDecl = NULL;
  info.pDecl       = NULL;

  rval = GetStructMemberStringRec( pStruct, offset, offset, sv, 0,
                                   pType != NULL ? &info : NULL );

  if( pType ) {
    CT_DEBUG( MAIN, ("Determining type") );
    if( rval == GSMS_HIT || rval == GSMS_HIT_OFF ) {
      if( info.pStructDecl == NULL || info.pDecl == NULL )
        fatal( "Cannot determine member type (rval == %d, pStructDecl == 0x%08X, "
               "pDecl == 0x%08X)", rval, info.pStructDecl, info.pDecl );

      if( info.pDecl->pointer_flag )
        *pType = sv_2mortal( newSVpv( "*", 0 ) );
      else
        *pType = sv_2mortal( GetTypeSpec( &info.pStructDecl->type ) );
    }
    else {
      *pType = &PL_sv_undef;
    }
  }
}

/*******************************************************************************
*
*   ROUTINE: SearchStructMember
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jan 2003
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

static int SearchStructMember( Struct *pStruct, const char *elem,
                               StructDeclaration **ppSD, Declarator **ppD )
{
  StructDeclaration *pStructDecl;
  Declarator        *pDecl = NULL;
  int                offset;

  LL_foreach( pStructDecl, pStruct->declarations ) {
    if( pStructDecl->declarators ) {
      LL_foreach( pDecl, pStructDecl->declarators ) {
        if( strEQ( pDecl->identifier, elem ) )
          break;
      }

      if( pDecl ) {
        offset = pDecl->offset;
        break;
      }
    }
    else {
      TypeSpec *pTS = &pStructDecl->type;

      FOLLOW_AND_CHECK_TSPTR( pTS );

      offset  = pStructDecl->offset;
      offset += SearchStructMember( (Struct *) pTS->ptr, elem, &pStructDecl, &pDecl );

      if( pDecl )
        break;
    }
  }

  *ppSD = pStructDecl;
  *ppD  = pDecl;

  return pDecl ? offset : -1;
}

/*******************************************************************************
*
*   ROUTINE: GetStructMember
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
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

static void GetStructMember( Struct *pStruct, const char *member, MemberInfo *pMI )
{
  const char        *c, *ixstr;
  char              *e, *elem;
  int                size, level, t_off;
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

        t_off = SearchStructMember( pStruct, elem, &pStructDecl, &pDecl );

        if( t_off < 0 ) {
          TRUNC_ELEM;
          (void) sprintf( err = errbuf, "Cannot find struct member '%s'", elem );
          goto error;
        }

        offset += t_off;
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

        if( level >= LL_count( pDecl->array ) ) {
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
            else if( level < LL_count( pDecl->array ) ) {
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
                    && pTypedef->pType->tflags & T_TYPE )
                pTypedef = (Typedef *) pTypedef->pType->ptr;
          
              if( ! pTypedef->pDecl->pointer_flag
                 && pTypedef->pType->tflags & (T_STRUCT|T_UNION) ) {
                pStruct = (Struct *) pTypedef->pType->ptr;
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
            if( level == 0 && LL_count( pDecl->array ) == 0 ) {
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

  if( pMI ) {
    pMI->type   = pStructDecl->type;
    pMI->pDecl  = pDecl;
    pMI->level  = level;
    pMI->offset = offset;
    pMI->size   = 0;  /* cannot determine size here */
  }
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

static void *GetTypePointer( CBC *THIS, const char *name, const char **pEOS )
{
  const char *c   = name;
  void       *ptr = NULL;
  int         len = 0;
  enum { S_UNKNOWN, S_STRUCT, S_UNION, S_ENUM } type = S_UNKNOWN;

  while( *c && isSPACE( *c ) ) c++;

  if( *c == '\0' )
    return NULL;

  switch( c[0] ) {
    case 's':
      if( c[1] == 't' &&
          c[2] == 'r' &&
          c[3] == 'u' &&
          c[4] == 'c' &&
          c[5] == 't' &&
          isSPACE( c[6] ) )
      {
        type = S_STRUCT;
        c += 6;
      }
      break;

    case 'u':
      if( c[1] == 'n' &&
          c[2] == 'i' &&
          c[3] == 'o' &&
          c[4] == 'n' &&
          isSPACE( c[5] ) )
      {
        type = S_UNION;
        c += 5;
      }
      break;

    case 'e':
      if( c[1] == 'n' &&
          c[2] == 'u' &&
          c[3] == 'm' &&
          isSPACE( c[4] ) )
      {
        type = S_ENUM;
        c += 4;
      }
      break;

    default:
      break;
  }

  while( *c && isSPACE( *c ) ) c++;

  while( c[len] && ( c[len]=='_' || isALNUM(c[len]) ) ) len++;

  if( len == 0 )
    return NULL;

  switch( type ) {
    case S_STRUCT:
    case S_UNION:
      {
        Struct *pStruct = HT_get( THIS->cpi.htStructs, c, len, 0 );
        ptr = (void *) (pStruct && (pStruct->tflags & (type == S_STRUCT
                       ? T_STRUCT : T_UNION)) ? pStruct : NULL);
      }
      break;

    case S_ENUM:
      ptr = HT_get( THIS->cpi.htEnums, c, len, 0 );
      break;

    default:
      if( (ptr = HT_get( THIS->cpi.htTypedefs, c, len, 0 )) == NULL )
        if( (ptr = HT_get( THIS->cpi.htStructs, c, len, 0 )) == NULL )
          ptr = HT_get( THIS->cpi.htEnums, c, len, 0 );
      break;
  }

  c += len;

  while( *c && isSPACE( *c ) ) c++;

  if( pEOS )
    *pEOS = c;

  return ptr;
}

/*******************************************************************************
*
*   ROUTINE: GetMemberInfo
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
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

static int GetMemberInfo( CBC *THIS, const char *name, MemberInfo *pMI )
{
  const char *member;
  void *ptr;

  ptr = GetTypePointer( THIS, name, &member );

  if( ptr == NULL )
    return 0;

  if( pMI ) {
    if( *member ) {
      if( *member == '.' ) {
        Struct *pStruct = NULL;

        switch( GET_CTYPE( ptr ) ) {
          case TYP_TYPEDEF:
            {
              Typedef *pTypedef = (Typedef *) ptr;
              ErrorGTI err;

              err = GetTypeInfo( &THIS->cfg, pTypedef->pType,
                                 pTypedef->pDecl, NULL, NULL,
                                 NULL, NULL );

              if( err != GTI_NO_ERROR )
                CroakGTI( err, name, 0 );

              while( ! pTypedef->pDecl->pointer_flag
                    && pTypedef->pType->tflags & T_TYPE )
                pTypedef = (Typedef *) pTypedef->pType->ptr;

              if( ! pTypedef->pDecl->pointer_flag
                 && pTypedef->pType->tflags & (T_STRUCT|T_UNION) )
                pStruct = (Struct *) pTypedef->pType->ptr;
              else {
                if( pTypedef->pDecl->pointer_flag )
                  croak( "A pointer type does not have members" );
                else if( pTypedef->pType->tflags & T_ENUM )
                  croak( "An enum does not have members" );
                else
                  croak( "A basic type does not have members" );
              }
            }
            break;

          case TYP_STRUCT:
            pStruct = (Struct *) ptr;
            break;

          case TYP_ENUM:
            croak( "An enum does not have members" );
            break;

          default:
            fatal("GetTypePointer returned an invalid type (%d) in "
                  "GetMemberInfo( '%s' )", GET_CTYPE( ptr ), name);
            break;
        }

        if( pStruct != NULL ) {
          ErrorGTI err;

          GetStructMember( pStruct, member+1, pMI );

          err = GetTypeInfo( &THIS->cfg, &pMI->type, NULL,
                             &pMI->size, NULL, NULL, &pMI->flags );

          if( err != GTI_NO_ERROR ) {
            CroakGTI( err, name, 0 );
            return 0;
          }

          if( pMI->pDecl && pMI->pDecl->array ) {
            Value   *pValue;
            unsigned level = pMI->level;

            LL_foreach( pValue, pMI->pDecl->array ) {
              if( IS_UNSAFE_VAL( *pValue ) )
                pMI->flags |= T_UNSAFE_VAL;
              if( level > 0 )
                level--;
              else
                pMI->size *= pValue->iv;
            }
          }

          return 1;
        }

        return 0;
      }
      else {
        croak( "Invalid character '%c' (0x%02X) in struct "
               "member expression", *member, (int) *member );
      }
    }
    else {
      pMI->flags = 0;

      switch( GET_CTYPE( ptr ) ) {
        case TYP_TYPEDEF:
          {
            ErrorGTI err;
            err = GetTypeInfo( &THIS->cfg, ((Typedef *) ptr)->pType,
                               ((Typedef *) ptr)->pDecl, &pMI->size, NULL,
                               NULL, &pMI->flags );
            if( err != GTI_NO_ERROR )
              CroakGTI( err, name, 0 );
          }
          pMI->type.tflags = T_TYPE;
          break;

        case TYP_STRUCT:
          if( ((Struct *) ptr)->declarations == NULL )
            CROAK_UNDEF_STRUCT( (Struct *) ptr );
          pMI->size  = ((Struct *) ptr)->size;
          pMI->flags = ((Struct *) ptr)->tflags & (T_HASBITFIELD | T_UNSAFE_VAL);
          pMI->type.tflags = ((Struct *)ptr)->tflags;
          break;

        case TYP_ENUM:
          pMI->size = GET_ENUM_SIZE( (EnumSpecifier *) ptr );
          pMI->type.tflags = T_ENUM;
          break;

        default:
          fatal("GetTypePointer returned an invalid type (%d) in "
                "GetMemberInfo( '%s' )", GET_CTYPE( ptr ), name);
          break;
      }

      pMI->type.ptr = ptr;
      pMI->pDecl    = NULL;
      pMI->level    = 0;
      pMI->offset   = 0;
    }
  }

  return 1;
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

  while( pTypedef->pType->tflags & T_TYPE ) {
    pTypedef = (Typedef *) pTypedef->pType->ptr;
    if( pTypedef->pDecl->pointer_flag )
      return 1;
  }

  if( pTypedef->pType->tflags & (T_STRUCT|T_UNION) )
    return ((Struct*)pTypedef->pType->ptr)->declarations != NULL;

  if( pTypedef->pType->tflags & T_ENUM )
    return ((EnumSpecifier*)pTypedef->pType->ptr)->enumerators != NULL;

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
static void debug_vprintf( char *f, va_list *l )
{
  vfprintf( gs_DB_stream, f, *l );
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
      sv_catpvf( str, "%" IVdf "%s", IVdf_cast *options++,
                      n <  count-2 ? ", " : n == count-2 ? " or " : "" );

    croak( "%s must be %s, not %" IVdf, name, SvPV_nolen( str ),
                                        IVdf_cast *value );
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

static void HandleStringList( const char *option, LinkedList list, SV *sv, SV **rval )
{
  const char *str;

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
*   ROUTINE: DisabledKeywords
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Dec 2002
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

static void DisabledKeywords( LinkedList *current, SV *sv, SV **rval, u_32 *pKeywordMask )
{
  const char *str;
  LinkedList keyword_list = NULL;

  if( sv ) {
    if( SvROK( sv ) ) {
      sv = SvRV( sv );
      if( SvTYPE( sv ) == SVt_PVAV ) {
        AV *av = (AV *) sv;
        SV **pSV;
        int i, max = av_len( av );
        u_32 keywords = HAS_ALL_KEYWORDS;

        keyword_list = LL_new();
  
        for( i=0; i<=max; ++i ) {
          if( (pSV = av_fetch( av, i, 0 )) != NULL ) {
            str = SvPV_nolen( *pSV );

#include "t_keywords.c"

            success:
            LL_push( keyword_list, string_new( str ) );
          }
          else
            fatal( "NULL returned by av_fetch() in DisabledKeywords()" );
        }

        if( pKeywordMask != NULL )
          *pKeywordMask = keywords;

        if( current != NULL ) {
          LL_destroy( *current, (LLDestroyFunc) string_delete ); 
          *current = keyword_list;
        }
      }
      else
        croak( "DisabledKeywords wants an array reference" );
    }
    else
      croak( "DisabledKeywords wants a reference to an array of strings" );
  }

  if( rval ) {
    AV *av = newAV();

    LL_foreach( str, *current )
      av_push( av, newSVpv( str, 0 ) );

    *rval = newRV_noinc( (SV *) av );
  }

  return;

unknown:
  LL_destroy( keyword_list, (LLDestroyFunc) string_delete );
  croak( "Cannot disable unknown keyword '%s'", str );
}

/*******************************************************************************
*
*   ROUTINE: KeywordMap
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Dec 2002
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

#define FAIL_CLEAN( x )                     \
        do {                                \
          HT_destroy( keyword_map, NULL );  \
          croak x;                          \
        } while(0)

static void KeywordMap( HashTable *current, SV *sv, SV **rval )
{
  HashTable keyword_map = NULL;

  if( sv ) {
    if( SvROK( sv ) ) {
      sv = SvRV( sv );
      if( SvTYPE( sv ) == SVt_PVHV ) {
        HV *hv = (HV *) sv;
        HE *entry;

        keyword_map = HT_new_ex( 4, HT_AUTOGROW );

        (void) hv_iterinit( hv );

        while( (entry = hv_iternext( hv )) != NULL ) {
          SV *value;
          I32 keylen;
          const char *key, *c;
          const CKeywordToken *pTok;

          c = key = hv_iterkey( entry, &keylen );

          if( *c == '\0' )
            FAIL_CLEAN(( "Cannot use empty string as a keyword" ));

          if( *c == '_' || isALPHA(*c) )
            do { c++; } while( *c && ( *c == '_' || isALNUM(*c) ) );

          if( *c != '\0' )
            FAIL_CLEAN(( "Cannot use '%s' as a keyword", key ));

          value = hv_iterval( hv, entry );

          if( value == &PL_sv_undef || !SvOK(value) )
            pTok = get_skip_token();
          else {
            const char *map;

            if( SvROK( value ) )
              FAIL_CLEAN(( "Cannot use a reference as a keyword", key ));

            map = SvPV_nolen( value );

            if( (pTok = get_c_keyword_token( map )) == NULL )
              FAIL_CLEAN(( "Cannot use '%s' as a keyword", map ));
          }

          (void) HT_store( keyword_map, key, (int) keylen, 0, (CKeywordToken *) pTok );
        }

        if( current != NULL ) {
          HT_destroy( *current, NULL ); 
          *current = keyword_map;
        }
      }
      else
        croak( "KeywordMap wants a hash reference" );
    }
    else
      croak( "KeywordMap wants a hash reference" );
  }

  if( rval ) {
    HV *hv = newHV();
    CKeywordToken *tok;
    char *key;
    int keylen;

    HT_reset( *current );
    while( HT_next( *current, &key, &keylen, (void **) &tok ) ) {
      SV *val;
      val = tok->name == NULL ? newSV(0) : newSVpv( tok->name, 0 );
      if( hv_store( hv, key, keylen, val, 0 ) == NULL )
        sv_dec( val );
    }

    *rval = newRV_noinc( (SV *) hv );
  }
}

#undef FAIL_CLEAN

/*******************************************************************************
*
*   ROUTINE: CloneStringList
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
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

static LinkedList CloneStringList( LinkedList list )
{
  char *str;
  LinkedList clone;

  clone = LL_new();

  LL_foreach( str, list )
    LL_push( clone, string_new( str ) );

  return clone;
}

/*******************************************************************************
*
*   ROUTINE: GetConfigOption
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Dec 2002
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

#include "t_config.c"

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

static const IV PointerSizeOption[]     = {     0, 1, 2, 4, 8         };
static const IV EnumSizeOption[]        = { -1, 0, 1, 2, 4, 8         };
static const IV IntSizeOption[]         = {     0, 1, 2, 4, 8         };
static const IV ShortSizeOption[]       = {     0, 1, 2, 4, 8         };
static const IV LongSizeOption[]        = {     0, 1, 2, 4, 8         };
static const IV LongLongSizeOption[]    = {     0, 1, 2, 4, 8         };
static const IV FloatSizeOption[]       = {     0, 1, 2, 4, 8, 12, 16 };
static const IV DoubleSizeOption[]      = {     0, 1, 2, 4, 8, 12, 16 };
static const IV LongDoubleSizeOption[]  = {     0, 1, 2, 4, 8, 12, 16 };
static const IV AlignmentOption[]       = {        1, 2, 4, 8,     16 };

#define START_OPTIONS                                                          \
          int changes = 0;                                                     \
          char *option = SvPV_nolen(opt);                                      \
          if( SvROK( opt ) )                                                   \
            croak( "Option name must be a string, not a reference" );          \
          switch( GetConfigOption( option ) ) {

#define END_OPTIONS       } return changes;

#define OPTION( name )    case OPTION_ ## name : {

#define ENDOPT            } break;

#define UPDATE( option, val )                                                  \
          if( (IV) THIS->option != val ) {                                     \
            THIS->option = val;                                                \
            changes = 1;                                                       \
          }

#define FLAG_OPTION( name, flag )                                              \
          case OPTION_ ## name :                                               \
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
            break;

#define IVAL_OPTION( name, config )                                            \
          case OPTION_ ## name :                                               \
            if( sv_val ) {                                                     \
              IV val;                                                          \
              if( CheckIntegerOption( name ## Option, sizeof( name ## Option ) \
                                    / sizeof( IV ), sv_val, &val, #name ) ) {  \
                UPDATE( cfg.config, val );                                     \
              }                                                                \
            }                                                                  \
            if( rval )                                                         \
              *rval = newSViv( THIS->cfg.config );                             \
            break;

#define STRLIST_OPTION( name, config )                                         \
          case OPTION_ ## name :                                               \
            HandleStringList( #name, THIS->cfg.config, sv_val, rval );         \
            changes = sv_val != NULL;                                          \
            break;

#define INVALID_OPTION                                                         \
          default:                                                             \
            croak( "Invalid option '%s'", option );                            \
            break;

static int HandleOption( CBC *THIS, SV *opt, SV *sv_val, SV **rval )
{
  START_OPTIONS

    FLAG_OPTION( UnsignedChars,  CHARS_ARE_UNSIGNED )
    FLAG_OPTION( Warnings,       ISSUE_WARNINGS     )
    FLAG_OPTION( HasCPPComments, HAS_CPP_COMMENTS )
    FLAG_OPTION( HasMacroVAARGS, HAS_MACRO_VAARGS )

    IVAL_OPTION( PointerSize,    ptr_size         )
    IVAL_OPTION( EnumSize,       enum_size        )
    IVAL_OPTION( IntSize,        int_size         )
    IVAL_OPTION( ShortSize,      short_size       )
    IVAL_OPTION( LongSize,       long_size        )
    IVAL_OPTION( LongLongSize,   long_long_size   )
    IVAL_OPTION( FloatSize,      float_size       )
    IVAL_OPTION( DoubleSize,     double_size      )
    IVAL_OPTION( LongDoubleSize, long_double_size )
    IVAL_OPTION( Alignment,      alignment        )

    STRLIST_OPTION( Include, includes   )
    STRLIST_OPTION( Define,  defines    )
    STRLIST_OPTION( Assert,  assertions )
  
    OPTION( DisabledKeywords )
      DisabledKeywords( &THIS->cfg.disabled_keywords, sv_val, rval,
                        &THIS->cfg.keywords );
      changes = sv_val != NULL;
    ENDOPT

    OPTION( KeywordMap )
      KeywordMap( &THIS->cfg.keyword_map, sv_val, rval );
      changes = sv_val != NULL;
    ENDOPT

    OPTION( ByteOrder )
      if( sv_val ) {
        const StringOption *pOpt = GET_STR_OPTION( ByteOrder, 0, sv_val );
        UPDATE( as.bo, pOpt->value );
      }
      if( rval ) {
        const StringOption *pOpt = GET_STR_OPTION( ByteOrder, THIS->as.bo, NULL );
        *rval = newSVpv( pOpt->string, 0 );
      }
    ENDOPT

    OPTION( EnumType )
      if( sv_val ) {
        const StringOption *pOpt = GET_STR_OPTION( EnumType, 0, sv_val );
        UPDATE( enumType, pOpt->value );
      }
      if( rval ) {
        const StringOption *pOpt = GET_STR_OPTION( EnumType, THIS->enumType, NULL );
        *rval = newSVpv( pOpt->string, 0 );
      }
    ENDOPT

    INVALID_OPTION

  END_OPTIONS
}

#undef START_OPTIONS
#undef END_OPTIONS
#undef OPTION
#undef ENDOPT
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

  FLAG_OPTION( UnsignedChars,  CHARS_ARE_UNSIGNED )
  FLAG_OPTION( Warnings,       ISSUE_WARNINGS     )
  FLAG_OPTION( HasCPPComments, HAS_CPP_COMMENTS )
  FLAG_OPTION( HasMacroVAARGS, HAS_MACRO_VAARGS )

  IVAL_OPTION( PointerSize,    ptr_size         )
  IVAL_OPTION( EnumSize,       enum_size        )
  IVAL_OPTION( IntSize,        int_size         )
  IVAL_OPTION( ShortSize,      short_size       )
  IVAL_OPTION( LongSize,       long_size        )
  IVAL_OPTION( LongLongSize,   long_long_size   )
  IVAL_OPTION( FloatSize,      float_size       )
  IVAL_OPTION( DoubleSize,     double_size      )
  IVAL_OPTION( LongDoubleSize, long_double_size )
  IVAL_OPTION( Alignment,      alignment        )

  STRLIST_OPTION( Include,          includes          )
  STRLIST_OPTION( Define,           defines           )
  STRLIST_OPTION( Assert,           assertions        )
  STRLIST_OPTION( DisabledKeywords, disabled_keywords )

  KeywordMap( &THIS->cfg.keyword_map, NULL, &sv );
  HV_STORE_CONST( hv, "KeywordMap", sv );

  STRING_OPTION( ByteOrder, THIS->as.bo    )
  STRING_OPTION( EnumType,  THIS->enumType )

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

		  RETVAL->as.bo                 = DEFAULT_BYTEORDER;
		  RETVAL->enumType              = DEFAULT_ENUMTYPE;

		  RETVAL->cfg.includes          = LL_new();
		  RETVAL->cfg.defines           = LL_new();
		  RETVAL->cfg.assertions        = LL_new();
		  RETVAL->cfg.disabled_keywords = LL_new();
		  RETVAL->cfg.keyword_map       = HT_new(1);
		  RETVAL->cfg.ptr_size          = DEFAULT_PTR_SIZE;
		  RETVAL->cfg.enum_size         = DEFAULT_ENUM_SIZE;
		  RETVAL->cfg.int_size          = DEFAULT_INT_SIZE;
		  RETVAL->cfg.short_size        = DEFAULT_SHORT_SIZE;
		  RETVAL->cfg.long_size         = DEFAULT_LONG_SIZE;
		  RETVAL->cfg.long_long_size    = DEFAULT_LONG_LONG_SIZE;
		  RETVAL->cfg.float_size        = DEFAULT_FLOAT_SIZE;
		  RETVAL->cfg.double_size       = DEFAULT_DOUBLE_SIZE;
		  RETVAL->cfg.long_double_size  = DEFAULT_LONG_DOUBLE_SIZE;
		  RETVAL->cfg.alignment         = DEFAULT_ALIGNMENT;
		  RETVAL->cfg.keywords          = HAS_ALL_KEYWORDS;
		  RETVAL->cfg.flags             = HAS_CPP_COMMENTS
		                                | HAS_MACRO_VAARGS;

		  if( gs_DisableParser ) {
		    warn( XSCLASS " parser is DISABLED" );
		    RETVAL->cfg.flags |= DISABLE_PARSER;
		  }

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

		LL_destroy( THIS->cfg.includes,          (LLDestroyFunc) string_delete );
		LL_destroy( THIS->cfg.defines,           (LLDestroyFunc) string_delete );
		LL_destroy( THIS->cfg.assertions,        (LLDestroyFunc) string_delete );
		LL_destroy( THIS->cfg.disabled_keywords, (LLDestroyFunc) string_delete );

		HT_destroy( THIS->cfg.keyword_map, NULL );

		Safefree( THIS );

################################################################################
#
#   METHOD: clone
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
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
CBC::clone()
	PREINIT:
		CBC  *clone;
		char *class;

	PPCODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::clone", DBG_CTXT_ARG) );

		CHECK_VOID_CONTEXT( clone );

		Newz( 0, clone, 1, CBC );
		Copy( THIS, clone, 1, CBC );
       
       		clone->bufptr     = NULL;
       		clone->buf.buffer = NULL;
		clone->buf.length = 0;
		clone->buf.pos    = 0;

		clone->cfg.includes          = CloneStringList( THIS->cfg.includes );
		clone->cfg.defines           = CloneStringList( THIS->cfg.defines );
		clone->cfg.assertions        = CloneStringList( THIS->cfg.assertions );
		clone->cfg.disabled_keywords = CloneStringList( THIS->cfg.disabled_keywords );

		clone->cfg.keyword_map = HT_clone( THIS->cfg.keyword_map, NULL );

		InitParseInfo( &clone->cpi );
		CloneParseInfo( &clone->cpi, &THIS->cpi );

		class = HvNAME( SvSTASH( SvRV( ST(0) ) ) );
		ST(0) = sv_newmortal();
		sv_setref_pv( ST(0), class, (void *) clone );

		XSRETURN(1);

################################################################################
#
#   METHOD: clean
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
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
CBC::clean()
	CODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::clean", DBG_CTXT_ARG) );

		FreeParseInfo( &THIS->cpi );

		if( GIMME_V != G_VOID )
		  XSRETURN(1);

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

		  XSRETURN(1);
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
                                                                               \
          hasRval = GIMME_V != G_VOID && items <= 1;                           \
                                                                               \
          if( GIMME_V == G_VOID && items <= 1 ) {                              \
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
          if( inval != NULL || hasRval )                                       \
            HandleStringList( #name, THIS->cfg.config, inval,                  \
                                     hasRval ? &rval : NULL );                 \
                                                                               \
          if( hasRval )                                                        \
            ST(0) = sv_2mortal( rval );                                        \
                                                                               \
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
		rval = ParseBuffer( NULL, &buf, &THIS->cfg, &THIS->cpi );
#ifdef CBC_THREAD_SAFE
		MUTEX_UNLOCK( &gs_parse_mutex );
#endif
		if( rval == 0 )
		  croak( "%s", THIS->cpi.errstr );

		UpdateParseInfo( &THIS->cpi, &THIS->cfg );

		if( GIMME_V != G_VOID )
		  XSRETURN(1);

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
		rval = ParseBuffer( file, NULL, &THIS->cfg, &THIS->cpi );
#ifdef CBC_THREAD_SAFE
		MUTEX_UNLOCK( &gs_parse_mutex );
#endif
		if( rval == 0 )
		  croak( "%s", THIS->cpi.errstr );

	        UpdateParseInfo( &THIS->cpi, &THIS->cfg );

		if( GIMME_V != G_VOID )
		  XSRETURN(1);

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

char *
CBC::def( type )
	char *type

	PREINIT:
		void *ptr;

	CODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::def( '%s' )", DBG_CTXT_ARG, type) );

		CHECK_PARSE_DATA( def );
		CHECK_VOID_CONTEXT( def );

		if( (ptr = GetTypePointer( THIS, type, NULL )) == NULL )
		  XSRETURN_UNDEF;

		switch( GET_CTYPE( ptr ) ) {
		  case TYP_TYPEDEF:
		    RETVAL = IsTypedefDefined( (Typedef *) ptr ) ? "typedef" : "";
		    break;

		  case TYP_STRUCT:
		    if( ((Struct *) ptr)->declarations )
		      RETVAL = ((Struct *) ptr)->tflags & T_STRUCT ? "struct" : "union";
		    else
		      RETVAL = "";
		    break;

		  case TYP_ENUM:
		    RETVAL = ((EnumSpecifier *) ptr)->enumerators ? "enum" : "";
		    break;

		  default:
		    fatal("GetTypePointer returned an invalid type (%d) in "
                          XSCLASS "::def( '%s' )", GET_CTYPE( ptr ), type);
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
		char *buffer;
		MemberInfo mi;

	CODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::pack( '%s' )",
		                 DBG_CTXT_ARG, type) );

		CHECK_PARSE_DATA( pack );

		if( string == NULL && GIMME_V == G_VOID ) {
		  WARN_VOID_CONTEXT( pack );
		  XSRETURN_EMPTY;
		}

		if( string != NULL )  {
		  if( ! SvPOK( string ) )
		    croak( "Type of arg 3 to pack must be string" );
		  if( GIMME_V == G_VOID && SvREADONLY( string ) )
		    croak( "Modification of a read-only value attempted" );
		}

		if( !GetMemberInfo( THIS, type, &mi ) )
		  croak( "Cannot find '%s'", type );

		if( mi.flags )
		  WARN_FLAGS( pack, type, mi.flags );

		if( string == NULL ) {
		  RETVAL = newSV( mi.size );
		  SvPOK_only( RETVAL );
		  SvCUR_set( RETVAL, mi.size );
		  buffer = SvPVX( RETVAL );
		  Zero( buffer, mi.size, char );
		}
		else {
		  STRLEN len = SvCUR( string );
		  STRLEN max = mi.size > len ? mi.size : len;

		  if( GIMME_V == G_VOID ) {
		    RETVAL = &PL_sv_undef;
		    buffer = SvGROW( string, mi.size+1 );
		    SvCUR_set( string, max );
		  }
                  else {
		    RETVAL = newSV( max );
		    SvPOK_only( RETVAL );
		    buffer = SvPVX( RETVAL );
		    SvCUR_set( RETVAL, max );
		    Copy( SvPVX(string), buffer, len, char );
		  }

		  if( mi.size > len )
		    Zero( buffer+len, mi.size-len, char );
		}

		THIS->bufptr     =
		THIS->buf.buffer = buffer;
		THIS->buf.length = mi.size;
		THIS->buf.pos    = 0;

		THIS->align_base = 0;
		THIS->alignment  = THIS->cfg.alignment;

		SetType( THIS, &mi.type, mi.pDecl, mi.level, data, type );

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
		MemberInfo mi;

	CODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::unpack( '%s' )",
		                 DBG_CTXT_ARG, type) );

		CHECK_PARSE_DATA( unpack );
		CHECK_VOID_CONTEXT( unpack );

		if( !SvPOK( string ) )
		  croak( "Type of arg 2 to unpack must be string" );

		if( !GetMemberInfo( THIS, type, &mi ) )
		  croak( "Cannot find '%s'", type );

		if( mi.flags )
		  WARN_FLAGS( unpack, type, mi.flags );

                THIS->bufptr     =
		THIS->buf.buffer = SvPV( string, len );
		THIS->buf.pos    = 0;
		THIS->buf.length = len;

		THIS->align_base = 0;
		THIS->alignment  = THIS->cfg.alignment;

		THIS->dataTooShortFlag = 0;

		RETVAL = GetType( THIS, &mi.type, mi.pDecl, mi.level );

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
		MemberInfo mi;

	CODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::sizeof( '%s' )",
		                 DBG_CTXT_ARG, type) );

		CHECK_PARSE_DATA( sizeof );
		CHECK_VOID_CONTEXT( sizeof );

		if( !GetMemberInfo( THIS, type, &mi ) )
		  croak( "Cannot find '%s'", type );

		if( mi.flags )
		  WARN_FLAGS( sizeof, type, mi.flags );
#ifdef newSVuv
		RETVAL = newSVuv( mi.size );
#else
		RETVAL = newSViv( (IV) mi.size );
#endif

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
		Struct *pStruct = NULL;
		MemberInfo mi;

	CODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::offsetof( '%s', '%s' )",
		                 DBG_CTXT_ARG, type, member) );

		CHECK_PARSE_DATA( offsetof );
		CHECK_VOID_CONTEXT( offsetof );

		if( !GetMemberInfo( THIS, type, &mi ) )
		  croak( "Cannot find '%s'", type );

		if( mi.pDecl != NULL ) {
		  if( mi.pDecl->pointer_flag )
		    croak( "Cannot use offsetof on a pointer type" );

		  if(   mi.pDecl->array
                     && ((int) mi.level) < LL_count( mi.pDecl->array ) )
		    croak( "Cannot use offsetof on an array type" );
		}

		if( mi.type.ptr == NULL )
		  fatal("GetMemberInfo returned NULL type pointer in "
                        XSCLASS "::offsetof( '%s', '%s' )", type, member);

		switch( GET_CTYPE( mi.type.ptr ) ) {
		  case TYP_TYPEDEF:
		    {
		      Typedef *pTypedef = (Typedef *) mi.type.ptr;
		      ErrorGTI err;

		      err = GetTypeInfo( &THIS->cfg, pTypedef->pType,
                                         pTypedef->pDecl, NULL, NULL,
		                         NULL, NULL );

		      if( err != GTI_NO_ERROR )
		        CroakGTI( err, type, 0 );

		      while( ! pTypedef->pDecl->pointer_flag
		            && pTypedef->pType->tflags & T_TYPE )
		        pTypedef = (Typedef *) pTypedef->pType->ptr;

		      if( ! pTypedef->pDecl->pointer_flag
		         && pTypedef->pType->tflags & (T_STRUCT|T_UNION) )
		        pStruct = (Struct *) pTypedef->pType->ptr;
		      else {
		        if( pTypedef->pDecl->pointer_flag )
		          croak( "Cannot use offsetof on a pointer type" );
		        else if( pTypedef->pType->tflags & T_ENUM )
		          croak( "Cannot use offsetof on an enum" );
		        else
		          croak( "Cannot use offsetof on a basic type" );
		      }
		    }
		    break;

		  case TYP_STRUCT:
		    pStruct = (Struct *) mi.type.ptr;
		    break;

		  case TYP_ENUM:
		    croak( "Cannot use offsetof on an enum" );
		    break;

		  default:
		    fatal("GetMemberInfo returned an invalid type (%d) in "
                          XSCLASS "::offsetof( '%s', '%s' )",
                          GET_CTYPE( mi.type.ptr ), type, member);
		    break;
		}

		if( pStruct->tflags & (T_HASBITFIELD | T_UNSAFE_VAL) )
		  WARN_FLAGS( offsetof, type, pStruct->tflags );

		if( pStruct->declarations == NULL )
		  CROAK_UNDEF_STRUCT( pStruct );

		GetStructMember( pStruct, member, &mi );
#ifdef newSVuv
		RETVAL = newSVuv( mi.offset );
#else
		RETVAL = newSViv( (IV) mi.offset );
#endif

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

void
CBC::member( type, offset )
	char *type
	int offset

	PREINIT:
		Struct *pStruct = NULL;
		MemberInfo mi;
		SV *member;

	PPCODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::member( '%s', %d )",
		                 DBG_CTXT_ARG, type, offset) );

		CHECK_PARSE_DATA( member );
		CHECK_VOID_CONTEXT( member );

		if( !GetMemberInfo( THIS, type, &mi ) )
		  croak( "Cannot find '%s'", type );

		if( mi.pDecl != NULL ) {
		  if( mi.pDecl->pointer_flag )
		    croak( "Cannot use member on a pointer type" );

		  if(   mi.pDecl->array
                     && ((int) mi.level) < LL_count( mi.pDecl->array ) )
		    croak( "Cannot use member on an array type" );
		}

		if( mi.type.ptr == NULL )
		  fatal("GetMemberInfo returned NULL type pointer in "
                        XSCLASS "::member( '%s', '%d' )", type, offset);

		switch( GET_CTYPE( mi.type.ptr ) ) {
		  case TYP_TYPEDEF:
		    {
		      Typedef *pTypedef = (Typedef *) mi.type.ptr;
		      ErrorGTI err;

		      err = GetTypeInfo( &THIS->cfg, pTypedef->pType,
                                         pTypedef->pDecl, NULL, NULL,
		                         NULL, NULL );

		      if( err != GTI_NO_ERROR )
		        CroakGTI( err, type, 0 );

		      while( ! pTypedef->pDecl->pointer_flag
		            && pTypedef->pType->tflags & T_TYPE )
		        pTypedef = (Typedef *) pTypedef->pType->ptr;
		      
		      if( ! pTypedef->pDecl->pointer_flag
		         && pTypedef->pType->tflags & (T_STRUCT|T_UNION) )
		        pStruct = (Struct *) pTypedef->pType->ptr;
		      else {
		        if( pTypedef->pDecl->pointer_flag )
		          croak( "Cannot use member on a pointer type" );
		        else if( pTypedef->pType->tflags & T_ENUM )
		          croak( "Cannot use member on an enum" );
		        else
		          croak( "Cannot use member on a basic type" );
		      }
		    }
		    break;

		  case TYP_STRUCT:
		    pStruct = (Struct *) mi.type.ptr;
		    break;

		  case TYP_ENUM:
		    croak( "Cannot use member on an enum" );
		    break;

		  default:
		    fatal("GetMemberInfo returned an invalid type (%d) in "
                          XSCLASS "::member( '%s', '%d' )",
                          GET_CTYPE( mi.type.ptr ), type, offset);
		    break;
		}

		if( pStruct->tflags & (T_HASBITFIELD | T_UNSAFE_VAL) )
		  WARN_FLAGS( member, type, pStruct->tflags );

		if( pStruct->declarations == NULL )
		  CROAK_UNDEF_STRUCT( pStruct );

		if( offset < 0 || offset >= (int) pStruct->size )
		  croak( "Offset %d out of range (0 <= offset < %d)",
                         offset, pStruct->size );

		member = sv_2mortal( newSVpvn( "", 0 ) );

		if( GIMME_V == G_ARRAY ) {
		  SV *type;
		  (void) GetStructMemberString( pStruct, offset, member, &type );
		  PUSHs( member );
		  PUSHs( type );    /* type SV is already mortal */
		  XSRETURN( 2 );
		}
		else {
		  (void) GetStructMemberString( pStruct, offset, member, NULL );
		  PUSHs( member );
		  XSRETURN( 1 );
		}

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
		  XSRETURN_IV( items > 1 ? items-1 : LL_count( THIS->cpi.enums ) );

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
		  int size = LL_count( THIS->cpi.enums );

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
            else if( (mask) == 0 )                                             \
              XSRETURN_IV( LL_count( THIS->cpi.structs ) );                    \
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
		TypedefList *pTDL;
		Typedef     *pTypedef;
		int          count = 0;
		U32          context;

	PPCODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::typedef_names", DBG_CTXT_ARG) );

		CHECK_PARSE_DATA( typedef_names );
		CHECK_VOID_CONTEXT( typedef_names );

		context = GIMME_V;

		LL_foreach( pTDL, THIS->cpi.typedef_lists )
		  LL_foreach( pTypedef, pTDL->typedefs )
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
		U32      context;

	PPCODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::typedef", DBG_CTXT_ARG) );

		CHECK_PARSE_DATA( typedef );
		CHECK_VOID_CONTEXT( typedef );

		context = GIMME_V;

		if( context == G_SCALAR && items != 2 )
		  XSRETURN_IV( items > 1 ? items-1 : HT_count( THIS->cpi.htTypedefs ) );

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
		  TypedefList *pTDL;
		  int size = HT_count( THIS->cpi.htTypedefs );

		  if( size <= 0 )
		    XSRETURN_EMPTY;

		  EXTEND( SP, size );

		  LL_foreach( pTDL, THIS->cpi.typedef_lists )
		    LL_foreach( pTypedef, pTDL->typedefs )
		      PUSHs( sv_2mortal( GetTypedefSpec( pTypedef ) ) );

		  XSRETURN( size );
		}

################################################################################
#
#   METHOD: sourcify
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Oct 2002
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
CBC::sourcify()
	CODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::sourcify", DBG_CTXT_ARG) );

		CHECK_PARSE_DATA( sourcify );
		CHECK_VOID_CONTEXT( sourcify );

		RETVAL = GetParsedDefinitionsString( &THIS->cpi );

	OUTPUT:
		RETVAL


################################################################################
#
#   METHOD: dependencies
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Sep 2002
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
CBC::dependencies()
	PREINIT:
		char     *pKey;
		FileInfo *pFI;
		HV       *hv;

	CODE:
		CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::dependencies", DBG_CTXT_ARG) );

		CHECK_PARSE_DATA( dependencies );
		CHECK_VOID_CONTEXT( dependencies );

		hv = newHV();

		HT_foreach( pKey, pFI, THIS->cpi.htFiles ) {
		  if( pFI && pFI->valid ) {
		    SV *attr;
		    HV *hattr = newHV();
#ifdef newSVuv
		    HV_STORE_CONST( hattr, "size",  newSVuv( pFI->size ) );
#else
		    HV_STORE_CONST( hattr, "size",  newSViv( (IV) pFI->size ) );
#endif
		    HV_STORE_CONST( hattr, "mtime", newSViv( pFI->modify_time ) );
		    HV_STORE_CONST( hattr, "ctime", newSViv( pFI->change_time ) );

		    attr = newRV_noinc( (SV *) hattr );

		    if( hv_store( hv, pFI->name, strlen( pFI->name ), attr, 0 ) == NULL )
                      sv_dec( attr );
		  }
		}

		RETVAL = newRV_noinc( (SV *) hv );

	OUTPUT:
		RETVAL

################################################################################
#
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

		if( items % 2 == 0 )
		  croak( "You must pass an even number of module arguments" );
		else {
		  for( i = 1; i < items; i += 2 ) {
		    char *opt = SvPV_nolen( ST(i) );
#ifdef CTYPE_DEBUGGING
		    char *arg = SvPV_nolen( ST(i+1) );
#endif
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
		if( strEQ( feat, "debug" ) )
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

#ifdef CTYPE_DEBUGGING

SV *
__DUMP__( val )
	SV *val

	CODE:
		RETVAL = newSVpvn( "", 0 );
		DumpSV( RETVAL, 0, val );

	OUTPUT:
		RETVAL

#endif


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
		  char *str;
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
		  if( (str = getenv("CBC_DEBUG_OPT")) != NULL )
		    SetDebugOptions( str );
		  if( (str = getenv("CBC_DEBUG_FILE")) != NULL )
		    SetDebugFile( str );
#endif
		  gs_DisableParser = 0;
		  if( (str = getenv("CBC_DISABLE_PARSER")) != NULL )
		    gs_DisableParser = atoi(str);
		}

