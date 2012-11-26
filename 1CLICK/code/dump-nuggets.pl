#!/usr/bin/perl
use strict;
use warnings;
use DBI;

die "$0 Query_ID\nWill output nuggets to stdout in tsv format" unless (@ARGV == 1);
my $queryid = $ARGV[0];
my $qid;

if ($queryid =~ /^1C2-[^\-]-[^\-]+-(\d+)$/) {
  $qid = $1;
} elsif ($queryid =~ /^\d+$/) {
  $qid = $queryid;
} else {
  die "Bad Query ID. Should be e.g. 0023 or 1C2-E-TEST-0023";
}

# MySQL CONFIG VARIABLES
my $dbhost = "fiji11";
my $dbdb = "ntcir_nuggets";
my $dbuser = "ntcir_nug";
my $dbpw = "IRUeTQnT+8HvRlzU";
my $dbh;

$dbh = DBI->connect("dbi:mysql:$dbdb:$dbhost",$dbuser,$dbpw) ||
  die ("Connection error: $DBI::errstr\n");

my $sth = $dbh->prepare("SELECT nugget_id,nugget_text FROM nugget where query_id = ? and rel = 1");
my $success = $sth->execute($qid);
my $i = 1;
while (my @row = $sth->fetchrow_array) {
  printf("I%03d\t%s\t%s\n",$i++,$row[1],$row[0]);
}
