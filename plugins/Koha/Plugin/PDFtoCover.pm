package Koha::Plugin::PDFtoCover;

# Mehdi Hamidi, 2016 - InLibro
# Modified by : Bouzid Fergani, 2016 - InLibro
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
use warnings;
use CGI;
use LWP::UserAgent;
use LWP::Simple;
use base qw(Koha::Plugins::Base);
use C4::Auth;
use C4::Context;
use File::Spec;
use JSON qw( encode_json );

BEGIN {
    my $kohaversion = Koha::version;
    $kohaversion =~ s/(.*\..*)\.(.*)\.(.*)/$1$2$3/;
    my $module = $kohaversion < 21.0508000 ? "C4::Images" : "Koha::CoverImages";
    my $file = $module;
    $file =~ s[::][/]g;
    $file .= '.pm';
    require $file;
    $module->import;
}

our $dbh      = C4::Context->dbh();
our $VERSION  = 1.8;
our $metadata = {
    name            => 'PDFtoCover',
    author          => 'Mehdi Hamidi, Bouzid Fergani, Arthur Bousquet, The Minh Luong',
    description     => 'Creates cover images for documents missing one',
    date_authored   => '2016-06-08',
    date_updated    => '2022-11-18',
    minimum_version => '17.05',
    version         => $VERSION,
};

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
    my $op  = $cgi->param('op');

    my $lock_path = File::Spec->catdir( File::Spec->rootdir(), "tmp", ".Koha.PDFtoCover.lock" );
    my $lock = (-e $lock_path) ? 1 : 0;

    my $poppler = "/usr/bin/pdftocairo";
    unless (-e $poppler){
        $self->missingModule();
    }
    elsif ( $op && $op eq 'valide' ) {
        my $pdf = $self->displayAffected();
        $self->store_data({ to_process => $pdf });

        my $pid = fork();
        if ($pid) {
            my $template = $self->retrieve_template('step_1');
            $template->param( pdf  => $pdf );
            $template->param( wait => 1 );
            $template->param( done => 0 );
            print $cgi->header( -type => 'text/html', -charset => 'utf-8' );
            print $template->output();
            exit 0;
        }

        open my $fh, ">", $lock_path;
        close $fh;
        $self->genererVignette();
        unlink($lock_path);

        exit 0;
    }
    else {
        $self->step_1($lock);
    }
}

sub step_1 {
    my ( $self, $lock ) = @_;
    my $cgi = $self->{'cgi'};
    my $pdf = $self->displayAffected();

    my $template = $self->retrieve_template('step_1');
    $template->param( pdf  => $pdf );
    $template->param( wait => $lock );
    $template->param( done => $cgi->param('done') || 0 );
    print $cgi->header( -type => 'text/html', -charset => 'utf-8' );
    print $template->output();
}

sub missingModule {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $template = $self->retrieve_template('missingModule');
    print $cgi->header( -type => 'text/html', -charset => 'utf-8' );
    print $template->output();
}

sub getKohaVersion {
    # Current version of Koha from sources
    my $kohaversion = Koha::version;
    # remove the 3 last . to have a Perl number
    $kohaversion =~ s/(.*\..*)\.(.*)\.(.*)/$1$2$3/;
    return $kohaversion;
}

sub displayAffected {
    my ( $self, $args ) = @_;
    my $pdf = 0;
    my $kohaversion = getKohaVersion();
    my $query = "";
    if($kohaversion < 21.0508000){
      $query = "SELECT count(*) as count FROM biblio_metadata AS a WHERE EXTRACTVALUE(a.metadata,\"record/datafield[\@tag='856']/subfield[\@code='u']\") <> '' and a.biblionumber not in (select biblionumber from biblioimages);";
    }else{
      $query = "SELECT count(*) as count FROM biblio_metadata AS a WHERE EXTRACTVALUE(a.metadata,\"record/datafield[\@tag='856']/subfield[\@code='u']\") <> '' and a.biblionumber not in (select biblionumber from cover_images);";
    }
    my $stmt = $dbh->prepare($query);
    $stmt->execute();

    if ( my $row = $stmt->fetchrow_hashref() ) {
        $pdf = $row->{count};
    }

    return $pdf;
}

sub genererVignette {
    my ( $self, $args ) = @_;
    my $dbh = C4::Context->dbh;
    my $ua = LWP::UserAgent->new( timeout => "5" );
    my $kohaversion = getKohaVersion();
    my $query = "";
    if($kohaversion < 21.0508000){
      $query = "SELECT a.biblionumber, EXTRACTVALUE(a.metadata,\"record/datafield[\@tag='856']/subfield[\@code='u']\") AS url FROM biblio_metadata AS a WHERE EXTRACTVALUE(a.metadata,\"record/datafield[\@tag='856']/subfield[\@code='u']\") <> '' and a.biblionumber not in (select biblionumber from biblioimages);";
    }else{
      $query = "SELECT a.biblionumber, EXTRACTVALUE(a.metadata,\"record/datafield[\@tag='856']/subfield[\@code='u']\") AS url FROM biblio_metadata AS a WHERE EXTRACTVALUE(a.metadata,\"record/datafield[\@tag='856']/subfield[\@code='u']\") <> '' and a.biblionumber not in (select biblionumber from cover_images);";
    }
    # Retourne 856$u, qui est le(s) URI(s) d'une ressource numérique
    my $sthSelectPdfUri = $dbh->prepare($query);
    $sthSelectPdfUri->execute();

    while ( my ( $biblionumber, $urifield ) = $sthSelectPdfUri->fetchrow_array() ) {
        my @uris = split / /, $urifield;
        foreach my $url (@uris) {
            my $response = $ua->get($url);
            if ( $response->is_success && $response->header('content-type') =~ /application\/pdf/ ) {
                my $lastmodified = $response->header('last-modified');

                # On vérifie que le fichier à l'URL spécifié est bel et bien un pdf
                my @filestodelete = ();
                my $save          = C4::Context->temporary_directory();
                $save =~ s/\/*$/\//;
                $save .= $biblionumber;
                if ( is_success( getstore( $url, $save ) ) ) {
                    push @filestodelete, $save;
                    `pdftocairo "$save" -png "$save" -singlefile 2>&1`;    # Conversion de pdf à png, seulement pour la première page
                    my $imageFile = $save . ".png";
                    push @filestodelete, $imageFile;

                    my $srcimage = GD::Image->new($imageFile);
                    my $replace  = 1;
                    if($kohaversion < 21.0508000){
                        C4::Images::PutImage( $biblionumber, $srcimage, $replace );
                    }else{
                        my $input = CGI->new;
                        my $itemnumber = $input->param('itemnumber');
                        Koha::CoverImage->new(
                            {
                              biblionumber => $biblionumber,
                              itemnumber   => $itemnumber,
                              src_image    => $srcimage
                            }
                        )->store;
                    }
                    foreach my $file (@filestodelete) {
                        unlink $file or warn "Could not unlink $file: $!\nNo more images to import.Exiting.";
                    }
                    last;
                }
            }
        }

        $self->store_data({ to_process => $self->retrieve_data('to_process') - 1 });
    }
}

sub progress {
    my ($self) = @_;
    print $self->{'cgi'}->header( -type => 'application/json', -charset => 'utf-8' );
    print encode_json({ to_process => $self->retrieve_data('to_process') });
    exit 0;
}

# retrieve the template that includes the prefix passed
# 'step_1'
# 'missingModule'
sub retrieve_template {
    my ( $self, $template_prefix ) = @_;
    my $cgi = $self->{'cgi'};

    return undef unless $template_prefix eq 'step_1' || $template_prefix eq 'missingModule';

    my $preferedLanguage = $cgi->cookie('KohaOpacLanguage');
    my $template = undef;
    eval {
        $template  = $self->get_template({ file => $template_prefix . '_' . $preferedLanguage . ".tt" })
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

#Supprimer le plugin avec toutes ses données
sub uninstall() {
    my ( $self, $args ) = @_;
    return 1;
}

1;
