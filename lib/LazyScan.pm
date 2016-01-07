package LazyScan;

use strict;
use warnings;
use File::Spec;
use File::Glob qw/:bsd_glob/;
use Fcntl qw/:flock SEEK_SET/;


use Exporter::Easy (
    OK => [qw/scandir listbatch new_batchnum batchfmt/],
);


sub scandir {
    $ENV{SCANHOME} or File::Spec->catfile($ENV{HOME}, 'scan')
}

sub listbatch {
    my ($basedir, $batchnum) = @_;
    my $pattern = File::Spec->catfile(
        $basedir, sprintf('b*%d_p*.{png,pnm,pdf}', $batchnum));
    return bsd_glob($pattern, GLOB_CSH);
}

sub new_batchnum {
    use autodie qw/:io/;
    my $nextbatch_path = File::Spec->catfile(scandir(), '.nextbatch');
    open my $bf, '+>>', $nextbatch_path;
    flock($bf, LOCK_EX);
    seek($bf, 0, SEEK_SET);
    my $nextnum = <$bf>;
    chomp $nextnum;
    $nextnum ||= 1;
    seek($bf, 0, SEEK_SET);
    truncate($bf, 0);
    say $bf ($nextnum + 1);
    flock($bf, LOCK_UN);
    return $nextnum;
}

sub batchfmt {
    my ($num, $format) = @_;
    return File::Spec->catfile(
        scandir(),
        'inbox',
        sprintf('b%05d_p%%03d.%s', $num, $format),
    );
}

1;
