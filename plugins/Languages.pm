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
    my $refresh = $cgi->param('status');
    if($language && !$refresh){
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
    
    # install the template
    my $translatedir = C4::Context->config('intranetdir')."/misc/translator";
    my $tasker = Koha::Tasks->new();
    my $rc = $tasker->addTask(name =>"PLUGIN-LANGUAGES", command=>"cd $translatedir; ./translate install $language");
    
    # add the language to the display choices
    foreach my $display ('language','opaclanguages'){
        my $value = C4::Context->preference($display);
        next if $value =~ /$language/;
        C4::Context->set_preference($display, "$value,$language");
    }
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
