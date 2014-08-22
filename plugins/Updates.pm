package Koha::Plugin::Updates;

use Modern::Perl;
use base qw(Koha::Plugins::Base);
use C4::Context;
use C4::Auth;
use Koha::Tasks;
use String::Util "trim";
use Data::Dumper;
use Switch;
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
    my $returnStatus = $cgi->param('success');
    
    if ($taskId) { # we're looking for a status
        my ($status, $log) = status($taskId);
        $params{'log'} = $log;
        $params{status} = $status;
    } elsif ($version) {
        my $return = launchUpdateSequence($version);
        switch($return){
            case -1 { abort("ERROR: Failed on backup.") }
            case -2 { abort("ERROR: Failed on update.") }
            case -3 { abort("ERROR: Failed on installing languages.") }
        }
        $params{'return'} = $return;
    }
    
    if ( defined $params{'return'} && $params{'return'} > 0 ){
        print $cgi->redirect("/cgi-bin/koha/plugins/run.pl?class=Koha::Plugin::Updates&method=tool&success=1");
    }
    $params{taskid} = $taskId;
    $params{version} = $version;
    $params{success} = $returnStatus;
    my @installed = map { $_->{rfc4646_subtag} } @{C4::Languages::getTranslatedLanguages()};    
    $params{languages} = \@installed if $returnStatus;
    $params{versions} = trouverVersion();
    my $template = $self->get_template({ file => 'updates.tt' });
    $template->param( %params );    
    print $cgi->header();
    print $template->output();
}

sub launchUpdateSequence {
    my $version = shift;
    my ($id, $status, $log);
    #lance le backup
    ($id, $status, $log) = preemptiveBackup();
    return -1 unless ($status && $status eq 'COMPLETED');
    #lance le checkout, l'update
    ($id, $status, $log) = installVersion($version);
    return -2 unless ($status && $status eq 'COMPLETED');
    #lance l'installation des langues
    ($id, $status, $log) = installLang();
    return -3 unless ($status && $status eq 'COMPLETED');
    
    return 1;
}

sub launchTask {
    my $name = shift;
    my $command = shift;
    my $tasker = Koha::Tasks->new();
    my $taskId = $tasker->addTask(
        name        => $name,
        command     => $command
    );
    for (my $i = 0; $i < 30; $i++){
        sleep 3;
        my $task = $tasker->getTask($taskId);
        return ($task->{id}, $task->{status}, $task->{log}) if ( $task->{status} eq 'COMPLETED' || $task->{status} eq 'FAILURE' ); 
    }
    return $taskId;
}

sub installVersion {
    my $v = trim("v" . shift);
    my $intranetdir = C4::Context->config("intranetdir");
    my $command = "cd $intranetdir; ";
    $command .= "git checkout -f $v; ";
    $command .= "./installer/data/mysql/updatedatabase.pl; ";
    
    return launchTask("PLUGIN-UPDATE-UPDATE", $command);
}

sub preemptiveBackup {
    my $tasker = Koha::Tasks->new();
    my $clientdb = C4::Context->config('database');
    my ( $client ) = grep { s/koha_// && s/_.*_.*// } C4::Context->config('database');    
    my $backupName = $clientdb . "-" . trim( `date +\%Y\%m\%d-\%H\%M\%S` ) . "-MANUAL.sql.gz";
    my $backupDir = "/inlibro/backups/db";
    my $command = "mysqldump -uinlibrodumper -pinlibrodumper $clientdb --single-transaction --ignore-table=$clientdb.tasks | gzip -c -9 > $backupDir/$client/$backupName";
    
    unless (-d "$backupDir/$client"){
        my $id = $tasker->addTask(name =>"PLUGIN-VERSIONUPDATE-CREATEDIR", command=>"mkdir $backupDir/$client");
        sleep 1 while ( $tasker->getTask($id)->{status} ne 'COMPLETED' && $tasker->getTask($id)->{status} ne 'FAILURE' );
    }
    
    return launchTask("PLUGIN-UPDATE-BACKUP", $command);
}

sub installLang {
    my $translatedir = C4::Context->config("intranetdir")."/misc/translator";
    my $command = "cd $translatedir; ";
    my @installed = map { $_->{rfc4646_subtag} } @{C4::Languages::getTranslatedLanguages()};
    foreach(@installed){
        # we lose our installed languages with git checkout -f, so we install them back
        $command .= "./translate install $_; ";
    }
    
    return launchTask("PLUGIN-UPDATE-LANG", $command);
}

sub trouverVersion() {
    my $dir = C4::Context->config("intranetdir");
    chdir($dir) or ( abort("ERROR: failed to reach your installation directory.") and return );
    my ( $cutoff_major, $cutoff_functional, $cutoff_subnumber ) = split ( /\./, C4::Context::KOHAVERSION );
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
