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
* $Date: 2003/08/17 10:03:37 +0100 $
* $Revision: 95 $
* $Snapshot: /Convert-Binary-C/0.44 $
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

#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "ppport.h"


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

#ifdef NATIVE_BIG_ENDIAN
#define NATIVE_BYTEORDER   BO_BIG_ENDIAN
#else
#define NATIVE_BYTEORDER   BO_LITTLE_ENDIAN
#endif

#ifndef DEFAULT_BYTEORDER
#define DEFAULT_BYTEORDER  NATIVE_BYTEORDER
#endif


/*-----------------------------*/
/* some stuff for older perl's */
/*-----------------------------*/

/*   <HACK>   */

#if PERL_REVISION == 5 && PERL_VERSION < 6
# define CONST_CHAR(x) ((char *)(x))
#else
# define CONST_CHAR(x) (x)
#endif

#ifndef sv_vcatpvf
static void sv_vcatpvf( SV *sv, const char *pat, va_list *args )
{
  sv_vcatpvfn( sv, pat, strlen(pat), args, NULL, 0, NULL );
}
#endif

#ifndef sv_catpvn_nomg
#define sv_catpvn_nomg sv_catpvn
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

/* values passed between all packing/unpacking routines */
#define pPACKARGS   pTHX_ const CBC *THIS, PackInfo *PACK
#define aPACKARGS   aTHX_ THIS, PACK

/*--------------------------------*/
/* macros for buffer manipulation */
/*--------------------------------*/

#define ALIGN_BUFFER( align )                                                  \
          do {                                                                 \
            unsigned _align = (unsigned)(align) > PACK->alignment              \
                            ? PACK->alignment : (align);                       \
            if( PACK->align_base % _align ) {                                  \
              _align -= PACK->align_base % _align;                             \
              PACK->align_base += _align;                                      \
              PACK->buf.pos    += _align;                                      \
              PACK->bufptr     += _align;                                      \
            }                                                                  \
          } while(0)

#define CHECK_BUFFER( size )                                                   \
          do {                                                                 \
            if( PACK->buf.pos + (size) > PACK->buf.length ) {                  \
              PACK->dataTooShortFlag = 1;                                      \
              PACK->buf.pos = PACK->buf.length;                                \
              return newSV(0);                                                 \
            }                                                                  \
          } while(0)

#define INC_BUFFER( size )                                                     \
          do {                                                                 \
            PACK->align_base += size;                                          \
            PACK->buf.pos    += size;                                          \
            PACK->bufptr     += size;                                          \
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
            SvREFCNT_dec( _val );                                              \
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
                          Perl_warn args;                                      \
                      } while(0)

#define PARSE_DATA (    THIS->cpi.enums         != NULL                        \
                     && THIS->cpi.structs       != NULL                        \
                     && THIS->cpi.typedef_lists != NULL                        \
                   )

#define CBC_METHOD( name )         const char * const method = #name
#define CBC_METHOD_VAR             const char * method = ""
#define CBC_METHOD_SET( string )   method = string

#define CT_DEBUG_METHOD                                                        \
          CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::%s", DBG_CTXT_ARG, method) )

#define CT_DEBUG_METHOD1( fmt, arg1 )                                          \
          CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::%s( " fmt " )",             \
                           DBG_CTXT_ARG, method, arg1) )

#define CT_DEBUG_METHOD2( fmt, arg1, arg2 )                                    \
          CT_DEBUG( MAIN, (DBG_CTXT_FMT XSCLASS "::%s( " fmt " )",             \
                           DBG_CTXT_ARG, method, arg1, arg2) )

#define CHECK_PARSE_DATA                                                       \
          do {                                                                 \
            if( !PARSE_DATA )                                                  \
              Perl_croak(aTHX_ "Call to %s without parse data", method);       \
          } while(0)

#define WARN_VOID_CONTEXT                                                      \
            WARN((aTHX_ "Useless use of %s in void context", method))

#define CHECK_VOID_CONTEXT                                                     \
          do {                                                                 \
            if( GIMME_V == G_VOID ) {                                          \
              WARN_VOID_CONTEXT;                                               \
              XSRETURN_EMPTY;                                                  \
            }                                                                  \
          } while(0)

#define WARN_BITFIELDS( type ) \
          WARN((aTHX_ "Bitfields are unsupported in %s('%s')", method, type))

#define WARN_UNSAFE( type ) \
          WARN((aTHX_ "Unsafe values used in %s('%s')", method, type))

#define WARN_FLAGS( type, flags )                                              \
          do {                                                                 \
            if( (flags) & T_HASBITFIELD )                                      \
              WARN_BITFIELDS( type );                                          \
            else if( (flags) & T_UNSAFE_VAL )                                  \
              WARN_UNSAFE( type );                                             \
          } while(0)

#define CROAK_UNDEF_STRUCT( ptr )                                              \
          Perl_croak(aTHX_ "Got no definition for '%s %s'",                    \
                           (ptr)->tflags & T_UNION ? "union" : "struct",       \
                           (ptr)->identifier)

#define WARN_UNDEF_STRUCT( ptr )                                               \
          WARN((aTHX_ "Got no definition for '%s %s'",                         \
                      (ptr)->tflags & T_UNION ? "union" : "struct",            \
                      (ptr)->identifier ) )

/*------------------------------------------------*/
/* this is needed quite often for unnamed structs */
/*------------------------------------------------*/

#define FOLLOW_AND_CHECK_TSPTR( pTS )                                          \
        do {                                                                   \
          if( (pTS)->tflags & T_TYPE ) {                                       \
            Typedef *_pT = (Typedef *) (pTS)->ptr;                             \
            for(;;) {                                                          \
              if( _pT && _pT->pType->tflags & T_TYPE                           \
                      && _pT->pDecl->pointer_flag == 0                         \
                      && LL_count( _pT->pDecl->array ) == 0 )                  \
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
          (THIS->cfg.enum_size > 0 ? (unsigned) THIS->cfg.enum_size \
                                 : (pES)->sizes[-THIS->cfg.enum_size]) 

/*----------------------------*/
/* checks if an SV is defined */
/*----------------------------*/

#define DEFINED( sv ) ( (sv) != NULL && SvOK(sv) )

/*---------------*/
/* other defines */
/*---------------*/

#define T_ALREADY_DUMPED   T_USER_FLAG_1

#define F_NEWLINE          0x00000001
#define F_KEYWORD          0x00000002
#define F_DONT_EXPAND      0x00000004

#define ALLOW_UNIONS       0x00000001
#define ALLOW_STRUCTS      0x00000002
#define ALLOW_ENUMS        0x00000004
#define ALLOW_POINTERS     0x00000008
#define ALLOW_ARRAYS       0x00000010
#define ALLOW_BASIC_TYPES  0x00000020

/* for fast index -> string conversion */
#define MAX_IXSTR 15

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

/*-----------------------*/
/* IDList handling stuff */
/*-----------------------*/

#define IDLIST_GRANULARITY    8
#define IDLIST_INITIAL_SIZE   (2*IDLIST_GRANULARITY)

#define IDLIST_GROW( idl, size )                                               \
        do {                                                                   \
          if( (size) > (idl)->max ) {                                          \
            int grow = ((size)+(IDLIST_GRANULARITY-1))/IDLIST_GRANULARITY;     \
            grow *= IDLIST_GRANULARITY;                                        \
            Renew( (idl)->list, grow, struct IDList_list );                    \
            (idl)->max = grow;                                                 \
          }                                                                    \
        } while(0)

#define IDLIST_INIT( idl )                                                     \
        do {                                                                   \
          (idl)->count = 0;                                                    \
          (idl)->max   = IDLIST_INITIAL_SIZE;                                  \
          (idl)->cur   = NULL;                                                 \
          New( 0, (idl)->list, (idl)->max, struct IDList_list );               \
        } while(0)

#define IDLIST_FREE( idl )                                                     \
        do {                                                                   \
          Safefree( (idl)->list );                                             \
        } while(0)

#define IDLIST_PUSH( idl, what )                                               \
        do {                                                                   \
          IDLIST_GROW( idl, (idl)->count+1 );                                  \
          (idl)->cur = (idl)->list + (idl)->count++;                           \
          (idl)->cur->choice = IDL_ ## what;                                   \
        } while(0)

#define IDLIST_SET_ID( idl, value )                                            \
        do {                                                                   \
          (idl)->cur->val.id = value;                                          \
        } while(0)

#define IDLIST_SET_IX( idl, value )                                            \
        do {                                                                   \
          (idl)->cur->val.ix = value;                                          \
        } while(0)

#define IDLIST_POP( idl )                                                      \
        do {                                                                   \
          if( --(idl)->count > 0 )                                             \
            (idl)->cur--;                                                      \
          else                                                                 \
            (idl)->cur = NULL;                                                 \
        } while(0)


/*===== TYPEDEFS =============================================================*/

typedef enum { GMS_NONE, GMS_PAD, GMS_HIT_OFF, GMS_HIT } GMSRV;

typedef enum {
  FPT_UNKNOWN,
  FPT_FLOAT,
  FPT_DOUBLE,
  FPT_LONG_DOUBLE
} FPType;

typedef struct {
  LinkedList hit, off, pad;
  HashTable  htpad;
} GMSInfo;

typedef union {
  LinkedList list;
  int        count;
} AMSInfo;

typedef struct {
  int count, max;
  struct IDList_list {
    enum { IDL_ID, IDL_IX } choice;
    union {
      const char *id;
      long        ix;
    } val;
  } *cur, *list;
} IDList;

typedef struct {
  char         *bufptr;
  unsigned      alignment;
  unsigned      align_base;
  int           dataTooShortFlag;
  Buffer        buf;
} PackInfo;

typedef struct {
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
  int         level;
  unsigned    offset;
  unsigned    size;
  u_32        flags;
} MemberInfo;


/*===== STATIC FUNCTION PROTOTYPES ===========================================*/

#ifdef CTYPE_DEBUGGING
static void debug_vprintf( const char *f, va_list *l );
static void debug_printf( const char *f, ... );
static void debug_printf_ctlib( const char *f, ... );
static void SetDebugOptions( pTHX_ const char *dbopts );
static void SetDebugFile( pTHX_ const char *dbfile );

static void DumpSV( pTHX_ SV *buf, int level, SV *sv );
#endif

static void fatal( const char *f, ... ) __attribute__(( __noreturn__ ));
static void *ct_newstr( void );
static void ct_scatf( void *p, const char *f, ... );
static void ct_vscatf( void *p, const char *f, va_list *l );
static void ct_warn( void *p );
static void ct_fatal( void *p ) __attribute__(( __noreturn__ ));

static char *string_new( const char *str );
static char *string_new_fromSV( pTHX_ SV *sv );
static void string_delete( char *sv );

static void CroakGTI( pTHX_ ErrorGTI error, const char *name, int warnOnly );

static const char *IDListToStr( pTHX_ IDList *idl );

static FPType GetFPType( u_32 flags );
static void StoreFloatSV( pPACKARGS, unsigned size, u_32 flags, SV *sv );
static SV *FetchFloatSV( pPACKARGS, unsigned size, u_32 flags );

static void StoreIntSV( pPACKARGS, unsigned size, unsigned sign, SV *sv );
static SV *FetchIntSV( pPACKARGS, unsigned size, unsigned sign );

static SV *GetPointer( pPACKARGS );
static SV *GetStruct( pPACKARGS, Struct *pStruct, HV *hash );
static SV *GetEnum( pPACKARGS, EnumSpecifier *pEnumSpec );
static SV *GetBasicType( pPACKARGS, u_32 flags );
static SV *GetType( pPACKARGS, TypeSpec *pTS, Declarator *pDecl,
                    int dimension );

static void SetPointer( pPACKARGS, SV *sv );
static void SetStruct( pPACKARGS, Struct *pStruct, SV *sv, IDList *idl );
static void SetEnum( pPACKARGS, EnumSpecifier *pEnumSpec, SV *sv );
static void SetBasicType( pPACKARGS, u_32 flags, SV *sv );
static void SetType( pPACKARGS, TypeSpec *pTS, Declarator *pDecl,
                     int dimension, SV *sv, IDList *idl );

static void GetBasicTypeSpecString( pTHX_ SV **sv, u_32 flags );

static void AddIndent( pTHX_ SV *s, int level );

static void CheckDefineType( pTHX_ SV *str, TypeSpec *pTS );

static void AddTypeSpecStringRec( pTHX_ SV *str, SV *s, TypeSpec *pTS, int level, U32 *pFlags );
static void AddEnumSpecStringRec( pTHX_ SV *str, SV *s, EnumSpecifier *pES, int level, U32 *pFlags );
static void AddStructSpecStringRec( pTHX_ SV *str, SV *s, Struct *pStruct, int level, U32 *pFlags );

static void AddTypedefListDeclString( pTHX_ SV *str, TypedefList *pTDL );
static void AddTypedefListSpecString( pTHX_ SV *str, TypedefList *pTDL );
static void AddEnumSpecString( pTHX_ SV *str, EnumSpecifier *pES );
static void AddStructSpecString( pTHX_ SV *str, Struct *pStruct );

static SV *GetParsedDefinitionsString( pTHX_ CParseInfo *pCPI );

static void GetInitStrStruct( pTHX_ CBC *THIS, Struct *pStruct, SV *init,
                              IDList *idl, int level, SV *string );
static void GetInitStrType( pTHX_ CBC *THIS, TypeSpec *pTS, Declarator *pDecl,
                            int dimension, SV *init, IDList *idl,
                            int level, SV *string );

static SV *GetInitializerString( pTHX_ CBC *THIS, MemberInfo *pMI, SV *init,
                                 const char *name );

static void GetAMSStruct( pTHX_ Struct *pStruct, SV *name, int level,
                          AMSInfo *info );
static void GetAMSType( pTHX_ TypeSpec *pTS, Declarator *pDecl, int dimension,
                        SV *name, int level, AMSInfo *info );

static int GetAllMemberStrings( pTHX_ MemberInfo *pMI, LinkedList list );

static SV *GetTypeSpecDef( pTHX_ TypeSpec *pTSpec );
static SV *GetTypedefDef( pTHX_ Typedef *pTypedef );

static SV *GetEnumeratorsDef( pTHX_ LinkedList enumerators );
static SV *GetEnumSpecDef( pTHX_ EnumSpecifier *pEnumSpec );

static SV *GetDeclaratorsDef( pTHX_ LinkedList declarators );
static SV *GetStructDeclarationsDef( pTHX_ LinkedList declarations );
static SV *GetStructSpecDef( pTHX_ Struct *pStruct );

static GMSRV AppendMemberStringRec( pTHX_ const TypeSpec *pType, const Declarator *pDecl,
                                          int offset, SV *sv, GMSInfo *pInfo );
static GMSRV GetMemberStringRec( pTHX_ const Struct *pStruct, int offset, int realoffset,
                                       SV *sv, GMSInfo *pInfo );
static SV *GetMemberString( pTHX_ const MemberInfo *pMI, int offset, GMSInfo *pInfo );

static int  SearchStructMember( Struct *pStruct, const char *elem,
                                StructDeclaration **ppSD, Declarator **ppD );
static void GetMember( pTHX_ const MemberInfo *pMI, const char *member,
                             MemberInfo *pMIout, int accept_dotless_member );

static void *GetTypePointer( CBC *THIS, const char *name, const char **pEOS );
static int   GetTypeSpec( CBC *THIS, const char *name, const char **pEOS, TypeSpec *pTS );
static int   GetMemberInfo( pTHX_ CBC *THIS, const char *name, MemberInfo *pMI );
static SV   *GetTypeNameString( pTHX_ const MemberInfo *pMI );
static int   IsTypedefDefined( Typedef *pTypedef );

static int   CheckIntegerOption( pTHX_ const IV *options, int count, SV *sv,
                                 IV *value, const char *name );
static const StringOption *GetStringOption( pTHX_ const StringOption *options, int count,
                                            int value, SV *sv, const char *name );
static LinkedList CloneStringList( LinkedList list );
static void  HandleStringList( pTHX_ const char *option, LinkedList list, SV *sv, SV **rval );
static void  DisabledKeywords( pTHX_ LinkedList *current, SV *sv, SV **rval, u_32 *pKeywordMask );
static void  KeywordMap( pTHX_ HashTable *current, SV *sv, SV **rval );
static int   HandleOption( pTHX_ CBC *THIS, SV *opt, SV *sv_val, SV **rval );
static SV   *GetConfiguration( pTHX_ CBC *THIS );
static void  UpdateConfiguration( CBC *THIS );

static void CheckAllowedTypes( pTHX_ const MemberInfo *pMI, const char *method,
                               U32 allowedTypes );

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

#define INDENT                             \
        do {                               \
          if( level > 0 )                  \
            AddIndent( aTHX_ buf, level ); \
        } while(0)


static void DumpSV( pTHX_ SV *buf, int level, SV *sv )
{
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

  CT_DEBUG( MAIN, (XSCLASS "::DumpSV( level=%d, sv=\"%s\" )", level, str) );

#ifdef CBC_USE_MORE_MEMORY
  /*
   *  This speeds up dump at the cost of memory,
   *  as it prevents a lot of realloc()s.
   *  Actually, it was only inserted to make valgrind
   *  run at acceptable speed... ;-)
   */
  {
    STRLEN cur, len;
    cur = SvCUR(buf) + 64;   // estimated new string length
    if( cur > 1024 ) {       // do nothing for small strings
      len = SvLEN(buf);      // buffer size
      if( cur > len ) {
        len = (len>>10)<<11; // double buffer size
        (void) sv_grow( buf, len );
      }
    }
  }
#endif

  INDENT; level++;
  sv_catpvf( buf, "SV = %s @ %p (REFCNT = %d)\n", str, sv, SvREFCNT(sv) );

  switch( type ) {
    case SVt_RV:
      DumpSV( aTHX_ buf, level, SvRV( sv ) );
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
            DumpSV( aTHX_ buf, level, *p );
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
          DumpSV( aTHX_ buf, level, v );
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

static void fatal( const char *f, ... )
{
  dTHX;
  va_list l;
  SV *sv = newSVpvn( "", 0 );

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

  SvREFCNT_dec( sv );

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
  dTHX;
  return (void *) sv_2mortal( newSVpvn( "", 0 ) );
}

static void ct_scatf( void *p, const char *f, ... )
{
  dTHX;
  va_list l;
  va_start( l, f );
  sv_vcatpvf( (SV*)p, f, &l );
  va_end( l );
}

static void ct_vscatf( void *p, const char *f, va_list *l )
{
  dTHX;
  sv_vcatpvf( (SV*)p, f, l );
}

static void ct_warn( void *p )
{
  dTHX;
  if( PERL_WARNINGS_ON )
    Perl_warn(aTHX_ "%s", SvPV_nolen((SV*)p));
}

static void ct_fatal( void *p )
{
  dTHX;
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

static char *string_new_fromSV( pTHX_ SV *sv )
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

static void CroakGTI( pTHX_ ErrorGTI error, const char *name, int warnOnly )
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
      WARN((aTHX_ "%s in resolution of '%s'", errstr, name));
    else
      WARN((aTHX_ "%s in resolution of typedef", errstr));
  }
  else {
    if( name )
      Perl_croak(aTHX_ "%s in resolution of '%s'", errstr, name);
    else
      Perl_croak(aTHX_ "%s in resolution of typedef", errstr);
  }
}

/*******************************************************************************
*
*   ROUTINE: IDListToStr
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jul 2003
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

static const char *IDListToStr( pTHX_ IDList *idl )
{
  SV *sv;
  int i;
  struct IDList_list *cur;

  sv = sv_2mortal( newSVpvn( "", 0 ) );
  cur = idl->list;

  for( i = 0; i < idl->count; ++i, ++cur ) {
    switch( cur->choice ) {
      case IDL_ID:
        if( i == 0 )
          sv_catpv( sv, cur->val.id );
        else
          sv_catpvf( sv, ".%s", cur->val.id );
        break;

      case IDL_IX:
        sv_catpvf( sv, "[%ld]", cur->val.ix );
        break;

      default:
        /* TODO: fatal() ? */
        break;
    }
  }

  return SvPV_nolen(sv);
}

/*******************************************************************************
*
*   ROUTINE: GetFPType
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jun 2003
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

static FPType GetFPType( u_32 flags )
{
  /* mask out irrelevant flags */
  flags &= T_VOID | T_CHAR | T_SHORT | T_INT
         | T_LONG | T_FLOAT | T_DOUBLE | T_SIGNED
         | T_UNSIGNED | T_LONGLONG;

  /* only a couple of types are supported */
  switch( flags ) {
    case T_LONG | T_DOUBLE: return FPT_LONG_DOUBLE;
    case T_DOUBLE         : return FPT_DOUBLE;
    case T_FLOAT          : return FPT_FLOAT;
  }

  return FPT_UNKNOWN;
}

/*******************************************************************************
*
*   ROUTINE: StoreFloatSV
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jun 2003
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

#ifdef CBC_HAVE_IEEE_FP

#define STORE_FLOAT( ftype )                                                   \
        do {                                                                   \
          union {                                                              \
            ftype f;                                                           \
            u_8   c[sizeof(ftype)];                                            \
          } _u;                                                                \
          int _i;                                                              \
          u_8 *_p = (u_8 *) PACK->bufptr;                                      \
          _u.f = (ftype) SvNV( sv );                                           \
          if( THIS->as.bo == NATIVE_BYTEORDER ) {                              \
            for( _i = 0; _i < sizeof(ftype); _i++ )                            \
              *_p++ = _u.c[_i];                                                \
          }                                                                    \
          else { /* swap */                                                    \
            for( _i = sizeof(ftype)-1; _i >= 0; _i-- )                         \
              *_p++ = _u.c[_i];                                                \
          }                                                                    \
        } while(0)

#else /* ! CBC_HAVE_IEEE_FP */

#define STORE_FLOAT( ftype )                                                   \
        do {                                                                   \
          if( size == sizeof( ftype ) ) {                                      \
            u_8 *_p = (u_8 *) PACK->bufptr;                                    \
            ftype _v = (ftype) SvNV( sv );                                     \
            Copy( &_v, _p, 1, ftype );                                         \
          }                                                                    \
          else                                                                 \
            goto non_native;                                                   \
        } while(0)

#endif /* CBC_HAVE_IEEE_FP */

static void StoreFloatSV( pPACKARGS, unsigned size, u_32 flags, SV *sv )
{
  FPType type = GetFPType( flags );

  if( type == FPT_UNKNOWN ) {
    SV *str = NULL;
    GetBasicTypeSpecString( aTHX_ &str, flags );
    WARN((aTHX_ "Unsupported floating point type '%s' in pack", SvPV_nolen( str )));
    SvREFCNT_dec( str );
    goto finish;
  }

#ifdef CBC_HAVE_IEEE_FP

  if( size == sizeof(float) )
    STORE_FLOAT( float );
  else if( size == sizeof(double) )
    STORE_FLOAT( double );
#ifdef HAVE_LONG_DOUBLE
  else if( size == sizeof(long double) )
    STORE_FLOAT( long double );
#endif
  else
    WARN((aTHX_ "Cannot pack %d byte floating point values", size));

#else /* ! CBC_HAVE_IEEE_FP */

  if( THIS->as.bo != NATIVE_BYTEORDER )
    goto non_native;

  switch( type ) {
    case FPT_FLOAT          : STORE_FLOAT( float );       break;
    case FPT_DOUBLE         : STORE_FLOAT( double );      break;
#ifdef HAVE_LONG_DOUBLE
    case FPT_LONG_DOUBLE    : STORE_FLOAT( long double ); break;
#endif
    default:
      goto non_native;
  }

  goto finish;

non_native:
  WARN((aTHX_ "Cannot pack non-native floating point values", size));

#endif /* CBC_HAVE_IEEE_FP */

finish:

  return;
}

#undef STORE_FLOAT

/*******************************************************************************
*
*   ROUTINE: FetchFloatSV
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jun 2003
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

#ifdef CBC_HAVE_IEEE_FP

#define FETCH_FLOAT( ftype )                                                   \
        do {                                                                   \
          union {                                                              \
            ftype f;                                                           \
            u_8   c[sizeof(ftype)];                                            \
          } _u;                                                                \
          int _i;                                                              \
          u_8 *_p = (u_8 *) PACK->bufptr;                                      \
          if( THIS->as.bo == NATIVE_BYTEORDER ) {                              \
            for( _i = 0; _i < sizeof(ftype); _i++ )                            \
              _u.c[_i] = *_p++;                                                \
          }                                                                    \
          else { /* swap */                                                    \
            for( _i = sizeof(ftype)-1; _i >= 0; _i-- )                         \
              _u.c[_i] = *_p++;                                                \
          }                                                                    \
          value = (NV) _u.f;                                                   \
        } while(0)

#else /* ! CBC_HAVE_IEEE_FP */

#define FETCH_FLOAT( ftype )                                                   \
        do {                                                                   \
          if( size == sizeof( ftype ) ) {                                      \
            u_8 *_p = (u_8 *) PACK->bufptr;                                    \
            ftype _v;                                                          \
            Copy( _p, &_v, 1, ftype );                                         \
            value = (NV) _v;                                                   \
          }                                                                    \
          else                                                                 \
            goto non_native;                                                   \
        } while(0)

#endif /* CBC_HAVE_IEEE_FP */

static SV *FetchFloatSV( pPACKARGS, unsigned size, u_32 flags )
{
  FPType type = GetFPType( flags );
  NV value = 0.0;

  if( type == FPT_UNKNOWN ) {
    SV *str = NULL;
    GetBasicTypeSpecString( aTHX_ &str, flags );
    WARN((aTHX_ "Unsupported floating point type '%s' in unpack", SvPV_nolen( str )));
    SvREFCNT_dec( str );
    goto finish;
  }

#ifdef CBC_HAVE_IEEE_FP

  if( size == sizeof(float) )
    FETCH_FLOAT( float );
  else if( size == sizeof(double) )
    FETCH_FLOAT( double );
#ifdef HAVE_LONG_DOUBLE
  else if( size == sizeof(long double) )
    FETCH_FLOAT( long double );
#endif
  else
    WARN((aTHX_ "Cannot unpack %d byte floating point values", size));

#else /* ! CBC_HAVE_IEEE_FP */

  if( THIS->as.bo != NATIVE_BYTEORDER )
    goto non_native;

  switch( type ) {
    case FPT_FLOAT          : FETCH_FLOAT( float );       break;
    case FPT_DOUBLE         : FETCH_FLOAT( double );      break;
#ifdef HAVE_LONG_DOUBLE
    case FPT_LONG_DOUBLE    : FETCH_FLOAT( long double ); break;
#endif
    default:
      goto non_native;
  }

  goto finish;

non_native:
  WARN((aTHX_ "Cannot unpack non-native floating point values", size));

#endif /* CBC_HAVE_IEEE_FP */

finish:

  return newSVnv( value );
}

#undef FETCH_FLOAT


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

static void StoreIntSV( pPACKARGS, unsigned size, unsigned sign, SV *sv )
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

  store_integer( size, PACK->bufptr, &THIS->as, &iv );
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

static SV *FetchIntSV( pPACKARGS, unsigned size, unsigned sign )
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

  fetch_integer( size, sign, PACK->bufptr, &THIS->as, &iv );

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

static void SetPointer( pPACKARGS, SV *sv )
{
  unsigned size = THIS->cfg.ptr_size ? THIS->cfg.ptr_size : sizeof( void * );

  CT_DEBUG( MAIN, (XSCLASS "::SetPointer( THIS=%p, sv=%p )", THIS, sv) );

  ALIGN_BUFFER( size );

  if( DEFINED( sv ) && ! SvROK( sv ) )
    StoreIntSV( aPACKARGS, size, 0, sv );

  INC_BUFFER( size );
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

static void SetStruct( pPACKARGS, Struct *pStruct, SV *sv, IDList *idl )
{
  StructDeclaration *pStructDecl;
  Declarator        *pDecl;
  char              *bufptr;
  long               pos;
  unsigned           old_align, old_base;

  CT_DEBUG( MAIN, (XSCLASS "::SetStruct( THIS=%p, pStruct=%p, sv=%p, idl=%p )",
            THIS, pStruct, sv, idl) );

  ALIGN_BUFFER( pStruct->align );

  bufptr           = PACK->bufptr;
  pos              = PACK->buf.pos;
  old_align        = PACK->alignment;
  old_base         = PACK->align_base;
  PACK->alignment  = pStruct->pack ? pStruct->pack : THIS->cfg.alignment;
  PACK->align_base = 0;

  if( DEFINED( sv ) ) {
    SV *hash;

    if( SvROK( sv ) && SvTYPE( hash = SvRV(sv) ) == SVt_PVHV ) {
      HV *h = (HV *) hash;

      IDLIST_PUSH( idl, ID );

      LL_foreach( pStructDecl, pStruct->declarations ) {
        if( pStructDecl->declarators ) {
          LL_foreach( pDecl, pStructDecl->declarators ) {
            size_t id_len = strlen(pDecl->identifier);
            SV **e = hv_fetch( h, pDecl->identifier, id_len, 0 );

            IDLIST_SET_ID( idl, pDecl->identifier );

            SetType( aPACKARGS, &pStructDecl->type, pDecl, 0,
                     e ? *e : NULL, idl );

            if( pStruct->tflags & T_UNION ) {
              PACK->bufptr  = bufptr;
              PACK->buf.pos = pos;
              PACK->align_base = 0;
            }
          }
        }
        else {
          TypeSpec *pTS = &pStructDecl->type;

          FOLLOW_AND_CHECK_TSPTR( pTS );

          IDLIST_POP( idl );

          SetStruct( aPACKARGS, (Struct *) pTS->ptr, sv, idl );

          IDLIST_PUSH( idl, ID );

          if( pStruct->tflags & T_UNION ) {
            PACK->bufptr     = bufptr;
            PACK->buf.pos    = pos;
            PACK->align_base = 0;
          }
        }
      }

      IDLIST_POP( idl );
    }
    else
      WARN((aTHX_ "'%s' should be a hash reference", IDListToStr(aTHX_ idl)));
  }

  PACK->alignment  = old_align;
  PACK->align_base = old_base + pStruct->size;
  PACK->bufptr     = bufptr   + pStruct->size;
  PACK->buf.pos    = pos      + pStruct->size;
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

static void SetEnum( pPACKARGS, EnumSpecifier *pEnumSpec, SV *sv )
{
  unsigned size = GET_ENUM_SIZE( pEnumSpec );
  IV value = 0;

  CT_DEBUG( MAIN, (XSCLASS "::SetEnum( THIS=%p, pEnumSpec=%p, sv=%p )",
            THIS, pEnumSpec, sv) );

  /* TODO: add some checks (range, perhaps even value) */

  ALIGN_BUFFER( size );

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
            WARN((aTHX_ "Enumerator value '%s' is unsafe", str));
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
    store_integer( size, PACK->bufptr, &THIS->as, &iv );
  }

  INC_BUFFER( size );
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

static void SetBasicType( pPACKARGS, u_32 flags, SV *sv )
{
  unsigned size;

  CT_DEBUG( MAIN, (XSCLASS "::SetBasicType( THIS=%p, flags=0x%08lX, sv=%p )",
            THIS, (unsigned long) flags, sv) );

  CT_DEBUG( MAIN, ("buffer.pos=%lu, buffer.length=%lu",
            PACK->buf.pos, PACK->buf.length) );

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

  ALIGN_BUFFER( size );

  if( DEFINED( sv ) && ! SvROK( sv ) ) {
    if( flags & (T_DOUBLE | T_FLOAT) )
      StoreFloatSV( aPACKARGS, size, flags, sv );
    else
      StoreIntSV( aPACKARGS, size, (flags & T_UNSIGNED) == 0, sv );
  }

  INC_BUFFER( size );
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

static void SetType( pPACKARGS, TypeSpec *pTS, Declarator *pDecl,
                     int dimension, SV *sv, IDList *idl )
{
  CT_DEBUG( MAIN, (XSCLASS "::SetType( THIS=%p, pTS=%p, pDecl=%p, "
            "dimension=%d, sv=%p, idl=%p )",
            THIS, pTS, pDecl, dimension, sv, idl) );

  if( pDecl && dimension < LL_count( pDecl->array ) ) {
    SV *ary;

    if( DEFINED(sv) && SvROK(sv) && SvTYPE( ary = SvRV(sv) ) == SVt_PVAV ) {
      long i, s = ((Value *) LL_get( pDecl->array, dimension ))->iv;
      AV *a = (AV *) ary;

      IDLIST_PUSH( idl, IX );

      for( i = 0; i < s; ++i ) {
        SV **e = av_fetch( a, i, 0 );

        IDLIST_SET_IX( idl, i );

        SetType( aPACKARGS, pTS, pDecl, dimension+1, e ? *e : NULL, idl );
      }

      IDLIST_POP( idl );
    }
    else {
      unsigned size, align;
      int dim;
      ErrorGTI err;

      if( DEFINED(sv) )
        WARN((aTHX_ "'%s' should be an array reference", IDListToStr(aTHX_ idl)));

      err = get_type_info( &THIS->cfg, pTS, NULL, &size, &align, NULL, NULL );
      if( err != GTI_NO_ERROR )
        CroakGTI( aTHX_ err, IDListToStr(aTHX_ idl), 1 );

      ALIGN_BUFFER( align );

      dim = LL_count( pDecl->array );

      while( dim-- > dimension )
        size *= ((Value *) LL_get( pDecl->array, dim ))->iv;

      INC_BUFFER( size );
    }
  }
  else {
    if( pDecl && pDecl->pointer_flag ) {
      if( DEFINED(sv) && SvROK(sv) )
        WARN((aTHX_ "'%s' should be a scalar value", IDListToStr(aTHX_ idl)));
      SetPointer( aPACKARGS, sv );
    }
    else if( pDecl && pDecl->bitfield_size >= 0 ) {
      /* unsupported */
    }
    else if( pTS->tflags & T_TYPE ) {
      Typedef *pTD = pTS->ptr;
      SetType( aPACKARGS, pTD->pType, pTD->pDecl, 0, sv, idl );
      /* SetTypedef( aPACKARGS, pTS->ptr, sv, idl ); */
    }
    else if( pTS->tflags & (T_STRUCT|T_UNION) ) {
      Struct *pStruct = (Struct *) pTS->ptr;
      if( pStruct->declarations == NULL )
        WARN_UNDEF_STRUCT( pStruct );
      else
        SetStruct( aPACKARGS, pStruct, sv, idl );
    }
    else {
      if( DEFINED(sv) && SvROK(sv) )
        WARN((aTHX_ "'%s' should be a scalar value", IDListToStr(aTHX_ idl)));

      CT_DEBUG( MAIN, ("SET '%s' @ %lu", pDecl ? pDecl->identifier : "", PACK->buf.pos ) );

      if( pTS->tflags & T_ENUM )
        SetEnum( aPACKARGS, pTS->ptr, sv );
      else
        SetBasicType( aPACKARGS, pTS->tflags, sv );
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

static SV *GetPointer( pPACKARGS )
{
  SV *sv;
  unsigned size = THIS->cfg.ptr_size ? THIS->cfg.ptr_size : sizeof( void * );

  CT_DEBUG( MAIN, (XSCLASS "::GetPointer( THIS=%p )", THIS) );

  ALIGN_BUFFER( size );
  CHECK_BUFFER( size );

  sv = FetchIntSV( aPACKARGS, size, 0 );

  INC_BUFFER( size );

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

static SV *GetStruct( pPACKARGS, Struct *pStruct, HV *hash )
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

  ALIGN_BUFFER( pStruct->align );

  bufptr           = PACK->bufptr;
  pos              = PACK->buf.pos;
  old_align        = PACK->alignment;
  old_base         = PACK->align_base;
  PACK->alignment  = pStruct->pack ? pStruct->pack : THIS->cfg.alignment;
  PACK->align_base = 0;

  LL_foreach( pStructDecl, pStruct->declarations ) {
    if( pStructDecl->declarators ) {
      LL_foreach( pDecl, pStructDecl->declarators ) {
        U32 klen = strlen(pDecl->identifier);

        if( hv_exists( h, pDecl->identifier, klen ) ) {
          WARN((aTHX_ "Member '%s' used more than once "
                      "in %s%s%s defined in %s(%d)",
                pDecl->identifier,
                pStruct->tflags & T_UNION ? "union" : "struct",
                pStruct->identifier[0] != '\0' ? " " : "",
                pStruct->identifier[0] != '\0' ? pStruct->identifier : "",
                pStruct->context.pFI->name, pStruct->context.line));
        }
        else {
          SV *value = GetType( aPACKARGS, &pStructDecl->type, pDecl, 0 );
          if( hv_store( h, pDecl->identifier, klen, value, 0 ) == NULL )
            SvREFCNT_dec( value );
        }

        if( pStruct->tflags & T_UNION ) {
          PACK->bufptr     = bufptr;
          PACK->buf.pos    = pos;
          PACK->align_base = 0;
        }
      }
    }
    else {
      TypeSpec *pTS = &pStructDecl->type;

      FOLLOW_AND_CHECK_TSPTR( pTS );

      (void) GetStruct( aPACKARGS, (Struct *) pTS->ptr, h );

      if( pStruct->tflags & T_UNION ) {
        PACK->bufptr     = bufptr;
        PACK->buf.pos    = pos;
        PACK->align_base = 0;
      }
    }
  }

  PACK->alignment  = old_align;
  PACK->align_base = old_base + pStruct->size;
  PACK->bufptr     = bufptr   + pStruct->size;
  PACK->buf.pos    = pos      + pStruct->size;

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

static SV *GetEnum( pPACKARGS, EnumSpecifier *pEnumSpec )
{
  Enumerator *pEnum;
  unsigned size = GET_ENUM_SIZE( pEnumSpec );
  IV value;
  SV *sv;

  CT_DEBUG( MAIN, (XSCLASS "::GetEnum( THIS=%p, pEnumSpec=%p )", THIS, pEnumSpec) );

  ALIGN_BUFFER( size );
  CHECK_BUFFER( size );

  if( pEnumSpec->tflags & T_SIGNED ) { /* TODO: handle signed/unsigned correctly */
    IntValue iv;
    iv.string = NULL;
    fetch_integer( size, 1, PACK->bufptr, &THIS->as, &iv );
#ifdef NATIVE_64_BIT_INTEGER
    value = iv.value.s;
#else
    value = (i_32) iv.value.s.l;
#endif
  }
  else {
    IntValue iv;
    iv.string = NULL;
    fetch_integer( size, 0, PACK->bufptr, &THIS->as, &iv );
#ifdef NATIVE_64_BIT_INTEGER
    value = iv.value.u;
#else
    value = iv.value.u.l;
#endif
  }

  INC_BUFFER( size );

  if( THIS->enumType == ET_INTEGER )
    return newSViv( value );

  LL_foreach( pEnum, pEnumSpec->enumerators )
    if( pEnum->value.iv == value )
      break;

  if( pEnumSpec->tflags & T_UNSAFE_VAL ) {
    if( pEnumSpec->identifier[0] != '\0' )
      WARN((aTHX_ "Enumeration '%s' contains unsafe values", pEnumSpec->identifier));
    else
      WARN((aTHX_ "Enumeration contains unsafe values"));
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

static SV *GetBasicType( pPACKARGS, u_32 flags )
{
  unsigned size;
  SV *sv;

  CT_DEBUG( MAIN, (XSCLASS "::GetBasicType( THIS=%p, flags=0x%08lX )",
                   THIS, (unsigned long) flags) );

  CT_DEBUG( MAIN, ("buffer.pos=%lu, buffer.length=%lu",
                   PACK->buf.pos, PACK->buf.length) );

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

  ALIGN_BUFFER( size );
  CHECK_BUFFER( size );

  if( flags & (T_FLOAT | T_DOUBLE) )
    sv = FetchFloatSV( aPACKARGS, size, flags );
  else
    sv = FetchIntSV( aPACKARGS, size, (flags & T_UNSIGNED) == 0 );

  INC_BUFFER( size );

  return sv;
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

static SV *GetType( pPACKARGS, TypeSpec *pTS, Declarator *pDecl, int dimension )
{
  CT_DEBUG( MAIN, (XSCLASS "::GetType( THIS=%p, pTS=%p, pDecl=%p, dimension=%d )",
                   THIS, pTS, pDecl, dimension) );

  if( pDecl && dimension < LL_count( pDecl->array ) ) {
    AV *a = newAV();
    long i, s = ((Value *) LL_get( pDecl->array, dimension ))->iv;

    av_extend( a, s-1 );

    for( i=0; i<s; ++i )
      av_store( a, i, GetType( aPACKARGS, pTS, pDecl, dimension+1 ) );

    return newRV_noinc( (SV *) a );
  }
  else {
    if( pDecl && pDecl->pointer_flag )       return GetPointer( aPACKARGS );
    if( pDecl && pDecl->bitfield_size >= 0 ) return newSV(0);  /* unsupported */
    if( pTS->tflags & T_TYPE ) {
      Typedef *pTD = pTS->ptr;
      return GetType( aPACKARGS, pTD->pType, pTD->pDecl, 0 );
    }
    if( pTS->tflags & (T_STRUCT|T_UNION) ) {
      Struct *pStruct = pTS->ptr;
      if( pStruct->declarations == NULL ) {
        WARN_UNDEF_STRUCT( pStruct );
        return newSV(0);
      }
      return GetStruct( aPACKARGS, pTS->ptr, NULL );
    }

    CT_DEBUG( MAIN, ("GET '%s' @ %lu", pDecl ? pDecl->identifier : "", PACK->buf.pos ) );

    if( pTS->tflags & T_ENUM )             return GetEnum( aPACKARGS, pTS->ptr );

    return GetBasicType( aPACKARGS, pTS->tflags );
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

static void GetBasicTypeSpecString( pTHX_ SV **sv, u_32 flags )
{
  struct { u_32 flag; const char *str; } *pSpec, spec[] = {
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
        *sv = newSVpv( CONST_CHAR(pSpec->str), 0 );

      first = 0;
    }
  }
}

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

static void AddIndent( pTHX_ SV *s, int level )
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

  sv_catpvn( s, CONST_CHAR(tab), level );
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

static void CheckDefineType( pTHX_ SV *str, TypeSpec *pTS )
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
      AddEnumSpecString( aTHX_ str, pES );
  }
  else if( flags & (T_STRUCT|T_UNION) ) {
    Struct *pStruct = (Struct *) pTS->ptr;

    if( pStruct && (pStruct->tflags & T_ALREADY_DUMPED) == 0 )
      AddStructSpecString( aTHX_ str, pStruct );
  }
}

#define INDENT                           \
        do {                             \
          if( level > 0 )                \
            AddIndent( aTHX_ s, level ); \
        } while(0)

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

static void AddTypeSpecStringRec( pTHX_ SV *str, SV *s, TypeSpec *pTS, int level, U32 *pFlags )
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
        AddEnumSpecStringRec( aTHX_ str, s, pES, level, pFlags );
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
        AddStructSpecStringRec( aTHX_ str, s, pStruct, level, pFlags );
    }
  }
  else {
    CHECK_SET_KEYWORD;
    GetBasicTypeSpecString( aTHX_ &s, flags );
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

static void AddEnumSpecStringRec( pTHX_ SV *str, SV *s, EnumSpecifier *pES,
                                  int level, U32 *pFlags )
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

static void AddStructSpecStringRec( pTHX_ SV *str, SV *s, Struct *pStruct,
                                    int level, U32 *pFlags )
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

      AddTypeSpecStringRec( aTHX_ str, s, &pStructDecl->type, level+1, &flags );

      flags &= ~F_DONT_EXPAND;

      if( flags & F_NEWLINE )
        AddIndent( aTHX_ s, level+1 );
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
        CheckDefineType( aTHX_ str, &pStructDecl->type );
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

static void AddTypedefListDeclString( pTHX_ SV *str, TypedefList *pTDL )
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

static void AddTypedefListSpecString( pTHX_ SV *str, TypedefList *pTDL )
{
  SV *s = newSVpv( "typedef", 0 );
  U32 flags = F_KEYWORD;

  CT_DEBUG( MAIN, (XSCLASS "::AddTypedefListSpecString( pTDL=%p )", pTDL) );

  AddTypeSpecStringRec( aTHX_ str, s, &pTDL->type, 0, &flags );

  if( (flags & F_NEWLINE) == 0 )
    sv_catpv( s, " " );

  AddTypedefListDeclString( aTHX_ s, pTDL );

  sv_catpv( s, ";\n" );
  sv_catsv( str, s );

  SvREFCNT_dec( s );
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

static void AddEnumSpecString( pTHX_ SV *str, EnumSpecifier *pES )
{
  SV *s = newSVpvn( "", 0 );

  CT_DEBUG( MAIN, (XSCLASS "::AddEnumSpecString( pES=%p )", pES) );

  AddEnumSpecStringRec( aTHX_ str, s, pES, 0, NULL );
  sv_catpv( s, ";\n" );
  sv_catsv( str, s );

  SvREFCNT_dec( s );
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

static void AddStructSpecString( pTHX_ SV *str, Struct *pStruct )
{
  SV *s = newSVpvn( "", 0 );

  CT_DEBUG( MAIN, (XSCLASS "::AddStructSpecString( pStruct=%p )", pStruct) );

  AddStructSpecStringRec( aTHX_ str, s, pStruct, 0, NULL );
  sv_catpv( s, ";\n" );
  sv_catsv( str, s );

  SvREFCNT_dec( s );
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

static SV *GetParsedDefinitionsString( pTHX_ CParseInfo *pCPI )
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
      AddTypedefListSpecString( aTHX_ s, pTDL );
    }
    else {
      const char *what = NULL, *ident;

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
        AddTypedefListDeclString( aTHX_ s, pTDL );
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
        AddTypedefListSpecString( aTHX_ s, pTDL );
        sv_catpv( s, "\n" );
      }

  /* defined enums */

  LL_foreach( pES, pCPI->enums )
    if(   pES->enumerators
       && pES->identifier[0] != '\0'
       && (pES->tflags & (T_ALREADY_DUMPED)) == 0
      ) {
      if( !fEnum ) {
        sv_catpv( s, "\n/* defined enums */\n\n" );
        fEnum = 1;
      }
      AddEnumSpecString( aTHX_ s, pES );
      sv_catpv( s, "\n" );
    }

  /* defined structs and unions */

  LL_foreach( pStruct, pCPI->structs )
    if(   pStruct->declarations
       && pStruct->identifier[0] != '\0'
       && (pStruct->tflags & (T_ALREADY_DUMPED)) == 0
      ) {
      if( !fStruct ) {
        sv_catpv( s, "\n/* defined structs and unions */\n\n" );
        fStruct = 1;
      }
      AddStructSpecString( aTHX_ s, pStruct );
      sv_catpv( s, "\n" );
    }

  /* undefined enums */

  LL_foreach( pES, pCPI->enums ) {
    if( (pES->tflags & T_ALREADY_DUMPED) == 0 ) {
      if(   pES->enumerators
         || (   pES->identifier[0] != '\0'
             && (pES->tflags & T_HASTYPEDEF) == 0
            )
        ) {
        if( !fUndefEnum ) {
          sv_catpv( s, "\n/* undefined enums */\n\n" );
          fUndefEnum = 1;
        }
        AddEnumSpecString( aTHX_ s, pES );
        sv_catpv( s, "\n" );
      }
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
        AddStructSpecString( aTHX_ s, pStruct );
        sv_catpv( s, "\n" );
      }
    }

    pStruct->tflags &= ~T_ALREADY_DUMPED;
  }

  return s;
}

#define INDENT                                \
        do {                                  \
          if( level > 0 )                     \
            AddIndent( aTHX_ string, level ); \
        } while(0)

#define APPEND_COMMA                          \
        do {                                  \
          if( first )                         \
            first = 0;                        \
          else                                \
            sv_catpv( string, ",\n" );        \
        } while(0)

#define ENTER_LEVEL                           \
        do {                                  \
          INDENT;                             \
          sv_catpv( string, "{\n" );          \
        } while(0)

#define LEAVE_LEVEL                           \
        do {                                  \
          sv_catpv( string, "\n" );           \
          INDENT;                             \
          sv_catpv( string, "}" );            \
        } while(0)

/*******************************************************************************
*
*   ROUTINE: GetInitStrStruct
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jun 2003
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

static void GetInitStrStruct( pTHX_ CBC *THIS, Struct *pStruct, SV *init,
                              IDList *idl, int level, SV *string )
{
  StructDeclaration *pStructDecl;
  Declarator        *pDecl;
  HV                *hash = NULL;
  int                first = 1;

  CT_DEBUG( MAIN, (XSCLASS "::GetInitStrStruct( THIS=%p, pStruct=%p, "
            "init=%p, idl=%p, level=%d, string=%p )",
            THIS, pStruct, init, idl, level, string) );

  if( DEFINED(init) ) {
    SV *h;
    if( SvROK(init) && SvTYPE( h = SvRV(init) ) == SVt_PVHV )
      hash = (HV *) h;
    else
      WARN((aTHX_ "'%s' should be a hash reference", IDListToStr(aTHX_ idl)));
  }

  ENTER_LEVEL;
  IDLIST_PUSH( idl, ID );

  LL_foreach( pStructDecl, pStruct->declarations ) {
    if( pStructDecl->declarators ) {
      LL_foreach( pDecl, pStructDecl->declarators ) {
        size_t id_len;
        SV **e;

        /* skip unnamed bitfield members right here */
        if( pDecl->bitfield_size >= 0 && pDecl->identifier[0] == '\0' )
          continue;

        id_len = strlen(pDecl->identifier);
        e = hash ? hv_fetch( hash, pDecl->identifier, id_len, 0 ) : NULL;

        IDLIST_SET_ID( idl, pDecl->identifier );
        APPEND_COMMA;

        GetInitStrType( aTHX_ THIS, &pStructDecl->type, pDecl, 0,
                        e ? *e : NULL, idl, level+1, string );

        /* only initialize first union member */
        if( pStruct->tflags & T_UNION )
          goto handle_end;
      }
    }
    else {
      TypeSpec *pTS = &pStructDecl->type;
      FOLLOW_AND_CHECK_TSPTR( pTS );
      APPEND_COMMA;
      IDLIST_POP( idl );
      GetInitStrStruct( aTHX_ THIS, (Struct *) pTS->ptr,
                        init, idl, level+1, string );
      IDLIST_PUSH( idl, ID );
    }
  }

handle_end:
  IDLIST_POP( idl );
  LEAVE_LEVEL;
}

/*******************************************************************************
*
*   ROUTINE: GetInitStrType
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jun 2003
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

static void GetInitStrType( pTHX_ CBC *THIS, TypeSpec *pTS, Declarator *pDecl,
                            int dimension, SV *init, IDList *idl,
                            int level, SV *string )
{
  CT_DEBUG( MAIN, (XSCLASS "::GetInitStrType( THIS=%p, pTS=%p, pDecl=%p, "
            "dimension=%d, init=%p, idl=%p, level=%d, string=%p )",
            THIS, pTS, pDecl, dimension, init, idl, level, string) );

  if( pDecl && dimension < LL_count( pDecl->array ) ) {
    AV *ary = NULL;
    long i, s = ((Value *) LL_get( pDecl->array, dimension ))->iv;
    int first = 1;

    if( DEFINED(init) ) {
      SV *sv;
      if( SvROK(init) && SvTYPE( sv = SvRV(init) ) == SVt_PVAV )
        ary = (AV *) sv;
      else
        WARN((aTHX_ "'%s' should be an array reference", IDListToStr(aTHX_ idl)));
    }

    ENTER_LEVEL;
    IDLIST_PUSH( idl, IX );

    for( i = 0; i < s; ++i ) {
      SV **e = ary ? av_fetch( ary, i, 0 ) : NULL;

      IDLIST_SET_IX( idl, i );
      APPEND_COMMA;

      GetInitStrType( aTHX_ THIS, pTS, pDecl, dimension+1,
                      e ? *e : NULL, idl, level+1, string );
    }

    IDLIST_POP( idl );
    LEAVE_LEVEL;
  }
  else {
    if( pDecl && pDecl->pointer_flag )
      goto handle_basic;
    else if( pTS->tflags & T_TYPE ) {
      Typedef *pTD = (Typedef *) pTS->ptr;
      GetInitStrType( aTHX_ THIS, pTD->pType, pTD->pDecl, 0,
                      init, idl, level, string );
    }
    else if( pTS->tflags & (T_STRUCT|T_UNION) ) {
      Struct *pStruct = pTS->ptr;
      if( pStruct->declarations == NULL )
        WARN_UNDEF_STRUCT( pStruct );
      GetInitStrStruct( aTHX_ THIS, pStruct, init, idl, level, string );
    }
    else {
handle_basic:
      INDENT;
      if( DEFINED(init) ) {
        if( SvROK(init) )
          WARN((aTHX_ "'%s' should be a scalar value", IDListToStr(aTHX_ idl)));
        sv_catsv( string, init );
      }
      else
        sv_catpvn( string, "0", 1 );
    }
  }
}

#undef INDENT
#undef APPEND_COMMA
#undef ENTER_LEVEL
#undef LEAVE_LEVEL

/*******************************************************************************
*
*   ROUTINE: GetInitializerString
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jun 2003
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

static SV *GetInitializerString( pTHX_ CBC *THIS, MemberInfo *pMI, SV *init,
                                 const char *name )
{
  SV *string = newSVpvn( "", 0 );
  IDList idl;

  IDLIST_INIT( &idl );
  IDLIST_PUSH( &idl, ID );
  IDLIST_SET_ID( &idl, name );

  GetInitStrType( aTHX_ THIS, &pMI->type, pMI->pDecl, pMI->level,
                  init, &idl, 0, string );

  IDLIST_FREE( &idl );

  return string;
}

/*******************************************************************************
*
*   ROUTINE: GetAMSStruct
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jul 2003
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

static void GetAMSStruct( pTHX_ Struct *pStruct, SV *name, int level,
                          AMSInfo *info )
{
  StructDeclaration *pStructDecl;
  Declarator        *pDecl;
  STRLEN             len;

  CT_DEBUG( MAIN, (XSCLASS "::GetAMSStruct( pStruct=%p, name='%s', level=%d, "
            "info=%p )", pStruct, name ? SvPV_nolen(name) : "", level, info) );

  if( name ) {
    len = SvCUR( name );
    sv_catpvn_nomg( name, ".", 1 );
  }

  LL_foreach( pStructDecl, pStruct->declarations ) {
    if( pStructDecl->declarators ) {
      LL_foreach( pDecl, pStructDecl->declarators ) {
        /* skip unnamed bitfield members right here */
        if( pDecl->bitfield_size >= 0 && pDecl->identifier[0] == '\0' )
          continue;

        if( name ) {
          SvCUR_set( name, len+1 );
          sv_catpvn_nomg( name, pDecl->identifier, strlen(pDecl->identifier) );
        }

        GetAMSType( aTHX_ &pStructDecl->type, pDecl, 0, name, level+1, info );
      }
    }
    else {
      TypeSpec *pTS = &pStructDecl->type;
      FOLLOW_AND_CHECK_TSPTR( pTS );
      if( name )
        SvCUR_set( name, len );
      GetAMSStruct( aTHX_ (Struct *) pTS->ptr, name, level+1, info );
    }
  }

  if( name )
    SvCUR_set( name, len );
}

/*******************************************************************************
*
*   ROUTINE: GetAMSType
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jul 2003
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

static void GetAMSType( pTHX_ TypeSpec *pTS, Declarator *pDecl, int dimension,
                        SV *name, int level, AMSInfo *info )
{
  CT_DEBUG( MAIN, (XSCLASS "::GetAMSType( pTS=%p, pDecl=%p, dimension=%d, "
            "name='%s', level=%d, info=%p )", pTS, pDecl, dimension,
            name ? SvPV_nolen(name) : "", level, info) );

  if( pDecl && dimension < LL_count( pDecl->array ) ) {
    long i, ix, s = ((Value *) LL_get( pDecl->array, dimension ))->iv;
    STRLEN len;
    char ixstr[MAX_IXSTR+1];
    int  ixlen;

    if( name ) {
      len = SvCUR( name );
      sv_catpvn_nomg( name, "[", 1 );
      ixstr[MAX_IXSTR-1] = ']';
      ixstr[MAX_IXSTR]   = '\0';
    }

    for( i = 0; i < s; ++i ) {
      if( name ) {
        SvCUR_set( name, len+1 );
        for( ix=i, ixlen=2; ixlen < MAX_IXSTR; ix /= 10, ixlen++ ) {
          ixstr[MAX_IXSTR-ixlen] = (char)('0'+(ix%10));
          if( ix < 10 ) break;
        }
        sv_catpvn_nomg( name, ixstr+MAX_IXSTR-ixlen, ixlen );
      }

      GetAMSType( aTHX_ pTS, pDecl, dimension+1, name, level+1, info );
    }

    if( name )
      SvCUR_set( name, len );
  }
  else {
    if( pDecl && pDecl->pointer_flag )
      goto handle_basic;
    else if( pTS->tflags & T_TYPE ) {
      Typedef *pTD = (Typedef *) pTS->ptr;
      GetAMSType( aTHX_ pTD->pType, pTD->pDecl, 0, name, level, info );
    }
    else if( pTS->tflags & (T_STRUCT|T_UNION) ) {
      Struct *pStruct = pTS->ptr;
      if( pStruct->declarations == NULL )
        WARN_UNDEF_STRUCT( pStruct );
      GetAMSStruct( aTHX_ pStruct, name, level, info );
    }
    else {
handle_basic:
      if( name )
        LL_push( info->list, newSVsv( name ) );
      else
        info->count++;
    }
  }
}

/*******************************************************************************
*
*   ROUTINE: GetAllMemberStrings
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Jul 2003
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

static int GetAllMemberStrings( pTHX_ MemberInfo *pMI, LinkedList list )
{
  AMSInfo info;
  if( list )
    info.list = list;
  else
    info.count = 0;

  GetAMSType( aTHX_ &pMI->type, pMI->pDecl, pMI->level,
              list ? sv_2mortal(newSVpvn("", 0)) : NULL, 0, &info );

  return list ? LL_count( list ) : info.count;
}

/*******************************************************************************
*
*   ROUTINE: GetTypeSpecDef
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

static SV *GetTypeSpecDef( pTHX_ TypeSpec *pTSpec )
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
        return GetEnumSpecDef( aTHX_ pEnumSpec );
    }
    else {
      return NEW_SV_PV_CONST("enum <NULL>");
    }
  }

  if( flags & (T_STRUCT|T_UNION) ) {
    Struct *pStruct = (Struct *) pTSpec->ptr;
    const char *type = flags & T_UNION ? "union" : "struct";

    if( pStruct ) {
      if( pStruct->identifier[0] )
        return newSVpvf( "%s %s", type, pStruct->identifier );
      else
        return GetStructSpecDef( aTHX_ pStruct );
    }
    else {
      return newSVpvf( "%s <NULL>", type );
    }
  }

  {
    SV *sv = NULL;

    GetBasicTypeSpecString( aTHX_ &sv, flags );

    return sv ? sv : NEW_SV_PV_CONST("<NULL>");
  }
}

/*******************************************************************************
*
*   ROUTINE: GetTypedefDef
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

static SV *GetTypedefDef( pTHX_ Typedef *pTypedef )
{
  Declarator *pDecl = pTypedef->pDecl;
  Value *pValue;

  HV *hv = newHV();
  SV *sv = newSVpvf( "%s%s", pDecl->pointer_flag ? "*" : "",
                             pDecl->identifier );

  LL_foreach( pValue, pDecl->array )
    sv_catpvf( sv, "[%ld]", pValue->iv );

  HV_STORE_CONST( hv, "declarator", sv );
  HV_STORE_CONST( hv, "type", GetTypeSpecDef( aTHX_ pTypedef->pType ) );

  return newRV_noinc( (SV *) hv );
}

/*******************************************************************************
*
*   ROUTINE: GetEnumeratorsDef
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

static SV *GetEnumeratorsDef( pTHX_ LinkedList enumerators )
{
  Enumerator *pEnum;
  HV *hv = newHV();

  LL_foreach( pEnum, enumerators ) {
    SV *val = newSViv( pEnum->value.iv );
    if( hv_store( hv, pEnum->identifier, strlen( pEnum->identifier ),
                  val, 0 ) == NULL )
      SvREFCNT_dec( val );
  }

  return newRV_noinc( (SV *) hv );
}

/*******************************************************************************
*
*   ROUTINE: GetEnumSpecDef
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

static SV *GetEnumSpecDef( pTHX_ EnumSpecifier *pEnumSpec )
{
  HV *hv = newHV();

  if( pEnumSpec->identifier[0] ) {
    HV_STORE_CONST( hv, "identifier", newSVpv( pEnumSpec->identifier, 0 ) );
  }

  if( pEnumSpec->enumerators ) {
    HV_STORE_CONST( hv, "sign", newSViv( pEnumSpec->tflags & T_SIGNED ? 1 : 0 ) );
    HV_STORE_CONST( hv, "enumerators", GetEnumeratorsDef( aTHX_ pEnumSpec->enumerators ) );
  }

  HV_STORE_CONST( hv, "context", newSVpvf( "%s(%lu)", pEnumSpec->context.pFI->name,
                                                      pEnumSpec->context.line ) );

  return newRV_noinc( (SV *) hv );
}

/*******************************************************************************
*
*   ROUTINE: GetDeclaratorsDef
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

static SV *GetDeclaratorsDef( pTHX_ LinkedList declarators )
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
*   ROUTINE: GetStructDeclarationsDef
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

static SV *GetStructDeclarationsDef( pTHX_ LinkedList declarations )
{
  StructDeclaration *pStructDecl;
  AV *av = newAV();

  LL_foreach( pStructDecl, declarations ) {
    HV *hv = newHV();

    HV_STORE_CONST( hv, "type", GetTypeSpecDef( aTHX_ &pStructDecl->type ) );

    if( pStructDecl->declarators ) {
      HV_STORE_CONST( hv, "declarators",
                          GetDeclaratorsDef( aTHX_ pStructDecl->declarators ) );
    }

    av_push( av, newRV_noinc( (SV *) hv ) );
  }

  return newRV_noinc( (SV *) av );
}

/*******************************************************************************
*
*   ROUTINE: GetStructSpecDef
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

static SV *GetStructSpecDef( pTHX_ Struct *pStruct )
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
                        GetStructDeclarationsDef( aTHX_ pStruct->declarations ) );
  }

  HV_STORE_CONST( hv, "context", newSVpvf( "%s(%lu)", pStruct->context.pFI->name,
                                                      pStruct->context.line ) );

  return newRV_noinc( (SV *) hv );
}

/*******************************************************************************
*
*   ROUTINE: AppendMemberStringRec
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

static GMSRV AppendMemberStringRec( pTHX_ const TypeSpec *pType,
                                          const Declarator *pDecl,
                                          int offset, SV *sv, GMSInfo *pInfo )
{
  CT_DEBUG( MAIN, ("AppendMemberStringRec( off=%d, sv='%s' )",
                   offset, SvPV_nolen(sv)) );

  if( pDecl && pDecl->identifier[0] != '\0' ) {
    CT_DEBUG( MAIN, ("Appending identifier [%s]", pDecl->identifier) );
    sv_catpvf( sv, ".%s", CONST_CHAR(pDecl->identifier) );
  }

  if( pDecl == NULL && pType->tflags & T_TYPE ) {
    Typedef *pTypedef = (Typedef *) pType->ptr;
    pDecl = pTypedef->pDecl;
    pType = pTypedef->pType;
  }

  if( pDecl != NULL ) {
    if( pDecl->offset > 0 )
      offset -= pDecl->offset;

    for(;;) {
      int index, size;
      Value *pValue;

      if( pDecl->size < 0 )
        fatal( "pDecl->size is not initialized in AppendMemberStringRec()" );

      size = pDecl->size;

      LL_foreach( pValue, pDecl->array ) {
        size /= pValue->iv;
        index = offset/size;
        CT_DEBUG( MAIN, ("Appending array size [%d]", index) );
        sv_catpvf( sv, "[%d]", index );
        offset -= index*size;
      }

      if( pDecl->pointer_flag || (pType->tflags & T_TYPE) == 0 )
        break;

      do {
        Typedef *pTypedef = (Typedef *) pType->ptr;
        pDecl = pTypedef->pDecl;
        pType = pTypedef->pType;
      } while( !pDecl->pointer_flag && pType->tflags & T_TYPE && LL_count( pDecl->array ) == 0 );
    }
  }

  if( (pDecl == NULL || !pDecl->pointer_flag) && pType->tflags & (T_STRUCT|T_UNION) )
    return GetMemberStringRec( aTHX_ pType->ptr, offset, offset, sv, pInfo );

  if( offset > 0 ) {
    CT_DEBUG( MAIN, ("Appending type offset [+%d]", offset) );
    sv_catpvf( sv, "+%d", offset );

    if( pInfo && pInfo->off )
      LL_push( pInfo->off, newSVsv( sv ) );

    return GMS_HIT_OFF;
  }

  if( pInfo && pInfo->hit )
    LL_push( pInfo->hit, newSVsv( sv ) );

  return GMS_HIT;
}

/*******************************************************************************
*
*   ROUTINE: GetMemberStringRec
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

#define GMS_HANDLE_PAD_REGION                                                  \
        do {                                                                   \
          CT_DEBUG( MAIN, ("Padding region found, exiting") );                 \
          sv_catpvf( sv, "+%d", realoffset );                                  \
          if( pInfo && pInfo->pad ) {                                          \
            const char *str;                                                   \
            STRLEN      len;                                                   \
            str = SvPV( sv, len );                                             \
            if( HT_store( pInfo->htpad, str, len, 0, NULL ) )                  \
              LL_push( pInfo->pad, newSVsv( sv ) );                            \
          }                                                                    \
          return GMS_PAD;                                                      \
        } while(0)

#define GMS_HANDLE_BEST_MEMBER                                                 \
        do {                                                                   \
          if( rval > best ) {                                                  \
            CT_DEBUG( MAIN, ("New member [%s] has better ranking (%d) than "   \
                             "old member [%s] (%d)", SvPV_nolen(tmpSV), rval,  \
                             bestSV ? SvPV_nolen(bestSV) : "", best ) );       \
                                                                               \
            best = rval;                                                       \
                                                                               \
            if( bestSV ) {                                                     \
              SV *t;                                                           \
              t      = tmpSV;                                                  \
              tmpSV  = bestSV;                                                 \
              bestSV = t;                                                      \
            }                                                                  \
            else {                                                             \
              bestSV = tmpSV;                                                  \
              tmpSV  = NULL;                                                   \
            }                                                                  \
          }                                                                    \
                                                                               \
          if( best == GMS_HIT && pInfo == NULL ) {                             \
            CT_DEBUG( MAIN, ("Hit struct member without offset") );            \
            goto handle_union_end;                                             \
          }                                                                    \
        } while(0)

static GMSRV GetMemberStringRec( pTHX_ const Struct *pStruct, int offset,
                                 int realoffset, SV *sv, GMSInfo *pInfo )
{
  StructDeclaration *pStructDecl;
  Declarator        *pDecl;
  SV                *tmpSV, *bestSV;
  GMSRV              best;
  int                isUnion;

  CT_DEBUG( MAIN, ("GetMemberStringRec( off=%d, roff=%d, sv='%s' )",
                   offset, realoffset, SvPV_nolen(sv)) );

  if( pStruct->declarations == NULL ) {
    WARN_UNDEF_STRUCT( pStruct );
    return GMS_NONE;
  }

  if( (isUnion = pStruct->tflags & T_UNION) != 0 ) {
    best   = GMS_NONE;
    bestSV = NULL;
    tmpSV  = NULL;
  }

  LL_foreach( pStructDecl, pStruct->declarations ) {
    CT_DEBUG( MAIN, ("Current StructDecl: offset=%d size=%d decl=%p",
                     pStructDecl->offset, pStructDecl->size,
                     pStructDecl->declarators) );

    if( pStructDecl->offset > offset )
      GMS_HANDLE_PAD_REGION;

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
          GMSRV rval;

          if( tmpSV == NULL )
            tmpSV = newSVsv( sv );
          else
            sv_setsv( tmpSV, sv );

          rval = GetMemberStringRec( aTHX_ (Struct *) pTS->ptr, offset,
                                     realoffset, tmpSV, pInfo );

          GMS_HANDLE_BEST_MEMBER;
        }
        else /* not isUnion */ {
          return GetMemberStringRec( aTHX_ (Struct *) pTS->ptr,
                                     offset - pStructDecl->offset,
                                     realoffset, sv, pInfo );
        }
      }
      else {
        LL_foreach( pDecl, pStructDecl->declarators ) {
          CT_DEBUG( MAIN, ("Current Declarator [%s]: offset=%d size=%d",
                           pDecl->identifier, pDecl->offset, pDecl->size) );

          if( pDecl->offset > offset )
            GMS_HANDLE_PAD_REGION;

          if( pDecl->offset <= offset && offset < pDecl->offset+pDecl->size ) {
            CT_DEBUG( MAIN, ("Member possibly within current Declarator [%s] "
                             "( %d <= %d < %d )",
                             pDecl->identifier, pDecl->offset, offset,
                             pDecl->offset+pDecl->size ) );

            if( isUnion ) {
              GMSRV rval;

              if( tmpSV == NULL )
                tmpSV = newSVsv( sv );
              else
                sv_setsv( tmpSV, sv );

              rval = AppendMemberStringRec( aTHX_ &pStructDecl->type, pDecl,
                                                  offset, tmpSV, pInfo );

              GMS_HANDLE_BEST_MEMBER;
            }
            else /* not isUnion */ {
              return AppendMemberStringRec( aTHX_ &pStructDecl->type, pDecl,
                                                  offset, sv, pInfo );
            }
          }
        }
      }
    }
  }

  CT_DEBUG( MAIN, ("End of %s reached", isUnion ? "union" : "struct") );

  if( !isUnion || bestSV == NULL )
    GMS_HANDLE_PAD_REGION;

handle_union_end:

  if( ! isUnion )
    fatal( "not a union!" );

  if( bestSV == NULL )
    fatal( "bestSV not set!" );

  sv_setsv( sv, bestSV );

  SvREFCNT_dec( bestSV );

  if( tmpSV )
    SvREFCNT_dec( tmpSV );

  return best;
}

#undef GMS_HANDLE_PAD_REGION
#undef GMS_HANDLE_BEST_MEMBER

/*******************************************************************************
*
*   ROUTINE: GetMemberString
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Apr 2003
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

static SV *GetMemberString( pTHX_ const MemberInfo *pMI, int offset, GMSInfo *pInfo )
{
  GMSRV rval;
  SV *sv;
  int dim;

  CT_DEBUG( MAIN, ("GetMemberString( off=%d )", offset) );

  if( pInfo )
    pInfo->htpad = HT_new( 4 );

  sv = newSVpvn( "", 0 );

  /* handle array remainder here */
  if(   pMI->pDecl && pMI->pDecl->array
     && pMI->level < (dim = LL_count(pMI->pDecl->array))
    ) {
    int i, index, size = pMI->size;

    for( i = pMI->level; i < dim; ++i ) {
      size /= ((Value *) LL_get( pMI->pDecl->array, i ))->iv;
      index = offset / size;
      sv_catpvf( sv, "[%d]", index );
      offset -= index*size;
    }
  }

  rval = AppendMemberStringRec( aTHX_ &pMI->type, NULL, offset, sv, pInfo );

  if( pInfo )
    HT_destroy( pInfo->htpad, NULL );

  if( rval == GMS_NONE ) {
    SvREFCNT_dec( sv );
    sv = newSV(0);
  }

  return sv_2mortal( sv );
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

#define PROPAGATE_FLAGS( from ) pMIout->flags |= (from) & (T_HASBITFIELD | T_UNSAFE_VAL);

static void GetMember( pTHX_ const MemberInfo *pMI, const char *member,
                             MemberInfo *pMIout, int accept_dotless_member )
{
  const TypeSpec    *pType;
  const char        *c, *ixstr, *dot;
  char              *e, *elem;
  unsigned           size;
  int                level, t_off, inc_c;
  UV                 offset;
  Struct            *pStruct;
  StructDeclaration *pSD;
  Declarator        *pDecl;
  char              *err, errbuf[128];

  enum {
    ST_MEMBER,
    ST_INDEX,
    ST_FINISH_INDEX,
    ST_SEARCH
  }                  state;

  Newz( 0, elem, strlen(member)+1, char );

  pMIout->flags = 0;

  pType = &pMI->type;
  pDecl = pMI->pDecl;

  if( pDecl == NULL && pType->tflags & T_TYPE ) {
    Typedef *pTypedef = (Typedef *) pType->ptr;
    pDecl = pTypedef->pDecl;
    pType = pTypedef->pType;
  }

  err    = NULL;
  c      = member;
  state  = ST_SEARCH;
  offset = 0;
  level  = pMI->level;
  size   = -1;

  if( pDecl ) {
    int i;

    if( pDecl->size < 0 )
      fatal( "pDecl->size is not initialized in GetMember()" );

    size = pDecl->size;

    for( i = 0; i < level; ++i )
      size /= ((Value *) LL_get( pDecl->array, i ))->iv;
  }

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

        t_off = SearchStructMember( pStruct, elem, &pSD, &pDecl );
        pType = &pSD->type;

        if( t_off < 0 ) {
          TRUNC_ELEM;
          (void) sprintf( err = errbuf, "Cannot find struct member '%s'", elem );
          goto error;
        }

        if( pDecl->size < 0 )
          fatal( "pDecl->size is not initialized in GetMember()" );

        size    = pDecl->size;
        offset += t_off;
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

          if( size < 0 )
            fatal( "size is not initialized in GetMember()" );

          size   /= dim;
          offset += index * size;
          level++;
        }

        state = ST_SEARCH;
        break;

      case ST_SEARCH:
        CT_DEBUG( MAIN, ("SEARCH: level=%d, dim=%d", level, pDecl ? LL_count( pDecl->array ) : 0) );

        PROPAGATE_FLAGS( pType->tflags );

        if( pDecl && !pDecl->pointer_flag && pType->tflags & T_TYPE && level == LL_count( pDecl->array ) ) {
          do {
            Typedef *pTypedef = (Typedef *) pType->ptr;
            pDecl = pTypedef->pDecl;
            pType = pTypedef->pType;
          } while( !pDecl->pointer_flag && pType->tflags & T_TYPE && LL_count( pDecl->array ) == 0 );

          if( pDecl->size < 0 )
            fatal( "pDecl->size is not initialized in GetMember()" );

          size  = pDecl->size;
          level = 0;
        }

        inc_c = 1;
        dot   = "";

        switch( *c ) {
          case '+':
            /*
               Handle the special case that we have a member returned
               by the 'member' method with appended "+digits".
               If this sequence is found at the end of the string,
               simply ignore it.
            */
            if( *(c+1) != '\0' ) {
              const char *p = c+1;
              while( *p && isDIGIT(*p) ) p++;
              if( *p == '\0' ) {
                /* quit */
                offset += atoi( c+1 );
                c = p;
                inc_c = 0;
                break;
              }
            }

            /* fall through */

          default:
            if( !accept_dotless_member || !(isALPHA(*c) || *c == '_') ) {
              (void) sprintf( err = errbuf,
                              "Invalid character '%c' (0x%02X) in "
                              "struct member expression",
                              *c, (int) *c );
              goto error;
            }

            inc_c = 0;
            dot   = ".";

            /* fall through */

          case '.':
            if( pDecl && level < LL_count( pDecl->array ) ) {
              (void) strcpy( elem, c );
              TRUNC_ELEM;
              (void) sprintf( err = errbuf,
                              "Cannot access member '%s%s' of array type",
                              dot, c );
              goto error;
            }
            else if( pDecl && pDecl->pointer_flag ) {
              (void) strcpy( elem, c );
              TRUNC_ELEM;
              (void) sprintf( err = errbuf,
                              "Cannot access member '%s%s' of pointer type",
                              dot, c );
              goto error;
            }
            else if( pType->tflags & (T_STRUCT|T_UNION) ) {
              pStruct = (Struct *) pType->ptr;
              PROPAGATE_FLAGS( pStruct->tflags );
            }
            else {
              (void) strcpy( elem, c );
              TRUNC_ELEM;
              (void) sprintf( err = errbuf,
                              "Cannot access member '%s%s' of non-compound type",
                              dot, c );
              goto error;
            }
            state = ST_MEMBER;
            break;

          case '[':
            if( pDecl == NULL || (level == 0 && LL_count( pDecl->array ) == 0) ) {
              if( elem[0] != '\0' ) {
                TRUNC_ELEM;
                (void) sprintf( err = errbuf,
                                "Cannot use '%s' as an array",
                                elem );
              }
              else {
                err = "Cannot use type as an array";
              }
              goto error;
            }
            state = ST_INDEX;
            break;
        }

        if( inc_c )
          c++;

        break;
    }

    /* only accept dotless members at the very beginning */
    accept_dotless_member = 0;
  }

  if( state != ST_SEARCH ) {
    err = "Incomplete struct member expression";
    goto error;
  }

  error:
  Safefree( elem );

  if( err != NULL )
    Perl_croak(aTHX_ "%s", err);

  if( pMIout ) {
    pMIout->type   = *pType;
    pMIout->pDecl  = pDecl;
    pMIout->level  = level;
    pMIout->offset = offset;
    pMIout->size   = size;
  }
}

#undef TRUNC_ELEM
#undef PROPAGATE_FLAGS

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

  if( ! PARSE_DATA )
    return NULL;

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
*   ROUTINE: GetBasicTypeSpec
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Apr 2002
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

static int GetBasicTypeSpec( const char *name, TypeSpec *pTS )
{
  const char *c;
  u_32 tflags = 0;

  for(;;) {
    success:
    /* skip whitespace */
    while( *name && isSPACE( *name ) ) name++;

    if( *name == '\0' )
      break;

    if( ! isALPHA( *name ) )
      return 0;

    c = name++;

    while( *name && isALPHA( *name ) ) name++;

    if( *name != '\0' && ! isSPACE( *name ) )
      return 0;

#include "t_basic.c"

    unknown:
      return 0;
  }

  if( tflags == 0 )
    return 0;

  if( pTS ) {
    pTS->ptr    = NULL;
    pTS->tflags = tflags;
  }

  return 1;
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

static int GetTypeSpec( CBC *THIS, const char *name, const char **pEOS, TypeSpec *pTS )
{
  void *ptr = GetTypePointer( THIS, name, pEOS );

  if( ptr == NULL ) {
    if( pEOS )
      *pEOS = NULL;

    return GetBasicTypeSpec( name, pTS );
  }

  switch( GET_CTYPE( ptr ) ) {
    case TYP_TYPEDEF:
      pTS->tflags = T_TYPE;
      break;

    case TYP_STRUCT:
      pTS->tflags = ((Struct *) ptr)->tflags;
      break;

    case TYP_ENUM:
      pTS->tflags = T_ENUM;
      break;

    default:
      fatal("GetTypePointer returned an invalid type (%d) in "
            "GetTypeSpec( '%s' )", GET_CTYPE( ptr ), name);
      break;
  }

  pTS->ptr = ptr;

  return 1;
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

static int GetMemberInfo( pTHX_ CBC *THIS, const char *name, MemberInfo *pMI )
{
  const char *member;
  MemberInfo mi;

  if( GetTypeSpec( THIS, name, &member, &mi.type ) == 0 )
    return 0;

  if( pMI ) {
    pMI->flags = 0;

    if( member && *member ) {
      mi.pDecl = NULL;
      mi.level = 0;
      GetMember( aTHX_ &mi, member, pMI, 0 );
    }
    else if( mi.type.ptr == NULL ) {
      ErrorGTI err;
      pMI->type   = mi.type;
      pMI->flags  = 0;
      pMI->level  = 0;
      pMI->offset = 0;
      pMI->pDecl  = NULL;
      err = get_type_info( &THIS->cfg, &mi.type, NULL, &pMI->size,
                           NULL, NULL, &pMI->flags );
      if( err != GTI_NO_ERROR )
        CroakGTI( aTHX_ err, name, 0 );
    }
    else {
      void *ptr = mi.type.ptr;  /* TODO: improve this... */

      switch( GET_CTYPE( ptr ) ) {
        case TYP_TYPEDEF:
          {
            /* TODO: get rid of get_type_info, add flags to size */
            ErrorGTI err;
            err = get_type_info( &THIS->cfg, ((Typedef *) ptr)->pType,
                                 ((Typedef *) ptr)->pDecl, &pMI->size, NULL,
                                 NULL, &pMI->flags );
            if( err != GTI_NO_ERROR )
              CroakGTI( aTHX_ err, name, 0 );
          }
          break;

        case TYP_STRUCT:
          if( ((Struct *) ptr)->declarations == NULL )
            CROAK_UNDEF_STRUCT( (Struct *) ptr );
          pMI->size  = ((Struct *) ptr)->size;
          pMI->flags = ((Struct *) ptr)->tflags & (T_HASBITFIELD | T_UNSAFE_VAL);
          break;

        case TYP_ENUM:
          pMI->size = GET_ENUM_SIZE( (EnumSpecifier *) ptr );
          break;

        default:
          fatal("GetTypeSpec returned an invalid type (%d) in "
                "GetMemberInfo( '%s' )", GET_CTYPE( ptr ), name);
          break;
      }

      pMI->type   = mi.type;
      pMI->pDecl  = NULL;
      pMI->level  = 0;
      pMI->offset = 0;
    }
  }

  return 1;
}

/*******************************************************************************
*
*   ROUTINE: GetTypeNameString
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2003
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

static SV *GetTypeNameString( pTHX_ const MemberInfo *pMI )
{
  SV *sv;

  if( pMI == NULL )
    fatal("GetTypeNameString() called with NULL pointer");

  if( pMI->type.ptr == NULL ) {
    sv = NULL;
    GetBasicTypeSpecString( aTHX_ &sv, pMI->type.tflags );
  }
  else {
    switch( GET_CTYPE( pMI->type.ptr ) ) {
      case TYP_TYPEDEF:
        sv = newSVpv( ((Typedef *) pMI->type.ptr)->pDecl->identifier, 0 );
        break;

      case TYP_STRUCT:
        {
          Struct *pS = (Struct *) pMI->type.ptr;
          sv = pS->identifier[0] == '\0'
             ? newSVpv( pS->tflags & T_STRUCT ? "struct" : "union", 0 )
             : newSVpvf( "%s %s", pS->tflags & T_STRUCT
                         ? "struct" : "union", pS->identifier );
        }
        break;

      case TYP_ENUM:
        {
          EnumSpecifier *pE = (EnumSpecifier *) pMI->type.ptr;
          sv = pE->identifier[0] == '\0'
             ? newSVpv( "enum", 0 )
             : newSVpvf( "enum %s", pE->identifier );
        }
        break;

      default:
        fatal("GetMemberInfo() returned an invalid type (%d) "
              "in GetTypeNameString()", GET_CTYPE( pMI->type.ptr ));
        break;
    }
  }

  if( pMI->pDecl != NULL ) {
    if( pMI->pDecl->bitfield_size >= 0 )
      sv_catpvf( sv, " :%d", pMI->pDecl->bitfield_size );
    else {
      if( pMI->pDecl->pointer_flag )
        sv_catpv( sv, " *" );

      if( pMI->pDecl->array ) {
        int level = pMI->level;
        if( level < LL_count( pMI->pDecl->array ) ) {
          sv_catpv( sv, " " );
          while( level < LL_count( pMI->pDecl->array ) ) {
            sv_catpvf( sv, "[%d]", ((Value *)
                       LL_get( pMI->pDecl->array, level ))->iv );
            level++;
          }
        }
      }
    }
  }

  return sv;
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
static void debug_vprintf( const char *f, va_list *l )
{
  dTHX;
  vfprintf( gs_DB_stream, f, *l );
}

static void debug_printf( const char *f, ... )
{
  dTHX;
  va_list l;
  va_start( l, f );
  vfprintf( gs_DB_stream, f, l );
  va_end( l );
}

static void debug_printf_ctlib( const char *f, ... )
{
  dTHX;
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
static void SetDebugOptions( pTHX_ const char *dbopts )
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
          Perl_croak(aTHX_ "Unknown debug option '%c'", *dbopts);
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
static void SetDebugFile( pTHX_ const char *dbfile )
{
  if( gs_DB_stream != stderr && gs_DB_stream != NULL ) {
    fclose( gs_DB_stream );
    gs_DB_stream = NULL;
  }

  gs_DB_stream = dbfile ? fopen( dbfile, "w" ) : stderr;

  if( gs_DB_stream == NULL ) {
    WARN((aTHX_ "Cannot open '%s', defaulting to stderr", dbfile));
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

static int CheckIntegerOption( pTHX_ const IV *options, int count, SV *sv,
                               IV *value, const char *name )
{
  const IV *opt = options;
  int n = count;

  if( SvROK( sv ) ) {
    Perl_croak(aTHX_ "%s must be an integer value, not a reference", name);
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

    Perl_croak(aTHX_ "%s must be %s, not %" IVdf, name, SvPV_nolen( str ),
                                            IVdf_cast *value);
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

#define GET_STR_OPTION( name, value, sv )                                      \
          GetStringOption( aTHX_ name ## Option, sizeof( name ## Option ) /    \
                           sizeof( StringOption ), value, sv, #name )

static const StringOption *GetStringOption( pTHX_ const StringOption *options,
                                            int count, int value, SV *sv,
                                            const char *name )
{
  char *string = NULL;

  if( sv ) {
    if( SvROK( sv ) )
      Perl_croak(aTHX_ "%s must be a string value, not a reference", name);
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
        sv_catpv( str, CONST_CHAR((options++)->string) );
        if( n < count-2 )
          sv_catpv( str, "', '" );
        else if( n == count-2 )
          sv_catpv( str, "' or '" );
      }

      Perl_croak(aTHX_ "%s must be '%s', not '%s'", name, SvPV_nolen( str ),
                                                    string);
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

static void HandleStringList( pTHX_ const char *option, LinkedList list, SV *sv, SV **rval )
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
            LL_push( list, string_new_fromSV( aTHX_ *pSV ) );
          else
            fatal( "NULL returned by av_fetch() in HandleStringList()" );
        }
      }
      else
        Perl_croak(aTHX_ "%s wants an array reference", option);
    }
    else
      Perl_croak(aTHX_ "%s wants a reference to an array of strings", option);
  }

  if( rval ) {
    AV *av = newAV();

    LL_foreach( str, list )
      av_push( av, newSVpv( CONST_CHAR(str), 0 ) );

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

static void DisabledKeywords( pTHX_ LinkedList *current, SV *sv,
                                    SV **rval, u_32 *pKeywordMask )
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
        Perl_croak(aTHX_ "DisabledKeywords wants an array reference");
    }
    else
      Perl_croak(aTHX_ "DisabledKeywords wants a reference to an array of strings");
  }

  if( rval ) {
    AV *av = newAV();

    LL_foreach( str, *current )
      av_push( av, newSVpv( CONST_CHAR(str), 0 ) );

    *rval = newRV_noinc( (SV *) av );
  }

  return;

unknown:
  LL_destroy( keyword_list, (LLDestroyFunc) string_delete );
  Perl_croak(aTHX_ "Cannot disable unknown keyword '%s'", str);
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
          Perl_croak x;                     \
        } while(0)

static void KeywordMap( pTHX_ HashTable *current, SV *sv, SV **rval )
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
            FAIL_CLEAN((aTHX_ "Cannot use empty string as a keyword"));

          if( *c == '_' || isALPHA(*c) )
            do { c++; } while( *c && ( *c == '_' || isALNUM(*c) ) );

          if( *c != '\0' )
            FAIL_CLEAN((aTHX_ "Cannot use '%s' as a keyword", key));

          value = hv_iterval( hv, entry );

          if( !SvOK(value) )
            pTok = get_skip_token();
          else {
            const char *map;

            if( SvROK( value ) )
              FAIL_CLEAN((aTHX_ "Cannot use a reference as a keyword", key));

            map = SvPV_nolen( value );

            if( (pTok = get_c_keyword_token( map )) == NULL )
              FAIL_CLEAN((aTHX_ "Cannot use '%s' as a keyword", map));
          }

          (void) HT_store( keyword_map, key, (int) keylen, 0, (CKeywordToken *) pTok );
        }

        if( current != NULL ) {
          HT_destroy( *current, NULL ); 
          *current = keyword_map;
        }
      }
      else
        Perl_croak(aTHX_ "KeywordMap wants a hash reference");
    }
    else
      Perl_croak(aTHX_ "KeywordMap wants a hash reference");
  }

  if( rval ) {
    HV *hv = newHV();
    CKeywordToken *tok;
    char *key;
    int keylen;

    HT_reset( *current );
    while( HT_next( *current, &key, &keylen, (void **) &tok ) ) {
      SV *val;
      val = tok->name == NULL ? newSV(0) : newSVpv( CONST_CHAR(tok->name), 0 );
      if( hv_store( hv, key, keylen, val, 0 ) == NULL )
        SvREFCNT_dec( val );
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
  const char *str;
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
          const char *option = SvPV_nolen(opt);                                \
          if( SvROK( opt ) )                                                   \
            Perl_croak(aTHX_ "Option name must be a string, "                  \
                             "not a reference");                               \
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
                Perl_croak(aTHX_ #name " must be a boolean value, "            \
                                       "not a reference");                     \
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
              if( CheckIntegerOption( aTHX_ name ## Option,                    \
                                      sizeof( name ## Option ) / sizeof( IV ), \
                                      sv_val, &val, #name ) ) {                \
                UPDATE( cfg.config, val );                                     \
              }                                                                \
            }                                                                  \
            if( rval )                                                         \
              *rval = newSViv( THIS->cfg.config );                             \
            break;

#define STRLIST_OPTION( name, config )                                         \
          case OPTION_ ## name :                                               \
            HandleStringList( aTHX_ #name, THIS->cfg.config, sv_val, rval );   \
            changes = sv_val != NULL;                                          \
            break;

#define INVALID_OPTION                                                         \
          default:                                                             \
            Perl_croak(aTHX_ "Invalid option '%s'", option);                   \
            break;

static int HandleOption( pTHX_ CBC *THIS, SV *opt, SV *sv_val, SV **rval )
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
      DisabledKeywords( aTHX_ &THIS->cfg.disabled_keywords, sv_val, rval,
                        &THIS->cfg.keywords );
      changes = sv_val != NULL;
    ENDOPT

    OPTION( KeywordMap )
      KeywordMap( aTHX_ &THIS->cfg.keyword_map, sv_val, rval );
      changes = sv_val != NULL;
    ENDOPT

    OPTION( ByteOrder )
      if( sv_val ) {
        const StringOption *pOpt = GET_STR_OPTION( ByteOrder, 0, sv_val );
        UPDATE( as.bo, pOpt->value );
      }
      if( rval ) {
        const StringOption *pOpt = GET_STR_OPTION( ByteOrder, THIS->as.bo, NULL );
        *rval = newSVpv( CONST_CHAR(pOpt->string), 0 );
      }
    ENDOPT

    OPTION( EnumType )
      if( sv_val ) {
        const StringOption *pOpt = GET_STR_OPTION( EnumType, 0, sv_val );
        UPDATE( enumType, pOpt->value );
      }
      if( rval ) {
        const StringOption *pOpt = GET_STR_OPTION( EnumType, THIS->enumType, NULL );
        *rval = newSVpv( CONST_CHAR(pOpt->string), 0 );
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
          HandleStringList( aTHX_ #name, THIS->cfg.config, NULL, &sv );        \
          HV_STORE_CONST( hv, #name, sv );

#define IVAL_OPTION( name, config )                                            \
          sv = newSViv( THIS->cfg.config );                                    \
          HV_STORE_CONST( hv, #name, sv );

#define STRING_OPTION( name, value )                                           \
          sv = newSVpv( CONST_CHAR(GET_STR_OPTION(name, value, NULL)->string), \
                        0 );                                                   \
          HV_STORE_CONST( hv, #name, sv );

static SV *GetConfiguration( pTHX_ CBC *THIS )
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

  KeywordMap( aTHX_ &THIS->cfg.keyword_map, NULL, &sv );
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
  if( PARSE_DATA ) {
    reset_parse_info( &THIS->cpi );
    update_parse_info( &THIS->cpi, &THIS->cfg );
  }
}

/*******************************************************************************
*
*   ROUTINE: CheckAllowedTypes
*
*   WRITTEN BY: Marcus Holland-Moritz             ON: Apr 2003
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

static void CheckAllowedTypes( pTHX_ const MemberInfo *pMI, const char *method,
                               U32 allowedTypes )
{
  const Declarator *pDecl = pMI->pDecl;
  const TypeSpec   *pType = &pMI->type;
  int               level = 0;

  if(   pType->tflags & T_TYPE
     && ( pDecl == NULL || ( ! pDecl->pointer_flag
                            && LL_count( pDecl->array ) == 0 ) )
    ) {
    do {
      const Typedef *pTypedef = (Typedef *) pType->ptr;
      pDecl = pTypedef->pDecl;
      pType = pTypedef->pType;
    } while(  ! pDecl->pointer_flag
             && pType->tflags & T_TYPE
             && LL_count( pDecl->array ) == 0 );
  }
  else
    level = pMI->level;

  if( pDecl != NULL ) {
    if( pDecl->pointer_flag ) {
      if( (allowedTypes & ALLOW_POINTERS) == 0 )
        Perl_croak(aTHX_ "Cannot use %s on a pointer type", method);
      return;
    }

    if( pDecl->array && level < LL_count( pDecl->array ) ) {
      if( (allowedTypes & ALLOW_ARRAYS) == 0 )
        Perl_croak(aTHX_ "Cannot use %s on an array type", method);
      return;
    }
  }

  if( pType->ptr == NULL ) {
    if( (allowedTypes & ALLOW_BASIC_TYPES) == 0 )
      Perl_croak(aTHX_ "Cannot use %s on a basic type", method);
    return;
  }

  if( pType->tflags & T_UNION ) {
    if( (allowedTypes & ALLOW_UNIONS) == 0 )
      Perl_croak(aTHX_ "Cannot use %s on a union", method);
    return;
  }

  if( pType->tflags & T_STRUCT ) {
    if( (allowedTypes & ALLOW_STRUCTS) == 0 )
      Perl_croak(aTHX_ "Cannot use %s on a struct", method);
    return;
  }

  if( pType->tflags & T_ENUM ) {
    if( (allowedTypes & ALLOW_ENUMS) == 0 )
      Perl_croak(aTHX_ "Cannot use %s on an enum", method);
    return;
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

void
CBC::new( ... )
	PREINIT:
		CBC_METHOD( new );

	PPCODE:
		CT_DEBUG_METHOD;

		if( items % 2 == 0 )
		  Perl_croak(aTHX_ "Number of configuration arguments "
		                   "to %s must be even", method);
		else {
		  int i;
		  CBC *THIS;

		  Newz( 0, THIS, 1, CBC );

		  /*
		   *  bless the new object here, because HandleOption()
		   *  may croak and DESTROY would not be called to free
		   *  the memory that has been allocated
		   */
		  ST(0) = sv_newmortal();
		  sv_setref_pv( ST(0), CLASS, (void *) THIS );

		  THIS->as.bo                 = DEFAULT_BYTEORDER;
		  THIS->enumType              = DEFAULT_ENUMTYPE;

		  THIS->cfg.includes          = LL_new();
		  THIS->cfg.defines           = LL_new();
		  THIS->cfg.assertions        = LL_new();
		  THIS->cfg.disabled_keywords = LL_new();
		  THIS->cfg.keyword_map       = HT_new(1);
		  THIS->cfg.ptr_size          = DEFAULT_PTR_SIZE;
		  THIS->cfg.enum_size         = DEFAULT_ENUM_SIZE;
		  THIS->cfg.int_size          = DEFAULT_INT_SIZE;
		  THIS->cfg.short_size        = DEFAULT_SHORT_SIZE;
		  THIS->cfg.long_size         = DEFAULT_LONG_SIZE;
		  THIS->cfg.long_long_size    = DEFAULT_LONG_LONG_SIZE;
		  THIS->cfg.float_size        = DEFAULT_FLOAT_SIZE;
		  THIS->cfg.double_size       = DEFAULT_DOUBLE_SIZE;
		  THIS->cfg.long_double_size  = DEFAULT_LONG_DOUBLE_SIZE;
		  THIS->cfg.alignment         = DEFAULT_ALIGNMENT;
		  THIS->cfg.keywords          = HAS_ALL_KEYWORDS;
		  THIS->cfg.flags             = HAS_CPP_COMMENTS
		                              | HAS_MACRO_VAARGS;

		  if( gs_DisableParser ) {
		    Perl_warn(aTHX_ XSCLASS " parser is DISABLED");
		    THIS->cfg.flags |= DISABLE_PARSER;
		  }

		  init_parse_info( &THIS->cpi );

		  for( i = 1; i < items; i += 2 )
		    (void) HandleOption( aTHX_ THIS, ST(i), ST(i+1), NULL );

		  XSRETURN(1);
		}

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
	PREINIT:
		CBC_METHOD( destroy );

	CODE:
		CT_DEBUG_METHOD;

		free_parse_info( &THIS->cpi );

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
		CBC_METHOD( clone );
		CBC *clone;
		const char *class;

	PPCODE:
		CT_DEBUG_METHOD;

		CHECK_VOID_CONTEXT;

		Newz( 0, clone, 1, CBC );
		Copy( THIS, clone, 1, CBC );

		clone->cfg.includes          = CloneStringList( THIS->cfg.includes );
		clone->cfg.defines           = CloneStringList( THIS->cfg.defines );
		clone->cfg.assertions        = CloneStringList( THIS->cfg.assertions );
		clone->cfg.disabled_keywords = CloneStringList( THIS->cfg.disabled_keywords );

		clone->cfg.keyword_map = HT_clone( THIS->cfg.keyword_map, NULL );

		init_parse_info( &clone->cpi );
		clone_parse_info( &clone->cpi, &THIS->cpi );

		class = HvNAME( SvSTASH( SvRV( ST(0) ) ) );
		ST(0) = sv_newmortal();
		sv_setref_pv( ST(0), CONST_CHAR(class), (void *) clone );

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
	PREINIT:
		CBC_METHOD( clean );

	CODE:
		CT_DEBUG_METHOD;

		free_parse_info( &THIS->cpi );

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
	PREINIT:
		CBC_METHOD( configure );

	CODE:
		CT_DEBUG_METHOD;

		if( items <= 2 && GIMME_V == G_VOID ) {
		  WARN_VOID_CONTEXT;
		  XSRETURN_EMPTY;
		}
		else if( items == 1 )
		  RETVAL = GetConfiguration( aTHX_ THIS );
		else if( items == 2 )
		  (void) HandleOption( aTHX_ THIS, ST(1), NULL, &RETVAL );
		else if( items % 2 ) {
		  int i, changes = 0;

		  for( i = 1; i < items; i += 2 )
		    if( HandleOption( aTHX_ THIS, ST(i), ST(i+1), NULL ) )
		      changes = 1;

		  if( changes )
		    UpdateConfiguration( THIS );

		  XSRETURN(1);
		}
		else
		  Perl_croak(aTHX_ "Invalid number of arguments to configure");

	OUTPUT:
		RETVAL

################################################################################
#
#   METHOD: Include / Define / Assert
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2002
#   CHANGED BY:                                   ON:
#
################################################################################

void
CBC::Include( ... )
	ALIAS:
		Define = 1
		Assert = 2

	PREINIT:
		CBC_METHOD_VAR;
		LinkedList list;
		int hasRval;
		SV *rval, *inval;

	PPCODE:
		/* handle aliases */
		switch( ix ) {
		  case 1:  /* Define */
		    CBC_METHOD_SET( "Define" );
		    list = THIS->cfg.defines;
		    break;
		  case 2:  /* Assert */
		    CBC_METHOD_SET( "Assert" );
		    list = THIS->cfg.assertions;
		    break;
		  default: /* Include */
		    CBC_METHOD_SET( "Include" );
		    list = THIS->cfg.includes;
		    break;
		}

		CT_DEBUG_METHOD;

		hasRval = GIMME_V != G_VOID && items <= 1;

		if( GIMME_V == G_VOID && items <= 1 ) {
		  WARN_VOID_CONTEXT;
		  XSRETURN_EMPTY;
		}

		if( items > 1 && !SvROK( ST(1) ) ) {
		  int i;
		  inval = NULL;

		  for( i = 1; i < items; ++i ) {
		    if( SvROK( ST(i) ) )
		      Perl_croak(aTHX_ "Argument %d to %s must not be a reference",
		                        i, method);

		    LL_push( list, string_new_fromSV( aTHX_ ST(i) ) );
		  }
		}
		else {
		  if( items > 2 )
		    Perl_croak(aTHX_ "Invalid number of arguments to %s", method);

		  inval = items == 2 ? ST(1) : NULL;
		}

		if( inval != NULL || hasRval )
		  HandleStringList( aTHX_ method, list, inval,
		                          hasRval ? &rval : NULL );

		if( hasRval )
		  ST(0) = sv_2mortal( rval );

		XSRETURN( 1 );

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
		CBC_METHOD( parse );
		Buffer buf;
		int rval;

	CODE:
		CT_DEBUG_METHOD;

		buf.buffer = code; /* code is not modified */
		buf.length = strlen( code );
		buf.pos    = 0;
#ifdef CBC_THREAD_SAFE
		MUTEX_LOCK( &gs_parse_mutex );
#endif
		rval = parse_buffer( NULL, &buf, &THIS->cfg, &THIS->cpi );
#ifdef CBC_THREAD_SAFE
		MUTEX_UNLOCK( &gs_parse_mutex );
#endif
		if( rval == 0 )
		  Perl_croak(aTHX_ "%s", THIS->cpi.errstr);

		update_parse_info( &THIS->cpi, &THIS->cfg );

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
	const char *file

	PREINIT:
		CBC_METHOD( parse_file );
		int rval;

	CODE:
		CT_DEBUG_METHOD1( "'%s'", file );
#ifdef CBC_THREAD_SAFE
		MUTEX_LOCK( &gs_parse_mutex );
#endif
		rval = parse_buffer( file, NULL, &THIS->cfg, &THIS->cpi );
#ifdef CBC_THREAD_SAFE
		MUTEX_UNLOCK( &gs_parse_mutex );
#endif
		if( rval == 0 )
		  Perl_croak(aTHX_ "%s", THIS->cpi.errstr);

		update_parse_info( &THIS->cpi, &THIS->cfg );

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
	const char *type

	PREINIT:
		CBC_METHOD( def );
		void *ptr;
		const char *eos = NULL;

	CODE:
		CT_DEBUG_METHOD1( "'%s'", type );

		CHECK_VOID_CONTEXT;

		ptr = GetTypePointer( THIS, type, &eos );

		if( ptr == NULL && GetBasicTypeSpec( type, NULL ) )
		  RETVAL = "basic";
		else {
		  if( eos && *eos != '\0' ) {
		    const char *kind;
		    switch( *eos ) {
		      default : kind = "garbage";                     break;
		      case '.': kind = "potential member expression"; break;
		      case '[': kind = "potential array expression";  break;
		    }
		    WARN((aTHX_ "Ignoring %s ('%s') after type name", kind, eos));
		  }
		  if( ptr == NULL )
		    XSRETURN_UNDEF;
		  else {
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
		  }
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
CBC::pack( type, data = &PL_sv_undef, string = NULL )
	const char *type
	SV *data
	SV *string

	PREINIT:
		CBC_METHOD( pack );
		char *buffer;
		MemberInfo mi;
		PackInfo pack;
		IDList idl;

	CODE:
		CT_DEBUG_METHOD1( "'%s'", type );

		if( string == NULL && GIMME_V == G_VOID ) {
		  WARN_VOID_CONTEXT;
		  XSRETURN_EMPTY;
		}

		if( string != NULL )  {
		  if( ! SvPOK( string ) )
		    Perl_croak(aTHX_ "Type of arg 3 to pack must be string");
		  if( GIMME_V == G_VOID && SvREADONLY( string ) )
		    Perl_croak(aTHX_ "Modification of a read-only value attempted");
		}

		if( !GetMemberInfo( aTHX_ THIS, type, &mi ) )
		  Perl_croak(aTHX_ "Cannot find '%s'", type);

		if( mi.flags )
		  WARN_FLAGS( type, mi.flags );

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

		pack.bufptr     =
		pack.buf.buffer = buffer;
		pack.buf.length = mi.size;
		pack.buf.pos    = 0;

		pack.align_base = 0;
		pack.alignment  = THIS->cfg.alignment;

		IDLIST_INIT( &idl );
		IDLIST_PUSH( &idl, ID );
		IDLIST_SET_ID( &idl, type );

		SetType( aTHX_ THIS, &pack, &mi.type, mi.pDecl, mi.level,
                         data, &idl );

		IDLIST_FREE( &idl );

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
	const char *type
	SV *string

	PREINIT:
		CBC_METHOD( unpack );
		STRLEN len;
		MemberInfo mi;
		PackInfo pack;

	CODE:
		CT_DEBUG_METHOD1( "'%s'", type );

		CHECK_VOID_CONTEXT;

		if( !SvPOK( string ) )
		  Perl_croak(aTHX_ "Type of arg 2 to unpack must be string");

		if( !GetMemberInfo( aTHX_ THIS, type, &mi ) )
		  Perl_croak(aTHX_ "Cannot find '%s'", type);

		if( mi.flags )
		  WARN_FLAGS( type, mi.flags );

		pack.bufptr     =
		pack.buf.buffer = SvPV( string, len );
		pack.buf.pos    = 0;
		pack.buf.length = len;

		pack.align_base = 0;
		pack.alignment  = THIS->cfg.alignment;

		pack.dataTooShortFlag = 0;

		RETVAL = GetType( aTHX_ THIS, &pack, &mi.type,
		                        mi.pDecl, mi.level );

		if( pack.dataTooShortFlag )
		  WARN((aTHX_ "Data too short"));

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
	const char *type

	PREINIT:
		CBC_METHOD( sizeof );
		MemberInfo mi;

	CODE:
		CT_DEBUG_METHOD1( "'%s'", type );

		CHECK_VOID_CONTEXT;

		if( !GetMemberInfo( aTHX_ THIS, type, &mi ) )
		  Perl_croak(aTHX_ "Cannot find '%s'", type);

		if( mi.pDecl && mi.pDecl->bitfield_size >= 0 )
		  Perl_croak(aTHX_ "Cannot use %s on bitfields", method);

		if( mi.flags )
		  WARN_FLAGS( type, mi.flags );
#ifdef newSVuv
		RETVAL = newSVuv( mi.size );
#else
		RETVAL = newSViv( (IV) mi.size );
#endif

	OUTPUT:
		RETVAL

################################################################################
#
#   METHOD: typeof
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Mar 2003
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
CBC::typeof( type )
	const char *type

	PREINIT:
		CBC_METHOD( typeof );
		MemberInfo mi;

	CODE:
		CT_DEBUG_METHOD1( "'%s'", type );

		CHECK_VOID_CONTEXT;

		if( !GetMemberInfo( aTHX_ THIS, type, &mi ) )
		  Perl_croak(aTHX_ "Cannot find '%s'", type);

		RETVAL = GetTypeNameString( aTHX_ &mi );

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
	const char *type
	const char *member

	PREINIT:
		CBC_METHOD( offsetof );
		MemberInfo mi, mi2;
		const char *m = member;

	CODE:
		CT_DEBUG_METHOD2( "'%s', '%s'", type, member );

		CHECK_PARSE_DATA;
		CHECK_VOID_CONTEXT;

		while( *m && isSPACE( *m ) ) m++;
		if( *m == '\0' )
		  WARN((aTHX_ "Empty string passed as member expression"));

		if( !GetMemberInfo( aTHX_ THIS, type, &mi ) )
		  Perl_croak(aTHX_ "Cannot find '%s'", type);

		GetMember( aTHX_ &mi, member, &mi2, 1 );

		if( mi2.pDecl && mi2.pDecl->bitfield_size >= 0 )
		  Perl_croak(aTHX_ "Cannot use %s on bitfields", method);

		if( mi.flags )
		  WARN_FLAGS( type, mi.flags );
#ifdef newSVuv
		RETVAL = newSVuv( mi2.offset );
#else
		RETVAL = newSViv( (IV) mi2.offset );
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
CBC::member( type, offset = NULL )
	const char *type
	SV *offset

	PREINIT:
		CBC_METHOD( member );
		MemberInfo mi;
		int have_offset, off;

	PPCODE:
		off = (have_offset = DEFINED(offset)) ? SvIV(offset) : 0;

		CT_DEBUG_METHOD2( "'%s', %d", type, off );

		CHECK_PARSE_DATA;
		CHECK_VOID_CONTEXT;

		if( !GetMemberInfo( aTHX_ THIS, type, &mi ) )
		  Perl_croak(aTHX_ "Cannot find '%s'", type);

		CheckAllowedTypes( aTHX_ &mi, "member", ALLOW_STRUCTS
		                                      | ALLOW_UNIONS
		                                      | ALLOW_ARRAYS );

		if( mi.flags ) {
		  u_32 flags = mi.flags;

		  /* bitfields are not a problem without offset given */
		  if( !have_offset )
		    flags &= ~T_HASBITFIELD;

		  WARN_FLAGS( type, flags );
		}

		if( have_offset ) {
		  if( off < 0 || off >= (int) mi.size )
		    Perl_croak(aTHX_ "Offset %d out of range (0 <= offset < %d)",
                                     off, mi.size);

		  if( GIMME_V == G_ARRAY ) {
		    GMSInfo info;
		    SV     *member;
		    int     count;

		    info.hit = LL_new();
		    info.off = LL_new();
		    info.pad = LL_new();

		    (void) GetMemberString( aTHX_ &mi, off, &info );

		    count = LL_count( info.hit )
		          + LL_count( info.off )
		          + LL_count( info.pad );

		    EXTEND( SP, count );

		    LL_foreach( member, info.hit )
		      PUSHs( member );

		    LL_foreach( member, info.off )
		      PUSHs( member );

		    LL_foreach( member, info.pad )
		      PUSHs( member );

		    LL_destroy( info.hit, NULL );
		    LL_destroy( info.off, NULL );
		    LL_destroy( info.pad, NULL );

		    XSRETURN( count );
		  }
		  else {
		    SV *member = GetMemberString( aTHX_ &mi, off, NULL );
		    PUSHs( member );
		    XSRETURN( 1 );
		  }
		}
		else {
		  LinkedList list;
		  SV *member;
		  int count;

		  list = GIMME_V == G_ARRAY ? LL_new() : NULL;
		  count = GetAllMemberStrings( aTHX_ &mi, list );

		  if( GIMME_V == G_ARRAY ) {
		    EXTEND( SP, count );

		    LL_foreach( member, list )
		      PUSHs( member );

		    LL_destroy( list, NULL );

		    XSRETURN( count );
		  }
		  else
		    XSRETURN_IV( count );
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
		CBC_METHOD( enum_names );
		EnumSpecifier *pEnumSpec;
		int count = 0;
		U32 context;

	PPCODE:
		CT_DEBUG_METHOD;

		CHECK_PARSE_DATA;
		CHECK_VOID_CONTEXT;

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
		CBC_METHOD( enum );
		EnumSpecifier *pEnumSpec;
		U32 context;

	PPCODE:
		CT_DEBUG_METHOD;

		CHECK_PARSE_DATA;
		CHECK_VOID_CONTEXT;

		context = GIMME_V;

		if( context == G_SCALAR && items != 2 )
		  XSRETURN_IV( items > 1 ? items-1 : LL_count( THIS->cpi.enums ) );

		if( items > 1 ) {
		  int i;

		  for( i = 1; i < items; ++i ) {
		    const char *name = SvPV_nolen( ST(i) );

		    /* skip optional enum */
		    if(   name[0] == 'e'
		       && name[1] == 'n'
		       && name[2] == 'u'
		       && name[3] == 'm'
		       && isSPACE( name[4] )
		      )
		      name += 5;

		    while( *name && isSPACE( *name ) ) name++;

		    pEnumSpec = HT_get( THIS->cpi.htEnums, name, 0, 0 );

		    if( pEnumSpec )
		      PUSHs( sv_2mortal( GetEnumSpecDef( aTHX_ pEnumSpec ) ) );
		    else {
		      WARN((aTHX_ "Cannot find enum '%s'", name));
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
		    PUSHs( sv_2mortal( GetEnumSpecDef( aTHX_ pEnumSpec ) ) );

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

void
CBC::compound_names()
	ALIAS:
		struct_names = 1
		union_names  = 2

	PREINIT:
		CBC_METHOD_VAR;
		Struct *pStruct;
		int count = 0;
		U32 context;
		u_32 mask;

	PPCODE:
		/* handle aliases */
		switch( ix ) {
		  case 1:  /* struct_names */
		    CBC_METHOD_SET( "struct_names" );
		    mask = T_STRUCT;
		    break;
		  case 2:  /* union_names */
		    CBC_METHOD_SET( "union_names" );
		    mask = T_UNION;
		    break;
		  default: /* compound_names */
		    CBC_METHOD_SET( "compound_names" );
		    mask = T_STRUCT | T_UNION;
		    break;
		}

		CT_DEBUG_METHOD;

		CHECK_PARSE_DATA;
		CHECK_VOID_CONTEXT;

		context = GIMME_V;

		LL_foreach( pStruct, THIS->cpi.structs )
		  if(    pStruct->identifier[0]
		      && pStruct->declarations
		      && pStruct->tflags & mask
		    ) {
		    if( context == G_ARRAY )
		      XPUSHs( sv_2mortal( newSVpv( pStruct->identifier, 0 ) ) );
		    count++;
		  }

		if( context == G_ARRAY )
		  XSRETURN( count );
		else
		  XSRETURN_IV( count );

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

void
CBC::compound( ... )
	ALIAS:
		struct = 1
		union  = 2

	PREINIT:
		CBC_METHOD_VAR;
		Struct *pStruct;
		U32 context;
		u_32 mask;

	PPCODE:
		/* handle aliases */
		switch( ix ) {
		  case 1:  /* struct */
		    CBC_METHOD_SET( "struct" );
		    mask = T_STRUCT;
		    break;
		  case 2:  /* union */
		    CBC_METHOD_SET( "union" );
		    mask = T_UNION;
		    break;
		  default: /* compound */
		    CBC_METHOD_SET( "compound" );
		    mask = T_STRUCT | T_UNION;
		    break;
		}

		CT_DEBUG_METHOD;

		CHECK_PARSE_DATA;
		CHECK_VOID_CONTEXT;

		context = GIMME_V;

		if( context == G_SCALAR && items != 2 ) {
		  if( items > 1 )
		    XSRETURN_IV( items-1 );
		  else if( mask == (T_STRUCT|T_UNION) )
		    XSRETURN_IV( LL_count( THIS->cpi.structs ) );
		  else {
		    int count = 0;

		    LL_foreach( pStruct, THIS->cpi.structs )
		      if( pStruct->tflags & mask )
		        count++;

		    XSRETURN_IV( count );
		  }
		}

		if( items > 1 ) {
		  int i;

		  for( i = 1; i < items; ++i ) {
		    const char *full, *name;
		    u_32 limit = mask;

		    full = name = SvPV_nolen( ST(i) );

		    /* skip optional union/struct */
		    if(   mask & T_UNION
		       && name[0] == 'u'
		       && name[1] == 'n'
		       && name[2] == 'i'
		       && name[3] == 'o'
		       && name[4] == 'n'
		       && isSPACE( name[5] )
		      ) {
		      name += 6;
		      limit = T_UNION;
		    }
		    else
		    if(   mask & T_STRUCT
		       && name[0] == 's'
		       && name[1] == 't'
		       && name[2] == 'r'
		       && name[3] == 'u'
		       && name[4] == 'c'
		       && name[5] == 't'
		       && isSPACE( name[6] )
		      ) {
		      name += 7;
		      limit = T_STRUCT;
		    }

		    while( *name && isSPACE( *name ) ) name++;

		    pStruct = HT_get( THIS->cpi.htStructs, name, 0, 0 );

		    if( pStruct && pStruct->tflags & limit )
		      PUSHs( sv_2mortal( GetStructSpecDef( aTHX_ pStruct ) ) );
		    else {
		      if( limit == T_UNION )
		        WARN((aTHX_ "Cannot find union '%s'", name));
		      else if( limit == T_STRUCT )
		        WARN((aTHX_ "Cannot find struct '%s'", name));
		      else
		        WARN((aTHX_ "Cannot find compound '%s'", full));
		      PUSHs( &PL_sv_undef );
		    }
		  }

		  XSRETURN( items-1 );
		}
		else {
		  int count = 0;

		  LL_foreach( pStruct, THIS->cpi.structs )
		    if( pStruct->tflags & mask ) {
		      XPUSHs( sv_2mortal( GetStructSpecDef( aTHX_ pStruct ) ) );
		      count++;
		    }

		  XSRETURN( count );
		}

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
		CBC_METHOD( typedef_names );
		TypedefList *pTDL;
		Typedef     *pTypedef;
		int          count = 0;
		U32          context;

	PPCODE:
		CT_DEBUG_METHOD;

		CHECK_PARSE_DATA;
		CHECK_VOID_CONTEXT;

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
		CBC_METHOD( typedef );
		Typedef *pTypedef;
		U32      context;

	PPCODE:
		CT_DEBUG_METHOD;

		CHECK_PARSE_DATA;
		CHECK_VOID_CONTEXT;

		context = GIMME_V;

		if( context == G_SCALAR && items != 2 )
		  XSRETURN_IV( items > 1 ? items-1 : HT_count( THIS->cpi.htTypedefs ) );

		if( items > 1 ) {
		  int i;

		  for( i = 1; i < items; ++i ) {
		    const char *name = SvPV_nolen( ST(i) );

		    pTypedef = HT_get( THIS->cpi.htTypedefs, name, 0, 0 );

		    if( pTypedef )
		      PUSHs( sv_2mortal( GetTypedefDef(aTHX_ pTypedef) ) );
		    else {
		      WARN((aTHX_ "Cannot find typedef '%s'", name));
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
		      PUSHs( sv_2mortal( GetTypedefDef(aTHX_ pTypedef) ) );

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
	PREINIT:
		CBC_METHOD( sourcify );

	CODE:
		CT_DEBUG_METHOD;

		CHECK_PARSE_DATA;
		CHECK_VOID_CONTEXT;

		RETVAL = GetParsedDefinitionsString( aTHX_ &THIS->cpi );

	OUTPUT:
		RETVAL


################################################################################
#
#   METHOD: initializer
#
#   WRITTEN BY: Marcus Holland-Moritz             ON: Jun 2003
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
CBC::initializer( type, init = &PL_sv_undef )
	const char *type
	SV *init

	PREINIT:
		CBC_METHOD( initializer );
		MemberInfo mi;

	CODE:
		CT_DEBUG_METHOD1( "'%s'", type );

		CHECK_VOID_CONTEXT;

		if( !GetMemberInfo( aTHX_ THIS, type, &mi ) )
		  Perl_croak(aTHX_ "Cannot find '%s'", type);

		RETVAL = GetInitializerString( aTHX_ THIS, &mi, init, type );

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

void
CBC::dependencies()
	PREINIT:
		CBC_METHOD( dependencies );
		const char *pKey;
		FileInfo   *pFI;

	PPCODE:
		CT_DEBUG_METHOD;

		CHECK_PARSE_DATA;
		CHECK_VOID_CONTEXT;

		if( GIMME_V == G_SCALAR ) {
		  HV *hv = newHV();

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
		        SvREFCNT_dec( attr );
		    }
		  }

		  XPUSHs( sv_2mortal( newRV_noinc( (SV *) hv ) ) );
		  XSRETURN(1);
		}
		else {
		  int keylen, count = 0;

		  HT_reset( THIS->cpi.htFiles );
		  while( HT_next( THIS->cpi.htFiles, (char **)&pKey, &keylen, (void **) &pFI ) )
		    if( pFI && pFI->valid ) {
		      XPUSHs( sv_2mortal( newSVpvn( pKey, keylen ) ) );
		      count++;
		    }

		  XSRETURN(count);
		}

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
		  Perl_croak(aTHX_ "You must pass an even number of module arguments");
		else {
		  for( i = 1; i < items; i += 2 ) {
		    const char *opt = SvPV_nolen( ST(i) );
#ifdef CTYPE_DEBUGGING
		    const char *arg = SvPV_nolen( ST(i+1) );
#endif
		    if( strEQ( opt, "debug" ) ) {
#ifdef CTYPE_DEBUGGING
		      SetDebugOptions( aTHX_ arg );
#else
		      wflags |= WARN_NO_DEBUGGING;
#endif
		    }
		    else if( strEQ( opt, "debugfile" ) ) {
#ifdef CTYPE_DEBUGGING
		      SetDebugFile( aTHX_ arg );
#else
		      wflags |= WARN_NO_DEBUGGING;
#endif
		    }
		    else
		      Perl_croak(aTHX_ "Invalid module option '%s'", opt);
		  }

		  if( wflags & WARN_NO_DEBUGGING )
		    Perl_warn(aTHX_ XSCLASS " not compiled with debugging support");
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

void
feature( feat )
	const char *feat

	CODE:
		switch( *feat ) {
		  case 'd':
		    if( strEQ( feat, "debug" ) )
#ifdef CTYPE_DEBUGGING
		      XSRETURN_YES;
#else
		      XSRETURN_NO;
#endif
		    break;

		  case 'i':
		    if( strEQ( feat, "ieeefp" ) )
#ifdef CBC_HAVE_IEEE_FP
		      XSRETURN_YES;
#else
		      XSRETURN_NO;
#endif
		    break;

		  case 't':
		    if( strEQ( feat, "threads" ) )
#ifdef CBC_THREAD_SAFE
		      XSRETURN_YES;
#else
		      XSRETURN_NO;
#endif
		    break;
		}

		XSRETURN_UNDEF;

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
		DumpSV( aTHX_ RETVAL, 0, val );

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
		  const char *str;
		  PrintFunctions f;
		  f.newstr = ct_newstr;
		  f.scatf  = ct_scatf;
		  f.vscatf = ct_vscatf;
		  f.warn   = ct_warn;
		  f.error  = ct_warn;
		  f.fatal  = ct_fatal;
		  set_print_functions( &f );
#ifdef CBC_THREAD_SAFE
		  MUTEX_INIT( &gs_parse_mutex );
#endif
#ifdef CTYPE_DEBUGGING
		  gs_DB_stream = stderr;
		  if( (str = getenv("CBC_DEBUG_OPT")) != NULL )
		    SetDebugOptions( aTHX_ str );
		  if( (str = getenv("CBC_DEBUG_FILE")) != NULL )
		    SetDebugFile( aTHX_ str );
#endif
		  gs_DisableParser = 0;
		  if( (str = getenv("CBC_DISABLE_PARSER")) != NULL )
		    gs_DisableParser = atoi(str);
		}

