#!/usr/bin/env perl


# Declaration of pragmas
use strict;
use utf8;
use open qw/:std :utf8/;


# Call of external modules
use Encode qw(is_utf8);
use Getopt::Long;
use HTTP::CookieJar::LWP;
use JSON;
use LWP::UserAgent;
# use URI::Encode qw(uri_decode uri_encode);
# use XML::Twig;

# Programme name
my ($programme) = $0 =~ m|^(?:.*/)?(.+)|;
my $substitute  = " " x length($programme);

my $usage = "Usage: \n" . 
            "    $programme -i input_file -m metadata_file -t teeft_file [ -l (fr|en) ] \n" .
            "    $programme -i input_file -m metadata_file [ -l (fr|en) ] \n" .
            "    $programme -i input_file -t teeft_file \n" .
            "    $programme -h\n\n";

my $version     = "0.5.3";
my $changeDate  = "April 17, 2019";

# Initialising global variables 
# necessary for options
my $help       = undef;
my $input      = undef;
my $language   = 'en';
my $metadata   = undef;
my $teeft      = undef;
my $type       = 'tsv';

eval    {
        $SIG{__WARN__} = sub {usage(1);};
        GetOptions(
                "help"       => \$help,
                "input=s"    => \$input,
                "language=s" => \$language,
                "metadata=s" => \$metadata,
                "teeft=s"    => \$teeft,
                );
        };
$SIG{__WARN__} = sub {warn $_[0];};

if ( $help ) {
        print "\nProgramme: \n";
        print "    “$programme”, version $version ($changeDate)\n";
        print "    Does lots of good stuff, we just haven’t figured out what exactly! \n";
#        print "     \n";
        print "\n";
        print $usage;
        print "\nOptions: \n";
        print "    -h  display this help and exit \n";
        print "    -i  specify the name of the input file  \n";
        print "    -l  specify the language used (French or English, English by default) \n";
        print "    -m  specify the name of the metadata output file \n";
        print "    -t  specify the name of the TEEFT “doc × term” file \n";

        exit 0;
        }

usage(2) if not $input ;
usage(2) if not $metadata and not $teeft;
$language = lc($language);
usage(2) if $language ne 'en' and $language ne 'fr';

# Interruptions
$SIG{'HUP'} = 'cleanup';
$SIG{'INT'} = 'cleanup';
$SIG{'QUIT'} = 'cleanup';
$SIG{'TERM'} = 'cleanup';

# Parameters of the ISTEX API 
my $base    = "https://api.istex.fr";
my $url     = "$base/document/?q=";
my $out     = "output=*";
my $size    = 250;
my $failure = 0;

# User agent initialization
my $agent = LWP::UserAgent->new(
                        cookie_jar => HTTP::CookieJar::LWP->new,
                        );
$agent->agent("$programme/$version");
$agent->default_header("Accept"          => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
$agent->default_header("Accept-Language" => "fr,fr-FR;q=0.8,en-US;q=0.5,en;q=0.3");
$agent->default_header("Accept-Encoding" => "gzip, deflate");
$agent->default_header("Connection"      => "keep-alive");
# if ( $token ) {
#         $agent->default_header("Authorization"      => "Bearer $token");
#         }

# Increasing timeout
$agent->timeout(300);
$agent->env_proxy;

# Variables
my $istex = undef;
my $nb    = undef;
my @ark   = ();
my @lines = ();
my @index = ();
my %name  = ();
my %pos   = ();

open(INP, "<:utf8", $input) or die "Cannot open \"$input\": $!,";
while(<INP>) {
        chomp;
        s/\r//go;        #just in case ...
        if ( /^\[ISTEX\]\s*/o ) {
                $istex ++;
                }
        elsif (/^\[.+?\]\s*/o) {
                $istex = 0;
                }
        elsif ($istex and /^ark +/o) {
                $nb ++;
                my ($type, $ark, $sep, $name) = split(/\s+/);
                $ark = "ark:$ark" if $ark !~ /^ark:/o;
                $name{$ark} = $name if $name;
                $pos{$ark} = $nb;
                push(@ark, $ark);
                }
        }
close INP;

my $format = sprintf("f%%0%dd", length($nb) + 1);

# Languages table (codes ISO 639)
my %language = initialize();

# Correspondence between corpus names and publishers
my %pretty = (
        "bmj"                 => "BMJ",
        "brepols-ebooks"      => "Brepols [e-books]",
        "brepols-journals"    => "Brepols [journals]",
        "brill-hacco"         => "Brill HACCO",
        "brill-journals"      => "Brill [journals]",
        "cambridge"           => "Cambridge",
        "degruyter-journals"  => "Degruyter [journals]",
        "ecco"                => "ECCO",
        "edp-sciences"        => "EDP Sciences",
        "eebo"                => "EEBO",
        "elsevier"            => "Elsevier",
        "emerald"             => "Emerald",
        "gsl"                 => "GSL",
        "iop"                 => "IOP",
        "lavoisier"           => "Lavoisier",
        "nature"              => "Nature",
        "numerique-premium"   => "Numérique Premium",
        "oup"                 => "OUP",
        "rsc-ebooks"          => "RSC [e-books]",
        "rsc-journals"        => "RSC [journals]",
        "sage"                => "Sage",
        "springer-ebooks"     => "Springer [e-books]",
        "springer-journals"   => "Springer [journals]",
        "wiley"               => "Wiley",
        );

# Opening the metadata file (if necessary) 
if ( $metadata ) {
        open(OUT, ">:utf8", $metadata) or die "$metadata: $!,";
        }

# Opening the TEEFT “doc × term” file (if necessary) 
if ( $teeft ) {
        open(NDX, ">:utf8", $teeft) or die "$teeft: $!,";
        }

if ( @ark ) {
        if ( $language eq 'en' ) {
                print OUT "Filename\tTitle\tAuthor\tAffiliation\tSource\tISSN\te-ISSN\t";
                print OUT "ISBN\te-ISBN\tPublisher\tDocument type\tContent type\tDate\t";
                print OUT "Language\tAbstract\tAuthor’s keywords\tWoS category\t";
                print OUT "Science-Metrix category\tScopus category\tINIST category\t";
                print OUT "Quality score\tPDF version\tISTEX Id\tARK\tDOI\tPMID\n";
                }
        elsif ( $language eq 'fr' ) {
                print OUT "Nom de fichier\tTitre\tAuthor\tAffiliation\tSource\tISSN\te-ISSN\t";
                print OUT "ISBN\te-ISBN\tÉditeur\tType de document\tType de contenu\tDate\t";
                print OUT "Langue\tRésumé\tMots-clés d’auteur\tCatégories WoS\t";
                print OUT "Catégories Science-Metrix\tCatégories Scopus\tCatégories INIST\t";
                print OUT "Score de qualité\tVersion du PDF\tIdentifiant ISTEX\tARK\tDOI\tPMID\n";
                }
        }

while (@ark) {
        my @tmp = splice(@ark, 0, 50);
        my $query = join(" ", map {'"' . $_ . '"';} @tmp);
        my ($code, $json) = my_get("$url$query&output=*&size=50&sid=visatm-galaxy");
        my $perl = undef;
        eval    {
                $perl = decode_json $json;
                };
        if ( $@ ) {
                print STDERR "Conversion error JSON => Perl: $@ \n";
                exit 3;
                }
        my %top = %{$perl};
        if ( defined $top{'hits'} ) {
                my @hits = @{$top{'hits'}};
                foreach my $hit (@hits) {
                        traite($hit);
                        }
                }
        foreach my $line (grep(!/^\s*\z/, @lines)) {
                print OUT "$line\n";
                }
        foreach my $line (sort @index) {
                print NDX "$line\n";
                }
        @lines = ();
        @index = ();
        }

close OUT if fileno(OUT);
close NDX if fileno(NDX);


exit 0;


sub usage
{
print STDERR $usage;

exit shift;
}

sub traite
{
my $ref = shift;

my $file   = undef;
my $xml    = undef;
my @values = ();
my %hit    = %{$ref};
my $id     = $hit{'id'};
my $ark    = $hit{'arkIstex'};
my $pos    = $pos{$ark};

if ( $name{$ark} ) {
        $file = $name{$ark};
        }
else    {
        $file = sprintf($format, $pos);
        }

# TEEFT first
if ( $teeft ) {
        if ( defined $hit{'keywords'} ) {
                my %keywords = %{$hit{'keywords'}};
                if ( defined $keywords{'teeft'} ) {
                        my @teeft = @{$keywords{'teeft'}};
                        foreach my $item (@teeft) {
                                push(@index, "$file\t$item");
                                }
                        }
                }
        return if not $metadata;
        }

my $title = $hit{'title'};
my $corpusName = $hit{'corpusName'};
if ( $pretty{$corpusName} ) {
        $corpusName = $pretty{$corpusName};
        }

# Variables
my $affiliations    = "";
my $authors         = "";
my $date            = "";
my $doi             = "";
my $dt              = "";
my $copyrightDate   = "";
my $eisbn           = "";
my $eissn           = "";
my $genre           = "";
my $inist           = "";
my $isbn            = "";
my $issn            = "";
my $keywords        = "";
my $languages       = "";
my $pdfVersion      = "";
my $pmid            = "";
my $publicationDate = "";
my $abstract        = "";
my $scienceMetrix   = "";
my $scopus          = "";
my $score           = "";
my $source          = "";
my $wos             = "";

if ( $hit{'author'} ) {
        my @authors = @{$hit{'author'}};
        my @names = ();
        my @affiliations = ();
        my %affiliations = ();
        my %lien         = ();
        foreach my $author (@authors) {
                my %author = %{$author};
                if ( $author{'name'} ) {
                        push(@names, $author{'name'});
                        }
                if ( $author{'affiliations'} ) {
                        foreach my $affiliation (@{$author{'affiliations'}}) {
                                next if not $affiliation;
                                next if $affiliation =~ /^\s*e-mail\s?:\s/io;
                                if ( not $affiliations{$affiliation} ) {
                                        push(@affiliations, $affiliation);
                                        $affiliations{$affiliation} = $#affiliations + 1;
                                        }
                                if ( $author{'name'} ) {
                                        $lien{$#affiliations}{$#names + 1}{$affiliations{$affiliation}} ++;
                                        }
                                }
                        }
                }
        if ( @names ) {
                $authors = join(" ; ", @names);
                }
        if ( @affiliations ) {
                if ( $#names > 0 ) {
                        for ( my $n = 0 ; $n <= $#affiliations ; $n ++ ) {
                                my $tmp = join(",", sort {$a <=> $b} keys %{$lien{$n + 1}});
                                if ( $tmp ) {
                                        $affiliations[$n] .= " (aut. $tmp)";
                                        }
                                }
                        }
                $affiliations = join(" ; ", @affiliations);
                }
        }

if ( $hit{'copyrightDate'} ) {
        $copyrightDate = $hit{'copyrightDate'};
        }
if ( $hit{'publicationDate'} ) {
        $publicationDate = $hit{'publicationDate'};
        }
if ( $copyrightDate and $publicationDate ) {
        if ( $copyrightDate == $publicationDate ) {
                $date = $copyrightDate;
                }
        elsif ( $copyrightDate =~ /^[12]\d\d\d\z/o ) {
                $date = $copyrightDate;
                }
        else    {
                $date = $publicationDate;
                }
        }
elsif ( $copyrightDate ) {
        $date = $copyrightDate;
        }
elsif ( $publicationDate ) {
        $date = $publicationDate;
        }
else    {
        $date = "S.D.";
        }

if ( defined $hit{'language'} ) {
        $languages = join("; ", map {$language{$_} ? $language{$_} : uc($_);} @{$hit{'language'}});
        }

if ( $hit{'abstract'} ) {
        $abstract = $hit{'abstract'};
        $abstract =~ s/^(abstract|summary)\s*:\s*//io;
        }

if ( defined $hit{'categories'} ) {
        my %categories = %{$hit{'categories'}};
        if ( defined $categories{'wos'} ) {
                $wos = join(" ; ", @{$categories{'wos'}});
                }
        if ( defined $categories{'scienceMetrix'} ) {
                $scienceMetrix = join(" ; ", @{$categories{'scienceMetrix'}});
                }
        if ( defined $categories{'scopus'} ) {
                $scopus = join(" ; ", @{$categories{'scopus'}});
                }
        if ( defined $categories{'inist'} ) {
                $inist = join(" ; ", @{$categories{'inist'}});
                }
        }
if ( defined $hit{'genre'} ) {
        $genre = join(", ", @{$hit{'genre'}});
        }

if ( defined $hit{'qualityIndicators'} ) {
        my %indicateurs = %{$hit{'qualityIndicators'}};
        if ( defined $indicateurs{'pdfVersion'} ) {
                $pdfVersion = $indicateurs{'pdfVersion'};
                }
        if ( defined $indicateurs{'score'} ) {
                $score = $indicateurs{'score'};
                }
        }
if ( defined $hit{'host'} ) {
        my %host = %{$hit{'host'}};
        if ( defined $host{'title'} ) {
                $source = $host{'title'}
                }
        if ( defined $host{'isbn'} ) {
                $isbn = join("/", @{$host{'isbn'}});
                }
        if ( defined $host{'eisbn'} ) {
                $eisbn = join("/", @{$host{'eisbn'}});
                }
        if ( defined $host{'issn'} ) {
                $issn = join("/", @{$host{'issn'}});
                }
        if ( defined $host{'eissn'} ) {
                $eissn = join("/", @{$host{'eissn'}});
                }
        if ( defined $host{'genre'} ) {
                $dt = join(", ", @{$host{'genre'}});
                }
        }
if ( $hit{'doi'} ) {
        $doi = join(" ; ", @{$hit{'doi'}});
        }
if ( $hit{'pmid'} ) {
        $pmid = join(" ; ", @{$hit{'pmid'}});
        }

my @values = ($file, $title, $authors, $affiliations, $source, $issn, $eissn, 
               $isbn, $eisbn, $corpusName, $dt, $genre, $date, $languages, $abstract, 
               $keywords, $wos, $scienceMetrix, $scopus, $inist, $score, $pdfVersion, 
               $id, $ark, $doi, $pmid);
my $ligne = join("\t", @values);
if ( $type eq "csv" ) {
        $lines[$pos] = tsv2csv($ligne);
        }
elsif ( $type eq 'tsv' ) {
        $lines[$pos] = $ligne;
        }
}

sub my_get
{
my $target = shift;
my $destination = shift;

my $request = HTTP::Request->new(GET => "$target");

my $response = $agent->request($request, $destination);
my $code = $response->code;

# Vérification de la réponse
if ( $destination ) {
        if ( defined $response->header('Client-Aborted') ) {
                die "Client-Aborted: $response->header('Client-Aborted'),";
                }
        elsif ( defined $response->header('X-Died') ) {
                die "X-Died: $response->header('X-Died'),";
                }
        }
if ($response->is_success) {
        $failure = 0;
        if ( $destination ) {
                return $code;
                }
        else    {
                return ($code, $response->decoded_content);
                }
        }
else    {
        my $message = $response->status_line;
        if ( $message =~ /\b(read timeout|Proxy Error)\b/o and $failure < 10 ) {
                $failure ++;
                print STDERR "Interruption #$failure: \"$message\", ", date(), "\n";
                print STDERR "             for \"$target\"\n" if $failure == 1;
                sleep 60;
                return my_get($target, $destination);
                }
        else    {
                $target =~ s/(scrollId=\w).+?(\w&)/$1...$2/;
                print STDERR "Erreur: $message pour URL \"$target\"\n";
                cleanup(15);
                }
        }
}

sub tsv2csv
{
my $ligne = shift;

my @champs = split(/\t/, $ligne);
foreach my $champ (@champs) {
        if ( $champ =~ /[",;]/o ) {
                $champ =~ s/"/""/go;
                $champ = "\"$champ\"";
                }
        }

return join(";", @champs);
}

sub cleanup
{
my $signal = shift;

if ( fileno(TMP) ) {
        close TMP;
        }

if ( $signal =~ /^\d+\z/ ) {
        exit $signal;
        }
if ( $signal ) {
        print STDERR "Signal SIG$signal detected\n";
        exit 9;
        }
else    {
        exit 0;
        }
}

sub initialize
{
my %hash =  ();

while (<DATA>) {
        next if /^\s*#/o;
        next if /^\s*\z/o;
        if ( /^% +(\w+)/o ) {
                my $token = $1;
                last if $token eq 'END' or $token eq 'FIN';
                }
        elsif ( /\t/o ) {
                chomp;
                s/\r//o;
                my ($code, $francais, $english) = split(/\t+/);
                $hash{'en'}{$code} = $english;
                $hash{'fr'}{$code} = $francais;
                $hash{'en'}{lc($code)} = $english;
                $hash{'fr'}{lc($code)} = $francais;
                }
        }

return %{$hash{$language}};
}


__DATA__

##
## Liste of language codes (ISO 639)
## DO NOT EDIT!
##

% LANGUAGES

AFR	Afrikaans 		Afrikaans
ALB	Albanais		Albanian
AMH	Amharique		Amharic
ARA	Arabe			Arabic
ARM	Arménien		Armenian
AZE	Azerbaïdjanais		Azerbaijani
BAK	Bachkir			Bashkir
BAS	Basque			Basque
BEL	Biélorusse		Belarusian
BEN	Bengali			Bengali
BER	Berbère			Berber
BRE	Breton			Breton
BUL	Bulgare			Bulgarian
BUR	Birman			Burmese
CAM	Cambodgien		Cambodian
CAT	Catalan			Catalan
CHI	Chinois			Chinese
CRO	Croate			Croatian
CZE	Tchèque			Czech
DAN	Danois			Danish
DUT	Néerlandais		Dutch
ENG	Anglais			English
ESK	Eskimo			Eskimo
ESP	Espéranto		Esperanto
EST	Estonien		Estonian
FAR	Feroien			Faroese
FIN	Finnois			Finnish
FLE	Flamand			Flemish
FRE	Français		French
FRI	Frison			Frisian
GAE	Gaélique		Goidelic
GEO	Géorgien		Georgian
GER	Allemand		German
GRC	Grec (ancien)		Greek (Ancient)
GRE	Grec (moderne)		Greek (Modern)
GUA	Guarani			Guarani
GUJ	Goujrati		Gujarati
HAU	Hausa			Hausa
HEB	Hébreu			Hebrew
HIN	Hindi			Hindi
HUN	Hongrois		Hungarian
ICE	Islandais		Icelandic
ILO	Igbo			Igbo			# ILO or IBO?
IND	Indonésien		Indonesian
INT	Interlingua		Interlingua
IRI	Irlandais		Irish
ITA	Italien			Italian
JAP	Japonais		Japanese
JPN	Japonais		Japanese
KAZ	Kazakh			Kazakh
KIR	Kirghiz			Kirghiz
KON	Kongo			Kongo
KOR	Coréen			Korean
KUR	Kurde			Kurdish
LAO	Laotien			Lao
LAP	Lapon			Sami
LAT	Latin			Latin
LAV	Letton			Latvian
LIT	Lithuanien		Lithuanian
LUB	Louba			Luba-Katanga
MAC	Macédonien		Macedonian
MAY	Malais			Malay
MLA	Malgache		Malagasy
MLG	Malgache		Malagasy
MOL	Moldave			Moldavian
MON	Mongol			Mongolian
MUL	Multilingue		Multiple languages
NOR	Norvégien		Norwegian
PAN	Pendjabi		Panjabi
PER	Persan			Persian
POL	Polonais		Polish
POR	Portugais		Portuguese
PRO	Provençal		Provençal
PUS	Pachto			Pashto
QUE	Quechua			Quechua
ROH	Romanche		Romansh
RUM	Roumain			Romanian
RUS	Russe			Russian
SER	Serbe			Serbian
SHO	Chona			Shona
SLO	Slovaque		Slovak
SLV	Slovène			Slovenian
SNH	Cingalais		Sinhala
SPA	Espagnol		Spanish
SWA	Swahili			Swahili
SWE	Suédois			Swedish
TAG	Tagal			Tagalog
TAJ	Tamoul			Tamil
TAM	Tamoul			Tamil
TGL	Tagal			Tagalog
THA	Thaï			Thai
TUK	Turkmène		Turkmen
TUR	Turc			Turkish
UKR	Ukrainien		Ukrainian
UND	Indéterminée		Undetermined
URD	Ourdou			Urdu
UZB	Ouzbek			Uzbek
VIE	Vietnamien		Vietnamese
WEL	Gallois			Welsh
WOL	Wolof			Wolof
YOR	Yorouba			Yoruba

% END
