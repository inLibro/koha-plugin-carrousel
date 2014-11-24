# nous ajouterons un InLibro:: si jamais on envoie ça public
package Koha::Plugin::Languages;

use Modern::Perl;
use base qw(Koha::Plugins::Base);
use C4::Context;
use C4::Auth;
use C4::Languages;
use Koha::Tasks;
use JSON;

sub new {
    my ( $class, $args ) = @_;

    $args->{'metadata'} = {
        name   => 'Installateur de langues.',
        author => 'Philippe Blouin',
        description => "Permet l'ajout de choix de langues aux usagers de l'interface.  Remplace la commande './translage install'",
        date_authored   => '2014-07-17',
        date_updated    => '2014-07-17',
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
    binmode(STDOUT, ':utf8');
    my %params;

    # which languages are still installing
    my %installing = ();
    my $iq = Koha::Tasks->new()->getTasksRegexp('name' => 'PLUGIN-LANGUAGES', 'status' => 'WAITING|PROCESSING');
    while(my($unused, $t) = each %$iq) {
        if($t->{'command'} =~ /.\/translate install (.+)/) {
            $installing{$1} = 1;
        }
    }

    # GET ?status=1
    if(uc($cgi->request_method) eq 'GET' && $cgi->param('status')) {
        print $cgi->header(-Content_type => 'application/json');
        print encode_json(\%installing);
        return;
    }

    # obtenir la liste des langues pour les thèmes DISPONIBLES.  La librairie C4::Languages ne vérifie que ce qui est déjà installé.
    my $dir=C4::Context->config('intranetdir')."/misc/translator/po";
    opendir (MYDIR,$dir);
    my @languages = sort map {$_ =~ /^(.*)-opac-bootstrap.po/; $1; } grep { /-opac-bootstrap.po/ } readdir(MYDIR);    
    closedir MYDIR;
    my @installed = grep { !($installing{$_}) } map { map { $_->{rfc4646_subtag} } @{$_->{sublanguages_loop}} } @{C4::Languages::getTranslatedLanguages()};
    my %installed = map { $_ => 1 } @installed;

    # POST
    # Either we're installing a new language,
    # or we're updating the language availability settings.
    if(uc($cgi->request_method) eq 'POST') {
        my $new_language = $cgi->param('new_language');
        if($new_language) {
            installLanguage($new_language);
        } else {
            # We can only activate languages that are installed
            # There MUST be at least one active language per interface;
            # reject requests to set 0 active languages
            for my $k ('language', 'opaclanguages') {
                my $langs = join(',', grep { $installed{$_} } $cgi->param($k));
                $langs and C4::Context->set_preference($k, $langs);
            }
        }
        # prevent double-posting by suggesting a GET-redirect
        print $cgi->header(-status => 303, -Location => '/cgi-bin/koha/plugins/run.pl?class=Koha%3A%3APlugin%3A%3ALanguages&method=tool');
        return;
    }

    # which language is available where
    my %intranet_languages = map { $_ => 1 } split(/,/, C4::Context->preference('language'));
    my %opac_languages     = map { $_ => 1 } split(/,/, C4::Context->preference('opaclanguages'));

    my @install_deets = ();
    foreach my $l (@installed) {
        push(@install_deets, {
                'language' => $l,
                'enabled_for_intranet' => $intranet_languages{$l},
                'enabled_for_opac' => $opac_languages{$l},
            });
    }
    while(my($l, $unused) = each %installing) {
        push(@install_deets, {
                'language' => $l,
                'installing' => 1,
            });
    }

    @languages = grep { !($installed{$_}) && !($installing{$_})} @languages;

    my @installing = keys %installing;

    $params{languages} = \@languages;
    $params{languagesinstalled} = \@install_deets;
    $params{installing} = \@installing;
    
    my $template = $self->get_template({ file => 'languages.tt' });

    $template->param( %params );
    
    print $cgi->header(-charset => 'utf8');
    print $template->output();
}

sub installLanguage{
    my ($language) = @_;

    # install the template
    my $translatedir = C4::Context->config('intranetdir')."/misc/translator";
    my $command = "cd $translatedir; ./translate install $language";
    my $tasker = Koha::Tasks->new();
    my $hrOldTasks = $tasker->getTasks(command => $command);
    # we do not want to install the language twice
    if($hrOldTasks){
        foreach my $id(keys $hrOldTasks){
            if($hrOldTasks->{$id}->{status} ne 'FAILED'){
                return $id;
            }
        }
    }
    my $taskId = $tasker->addTask(name =>"PLUGIN-LANGUAGES", command=>$command);

    return $taskId;
}

sub status{
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
