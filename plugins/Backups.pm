package Koha::Plugin::Backups;

use Modern::Perl;
use File::Spec;
use base qw(Koha::Plugins::Base);
use C4::Context;
use C4::Auth;
use DateTime;
use Koha::Tasks;
use String::Util "trim";
use Data::Dumper;
use strict;
use warnings;
use vars qw/%params/;

my $minimumDelayBetweenTasks = 5; # en minutes

sub new {
    my ($class, $args) = @_;
    $args->{'metadata'} = {
        name   => 'Gestionnaire de sauvegardes',
        author => 'Charles Farmer',
        description => "Permet à l'usager de créer et gérer ses sauvegardes koha",
        date_authored   => '2014-07-30',
        date_updated    => '2014-07-30',
        minimum_version => '3.0140007',
        maximum_version => undef,
        version         => 1.01,
    };
    my $self = $class->SUPER::new($args);
    return $self
}

sub tool {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $taskId = $cgi->param('taskid');
    my $backup = $cgi->param('backup');
    my $request = $cgi->param('submitbuttontype');
    my $statusupdate = $cgi->param('status');
    $params{logall} = "";
    
    if ($taskId && ($statusupdate eq 'WAITING')) { # we're looking for a status
        my ($status, $log) = status($taskId);
        $params{'log'} = $log;
        $params{status} = $status;
    } elsif ($request eq "Download" && $backup) {
        downloadBackup($backup);
    } elsif ($request eq "Install" && $backup) {
        my ($id, $status, $log) = applyBackup($backup);
        $params{'log'} = $log;
        $params{'status'} = $status;
        $taskId = $id;
        abort("ERROR: Your installation did not complete in time, and could still be running.") unless $status;
    } elsif ($request eq "Backup"){
        my ($id, $status, $log) = saveBackup();
        $params{'log'} = $log;
        $params{'status'} = $status;
        $taskId = $id;
        abort("ERROR: Your manual backup did not complete in time, and could still be running.") unless $status;
    }
    
    $params{taskid} = $taskId;
    $params{request} = $request;
    $params{backups} = listBackups();

    my $template = $self->get_template({ file => 'backups.tt' });
    $template->param( %params );

    print $cgi->header();
    print $template->output();
}

sub listBackups {
    my ( $client ) = grep { s/koha_// && s/_.*_.*// } C4::Context->config('database');
    my $backupDir = "/inlibro/backups/db";
    
    opendir(my $dh, "$backupDir/$client") or ( return );   
    my @backuplist = grep { s/\.sql\.gz// && s/.*?-// } readdir ($dh);
    closedir($dh);
    return prettify(@backuplist);
}

sub applyBackup {
    my $backupChoisi = parseDate(trim( shift ));
    my $backupDir = "/inlibro/backups/db";
    my $clientdb = C4::Context->config('database');
    my ( $client ) = grep { s/koha_// && s/_.*_.*// } C4::Context->config('database');
    my ( $u, $p ) = ( C4::Context->config('user'), C4::Context->config('pass') );
    opendir(my $dh, "$backupDir/$client") or ( return );
    ( $backupChoisi ) = grep { /$backupChoisi/ } readdir ($dh);
    closedir($dh);
    my $command = "gunzip -c $backupDir/$client/$backupChoisi | mysql -u$u -p$p $clientdb";
    
    my $tasker = Koha::Tasks->new();
    my $abbreviatedCmd = "gunzip -c $backupDir/$client/.* | mysql -u$u -p$p $clientdb";
    my $recentTasks = $tasker->getTasksRegexp(command => $abbreviatedCmd);
    my $isUserAllowed = isUserAllowedCommand($recentTasks);
    if ( !$isUserAllowed ){
        return (-1, 'FAILURE', "REASON: A backup was already recovered in the last $minimumDelayBetweenTasks minutes. Please try again later.");
    }

    my $taskId = $tasker->addTask(name =>"PLUGIN-MANAGEBACKUPS-INSTALL", command=>$command);
    for (my $i = 0; $i < 10; $i++){
        sleep 3;
        my $task = $tasker->getTask($taskId);
        return ($task->{id}, $task->{status}, $task->{log}) if ( $task->{status} eq 'COMPLETED' || $task->{status} eq 'FAILURE' ); 
    }
    return $taskId;
}

sub downloadBackup {
    my $backupChoisi = parseDate(trim( shift ));
    my $backupDir = "/inlibro/backups/db";
    my ( $client ) = grep { s/koha_// && s/_.*_.*// } C4::Context->config('database');

    opendir(my $dh, "$backupDir/$client") or ( return );
    ( $backupChoisi ) = grep { /$backupChoisi/ } readdir ($dh);
    return if !$backupChoisi;
    closedir($dh);

    my $filename = "$backupDir/$client/$backupChoisi";
    my ( $volume,$directories,$file ) = File::Spec->splitpath ($filename);
    return if $directories != "$backupDir/$client";
    open(FILE, "<", "$filename") or ( return );
    my @fileholder = <FILE>;
    close(FILE);
    $filename =~ s/.*\///;
    print "Content-Type:application/x-download\n";
    print "Content-Disposition:attachment;filename=$filename\n\n";
    print @fileholder;
}

sub saveBackup {
    my $tasker = Koha::Tasks->new();
    my $clientdb = C4::Context->config('database');
    my ( $client ) = grep { s/koha_// && s/_.*_.*// } C4::Context->config('database');    
    my $backupName = $clientdb . "-" . trim( `date +\%Y\%m\%d-\%H\%M\%S` ) . "-MANUAL.sql.gz";
    my $backupDir = "/inlibro/backups/db";
    my $command = "mysqldump -uinlibrodumper -pinlibrodumper $clientdb --single-transaction --ignore-table=$clientdb.tasks | gzip -c -9 > $backupDir/$client/$backupName";
    
    unless (-d "$backupDir/$client"){
        my $id = $tasker->addTask(name =>"PLUGIN-MANAGEBACKUPS-CREATEDIR", command=>"mkdir $backupDir/$client");
        sleep 1 while ( $tasker->getTask($id)->{status} ne 'COMPLETED' && $tasker->getTask($id)->{status} ne 'FAILURE' );
    }
    
    my $abbreviatedCmd = "mysqldump -uinlibrodumper -pinlibrodumper $clientdb --single-transaction --ignore-table=$clientdb.tasks | gzip -c -9 > $backupDir/$client/$clientdb-.*\.sql\.gz";
    my $th = $tasker->getTasksRegexp(command => $abbreviatedCmd);
    my $isUserAllowed = isUserAllowedCommand($th);
    if ( !$isUserAllowed ){
        return (-1, 'FAILURE', "REASON: A backup was already made in the last $minimumDelayBetweenTasks minutes. Please try again later.");
    }

    my $taskId = $tasker->addTask(name =>"PLUGIN-MANAGEBACKUPS-MANUAL", command=>$command);
    for(my $i=0; $i<20; $i++){
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

sub prettify {
    my @backuplist = @_;
    my @a;
    foreach (@backuplist) {
        my $annee = substr $_, 0, 4;
        my $mois  = substr $_, 4, 2;
        my $jour  = substr $_, 6, 2;
        my $reste = substr $_, 9;
        
        my $manual = ", DAILY";
        $manual = ", MANUAL" if index($reste, "MANUAL") != -1;
        my @time = ( $reste =~ m/../g )[0..2] if index($reste, ":") == -1;
        my $hsql = @time ? join ("", @time) : grep { s/:// } substr $reste, 0, 7;
        my $heure= @time ? join (":", @time) : substr $reste, 0, 7 ;
        $heure .= $manual;
        
        # afficher dans le format par défaut
        my $date = C4::Dates->new("$annee$mois$jour    $hsql","sql");#, "sql");
        if(C4::Context->preference('dateformat') =~ /rfc822|sql/){
            push @a, [$date->output()."$manual", "$annee$mois$jour$hsql"] ;
        } else {
            push @a, [$date->output().", $heure", "$annee$mois$jour$hsql"];
        }
    }
    @a = reverse map { $_->[0] } sort { $a->[1] <=> $b->[1] } @a;
    return \@a;
}

sub parseDate {
    #
    # prend la date telle qu'affichée dans le menu déroulant et
    # construit une chaine de caractères semblable à celle du nom de nos fichiers de sauvegarde
    #
    # risque de changer en fonction des specs de sauvegarde
    #
    # ACHTUNG : Certains fichiers ont déjà eu la forme YYYY-MM-DD-03:00:0X
    # sauf dans nos nouvelles installations
    #
    my $d = shift;
    my ( $date, $heure, $manual ) = split ( ", ", $d );
    my $dh = C4::Dates->new($date, C4::Context->preference('dateformat'));
    my ( $annee, $mois, $jour ) = split ( "/", $dh->output("metric") );
    $heure =~ s/://g;
    my $s = $jour.$mois.$annee."-".$heure;
    $s .= "-MANUAL" if index($manual, "MANUAL") != -1;
    
    return $s;
}

sub isUserAllowedCommand {
    my $recentTasks = shift;
    if($recentTasks){
        foreach my $id (keys $recentTasks){
            next unless $recentTasks->{$id}->{time_last_start};
            my ($date, $time) = split(" ", $recentTasks->{$id}->{time_last_start});
            my ($hour, $minute, $second) = split(":", $time);
            my ($annee, $mois, $jour) = split("-", $date);
            my $last_time = DateTime->new(
                                year   => $annee,
                                month  => $mois,
                                day    => $jour,
                                hour   => $hour,
                                minute => $minute,
                                second => $second,
                            );
            my $now = DateTime->now();
            my $timegap = $last_time->delta_ms($now)->minutes;
            if($recentTasks->{$id}->{status} ne 'FAILURE' && $timegap < $minimumDelayBetweenTasks){
                return 0;
            }
        }
    }
    return 1;
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
