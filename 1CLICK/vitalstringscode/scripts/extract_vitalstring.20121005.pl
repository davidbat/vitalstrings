#!/usr/bin/perl -W

use strict;
use warnings;
use Getopt::Std;

use XML::DOM;
use Data::SExpression;
use Data::Dump qw(dump);
use UNIVERSAL 'isa';
use List::Util qw/max min/;

use List::MoreUtils qw/any/;

my %opts = ();
getopts('s:q:P:fT:O:',\%opts);
for(qw/s q P T o/){ defined($_) or die "usage; $0 -s <stopwords> -q <query.tsv> -P <parser> -T <tmp_folder> -O <out_folder>"; }

# settings
my $tmp = $opts{T};
my $out = $opts{O};
my $parser_out = "$tmp/parser";

# input
my %fileid2iunits = ();
my @sentence_files = ();

while(my $l=<STDIN>){
    chomp $l;
    my @F = split /\s+/, $l;
    scalar(@F)==2 or die "Invalid line '$l'\n";
    
    my ($fileid,$file) = @F;
    my @iunits = file2tokens($file, "\t");
    my $sentence_file = "$tmp/$fileid.sentences";
    lines2file($sentence_file, {}, map{my $s=$_->[1]; $s=~s/(\.)?\s*$/.\n/; $s}@iunits );
    push(@sentence_files, $sentence_file);
    $fileid2iunits{$fileid}=\@iunits;
}

#exit(0);
# stanford parser
my $jarpath = join(":",'stanford-corenlp-2012-07-06-models.jar','xom.jar','joda-time.jar','stanford-corenlp-2012-07-09.jar');
lines2file("$tmp/files", {}, map{"../$_"}@sentence_files );
my $cmd = "cd $opts{P} && java -cp $jarpath edu.stanford.nlp.pipeline.StanfordCoreNLP -props parser.properties -filelist ../$tmp/files -outputDirectory ../$parser_out";
print STDERR "$cmd\n";
#system($cmd)==0 or die "$!";

my %fileid2query = map{($_->[0])=>($_->[2])} file2tokens($opts{q}, "\t");
my @stopwords = file2lines($opts{s});

foreach my $fileid (sort keys %fileid2iunits){
    print STDERR "processing '$fileid'\n";
    die "$fileid ".join(" ",keys %fileid2query)."\n"
	unless defined($fileid2query{$fileid});

    my @queries = map{lc}(split /\s+/, $fileid2query{$fileid});
    my %ignorewords = map{$_=>1}(@queries,@stopwords);
    my $parseXML = "$parser_out/$fileid.sentences.xml";
    #stanford2result($fileid2iunits{$fileid}, \%ignorewords, $parseXML);
    lines2file("$out/$fileid.out", {},stanford2result($fileid2iunits{$fileid}, \%ignorewords, $parseXML));
    #last;
}

exit(0);


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
	my ($tree,$wordID) = listtree2tree(lisp2listtree($parse_str),undef,1,0);
	#print STDERR "TREE: ".dump($tree)."\n";
	defined($tree) or die "What?";
	#print STDERR dump($tree)."\n";

	#for my $leaf (getLeaves($tree)){
	#    print STDERR join(" ",map{$leaf->{$_}}(qw/leafID POS text/))."\n";
	#}

	#setLeafIDNnodeHeight($listtree,1);
	my $dep_hash = getDependencyHash(moveDownXML($sentence,["basic-dependencies"]));
	push(@olines, tree2olines($tree,$ignorewords,$iunit,$dep_hash));
	#last;
    }
    return @olines;
}

sub getLeaves{
    my ($node) = @_;
    my @children = @{$node->{'children'}};
    #print STDERR "CHILDREN: ".dump(@children)."\n";
    if(scalar(@children)==0){ return ($node); }
    my @leaves = map{getLeaves($_)}@children;
    return @leaves;
}

sub mergeNodes{
    my ($depth,@nodes) = @_;
    #print STDERR "mergeNodes() - $depth ".dump(@nodes)."\n";
    #print STDERR join(" ",map{$_->{'parent'}{'POS'} }@nodes)."\n";
    #exit(0) if $depth==8;

    if($depth==0){ return (0,@nodes); }

    my %h_nodes = map{$_=>1}@nodes;
    my @merged = ();
    my %isParentMerged = ();
    my %seen = ();
    for my $n (@nodes){	
	unless( ($n->{'POS'}) =~ /^\p{PosixAlpha}+$/ ){ next; }
	if($n->{'POS'} eq "IN"){ next; }

	if($n->{'depth'} != $depth){ push(@merged,$n); next;}

	my $p = $n->{'parent'};
	if(defined $seen{$p}){
	    if(! defined($isParentMerged{$p}) ){ push(@merged, $n); }
	    next;
	}
	$seen{$p}=1;

	my @siblings = @{$p->{'children'}};
	if(grep{
	    !defined($h_nodes{$_})
		or !($_->{'POS'}=~/^\p{PosixAlpha}+$/)
		or ($_->{'POS'} eq "IN")
	   }@siblings){ push(@merged,$n); next; }

	push(@merged,$p);
	$isParentMerged{$p}=1;
    }

    return mergeNodes($depth-1, @merged);
}

sub getValidString{
    my ($node,$ignorewords) = @_;
    my %ignoretags = map{$_=>1}(qw/DT IN TO MD POS/);

    return join(" ",
		map{ $_->{'text'} }
		grep{ !defined($ignorewords->{lc($_->{'text'})}) }
		grep{ !defined($ignoretags{lc($_->{'POS'})}) }
		getLeaves($node));
    
}

sub tree2olines{
    my ($tree,$ignorewords,$iunit,$dep_hash) = @_;
    my @leaves = getLeaves($tree);
    #print STDERR join(" ",map{"'".($_->{'text'})."'"}@leaves)."\n";
    #print STDERR max(map{$_->{'depth'}}@leaves)."\n";
    #exit(0);
    my ($depth,@merged) = mergeNodes( max(map{$_->{'depth'}}@leaves), @leaves );
    my @nodes = sort{$a->{'wordID'}<=>$b->{'wordID'}}@merged;

    # output here
    #my @olines = (join("\t",@{$iunit}[0,1]));
    my $VSID_header = $iunit->[0]; $VSID_header=~s/^I/V/;
    #my @VSs = leaves2VS(\@NP_leaves,\@leaves,$dep_hash);
    return (
	join("\t",@{$iunit}[0,1]),
	map{
	    join("\t",sprintf("%s%03d",$VSID_header,$_+1), getValidString($nodes[$_]))
	}(0..$#nodes)
	);
    #return @olines;

    # output here
    #my @olines = (join("\t",@{$iunit}[0,1]));
    #my $VSID_header = $iunit->[0]; $VSID_header=~s/^I/V/;
    #my @VSs = leaves2VS(\@NP_leaves,\@leaves,$dep_hash);
    #for(my $i=0; $i<=$#VSs; $i++){
	#my $VS = $VSs[$i];
	#my @outTokens = (sprintf("%s%03d",$VSID_header,$i+1), lc($VS->[0]));
	#if(scalar(@$VS)>1){ push(@outTokens,sprintf("DEP=%s%03d",$VSID_header,$VS->[1]+1)); }
	#push(@olines,join("\t",@outTokens));
    #}
    #return ();
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
    my ($listtree,$name,$depth) = @_;
    my @l = @$listtree;
    return ($listtree) if($l[0] eq $name && $l[$#l-1] eq 'N' && $l[$#l]==2);

    my @rs = ();
    for my $child (@l){
	next if(!isa($child,'ARRAY'));
	push(@rs, extractNodes($child,$name,$depth));
    }
    return @rs;
}

sub setLeafIDNnodeHeight{
    my ($listtree,$i) = @_;
    my $hasChildList = 0;
    my $height=0;
    for my $child (@$listtree){
	next if(!isa($child,'ARRAY'));
	$hasChildList=1;
	my $h;
	($i,$h)=setLeafIDNnodeHeight($child,$i);
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

sub listtree2tree{
    my ($listtree,$parent,$wordID,$depth) = @_;
    my $pos = ($listtree->[0]);
    #print STDERR "Listtree: ".dump($listtree)."\n";
    #print STDERR "Listtree: '$pos'\n";
    #print STDERR dump($listtree->[1])."\n";
    my $node ={'POS'=>$pos,'parent'=>$parent, 'isLeaf'=>(!isa($listtree->[1],'ARRAY')), 'depth'=>$depth };

    if($node->{'isLeaf'}){
	#print STDERR $listtree->[0]." is a LEAF\n";
	$node->{'text'} = $listtree->[1];
	$node->{'wordID'} = $wordID++;
	$node->{'height'} = 0;
	$node->{'children'} = [];
	return ($node,$wordID);
    }

    my @children = ();
    my $n = scalar(@$listtree);
    for my $i (1..($n-1)){
	my $child;
	($child, $wordID) = listtree2tree($listtree->[$i],$node,$wordID,$depth+1);
	push(@children, $child);
    }
    $node->{'children'} = \@children;
    $node->{'height'} = max(map{$_->{'height'}}@children)+1;
    $node->{'wordID'} = min(map{$_->{'wordID'}}@children);
    return ($node,$wordID);
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
