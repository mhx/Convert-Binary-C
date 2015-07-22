#!/home/mhx/bin/perl580mtopt -w
use Net::Telnet;
use Net::FTP;
use IO::Pty;
use IO::File;
use POSIX qw( setsid );
use threads;
use strict;

use constant USER => 'mhx';
use constant PASS => 'sTGC3kg';

my $HOMEDIR = '/house/mhx';
my $PROMPT = '/spe\d{3}(?:\.testdrive\.(?:hp|compaq)\.com)?> $/';

my @hosts = (
  # { ip => '192.233.54.140', prompt => $PROMPT },
  # { ip => '192.233.54.141', prompt => $PROMPT }, # broken libgcc?
  { ip => '192.233.54.142', prompt => $PROMPT },        # 5.6.1 alpha-linux
  { ip => '192.233.54.143', prompt => $PROMPT },        # 5.8.0 i386-netbsd
  # { ip => '192.233.54.144', prompt => $PROMPT },        # 5.6.1 alpha-linux
  { ip => '192.233.54.145', prompt => $PROMPT },        # 5.6.1 alpha-dec_osf
  { ip => '192.233.54.147', prompt => $PROMPT },        # 5.8.0 alpha-dec_osf
  # { ip => '192.233.54.148', prompt => $PROMPT },        # 5.6.1 alpha-linux
  { ip => '192.233.54.149', prompt => $PROMPT },        # 5.6.1 alpha-freebsd

  { ip => '192.233.54.150', prompt => $PROMPT },        # 5.8.0 i586-linux-thread-multi
  { ip => '192.233.54.151', prompt => $PROMPT },        # 5.005_03 i386-freebsd
  { ip => '192.233.54.156', prompt => $PROMPT },        # 5.6.1 ia64-linux

  # { ip => '192.233.54.160', prompt => $PROMPT },        # 5.8.0 i486-linux
  { ip => '192.233.54.161', prompt => $PROMPT },        # 5.6.1 alpha-linux
  { ip => '192.233.54.165', prompt => '/mgtnode> $/' }, # 5.6.0 alpha-linux
  # { ip => '192.233.54.167', prompt => $PROMPT },        # 5.8.0 alpha-dec_osf

  { ip => '192.233.54.170', prompt => $PROMPT },        # 5.6.1 hppa-linux
  # { ip => '192.233.54.174', prompt => $PROMPT },        # 5.6.1 ia64-linux
  # { ip => '192.233.54.175', prompt => $PROMPT },  # broken perl installation
  { ip => '192.233.54.176', prompt => $PROMPT, perl => 'perl5.8.0' },  # 5.8.0 parisc-hpux
  { ip => '192.233.54.177', prompt => $PROMPT },        # 5.6.1 ia64-linux
  # { ip => '192.233.54.178', prompt => $PROMPT },        # 5.6.1 ia64-linux

  { ip => '192.233.54.188', prompt => $PROMPT },        # 5.8.1 i386-linux-thread-multi

  # { ip => '192.233.54.191', prompt => $PROMPT },  # 
  { ip => '192.233.54.192', prompt => $PROMPT, perl => 'perl5.8.0' },  #    HP-UX 11

  # { ip => '192.233.54.206', prompt => $PROMPT },        # 5.8.0 alpha-dec_osf
  # { ip => '192.233.54.207', prompt => $PROMPT },        # 5.8.0 alpha-dec_osf

  { ip => '192.233.54.208', prompt => $PROMPT },        # 5.8.0 alpha-dec_osf

  # { ip => '192.233.54.222', prompt => $PROMPT },        # 5.6.1 i386-linux
  # { ip => '192.233.54.223', prompt => $PROMPT },        # 5.6.1 i386-linux
);

my $file = shift;

upload_file( $hosts[0], $file );
remove_reports( $hosts[0] );

my @t = map { new threads
 \&test_compile, $_, $file
# \&version, $_
} @hosts;

$_->join for @t;

collect_reports( $hosts[0] );
download_file( $hosts[0], 'reports.tar.gz' );

sub upload_file
{
  my($host, $file) = @_;

  print STDERR "uploading $file to $host->{ip}...";
  my $ftp = Net::FTP->new( $host->{ip}, Passive => 1 );
  $ftp->login( USER, PASS );
  $ftp->cwd( $HOMEDIR );
  $ftp->binary;
  $ftp->put( $file );
  $ftp->quit;
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

  my $f = new IO::File;
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

  my $f = new IO::File;
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
