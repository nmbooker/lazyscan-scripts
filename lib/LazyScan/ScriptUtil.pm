package LazyScan::ScriptUtil;

use strict;
use warnings;

use Exporter::Easy (
    OK => [qw/
        mutex
        is_even
        is_odd
        err
        errf
        lookup
        $lookup
    /],
);

use failures qw/lookup/;

sub mutex {
    my $count = 0;
    foreach my $opt (@_) {
        $count++ if $opt;
    }
    return $count <= 1;
}

sub is_even { $_[0] % 2 == 0 }
sub is_odd { $_[0] % 2 == 1 }

sub err {
    my $msg = shift;
    die "$0: Error: $msg\n";
}

sub errf {
    my ($fmt, @args) = @_;
    die sprintf("$0: Error: $fmt\n", @args);
}

sub lookup {
    my ($hash, $key, %options) = @_;
    return do {
        if (exists $hash->{$key}) {
            $hash->{$key}
        }
        elsif (exists $options{default}) {
            $options{default}
        }
        else {
            failure::lookup->throw({
                msg => "key doesn't exist: $key",
                payload => { key => $key },
            });
        }
    };
}

our $lookup = \&lookup;

1;
