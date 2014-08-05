package Koha::Plugin::Updates;

use Modern::Perl;
use base qw(Koha::Plugins::Base);
use C4::Context;
use C4::Auth;
use Koha::Tasks;
use String::Util "trim";
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
        $params{'log'} = $log;
        $params{'status'} = $status;
        $taskId = $id;
        abort("ERROR: the installation process did not complete in time.") unless $status;
    }
    $params{taskid} = $taskId;
    $params{version} = $version;
    $params{'kohaVersion'} = C4::Context::KOHAVERSION;
    $params{'versions'} = trouverVersion($params{'kohaVersion'});
    
    my $template = $self->get_template({ file => 'updates.tt' });
    $template->param( %params );

    print $cgi->header();
    print $template->output();
}

sub installVersion {
    my $v = trim("v" . shift);
    
    my $intranetdir = C4::Context->config("intranetdir"); 
    my $tasker = Koha::Tasks->new();
    my $taskId = $tasker->addTask(name =>"PLUGIN-VERSIONUPDATE", command=>"cd $intranetdir; git checkout $v; ./installer/data/mysql/updatedatabase.pl;");

    for (my $i = 0; $i < 10; $i++){
        sleep 3;
        my $task = $tasker->getTask($taskId);
        return ($task->{id}, $task->{status}, $task->{log}) if ( $task->{status} eq 'COMPLETED' || $task->{status} eq 'FAILED' ); 
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
    $params{'status'} = 'FAILED';
}

1;
