package LazyScan::Locking;

use strict;
use warnings;
use File::Spec::Functions qw/catfile/;
use LockFile::Simple;
use failures qw/lazyscan::dirlock/;
use Try::Tiny;

use Exporter::Easy (
    OK => [qw/
        with_dir_locked
    /],
);

sub with_dir_locked {
    my %params = @_;
    my $code = $params{do};
    my $dir = $params{dir};
    my $lockmgr = LockFile::Simple->make(
        -autoclean => 1, -warn => 1, -format => '%f/.lock' );
    my $lock = $lockmgr->trylock($dir) or do {
        failure::lazyscan::dirlock->throw("Could not lock $dir");
    };
    try {
        $code->()
    }
    catch {
        $lock->release;
        die $_;
    };
    $lock->release;
}

1;
