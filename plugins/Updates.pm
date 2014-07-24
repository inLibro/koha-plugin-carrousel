package Koha::Plugin::Updates;

use Modern::Perl;
use base qw(Koha::Plugins::Base);
use C4::Context;
use C4::Auth;
use strict;
use warnings;

sub new {
    my ( $class, $args ) = @_;

    $args->{'metadata'} = {
        name   => 'Gestionnaire de mises à jour',
        author => 'Charles Farmer',
        description => "Permet à l'usager de mettre à jour convivialement son installation Koha",
        date_authored   => '2014-07-23',
        date_updated    => '2014-07-23',
        minimum_version => '3.0140007',
        maximum_version => undef,
        version         => 1.00,
    };

    my $self = $class->SUPER::new($args);

    return $self;
}

sub tool {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my %params;

    $params{'kohaVersion'} = C4::Context::KOHAVERSION;
    $params{'versions'} = trouverVersion($params{'kohaVersion'});
    
    my $template = $self->get_template({ file => 'updates.tt' });
    $template->param( %params );

    print $cgi->header();
    print $template->output();
}

sub trouverVersion() {
    my @versionlist = qx( git tag );
    print "@versionlist\n";
}

sub install() {
    my ( $self, $args ) = @_;
    return 1; # succès (0 pour erreur?)
}

sub uninstall() {
    my ( $self, $args ) = @_;
    return 1; # succès
}

1;
