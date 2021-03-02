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
use C4::Biblio;
use C4::Context;
use C4::Koha qw(GetNormalizedISBN);
use C4::Output;
use C4::XSLT;
use Koha::Reports;
use C4::Reports::Guided;
use Koha::Uploader;
use Koha::News;

our $VERSION = 3.7;
our $metadata = {
    name            => 'Carrousel 3.7',
    author          => 'Mehdi Hamidi, Maryse Simard, Brandon Jimenez',
    description     => 'Generates a carrousel from available data sources (lists, reports or collections).',
    date_authored   => '2016-05-27',
    date_updated    => '2021-03-02',
    minimum_version => '3.20',
    maximum_version => undef,
    version         => $VERSION,
};

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
                my ( $sth, $errors ) = execute_query($sql);
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
        my $stmt = $dbh->prepare(
            "SELECT distinct biblionumber
            FROM items
            WHERE ccode = ?");
        $stmt->execute($id);

        while (my $row = $stmt->fetchrow_hashref()) {
            push @content, $row->{biblionumber};
        }
    } elsif ($useSql) {
        my $stmt = $dbh->prepare("SELECT * FROM virtualshelfcontents WHERE shelfnumber = ?");
        $stmt->execute($id);
        while (my $row = $stmt->fetchrow_hashref()) {
            push @content, $row->{biblionumber};
        }
    } else {
        my @shelves = Koha::Virtualshelfcontents->search({ shelfnumber => $id });
        foreach my $item (@shelves) {
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

    $self->insertIntoPref($data);
    $self->generateJSONFile($carrousels) if ($self->retrieve_data('generateJSON'));
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
    foreach my $biblionumber ( @contents ) {
        my $record = GetMarcBiblio({ biblionumber => $biblionumber });
        # Attempt the old call
        if (! $record) {
            $record = GetMarcBiblio( $biblionumber );
        }
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
        }else{
            warn "[Koha::Plugin::Carrousel] There was no image found for biblionumber $biblionumber : \" $title \"\n";
        }
    }

    unless ( @images ) {
        warn "[Koha::Plugin::Carrousel] No images were found for $module with id $id. OpacMainUserBlock kept unchanged.\n";
        return;
    }

    return \@images;
}

sub insertIntoPref{
    my ( $self, $data) = @_;

    # we select the current version of Koha
    my $kohaversion = Koha::version;
    # remove the 3 last . to have a Perl number
    $kohaversion =~ s/(.*\..*)\.(.*)\.(.*)/$1$2$3/;

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
    } elsif ( defined $kohaversion ) {  # sinon, utiliser le système de nouvelle
        #1. check installed languages
        my $opaclanguages = C4::Context->preference('opaclanguages');
        
        #expected ex opaclanguages = "fr-CA,en"
        my @languages = split /,/, $opaclanguages;
        #2. for each installed language
        foreach my $language (@languages) {
            #TODO: verify if it has to be applied to individual branches
            #2.1 check if opacmainuserblock exists
            my $mainblock = "OpacMainUserBlock_".$language;
            my $rs = Koha::News->search({ lang => $mainblock });
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
                Koha::NewsItem->new({ lang => $mainblock, number => '0', title => $mainblock, content => $value })->store;
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
                $yyiss->update({ lang => $mainblock,number => '0',title => $mainblock,content => $value });
            }
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

sub getUrlFromExternalSources {
    my $isbn = shift;
    my $biblionumber = shift;

    # les clefs sont les systempreferences du même nom
    my $es = {};

    $es->{OpacCoce} = {
        'priority' => 1,
        'retrieval' => \&retrieveUrlFromCoceJson,
        'url' => C4::Context->preference('CoceHost').'/cover'
                ."?id=$isbn"
                ."&bn=$biblionumber"
                .'&provider='.join(',', C4::Context->preference('CoceProviders'))
                .'&thumbnail=1',
    };

    $es->{OPACAmazonCoverImages} = {
        'priority' => 2,
        'url' => "https://images-na.ssl-images-amazon.com/images/P/$isbn.01.MZZZZZZZ.jpg",
        'content_length' => 500, # FIXME pourquoi seuil minimal de 500?
    };

    $es->{GoogleJackets} = {
        'priority' => 3,
        'retrieval' => \&retrieveUrlFromGoogleJson,
        'url' => "https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn&country=CA",
    };

    $es->{OpenLibraryCovers} = {
        'priority' => 4,
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
    my $stm = $dbh->prepare("SELECT COUNT(*) AS count FROM biblioimages WHERE biblionumber=$biblionumber;");
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
        my $carrousels         = $cgi->param('carrousels'),
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

    if ($database_version < 3.0) {
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
