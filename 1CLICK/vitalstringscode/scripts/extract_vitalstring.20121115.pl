#!/usr/bin/perl -W

use strict;
use warnings;
use Getopt::Std;

use XML::DOM;
#use Data::SExpression;
use Data::Dump qw(dump);
use UNIVERSAL 'isa';
use List::Util qw/max/;

use List::MoreUtils qw/any/;

print STDERR "++++++++++++++++++++ START '$0' ++++++++++++++++++++\n";

my %opts = ();
getopts('q:o:u',\%opts);
for(qw/s o/){ defined($_) or die "usage; $0 -q <querywords> -o <originals> [-u]"; }

# settings
my %querywords = map{lc($_)=>1}file2lines($opts{q});
my @ori_tokens = file2tokens($opts{o}, "\t");
my $sentIndex = (defined($opts{u})?1:0);

binmode(STDOUT, ":utf8");

# input
my $parser = new XML::DOM::Parser;
my $doc = $parser->parse(\*STDIN);

my @sentences = moveDownXML($doc->getDocumentElement, ["document","sentences"])->getElementsByTagName("sentence");
$sentIndex==0 or scalar(@sentences)==scalar(@ori_tokens) or die join(" vs ",scalar(@sentences),scalar(@ori_tokens))." $!";

my @olines = ();
for(my $i=0; $i<=$#sentences; $i++){
    my $sentence = $sentences[$i];

    my $sid = ($sentIndex?$ori_tokens[$i]->[0]:sprintf("I%03d",$i+1));
    my $ori_sent = $ori_tokens[$i]->[$sentIndex];

    my $parse_str = getText(moveDownXML($sentence,["parse"]));
    my $listtree = lisp2listtree($parse_str);
    if(!defined($listtree)){ print STDERR "what?\n"; }
    
    idLeaves_heightNodes($listtree,1);
    my $dep_hash = getDependencyHash(moveDownXML($sentence,["basic-dependencies"]));
    
    my @NPs = extractNodes($listtree, "NP",2);
    my @NP_leaves = map{[filterLeaves(\%querywords,extractLeaves($_))]}@NPs;
    my @leaves = filterLeaves(\%querywords,extractLeaves($listtree));
    
    # output here
    print join("\t",$sid,$ori_sent)."\n";
    my $VSID_header = $sid; $VSID_header=~s/^I/V/;
    my @VSs = leaves2VS(\@NP_leaves,\@leaves,$dep_hash);
    for(my $i=0; $i<=$#VSs; $i++){
	my $VS = $VSs[$i];
	my @outTokens = (sprintf("%s/%03d",$VSID_header,$i+1), lc($VS->[0]));
	if(scalar(@$VS)>1){ push(@outTokens,sprintf("DEP=%s%03d",$VSID_header,$VS->[1]+1)); }
	print join("\t",@outTokens)."\n";
    }
}

print STDERR "++++++++++++++++++++ FINISHED '$0' ++++++++++++++++++++\n";
exit(0);
sub file2lines{
    my ($file, $h) = @_;
    $h = {} unless defined $h;
    my @lines = ();
    open FILE, "<", $file or die "$!";
    binmode(FILE, $h->{encoding}) if defined $h->{encoding};
    while(my $l=<FILE>){
	chomp $l;
	$l =~ s/\r$//;
	push(@lines, $l);
    }
    close(FILE);
    return @lines;
}
sub file2tokens{
    my ($file, $delim, $token_count_per_line, $h) = @_;
    $h = {} unless defined $h;

    #print STDERR "file2token on file '$file'\n";
    open FILE, "<", $file or die "Invalid file: '$file'\n $!";
    binmode(FILE, $h->{encoding}) if defined $h->{encoding};
    my @tokens = ();
    while(my $l=<FILE>){
	chomp $l;
	my @F = map{chomp; $_}(defined($delim)?(split /$delim/, $l):(split /\s+/, $l));
	if(defined($token_count_per_line)){
	    scalar(@F)==$token_count_per_line
		or die "line should have $token_count_per_line tokens\n";
	}
	push(@tokens, \@F);
    }
    close(FILE);
    return @tokens;
}

sub filterLeaves{
    my ($ignorewords,@leaves) = @_;
    my @ignoretags = qw/DT IN TO VBP MD POS/;
    #print dump($ignorewords)."\n";
    #exit(0);
    return #grep{$_->[1]=~/^\w+$/}
    grep{!defined($ignorewords->{lc($_->[1])})}
    grep{$_->[0]=~/^\w+$/}
    grep{!isIn($_->[0],@ignoretags)}
    @leaves;
}
sub extractLeaves{
    my ($listtree) = @_;
    my @l = @$listtree;
    return ($listtree) if $l[$#l-1] eq 'L';

    my @rs = ();
    for my $child (@$listtree){
	next if(!isa($child,'ARRAY'));
	push(@rs, extractLeaves($child));
    }
    return @rs;
}

sub moveDownXML{
    my ($root, $branches,$opts) = @_;

    # should be passed in through "$opts" but implement later
    die "not implemented yet" if defined($opts);
    my $childIndex=0;
    my $childCount=1;

    my $node = $root;
    for my $b (@$branches){
	my @children = $node->getElementsByTagName($b);
	die "Invalid childcount of '".$node->getNodeName."': ".scalar(@children)." vs $childCount"
	    unless scalar(@children)==$childCount;
	$node = $children[$childIndex];
    }
    return $node;
}

sub getText{
    my ($node) = @_;
    my @textnodes = grep{$_->getNodeType==TEXT_NODE}(@{$node->getChildNodes});
    scalar(@textnodes)==1 or die "$!";
    return $textnodes[0]->getNodeValue;
}

sub lisp2listtree{
    my ($s)=@_;
    $s=~s/'/\\'/g;
    $s=~s/([^() ]+)/'$1'/g;
    $s=~s/,/,/g;
    $s=~s/\././g;
    $s=~s/ /,/g;
    $s=~s/\(/[/g;
    $s=~s/\)/]/g;
    #print STDERR "$s\n";
    return eval($s);
}
sub idLeaves_heightNodes{
    my ($listtree,$i) = @_;
    my $hasChildList = 0;
    my $height=0;
    for my $child (@$listtree){
	next if(!isa($child,'ARRAY'));
	$hasChildList=1;
	my $h;
	($i,$h)=idLeaves_heightNodes($child,$i);
	$height = max($height,$h);
    }
    $height++;
    if($hasChildList){ push(@$listtree,'N',$height); }
    else{ push(@$listtree,'L',$i++); }
    return ($i,$height);
}


sub extractNodes{
    my ($listtree,$name,$height) = @_;
    my @l = @$listtree;
    return ($listtree) if($l[0] eq $name && $l[$#l-1] eq 'N' && $l[$#l]==2);

    my @rs = ();
    for my $child (@l){
	next if(!isa($child,'ARRAY'));
	push(@rs, extractNodes($child,$name,$height));
    }
    return @rs;
}

sub getDependencyHash{
    my ($root) = @_;
    my %h = ();
    for my $dep ($root->getElementsByTagName("dep")){
	my $g = moveDownXML($dep,["governor"])->getAttribute("idx");
	my $d = moveDownXML($dep,["dependent"])->getAttribute("idx");
	die "$!" if defined($h{$d});
	$h{$d}= $g;
    }
    return \%h;
}
sub isIn{ my ($e,@l)=@_;  return any{$e eq $_}@l; }
sub leaves2VS{
    my ($NP_leaves,$leaves,$dep_hash) = @_;
    my @VSs = ();
    my %token2VSindex = ();

    foreach my $NP (@$NP_leaves){
	next if scalar(@$NP)==0;
	push(@VSs,[join(" ",map{$_->[1]}@$NP)]);
	for(@$NP){ $token2VSindex{$_->[3]}=$#VSs; }
    }

    my @uncovered_leaves = grep{!defined($token2VSindex{$_->[3]})}@$leaves;
    for(@uncovered_leaves){
	push(@VSs, [$_->[1]]);
	$token2VSindex{$_->[3]}=$#VSs;
    }
    # add dependencies
    for( (map{@$_}@$NP_leaves), @uncovered_leaves){
	my $id = $_->[3];
	my $VSindex = $token2VSindex{$id};
	my $parent = $dep_hash->{$id};
	next unless defined($parent);
	next unless defined($token2VSindex{$parent});
	next if $VSindex==$token2VSindex{$parent}; # if referring to self
	push(@{$VSs[$VSindex]}, $token2VSindex{$parent});
    }
    return @VSs;
}
