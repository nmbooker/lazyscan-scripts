package LazyScan;

use strict;
use warnings;

use Exporter::Easy (
    OK => [qw/scandir/],
);


sub scandir {
    $ENV{SCANHOME} or File::Spec->catfile($ENV{HOME}, 'scan')
}

1;
