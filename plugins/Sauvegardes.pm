package Koha::Plugin::Sauvegardes;

use Modern::Perl;
use File::Basename;
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
    
    my %params;
    
    if ($taskId) { # we're looking for a status
        my ($status, $log) = status($taskId);
        $params{'log'} = $log;
        $params{status} = $status;
    } elsif ($backup) {
#        die $cgi->param('submitbuttontype');
        my ($id, $status, $log) = downloadBackup($backup); #applyBackup($backup);
        $params{'log'} = $log;
        $params{'status'} = $status;
        $taskId = $id;
    }
    
    $params{taskid} = $taskId;
    $params{backups} = listBackups();

    my $template = $self->get_template({ file => 'sauvegardes.tt' });
    $template->param( %params );

    print $cgi->header();
    print $template->output();
}

sub listBackups {
    my ( $client ) = grep { s/koha_// && s/_.*_.*// } C4::Context->config('database');
    
    opendir(my $backupdir, "/inlibro/backups/db/2907") or ( warn "failed to opendir\n" and return ); #opendir(my $backupdir, "/inlibro/backups/db/$client") or ( warn "failed to opendir\n", return );
    my @backuplist = reverse grep { s/\.sql\.gz// && s/.*?-// } readdir ($backupdir);
    closedir($backupdir);
    
    return \@backuplist;
}

sub applyBackup {
    my $backupChoisi = trim( shift );
    my $clientdb = C4::Context->config('database');
    my ( $client ) = grep { s/koha_// && s/_.*_.*// } C4::Context->config('database');
    
    opendir(my $dh, "/inlibro/backups/db/2907") or ( warn "failed to opendir\n" and return ); #opendir(my $dh, "/inlibro/backups/db/$client") or ( warn "failed to opendir\n", return );
    ( $backupChoisi ) = grep { /$backupChoisi/ } readdir ($dh);
    closedir($dh);
    
    my $tasker = Koha::Tasks->new();
    my $taskId = $tasker->addTask(name =>"PLUGIN-MANAGEBACKUPS", command=>"gunzip -c $backupChoisi | mysql -u -p $clientdb");
    
    for (my $i = 0; $i < 10; $i++){
        sleep 3;
        my $task = $tasker->getTask($taskId);
        return ($task->{id}, $task->{status}, $task->{log}) if ( $task->{status} eq 'COMPLETED' || $task->{status} eq 'FAILED' ); 
    }
    return $taskId;
}

sub downloadBackup {
    my $backupChoisi = "/inlibro/backups/db/2907/machin"; #trim( shift );
    opendir(my $dh, "/inlibro/backups/db/2907") or ( warn "failed to opendir\n" and return ); #opendir(my $dh, "/inlibro/backups/db/$client") or ( warn "failed to opendir\n", return );
#    ( $backupChoisi ) = grep { /$backupChoisi/ } readdir ($dh);
    closedir($dh);
    
    #
    #
    # FAIRE TRÈS ATTENTION AU GREP CI-HAUT
    #
    
    my $filename = "/inlibro/backups/db/2907/$backupChoisi";
    my ( $file, $dirs, $suffix ) = fileparse ($filename);
    die $file."\n".$dirs."\n".$suffix;
    return if $dirs != "/inlibro/backups/db/2907";
    
    open(FILE, "<", "$filename") or ( warn "failed to open file $filename\n" and return );
    my @fileholder = <FILE>;
    close(FILE);
    
    $filename =~ s/.*\///;
    print "Content-Type:application/x-download\n";
    print "Content-Disposition:attachment;filename=$filename\n\n";
    print @fileholder;
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

1;