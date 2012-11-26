#!/usr/bin/perl
use strict;
use warnings;
use File::Path qw/make_path/;
use File::Basename;

my $if = $ARGV[0];
my $od = "/huge1/people/mattea/1click/data/summarydocuments/";

my $runn = basename($if,".tsv");
open (I,"<:encoding(UTF-8)",$if);
print "$runn\n";

while (<I>) {
  chomp;
  my @r = split(/\t+/);
  next unless ($r[1] and $r[1] eq "OUT");
  next unless ($r[2]);
  my $q = $r[0];
  $q =~ s/.*-//;
  my $cod = "$od/q$q";
  make_path($cod);
  open(O,">:encoding(UTF-8)","$cod/$runn.txt") or die "Can't open: $!";
  print O $r[2] . "\n";
  close(O);
};
close(I);
