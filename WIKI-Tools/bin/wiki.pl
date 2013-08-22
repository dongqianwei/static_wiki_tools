use v5.16;
use autodie;
use File::Slurp;
use File::Basename;
use Text::Template;
use Storable;
use Data::Dump 'dump';
use subs qw(_gettoken init _processSrc _getSrc);
use constant {
        SRCDIR   => './src/',
        TARDIR   => './target/',
        METADATA => 'data.bin',
    };

my %specTokens = (
        '#'   => 'h1',
        '##'  => 'h2',
        '###' => 'h3',
        '___' => 'line',
);

my $headRe = qr/^(#+|___)\s*/;

my %templateMap = (
                   h1 => Text::Template->new(TYPE=>'STRING',SOURCE=>'<h1>{$line}</h1>'),
                   h2 => Text::Template->new(TYPE=>'STRING',SOURCE=>'<h2>{$line}</h2>'),
                   h3 => Text::Template->new(TYPE=>'STRING',SOURCE=>'<h3>{$line}</h3>'),
                   line => Text::Template->new(TYPE=>'STRING',SOURCE=>'<hr/>'),
                   section => Text::Template->new(TYPE=>'STRING',SOURCE=>'<p>{"@line"}</p>'),
                   order => Text::Template->new(TYPE=>'STRING',
                                                SOURCE=>q[<ol>{my $comb;for my $l (@line){$comb .= '<li>'.$l.'</li>' };
                                                  $comb}</ol>]),
                   unorder => Text::Template->new(TYPE=>'STRING',
                                                  SOURCE=>q[<ul>{my $comb;for my $l (@line){$comb .= '<li>'.$l.'</li>' };
                                                  $comb}</ul>]),
);

sub init {
    do{mkdir SRCDIR;write_file(_getSrc('index'), "# welcome to use static wiki")} unless -d SRCDIR;
    mkdir TARDIR unless -e TARDIR;
}

init();

my @files = glob(SRCDIR.'*.md');

#get metadata
my $metaref = {};$metaref = retrieve METADATA if -e METADATA;

#grep modified files
@files = grep {(stat $_)[9] != $metaref->{terms}{$_}{modify}} @files if keys %{$metaref};
say "last modified files: @files";
say "new terms waited for edited:".join ',',keys %{$metaref->{newterms}};
#if modified, remove from newterms
delete $metaref->{newterms}{$_} for map {_gettoken $_} @files;
#update modified time
$metaref->{terms}{$_}{modify} = (stat $_)[9] for @files;

while (@files) {
    my $fname = shift @files;
    my $token = _gettoken $fname;
    my @terms = _processSrc $fname;
    #new terms in current line
    @terms = map {_gettoken $_} grep {!exists $metaref->{terms}{$_}} map {_getSrc $_} @terms;
    for my $term (@terms) {
        say "add new term :$term";
        my $srcFileName= _getSrc $term;
        write_file($srcFileName, "### this is a new token, back to :[$token]");
        #record new created terms;
        $metaref->{newterms}{$term} = 1;
        $metaref->{terms}{$srcFileName}{modify} = (stat $srcFileName)[9];
        unshift @files, $srcFileName,
    }
}

sub _gettoken {
    my $fname = shift;
    (fileparse $fname) =~ s/(.*)\.md/$1/r;
}

sub _getSrc {
    my $token = shift;
    SRCDIR.$token.'.md';
}

sub _processSrc {
    my $fname = shift;
    open(my $sfd, '<', $fname);
    open(my $tfd, '>', TARDIR.scalar fileparse $fname =~ s/md$/html/xmsr);
    say $tfd '<html><body>';

    my ($sectionMark, $orderMark, $unorderMark);
    my @terms;
    my @sectionStack;
    while (<$sfd>) {
        chomp;
        my $line = $_;
        #collect terms in current line
        unshift @terms, @{[$line =~ m/\[([^\]]*?)\]/xmsg]};
        #change term to link
        $line =~ s|\[([^\]]*?)\]|<a href="./$1.html">$1</a>|mxsg;

        #process line prefix
        if ($sectionMark+$orderMark+$unorderMark == 0) {
            my ($mode) = $line =~ $headRe;
            if ($mode) {
                my $temp = $templateMap{$specTokens{$mode}};
                $line =~ s/$headRe//;
                $line = $temp->fill_in(HASH => {line => $line});
                say $tfd $line;
            }
            elsif (!$line =~ /^$/) {
                $line =~ /^\+/ ? $orderMark   = 1:
                $line =~ /^\*/ ? $unorderMark = 1:
                                 do{$sectionMark = 1, push @sectionStack, $line};
		    }
        }
        else {
            if ($line =~ /^$/) {
                my $sectionType = $sectionMark ? 'section' :
                                  $orderMark   ? 'order'   :
                                  $unorderMark ? 'unorder' : die;
                say $tfd $templateMap{$sectionType}->fill_in(HASH => {line => [@sectionStack]});
                (@sectionStack, $sectionMark, $orderMark, $unorderMark) =();
            }
            else {
                push @sectionStack, $line;
            }
        }
    }
    say $tfd '</body></html>';
    close $sfd;
    close $tfd;
    @terms;
}

say dump $metaref;
store $metaref, METADATA;
