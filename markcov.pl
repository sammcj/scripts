#!/usr/bin/env perl
use 5.010;
use strict;
use warnings qw(all);
 
use Carp qw(croak);
use String::Markov;
 
my $mc = String::Markov->new(
    order       => 1,
    split_sep   => qr{\s+}x,
    do_chomp    => 1,
);
 
my @cmd = qw(git -C git_tree/main log --no-merges --pretty=format:%s);
open(my $pipe, '-|', @cmd) or croak "pipe: $!";
$mc->add_sample($_)
    while <$pipe>;
close $pipe;
 
say join ' ' => $mc->generate_sample
    for 1 .. 20;
