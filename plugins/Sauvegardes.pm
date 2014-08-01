package Koha::Plugin::Sauvegardes;

use Modern::Perl;
use File::Spec;
use base qw(Koha::Plugins::Base);
use C4::Context;
use C4::Auth;
use Koha::Tasks;
use String::Util "trim";
use Data::Dumper;
use strict;
use warnings;

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
    
    my %params;
    
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
    } elsif ($request eq "Backup"){
        my ($id, $status, $log) = saveBackup($backup);
        $params{'log'} = $log;
        $params{'status'} = $status;
        $taskId = $id;
    }
    
    $params{taskid} = $taskId;
    $params{request} = $request;
    $params{backups} = listBackups();

    my $template = $self->get_template({ file => 'sauvegardes.tt' });
    $template->param( %params );

    print $cgi->header();
    print $template->output();
}

sub listBackups {
    my ( $client ) = grep { s/koha_// && s/_.*_.*// } C4::Context->config('database');
    my $backupDir = "/inlibro/backups/db";
    
    opendir(my $dh, "$backupDir/$client") or ( warn "failed to opendir $backupDir/$client\n", return );
    my @backuplist = grep { s/\.sql\.gz// && s/.*?-// } readdir ($dh);
    my $l='';
    my @a;
    foreach (@backuplist) {
        my $annee = substr $_, 0, 4;
        my $mois  = substr $_, 4, 2;
        my $jour  = substr $_, 6, 2;
        my $heure = substr $_, 9;
        if(index($heure, ":") == -1){
            my @t = ( $heure =~ m/../g );
            $heure = join (":", @t);
        }
        push @a, "$jour/$mois/$annee, $heure";
    }
    closedir($dh);
    @a = map  $_->[0],
         sort { $a->[1] cmp $b->[1] }
         map  [ $_, join('', (split '/', $_)[1,0]) ], @a; # magie noire pour trier dates
    @a = reverse @a;
    return \@a;
}

sub applyBackup {
    my $backupChoisi = parseDate(trim( shift ));
    my $backupDir = "/inlibro/backups/db";
    my $clientdb = C4::Context->config('database');
    my ( $client ) = grep { s/koha_// && s/_.*_.*// } C4::Context->config('database');
    
    opendir(my $dh, "$backupDir/$client") or ( warn "failed to opendir $backupDir/$client\n", return );
    ( $backupChoisi ) = grep { /$backupChoisi/ } readdir ($dh);
    closedir($dh);
    
    my $tasker = Koha::Tasks->new();
    my ( $u, $p ) = ( C4::Context->config('user'), C4::Context->config('pass') );
    my $taskId = $tasker->addTask(name =>"PLUGIN-MANAGEBACKUPS", command=>"gunzip -c $backupChoisi | mysql -u$u -p$p $clientdb");
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
    
    opendir(my $dh, "$backupDir/$client") or ( warn "failed to opendir $backupDir/$client\n", return );
    ( $backupChoisi ) = grep { /$backupChoisi/ } readdir ($dh);
    return if !$backupChoisi;
    closedir($dh);

    my $filename = "$backupDir/$client/$backupChoisi";
    my ( $volume,$directories,$file ) = File::Spec->splitpath ($filename);
    return if $directories != "$backupDir/$client";
    
    open(FILE, "<", "$filename") or ( warn "failed to open file $filename\n" and return );
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
    my $backupName = "$clientdb-" . trim( `date +\%Y\%m\%d-\%H\%M\%S` ) . ".sql.gz"; 
    my $taskId = $tasker->addTask(name =>"PLUGIN-MANAGEBACKUPS", command=>"mysqldump -uinlibrodumper -pinlibrodumper $clientdb | gzip -c -9 > /inlibro/backups/db/$client/$backupName");
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

sub parseDate {
    #
    # risque de changer en fonction des specs de sauvegarde
    # 
    my $d = shift; 
    my ( $date, $heure ) = split ( ", ", $d );
    my ( $annee, $mois, $jour ) = split ( "/", $date );
    if ( substr($heure, 0, 2) gt "03" ){
        $heure =~ s/://g;
    }
    return ($jour.$mois.$annee."-".$heure);
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
