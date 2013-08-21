use v5.16;
use autodie;
use File::Slurp;
use File::Basename;
use Text::Template;
use constant {
        SRCDIR => './src/',
        TARDIR => './target/'
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
                   order => Text::Template->new(TYPE=>'STRING',SOURCE=>q[<ol>{my $comb;for my $l (@line){$comb .= '<li>'.$l.'</li>' };$comb}</ol>]),
                   unorder => Text::Template->new(TYPE=>'STRING',SOURCE=>q[<ul>{my $comb;for my $l (@line){$comb .= '<li>'.$l.'</li>' };$comb}</ul>]),
);

mkdir SRCDIR unless -d SRCDIR;
mkdir TARDIR unless -e TARDIR;

my %srcSet = map {$_, 1} glob(SRCDIR.'*.md');
my @files = keys %srcSet;
while (@files) {
    my $fname = shift @files;
    open(my $sfd, '<', $fname);
    open(my $tfd, '>', TARDIR.scalar fileparse $fname =~ s/md$/html/xmsr);

    my ($sectionMark, $orderMark, $unorderMark);
    my @sectionStack;
    while (<$sfd>) {
        chomp;
        my $line = $_;

        my @terms = $line =~ m/\[([^\]]*?)\]/xmsg;
        for my $term (@terms) {
            if (not -e $srcSet{$term.'.md'}) {
                write_file(SRCDIR.$term.'.md', 'new File');
                unshift @files, SRCDIR.$term.'.md',
            }
        }

        $line =~ s|\[([^\]]*?)\]|<a href="./$1.html">$1</a>|mxsg if @terms;

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
            push @sectionStack, $line;
            if ($line =~ /^$/) {
                say "@sectionStack";
                my $sectionType = $sectionMark ? 'section' :
                                  $orderMark   ? 'order'   :
                                  $unorderMark ? 'unorder' : die;
                say $tfd $templateMap{$sectionType}->fill_in(HASH => {line => [@sectionStack]});
                (@sectionStack, $sectionMark, $orderMark, $unorderMark) =();
            }
        }
    }
    close $sfd;
    close $tfd;
}
