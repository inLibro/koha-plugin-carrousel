package Koha::Plugin::Reindexing;

use Modern::Perl;
use base qw(Koha::Plugins::Base);
use C4::Context;
use C4::Auth;
use Koha::Tasks;
use String::Util "trim";
use Time::Piece;
use Time::Seconds;
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
    
    my $canceltask = $cgi->param('canceltask');
    my $reindexnow = $cgi->param('reindexnow');
    my $updatenow  = $cgi->param('updatenow');
    
    my %list = (
        'biblio'     => $cgi->param('biblio')    || undef,
        'authority'  => $cgi->param('authority') || undef,
        'full'       => $cgi->param('group') eq "full"      ? 'on' : undef,
        'zebratbl'   => $cgi->param('group') eq "zebratbl"  ? 'on' : undef,
        'reset'      => $cgi->param('reset')     || undef,
        'email'      => $cgi->param('email')     || undef,
        'email2'     => $cgi->param('email2')    || undef,
        'startlater' => $cgi->param('startlater')|| undef,
        'hour'       => $cgi->param('hour')      || undef,
        'minute'     => $cgi->param('minute')    || undef,
    );
    
    if ($canceltask){
        my $nbrow = cancelTask();
        $params{status} = 'DELETED' if ( $nbrow > 0 );
    } elsif ($updatenow){
        
    } elsif ($reindexnow) {
        my ($id, $status, $log) = reindex_zebra( %list );
        $params{'log'} = $log;
        $params{'status'} = $status;
        abort("ERROR: the reindexing process did not complete in time and could still be running.") unless $status;
    }
    
    $params{updatenow}  = '';
    $params{canceltask} = '';
    $params{reindexnow} = '';
    $params{email2} = $list{'email2'} || C4::Context->preference('KohaAdminEmailAddress');
    ($params{status}, $params{timenext}) = getWaiting() if ($params{status} ne 'FAILURE' && $params{status} ne 'COMPLETED' && $params{status} ne 'DELETED');
    
    my $template = $self->get_template({ file => 'reindexing.tt' });
    $template->param( %params );
    print $cgi->header();
    print $template->output();
}

sub reindex_zebra{
    my %list = @_;
    my $intranetdir = C4::Context->config("intranetdir");
    my $command = "cd $intranetdir; ./misc/migration_tools/rebuild_zebra.pl";
    $command .= " -b" if($list{'biblio'});
    $command .= " -a" if($list{'authority'});
    $command .= " -z" if($list{'zebratbl'});
    $command .= " -r" if($list{'reset'});
    $command .= " -v" if($list{'email'});
    $command .= ";";
    
    my $timestring;
    if($list{'startlater'} && $list{hour} && $list{minute}){
        my $t = localtime;
        my $u = Time::Piece->strptime(localtime->ymd." $list{hour}:$list{minute}:00", "%Y-%m-%d %H:%M:%S" );
        $u += ONE_DAY if ($list{hour} < $t->hour || ($list{hour} == $t->hour && $list{minute} < $t->min));
        
        $timestring = $u->strftime("%Y-%m-%d %H:%M:%S");
    }
    my $tasker = Koha::Tasks->new();
    my $taskId = $tasker->addTask(name =>"PLUGIN-REBUILDZEBRA", command=>"$command", time_next=>($timestring||"0"));
    for (my $i = 0; $i < 20; $i++){
        sleep 3;
        my $task = $tasker->getTask($taskId);
        return ($task->{id}, $task->{status}, $task->{log}) if ( $task->{status} eq 'COMPLETED' || $task->{status} eq 'FAILURE' || ($task->{status} eq 'WAITING' && $timestring) ); 
    }
    return $taskId;
}

sub getWaiting {
    my $tasker = Koha::Tasks->new();
    my $intranetdir = C4::Context->config("intranetdir");
    my $command = "cd $intranetdir; ./misc/migration_tools/rebuild_zebra.pl";
    my $th = $tasker->getTasksRegexp(command=>$command, status=>'WAITING');
    if($th){
        my ($id) = keys $th;
        my $time = Time::Piece->strptime($th->{$id}->{time_next}, "%Y-%m-%d %H:%M:%S" );
        return ($th->{$id}->{status}, $time->strftime("%c"));
    }
    return (undef, undef);
}

sub cancelTask() {
    my $tasker = Koha::Tasks->new();
    my $intranetdir = C4::Context->config("intranetdir");
    my $command = "cd $intranetdir; ./misc/migration_tools/rebuild_zebra.pl";
    my $th = $tasker->getTasksRegexp(command=>$command, status=>'WAITING');
    return $tasker->deleteTask((keys $th)[0]);
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