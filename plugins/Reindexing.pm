package Koha::Plugin::Reindexing;

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
        name   => 'Gestionnaire de réindexation Zebra',
        author => 'Charles Farmer',
        description => "Permet à l'usager de réindexer Zebra depuis son intranet",
        date_authored   => '2014-08-11',
        date_updated    => '2014-08-11',
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
    my $taskId = $cgi->param('taskid');
    my $reindexnow = $cgi->param('reindexnow');
    my %list = (
        'biblio'     => $cgi->param('biblio')    || undef,
        'authority'  => $cgi->param('authority') || undef,
        'full'       => $cgi->param('group') eq "full"      ? 'on' : undef,
        'zebratbl'   => $cgi->param('group') eq "zebratbl"  ? 'on' : undef,
        'reset'      => $cgi->param('reset')     || undef,
        'email'      => $cgi->param('email')     || undef,
    );
    
#    die Dumper(%list) . $list{'biblio'} ."\n". $list{'authority'} ."\n". $list{'reset'} ."\n". $list{'email'} ."\n". $list{'zebratbl'} ."\n". $list{'full'} ."\n". $taskId;
    
    if ($taskId) { # we're looking for a status
        my ($status, $log) = status($taskId);
#        $taskId = 0 if(! $status =~ /WAITING|PROCESSING/);
        $params{'log'} = $log;
        $params{status} = $status;
    } elsif ($reindexnow) {
        my ($id, $status, $log) = reindex_zebra( %list );
        $params{'log'} = $log;
        $params{'status'} = $status;
        $taskId = $id;
        abort("ERROR: the reindexing process did not complete in time.") unless $status;
    }
    $params{taskid} = $taskId;
    $params{reindexnow} = '';
    
    my $template = $self->get_template({ file => 'reindexing.tt' });
    $template->param( %params );

    print $cgi->header();
    print $template->output();
}

sub reindex_zebra{
    my %args = @_;    
    my $intranetdir = C4::Context->config("intranetdir");
    my $command = "cd $intranetdir; ./misc/migration_tools/rebuild_zebra.pl;";
    
    my $tasker = Koha::Tasks->new();
    my $taskId = $tasker->addTask(name =>"PLUGIN-REBUILDZEBRA", command=>"$command");

    for (my $i = 0; $i < 10; $i++){
        sleep 3;
        my $task = $tasker->getTask($taskId);
        return ($task->{id}, $task->{status}, $task->{log}) if ( $task->{status} eq 'COMPLETED' || $task->{status} eq 'FAILURE' ); 
    }
    return $taskId;
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