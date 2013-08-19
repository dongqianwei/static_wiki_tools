use v5.16;
use autodie;
use File::Slurp;
use File::Basename;
use constant {
        SRCDIR => './src/',
        TARDIR => './target/'
    };

mkdir SRCDIR unless -d SRCDIR;
mkdir TARDIR unless -e TARDIR;

my %srcSet = map {$_, 1} glob(SRCDIR.'*.md');
my @files = keys %srcSet;
while (@files) {
    my $fname = shift @files;
    open(my $sfd, '<', $fname);
    open(my $tfd, '>', TARDIR.scalar fileparse $fname =~ s/md$/html/xmsr);
    while (<$sfd>) {
        chomp;
        my $line = $_;

        my @terms = $line =~ m/\[([^\]]*?)\]/xmsg;
        say $tfd $line =~ s|\[([^\]]*?)\]|<a href="./$1.html">$1</a>|mxsrg;

        for my $term (@terms) {
            if (not -e $srcSet{$term.'.md'}) {
                write_file(SRCDIR.$term.'.md', 'new File');
                unshift @files, SRCDIR.$term.'.md',
            }
        }
    }
    close $sfd;
    close $tfd;
}
