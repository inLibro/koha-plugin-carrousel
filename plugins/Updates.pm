package Koha::Plugin::Updates;

use Modern::Perl;
use base qw(Koha::Plugins::Base);
use C4::Context;
use C4::Auth;
use Koha::Tasks;
use String::Util "trim";
use Data::Dumper;
use vars qw/%params/;

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
        version         => 1.01,
    };

    my $self = $class->SUPER::new($args);

    return $self;
}

sub tool {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $version = $cgi->param('version');
    my $taskId = $cgi->param('taskid');

    if ($taskId) { # we're looking for a status
        my ($status, $log) = status($taskId);
#        $taskId = 0 if(! $status =~ /WAITING|PROCESSING/);
        $params{'log'} = $log;
        $params{status} = $status;
    } elsif ($version) {
        my ($id, $status, $log) = installVersion($version);
        warn "RETOUR À UPDATES.PM APRÈS L'EXÉCUTION DE INSTALLVERSION";
        $params{'log'} = $log;
        $params{'status'} = $status;
        $taskId = $id;
        abort("ERROR: the installation process did not complete in time and could still be running.") unless $status;
    }
    $params{taskid} = $taskId;
    $params{version} = $version;
    warn "AVANT C4::CONTEXT::KOHAVERSION";
    $params{'kohaVersion'} = C4::Context::KOHAVERSION;
    $params{'versions'} = trouverVersion($params{'kohaVersion'});
    
    my $template = $self->get_template({ file => 'updates.tt' });
    $template->param( %params );
    warn "AVANT C4::CONTEXT->PREFERENCE";
    my $prefversion = C4::Context->preference('Version');
    warn "------------\n$prefversion\n$params{kohaVersion}\n$version\n------------\n";
    
    if($params{'status'} eq 'COMPLETED'){
        print $cgi->redirect("/cgi-bin/koha/mainpage.pl?logout.x=1");        
    }
    
    print $cgi->header();
    print $template->output();
}

sub installVersion {
    my $v = trim("v" . shift);
    my $intranetdir  = C4::Context->config("intranetdir");
    my $translatedir = C4::Context->config("intranetdir")."/misc/translator";
    my $command = "cd $intranetdir; ";
    $command .= "git checkout -f $v; ";
    $command .= "./installer/data/mysql/updatedatabase.pl; ";
    $command .= "cd $translatedir; ";
    my @installed = map { $_->{rfc4646_subtag} } @{C4::Languages::getTranslatedLanguages()};
    foreach(@installed){
        # we lose our installed languages with git checkout -f, so we install them back
        $command .= "./translate install $_; ";
    }
    
    my $tasker = Koha::Tasks->new();
    my $taskId = $tasker->addTask(
        name        => "PLUGIN-VERSIONUPDATE",
        command     => $command
    );
    for (my $i = 0; $i < 30; $i++){
        sleep 3;
        my $task = $tasker->getTask($taskId);
        warn "EXECUTION DE LA MISE À JOUR";
        return ($task->{id}, $task->{status}, $task->{log}) if ( $task->{status} eq 'COMPLETED' || $task->{status} eq 'FAILURE' ); 
    }
    return $taskId;
}

sub trouverVersion() {
    my $dir = C4::Context->config("intranetdir");
    chdir($dir) or ( abort("ERROR: failed to reach your installation directory.") and return );
    my ( $cutoff_major, $cutoff_functional, $cutoff_subnumber ) = split ( /\./, shift );
    my @versionlist = reverse grep { $_ =~ /^v.*\.[0-9]{2}$/ && s/v//g } qx( git tag );
    
    my @arr;
    foreach my $ele (@versionlist){
        my ( $major, $functional, $subnumber ) = split ( /\./, $ele );
        if ( $major >= $cutoff_major ){
            if ( $functional > $cutoff_functional || ( $functional == $cutoff_functional && $subnumber > $cutoff_subnumber ) ){
                push (@arr, $ele);
            }
        }
    }
    return \@arr;
}

sub status {
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

sub abort {
    $params{'log'} = shift;
    $params{'status'} = 'FAILURE';
}

1;
