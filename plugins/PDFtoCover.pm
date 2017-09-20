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
use C4::Images;
use File::Spec;

our $dbh      = C4::Context->dbh();
our $VERSION  = 1.1;
our $metadata = {
    name            => 'PDFtoCover',
    author          => 'Mehdi Hamidi, Bouzid Fergani',
    description     => 'Creates cover images for documents missing one',
    date_authored   => '2016-06-08',
    date_updated    => '2017-09-20',
    minimum_version => '17.05',
    maximum_version => undef,
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
    my $cgi      = $self->{'cgi'};
    my $op       = $cgi->param('op');
    my @sortie   = `ps -eo user,bsdstart,command --sort bsdstart`;
    my @lockfile = `ls -s /tmp/.Koha.PDFtoCover.lock`;
    my @process;

    foreach my $val (@sortie) {
        push @process, $val if ( $val =~ '/plugins/run.pl' );
    }

    my $nombre           = scalar(@process);
    my $lock             = scalar(@lockfile);
    my $preferedLanguage = $cgi->cookie('KohaOpacLanguage');
    my $warning          = eval {`dpkg -s libcairo2-dev`};
    my $pdftocairo       = "/usr/bin/pdftocairo";

    unless ( -e $pdftocairo ) {
        $self->missingModule();
    }
    elsif ( $op && $op eq 'valide' ) {
        my $pid = fork();
        if ($pid) {
            my $template = undef;
            eval { $template = $self->get_template( { file => "step_1_" . $preferedLanguage . ".tt" } ) };
            if ( !$template ) {
                $preferedLanguage = substr $preferedLanguage, 0, 2;
                eval { $template = $self->get_template( { file => "step_1_$preferedLanguage.tt" } ) };
            }
            $template = $self->get_template( { file => 'step_1.tt' } ) unless $template;
            my $pdf = $self->displayAffected();
            $template->param( pdf     => $pdf );
            $template->param( 'wait'  => 1 );
            $template->param( 'exist' => 0 );
            $template->param( lock    => 0 );
            print $cgi->header( -type => 'text/html', -charset => 'utf-8' );
            print $template->output();
            exit 0;
        }
        else {
            close STDOUT;
        }
        open my $fh, ">", File::Spec->catdir( "/tmp/", ".Koha.PDFtoCover.lock" );
        &genererVignette();
        `rm /tmp/.Koha.PDFtoCover.lock`;
        exit 0;
    }
    else {
        $self->step_1( $nombre, $lock );
    }
}

sub step_1 {
    my ( $self, $nombre, $lock ) = @_;
    my $cgi              = $self->{'cgi'};
    my $preferedLanguage = $cgi->cookie('KohaOpacLanguage');
    my $template         = undef;
    my $pdf              = $self->displayAffected();

    eval { $template = $self->get_template( { file => "step_1_" . $preferedLanguage . ".tt" } ) };
    if ( !$template ) {
        $preferedLanguage = substr $preferedLanguage, 0, 2;
        eval { $template = $self->get_template( { file => "step_1_$preferedLanguage.tt" } ) };
    }
    $template = $self->get_template( { file => 'step_1.tt' } ) unless $template;

    $template->param( 'wait' => 0 );
    $template->param( exist  => $nombre );
    $template->param( lock   => $lock );
    $template->param( pdf    => $pdf );
    print $cgi->header( -type => 'text/html', -charset => 'utf-8' );
    print $template->output();
}

sub missingModule {
    my ( $self, $args ) = @_;
    my $cgi              = $self->{'cgi'};
    my $preferedLanguage = $cgi->cookie('KohaOpacLanguage');
    my $template         = undef;

    eval { $template = $self->get_template( { file => "missingModule_" . $preferedLanguage . ".tt" } ) };
    if ( !$template ) {
        $preferedLanguage = substr $preferedLanguage, 0, 2;
        eval { $template = $self->get_template( { file => "missingModule_$preferedLanguage.tt" } ) };
    }
    $template = $self->get_template( { file => 'missingModule.tt' } ) unless $template;

    print $cgi->header( -type => 'text/html', -charset => 'utf-8' );
    print $template->output();
}

sub displayAffected {
    my ( $self, $args ) = @_;
    my $pdf = 0;
    my $query
        = "SELECT a.biblionumber, EXTRACTVALUE(a.metadata,\"record/datafield[\@tag='856']/subfield[\@code='u']\") AS url  FROM biblio_metadata AS a WHERE EXTRACTVALUE(a.metadata,\"record/datafield[\@tag='856']/subfield[\@code='u']\") <>'' and a.biblionumber not in (select biblionumber from biblioimages);";

    my $stmt = $dbh->prepare($query);
    $stmt->execute();
    while ( my $row = $stmt->fetchrow_hashref() ) {
        my @uris = split / /, $row->{url};
        foreach my $url (@uris) {
            if ( substr( $url, -3 ) eq 'pdf' ) {
                $pdf++;
            }
        }
    }
    return $pdf;
}

sub genererVignette {
    my ( $self, $args ) = @_;
    my $dbh = C4::Context->dbh;
    my $ua = LWP::UserAgent->new( timeout => "5" );
    my $query
        = "SELECT a.biblionumber, EXTRACTVALUE(a.metadata,\"record/datafield[\@tag='856']/subfield[\@code='u']\") AS url  FROM biblio_metadata AS a WHERE EXTRACTVALUE(a.metadata,\"record/datafield[\@tag='856']/subfield[\@code='u']\") <>'' and a.biblionumber not in (select biblionumber from biblioimages);";

    # Retourne 856$u, qui est le(s) URI(s) d'une ressource numérique
    my $sthSelectPdfUri = $dbh->prepare($query);
    $sthSelectPdfUri->execute();
    while ( my ( $biblionumber, $urifield ) = $sthSelectPdfUri->fetchrow_array() ) {
        my @uris = split / /, $urifield;
        foreach my $url (@uris) {
            my $response = $ua->get($url);
            if ( $response->is_success && $response->header('content-type') eq "application/pdf" ) {
                my $lastmodified = $response->header('last-modified');

                # On vérifie que le fichier à l'URL spécifié est bel et bien un pdf
                my @filestodelete = ();
                my $filename      = $url;
                my $save          = '';
                $filename =~ m/.*\/(.*)$/;
                $filename = $1;
                $save     = "/tmp/$filename";
                if ( is_success( getstore( $url, $save ) ) ) {
                    push @filestodelete, $save;
                    `pdftocairo $save -png $save -singlefile 2>&1`;    # Conversion de pdf à png, seulement pour la première page
                    my $imageFile = $save . ".png";
                    push @filestodelete, $imageFile;

                    my $srcimage = GD::Image->new($imageFile);
                    my $replace  = 1;
                    C4::Images::PutImage( $biblionumber, $srcimage, $replace );
                    foreach my $file (@filestodelete) {
                        unlink $file or warn "Could not unlink $file: $!\nNo more images to import.Exiting.";
                    }
                    last;
                }
            }
        }
    }
}

#Supprimer le plugin avec toutes ses données
sub uninstall() {
    my ( $self, $args ) = @_;
    my $table = $self->get_qualified_table_name('mytable');

    return C4::Context->dbh->do("DROP TABLE $table");
}

1;
