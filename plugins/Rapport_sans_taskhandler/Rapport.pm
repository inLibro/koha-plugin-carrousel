package Koha::Plugin::Rapport;

## It's good practive to use Modern::Perl
use File::stat;
use Modern::Perl;
use warnings;
use utf8;

## Required for all plugins
use base qw(Koha::Plugins::Base);
use C4::Auth;
use C4::Context;

## plugin version
our $VERSION = 1.00;


my $baseDirectory = C4::Context->config('pluginsdir');
our $publicDirectory = '/public/' . C4::Context->config('client') . '/intranet';
our $scriptDirectory = $baseDirectory."/Koha/Plugin/Rapport";
my $year = 2014;

sub new {
    my ( $class, $args ) = @_;

    $args->{'metadata'} = {
        name   => 'Rapport Bilans et statistiques',
        author => 'Simith DOliveira',
        description => "Le plugin crée le rapport annuel à partir de la base de donnée installé sur koha",
        date_authored   => '2015-02-09',
        date_updated    => '2016-06-15',
        minimum_version => '3.20',
        maximum_version => undef,
        version         => $VERSION,
    };

    my $self = $class->SUPER::new($args);

    return $self;
}

sub tool {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my %params;

    #enelver le commentaire pour laisser l'utilisateur faire le choix de l'annnee dans la configuration
    #my $year = $self->retrieve_data('year');

    #Si l'action est generer, le script repport.pl sera excuter
    if($cgi->param('action')){
        `perl $scriptDirectory/rapport.pl -year $year`;
    }

    #get a list from all files in $directory
    my @files_list = getFilesList();

    # Telecharger le fichier choisi
    if(uc($cgi->request_method) eq 'GET' && defined $cgi->param('id')) {
        my $file_id = $cgi->param('id');

        if($file_id >= 0 and $file_id < scalar @files_list){

            my $filename = $files_list[$file_id]->{name};
            binmode STDOUT;
            # Open the selected file and send it to the browser
            print $cgi->header(-type => 'application/x-download',
            -name => "$filename",
            -Content_length => -s "$scriptDirectory/rapports/$filename",
            -attachment => "$filename");

            open FILE, "<:utf8", "$scriptDirectory/rapports/$filename";
            binmode FILE;

            my $buf;
            while(read(FILE, $buf, 65536)) {
                print $buf;
            }
            close FILE;
        }
    }

    my $preferedLanguage = $cgi->cookie('KohaOpacLanguage');
    $params{files_loop} = \@files_list;
    $params{year} = $year;

    #La template par défault est en anglais et tout depend du cookie, il va charger la template en français
    my $template = undef;

    eval {$template = $self->get_template( { file => "Rapport_" . $preferedLanguage . ".tt" } )};
    if(!$template){
        $preferedLanguage = substr $preferedLanguage, 0, 2;
        eval {$template = $self->get_template( { file => "Rapport_$preferedLanguage.tt" } )};
    }
    $template = $self->get_template( { file => 'Rapport_fr-CA.tt' } ) unless $template;
    $template->param( %params );

    print $cgi->header(-charset => 'utf8');
    print $template->output();

}

#enelver le commentaire pour laisser l'utilisateur faire le choix de l'annnee dans la configuration
# sub configure {
#     my ( $self, $args ) = @_;
#     my $cgi = $self->{'cgi'};
#
#     unless ( $cgi->param('save') ) {
#         my $template = $self->get_template({ file => 'configure_fr-CA.tt' });
#
#         ## Grab the values we already have for our settings, if any exist
#         $template->param(
#             year => $self->retrieve_data('year'),
#         );
#
#         print $cgi->header(-charset => 'utf8');
#         print $template->output();
#     }
#     else {
#         $self->store_data(
#             {
#                 year                => $cgi->param('year'),
#                 last_configured_by => C4::Context->userenv->{'number'},
#             }
#         );
#         $self->go_home();
#     }
# }

sub getFilesList {
    #Get the files list
    my @files_list;
    opendir(DIR, "$scriptDirectory/rapports");

    my $i=0;
    foreach my $filename (readdir(DIR)) {
        my $full_path = "$scriptDirectory/rapports/$filename";
        next if ($filename =~ /^\./ or $filename =~ /\.xml/ or -d $full_path);

        my $st = stat($full_path);
        push(@files_list, {name => $filename,
        date => scalar localtime($st->mtime),
        size => $st->size,
        id   => $i});
        $i++;
    }
    closedir(DIR);

    return @files_list;
}

#Supprimer le plugin avec toutes ses données
sub uninstall() {
    my ( $self, $args ) = @_;
    my $table = $self->get_qualified_table_name('mytable');

    return C4::Context->dbh->do("DROP TABLE $table");
}

1;
