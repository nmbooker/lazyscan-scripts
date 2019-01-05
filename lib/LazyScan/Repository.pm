package LazyScan::Repository;
# TODO: Rename to LazyScan::Box

use v5.10;
use strict;
use warnings;
use File::Spec;
use Fcntl qw/:flock SEEK_SET/;
use LazyScan;
use LazyScan::ScriptUtil qw/$lookup/;

use Moo;

has scanhome => (
    is => 'ro',
    default => sub {$ENV{SCANHOME} or File::Spec->catfile($ENV{HOME}, "/scan")},
);

has inbox => (is => 'ro', default => sub { 'inbox' });

sub inbox_path {
    my ($self) = @_;
    return File::Spec->catfile($self->scanhome, $self->inbox);
}

sub batchfmt {
    my ($self, $num, $format) = @_;
    return File::Spec->catfile(
        $self->inbox_path,
        sprintf('b%05d_p%%03d.%s', $num, $format),
    );
}

sub new_batchnum {
    my ($self, %opts) = @_;
    use autodie qw/:io/;
    my $nextbatch_path = File::Spec->catfile($self->inbox_path, '.nextbatch');
    open my $bf, '+>>', $nextbatch_path;
    flock($bf, LOCK_EX);
    seek($bf, 0, SEEK_SET);
    my $nextnum = <$bf>;
    chomp $nextnum;
    $nextnum ||= 1;
    my $should_increment = (\%opts)->$lookup('increment', default => 1);
    if ($should_increment) {
        seek($bf, 0, SEEK_SET);
        truncate($bf, 0);
        say $bf ($nextnum + 1);
    }
    flock($bf, LOCK_UN);
    return $nextnum;
}


# TODO: list of boxes, on a new LazyScan::Repository class
# sub boxes {
    
# }

1;
