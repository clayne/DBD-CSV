#!/pro/bin/perl

use strict;
use warnings;

my $opt_cm = 1;
my $opt_as = 1;
my $opt_is = 0;
my $opt_l  = "en_US";

use Test::More;
use File::Find;

my @files = ("lib/DBD/CSV.pm");

subtest "CommonMistakes" => sub {
    eval "use Pod::Spell::CommonMistakes qw( check_pod )";
    $@ and plan skip_all => "Pod::Spell::CommonMistakes not available";

    foreach my $pm (sort @files) {
	my $result = check_pod ($pm);
	my @keys = keys %$result;

	is (scalar @keys, 0, $pm);
	@keys or next;

	diag (join "\n", map { "$_\t=> $result->{$_}" } @keys);
	}

    done_testing;
    };

subtest "Spell-check with aspell" => sub {
    $opt_as or
	plan skip_all => "Aspell not selected";

    eval "use Text::Aspell";
    $@ and
	plan skip_all => "Text::Aspell not available";

    if (!$opt_l && open my $af, "<", ".aspell.local.pws") {
	close $af;
	}

    my $speller = Text::Aspell->new;
    $opt_l and $speller->set_option ("lang", $opt_l);

    foreach my $sf (".aspell.local.pws", glob "$ENV{HOME}/.aspell.*.pws") {
	open my $af, "<", $sf or next;
	while (<$af>) {
	    if ($. == 1) {
		!$opt_l && m/\s+(\w\w[-_]\w\w)\s+[0-9]+\s*$/ and
		    $speller->set_option ("lang", $opt_l = $1);
		next;
		}
	    chomp;
	    $speller->add_to_session ($_);
	    }
	}

    foreach my $pm (sort @files) {
	my $as = Pod::Aspell->new;
	my @as;
	for ($as->parse_from_file ($pm)) {
	    m/[0-9]/ and next;	# too likely to be some form of code
	    $speller->check ($_) and next;
	    my @s = $speller->suggest ($_);
	    push @as, "'$_' => (@s)";
	    }
	my $rpt = join "\n", @as;
	is ($rpt, "", $pm);
	}

    done_testing;
    };

subtest "Spell-check with ispell" => sub {
    $opt_is or
	plan skip_all => "Ispell not selected";

    eval "use Text::Ispell";
    $@ and
	plan skip_all => "Text::Ispell not available";

    Text::Ispell::allow_compounds (1);
    $Text::Ispell::path = $Text::Ispell::path = "/usr/bin/ispell";

    foreach my $pm (sort @files) {
	my $as = Pod::Aspell->new;
	my @as;
	foreach my $w ($as->parse_from_file ($pm)) {
	    $w =~ m/[0-9]/ and next;	# too likely to be some form of code
	    my $r = Text::Ispell::spellcheck ($w);
	    ref $r eq "HASH" or next;
	    $r->{type} eq "ok" || $r->{type} eq "compound" and next;
	    if ($r->{type} eq "root") {
		push @as, "'$_' -r $r->{term} <- $r->{root}";
		next;
		}
	    if ($r->{type} eq "miss") {
		push @as, "'$_' -m $r->{term} ($r->{misses})";
		next;
		}
	    if ($r->{type} eq "guess") {
		push @as, "'$_' -g $r->{term} ($r->{guesses})";
		next;
		}
	    if ($r->{type} eq "none") {
		push @as, "'$_' -n $r->{term}";
		next;
		}
	    }
	my $rpt = join "\n", @as;
	is ($rpt, "", $pm);
	}

    done_testing;
    };

done_testing;

# ==============================================================================

# Basics stolen from Pod::Spell
# Main problem is the output_handle

package Pod::Aspell;

use strict;
use warnings;

use Pod::Parser ();
use parent "Pod::Parser";

use Pod::Wordlist ();
use Pod::Escapes  ("e2char");
use Text::Wrap    ("wrap");
$Text::Wrap::huge = "overflow";

use integer;
use locale;    # so our uc/lc works right
use Carp;

sub new {
    my $x = shift;
    my $new = $x->SUPER::new (@_);
    $new->{spell_stopwords} = {};
    @{$new->{spell_stopwords}}{keys %Pod::Wordlist::Wordlist} = ();
    $new->{region} = [];
    return $new;
    } # new

sub output_handle {
    my ($self, $arg) = @_;
    if ($arg) {
	my $oh;
	if (ref $arg eq "SCALAR") {
	    open $oh, ">", $arg;
	    }
	else {
	    $oh = $arg;
	    }
	$self->{oh} = $oh;
	}
    return $self->{oh} || $self->SUPER::output_handle ();
    } # output_handle

sub parse_from_file {
    my ($self, $fn) = @_;

    my $str = "";
    $self->output_handle (\$str);
    $self->SUPER::parse_from_file ($fn);

    my %words;
    $words{$_}++ for $str =~ m/(\w+)/g;
    sort keys %words;
    } # parse_from_file

sub verbatim { return ""; }    # totally ignore verbatim sections

sub _get_stopwords_from {
    my $stopwords = $_[0]{spell_stopwords};

    my $word;
    while ($_[1] =~ m<(\S+)>g) {
	$word = $1;
	if ($word =~ m/^!(.+)/s) {    # "!word" deletes from the stopword list
	    delete $stopwords->{$1};
	    }
	else {
	    $stopwords->{$1} = 1;
	    }
	}
    return;
    } # _get_stopwords_from

sub textblock {
    my ($self, $paragraph) = @_;
    if (@{$self->{region}}) {
	my $last = $self->{region}[-1];
	if ($last eq "stopwords") {
	    $self->_get_stopwords_from ($paragraph);
	    return;
	    }

	if ($last eq ":stopwords") {
	    $self->_get_stopwords_from ($self->interpolate ($paragraph));
	    return;
	    }

	$last =~ m/^:/s or return;
	}
    $self->_treat_words ($self->interpolate ($paragraph));
    return;
    } # textblock

sub command {
    my $self    = shift;
    my $command = shift;
    $command eq "pod" and return;

    if ($command eq "begin") {
	my $region_name;
	if (shift (@_) =~ m/^\s*(\S+)/s) {
	    $region_name = $1;
	    }
	else {
	    $region_name = "WHATNAME";
	    }
	push @{$self->{region}}, $region_name;
	}
    elsif ($command eq "end") {
	pop @{$self->{region}};    # doesn't bother to check
	}
    elsif ($command eq "for") {
	if ($_[0] =~ s/^\s*(\:?)stopwords\s*(.*)//s) {
	    my $para = $2;
	    $1 and $para = $self->interpolate ($para);
	    $self->_get_stopwords_from ($para);
	    }
	}
    elsif (@{$self->{region}}) {    # TODO: accept POD formatting
	                            # ignore
	}
    elsif ($command eq "head1" or $command eq "head2" or
	   $command eq "head2" or $command eq "head3" or
	   $command eq "item") {
	my $out_fh = $self->output_handle ();
	print $out_fh "\n";
	$self->_treat_words ($self->interpolate (shift));
	}
    return;
    } # command

sub interior_sequence {
    my $self    = shift;
    my $command = shift;

    $command eq "X" || $command eq "Z" and return "";

    local $_ = shift;

    # Expand escapes into the actual character now, carping if invalid.
    if ($command eq "E") {
	my $it = e2char ($_);
	defined $it and return $it;

	carp "Unknown escape: E<$_>";
	return "E<$_>";
	}

    # For all the other sequences, empty content produces no output.
    $_ eq "" and return;

    if ($command eq "B" or $command eq "I" or $command eq "S") {
	return $_;
	}

    if ($command eq "C" or $command eq "F") {
	# don't lose word-boundaries
	my $out = "";
	$out .= " " if s/^\s+//s;
	my $append;
	$append = 1 if s/\s+$//s;
	$out .= "_" if length $_;
	# which, if joined to another word, will set off the Perl-token alarm
	$out .= " " if $append;
	return $out;
	}

    if ($command eq "L") {
	m/^([^|]+)\|/s and return $1;
	return "";
	}

    carp "Unknown sequence $command<$_>";
    } # interior_sequence

sub _treat_words {
    my $p = shift;
    # Count the things in $_[0]

    my $stopwords = $p->{spell_stopwords};
    my $word;
    $_[0] =~ tr/\xA0\xAD/ /d;
    # i.e., normalize non-breaking spaces, and delete soft-hyphens

    my $out = "";

    my ($leading, $trailing);
    while ($_[0] =~ m<(\S+)>g) {
	# Trim normal English punctuation, if leading or trailing.
	length $1 > 50 and next;
	$word = $1;

	$leading  = $word =~ s/^([\`\"\'\(\[])//s            ? $1 : "";
	$trailing = $word =~ s/([\)\]\'\"\.\:\;\,\?\!]+)$//s ? $1 : "";

	$word =~ m/^[\&\%\$\@\:\<\*\\\_]/s ||
	    # if it looks like it starts with a sigil, etc.
	    $word =~ m/[\%\^\&\#\$\@\_\<\>\(\)\[\]\{\}\\\*\:\+\/\=\|\`\~]/
	    # or contains anything strange
	     and next;

	exists $stopwords->{$word} || exists $stopwords->{lc $word} or
	    $out .= "$leading$word$trailing ";
	}

    if (length $out) {
	my $out_fh = $p->output_handle ();
	print $out_fh wrap ("", "", $out), "\n\n";
	}

    return;
    } # _treat_words

1;
