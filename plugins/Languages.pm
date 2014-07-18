# nous ajouterons un InLibro:: si jamais on envoie ça public
package Koha::Plugin::Languages;

use Modern::Perl;
use base qw(Koha::Plugins::Base);
use C4::Context;
use C4::Auth;
use Koha::Tasks;

sub new {
    my ( $class, $args ) = @_;

    $args->{'metadata'} = {
        name   => 'Installateur de langues.',
        author => 'Philippe Blouin',
        description => "Permet l'ajout de choix de langues aux usagers de l'interface.  Remplace la commande './translage install'",
        date_authored   => '2014-07-17',
        date_updated    => '2014-07-17',
        minimum_version => '3.0140007',
        maximum_version => undef,
        version         => 1.01,
    };

    my $self = $class->SUPER::new($args);

    return $self;
}

sub tool {
    my ( $self, $args ) = @_;

    my $cgi = $self->{'cgi'};

    my $language = $cgi->param('language');
    
    if($language){
        installLanguage($language);
    }
    
    my $template = $self->get_template({ file => 'languages.tt' });

    # obtenir la liste des langues pour les thèmes DISPONIBLES.  La librairie C4::Languages ne vérifie que ce qui est déjà installé.
    my $dir=C4::Context->config('intranetdir')."/misc/translator/po";
    opendir (MYDIR,$dir);
    my @languages = sort map {$_ =~ /^(.*)-opac-bootstrap.po/; $1; } grep { /-opac-bootstrap.po/ } readdir(MYDIR);    
    closedir MYDIR;
    
    $template->param( languages => \@languages );
    
    print $cgi->header();
    print $template->output();
}

sub installLanguage{
    my ($language) = @_;
    
    my $translatedir = C4::Context->config('intranetdir')."/misc/translator";
    my $rc = Koha::Tasks->new()->addTask(name =>"LANGUAGES", command=>"$translatedir/translate install $language");
    
    my $dbh = C4::Context->dbh;
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
