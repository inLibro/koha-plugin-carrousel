package Koha::Plugin::ScheduledScripts;

use Modern::Perl;
use base qw(Koha::Plugins::Base);
use C4::Context;
use C4::Auth;
use Koha::Tasks;
use DateTime;
use DateTime::Duration;
use DateTime::Format::MySQL;
use JSON;
use List::Util qw(min);
use Data::Dumper;

my %SCRIPTS = (
    'SCRIPT-FOOBAR' => {
        name => 'foobar',
        desc => "Foobars the baz.",
        cmd => 'echo foobar',
    },
    'PLUGIN-REBUILDZEBRA' => {
        name => 'Rebuild Index',
        desc => 'Fake. For testing purposes.',
        cmd => 'echo nope',
    },
);

sub new {
    my ( $class, $args ) = @_;

    $args->{'metadata'} = {
        name   => 'Gestionnaire de scripts',
        author => 'Pierre-Paul Paquin',
        description => "Pour lancer et/ou mettre à l'horaire des scripts",
        date_authored   => '2014-11-24',
        date_updated    => '2014-11-24',
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
    $cgi->charset('UTF-8');
    binmode(STDOUT, ':utf8');
    my %params;

    if(uc($cgi->request_method) eq 'POST') {
        my $script = $cgi->param('script');

        if(!exists $SCRIPTS{$script}) {
            print $cgi->header(-status => 400);
            print "Bad script name \"$script\"\n";
            return;
        }

        my $tasker = Koha::Tasks->new();

        if($cgi->param('unschedule')) {
            my $waiting = $tasker->getTasks(name => $script, status => 'WAITING');
            for my $task_id (keys %$waiting) {
                $tasker->deleteTask($task_id);
            }
        } else {
            my %task = ( name => $script );
            if($cgi->param('launch_time')) {
                if($cgi->param('launch_time') eq '0000-00-00 00:00') {
                    $task{time_next} = $cgi->param('launch_time');
                } else {
                    if($cgi->param('launch_tz')) {
                        if($cgi->param('launch_time') =~ /^(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d)$/) {
                            my $launch_time = eval {
                                DateTime->new(year => $1, month => $2, day => $3, hour => $4, minute => $5, time_zone => $cgi->param('launch_tz'));
                            };
                            if($@) {
                                print $cgi->header(-status => 400);
                                print "Bad launch time: $@\n";
                                return;
                            }
                            $launch_time->set_time_zone('local');
                            $task{time_next} = DateTime::Format::MySQL->format_datetime($launch_time);
                        } else {
                            print $cgi->header(-status => 400);
                            print "Malformed parameter \"launch_time\"; expected YYYY-MM-DD hh:mm.\n";
                            return;
                        }
                    } else {
                        print $cgi->header(-status => 400);
                        print "Missing time zone for launch time (parameter \"launch_tz\").\n";
                        return;
                    }
                }
            }

            if($cgi->param('recur')) {
                if(my $recur = $self->parse_recurrence($cgi->param('recur'))) {
                    $task{time_repeat} = sprintf('%d %02d:%02d:%02d', $recur->days(), $recur->hours(), $recur->minutes, $recur->seconds);
                } else {
                    print $cgi->header(-status => 400);
                    print 'Malformed value for "recur": "' . $cgi->param('recur') . "\"; expected /^\d+[smhdj]$/.\n";
                    return;
                }
            }

            # If we already have a task scheduled, we'll update it. Otherwise, we'll create a new one.
            my $waiting = $tasker->getTasks(name => $script, status => 'WAITING');
            my $n_waiting = keys %$waiting;
            if($n_waiting > 1) {
                print $cgi->header(-status => 500);
                print "There is more than one ($n_waiting) tasks named \"$script\" waiting to be run.\nThere should only be one.\nWe done goofed somewhere.\nRefusing to proceed.\n";
                return;
            }
            if($n_waiting == 1) {
                # Le système gère naturellement bien les mises-à-jour à la période de récurrence:
                #   - ça n'a d'effet que si la tâche est présentement au statut WAITING
                #   - ça n'affecte pas le temps de la prochaine exécution;
                #     la nouvelle période de récurrence entre en vigueur après la prochaine exécution.
                $task{id} = scalar(each $waiting);
                if(!$tasker->update(%task)) {
                    print $cgi->header(-status => 500);
                    print "Error trying to update task " . Dumper(\%task) . "; " . C4::Context->dbh()->errstr;
                    return;
                }
            } else {
                $task{command} = $SCRIPTS{$script}->{cmd};
                $tasker->addTask(%task)
            }
        }

        print $cgi->header(-status => 303, -Location => '/cgi-bin/koha/plugins/run.pl?class=Koha%3A%3APlugin%3A%3AScheduledScripts&method=tool');
        return;
    }

    $self->load_run_times;

    # User wants JSON (the Javascript wants this)
    if($cgi->Accept('application/json') > $cgi->Accept('text/*')) {
        print $cgi->header( -Content_type => 'application/json' );
        print encode_json(\%SCRIPTS);
        return;
    }

    $params{scripts} = \%SCRIPTS;

    my $now = DateTime->now( time_zone => 'local', formatter => DateTime::Format::MySQL->new() );
    $params{now} = "$now";
    $params{time_zone} = $now->strftime('%z');

    if(grep { $_->{next_run} } values %SCRIPTS) {
        $params{refresh} = 5000;
    }
    
    my $template = $self->get_template({ file => 'scheduled_scripts.tt' });
    $template->param( %params );

    print $cgi->header();
    print $template->output();
}

sub load_run_times {
    my ($self) = @_;
    my $tasker = Koha::Tasks->new();
    my $last_run = $tasker->getLastTaskTimes(keys %SCRIPTS);
    while(my($id, $row) = each %$last_run) {
        $SCRIPTS{$id}->{last_run} = $row->{last_run};
    }
    my $next_run = $tasker->getNextTasksByName(keys %SCRIPTS);
    while(my($id, $row) = each %$next_run) {
        $SCRIPTS{$id}->{next_run} = $row->{time_next} eq '0000-00-00 00:00:00' ? 'Any time now...' : $row->{time_next};
        $SCRIPTS{$id}->{recur} = $self->abbr_time($row->{time_repeat});
    }
}

my %TIME_ABBR = (
    s => 'seconds',
    m => 'minutes',
    h => 'hours',
    d => 'days',
    j => 'days',
);
sub parse_recurrence {
    my($self, $duration) = @_;
    $duration =~ /^(\d+)([smhdj])$/ or return undef;
    my($length, $unit) = ($1, $TIME_ABBR{$2});
    return DateTime::Duration->new( $unit => $length );
}

sub abbr_time {
    my($self, $time) = @_;
    my $d = 0;
    $time =~ /(\d\d):(\d\d):(\d\d)$/ or return '';
    my($h, $m, $s) = ($1, $2, $3);
    $time =~ /^(\d+) / and $d = $1;
    $s != 0 and return ($s + 60 * $m + 3600 * $h + 86400 * $d) . 's';
    $m != 0 and return ($m + $h * 60 + $d * 1440) . 'm';
    $h != 0 and return ($h + $d * 24) . 'h';
    $d != 0 and return $d . 'd';
    return '';
}

sub status {
    return ('FAILED', '???');
}

sub install {
    my ( $self, $args ) = @_;
    return 1; # succès (0 pour erreur?)
}

sub uninstall {
    my ( $self, $args ) = @_;
    return 1; # succès
}

1;
