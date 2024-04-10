package Koha::Plugin::Carrousel::Spec;

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# This program comes with ABSOLUTELY NO WARRANTY;

use Modern::Perl;

use base qw{Module::Bundled::Files};

=head1 Koha::Plugin::Carrousel::Spec

Editeur des données de personnalisation

=cut

=head2 Class methods

=head3 json_parse_refs

Fonction permettant de parser un objet json pour y inclure le contenu
d'autres fichiers.

Utilisation en json :

    {
        "attr" : {
            "$ref" : "from_plugin_root/file_path.json"
        }
    }

Les attributs contenu dans le fichier référencé seront ajouté à ceux
de l'objet contenant le "$ref". Par défaut, remplace les attributs
existants.

=cut

sub json_parse_refs {
    my ( $self, $args ) = @_;
    my $object = $args->{'json_object'};
    my $overwrite = $args->{'overwrite'} // 1;

    if ( ref $object eq "HASH" ) {
        if ( my $ref = $object->{'$ref'} ) {
            # Le HASH contient une référence. Ajouter le nouvel objet.
            my $include_str = $self->mbf_read($ref);
            my $include     = decode_json($include_str);
            my $include_obj = $self->json_parse_refs( { json_object => $include });

            # Traiter le reste de l'objet.
            delete $object->{'$ref'};
            foreach my $key ( keys %{$object} ) {
                my $value = $object->{$key};
                $object->{$key} = $self->json_parse_refs( { json_object => $value });
            }

            # Ajouter le contenu du fichier à l'objet actuel.
            foreach my $key ( keys %{$include_obj} ) {
                if ( $overwrite || ! $object->{$key} ) {
                    $object->{$key} = $include_obj->{$key};
                }
            }

            return $object;
        } else {
            # Le HASH ne contient pas de référence. Continuer sur chaque propriété.
            foreach my $key ( keys %{$object} ) {
                my $value = $object->{$key};
                $object->{$key} = $self->json_parse_refs( { json_object => $value });
            }
        }
    } elsif ( ref $object eq "ARRAY" ) {
        # ARRAY ne peut pas être une référence. Continuer sur chaque élément.
        foreach my $obj ( @{$object} ) {
            $self->json_parse_refs( { json_object => $obj });
        }
    }

    return $object;
}

1;
