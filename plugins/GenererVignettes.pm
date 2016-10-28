package Koha::Plugin::GenererVignettes;
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

our $dbh = C4::Context->dbh();
our $VERSION = 1.1;
our $metadata = {
    name            => 'GenererVignettes',
    author          => 'Mehdi Hamidi, Bouzid Fergani',
    description     => 'Generate images for documents that they are missing one',
    date_authored   => '2016-06-08',
    date_updated    => '2016-10-21',
    minimum_version => '3.20',
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
    my $cgi = $self->{'cgi'};
    my $preferedLanguage = $cgi->cookie('KohaOpacLanguage');
    my $warning = eval{`dpkg -s libcairo2-dev`};
    if(!$warning){
        $self->missingModule();
    } elsif($cgi->param('op') eq 'valide'){
        my $last = $cgi->param('last');
        my $numberError = $cgi->param('erreur');
        my $numberprocessed = $cgi->param('processed');
        my $onepourcent = $cgi->param('onepourcent');
        my $numberprocess = $cgi->param('limit') ? $cgi->param('limit'): 5;
        my $suite = $cgi->param('suite');
        my $progress = $cgi->param('progress');
        my $global = $cgi->param('global');
        my $pdf = $cgi->param('pdf');
        $suite ++;
        $onepourcent -=$numberprocess;
        if ($onepourcent <= 0){
            $progress ++;
            $onepourcent = ($global < 50) ? 1 : sprintf('%.0f',$global / 100);
        }
        my @fait  = $self->genererVignette($last,$numberprocess,$numberError,$numberprocessed);
        my $lastborrowenumber = $fait[0][-3];
        $numberError = $fait[0][-2];
        $numberprocessed = $fait[0][-1];
        my $end =($numberprocessed == $global) ? 1 : 0;
        my $template = undef;
        eval {$template = $self->get_template( { file => "step_1_" . $preferedLanguage . ".tt" } )};
        if(!$template){
            $preferedLanguage = substr $preferedLanguage, 0, 2;
            eval {$template = $self->get_template( { file => "step_1_$preferedLanguage.tt" } )};
        }
        $template = $self->get_template( { file => 'step_1.tt' } ) unless $template;
        my $other = $cgi->param('other');
        $template->param(processed => $numberprocessed);
        $template->param(progress => $progress);
        $template->param(erreur => $numberError);
        $template->param(lastborrowernumber => $lastborrowenumber);
        $template->param( suite => $suite);
        $template->param( global => $global);
        $template->param( pdf => $pdf);
        $template->param( other => $other);
        $template->param(onepourcent => $onepourcent);
        $template->param(fin => $end);
        print $cgi->header();
        print $template->output();
        #$self->go_home();
    }else{
        $self->step_1();
    }
}

sub step_1{
    my ( $self, $args) = @_;
    my $cgi = $self->{'cgi'};
    my $preferedLanguage = $cgi->cookie('KohaOpacLanguage');
    my $template = undef;
    my @notices = $self->displayAffected();
    my $pdf = $notices[0];
    my $other = $notices[1];
    my $global = $notices[2];
    my $onepourcent;
    $onepourcent = ($global < 50) ? 1 : sprintf('%.0f',$global / 100);
    eval {$template = $self->get_template( { file => "step_1_" . $preferedLanguage . ".tt" } )};
    if(!$template){
        $preferedLanguage = substr $preferedLanguage, 0, 2;
        eval {$template = $self->get_template( { file => "step_1_$preferedLanguage.tt" } )};
    }
    $template = $self->get_template( { file => 'step_1.tt'} ) unless $template;

    $template->param(fin => 0);
    $template->param(processed => 0);
    $template->param(progress => 0);
    $template->param( erreur => 0);
    $template->param( global => $global);
    $template->param( pdf => $pdf);
    $template->param( other => $other);
    $template->param( suite => 0);
    $template->param(lastborrowernumber => 0);
    $template->param(onepourcent => $onepourcent);
    print $cgi->header(-type => 'text/html',-charset => 'utf-8');
    print $template->output();
}

sub missingModule{
    my ( $self, $args) = @_;
    my $cgi = $self->{'cgi'};
    my $preferedLanguage = $cgi->cookie('KohaOpacLanguage');
    my $template = undef;

    eval {$template = $self->get_template( { file => "missingModule_" . $preferedLanguage . ".tt" } )};
    if(!$template){
        $preferedLanguage = substr $preferedLanguage, 0, 2;
        eval {$template = $self->get_template( { file => "missingModule_$preferedLanguage.tt" } )};
    }
    $template = $self->get_template( { file => 'missingModule.tt'} ) unless $template;
    print $cgi->header(-type => 'text/html',-charset => 'utf-8');
    print $template->output();
}

sub displayAffected{
    my ( $self, $args) = @_;
    my $pdf = 0;
    my $other = 0;
    my $global = 0;
    my @items;

    my $query = "SELECT a.biblionumber, b.title, b.author, EXTRACTVALUE(a.marcxml,\"record/datafield[\@tag='856']/subfield[\@code='u']\")
 as url  FROM biblioitems a, biblio b
                 WHERE a.biblionumber=b.biblionumber and EXTRACTVALUE(a.marcxml,\"record/datafield[\@tag='856']/subfield[\@code='u']\") <>''
                 and a.biblionumber not in (select biblionumber from biblioimages)";
    my $stmt = $dbh->prepare($query);
    $stmt->execute();
    while (my $row = $stmt->fetchrow_hashref()) {
        my $ispdf = 0;
        $global ++;
        my @uris = split / /,$row->{url};
        foreach my $url (@uris) {
            if(substr($url,-3) eq 'pdf'){
                $pdf ++;
                $ispdf = 1;
                last;
            }
        }
        $other ++ unless $ispdf;
}
    $items[0] = $pdf;
    $items[1] = $other;
    $items[2] = $global;
    return @items;
}
sub genererVignette{
    my ( $self, $last, $numberprocess, $numberError, $numberprocessed) = @_;
    my $dbh = C4::Context->dbh;
    my $ua = LWP::UserAgent->new(timeout => "5");
    my @fait;
    my $ispdf = 0;
    my $query = "SELECT a.biblionumber,EXTRACTVALUE(a.marcxml,\"record/datafield[\@tag='856']/subfield[\@code='u']\")
    FROM biblioitems a
    WHERE EXTRACTVALUE(a.marcxml,\"record/datafield[\@tag='856']/subfield[\@code='u']\") <> '' and a.biblionumber not in(select biblionumber from biblioimages) and (a.biblionumber > ?) order by biblionumber asc limit ?";
    # Retourne 856$u, qui est le(s) URI(s) d'une ressource numérique
    my $sthSelectPdfUri = $dbh->prepare($query);
    $sthSelectPdfUri->execute($last,$numberprocess);
    while (my ($biblionumber,$urifield) = $sthSelectPdfUri->fetchrow_array()){
        $numberprocessed ++;
        push @fait,$biblionumber;
        my @uris = split / /,$urifield;
        foreach my $url (@uris) {
            if(substr($url,-3) eq 'pdf'){
                $ispdf = 1;
                my $response = $ua->get($url);
                if(!$response->is_success){
                    $numberError ++;
                }else{
                    my $contenttype = $response->header('content-type');
                    my $lastmodified = $response->header('last-modified');
                    # On vérifie que le fichier à l'URL spécifié est bel et bien un pdf
                    if($contenttype eq "application/pdf"){
                        my @filestodelete = ();
                        my $filename = $url;
                        my $save = '';
                        $filename =~ m/.*\/(.*)$/;
                        $filename = $1;
                        $save = "/tmp/$filename";
                        if (is_success(getstore($url,$save))){
                            push @filestodelete,$save;
                            `pdftocairo $save -png $save -singlefile 2>&1`; # Conversion de pdf à png, seulement pour la première page
                            my $imageFile = $save . ".png";
                            push @filestodelete,$imageFile;

                            my $srcimage = GD::Image->new($imageFile);
                            my $replace = 1;
                            C4::Images::PutImage($biblionumber,$srcimage,$replace);
                            foreach my $file (@filestodelete){
                                unlink $file or warn "Could not unlink $file: $!\nNo more images to import.Exiting.";
                            }
                            last;
                        }
                    }
                }
            }
        }
    }
    push @fait,$numberError;
    push @fait,$numberprocessed;
    return \@fait;
}
#Supprimer le plugin avec toutes ses données
sub uninstall() {
    my ( $self, $args ) = @_;
    my $table = $self->get_qualified_table_name('mytable');

    return C4::Context->dbh->do("DROP TABLE $table");
}

1;
