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
use JSON qw( decode_json );
use LWP::Simple;
use Template;
use utf8;
use base qw(Koha::Plugins::Base);
#use C4::Auth;
use C4::Biblio;
use C4::Context;
use C4::Koha qw(GetNormalizedISBN);
use C4::Output;
use C4::XSLT;

our $VERSION = 2.0;
our $metadata = {
    name            => 'Carrousel 2.0',
    author          => 'Mehdi Hamidi',
    description     => 'Generates a carrousel from available lists',
    date_authored   => '2016-05-27',
    date_updated    => '2020-09-03',
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
    my @enabledShelves = (!defined $self->retrieve_data('enabledShelves')) ? () : @{decode_json($self->retrieve_data('enabledShelves'))};
    $template->param(enabledShelves => \@enabledShelves);
    print $cgi->header(-type => 'text/html',-charset => 'utf-8');
    print $template->output();
}

sub getOrderedShelves {
    my ( $self, $args ) = @_;
    my @shelves;

    if ($useSql) {
        my $dbh = $dbh;
        my $stmt = $dbh->prepare("SELECT * FROM virtualshelves WHERE category = 2 ORDER BY shelfname");
        $stmt->execute();

        while (my $row = $stmt->fetchrow_hashref()) {
            push @shelves, $row;
        }
    } else {
        @shelves = Koha::Virtualshelves->get_public_shelves();
    }

    # ordering
    if (defined $self->retrieve_data('shelvesOrder')) {
        my @shelvesOrder = @{decode_json($self->retrieve_data('shelvesOrder'))};
        my $shelvesOrderCount = @shelvesOrder;
        my @orderedShelves;
        my @otherShelves;
        foreach my $list (@shelves) {
            my $id = ($useSql) ? $list->{'shelfnumber'} : $list->shelfnumber;
            my $found = 0;
            for (my $i = 0; $i < $shelvesOrderCount; $i++) {
                if ($id == $shelvesOrder[$i]) {
                    $orderedShelves[$i] = $list;
                    $found = 1;
                    last;
                }
            }
            push(@otherShelves, $list) unless ($found);
        }

        my @temp = @orderedShelves;
        @orderedShelves = ();
        for my $list (@temp) {
            push(@orderedShelves, $list) if ($list != undef);
        }

        @shelves = @orderedShelves;
        push(@shelves, @otherShelves);
    }

    return @shelves;
}

#Charger le contenus des listes en utilisant sql si le module virtualshelfcontents n'est pas disponible
sub loadContent {
    my ( $self, $virtualshelf ) = @_;
    my @content;

    if ($useSql) {
        my $id = $virtualshelf->{'shelfnumber'};
        my $stmt = $dbh->prepare("select * from virtualshelfcontents where shelfnumber =?");
        $stmt->execute($id);

        my $i = 0;
        while (my $row = $stmt->fetchrow_hashref()) {
            $content[$i] = $row;
            $i++;
        }
    } else {
        @content = Koha::Virtualshelfcontents->search({shelfnumber => $virtualshelf->shelfnumber});
    }

    return @content;
}

sub generateCarrousels{
    my ( $self ) = @_;
    my @carrousels = $self->getCarrousels();
    my $tt = Template->new(
        INCLUDE_PATH => C4::Context->config("pluginsdir"),
        ENCODING     => 'utf8',
    );
    my $data = "";
    binmode( STDOUT, ":utf8" );
    $tt->process(
        'Koha/Plugin/Carrousel/opac-carrousel.tt',
        {
            carrousels  => \@carrousels,
            type     => $self->retrieve_data('type'),
            bgColor  => $self->retrieve_data('bgColor'),
            txtColor => $self->retrieve_data('txtColor'),
            ENCODING => 'utf8',
        },
        \$data,
        { binmode => ':utf8' }
    ) || warn "Unable to generate Carrousel, " . $tt->error();

    $self->insertIntoPref($data);
}

sub getCarrousels {
    my ( $self ) = @_;
    my @shelves = $self->getOrderedShelves();
    my @carrousels = ();

    return @carrousels if (!defined $self->retrieve_data('enabledShelves'));
    my @enabledShelvesId = @{decode_json($self->retrieve_data('enabledShelves'))};

    foreach my $list (@shelves) {
        my $id = ($useSql) ? $list->{'shelfnumber'} : $list->shelfnumber;
        if (grep(/^$id$/, @enabledShelvesId)) {
            my %carrousel = $self->getCarrousel($list);
            push(@carrousels, \%carrousel) if %carrousel;
        }
    }

    return @carrousels;
}

sub getCarrousel{
    my ( $self, $shelf ) = @_;

    my $shelfname = ($useSql) ? $shelf->{'shelfname'} : $shelf->shelfname;
    #$shelfname =~ s/[^a-zA-Z0-9]/_/g;
    #content : shelfnumber,biblionumber,flags,dateadded, borrowernumber
    my @contents = $self->loadContent($shelf);

    my @images;
    foreach my $content ( @contents ) {
        my $biblionumber = ($useSql) ? $content->{'biblionumber'} : $content->biblionumber;
        my $record = GetMarcBiblio({ biblionumber => $biblionumber });
        # Attempt the old call
        if (! $record) {
            $record = GetMarcBiblio( $biblionumber );
        }
        next if ! $record;
        my $title;
        my $marcflavour = C4::Context->preference("marcflavour");
        if ($marcflavour eq 'MARC21'){
            $title = $record->subfield('245', 'a');
        }elsif ($marcflavour eq 'UNIMARC'){
            $title = $record->subfield('200', 'a');
        }
        $title =~ s/[,:\/\s]+$//;

        my $url = getThumbnailUrl( $biblionumber, $record );
        if ( $url ){
            my %image = ( url => $url, title => $title, biblionumber => $biblionumber );
            push @images, \%image;
        }else{
            warn "[Koha::Plugin::Carrousel] There was no image found for biblionumber $biblionumber : \" $title \"\n";
        }
    }

    unless ( @images ) {
        my $shelfid = ($useSql) ? $shelf->{'shelfnumber'} : $shelf->shelfnumber;
        warn "[Koha::Plugin::Carrousel] No images were found for virtualshelf '$shelfname' (id: $shelfid). OpacMainUserBlock kept unchanged.\n";
        return;
    }

    return ('name', $shelfname, 'documents', \@images);
}

sub insertIntoPref{
    my ( $self, $data) = @_;
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

    #Update system preference
    C4::Context->set_preference( 'OpacMainUserBlock' , $value );
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
        my $enabledShelves     = $cgi->param('enabledShelves');
        my $shelvesOrder       = $cgi->param('shelvesOrder');
        my $type               = $cgi->param('type');
        my $bgColor            = $cgi->param('bgColor');
        my $txtColor           = $cgi->param('txtColor');
        my $last_configured_by = C4::Context->userenv->{'number'};

        $self->store_data(
            {
                enabledShelves     => $enabledShelves,
                shelvesOrder       => $shelvesOrder,
                type               => $type,
                bgColor            => $bgColor,
                txtColor           => $txtColor,
                last_configured_by => $last_configured_by,
            }
        );

        $self->go_home();
    } else {
        my @shelves = $self->getOrderedShelves();

        my $template = $self->retrieve_template("configure");
        $template->param(
            shelves        => \@shelves,
            enabledShelves => $self->retrieve_data('enabledShelves'),
            type           => $self->retrieve_data('type'),
            bgColor        => $self->retrieve_data('bgColor'),
            txtColor       => $self->retrieve_data('txtColor'),
            ENCODING       => 'utf8',
        );
        print $cgi->header(-type => 'text/html',-charset => 'utf-8');
        print $template->output();
    }
}

#Supprimer le plugin avec toutes ses données
sub uninstall() {
    my ( $self, $args ) = @_;
    my $table = $self->get_qualified_table_name('mytable');
    my $dbh = $dbh;
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

    return C4::Context->dbh->do("DROP TABLE $table");
}

# retrieve the template that includes the prefix passed
# 'step_1'
# 'configure'
sub retrieve_template {
    my ( $self, $template_prefix ) = @_;
    my $cgi = $self->{'cgi'};

    return undef unless $template_prefix eq 'step_1' || $template_prefix eq 'configure';

    my $preferedLanguage = $cgi->cookie('KohaOpacLanguage');
    my $template = undef;
    eval {
        $template = $self->get_template({ file => $template_prefix . '_' . $preferedLanguage . ".tt" })
    };

    if ( !$template ) {
        $preferedLanguage = substr $preferedLanguage, 0, 2;
        eval {
            $template = $self->get_template( { file => $template_prefix . '_' . $preferedLanguage .  ".tt" })
        };
    }

    $template = $self->get_template( { file => $template_prefix . '.tt' } ) unless $template;
    return $template;
}

1;
