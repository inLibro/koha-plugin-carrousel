package Koha::Plugin::Reindexing;

use Modern::Perl;
use base qw(Koha::Plugins::Base);
use C4::Context;
use C4::Auth;
use Koha::Tasks;
use String::Util "trim";
use Time::Piece;
use Time::Seconds;
use DateTime;
use Data::Dumper;
use vars qw/%params/;

sub new {
    my ( $class, $args ) = @_;

    $args->{'metadata'} = {
        name   => 'Gestionnaire de réindexation Zebra',
        author => 'Charles Farmer',
        description => "Permet à l'usager de réindexer Zebra depuis son intranet",
        date_authored   => '2014-08-11',
        date_updated    => '2014-11-24',
        minimum_version => '3.0140007',
        maximum_version => undef,
        version         => 1.02,
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
        'emailaddr'     => $cgi->param('emailaddr')    || undef,
        'startlater' => $cgi->param('startlater')|| undef,
        'hour'       => (defined $cgi->param('hour') && $cgi->param('hour')) == 0 ? 0 : $cgi->param('hour') || undef,
        'minute'     => (defined $cgi->param('minute') && $cgi->param('minute')) == 0 ? 0 : $cgi->param('minute') || undef,
        'tz'         => $cgi->param('tz') || undef,
    );
    #die "$list{hour}\n$list{minute}";
    #
    # Switch vers les opérations
    #
    if ($canceltask){
        my $nbrow = cancelTask();
        $params{status} = $nbrow > 0  ? 'DELETED' : 'ERROR';
    } elsif ($updatenow){
        my ($nbrow, $id, $status, $log) = updateTask( %list );
        $params{status} = $nbrow > 0  ? 'UPDATED' : '';
        $params{'log'} = $log if $log;
        $params{'reindexstatus'} = $status if $status;
        abort("ERROR: the reindexing process did not complete in time and could still be running.") if ($id && !$status);
    } elsif ($reindexnow) {
        my ($id, $status, $log) = reindex_zebra( %list );
        $params{'log'} = $log;
        $params{'reindexstatus'} = $status;
        abort("ERROR: the reindexing process did not complete in time and could still be running.") unless $status;
    }
    
    $params{reindexnow} = '';
    $params{updatenow}  = '';
    $params{canceltask} = '';
    $params{emailaddr} = $list{'emailaddr'} || C4::Context->preference('KohaAdminEmailAddress');
    
    my $th = getWaiting();# unless ($params{status} =~ /(FAILURE|COMPLETED|DELETED)/ );
    ( $params{nexttaskstatus}, $params{timenext} ) = ($th->{(keys $th)[0]}->{status}, $th->{(keys $th)[0]}->{time_next}) if ($th);
    $params{time_zone} = DateTime::TimeZone->new( name => 'local')->name;
        
    my $template = $self->get_template({ file => 'reindexing.tt' });
    $template->param( %params );
    print $cgi->header();
    print $template->output();
}

sub reindex_zebra {
    my %list = @_;
    my ($command, $timestring) = buildQuery( %list );
    my $tasker = Koha::Tasks->new();
    my $taskId = $tasker->addTask(
        name        => "PLUGIN-REBUILDZEBRA",
        command     => $command,
        time_next   => $timestring,
        email       => $list{email} ? $list{emailaddr} : ''
    );
    for (my $i = 0; $i < 20; $i++){
        sleep 3;
        my $task = $tasker->getTask($taskId);
        return ($task->{id}, $task->{status}, $task->{log}) if ( $task->{status} eq 'COMPLETED' || $task->{status} eq 'FAILURE' || ($task->{status} eq 'WAITING' && $timestring) ); 
    }
    return $taskId;
}

sub cancelTask {
    my $tasker = Koha::Tasks->new();
    my $intranetdir = C4::Context->config("intranetdir");
    my $command = "cd $intranetdir; ./misc/migration_tools/rebuild_zebra.pl";
    my $th = $tasker->getTasksRegexp(command=>$command, status=>'WAITING');
    return $tasker->deleteTask((keys $th)[0]);
}

sub updateTask {
    my %list = @_;
    my $th = getWaiting();

    return (-1, reindex_zebra(%list)) unless $th;
    
    my ($command, $timestring) = buildQuery( %list );
    my $taskId = (keys $th)[0];
    my %args = (
        id          => $taskId,
        command     => $command,
        time_next   => $timestring,
        email       => $list{email} ? $list{emailaddr} : ''
    ); 
    my $tasker = Koha::Tasks->new();
    my $nbrow = $tasker->update( %args );
    
    for (my $i = 0; $i < 20; $i++){
        sleep 3;
        my $task = $tasker->getTask($taskId);
        return ($nbrow, $task->{id}, $task->{status}, $task->{log}) if ( $task->{status} eq 'COMPLETED' || $task->{status} eq 'FAILURE' || ($task->{status} eq 'WAITING' && $timestring) ); 
    }
    return ($nbrow, $taskId);
    
}

sub getWaiting {
    my $tasker = Koha::Tasks->new();
    my $intranetdir = C4::Context->config("intranetdir");
    my $command = "cd $intranetdir; ./misc/migration_tools/rebuild_zebra.pl";
    my $th = $tasker->getTasksRegexp(command=>$command, status=>'WAITING');
#    if($th){
#        my ($id) = keys $th;
#        my $time = Time::Piece->strptime($th->{$id}->{time_next}, "%Y-%m-%d %H:%M:%S" );
#        return ($th->{$id}->{status}, $time->strftime("%c"));
#    }
#    return (undef, undef);
    return (%{$th} ? $th : undef);
}

sub buildQuery {
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
    if($list{'startlater'} && defined ($list{hour}) && defined ($list{minute}) && defined($list{tz})){
        # MySQL doesn't store time zone information in DATETIME fields
        # (this timestring is for the 'time_next' column, which is of type DATETIME).
        # Datetimes are to be interpreted in the system timezone (i.e. the same value is returned
        # by MySQL whether you set its timezone to UTC or, say, EST). This is fine: the system
        # timezone has no reason to change over time. However, this timezone may be different
        # from the client's timezone. So: we force the client to supply a timezone, and we
        # convert the time to our local system's timezone before storing it in the database.
        # This way, all values stored in our database are in the same timezone.
        my $dt = DateTime->now( time_zone => $list{tz} );
        if($list{hour} < $dt->hour || ($list{hour} == $dt->hour && $list{minute} < $dt->minute)) {
            $dt->add( days => 1 );
        }
        $dt->set_hour($list{hour});
        $dt->set_minute($list{minute});
        $dt->set_time_zone(DateTime::TimeZone->new( name => 'local' ));
        $timestring = $dt->strftime("%Y-%m-%d %H-%M-%S");
    }
    return ($command, $timestring);
}

sub status {
    my $taskId = shift;
    my $hrTask = Koha::Tasks->new()->getTask($taskId);
    return "Internal error, unknown task id $taskId" unless $hrTask;
    
    return ($hrTask->{status}, $hrTask->{'log'});
}

sub install {
    my ( $self, $args ) = @_;
    return 1; # succès (0 pour erreur?)
}

sub uninstall {
    my ( $self, $args ) = @_;
    return 1; # succès
}

sub abort {
    $params{'log'} = shift;
    $params{'reindexstatus'} = 'FAILURE';
}

1;
