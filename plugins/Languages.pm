# nous ajouterons un InLibro:: si jamais on envoie ça public
package Koha::Plugin::Languages;

use Modern::Perl;
use base qw(Koha::Plugins::Base);
use C4::Context;
use C4::Auth;
use C4::Languages;
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
    my $taskId = $cgi->param('taskid');
    my %params;
    if($taskId){ # we're looking for a status
        my ($status, $log) = status($taskId);
#        $taskId = 0 if(! $status =~ /WAITING|PROCESSING/);
        $params{'log'} = $log;
        $params{status} = $status;
    }elsif($language){
        my ($id, $status, $log) = installLanguage($language);
        $params{'log'} = $log;
        $params{status} = $status;
        $taskId = $id;
#        $params{selectedlanguage} = 'fr-CA';
    } 
#    $params{taskid} = $taskId;
#    $params{language} = $language;
        
    # obtenir la liste des langues pour les thèmes DISPONIBLES.  La librairie C4::Languages ne vérifie que ce qui est déjà installé.
    my $dir=C4::Context->config('intranetdir')."/misc/translator/po";
    opendir (MYDIR,$dir);
    my @languages = sort map {$_ =~ /^(.*)-opac-bootstrap.po/; $1; } grep { /-opac-bootstrap.po/ } readdir(MYDIR);    
    closedir MYDIR;
    my @installed = map { $_->{rfc4646_subtag} } @{C4::Languages::getTranslatedLanguages()};
    foreach my $t (@installed){
        @languages = grep { $_ ne $t} @languages;
    }
    
    $params{languages} = \@languages;
    $params{languagesinstalled} = \@installed;
    
    my $template = $self->get_template({ file => 'languages.tt' });

    $template->param( %params );
    
    print $cgi->header();
    print $template->output();
}

sub installLanguage{
    my ($language) = @_;
    
    # install the template
    my $translatedir = C4::Context->config('intranetdir')."/misc/translator";
    my $command = "cd $translatedir; ./translate install $language";
    my $tasker = Koha::Tasks->new();
    my $hrOldTasks = $tasker->getTasks(command => $command);
    # we do not want to install the language twice
    if($hrOldTasks){
        foreach my $id(keys $hrOldTasks){
            if($hrOldTasks->{$id}->{status} ne 'FAILED'){
                return ($id,$hrOldTasks->{$id}->{status},$hrOldTasks->{$id}->{log});
            }
        }
    }
    my $taskId = $tasker->addTask(name =>"PLUGIN-LANGUAGES", command=>$command);
    
    # add the language to the display choices
    foreach my $display ('language','opaclanguages'){
        my $value = C4::Context->preference($display);
        next if $value =~ /$language/;
        C4::Context->set_preference($display, "$value,$language");
    }

#je suis tanné de tenter de coder le progress bar "simplement", so fuck it pour l'instant
for (my $i = 0; $i < 10; $i++){
    sleep 3;
    my $task = $tasker->getTask($taskId);
    return ($task->{id}, $task->{status}, $task->{log}) if ($task->{status} eq 'COMPLETED' || $task->{status} eq 'FAILED'); 
}
    return $taskId;
}

sub status{
    my $taskId = shift;
    my $hrTask = Koha::Tasks->new()->getTask($taskId);
    return "Internal error, unknown task id $taskId" unless $hrTask;
    
    return ($hrTask->{status}, $hrTask->{'log'});
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
