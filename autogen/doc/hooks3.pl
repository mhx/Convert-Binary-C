#!perl -w
use Convert::Binary::C;
use Data::Dumper;
$Data::Dumper::Indent = 1;

%CC = (
            'Define' => [
                          '__CHECKER__=1',
                          '__CHAR_BIT__=8',
                          '__DBL_DIG__=15',
                          '__DBL_EPSILON__=2.2204460492503131e-16',
                          '__DBL_MANT_DIG__=53',
                          '__DBL_MAX_10_EXP__=308',
                          '__DBL_MAX_EXP__=1024',
                          '__DBL_MAX__=1.7976931348623157e+308',
                          '__DBL_MIN_10_EXP__=(-307)',
                          '__DBL_MIN_EXP__=(-1021)',
                          '__DBL_MIN__=2.2250738585072014e-308',
                          '__DECIMAL_DIG__=21',
                          '__ELF__=1',
                          '__FLT_DIG__=6',
                          '__FLT_EPSILON__=1.19209290e-7F',
                          '__FLT_EVAL_METHOD__=2',
                          '__FLT_MANT_DIG__=24',
                          '__FLT_MAX_10_EXP__=38',
                          '__FLT_MAX_EXP__=128',
                          '__FLT_MAX__=3.40282347e+38F',
                          '__FLT_MIN_10_EXP__=(-37)',
                          '__FLT_MIN_EXP__=(-125)',
                          '__FLT_MIN__=1.17549435e-38F',
                          '__FLT_RADIX__=2',
                          '__GNUC_MINOR__=3',
                          '__GNUC_PATCHLEVEL__=3',
                          '__GNUC__=3',
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
                          '__PTRDIFF_TYPE__=int',
                          '__SCHAR_MAX__=127',
                          '__SHRT_MAX__=32767',
                          '__SIZE_TYPE__=unsigned int',
                          '__WCHAR_TYPE__=long int',
                          '__WINT_TYPE__=unsigned int',
                          '__attribute__(x)=',
                          '__builtin_va_list=int',
                          '__gnu_linux__=1',
                          '__i386=1',
                          '__i386__=1',
                          '__linux=1',
                          '__linux__=1',
                          '__tune_i686__=1',
                          '__tune_pentiumpro__=1',
                          '__unix=1',
                          '__unix__=1',
                          'i386=1',
                          'linux=1',
                          'unix=1'
                        ],
            'ByteOrder' => 'LittleEndian',
            'LongSize' => 4,
            'IntSize' => 4,
            'ShortSize' => 2,
            'Assert' => [
                          'cpu(i386)',
                          'machine(i386)',
                          'system(posix)'
                        ],
            'UnsignedChars' => 0,
            'DoubleSize' => 8,
            'PointerSize' => 4,
            'EnumSize' => 4,
            'FloatSize' => 4,
            'DisabledKeywords' => [
                                    'restrict'
                                  ],
            'LongLongSize' => 8,
            'Alignment' => 4,
            'LongDoubleSize' => 12,
            'KeywordMap' => {
                              '__imag__' => undef,
                              '__inline' => 'inline',
                              '__volatile' => 'volatile',
                              '__complex__' => undef,
                              '__real' => undef,
                              '__imag' => undef,
                              '__restrict' => undef,
                              '__inline__' => 'inline',
                              '__asm' => 'asm',
                              '__bounded__' => undef,
                              '__volatile__' => 'volatile',
                              '__unbounded' => undef,
                              '__extension__' => undef,
                              '__signed' => 'signed',
                              '__unbounded__' => undef,
                              '__const' => 'const',
                              '__const__' => 'const',
                              '__signed__' => 'signed',
                              '__bounded' => undef,
                              '__real__' => undef,
                              '__complex' => undef,
                              '__restrict__' => undef,
                              '__asm__' => 'asm'
                            },
            'HasCPPComments' => 1,
            'Include' => [
                           '/usr/lib/gcc-lib/i686-pc-linux-gnu/3.3.6/include',
                           '/usr/include'
                         ],
            'CompoundAlignment' => 1
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
    for qw( XPVAV XPVHV MAGIC MGVTBL HV );

#-8<-

sub unpack_ptr {
  my($self, $type, $ptr) = @_;
  $ptr or return '<NULL>';
  my $size = $self->sizeof($type);
  $self->unpack($type, unpack("P$size", pack('I', $ptr)));
}

#-8<-

my $ref = bless ["Boo!"], "Foo::Bar";
my $ptr = hex(("$ref" =~ /\(0x([[:xdigit:]]+)\)$/)[0]);

print Dumper(unpack_ptr($c, 'AV', $ptr));
