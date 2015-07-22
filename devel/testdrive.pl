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
  { ip => '192.233.54.140', prompt => $PROMPT },
  { ip => '192.233.54.141', prompt => $PROMPT },
  { ip => '192.233.54.142', prompt => $PROMPT },
  { ip => '192.233.54.143', prompt => $PROMPT },
  { ip => '192.233.54.144', prompt => $PROMPT },
  { ip => '192.233.54.145', prompt => $PROMPT },
  { ip => '192.233.54.147', prompt => $PROMPT },
  { ip => '192.233.54.148', prompt => $PROMPT },
  { ip => '192.233.54.149', prompt => $PROMPT },

  { ip => '192.233.54.150', prompt => $PROMPT },
  { ip => '192.233.54.151', prompt => $PROMPT },
  { ip => '192.233.54.152', prompt => $PROMPT },
  { ip => '192.233.54.153', prompt => $PROMPT },
  { ip => '192.233.54.154', prompt => $PROMPT },
  { ip => '192.233.54.155', prompt => $PROMPT },
  { ip => '192.233.54.156', prompt => $PROMPT },
  { ip => '192.233.54.158', prompt => $PROMPT },
  { ip => '192.233.54.159', prompt => $PROMPT },

  { ip => '192.233.54.160', prompt => $PROMPT },
  { ip => '192.233.54.161', prompt => $PROMPT },
  { ip => '192.233.54.162', prompt => $PROMPT },  # problem
  { ip => '192.233.54.163', prompt => $PROMPT },
  { ip => '192.233.54.164', prompt => $PROMPT },  # problem
  { ip => '192.233.54.165', prompt => '/mgtnode> $/' },
  { ip => '192.233.54.166', prompt => $PROMPT },
  { ip => '192.233.54.167', prompt => $PROMPT },
  # { ip => '192.233.54.168', prompt => $PROMPT },  # only perl 5.5.2
  # { ip => '192.233.54.169', prompt => $PROMPT },  # only perl 5.5.2

  { ip => '192.233.54.170', prompt => $PROMPT },
  { ip => '192.233.54.172', prompt => $PROMPT },
  { ip => '192.233.54.174', prompt => $PROMPT },

  { ip => '192.233.54.188', prompt => $PROMPT },

  { ip => '192.233.54.190', prompt => $PROMPT },

  { ip => '192.233.54.206', prompt => $PROMPT },
  { ip => '192.233.54.207', prompt => $PROMPT },

  { ip => '192.233.54.211', prompt => '/shark1.testdrive.compaq.com> $/' },
  { ip => '192.233.54.212', prompt => '/mhx\@shark2:\~\$ $/' },
  { ip => '192.233.54.214', prompt => '/shark4.testdrive.compaq.com> $/' },
);

my $file = shift;

upload_file( $hosts[0], $file );

my @t = map { new threads
 \&test_compile, $_, $file
# \&version, $_
} @hosts;

$_->join for @t;

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

sub version
{
  my($host) = @_;

  print "checking version on $host->{ip}\n";

  my @lines = run_script( $host, 20, <<END );
uname -a
perl -v
perl -V
END

  my $f = new IO::File;
  $f->open( ">version-$host->{ip}.log" );
  $f->print( @lines );
  $f->close;
}

sub test_compile
{
  my($host, $file) = @_;
  my($dir) = $file =~ /([^\/]+)\.tar\.gz$/;

  print "compiling $file on $host->{ip}\n";

  my @lines = run_script( $host, 1800, <<END );
cd /tmp
gzip -dc $HOMEDIR/$file | tar xvf -
cd $dir
uname -a
perl -v
perl -V
touch Makefile.PL
perl Makefile.PL
make
make test
make realclean
cd ..
rm -rf $dir
END

  my $f = new IO::File;
  $f->open( ">testdrive-$host->{ip}.log" );
  $f->print( @lines );
  $f->close;
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

  my @cmds = grep /\S/, split $/, $script;

  for my $cmd ( @cmds ) {
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
