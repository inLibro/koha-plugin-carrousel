package Koha::Plugin::Carrousel;
# Mehdi Hamidi, 2016 - InLibro
# Modified by Bouzid Fergani, 2016 - InLibro
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
use C4::Auth;
use C4::Biblio;
use C4::Context;
use C4::Koha qw(GetNormalizedISBN);
use C4::Output;
use C4::XSLT;

our $VERSION = 1.6;
our $metadata = {
    name            => 'Carrousel',
    author          => 'Mehdi Hamidi',
    description     => 'Generates a carrousel from available lists',
    date_authored   => '2016-05-27',
    date_updated    => '2018-04-18',
    minimum_version => '3.20',
    maximum_version => undef,
    version         => $VERSION,
};

our $useSql = 0;
if (!(eval("use Koha::Virtualshelves") || !(eval("use Koha::Virtualshelfcontents")))) {
    $useSql =1;
}
our @shelves;
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

    if($useSql){
        $self->loadShelves();
    }else{
        @shelves =  Koha::Virtualshelves->search(undef,
            { order_by => { -asc => 'shelfname' }
        });
    }

    if ($cgi->param('action')){
        my $selectedShelf = $cgi->param('selectedShelf');
        $self->generateCarroussel($selectedShelf);
        $self->go_home();
    }else{
        $self->step_1();
    }

}

#Charger les listes en utilisant sql si le module virtualShelves n'est pas disponible
sub loadShelves{
    my ( $self, $args) = @_;
    my $dbh = $dbh;
    my $stmt = $dbh->prepare("SELECT * FROM virtualshelves ORDER BY shelfname");
    $stmt->execute();

    my $i =0;
    while (my $row = $stmt->fetchrow_hashref()) {
        $shelves[$i] = $row;
        $i++;
    }
}

#Charger le contenus des listes en utilisant sql si le module virtualshelfcontents n'est pas disponible
sub loadContent{
    my ( $self, $virtualshelf) = @_;
    my $dbh =  $dbh;
    my $stmt = $dbh->prepare("select * from virtualshelfcontents where shelfnumber =?");
    $stmt ->bind_param(1,$virtualshelf);
    $stmt->execute();

    my $i =0;
    my @content;
    while (my $row = $stmt->fetchrow_hashref()) {
        $content[$i] = $row;
        $i++;
    }
    return @content;
}

sub step_1{
    my ( $self, $args) = @_;
    my $cgi = $self->{'cgi'};
    #chercher la langue de l'utilisateur
    my $preferedLanguage = $cgi->cookie('KohaOpacLanguage');
    #La template par défault est en anglais et tout depend du cookie, il va charger la template en français
    my $template = undef;
    if ($preferedLanguage) {
        eval {$template = $self->get_template( { file => "step_1_" . $preferedLanguage . ".tt" } )};
        if(!$template){
            $preferedLanguage = substr $preferedLanguage, 0, 2;
            eval {$template = $self->get_template( { file => "step_1_$preferedLanguage.tt" } )};
        }
    }
    $template = $self->get_template( { file => 'step_1.tt' } ) unless $template;

    $template->param(shelves => \@shelves, selectedShelf => $self->retrieve_data('selectedShelf'));
    print $cgi->header(-type => 'text/html',-charset => 'utf-8');
    print $template->output();
}

sub generateCarroussel{
    my ( $self, $selectedShelf) = @_;
    my $shelf;
    my $sqllist;

    if($useSql){
        foreach $sqllist (@shelves){
            $shelf = $sqllist if($sqllist->{'shelfnumber'} == $selectedShelf);
        }

    } else{
        foreach my $list (@shelves){
            $shelf = $list if($list->shelfnumber == $selectedShelf);
        }
    }

    my $shelfid;
    if($useSql){
        $shelfid = $shelf->{'shelfnumber'};
    }else{
        $shelfid = $shelf->shelfnumber;
    }

    #content : shelfnumber,biblionumber,flags,dateadded, borrowernumber
    my @contents;
    if($useSql){
        @contents = $self->loadContent($shelfid);
    }else {
        @contents = Koha::Virtualshelfcontents->search({shelfnumber => $shelf->shelfnumber});
    }

    my @items;
    if($useSql){
        foreach my $content (@contents){
            push @items,$content->{'biblionumber'};
        }
    }else{
        foreach my $content (@contents){
            push @items,$content->biblionumber;
        }
    }

    my @images;
    my $shelfname;
    if($useSql){
        $shelfname = $shelf->{'shelfname'};
    }else{
        $shelfname = $shelf->shelfname;
    }
    $shelfname =~ s/[^a-zA-Z0-9]/_/g;

    foreach my $biblionumber ( @items ) {
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
        warn "[Koha::Plugin::Carrousel] No images were found for virtualshelf '$shelfname' (id: $selectedShelf). OpacMainUserBlock kept unchanged.\n";
        return;
    }

    my $pluginDirectory = C4::Context->config("pluginsdir");
    my $tt = Template->new(INCLUDE_PATH => $pluginDirectory);
    my $data = "";

    $tt->process('Koha/Plugin/Carrousel/opac-carrousel.tt',
                {   shelfname => $shelfname,
                    documents => \@images,
                    bgColor => $self->retrieve_data('bgColor'),
                    txtColor => $self->retrieve_data('txtColor')
                },
                \$data,
                { binmode => ':utf8' }
                ) || warn "Unable to generate Carrousel, ". $tt->error();


    $self->insertIntoPref($data);
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
    return $json->{$_} for keys %$json;
}

sub getUrlFromExternalSources {
    my $isbn = shift;

    # les clefs sont les systempreferences du même nom
    my $es = {};

    $es->{OpacCoce} = {
        'priority' => 1,
        'retrieval' => \&retrieveUrlFromCoceJson,
        'url' => C4::Context->preference('CoceHost').'/cover'
                ."?id=$isbn"
                .'&provider='.join(',', C4::Context->preference('CoceProviders')),
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
    my @orderedProvidersByPriority = sort { $es->{$a}->{priority} <=> $es->{$b}->{priority} } keys %$es;

    for my $provider ( @orderedProvidersByPriority ) {

        next if ( $provider eq 'OpacCoce' );

        if ( C4::Context->preference($provider) ) {

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

            return $url;

        } # if source enabled by systempreference
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
    if ( C4::Context->preference("OPACLocalCoverImages") ) {
        my $stm = $dbh->prepare("SELECT COUNT(*) AS count FROM biblioimages WHERE biblionumber=$biblionumber;");
        $stm->execute();
        if ( $stm->fetchrow_hashref()->{count} > 0 ) {
            return "/cgi-bin/koha/opac-image.pl?thumbnail=1&biblionumber=$biblionumber";
        }
    }

    #If there is not local thumbnail, we look for one on Amazon, Google and Openlibrary in this order and we will exit when a thumbnail is found.
    foreach my $field ( @isbns )
    {
        my $isbn = GetNormalizedISBN( $field->subfield('a') );
        next if ! $isbn;

        return getUrlFromExternalSources($isbn);
    }

    return;
}

sub configure{
    my ( $self, $args) = @_;
    my $cgi = $self->{'cgi'};
    my $preferedLanguage = $cgi->cookie('KohaOpacLanguage');
    if($useSql){
        $self->loadShelves();
    }else{
        @shelves =  Koha::Virtualshelves->search();
    }
    if($cgi->param("action")){
        $self->store_data(
        {
            shelves             => \@shelves,
            bgColor             => $cgi->param('bgColor'),
            txtColor            => $cgi->param('txtColor'),
            selectedShelf        => $cgi->param('selectedShelf'),
            last_configured_by => C4::Context->userenv->{'number'},
        }
        );
        $self->go_home();
    }else{
        #La template par défault est en anglais et tout depend du cookie, il va charger la template en français
        my $template = undef;
        if ($preferedLanguage){
            eval {$template = $self->get_template( { file => "configure_" . $preferedLanguage . ".tt" } )};
            if(!$template){
                $preferedLanguage = substr $preferedLanguage, 0, 2;
                eval {$template = $self->get_template( { file => "configure_$preferedLanguage.tt" } )};
            }
        }
        $template = $self->get_template( { file => 'configure.tt' } ) unless $template;

        $template->param(
            shelves       => \@shelves,
            bgColor       => $self->retrieve_data('bgColor'),
            txtColor      => $self->retrieve_data('txtColor'),
            selectedShelf => $self->retrieve_data('selectedShelf')
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

1;
