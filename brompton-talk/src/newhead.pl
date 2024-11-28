eval 'exec perl -w $0'          # set emacs major mode: -*-Perl-*-
  if not "running under perl";

sub FileModifiedTime ($) {
  my ($file) = @_;
  my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat $file or die "\nerror accessing file $file: $!\n";
  return $mtime;
}
                      
foreach $file (@ARGV) {
  if ($file neq "chapters.src") {
    my $time = FileModifiedTime($file);
    my $out = $file;
    die unless $out =~ s/\.src/.new/;
    open IN, "<$file";
    open OUT, ">$out";
    print OUT "<!--*-html-*--><!DOCTYPE HTML SYSTEM><HTML><HEAD><TITLE></TITLE></HEAD><BODY>\n";
    while (<IN>) {
      print OUT unless m|-\*-html-\*-| or m|<!DOCTYPE HTML SYSTEM><HTML><HEAD><TITLE></TITLE></HEAD><BODY>|;
    }
    close IN;
    close OUT;
    utime $time, $time, $out;
  }
}
