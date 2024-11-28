#!/usr/bin/perl

# http://mipagina.cantv.net/lem/perl/ftpsync
# This script is (c) 2002 Luis E. Muñoz, All Rights Reserved
# This code can be used under the same terms as Perl itself. It comes
# with absolutely NO WARRANTY. Use at your own risk.

use strict;
use warnings;
use Net::FTP;
use File::Find;
use Pod::Usage;
use Getopt::Std;

use vars qw($opt_s $opt_k $opt_u $opt_l $opt_p $opt_r $opt_h $opt_v
	    $opt_d $opt_P $opt_i $opt_o);

getopts('i:o:l:s:u:p:r:hkvdP');

if ($opt_h)
{
    pod2usage({-exitval => 2,
	       -verbose => 2});
}
				# Defaults are set here
$opt_s ||= 'localhost';
$opt_u ||= 'anonymous';
$opt_p ||= 'someuser@';
$opt_r ||= '/';
$opt_l ||= '.';
$opt_o ||= 0;

$opt_i = qr/$opt_i/ if $opt_i;

$|++;				# Autoflush STDIN

my %rem = ();
my %loc = ();

print "Using time offset of $opt_o seconds\n" if $opt_v and $opt_o;

				# Phase 0: Scan local path and see what we
				# have

chdir $opt_l or die "Cannot change dir to $opt_l: $!\n";

find(
     {
	 no_chdir	=> 1,
	 follow		=> 0,	# No symlinks, please
	 wanted		=> sub
	 {
	     return if $File::Find::name eq '.';
	     $File::Find::name =~ s!^\./!!;
	     if ($opt_i and $File::Find::name =~ m/$opt_i/)
	     {
		 print "local: IGNORING $File::Find::name\n" if $opt_d;
		 return;
	     }
	     my $r = $loc{$File::Find::name} = 
	     {
		 mdtm => (stat($File::Find::name))[9],
		 size => (stat(_))[7],
		 type => -f _ ? 'f' : -d _ ? 'd' 
		     : -l $File::Find::name ? 'l' : '?',
	     };
	     print "local: adding $File::Find::name (",
	     "$r->{mdtm}, $r->{size}, $r->{type})\n" if $opt_d;
	 },
     }, '.' );

				# Phase 1: Build a representation of what's
				# in the remote site

my $ftp = new Net::FTP ($opt_s, 
			Debug		=> $opt_d, 
			Passive		=> $opt_P,
			);

die "Failed to connect to server '$opt_s': $!\n" unless $ftp;
die "Failed to login as $opt_u\n" unless $ftp->login($opt_u, $opt_p);
die "Cannot change directory to $opt_r\n" unless $ftp->cwd($opt_r);
warn "Failed to set binary mode\n" unless $ftp->binary();

print "connected\n" if $opt_v;

sub scan_ftp
{
    my $ftp	= shift;
    my $path	= shift;
    my $rrem	= shift;

    my $rdir = length($path) ? $ftp->dir($path) : $ftp->dir();

    return unless $rdir and @$rdir;

    for my $f (@$rdir)
    {
	next if $f =~ m/^d.+\s\.\.?$/;

	my $n = (split(/\s+/, $f, 9))[8];
	next unless defined $n;

	my $name = '';
	$name = $path . '/' if $path;
	$name .= $n;

	if ($opt_i and $name =~ m/$opt_i/)
	{
	    print "ftp: IGNORING $name\n" if $opt_d;
	    next;
	}

	next if exists $rrem->{$name};

	my $mdtm = ($ftp->mdtm($name) || 0) + $opt_o;
	my $size = $ftp->size($name) || 0;
	my $type = substr($f, 0, 1);

	$type =~ s/-/f/;

	warn "ftp: adding $name ($mdtm, $size, $type)\n" if $opt_d;
	
	$rrem->{$name} = 
	{
	    mdtm => $mdtm,
	    size => $size,
	    type => $type,
	};

	scan_ftp($ftp, $name, $rrem) if $type eq 'd';
    }
}

scan_ftp($ftp, '', \%rem);

				# Phase 2: Upload "missing files"

for my $l (sort { length($a) <=> length($b) } keys %loc)
{
    warn "Symbolic link $l not supported\n"
	if $loc{$l}->{type} eq 'l';

    if ($loc{$l}->{type} eq 'd')
    {
	next if exists $rem{$l};
	print "$l dir missing in the FTP repository\n" if $opt_v;
	$opt_k ? print "MKDIR $l\n" : $ftp->mkdir($l)
	    or die "Failed to MKDIR $l\n";
    }
    else
    {
	next if exists $rem{$l} and $rem{$l}->{mdtm} >= $loc{$l}->{mdtm};
	print "$l file missing or older in the FTP repository\n" 
	    if $opt_v;
	$opt_k ? print "PUT $l $l\n" : $ftp->put($l, $l)
	    or die "Failed to PUT $l\n";
    }
}

				# Phase 3: Delete missing files

for my $r (sort { length($b) <=> length($a) } keys %rem)
{
    if ($rem{$r}->{type} eq 'l')
    {
	warn "Symbolic link $r not supported\n";
	next;
    }
	
    next if exists $loc{$r};

    print "$r file missing locally\n" if $opt_v;
    $opt_k ? print "DELETE $r\n" : $ftp->delete($r)
	or die "Failed to DELETE $r\n";
}

__END__

=pod

=head1 NAME

ftpsync - Sync a hierarchy of local files with a remote FTP repository

=head1 SYNOPSIS

ftpsync [-h] [-v] [-d] [-k] [-P] [-s server] [-u username] [-p password] [-r remote] [-l local] [-i ignore] [-o offset]

=head1 ARGUMENTS

The recognized flags are described below:

=over 2

=item B<-h>

Produce this documentation.

=item B<-v>

Produce verbose messages while running.

=item B<-d>

Put the C<Net::FTP> object in debug mode and also emit some debugging
information about what's being done.

=item B<-k>

Just kidding. Only announce what would be done but make no change in
neither local nor remote files.

=item B<-P>

Set passive mode.

=item B<-i ignore>

Specifies a regexp. Files matching this regexp will be left alone.

=item B<-s server>

Specify the FTP server to use. Defaults to C<localhost>.

=item B<-u username>

Specify the username. Defaults to 'anonymous'.

=item B<-p password>

Password used for connection. Defaults to an anonymous pseudo-email
address.

=item B<-r remote>

Specifies the remote directory to match against the local directory.

=item B<-l local>

Specifies the local directory to match against the remote directory.

=item B<-o offset>

Allows the specification of a time offset between the FTP server and
the local host. This makes it easier to correct time skew or
differences in time zones.

=back

=head1 DESCRIPTION

This is an example script that should be usable as is for simple
website maintenance. It synchronizes a hierarchy of local files /
directories with a subtree of an FTP server.

The synchronyzation is quite simplistic. It was written to explain how
to C<use Net::FTP> and C<File::Find>.

Always use the C<-k> option before using it in production, to avoid
data loss.

=head1 BUGS

The synchronization is not quite complete. This script does not deal
with symbolic links. Many cases are not handled to keep the code short
and understandable.

=head1 AUTHORS

Luis E. Muñoz <luismunoz@cpan.org>

=head1 SEE ALSO

Perl(1).

=cut


