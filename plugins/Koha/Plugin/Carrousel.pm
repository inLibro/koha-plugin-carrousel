package Koha::Plugin::Carrousel;
# Mehdi Hamidi, 2016 - InLibro
# Modified by Bouzid Fergani, 2016 - InLibro
# Modified by William Frazilien, 2020 - InLibro
#
# This plugin allows you to generate a Carrousel of books from available lists
# and insert the template into the table system preferences;OpacMainUserBlock
#
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
use Modern::Perl;
use strict;
use CGI;
use DBI;
use JSON qw( decode_json encode_json );
use Encode qw( encode_utf8 );
use LWP::Simple;
use Template;
use utf8;
use base qw(Koha::Plugins::Base);
use Koha::Biblio;
use C4::Context;
use C4::Koha qw(GetNormalizedISBN);
use C4::Output;
use C4::XSLT;
use Koha::Reports;
use C4::Reports::Guided;
use Koha::Uploader;
use Koha::DateUtils qw( dt_from_string );

BEGIN {
    my $kohaversion = Koha::version;
    $kohaversion =~ s/(.*\..*)\.(.*)\.(.*)/$1$2$3/;
    my $module = $kohaversion < 21.11 ? "Koha::News" : "Koha::AdditionalContents";
    my $file = $module;
    $file =~ s[::][/]g;
    $file .= '.pm';
    require $file;
    $module->import;
}

our $VERSION = "4.1.1";
our $metadata = {
    name            => 'Carrousel 4.1.1',
    author          => 'Mehdi Hamidi, Maryse Simard, Brandon Jimenez, Alexis Ripetti, Salman Ali',
    description     => 'Generates a carrousel from available data sources (lists, reports or collections).',
    date_authored   => '2016-05-27',
    date_updated    => '2023-03-22',
    minimum_version => '18.05',
    maximum_version => undef,
    version         => $VERSION,
};

#On fixe la limite affichable à 40 afin de ne pas surcharger l'affiche du carrousel
our $LIMIT_DISPLAYED = 40;

our $useSql = 0;
if (!(eval("use Koha::Virtualshelves") || !(eval("use Koha::Virtualshelfcontents")))) {
    $useSql =1;
}
our $dbh = C4::Context->dbh();

sub new {
    my ( $class, $args ) = @_;
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;
    my $self = $class->SUPER::new($args);

    return $self;
}

sub tool {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    if ($cgi->param('action')){
        $self->generateCarrousels();
        $self->go_home();
    }else{
        $self->step_1();
    }
}

sub step_1 {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $template = $self->retrieve_template("step_1");
    my $carrousels = (!defined $self->retrieve_data('carrousels')) ? () : decode_json(encode_utf8($self->retrieve_data('carrousels')));
    $template->param(carrousels => $carrousels);
    print $cgi->header(-type => 'text/html',-charset => 'utf-8');
    print $template->output();
}

sub getDisplayName {
    my ( $self, $module, $id ) = @_;
    my $name = "";

    if ($useSql || $module eq "collections") {
        my $table = ($module eq "reports") ? "saved_sql" : (($module eq "collections") ? "authorised_values" : "virtualshelves");
        my $column_id = ($module eq "reports") ? "id" : (($module eq "collections") ? "authorised_value" : "shelfnumber");
        my $column_name = ($module eq "reports") ? "report_name" : (($module eq "collections") ? "lib" : "shelfname");

        my $stmt = $dbh->prepare("SELECT * FROM $table WHERE $column_id = ?");
        $stmt->execute($id);

        while (my $row = $stmt->fetchrow_hashref()) {
            $name = $row->{$column_name};
        }
    } else {
        if ($module eq "reports") {
            my $report = Koha::Reports->find({ id => $id });
            $name = $report->report_name if $report;
        } else {
            my $shelve = Koha::Virtualshelves->find({ shelfnumber => $id });
            $name = $shelve->shelfname if $shelve;
        }
    }

    return $name;
}

sub getModules {
    my ( $self, $args ) = @_;
    my $modules;

    if ($useSql) {
        my $stmt = $dbh->prepare("SELECT * FROM virtualshelves WHERE category = 2 ORDER BY shelfname");
        $stmt->execute();
        while (my $row = $stmt->fetchrow_hashref()) {
            push @{$modules->{lists}}, $row;
        }

        $stmt = $dbh->prepare("SELECT * FROM saved_sql ORDER BY report_name");
        $stmt->execute();
        while (my $row = $stmt->fetchrow_hashref()) {
            push @{$modules->{reports}}, $row;
        }
    } else {
        $modules->{lists} = Koha::Virtualshelves->get_public_shelves();
        $modules->{reports} = Koha::Reports->search();
    }

    my $ccodes = C4::Koha::GetAuthorisedValues('CCODE');
    $ccodes = Koha::AuthorisedValues->search({category => "CCODE"})->unblessed if (C4::Context->preference("IndependentBranches"));
    my @ccodeloop;
    for my $thisccode (@$ccodes) {
        my %row = (value => $thisccode->{authorised_value},
            description => $thisccode->{lib},
        );
        push @ccodeloop, \%row;
    }
    foreach my $row (@ccodeloop) {
        push @{$modules->{collections}}, $row;
    }

    return $modules;
}

#Charger le contenus des listes en utilisant sql si le module virtualshelfcontents n'est pas disponible
sub loadContent {
    my ( $self, $module, $id ) = @_;
    my @content;

    if ($module eq "reports") {
        my $sql = "";
        if ($useSql) {
            my $stmt = $dbh->prepare("SELECT * FROM saved_sql WHERE id = ?");
            $stmt->execute($id);

            while (my $row = $stmt->fetchrow_hashref()) {
                $sql = $row->{savedsql};
            }
        } else {
            my $report = Koha::Reports->find($id);
            $sql = $report->savedsql if $report;
        }

        unless ($sql) {
            warn "Report $id was not found.";
        } else {
            unless ($sql =~ /<</) {
                my $sth = $dbh->prepare($sql);
                $sth->execute();
                if ($sth) {
                    while ( my $row = $sth->fetchrow_hashref() ) {
                        if (defined($row->{biblionumber})) {
                            push @content, $row->{biblionumber};
                        } else {
                            warn "Report $id can't be used because it doesn't use biblionumber.";
                            last;
                        }
                    }
                } else {
                    warn "An error occured while executing report $id.";
                }
            } else {
                warn "Report $id can't be used because it needs parameters.";
            }
        }
    } elsif ($module eq "collections") {
        #On fait notre recherche en triant du plus récent au plus aucien
        my $stmt = $dbh->prepare(
            "SELECT distinct biblionumber, timestamp
            FROM items
            WHERE ccode = ?
            ORDER BY timestamp DESC");
        $stmt->execute($id);

        while (my $row = $stmt->fetchrow_hashref()) {
            push @content, $row->{biblionumber};
        }
    } elsif ($useSql) {
        #On fait notre recherche en triant du plus récent au plus aucien
        my $stmt = $dbh->prepare("SELECT * FROM virtualshelfcontents WHERE shelfnumber = ?
        ORDER BY dateadded DESC");
        $stmt->execute($id);
        while (my $row = $stmt->fetchrow_hashref()) {
            push @content, $row->{biblionumber};
        }
    } else {
        #On fait notre recherche en triant du plus récent au plus aucien
        my $shelves = Koha::Virtualshelfcontents->search({ shelfnumber => $id }, {order_by => {-desc => [qw{dateadded}]}});
        while ( my $item = $shelves->next ) {
            push @content, $item->biblionumber;
        }
    }

    return @content;
}

sub getEnabledCarrousels {
    my ( $self ) = @_;
    my $shelves = ();
    $shelves = decode_json(encode_utf8($self->retrieve_data('carrousels'))) if ($self->retrieve_data('carrousels'));
    foreach my $carrousel (@{$shelves}) {
        $carrousel->{name} = $self->getDisplayName($carrousel->{module}, $carrousel->{id});
        my $branchcode;
        if ($carrousel->{module} eq "lists") {
            my $shelf = Koha::Virtualshelves->find($carrousel->{id});
            my $borrowernumber = $shelf->owner if defined $shelf;
            if (C4::Context->preference("IndependentBranches")) {
                my $patron = Koha::Patrons->find($borrowernumber);
                $branchcode = $patron->branchcode if defined $patron;
            }
        }
        elsif ($carrousel->{module} eq "collections") {
            my $authorised_value = Koha::AuthorisedValues->find({category => "CCODE", authorised_value => $carrousel->{id}});
            my $authorised_value_id = $authorised_value->id;

            my $dbh = C4::Context->dbh;
            my $query = qq {SELECT branchcode FROM authorised_values_branches WHERE av_id = ? };
            my $sth = $dbh->prepare($query);
            $sth->execute($authorised_value_id);
            my $data = $sth->fetchrow_hashref;

            # Si aucun CCODE n'est spécifique à une branche on va le skip plus tard
            if (C4::Context->preference("IndependentBranches") && $data->{branchcode}) {
                $branchcode = $data->{branchcode};
            }
        }
        elsif ($carrousel->{module} eq "reports") {
            if (C4::Context->preference("IndependentBranches")) {
                my $borrowernumber = Koha::Reports->find($carrousel->{id})->id;
                my $patron = Koha::Patrons->find($borrowernumber);
                $branchcode = $patron->branchcode if defined $patron;
            }
        }
        $carrousel->{branchcode} = $branchcode;
    }
    return $shelves;
}

sub generateCarrousels{
    my ( $self ) = @_;
    my $carrousels = $self->getCarrousels();
    my $tt = Template->new(
        INCLUDE_PATH => C4::Context->config("pluginsdir"),
        ENCODING     => 'utf8',
    );
    # Si IndependentBranches on doit trier les carrousels par branches et faire une boucle par branche
    if (C4::Context->preference("IndependentBranches")) {
        my %branchcodes;
        foreach my $carrousel (@{ $carrousels }) {
            # Si le branchcode est undef c'est qu'il n'y a pas de branche de précisée
            next unless defined $carrousel->{branchcode};
            push @{ $branchcodes{$carrousel->{branchcode}} }, $carrousel;
        }
        foreach my $branchcode (keys %branchcodes) {
            my $t_carrousels = $branchcodes{$branchcode};
            my $data = "";
            binmode( STDOUT, ":utf8" );
            $tt->process(
                'Koha/Plugin/Carrousel/opac-carrousel.tt',
                {
                    carrousels => $t_carrousels,
                    bgColor  => $self->retrieve_data('bgColor'),
                    txtColor => $self->retrieve_data('txtColor'),
                    autoRotateDirection => $self->retrieve_data('autoRotateDirection'),
                    autoRotateDelay => $self->retrieve_data('autoRotateDelay'),
                    ENCODING => 'utf8',
                },
                \$data,
                { binmode => ':utf8' }
            ) || warn "Unable to generate Carrousel, " . $tt->error();

            #$self->insertIntoPref($data, $branchcode, "en");
            $self->insertIntoPref($data, $branchcode, "default");
            $self->generateJSONFile($carrousels) if ($self->retrieve_data('generateJSON'));

            $tt->process(
                'Koha/Plugin/Carrousel/opac-carrousel_fr-CA.tt',
                {
                    carrousels => $carrousels,
                    bgColor  => $self->retrieve_data('bgColor'),
                    txtColor => $self->retrieve_data('txtColor'),
                    autoRotateDirection => $self->retrieve_data('autoRotateDirection'),
                    autoRotateDelay => $self->retrieve_data('autoRotateDelay'),
                    ENCODING => 'utf8',
                },
                \$data,
                { binmode => ':utf8' }
            ) || warn "Unable to generate Carrousel, " . $tt->error();

            $self->insertIntoPref($data, $branchcode, "fr-CA");
            $self->generateJSONFile($carrousels) if ($self->retrieve_data('generateJSON'));
        }
    } else {
        my $data = "";
        binmode( STDOUT, ":utf8" );
        $tt->process(
            'Koha/Plugin/Carrousel/opac-carrousel.tt',
            {
                carrousels => $carrousels,
                bgColor  => $self->retrieve_data('bgColor'),
                txtColor => $self->retrieve_data('txtColor'),
                autoRotateDirection => $self->retrieve_data('autoRotateDirection'),
                autoRotateDelay => $self->retrieve_data('autoRotateDelay'),
                ENCODING => 'utf8',
            },
            \$data,
            { binmode => ':utf8' }
        ) || warn "Unable to generate Carrousel, " . $tt->error();

        #$self->insertIntoPref($data, undef, "en");
        $self->insertIntoPref($data, undef, "default");
        $self->generateJSONFile($carrousels) if ($self->retrieve_data('generateJSON'));
        
        $data = "";        
        $tt->process(
            'Koha/Plugin/Carrousel/opac-carrousel_fr-CA.tt',
            {
                carrousels => $carrousels,
                bgColor  => $self->retrieve_data('bgColor'),
                txtColor => $self->retrieve_data('txtColor'),
                autoRotateDirection => $self->retrieve_data('autoRotateDirection'),
                autoRotateDelay => $self->retrieve_data('autoRotateDelay'),
                ENCODING => 'utf8',
            },
            \$data,
            { binmode => ':utf8' }
        ) || warn "Unable to generate Carrousel, " . $tt->error();

        $self->insertIntoPref($data, undef, "fr-CA");
        $self->generateJSONFile($carrousels) if ($self->retrieve_data('generateJSON'));
    }
}

sub generateJSONFile {
    my ( $self, $carrousels ) = @_;
    my @json;
    foreach my $carrousel (@{$carrousels}) {
        my @documents;
        foreach my $document (@{$carrousel->{documents}}) {
            my $url = C4::Context->preference('OPACBaseURL') . "/cgi-bin/koha/opac-detail.pl?biblionumber=" . $document->{biblionumber};
            push @documents, {
                title  => $document->{title},
                author => $document->{author},
                image  => $document->{url},
                url    => $url,
            };
        }
        push @json, {
            title => $carrousel->{title} || $carrousel->{name},
            documents => \@documents,
        };
    }

    # save file
    my $hash = "carrousel";
    my $filename = "$hash.json";
    my $path = File::Spec->catdir( C4::Context->config('upload_path'), "${hash}_${filename}" );
    open my $fh, ">", $path;
    print $fh encode_json(\@json);
    close $fh;

    unless (Koha::UploadedFiles->search({ hashvalue => $hash, filename => $filename })->count ) {
        my $rec = Koha::UploadedFile->new({
            hashvalue => $hash,
            filename  => $filename,
            public    => 1,
            permanent => 1,
        })->store;
    }
}

sub getCarrousels {
    my ( $self ) = @_;
    my $enabled_carrousels = $self->getEnabledCarrousels();
    my @carrousels;

    foreach my $carrousel (@{$enabled_carrousels}) {
        my $documents = $self->getCarrouselContent($carrousel->{module}, $carrousel->{id});
        if ($documents) {
            $carrousel->{documents} = $documents;
            push @carrousels, $carrousel;
        }
    }

    return \@carrousels;
}

sub getCarrouselContent {
    my ( $self, $module, $id ) = @_;

    my @contents = $self->loadContent($module, $id);
    return unless @contents;

    my @images;
    my $index = 0;
    foreach my $biblionumber ( @contents ) {
        my $biblio = Koha::Biblios->find($biblionumber);
        next unless $biblio;
        my $record = $biblio->metadata->record;
        next if ! $record;
        my $title;
        my $author;
        my $marcflavour = C4::Context->preference("marcflavour");
        if ($marcflavour eq 'MARC21'){
            $title = $record->subfield('245', 'a');
            $author = $record->subfield( '100', 'a' );
            $author = $record->subfield( '110', 'a' ) unless $author;
            $author = $record->subfield( '111', 'a' ) unless $author;
        }elsif ($marcflavour eq 'UNIMARC'){
            $title = $record->subfield('200', 'a');
            $author = $record->subfield( '200', 'f' );
        }
        $title =~ s/[,:\/\s]+$//;

        my $url = getThumbnailUrl( $biblionumber, $record );
        if ( $url ){
            my %image = ( url => $url, title => $title, author => $author, biblionumber => $biblionumber );
            push @images, \%image;
            $index++;
        }else{
            warn "[Koha::Plugin::Carrousel] There was no image found for biblionumber $biblionumber : \" $title \"\n";
        }
        #On vérifie qu'on ne dépasse pas la limite affichable fixée
        if ($index >= $LIMIT_DISPLAYED) { last; }
    }

    unless ( @images ) {
        warn "[Koha::Plugin::Carrousel] No images were found for $module with id $id. OpacMainUserBlock kept unchanged.\n";
        return;
    }

    return \@images;
}

sub getKohaVersion {
    # Current version of Koha from sources
    my $kohaversion = Koha::version;
    # remove the 3 last . to have a Perl number
    $kohaversion =~ s/(.*\..*)\.(.*)\.(.*)/$1$2$3/;
    return $kohaversion;
}

sub insertIntoPref {
    my ( $self, $data, $branchcode, $lang) = @_;

    # we select the current version of Koha
    my $kohaversion = getKohaVersion();
    my $version_line ="<!-- Carrousel $VERSION -->";

    $data = $version_line.$data;

    # si la version de koha est < 19.12 on utilise la préférence système "OpacMainUserBlock"
    if ( $kohaversion < 19.1200082 ) {
        my $stmt = $dbh->prepare("select * from systempreferences where variable='OpacMainUserBlock'");
        $stmt->execute();

        my $value;
        while (my $row = $stmt->fetchrow_hashref()) {
            $value =$row->{'value'};
        }
        $stmt->finish();

        # Le code de le carrousel est entre $first_line et $second_line, donc je m'assure que c'est uniquement ce code qui est modifié
        my $first_line = "<!-- Debut du carrousel -->";
        my $second_line ="<!-- Fin du carrousel -->";

        #Si c'est la première utilisation, ca crée les tags $first_line et $second_line qui englobent la template
        if(index($value, $first_line) == -1 && index($value, $second_line) == -1  ){
            $value = $value."\n".$first_line.$data.$second_line;
        } else{
            $data = $first_line.$data.$second_line;
            $value =~ s/$first_line.*?$second_line/$data/s;
        }

        # Update system preference
        C4::Context->set_preference( 'OpacMainUserBlock' , $value );
    }
    # Après la version 21.11, Koha::News n'existe plus
    elsif ( $kohaversion < 21.11 ) {
        #1. check installed languages
        my $opaclanguages = C4::Context->preference('opaclanguages');
        
        #expected ex opaclanguages = "fr-CA,en"
        my @languages = split /,/, $opaclanguages;
        #2. for each installed language
        foreach my $language (@languages) {
            #TODO: verify if it has to be applied to individual branches
            #2.1 check if opacmainuserblock exists
            my $mainblock = "OpacMainUserBlock_".$language;
            my $rs = Koha::News->search({ branchcode => $branchcode, lang => $mainblock });
            my $c_lang = $rs->count;

            # Le code de le carrousel est entre $first_line et $second_line, donc je m'assure que c'est uniquement ce code qui est modifié
            my $first_line = "<!-- Debut du carrousel -->";
            my $second_line ="<!-- Fin du carrousel -->";

            #2.1.1 if not - add
            if ($c_lang == 0){
                my $value = '';
                #Si c'est la première utilisation, ca crée les tags $first_line et $second_line qui englobent la template
                if(index($value, $first_line) == -1 && index($value, $second_line) == -1  ){
                    $value = $value."\n".$first_line.$data.$second_line;
                } else{
                    $data = $first_line.$data.$second_line;
                    $value =~ s/$first_line.*?$second_line/$data/s;
                }
                if ($kohaversion > 21.05) {
                    Koha::NewsItem->new({ branchcode => $branchcode, lang => $mainblock, number => '0', title => $mainblock, content => $value, published_on => dt_from_string()->ymd() })->store;
                } else {
                    Koha::NewsItem->new({ branchcode => $branchcode, lang => $mainblock, number => '0', title => $mainblock, content => $value })->store;
                }
            }
            #2.1.2 if exists - modify
            else{
                my $yyiss = $rs->next;
                my $value = $yyiss->content;

                #Si c'est la première utilisation, ca crée les tags $first_line et $second_line qui englobent la template
                if(index($value, $first_line) == -1 && index($value, $second_line) == -1  ){
                    $value = $value."\n".$first_line.$data.$second_line;
                } else{
                    $data = $first_line.$data.$second_line;
                    $value =~ s/$first_line.*?$second_line/$data/s;
                }
                if ($kohaversion > 21.05) {
                    $yyiss->update({ branchcode => $branchcode, lang => $mainblock, number => '0',title => $mainblock, content => $value, updated_on => dt_from_string() });
                } else {
                    $yyiss->update({ branchcode => $branchcode, lang => $mainblock, number => '0',title => $mainblock, content => $value });
                }
            }
        }
    }
    elsif ( defined $kohaversion ) {  # sinon, utiliser le système de contenu additionnel
        # Plus besoin de regarder les langues. Le carrousel généré et le même pour les deux langues.

        my $location = 'OpacMainUserBlock';
        my $published_on = dt_from_string()->ymd();
        my $code = undef;
        #my $lang = "fr-CA";
        my $expirationdate = undef;
        my $number = undef;
        my $title = 'OpacMainUserBlock_Carrousel';
        my $category = 'html_customizations';
        my $borrowernumber = undef;
        my $content = '';

        # Le code de le carrousel est entre $first_line et $second_line, donc je m'assure que c'est uniquement ce code qui est modifié
        my $first_line = "<!-- Debut du carrousel -->";
        my $second_line ="<!-- Fin du carrousel -->";

        #Si c'est la première utilisation, ca crée les tags $first_line et $second_line qui englobent la template
        if(index($content, $first_line) == -1 && index($content, $second_line) == -1  ){
            $content = $content."\n".$first_line.$data.$second_line;
        } else{
            $data = $first_line.$data.$second_line;
            $content =~ s/$first_line.*?$second_line/$data/s;
        }

        # Enlever les carrousels spécifiques à chaque langue qui était là auparavant
        # dans les versions précédentes de Koha
        Koha::AdditionalContents->search({
            category => $category,
            location => $location,
            branchcode => $branchcode,
            title => {
                '!=', 'OpacMainUserBlock_Carrousel',
                -like => 'OpacMainUserBlock\_%' # pour match OpacMainUserBlock_fr-CA, OpacMainUserBlock_en, etc.
            }
        })->delete;

        #TODO: verify if it has to be applied to individual branches
        #2.1 check if opacmainuserblock exists
        my $additional_content = Koha::AdditionalContents->find({
        location   => $location,
        branchcode => $branchcode,
        title      => $title,
        });
        if( $additional_content ) {
            $code = $additional_content->code;
        }

        # get entry for this specific lang
        $additional_content = Koha::AdditionalContents->find({
            code       => $code || 'tmp_code',
            category   => $category,
            branchcode => $branchcode,
            lang       => $lang,
            title      => $title,
        });

        #2.1.2 if lang exists update
        if ( $additional_content ) {
            my $updated;
            eval {
                $additional_content->set({
                    category       => $category,
                    code           => $code || 'tmp_code',
                    location       => $location,
                    branchcode     => $branchcode,
                    title          => $title,
                    content        => $content,
                    lang           => $lang,
                    expirationdate => $expirationdate,
                    published_on   => $published_on,
                    number         => $number,
                    borrowernumber => $borrowernumber,
                });
                $updated = $additional_content->_result->get_dirty_columns;
                $additional_content->store;
            };
        }
        #2.1.3 else add new
        else {
            my $additional_content = Koha::AdditionalContent->new({
                category       => $category,
                code           => $code || 'tmp_code',
                location       => $location,
                branchcode     => $branchcode,
                title          => $title,
                content        => $content,
                lang           => $lang,
                expirationdate => $expirationdate,
                published_on   => $published_on,
                number         => $number,
                borrowernumber => $borrowernumber,
            })->store;
            eval {
                $additional_content->store;
                unless ($code) {
                    $additional_content->discard_changes;
                    $code = $category eq 'news'
                    ? 'News_' . $additional_content->idnew
                    : $location . '_' . $additional_content->idnew;
                    $additional_content->code($code)->store;
                }
            };
        }
    } else {
        #somewhere else
        print "Error! Please check your configuration\n";
    }
    
}

# routines pour récupérer les images

sub retrieveUrlFromGoogleJson {
    my $res = shift;
    my $json = decode_json($res->decoded_content);

    return unless exists $json->{items};
    return unless        $json->{items}->[0];
    return unless exists $json->{items}->[0]->{volumeInfo};
    return unless exists $json->{items}->[0]->{volumeInfo}->{imageLinks};
    return unless exists $json->{items}->[0]->{volumeInfo}->{imageLinks}->{thumbnail};

    return $json->{items}->[0]->{volumeInfo}->{imageLinks}->{thumbnail};
}

sub retrieveUrlFromCoceJson {
    my $res = shift;
    my $json = decode_json($res->decoded_content);

    return unless keys %$json;
    for my $k (keys %$json) {
        # le lien de la btlf est à usage unique, ce qui doit être évité pour le carrousel
        next if ($json->{$k} =~ m/restapi.mementolivres.com/);
        return $json->{$k};
    }
}

sub retrieveUrlFromBourriquetJson {
    my $res = shift;
    return unless $res->decoded_content;

    my $json = decode_json($res->decoded_content);
    my $stdnos = $json->{stdnos};
    my $record_numbers = $json->{record_numbers};

    if (keys(%$stdnos)) {
        my @keys_stdnos = keys(%$stdnos);
        return unless $stdnos->{$keys_stdnos[0]};
        return unless $stdnos->{$keys_stdnos[0]}->{thumbnail} ne "";
        return $stdnos->{$keys_stdnos[0]}->{thumbnail};
    } elsif (keys(%$record_numbers)) {
        my @keys_record_numbers = keys(%$record_numbers);
        return unless $record_numbers->{$keys_record_numbers[0]};
        return unless $record_numbers->{$keys_record_numbers[0]}->{thumbnail} ne "";
        return $record_numbers->{$keys_record_numbers[0]}->{thumbnail};
    }
    else {
        return;
    }
}

sub getUrlFromExternalSources {
    my $isbn = shift;
    my $biblionumber = shift;

    # les clefs sont les systempreferences du même nom
    my $es = {};

    if (C4::Context->preference('BourriquetOpac') && C4::Context->preference('BourriquetToken') && C4::Context->preference('BourriquetProviders')) {
        $es->{BourriquetOpac} = {
            'priority' => 1,
            'retrieval' => \&retrieveUrlFromBourriquetJson,
            'url' => C4::Context->preference('OPACBaseURL')."/cgi-bin/koha/svc/bourriquet/images/?stdnos=$isbn|$biblionumber&providers=".C4::Context->preference('BourriquetProviders'),
        };
    }

    $es->{OpacCoce} = {
        'priority' => 2,
        'retrieval' => \&retrieveUrlFromCoceJson,
        'url' => C4::Context->preference('CoceHost').'/cover'
                ."?id=$isbn"
                ."&bn=$biblionumber"
                .'&provider='.join(',', C4::Context->preference('CoceProviders'))
                .'&thumbnail=1',
    };

    $es->{OPACAmazonCoverImages} = {
        'priority' => 3,
        'url' => "https://images-na.ssl-images-amazon.com/images/P/$isbn.01.MZZZZZZZ.jpg",
        'content_length' => 500, # FIXME pourquoi seuil minimal de 500?
    };

    $es->{GoogleJackets} = {
        'priority' => 4,
        'retrieval' => \&retrieveUrlFromGoogleJson,
        'url' => "https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn&country=CA",
    };

    $es->{OpenLibraryCovers} = {
        'priority' => 5,
        'url' => "https://covers.openlibrary.org/b/isbn/$isbn-M.jpg?default=false",
    };

    my $ua = LWP::UserAgent->new;
    $ua->timeout(2);
    $ua->ssl_opts(verify_hostname => 0);
    my @orderedProvidersByPriority = sort { $es->{$a}->{priority} <=> $es->{$b}->{priority} } keys %$es;

    for my $provider ( @orderedProvidersByPriority ) {
        my $url = $es->{$provider}->{url};
        my $req = HTTP::Request->new( GET => $url );
        my $res = $ua->request( $req );

        next if !$res->is_success;

        if ( exists $es->{$provider}->{content_length} ) {
            next if $res->header('content_length') <= $es->{$provider}->{content_length};
        }

        if ( exists $es->{$provider}->{retrieval} ) {
            $url = $es->{$provider}->{retrieval}->($res);
            next unless $url;
        }

        # GoogleJackets returns http links.
        if ( $url =~ m!^http://!) {
            $url =~ s/http:\/\//https:\/\//;
        }

        if ( $url =~ m!^/9j/! ) {
            $url = 'data:image/jpg;base64, ' . $url;
        }

        return $url;
    } # foreach providers

    # FIXME: hardcoded fallback to Amazon.com, cam#6918
    my $url = $es->{OPACAmazonCoverImages}->{url};
    my $req = HTTP::Request->new( GET => $url );
    my $res = $ua->request( $req );
    return if !$res->is_success;
    return if $res->header('content_length') <= $es->{OPACAmazonCoverImages}->{content_length};
    return $url;
}

sub getThumbnailUrl
{
    my $biblionumber = shift;
    my $record = shift;
    return if ! $record;
    my $marcflavour = C4::Context->preference("marcflavour");
    my @isbns;
    if ($marcflavour eq 'MARC21' ){
        @isbns = $record->field('020');
    }elsif($marcflavour eq 'UNIMARC'){
        @isbns = $record->field('010');
    }

    # We look for image localy, if available we return relative path and exit function.
    my $cover_images_table='cover_images';
    if ( getKohaVersion() < 20.0600049 ) {
        $cover_images_table='biblioimages';
    }

    my $stm = $dbh->prepare("SELECT COUNT(*) AS count FROM $cover_images_table WHERE biblionumber=$biblionumber;");
    $stm->execute();
    if ( $stm->fetchrow_hashref()->{count} > 0 ) {
        return "/cgi-bin/koha/opac-image.pl?thumbnail=1&biblionumber=$biblionumber";
    }

    #If there is not local thumbnail, we look for one on Amazon, Google and Openlibrary in this order and we will exit when a thumbnail is found.
    foreach my $field ( @isbns )
    {
        my $isbn = GetNormalizedISBN( $field->subfield('a') );
        next if ! $isbn;

        return getUrlFromExternalSources($isbn, $biblionumber);
    }

    return;
}

sub configure {
    my ( $self, $args) = @_;
    my $cgi = $self->{'cgi'};

    if ($cgi->param("action")) {
        my $carrousels         = $cgi->param('carrousels');
        my $shelvesOrder       = $cgi->param('shelvesOrder');
        my $bgColor            = $cgi->param('bgColor');
        my $txtColor           = $cgi->param('txtColor');
        my $autoRotateDirection = $cgi->param('autorotate-direction');
        my $autoRotateDelay    = $cgi->param('autorotate-delay') || undef;
        my $last_configured_by = C4::Context->userenv->{'number'};
        my $generateJSON       = $cgi->param('generateJSON');

        $self->store_data(
            {
                carrousels         => $carrousels,
                bgColor            => $bgColor,
                txtColor           => $txtColor,
                autoRotateDirection => $autoRotateDirection,
                autoRotateDelay    => $autoRotateDelay,
                last_configured_by => $last_configured_by,
                generateJSON       => $generateJSON,
            }
        );

        $self->go_home();
    } else {
        my $carrousels = $self->getEnabledCarrousels();
        my $modules = $self->getModules();

        my $template = $self->retrieve_template("configure");
        $template->param(
            carrousels     => $carrousels,
            lists          => $modules->{lists},
            reports        => $modules->{reports},
            collections    => $modules->{collections},
            bgColor        => $self->retrieve_data('bgColor'),
            txtColor       => $self->retrieve_data('txtColor'),
            autoRotateDirection => $self->retrieve_data('autoRotateDirection'),
            autoRotateDelay => $self->retrieve_data('autoRotateDelay'),
            generateJSON   => $self->retrieve_data('generateJSON'),
            ENCODING       => 'utf8',
        );
        print $cgi->header(-type => 'text/html',-charset => 'utf-8');
        print $template->output();
    }
}

sub install {
    my ( $self, $args ) = @_;

    # Nothing actually

    return 1;
}

sub upgrade {
    my ( $self, $args ) = @_;
    my $database_version = $self->retrieve_data('__INSTALLED_VERSION__') || $VERSION;

    # _version_compare Returns 1 if the first argument is the higher version
    if ($self->_version_compare("3.0", $database_version) == 1) {
        my @shelvesOrder = @{decode_json($self->retrieve_data('shelvesOrder'))} if (defined $self->retrieve_data('shelvesOrder'));
        my @enabledShelves = @{decode_json($self->retrieve_data('enabledShelves'))} if (defined $self->retrieve_data('enabledShelves'));
        my $type = $self->retrieve_data('type');

        my @carrousels;
        foreach my $id (@shelvesOrder) {
            if (grep(/^$id$/, @enabledShelves)) {
                my $carrousel = {
                    id     => $id,
                    module => "lists",
                    title  => "",
                    type   => $type || "carrousel",
                    autorotate => 0
                };
                push @carrousels, $carrousel;
            }
        }

        $self->store_data({ carrousels => encode_json(\@carrousels) });

        my $sth = $dbh->prepare("DELETE FROM plugin_data WHERE plugin_class = ? AND plugin_key in ('enabledShelves', 'shelves', 'shelvesOrder', 'type')");
        $sth->execute( $self->{'class'} );
    }

    return 1;
}

#Supprimer le plugin avec toutes ses données
sub uninstall() {
    my ( $self, $args ) = @_;

    my $stmt = $dbh->prepare("select * from systempreferences where variable='OpacMainUserBlock'");
    $stmt->execute();

    my $value;
    while (my $row = $stmt->fetchrow_hashref()) {
        $value ="$row->{'value'}";
    }

    # Le code du carrousel est entre $first_line et $second_line, donc je m'assure que c'est uniquement ce code qui est modifié
    my $first_line = "<!-- Debut du carrousel -->";
    my $second_line ="<!-- Fin du carrousel -->";
    $value =~ s/$first_line.*?$second_line//s;

    my $query = $dbh->prepare("update systempreferences set value= ? where variable='OpacMainUserBlock'");
    $query->bind_param(1,$value);
    #Executer le update sur le champ value de table systempreferences avec la nouvelle carrousel
    $query->execute();

    #Fermer toutes connections avec la BD
    $query->finish();
    $stmt->finish();

    return 1;
}

# retrieve the template that includes the prefix passed
# 'step_1'
# 'configure'
sub retrieve_template {
    my ( $self, $template_prefix ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = undef;
    return $template unless $template_prefix eq 'step_1' || $template_prefix eq 'configure';

    my $preferedLanguage = $cgi->cookie('KohaOpacLanguage');
    if ($preferedLanguage) {
        eval {
            $template = $self->get_template({ file => $template_prefix . '_' . $preferedLanguage . ".tt" })
        };

        if ( !$template ) {
            $preferedLanguage = substr $preferedLanguage, 0, 2;
            eval {
                $template = $self->get_template( { file => $template_prefix . '_' . $preferedLanguage .  ".tt" })
            };
        }
    }

    $template = $self->get_template( { file => $template_prefix . '.tt' } ) unless $template;
    return $template;
}

1;

