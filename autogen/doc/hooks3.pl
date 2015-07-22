#!perl -w
use Convert::Binary::C;
use Data::Dumper;
$Data::Dumper::Indent = 1;

%CC = (
            'Alignment' => 4,
            'Assert' => [
                          'cpu(i386)',
                          'machine(i386)',
                          'system(linux)',
                          'system(posix)',
                          'system(unix)'
                        ],
            'ByteOrder' => 'LittleEndian',
            'CharSize' => 1,
            'CompoundAlignment' => 1,
            'Define' => [
                          '_FORTIFY_SOURCE=2',
                          '__CHAR_BIT__=8',
                          '__DBL_DIG__=15',
                          '__DBL_EPSILON__=((double)2.22044604925031308085e-16L)',
                          '__DBL_MANT_DIG__=53',
                          '__DBL_MAX_10_EXP__=308',
                          '__DBL_MAX_EXP__=1024',
                          '__DBL_MAX__=((double)1.79769313486231570815e+308L)',
                          '__DBL_MIN_10_EXP__=(-307)',
                          '__DBL_MIN_EXP__=(-1021)',
                          '__DBL_MIN__=((double)2.22507385850720138309e-308L)',
                          '__DEC128_EPSILON__=1E-33DL',
                          '__DEC128_MANT_DIG__=34',
                          '__DEC128_MAX_EXP__=6145',
                          '__DEC128_MAX__=9.999999999999999999999999999999999E6144DL',
                          '__DEC128_MIN_EXP__=(-6142)',
                          '__DEC128_MIN__=1E-6143DL',
                          '__DEC128_SUBNORMAL_MIN__=0.000000000000000000000000000000001E-6143DL',
                          '__DEC32_EPSILON__=1E-6DF',
                          '__DEC32_MANT_DIG__=7',
                          '__DEC32_MAX_EXP__=97',
                          '__DEC32_MAX__=9.999999E96DF',
                          '__DEC32_MIN_EXP__=(-94)',
                          '__DEC32_MIN__=1E-95DF',
                          '__DEC32_SUBNORMAL_MIN__=0.000001E-95DF',
                          '__DEC64_EPSILON__=1E-15DD',
                          '__DEC64_MANT_DIG__=16',
                          '__DEC64_MAX_EXP__=385',
                          '__DEC64_MAX__=9.999999999999999E384DD',
                          '__DEC64_MIN_EXP__=(-382)',
                          '__DEC64_MIN__=1E-383DD',
                          '__DEC64_SUBNORMAL_MIN__=0.000000000000001E-383DD',
                          '__DECIMAL_DIG__=21',
                          '__DEC_EVAL_METHOD__=2',
                          '__ELF__=1',
                          '__FLT_DIG__=6',
                          '__FLT_EPSILON__=1.19209289550781250000e-7F',
                          '__FLT_EVAL_METHOD__=2',
                          '__FLT_MANT_DIG__=24',
                          '__FLT_MAX_10_EXP__=38',
                          '__FLT_MAX_EXP__=128',
                          '__FLT_MAX__=3.40282346638528859812e+38F',
                          '__FLT_MIN_10_EXP__=(-37)',
                          '__FLT_MIN_EXP__=(-125)',
                          '__FLT_MIN__=1.17549435082228750797e-38F',
                          '__FLT_RADIX__=2',
                          '__GNUC_MINOR__=5',
                          '__GNUC_PATCHLEVEL__=2',
                          '__GNUC__=4',
                          '__INT16_MAX__=32767',
                          '__INT16_TYPE__=short int',
                          '__INT32_MAX__=2147483647',
                          '__INT32_TYPE__=int',
                          '__INT64_MAX__=9223372036854775807LL',
                          '__INT64_TYPE__=long long int',
                          '__INT8_MAX__=127',
                          '__INT8_TYPE__=signed char',
                          '__INTMAX_MAX__=9223372036854775807LL',
                          '__INTMAX_TYPE__=long long int',
                          '__INTPTR_MAX__=2147483647',
                          '__INTPTR_TYPE__=int',
                          '__INT_FAST16_MAX__=2147483647',
                          '__INT_FAST16_TYPE__=int',
                          '__INT_FAST32_MAX__=2147483647',
                          '__INT_FAST32_TYPE__=int',
                          '__INT_FAST64_MAX__=9223372036854775807LL',
                          '__INT_FAST64_TYPE__=long long int',
                          '__INT_FAST8_MAX__=127',
                          '__INT_FAST8_TYPE__=signed char',
                          '__INT_LEAST16_MAX__=32767',
                          '__INT_LEAST16_TYPE__=short int',
                          '__INT_LEAST32_MAX__=2147483647',
                          '__INT_LEAST32_TYPE__=int',
                          '__INT_LEAST64_MAX__=9223372036854775807LL',
                          '__INT_LEAST64_TYPE__=long long int',
                          '__INT_LEAST8_MAX__=127',
                          '__INT_LEAST8_TYPE__=signed char',
                          '__INT_MAX__=2147483647',
                          '__LDBL_DIG__=18',
                          '__LDBL_EPSILON__=1.08420217248550443401e-19L',
                          '__LDBL_MANT_DIG__=64',
                          '__LDBL_MAX_10_EXP__=4932',
                          '__LDBL_MAX_EXP__=16384',
                          '__LDBL_MAX__=1.18973149535723176502e+4932L',
                          '__LDBL_MIN_10_EXP__=(-4931)',
                          '__LDBL_MIN_EXP__=(-16381)',
                          '__LDBL_MIN__=3.36210314311209350626e-4932L',
                          '__LONG_LONG_MAX__=9223372036854775807LL',
                          '__LONG_MAX__=2147483647L',
                          '__NO_INLINE__=1',
                          '__PRAGMA_REDEFINE_EXTNAME=1',
                          '__PTRDIFF_MAX__=2147483647',
                          '__PTRDIFF_TYPE__=int',
                          '__SCHAR_MAX__=127',
                          '__SHRT_MAX__=32767',
                          '__SIG_ATOMIC_MAX__=2147483647',
                          '__SIG_ATOMIC_MIN__=(-2147483647 - 1)',
                          '__SIZEOF_LONG_LONG__=8',
                          '__SIZEOF_LONG__=4',
                          '__SIZEOF_POINTER__=4',
                          '__SIZE_MAX__=4294967295U',
                          '__SIZE_TYPE__=unsigned int',
                          '__UINT16_MAX__=65535',
                          '__UINT16_TYPE__=short unsigned int',
                          '__UINT32_MAX__=4294967295U',
                          '__UINT32_TYPE__=unsigned int',
                          '__UINT64_MAX__=18446744073709551615ULL',
                          '__UINT64_TYPE__=long long unsigned int',
                          '__UINT8_MAX__=255',
                          '__UINT8_TYPE__=unsigned char',
                          '__UINTMAX_MAX__=18446744073709551615ULL',
                          '__UINTMAX_TYPE__=long long unsigned int',
                          '__UINTPTR_MAX__=4294967295U',
                          '__UINTPTR_TYPE__=unsigned int',
                          '__UINT_FAST16_MAX__=4294967295U',
                          '__UINT_FAST16_TYPE__=unsigned int',
                          '__UINT_FAST32_MAX__=4294967295U',
                          '__UINT_FAST32_TYPE__=unsigned int',
                          '__UINT_FAST64_MAX__=18446744073709551615ULL',
                          '__UINT_FAST64_TYPE__=long long unsigned int',
                          '__UINT_FAST8_MAX__=255',
                          '__UINT_FAST8_TYPE__=unsigned char',
                          '__UINT_LEAST16_MAX__=65535',
                          '__UINT_LEAST16_TYPE__=short unsigned int',
                          '__UINT_LEAST32_MAX__=4294967295U',
                          '__UINT_LEAST32_TYPE__=unsigned int',
                          '__UINT_LEAST64_MAX__=18446744073709551615ULL',
                          '__UINT_LEAST64_TYPE__=long long unsigned int',
                          '__UINT_LEAST8_MAX__=255',
                          '__UINT_LEAST8_TYPE__=unsigned char',
                          '__USER_LABEL_PREFIX__=',
                          '__WCHAR_MAX__=2147483647L',
                          '__WCHAR_MIN__=(-2147483647L - 1)',
                          '__WCHAR_TYPE__=long int',
                          '__WINT_MAX__=4294967295U',
                          '__WINT_MIN__=0U',
                          '__WINT_TYPE__=unsigned int',
                          '__attribute__(x)=',
                          '__builtin_va_list=int',
                          '__gnu_linux__=1',
                          '__i386=1',
                          '__i386__=1',
                          '__i686=1',
                          '__i686__=1',
                          '__linux=1',
                          '__linux__=1',
                          '__pentiumpro=1',
                          '__pentiumpro__=1',
                          '__unix=1',
                          '__unix__=1',
                          'i386=1',
                          'linux=1',
                          'unix=1'
                        ],
            'DisabledKeywords' => [
                                    'restrict'
                                  ],
            'DoubleSize' => 8,
            'EnumSize' => 4,
            'FloatSize' => 4,
            'HasCPPComments' => 1,
            'HostedC' => 1,
            'Include' => [
                           '/usr/lib/gcc/i686-pc-linux-gnu/4.5.2/include',
                           '/usr/lib/gcc/i686-pc-linux-gnu/4.5.2/include-fixed',
                           '/usr/include'
                         ],
            'IntSize' => 4,
            'KeywordMap' => {
                              '__asm' => 'asm',
                              '__asm__' => 'asm',
                              '__complex' => undef,
                              '__complex__' => undef,
                              '__const' => 'const',
                              '__const__' => 'const',
                              '__extension__' => undef,
                              '__imag' => undef,
                              '__imag__' => undef,
                              '__inline' => 'inline',
                              '__inline__' => 'inline',
                              '__real' => undef,
                              '__real__' => undef,
                              '__restrict' => 'restrict',
                              '__restrict__' => 'restrict',
                              '__signed' => 'signed',
                              '__signed__' => 'signed',
                              '__volatile' => 'volatile',
                              '__volatile__' => 'volatile'
                            },
            'LongDoubleSize' => 12,
            'LongLongSize' => 8,
            'LongSize' => 4,
            'PointerSize' => 4,
            'ShortSize' => 2,
            'StdCVersion' => undef,
            'UnsignedChars' => 0
      );

#-8<-

use Config;

$c = new Convert::Binary::C %CC, OrderMembers => 1;
$c->Include(["$Config{archlib}/CORE", @{$c->Include}]);
$c->parse(<<ENDC);
#include "EXTERN.h"
#include "perl.h"
ENDC

$c->tag($_, Hooks => { unpack_ptr => [\&unpack_ptr,
                                      $c->arg(qw(SELF TYPE DATA))] })
    for qw( XPVAV XPVHV );

#-8<-

sub unpack_ptr {
  my($self, $type, $ptr) = @_;
  $ptr or return '<NULL>';
  my $size = $self->sizeof($type);
  $self->unpack($type, unpack("P$size", pack('I', $ptr)));
}

#-8<-

my $ref = { foo => 42, bar => 4711 };
my $ptr = hex(("$ref" =~ /\(0x([[:xdigit:]]+)\)$/)[0]);

print Dumper(unpack_ptr($c, 'AV', $ptr));

