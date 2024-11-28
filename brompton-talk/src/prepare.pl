eval 'exec perl -w $0 $@'    # set emacs major mode: -*-Perl-*-
if not "running under perl";

$body = 0;
# 0 = looking for/in header
# 1 = expecting body, skip following empty lines
# 2 = copy body

$backlog = 0;
# Number of empty body lines not printed yet.
# Empty body lines at beginning and end of body are ignored.

binmode STDOUT;  # no CR/LF please

while (<>)
{
    s/\s*$//;	# strip trailing whitespace & newline

    if (/^From - /)
    {
	$body = $backlog = 0;
	$author = $date = $subject = "";
    }
    elsif (/^X-Mozilla-Status2: /)
    {
	# Netscape ?, follows X-Mozilla-Status
    }
    elsif (/^X-UIDL: /)
    {
	# Netscape ?, follows X-Mozilla-Status
    }
    elsif (/^Content-Length: /)
    {
	# Netscape 3.0, follows X-Mozilla-Status
    }
    elsif ($body)
    {
	if (length)
	{   
	    # non-empty body line
	    s/\243/&pound;/g;
	    print "    <BR>\n" x $backlog, "    $_\n";
	    $body = 2;
	    $backlog = 0;
	}
	elsif ($body == 2)

	{
	    # count accountable empty body lines
	    ++$backlog;
	}
    }
    elsif (/^From: */)
    {
        s///;
        # separate author name from e-mail address
        s/"//g;   # " balance emacs fontify
	s/<.*?>// unless /^<.*?>$/;
	s/@\S*//;
        s/^ *//;
        s/ *$//;
	$author = $_;
    }
    elsif (/^Date: */)
    {
        s///;
        my @d = split;
	if (! defined $d[3])
	{
            print STDERR "Line $.: weird date: '$_'\n";
	    $date = $_;
	}
	else
	{
	    $date = "$d[2] $d[3]";
	}
    }
    elsif (/^Subject: */)
    {
	$subject = $_;
    }
    elsif (/^X-Mozilla-Status: */)
    {
	print "\n\n$subject\n  <LI>{$author, $date}\n";
	$body = 1;
    }
}
