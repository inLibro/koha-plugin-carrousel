# Rémi Mayrand-Provencher, 2016 - Inlibro
#
# Allows to dump the database and then download the said dump
# You need to add the <publicdumpdir>/path/to/dump/directory</publicdumpdir> directive to your koha-conf.xml
# The dump directory also needs to belong to www-data:www-data for the plugin to be able to write the dump inside it.
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
package Koha::Plugin::DatabaseDumper;

use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## Koha libraries we need to access
use C4::Context;
use C4::Auth;

use CGI;
use C4::Output;
use C4::Koha;
use File::stat qw(stat);
use Digest::MD5 qw(md5_hex);


## Here we set our plugin version
our $VERSION = 1.02;

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'Database Dumper',
    author          => 'Rémi MP',
    description     => 'Allows database dumping directly from the intranet. Then gives a link to download the said dump',
    date_authored   => '2016-04-22',
    date_updated    => '2016-07-11',
    minimum_version => '3.1400000',
    maximum_version => undef,
    version         => $VERSION,
};

## This is the minimum code required for a plugin's 'new' method
## More can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

sub tool {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $action = $cgi->param('action');

    if($action eq 'dump'){
        # Dans le cas d'une dompe, on propose à l'utilisateur de téléchargé le fichier mais on ne réimprime pas le template
        $self->dumpDatabase();
    }else{
        # Impression simple du template
        $self->databaseDumper();
    }
}

# Page du plugin, print le template et c'est tout
sub databaseDumper {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    # Chercher la langue de l'utilisateur
    my $lang = $cgi->cookie('KohaOpacLanguage');

    my $templateName = 'DatabaseDumper.tt';
    if($lang && $lang ne ''){
	$templateName = 'DatabaseDumper_' . $lang . '.tt';

    }
    warn "template = $templateName";
    #eval {$template = $self->get_template( { file => "DatabaseDumper" . $preferedLanguage . ".tt" } )};
    #if(!$template){
    #    $preferedLanguage = substr $preferedLanguage, 0, 2;
    #    eval {$template = $self->get_template( { file => "step_1_$preferedLanguage.tt" } )};
    #}
    #$template = $self->get_template( { file => 'step_1.tt' } ) unless $template;

    my $template = $self->get_template( { file => $templateName } );
    print $cgi->header();
    print $template->output();
}

sub dumpDatabase {
	my ( $self, $args ) = @_;
    my $input = $self->{'cgi'};
	my $publicdumpdir = C4::Context->config('pluginsdir') . "/Koha/Plugin/DatabaseDumper";
    my $db_user = C4::Context->config('user');
    my $db_pass = C4::Context->config('pass');
    my $db_name = C4::Context->config('database');
	my $dumpName = $input->param("dumpName");
	if(!$dumpName){
		$dumpName="dump";
	}
	$dumpName .= '.sql.gz';
    # On lance la dompe
    `mysqldump -u $db_user -p$db_pass $db_name | gzip > $publicdumpdir/$dumpName`;

    my $filepath = "$publicdumpdir/$dumpName";

    print ("Content-Type:application/x-download\n");
    print "Content-Disposition: attachment; filename=$dumpName\n\n";

    # On imprime le contenu de la page
    open FILE, "< $filepath" or die "can't open : $!";
    binmode FILE;
    local $/ = \10240;
    while (<FILE>){
        print $_;
    }
    close FILE;

    # On supprime le fichier
    unlink ($filepath);
}

1;
