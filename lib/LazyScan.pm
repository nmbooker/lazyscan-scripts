package LazyScan;

use strict;
use warnings;
use File::Spec;
use File::Glob qw/:bsd_glob/;

use Exporter::Easy (
    OK => [qw/scandir listbatch/],
);


sub scandir {
    $ENV{SCANHOME} or File::Spec->catfile($ENV{HOME}, 'scan')
}

sub listbatch {
    my ($basedir, $batchnum) = @_;
    my $pattern = File::Spec->catfile(
        $basedir, sprintf('b*%d_p*.{png,pnm}', $batchnum));
    my @match = bsd_glob($pattern, GLOB_CSH);

}

1;
