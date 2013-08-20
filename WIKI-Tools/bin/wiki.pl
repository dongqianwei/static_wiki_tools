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
                   section => Text::Template->new(TYPE=>'STRING',SOURCE=>'<p>{$line}</p>'),
                   );

mkdir SRCDIR unless -d SRCDIR;
mkdir TARDIR unless -e TARDIR;

my %srcSet = map {$_, 1} glob(SRCDIR.'*.md');
my @files = keys %srcSet;
while (@files) {
    my $fname = shift @files;
    open(my $sfd, '<', $fname);
    open(my $tfd, '>', TARDIR.scalar fileparse $fname =~ s/md$/html/xmsr);

    my $sectionMark;
    my @sectionStack;
    while (<$sfd>) {
        chomp;
        my $line = $_;

        my $tLine;
        my @terms = $line =~ m/\[([^\]]*?)\]/xmsg;

        #process line prefix
        my ($mode) = $line =~ $headRe;
        say "mode $mode; line: $line";
        if ($mode and !$sectionMark) {
            my $temp = $templateMap{$specTokens{$mode}};
            $tLine = $line =~ s/$headRe//r;
            $tLine = $temp->fill_in(HASH => {line => $tLine});
        }
        else {
                $tLine = $line;
                $sectionMark = 1 unless $line =~ m/^$/msx;
        }

        #process terms
        $tLine =~ s|\[([^\]]*?)\]|<a href="./$1.html">$1</a>|mxsg if @terms;
        $sectionMark = 0 if $tLine =~ m/^$/xsm;
        say "blank line $." if $tLine =~ m/^$/xsm;;
        if ($sectionMark) {
                push @sectionStack, $tLine;
        }
        else {
            if (@sectionStack) {
                say $tfd $templateMap{section}->fill_in(HASH => {line => join ' ', @sectionStack});
                @sectionStack = ();
            }
            else {
                say $tfd $tLine;
            }
        }

        for my $term (@terms) {
            if (not -e $srcSet{$term.'.md'}) {
                write_file(SRCDIR.$term.'.md', 'new File');
                unshift @files, SRCDIR.$term.'.md',
            }
        }
    }
    close $sfd;
    say $tfd $templateMap{section}->fill_in(HASH => {line => join ' ', @sectionStack}) if @sectionStack;
    close $tfd;
}
