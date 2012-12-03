#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Std;
use IPC::Open3;
use File::Spec;
use Symbol qw/gensym/;
use Storable;

# Data Locations
my $hashdir = "../data/hashes";
my $shashdir = "../data/summaryhashes";
my $indexdir = "../data/indices";
my $sindexdir = "../data/summaryindices";

# External Commands
my $dumpcmd = "./dumpindex";



# CODE
my (%opts);
getopts('ahsd:',\%opts);

if( scalar @ARGV < 2 or $opts{h}){
  print STDERR "Usage: $0 [-a] [-d <doc_id>] <queryid> <querystring>\n";
  print STDERR "\t-a Print all spans (default prints minspan)\n";
  print STDERR "\t-d <doc_id> Print only for matching document (default prints all)\n";
  print STDERR "\t-s Search through summaries, not documents\n";
  exit;
}

my ($the_queryid, $str) = @ARGV;

open(NULL, ">", File::Spec->devnull);


my $all;
$all = 1 if $opts{a};
my $onedoc;
$onedoc = $opts{d} if defined $opts{d};

my ($index,$docmapf,%docmap);

if ($opts{s}) {
  $index = $sindexdir . "/q$the_queryid/";
  $docmapf = $shashdir . "/q$the_queryid/docmap.hash";
} else {
  $index = $indexdir . "/q$the_queryid/";
  $docmapf = $hashdir . "/q$the_queryid/docmap.hash";
}
%docmap = %{retrieve($docmapf)};

my $pid = open3(gensym, \*PH, ">&NULL", "$dumpcmd ".$index." e \"#uw($str)\"");
<PH>; # Throw away first line
my $cdid = -1;
my ($minspan,$cstart,$cend);
# Find all documents matching string
while( <PH> ) {
  next unless (/(\d+) (\d+) (\d+) (\d+)/);
  my ($did,$start,$end,$span) = ($1,$3,$4,$4-$3);
  next if ($onedoc and ($onedoc ne $docmap{$did}));
  if ($all) {
    print $docmap{$did} . " $span $start $end\n";
    next;
  }
  if ($cdid != $did) {
    if ($cdid != -1) {
      print $docmap{$cdid} . " $minspan $cstart $cend\n";
    }
    $minspan = $span;
    $cstart = $start;
    $cend = $end;
    $cdid = $did;
  } else {
    if ($span < $minspan) {
      $minspan = $span;
      $cstart = $start;
      $cend = $end;
    }
  }
}
if ($cdid > 0) {
  print $docmap{$cdid} . " $minspan $cstart $cend\n";
}
waitpid($pid, 0);
close(NULL);
