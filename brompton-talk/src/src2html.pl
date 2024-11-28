eval 'exec perl -w $0'    # set emacs major mode: -*-Perl-*-
if not "running under perl";

use POSIX 'strftime';
use FileHandle;
use Image::Info 'image_info';
# use strict 'vars';

$timeformat = '%B %e, %Y';
$bar = "";

$ANCHORTYPE_ERROR = 0;
$ANCHORTYPE_ANONYMOUS = 1;
$ANCHORTYPE_NORMAL = 2;
$ANCHORTYPE_FILE = 3;

sub FileKiloBytes ($)
{
  my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat $_[0] or die "\nerror accessing file $_[0]: $!\n";
  return int(($size+1023)/1024);
}

sub FileModifiedTime ($)
{
  my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat $_[0] or die "\nerror accessing file $_[0]: $!\n";
  return $mtime;
}

sub ImageTags ($)
{
  my $info = image_info($_[0]);
  my $kB = FileKiloBytes($_[0]);
  return " WIDTH=$info->{width} HEIGHT=$info->{height}";
}


sub OpenOut ($)
{ # arg 0: filename
  my ($fn) = @_;
  my $fh = new FileHandle "> $fn" or die "\nerror opening $fn for output: $!\n";
  binmode $fh;
  return $fh;
}

sub InitLevel ($)
{ # arg 0: level variable
  $_[0] = 0;
}

sub GoToLevel ($$$)
{ # arg 0: output file handle
  # arg 1: level variable initialised to 0
  # arg 2: new level value > 0
  my $fh = shift;

  if ($_[0] != $_[1])
  {
    while ($_[0] < $_[1])
    {
      print $fh "<UL>";
      ++$_[0];
    }
    while ($_[0] > $_[1])
    {
      print $fh "</UL>";
      --$_[0];
    }
    print $fh "\n";
  }
}

sub ExitLevel ($$)
{ # arg 0: output file handle
  # arg 1: level variable
  my $fh = shift;

  if ($_[0] > 0)
  {
    GoToLevel($fh, $_[0], 0);
  }
}

sub PrintChapterTOC ($$$;$)
{ # arg 0: output file handle
  # arg 1 = source module to output table of contents from
  # arg 2 = name of output module to refer crossreferences to
  # arg 3 = max_level (>= 1)

  my $fh = shift;
  my $chapter = $_[0];
  my $refer = $_[1] ? "$_[1].html" : "";
  my $max_level = $_[2];

  my $level;
  InitLevel($level);

  foreach $anchor ( @{ $bookChapterInfo{$chapter}->{anchorList} })
  {
    my %info = %{ $bookAnchorInfo{$anchor} };
    if (! defined $max_level or $info{level} <= $max_level)
    {
      GoToLevel($fh, $level, $info{level});
      print $fh "  " x $info{level}, "<LI><A HREF=\"$refer#$anchor\">$info{title}</A>\n";
    }
  }

  ExitLevel($fh, $level);
}

sub InitTOC ($$)
{ # arg 0: output file handle
  # arg 1 = title of table
  my $fh = shift;
  my $title = shift;

  print $fh "<TABLE CLASS=\"toc\" ALIGN=\"center\" WIDTH=\"95%\">\n<TR><TH ALIGN=\"left\">$title";
  print $fh "<TR><TD>\n";
}

sub ExitTOC ($)
{ # arg 0: output file handle
  my $fh = shift;

  print $fh "</TABLE>\n";
}


sub CheckAnchorDefinition ($)
{ # Checks whether $_ contains anchor definition.
  # Returns array (anchorType(enum), level(int), label(string), title(string)) if found.
  # If anchorType==$ANCHORTYPE_ERROR, title contains the error message.
  # Returns null array otherwise.
  # arg 0: $currentAnonymousAnchorNr variable

  my ($indented, $label, $title);
  if ( ($indented, $label, $title) = m[^( *)#(\S*)\s*(.*)] )
  {
    my $file = ($label =~ s/\.html$//);
    my $anonymous = ($label eq "");
    if ( $anonymous && $title eq "" )
    {
      return ( $ANCHORTYPE_ERROR, 0, "", "label or title required in anchor definition" );
    }
    elsif ( length($indented) % 2 != 0 )
    {
      return ( $ANCHORTYPE_ERROR, 0, "", "even indentation required in anchor definition" );
    }
    elsif ( $label =~ /\./ )
    {
      return ( $ANCHORTYPE_ERROR, 0, "", "unknown file extension in anchor definition" );
    }
    else
    {
      $label = ++$_[0] if $anonymous;
      return ( $anonymous? $ANCHORTYPE_ANONYMOUS : $file ? $ANCHORTYPE_FILE : $ANCHORTYPE_NORMAL,
               length($indented) / 2 +1,
               $label,
               $title ne ""? $title : $label );
    }
  }
  return ();
}


sub PrintHtmlHead ($$$$$;$$)
{ # arg 0: output file handle
  # arg 1: output file sub-url (without for index.html)
  # arg 2: title
  # arg 3: what has last changed
  # arg 4: time of last change
  # arg 5: left HTML for pointers, if any
  # arg 6: right HTML for pointers, if any
  my ($fh, $suburl, $title, $thing, $time, $lpointers, $rpointers) = @_;
  my $changed = strftime($timeformat, localtime $time);

  print $fh "<!DOCTYPE public \"-//w3c//dtd html 4.01 transitional//en\" \"http://www.w3.org/TR/html4/loose.dtd\">\n";
  print $fh "<HTML><HEAD>\n";
  print $fh "<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=iso-8859-1\">\n";
  print $fh "<META HTTP-EQUIV=\"Content-Language\" CONTENT=\"en-GB\">\n";
  print $fh "<META NAME=\"GENERATOR\" CONTENT=\"src2html\">\n";
  print $fh "<META NAME=\"DATE\" CONTENT=\"", strftime("%Y-%m-%d", localtime $time), "\">\n";
  print $fh "<META NAME=\"AUTHOR\" CONTENT=\"$siteAuthor\">\n";
  print $fh "<META NAME=\"KEYWORDS\" CONTENT=\"$siteKeywords\">\n" unless $suburl;
  print $fh "<META NAME=\"DESCRIPTION\" CONTENT=\"$siteDescription\">\n" unless $suburl;
  print $fh "<LINK HREF=\"style.css\" REL=\"stylesheet\" TYPE=\"text/css\">\n" unless $suburl;
  print $fh "<LINK HREF=\"../style.css\" REL=\"stylesheet\" TYPE=\"text/css\">\n" if $suburl;
  print $fh "<LINK HREF=\"../index.html\" REL=\"contents\">\n" if $suburl;
  print $fh "<TITLE>$title</TITLE></HEAD>\n";
  print $fh "<BODY>";
  if (!$suburl) {
    print $fh "<TABLE WIDTH=\"100%\"><TR>";
    print $fh "<TD>\n";
  }
  print $fh "<TABLE CLASS=\"banner\" ALIGN=\"right\"><TR>\n";
  print $fh "$bar<TD>$lpointers</TD>\n" if defined $lpointers;
  print $fh "$bar<TD>$thing last changed $changed</TD>\n";
  print $fh "$bar<TD>$rpointers</TD>" if defined $rpointers;
  print $fh "$bar</TR></TABLE>\n";
  print $fh "<H1>$title</H1>\n";
  if (!$suburl) {
    print $fh "</TD></TR></TABLE>\n";
  }
}

sub PrintHtmlFoot ($$;$$)
{ # arg 0: output file handle
  # arg 1: "chapter" or "section" or undefined, along type of output module
  # arg 2: file with left HTML for pointers
  # arg 3: right HTML for pointers
  my ($fh, $pointer, $flpointers, $rpointers) = @_;
  print $fh "<TABLE CLASS=\"banner\" ALIGN=\"right\"><TR>\n";
  if (defined $flpointers)
  {
    print $fh "$bar<TD>\n" if $flpointers;
    open SUB, "< $flpointers" or die "\nerror opening $flpointers for input: $!";
    <SUB>;
    while (<SUB>)
    {
      print $fh $_;
    }
    close SUB;
  }
  print $fh "</TD>$bar<TD><A HREF=\"https://$siteLocation\">$siteTitle</A>";
  #if (defined $pointer) {
  #  my $aboutAnchor = $bookAnchorInfo{"author"}->{$pointer};
  #  print $fh " - please <A HREF=\"$aboutAnchor.html#author\">comment</A>";
  #}
  print $fh "</TD>$bar<TD>$rpointers" if defined $rpointers;
  print $fh "</TD>$bar</TR></TABLE></BODY></HTML>\n";
}


sub PrintChapterBlock ($$$$$$;$)
{ # arg 0: output file handle
  # arg 1: level up to which' next label should be printed.
  # arg 2: input module (without .src)
  # arg 3: output module (without .html)
  # arg 4: "chapter" or "section" or undefined, along type of output module
  # arg 5: current title inside input module
  # arg 6: current label inside input module
  # return: result of CheckAnchorDefinition or ().
  my ($fh, $stopAtLevel, $in_module, $out_module, $pointer, $mastertitle, $masterlabel) = @_;

  my $source =  "$in_module.src";
  line:
  while (<SRC>)
  {
    chop;
    next line if /-\*-html-\*-/;

    my ($anchorType, $level, $label, $title);
    if ( ($anchorType, $level, $label, $title) = CheckAnchorDefinition($currentAnonymousAnchorNr) )
    {
      if ($anchorType == $ANCHORTYPE_ERROR)
      {
	print STDERR "$source:$.: $title (and why the heck didn't I notice the first time??)\n";
      }
      else
      {
# switch sub-pages off for a change, links in them don't work
$anchorType = $ANCHORTYPE_NORMAL if $anchorType == $ANCHORTYPE_FILE;

        while ($level > $stopAtLevel)
        {
          if ($level != $stopAtLevel + 1)
          {
            print STDERR "$source:$.: didn't you skip a level here?\n";
          }

          my $hl = "H" . ($level+1);
          my $hassubfile = $anchorType == $ANCHORTYPE_FILE && $pointer eq "chapter";
          print $fh "<$hl>";
          print $fh "<A NAME=\"$label\"></A>";
          print $fh "<A HREF=\"$label.html\">" if $hassubfile;
          print $fh $title;
          print $fh "</A>" if $hassubfile;
          print $fh "</$hl>\n";
          if ($hassubfile)
          {
            my $info = $bookChapterInfo{$chapter};
            my $url = "$chapter.html";
            $url .= "#$masterlabel" if defined $masterlabel;
            my $pointers = HtmlForPointer($url, "^");

            my $nestedfh = OpenOut("../chapters/$label.html");
            PrintHtmlHead($nestedfh, "chapters/$label.html", $mastertitle, "Page", $info->{mtime}, undef, $pointers);
            print $nestedfh "<$hl ALIGN=\"center\">$title</$hl>";
            my $more = ($anchorType, $level, $label, $title) = PrintChapterBlock($nestedfh, $level, $in_module, $label, $pointer, $title, $label);
            PrintHtmlFoot($nestedfh, $pointer, undef, $pointers);
            return () unless $more;
          }
          else
          {
            my $more = ($anchorType, $level, $label, $title) = PrintChapterBlock($fh, $level, $in_module, $label, $pointer, $title, $label);
            return () unless $more;
          }
        }
        return ($anchorType, $level, $label, $title);
      }
    }
    else
    {
      # literal HREFs:
      s[(?<!")(http:[-+_!$%^&*/.a-zA-Z0-9~]*)]   [<A HREF="$1">$1</A>]g;
	# balancing " here to balance emacs fontification

      # literal MAILTO:
      s[(?<!")(mailto:([^\s,;]*))]   [<A HREF="$1">$2</A>]g;
        # this balancing " normalises emacs fontification

      # HREFs without quotes:
      s[<A HREF=([^"].*?)>]   [<A HREF="$1">]g;
        # this balancing " normalises emacs fontification

      # quick HREFs:
      while (m[\B@(\w+)])
      {
	if (! defined $pointer)
	{
	  print STDERR "$source:$.: unexpected anchor '$1'\n";
	  s[] [];
	}
	elsif (! exists $bookAnchorInfo{$1} )
	{
	  print STDERR "$source:$.: unknown anchor '$1'\n";
	  s[] [];
	}
	else
	{
	  ++$bookAnchorInfo{$1}->{references};
	  my $to_module = $bookAnchorInfo{$1}->{$pointer};
	  my $href_file;
	  my $href_text;
          if ($to_module eq $out_module)
	  {
	    $href_file = "";
	    $href_text = $bookAnchorInfo{$1}->{title};
	  }
	  else
	  {
	    $href_file = "$to_module.html";
            my $dict = ($pointer eq "section") ? \%bookSectionInfo : \%bookChapterInfo;
	    $href_text = "$dict->{$to_module}->{title} - $bookAnchorInfo{$1}->{title}";
	  }
	  s[] 	[<A CLASS=\"quick\" HREF="$href_file#$1">$href_text</A>];
	}
      }

      # IMG
      s[<IMG SRC="([^"]*)"]   ["<IMG SRC=\"$1\"" . ImageTags $1]ge;
      # another " here to balance emacs fontification

      # author names:
      s[^( *(?:<LI>|<BR>)?)\{(.+?)\}<P>]   [$1<EM CLASS="from">$2:</EM><P>]i;
      s[^( *(?:<LI>|<BR>)?)\{(.+?)\}\s*]   [$1<EM CLASS="from">$2:</EM><BR>]i;

      # prune leading/trailing whitespace from HTML output:
      s/^\s*//;
      s/\s*$//;

      print $fh "$_\n";
    }
  }
  close SRC;
  return ();
}

sub PrintChapterContents ($$$;$$)
{ # arg 0: output file handle
  # arg 1: input module (without .src)
  # arg 2: output module (without .html)
  # arg 3: "chapter" or "section" or undefined, along type of output module
  # arg 4: output module title
  my ($fh, $in_module, $out_module, $pointer, $title) = @_;
  die if defined $pointer && $pointer ne "chapter" && $pointer ne "section";

  my $source =  "$in_module.src";
  open SRC, "< $source" or die "\nerror opening $source for input: $!";
  PrintChapterBlock($fh, 0, $in_module, $out_module, $pointer, $title);
  close SRC;
}

sub HtmlForImgPtr ($;$$)
{ # arg 0 = file containing image
  # arg 1 = relative path to destination document
  my ($src, $path) = @_;
  $path = "" unless defined $path;
  return "<IMG SRC=\"$src\"" . (ImageTags "$path$src") . ">";
}

sub HtmlForPointer ($$)
{ # arg 0 = module to point to, if empty: void pointer
  # arg 1 = "<" for previous, ">" for next, "^" for index, or something else
  my ($href, $text) = @_;
  my $rel = "";

  if ($text eq "^")
  {
    $text = HtmlForImgPtr("../pictures/index.gif");
    $rel = " REL=\"index\" TITLE=\"To Index\"";
  }
  elsif ($text eq "<")
  {
    $text = HtmlForImgPtr("../pictures/prev.gif");
    $rel = " REL=\"prev\" TITLE=\"To Previous Chapter\"";
  }
  elsif ($text eq ">")
  {
    $text = HtmlForImgPtr("../pictures/next.gif");
    $rel = " REL=\"next\" TITLE=\"To Next Chapter\"";
  }

  if ($href eq "")
  {
    return "<B>$text</B>\n";
  }
  elsif ($href eq ".")
  {
    return "<A>$text</A>\n";
  }
  else
  {
    return "<A$rel HREF=\"$href\">$text</A>\n";
  }
}


#####################################
# read chapters.src & scan the rest #
#####################################
print STDERR "Scanning chapters...\n";

local $siteTitle;
local $siteSubtitle;
local $siteAuthor;
local $siteKeywords;
local $siteDescription;
local $siteLocation;

# There are two name spaces for labels:
# - modules = chapters and sections,
# - anchors

local @bookSections;	# ordered list of sections

local %bookSectionInfo;	# record for each section label with:
                        # - title: section title
			# - chapterList: ordered list of chapter labels
			# - mtime: last modified (max of contained chapters)

local %bookChapterInfo;	# record for each chapter label with:
                        # - title: chapter title
			# - section: label of containing section
			# - nextChapter: label of next chapter in this or next section
			# - prevChapter: label of previous chapter in this or previous section
			# - anchorList: ordered list of anchor labels
			# - mtime: last modified

local %bookAnchorInfo;	# record for each anchor label with:
                        # - type: one of ANCHORTYPE_*
			# - title: description of anchor
			# - chapter: chapter label
			# - section: section label
			# - level: numeric, 1 or more
                        # - line: position in the chapters's source file
                        # - references: number of references

local $bookLevels = 0;	# highest anchor level in all chapters of book
local $bookMTime = 0;   # latest last modified time


open TOC, "< chapters.src" or die "Error opening chapters.src for input: $!\n";
Keyword:
while (<TOC>)
{
  chop;
  last Keyword if /^$/;
  my ($keyword, $value) = split ": *";
  
  die "\nMissing value for keyword '$keyword' in chapters.src\n" unless defined $value;
  if ($keyword eq "TITLE")
  {
    $siteTitle = $value;
  }
  elsif ($keyword eq "SUBTITLE")
  {
    $siteSubtitle = $value;
  }
  elsif ($keyword eq "AUTHOR") 
  {
    $siteAuthor = $value;
  }
  elsif ($keyword eq "KEYWORDS")
  {
    $siteKeywords = $value;
  }
  elsif ($keyword eq "DESCRIPTION")
  {
    $siteDescription = $value;
  }
  elsif ($keyword eq "LOCATION")
  {
    $siteLocation = $value;
  }
  else
  {
    die "\nUnexpected keyword '$keyword' in chapters.src\n";
  }
}

die "chapters.src: missing keyword 'TITLE'\n" unless defined $siteTitle;
die "chapters.src: missing keyword 'SUBTITLE'\n" unless defined $siteSubtitle;
die "chapters.src: missing keyword 'AUTHOR'\n" unless defined $siteAuthor;
die "chapters.src: missing keyword 'KEYWORDS'\n" unless defined $siteKeywords;
die "chapters.src: missing keyword 'DESCRIPTION'\n" unless defined $siteDescription;
die "chapters.src: missing keyword 'LOCATION'\n" unless defined $siteLocation;

local $currentAnonymousAnchorNr = 0;
my $currentSection;
my $currentPrevChapter = "index";
my $currentSectionInfoRef;
my $currentLevel = 0;
while ( <TOC> )
{
  chop;
  my ($indented, $module, $title);
  if ( ($indented, $module, $title) = m/^(\s*)([^#]\S+)\s*(.*)/ ) # skip empty & comment lines
  {
    if (! $indented)
    { # new section:
      die "\nSection '$module' featured twice in chapters.src" if exists $bookSectionInfo{$module};
      $currentSection = $module;
      push @bookSections, $module;
      $bookSectionInfo{$module} = { title => $title, chapterList => [], mtime => 0 };
      $currentSectionInfoRef = $bookSectionInfo{$module};
    }
    else
    { # new chapter:
      die "\nChapter '$module' featured twice in chapters.src" if exists $bookChapterInfo{$module};
      my @currentChapterAnchorList = (); 
      my $source = "$module.src";
      my $mtime = FileModifiedTime($source);
      open SRC, "< $source" or print STDERR "Error opening $source for input: $!\n";
      while (<SRC>)
      {
	chop;
        my ($anchorType, $level, $label, $anchorTitle);
        if ( ($anchorType, $level, $label, $anchorTitle) = CheckAnchorDefinition($currentAnonymousAnchorNr) )
    	{
          if ($anchorType == $ANCHORTYPE_ERROR)
	  {
	    print STDERR "$source:$.: $anchorTitle\n";
	  }
          elsif ($anchorType == $ANCHORTYPE_FILE && exists $bookChapterInfo{$label})
	  {
	    print STDERR "$source:$.: label '$label' previously defined as chapter in chapters.src\n";
	  }
	  elsif (exists $bookAnchorInfo{$label})
	  {
	    print STDERR "$source:$.: label '$label' previously defined in $bookAnchorInfo{$label}->{chapter}.src\n";
	  }
	  else
	  {
	    if ($level > $currentLevel +1)
	    {
	      print STDERR "$source:$.: label '$label' at level $level inside $currentLevel\n";
	    }
	    $currentLevel = $level;
	    $bookAnchorInfo{$label} = { type => $anchorType, title => $anchorTitle, level => $level, section => $currentSection, chapter => $module, line => $., references => 0 };
	    push @currentChapterAnchorList, $label;
	    $bookLevels = $level if $bookLevels < $level;
	  }
        }
      }
      close SRC;

      $bookChapterInfo{$module} = { title => $title, anchorList => \@currentChapterAnchorList, section => $currentSection, prevChapter => $currentPrevChapter, mtime => $mtime };
      $bookChapterInfo{$currentPrevChapter}->{nextChapter} = $module;

      push @{ $currentSectionInfoRef->{chapterList} }, $module;
      $currentSectionInfoRef->{mtime} = $mtime if $currentSectionInfoRef->{mtime} < $mtime;

      $bookMTime = $mtime if $bookMTime < $mtime;
      $currentPrevChapter = $module;
    }
  }
}
close TOC;

print STDERR "Found $bookLevels levels\n";

#... local $moduleCount = scalar keys %bookModuleTitle;
#... my $progressModuleNum = 0;
#... print STDERR "___%";

##########################
# make .html per chapter #
##########################

$currentAnonymousAnchorNr = 0;
foreach $section (@bookSections)
{
  print STDERR "Creating chapters in section $section...\n";
  foreach $chapter ( @{ $bookSectionInfo{$section}->{chapterList} } )
  {
#print STDERR "\nchapter = $chapter\n";

    my $info = $bookChapterInfo{$chapter};
    my $title = $info->{title};
    my $pointers = HtmlForPointer("$info->{prevChapter}.html", "<")
                 . "$bar<TD>"
                 . HtmlForPointer("index.html", "^")
                 . "$bar<TD>"
                 . HtmlForPointer(defined $info->{nextChapter}?
                                  "$info->{nextChapter}.html" : "", ">");

    my $fh = OpenOut("../chapters/$chapter.html");
    PrintHtmlHead($fh, "chapters/$chapter.html", $title, "Page", $info->{mtime}, undef, $pointers);
    InitTOC($fh, "Contents:");
    PrintChapterTOC($fh, $chapter, "");
    ExitTOC($fh);
    PrintChapterContents($fh, $chapter, $chapter, "chapter", $title);
    PrintHtmlFoot($fh, "chapter", undef, $pointers);
#...    printf STDERR "\b\b\b\b%3d%%", 100*$progressModuleNum/$moduleCount;
#...    ++$progressModuleNum;
  }
}


############################
# list unrefernced anchors #
############################

foreach $anchor (keys %bookAnchorInfo)
{
    my %info = %{ $bookAnchorInfo{$anchor} };
    if ($info{type} == $ANCHORTYPE_NORMAL && $info{references} == 0)
    {
#	print STDERR "$info{chapter}.src:$info{line}: label '$anchor' not referenced\n";
    }
}





##########################
# make .html per section #
##########################

$currentAnonymousAnchorNr = 0;
foreach $section (@bookSections)
{
  print STDERR "Creating section $section...\n";

  my $info = $bookSectionInfo{$section};
  my $title = $info->{title};

  my $fh = OpenOut("../sections/$section.html");
  PrintHtmlHead($fh, "sections/$section.html", $title, "Page", $info->{mtime});
  InitTOC($fh, "Contents:");
  print $fh "Contents:<P>\n";
  foreach $chapter ( @{ $info->{chapterList} } )
  {
    print $fh "$bookChapterInfo{$chapter}->{title}\n";
    PrintChapterTOC($fh, $chapter, $section);
    print $fh "<BR>\n";
  }
  ExitTOC($fh);
  foreach $chapter ( @{ $info->{chapterList} } )
  {
    print $fh "<HR>\n";
    print $fh "<H2 ALIGN=center>$bookChapterInfo{$chapter}->{title}</H2>\n";
    PrintChapterContents($fh, $chapter, $section, "section", $bookChapterInfo{$chapter}->{title});
  }
  print $fh "</BODY></HTML>\n";
#...   printf STDERR "\b\b\b\b%3d%%", 100*$progressModuleNum/$moduleCount;
#...   ++$progressModuleNum;
}




######################
# make section index #
######################

{
  my $fh = OpenOut("../sections/index.html");
  PrintHtmlHead($fh, "sections/", $siteTitle, "Site", $bookMTime);
  print $fh "<P ALIGN=\"center\"><EM>$siteSubtitle</EM>\n" if $siteSubtitle;
  foreach $section (@bookSections)
  {
    print $fh "<H2><A HREF=\"$section.html\">$bookSectionInfo{$section}->{title}</A></H2>\n";
  }
  PrintHtmlFoot($fh, "section");
}


###########################
# make chapters index(es) #
###########################

sub indexName
{ #arg 0: level
  my $level = shift;
  return "index" . ($level == 0? "" : $level+1) . ".html";
}

my $firstChapter = $bookSectionInfo{$bookSections[0]}->{chapterList}->[0];

for $max_level (0..$bookLevels)
{
  my $lpointers = "";
  for $l (0..$bookLevels)
  {
    $lpointers .= HtmlForPointer($l == $max_level? "." : indexName($l),	$l+1);
  }
  $lpointers .= "levels";
  my $rpointers = HtmlForPointer("$firstChapter.html", ">");

  my $fh = OpenOut("../chapters/" . indexName($max_level));
  PrintHtmlHead($fh, "chapters/" . indexName($max_level), $siteTitle, "Site", $bookMTime, $lpointers, $rpointers);
  print $fh "<P ALIGN=\"center\"><EM>$siteSubtitle</EM>\n" if $siteSubtitle;

  print $fh "<TABLE><TR><TD>";
  foreach $section (@bookSections)
  {
    print $fh "<H2>$bookSectionInfo{$section}->{title}</H2>\n";
    foreach $chapter ( @{ $bookSectionInfo{$section}->{chapterList} } )
    {
      print $fh "<A HREF=\"$chapter.html\">$bookChapterInfo{$chapter}->{title}</A>\n";
      PrintChapterTOC($fh, $chapter, $chapter, $max_level);
      print $fh "<BR>\n";
    }
  }
  print $fh "</TABLE>\n";
  PrintHtmlFoot($fh, "chapter", undef, $rpointers);
}


{
  my $pointers = "<A REL=\"next\" TITLE=\"To First Page\" HREF=\"chapters/index.html\">"
      . HtmlForImgPtr("pictures/next.gif", "../") . "</A>\n";
  my $fh = OpenOut("../index.html");
  PrintHtmlHead($fh, "", $siteTitle, "Site", $bookMTime);
  print $fh "<P ALIGN=\"center\"><EM>$siteSubtitle</EM>\n" if $siteSubtitle;
  PrintChapterContents($fh, "index", "index");
#  PrintHtmlFoot($fh, undef, "nedstat.src", $pointers);
#  PrintHtmlFoot($fh, undef, undef, $pointers);
  PrintHtmlFoot($fh, undef, undef, undef);
}

print STDERR "Finished!\n";
