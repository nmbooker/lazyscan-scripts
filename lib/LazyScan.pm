package LazyScan;

# libscalar-list-utils-perl liblist-moreutils-perl

use strict;
use warnings;
use File::Spec;
use File::Glob qw/:bsd_glob/;
use Fcntl qw/:flock SEEK_SET/;
use File::Basename;
use List::MoreUtils qw/uniq/;
use List::Util qw/sum/;


use Exporter::Easy (
    OK => [qw/
        scandir
        listbatch
        new_batchnum
        batchfmt
        file_batchnum
        parse_filename
        batches
        batch_size
        chunk_batches
    /],
);

sub file_size {
    my @stat = stat(shift);
    return $stat[7]    # the size is element 7
}

sub files_size { sum map { file_size($_) } @_ }

sub batch_size {
    my ($basedir, $batchnum) = @_;
    sum map { file_size($_) } listbatch($basedir, $batchnum)
}

sub split_with {
    # Based on MITHALDU's Array::Split::split_by (c) 2010 Christian Walde under DWTFYW public license v2
    my ($original, $chunk_invariant) = @_;

    # not hugely efficient, but doesn't need to be to save time vs doing it manually
    my @sub_arrays;
    for my $element ( @$original ) {
        push @sub_arrays, [] if !@sub_arrays;
        push @sub_arrays, [] unless $chunk_invariant->([@{$sub_arrays[-1]}, $element]);
        push @{ $sub_arrays[-1] }, $element;
    }
    return @sub_arrays;
}

sub chunk_batches {
    my ($basedir, $max_size, $start_batch) = @_;
    my @batches = grep { $_ >= $start_batch } batches($basedir);
    return split_with(\@batches => sub {
        my $chunk = shift;
        sum(map { batch_size($basedir, $_) } @$chunk) <= $max_size
    });
}

sub scandir {
    $ENV{SCANHOME} or File::Spec->catfile($ENV{HOME}, 'scan')
}

sub listbatch {
    my ($basedir, $batchnum) = @_;
    my $pattern = File::Spec->catfile(
        $basedir, sprintf('b%05d_p*.*', $batchnum));
    return bsd_glob($pattern, GLOB_CSH);
}

sub imgfiles {
    my ($basedir) = @_;
    my $pattern = File::Spec->catfile($basedir, 'b*.{png,pnm,pdf}');
    return bsd_glob($pattern, GLOB_CSH);
}

sub batches {
    my ($basedir) = @_;
    my @img = imgfiles($basedir);
    my @batches;
    for (@img) {
        $_ = basename($_);
        if (/b0*([1-9][0-9]*)(_p[0-9]*)\.*[^\/]*$/) {
            push @batches => $1;
        }
    }
    return uniq sort { $a <=> $b } @batches;
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

sub file_batchnum {
    my ($filename) = @_;
    return parse_filename($filename)->{batch};
}

sub parse_filename {
    my ($filename) = @_;
    my ($name, $path, $suffix) = fileparse($filename, qr/((\.[^.\s]+)+)$/);
    my ($batch, $page);
    if ($name =~ /^b0*([1-9][0-9]*)/) {
        $batch= $1;
    }
    if ($name =~ /p0*([1-9][0-9]*)$/) {
        $page= $1;
    }
    return {
        wholename => basename($filename),
        name => $name,
        path => $path,
        suffix => $suffix,
        stripped_suffix => $suffix =~ s/^\.*//r,
        batch => $batch,
        page => $page,
    }
}

1;
