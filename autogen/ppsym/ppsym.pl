#!/usr/bin/perl -w
use IO::File;
use File::Find;
use Data::Dumper;
use Text::Wrap;
use strict;

my @def = qw(
  a29k ABI64 aegis AES_SOURCE AIX AIX32 AIX370 AIX41 AIX42 AIX43 AIX_SOURCE
  aixpc ALL_SOURCE alliant alpha am29000 AM29000 AMD64 amiga AMIGAOS AMIX ansi
  ANSI_C_SOURCE apollo ardent ARM32 atarist att386 att3b BeOS BIG_ENDIAN
  BIT_MSF bsd BSD bsd43 bsd4_2 bsd4_3 BSD4_3 bsd4_4 BSD_4_3 BSD_4_4 BSD_NET2
  BSD_TIME BSD_TYPES BSDCOMPAT bsdi bull c cadmus clipper CMU COFF
  COMPILER_VERSION concurrent convex cpu cray CRAY CRAYMPP ctix CX_UX CYGWIN
  DGUX DGUX_SOURCE DJGPP dmert DOLPHIN DPX2 DSO Dynix DynixPTX ELF encore EPI
  EXTENSIONS FAVOR_BSD FILE_OFFSET_BITS FreeBSD GCC_NEW_VARARGS gcos gcx gimpel
  GLIBC GLIBC_MINOR GNU_SOURCE GNUC GNUC_MINOR GNU_LIBRARY GO32 gould GOULD_PN
  H3050R H3050RX hbullx20 hcx host_mips hp200 hp300 hp700 HP700 hp800 hp9000
  hp9000s200 hp9000s300 hp9000s400 hp9000s500 hp9000s700 hp9000s800 hp9k8
  hp_osf hppa hpux HPUX_SOURCE i186 i286 i386 i486 i586 i686 i8086 i80960 i860
  I960 IA64 iAPX286 ibm ibm032 ibmesa IBMR2 ibmrt ILP32 ILP64 INLINE_INTRINSICS
  INTRINSICS INT64 interdata is68k ksr1 LANGUAGE_C LARGE_FILE_API
  LARGEFILE64_SOURCE LARGEFILE_SOURCE LFS64_LARGEFILE LFS_LARGEFILE Linux
  LITTLE_ENDIAN LONG64 LONG_DOUBLE LONG_LONG LONGDOUBLE LONGLONG LP64 luna
  luna88k Lynx M68000 m68k m88100 m88k M88KBCS_TARGET M_COFF M_I186 M_I286
  M_I386 M_I8086 M_I86 M_I86SM M_SYS3 M_SYS5 M_SYSIII M_SYSV M_UNIX M_XENIX
  MACH machine MachTen MATH_HAS_NO_SIDE_EFFECTS mc300 mc500 mc68000 mc68010
  mc68020 mc68030 mc68040 mc68060 mc68k mc68k32 mc700 mc88000 mc88100 merlin
  mert MiNT mips MIPS_FPSET MIPS_ISA MIPS_SIM MIPS_SZINT MIPS_SZLONG MIPS_SZPTR
  MIPSEB MIPSEL MODERN_C motorola mpeix MSDOS MTXINU MULTIMAX mvs MVS n16
  ncl_el ncl_mr NetBSD news1500 news1700 news1800 news1900 news3700 news700
  news800 news900 NeXT NLS nonstopux ns16000 ns32000 ns32016 ns32332 ns32k
  nsc32000 OCS88 OEMVS OpenBSD os OS2 OS390 osf OSF1 OSF_SOURCE pa_risc
  PA_RISC1_1 PA_RISC2_0 PARAGON parisc pc532 pdp11 PGC PIC plexus PORTAR posix
  POSIX1B_SOURCE POSIX2_SOURCE POSIX4_SOURCE POSIX_C_SOURCE POSIX_SOURCE POWER
  PROTOTYPES PWB pyr QNX R3000 REENTRANT RES Rhapsody RISC6000 riscix riscos RT
  S390 SA110 scs SCO sequent sgi SGI_SOURCE SH3 sinix SIZE_INT SIZE_LONG
  SIZE_PTR SOCKET_SOURCE SOCKETS_SOURCE sony sony_news sonyrisc sparc sparclite
  spectrum stardent stdc STDC_EXT stratos sun sun3 sun386 Sun386i svr3 svr4
  SVR4_2 SVR4_SOURCE svr5 SX system SYSTYPE_BSD SYSTYPE_BSD43 SYSTYPE_BSD44
  SYSTYPE_SVR4 SYSTYPE_SVR5 SYSTYPE_SYSV SYSV SYSV3 SYSV4 SYSV5 sysV68 sysV88
  Tek4132 Tek4300 titan TM3200 TM5400 TM5600 tower tower32 tower32_200
  tower32_600 tower32_700 tower32_800 tower32_850 tss u370 u3b u3b2 u3b20
  u3b200 u3b20d u3b5 ultrix UMAXV UnicomPBB UnicomPBD UNICOS UNICOSMK unix
  UNIX95 UNIX99 unixpc unos USE_BSD USE_FILE_OFFSET64 USE_GNU USE_ISOC9X
  USE_LARGEFILE USE_LARGEFILE64 USE_MISC USE_POSIX USE_POSIX199309
  USE_POSIX199506 USE_POSIX2 USE_REENTRANT USE_SVID USE_UNIX98 USE_XOPEN
  USE_XOPEN_EXTENDED USGr4 USGr4_2 Utek UTek UTS UWIN uxpm uxps vax venix VMESA
  vms xenix Xenix286 XOPEN_SOURCE XOPEN_SOURCE_EXTENDED XPG2 XPG2_EXTENDED XPG3
  XPG3_EXTENDED XPG4 XPG4_EXTENDED z8000 GNUC_PATCHLEVEL gnu_linux NO_INLINE
  tune_i686 tune_pentiumpro M_IX86 BYTE_ORDER HP_aCC hp9000ipc hp64000 hp64902
  DCC hp64903 bool cplusplus DCPLUSPLUS DIAB_TOOL EABI hardfp LDBL lint nofp
  ppc softfp STRICT_ANSI wchar_t m68332 m68020 m68030 m68040 v20 v33 STDCPP
  
);

my @sys    = qw( gnu mach hurd linux unix aix bsd hpux lynx mach posix svr3 svr4
                 xpg4 mvs vms winnt );
my @cpu    = qw( a29k alpha arm clipper convex elxsi tron h8300 i370 i386 i860
                 i960 ia64 m68k m88k mips ns32k hppa pyr ibm032 rs6000 sh sparc
                 spur tahoe vax we32000 parisc );
my @model  = qw( lp64 ilp32 );
my @endian = qw( big little );

my(%assert, %define);

@define{@def} = map { { $_ => 1 } } @def;

%assert = (
  'system'  => { map { ($_ => 1) } @sys    },
  'cpu'     => { map { ($_ => 1) } @cpu    },
  'machine' => { map { ($_ => 1) } @cpu    },
  'model'   => { map { ($_ => 1) } @model  },
  'endian'  => { map { ($_ => 1) } @endian },
);

find( { wanted => \&getsym, no_chdir => 1 }, @ARGV );

for my $key ( keys %define ) {
  for( lc $key, uc $key ) {
    if( exists $define{$_} ) {
      my $src = delete $define{$_};
      $define{$key}{$_} = $src->{$_} for keys %$src;
    }
  }
}

# print Data::Dumper->Dump( [\%define, \%assert],
#                          [qw(*define *assert)] );

my $defines = wrap( ' 'x4, ' 'x4, sort {lc $a cmp lc $b} keys %define );

my $asserts = join ",\n", map {
  my $a = wrap( ' 'x6, ' 'x6, sort {lc $a cmp lc $b} keys %{$assert{$_}} );
  "    '$_' => [qw(\n$a\n    )]"
} sort {lc $a cmp lc $b} keys %assert;

print <<END;
sub _preset_names
{
  qw(
$defines
  )
}

sub _assert
{
  {
$asserts
  }
}
END

exit 0;

sub getsym
{
  /\.h$/ or return;
  my $fh = new IO::File $_ or return;
  my $file = do { local $/; <$fh> };
  my $id = '[a-zA-Z_]\w*';

  $file =~ s{\\\s*$/}{}g;

  for( split $/, $file ) {
    my($line) = /^\s*#\s*define[^"]+\"([^"]+)\"/ or next;
    $line =~ /-[DA]/ or next;
    for( $line =~ /(-D$id|-A$id=[\w\$]+)/g ) {
      if( my($sym) = /^-D($id)/ ) {
        my $key = $sym;
        $key =~ /^_+\d/
        or $key =~ s/^__($id)__$/$1/
        or $key =~ s/^__($id)$/$1/
        or $key =~ s/^_($id)$/$1/;
        for( lc $key, uc $key ) {
          if( exists $define{$_} ) {
            my $src = delete $define{$_};
            $define{$key}{$_} = $src->{$_} for keys %$src;
          }
        }
        $define{$key}{$sym}++;
      }
      elsif( my($q,$a) = /^-A($id)=(\w+)$/ ) {
        $q =~ /^___/ or $assert{$q}{$a}++;
      }
    }
  }
}
