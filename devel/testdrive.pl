#!perl -w
use Net::Telnet;
use Net::FTP;
use IO::Pty;
use IO::File;
use POSIX qw( setsid );
use Getopt::Long;
use threads;
use strict;

use constant USER => 'mhx';
use constant PASS => 'sTGC3kg';

my %OPT = (
  upload  => 0,
  remove  => 1,
  test    => 1,
  reports => 1,
  compile => 1,
);

GetOptions(\%OPT, qw(
  upload|u! remove|r! test|t! reports|p! compile|c!
)) && @ARGV == 1 or die "USAGE: $0 <options> file";

my $HOMEDIR = '/house/mhx';
my $PROMPT = '/(spe|td)\d{3}(?:\.testdrive\.(?:hp|compaq)\.com)?(:[^>]+)?> $/';

my @hosts = (
  ### HP-UX

  { ip => 'td192.testdrive.hp.com', prompt => $PROMPT },
  { ip => 'td176.testdrive.hp.com', prompt => $PROMPT },
  { ip => 'td191.testdrive.hp.com', prompt => $PROMPT },
  { ip => 'td193.testdrive.hp.com', prompt => $PROMPT },
  { ip => 'td194.testdrive.hp.com', prompt => $PROMPT },

  ### OpenVMS

  # { ip => 'td237.testdrive.hp.com', prompt => $PROMPT },
  # { ip => 'td180.testdrive.hp.com', prompt => $PROMPT },
  # { ip => 'td183.testdrive.hp.com', prompt => $PROMPT },
  # { ip => 'td184.testdrive.hp.com', prompt => $PROMPT },

  ### Debian

  { ip => 'td140.testdrive.hp.com', prompt => $PROMPT },
  { ip => 'td156.testdrive.hp.com', prompt => $PROMPT },
  { ip => 'td157.testdrive.hp.com', prompt => $PROMPT },

  ### Mandriva

  { ip => 'td153.testdrive.hp.com', prompt => $PROMPT },

  ### Oracle

  { ip => 'td189.testdrive.hp.com', prompt => $PROMPT },

  ### RHEL

  { ip => 'td163.testdrive.hp.com', prompt => $PROMPT },
  { ip => 'td165.testdrive.hp.com', prompt => $PROMPT },
  { ip => 'td188.testdrive.hp.com', prompt => $PROMPT },
  { ip => 'td161.testdrive.hp.com', prompt => $PROMPT },
  { ip => 'td185.testdrive.hp.com', prompt => $PROMPT },
  { ip => 'td159.testdrive.hp.com', prompt => $PROMPT },

  ### SuSE

  { ip => 'td162.testdrive.hp.com', prompt => $PROMPT },   ## no cc ???
  { ip => 'td186.testdrive.hp.com', prompt => $PROMPT },   ## offline ?
  { ip => 'td190.testdrive.hp.com', prompt => $PROMPT },   ## offline ?
  { ip => 'td179.testdrive.hp.com', prompt => $PROMPT },   ## offline ?
  { ip => 'td187.testdrive.hp.com', prompt => $PROMPT },   ## offline ?

  ### FreeBSD

  { ip => 'td150.testdrive.hp.com', prompt => $PROMPT },
  { ip => 'td152.testdrive.hp.com', prompt => $PROMPT },
);

my $file = shift;

$OPT{upload} and upload_file( $hosts[0], $file );
$OPT{remove} and remove_reports( $hosts[0] );

if ($OPT{compile}) {
  my @t = map { threads->new(
   \&test_compile, $_, $file
  # \&version, $_
  ) } @hosts;
  
  $_->join for @t;
}

if ($OPT{reports}) {
  collect_reports( $hosts[0] );
  download_file( $hosts[0], 'reports.tar.gz' );
}

sub upload_file
{
  my($host, $file) = @_;

  print STDERR "uploading $file to $host->{ip}...";
  my $ftp = Net::FTP->new( $host->{ip}, Passive => 1 ) or die "connect $host->{ip}: $!\n";
  $ftp->login( USER, PASS ) or die "login $host->{ip}: $!\n";
  $ftp->cwd( $HOMEDIR ) or die "cwd $HOMEDIR on $host->{ip}: $!\n";
  $ftp->binary or die "binary $host->{ip}: $!\n";
  $ftp->put( $file ) or die "put $file to $host->{ip}: $!\n";
  $ftp->quit or die "quit $host->{ip}: $!\n";
  print STDERR "done\n";
}

sub download_file
{
  my($host, $file) = @_;

  print STDERR "downloading $file from $host->{ip}...";
  my $ftp = Net::FTP->new( $host->{ip}, Passive => 1 );
  $ftp->login( USER, PASS );
  $ftp->cwd( $HOMEDIR );
  $ftp->binary;
  $ftp->get( $file );
  $ftp->quit;
  print STDERR "done\n";
}

sub collect_reports
{
  my($host) = @_;
  print "collecting reports on $host->{ip}...";
  run_script( $host, 20, <<END );
tar cf - reports | gzip > reports.tar.gz
rm -f reports/*
END
  print "done\n"
}

sub remove_reports
{
  my($host) = @_;
  print "removing existing reports on $host->{ip}...";
  run_script( $host, 20, <<END );
rm -rf reports reports.tar.gz
mkdir reports
END
  print "done\n"
}

sub version
{
  my($host) = @_;
  my $perl = $host->{perl} || 'perl';

  print "checking version on $host->{ip}\n";

  my @lines = run_script( $host, 20, <<END );
uname -a
$perl -v
$perl -V
END

  my $f = IO::File->new;
  $f->open( ">version-$host->{ip}.log" );
  $f->print( @lines );
  $f->close;
}

sub test_compile
{
  my($host, $file) = @_;
  my $perl = $host->{perl} || 'perl';
  my($dist) = $file =~ /([^\/]+)\.tar\.gz$/;

  print "compiling $file on $host->{ip}\n";

  my @lines = run_script( $host, 1800, <<END );
cd /tmp
rm -rf $dist
gzip -dc $HOMEDIR/$file | tar xvf -
cd $dist
uname -a
$perl -v
$perl -V
touch Makefile.PL
$perl Makefile.PL
make
make test HARNESS_NOTTY=1
# make test HARNESS_NOTTY=1 && perl -I$HOMEDIR/lib -MTest::Reporter -e'Test::Reporter->new(grade=>"pass", distribution=>"$dist", dir=>"$HOMEDIR/reports")->write'
$perl -Mblib bin/ccconfig --nostatus
$perl -Mblib bin/ccconfig --nostatus --norun
make realclean
$perl Makefile.PL enable-debug
make
make test HARNESS_NOTTY=1
make realclean
$perl Makefile.PL enable-debug
CBC_USELONGLONG=0 CBC_USE64BIT=0 make
make test HARNESS_NOTTY=1
make realclean
cd ..
rm -rf $dist
END

  my $f = IO::File->new;
  $f->open( ">testdrive-$host->{ip}.log" );
  $f->print( @lines );
  $f->close;

  print "finished $file on $host->{ip}\n";
}

sub run_script
{
  my($host, $timeout, $script) = @_;
  my @lines;

  my $telnet = do_cmd( 'telnet', $host->{ip} );
  my $t = Net::Telnet->new( Fhopen => $telnet, Timeout => $timeout, Errmode => 'return' );

  # login
  $t->binmode(1);
  $t->waitfor('/.*[lL]ogin:\s*/');
  $t->print( USER );
  $t->waitfor('/.*[pP]assword:\s*/');
  $t->print( PASS );
  push @lines, $t->waitfor($host->{prompt}) or return @lines;

  my @cmds = grep !/^\s*#/, grep /\S/, split $/, $script;

  for my $cmd ( @cmds ) {
    print "[$host->{ip}: $cmd]\n";
    $t->print($cmd);
    push @lines, $t->waitfor($host->{prompt}) or return @lines;
  }
  $t->close;

  @lines;
}

sub do_cmd
{
  my($cmd, @args) = @_;
  my $pty = IO::Pty->new or die "can't make pty: $!";
  defined (my $child = fork) or die "can't fork: $!";
  return $pty if $child;
  setsid();
  my $tty = $pty->slave;
  close $pty;
  STDIN->fdopen($tty, "<") or die "STDIN: $!";
  STDOUT->fdopen($tty, ">") or die "STDOUT: $!";
  STDERR->fdopen($tty, ">") or die "STDERR: $!";
  close $tty;
  $| = 1;
  exec $cmd, @args;
  die "couldn't exec: $!";
}
