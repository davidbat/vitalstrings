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

my %opts = ();
getopts('d:s:q:P:fT:O:g',\%opts);
for(qw/d s P T o/){ defined($_) or die "usage; $0 -d <data_list> -s <stopwords> -q <query.tsv> -P <parser> -T <tmp_folder> -O <out_folder> [-u]"; }

# settings
my $tmp = $opts{T};
my $out = $opts{O};
my $iunitInData = defined($opts{u});
my $parser_out = "$tmp/STANFORD/output";

# input
#my %fileid2iunits = ();
my @sentence_files = ();


#exit(0);
# stanford parser
my $jarpath = join(":",'stanford-corenlp-2012-07-06-models.jar','xom.jar','joda-time.jar','stanford-corenlp-2012-07-09.jar');
lines2file("$tmp/files", {}, map{"../$_"}@sentence_files );
my $cmd = "cd $opts{P} && java -cp $jarpath edu.stanford.nlp.pipeline.StanfordCoreNLP -props $opts{p} -filelist ../$tmp/files -outputDirectory ../$parser_out";
print STDERR "$cmd\n";
system($cmd)==0 or die "$!";

my %fileid2query = undef;
if(defined($opts{q})){ %fileid2query=map{($_->[0])=>($_->[2])} file2tokens($opts{q}, "\t"); }
my @stopwords = file2lines($opts{s});

foreach my $fileid (sort keys %fileid2iunits){
    print STDERR "processing '$fileid'\n";

    my %ignorewords = map{$_=>1}@stopwords;
    if(defined($opts{q})){
	die "$fileid ".join(" ",keys %fileid2query)."\n"
	    unless defined($fileid2query{$fileid});

	my @queries = map{lc}(split /\s+/, $fileid2query{$fileid});
	for(@queries){ $ignorewords{$_}=1; }
    }
    my $parseXML = "$parser_out/$fileid.sentences.xml";
    lines2file("$out/$fileid.out", {},stanford2result($fileid2iunits{$fileid}, \%ignorewords, $parseXML));
}

exit(0);


sub extractText{
    my ($file) = @_;
    my @sentence_files=();

    open FILE, "<", $file or die "$!";
    while(my $l=<STDIN>){
	chomp $l;
	my @F = split /\s+/, $l;
	scalar(@F)==2 or die "Invalid line '$l'\n";
    
	my ($fileid,$file) = @F;
	my $sentence_file = $file;

	if($iunitInData){
	    $sentence_file = "$tmp/STANFORD/input/$fileid.sentences";
		
	    my @iunits = file2tokens($file, "\t");
	    my @lines = map{my $s=$_->[1]; $s=~s/(\.)?\s*$/.\n/; $s}@iunits;
	    lines2file($sentence_file, {}, @lines);
	}
	push(@sentence_files, $sentence_file);
    }
    close(FILE);
    return @sentence_files;
}


sub stanford2result{
    my ($iunits,$ignorewords,$parseXML) = @_;

    my $doc = xmlfile2doc($parseXML);
    my @sentences = moveDownXML($doc->getDocumentElement, ["document","sentences"])->getElementsByTagName("sentence");
    scalar(@sentences)==scalar(@$iunits) or die join(" vs ",scalar(@sentences),scalar(@$iunits))." $!";

    my @olines = ();
    for(my $i=0; $i<=$#sentences; $i++){
	my $sentence = $sentences[$i];
	my $iunit = $iunits->[$i];
	my $parse_str = getText(moveDownXML($sentence,["parse"]));
	my $listtree = lisp2listtree($parse_str);
	if(!defined($listtree)){ print STDERR "what?\n"; }

	idLeaves_heightNodes($listtree,1);
	my $dep_hash = getDependencyHash(moveDownXML($sentence,["basic-dependencies"]));

	my @NPs = extractNodes($listtree, "NP",2);
	my @NP_leaves = map{[filterLeaves($ignorewords,extractLeaves($_))]}@NPs;
	my @leaves = filterLeaves($ignorewords,extractLeaves($listtree));

	# output here
	push(@olines,join("\t",@{$iunit}[0,1]));
	my $VSID_header = $iunit->[0]; $VSID_header=~s/^I/V/;
	my @VSs = leaves2VS(\@NP_leaves,\@leaves,$dep_hash);
	for(my $i=0; $i<=$#VSs; $i++){
	    my $VS = $VSs[$i];
	    my @outTokens = (sprintf("%s%03d",$VSID_header,$i+1), lc($VS->[0]));
	    if(scalar(@$VS)>1){ push(@outTokens,sprintf("DEP=%s%03d",$VSID_header,$VS->[1]+1)); }
	    push(@olines,join("\t",@outTokens));
	}
    }
    return @olines;
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

sub isIn{ my ($e,@l)=@_;  return any{$e eq $_}@l; }
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

sub getText{
    my ($node) = @_;
    my @textnodes = grep{$_->getNodeType==TEXT_NODE}(@{$node->getChildNodes});
    scalar(@textnodes)==1 or die "$!";
    return $textnodes[0]->getNodeValue;
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

sub xmlfile2doc{
    my ($file) = @_;
    my $parser = new XML::DOM::Parser;
    return $parser->parsefile($file);
}

sub hash2str{
    my ($h,$d1,$d2) = @_;
    $d1=" " if !defined($d1); $d2="\n" if !defined($d2);
    return join($d2,
	 map{ my $k = $_;
	      join($d1,map{"'$_'"}($k, $h->{$k}))
	 }(keys %$h));
}

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

sub lines2file{
    my ($file,$h,@lines) = @_;
    $h = {} unless defined $h;

    open FILE, ">", $file or die "$!";
    binmode(FILE,$h->{encoding}) if defined $h->{encoding};
    for my $line (@lines){
	print FILE "$line\n";
    }
    close(FILE);
}
