# koha-plugin-carrousel
Extension Carrousel pour le SIGB Koha

Cette extension permet de générer un ou plusieurs carrousels d'images sur l’OPAC.

La liste des notices de chaque carrousel peut provenir de différentes sources de données dans Koha telles les&nbsp;:
- listes publiques
- rapports SQL
- codes de collection (contenu dans la zone 952$ 8 de la notice exemplaire)

Cette extension offre aussi plusieurs configurations&nbsp;:
- style d’affichage des carrousels
- ordre d’apparition des carrousels
- couleur du texte et de l’arrière-plan
- autorotation

Instructions (anglais)&nbsp;: https://inlibro.com/en/carousel-instructions/

## Aperçu

### Affichage style «&nbsp;Carrousel&nbsp;»
![Carrousel style «&nbsp;Carrousel&nbsp;»](https://inlibro.com/wp-content/uploads/2021/02/Carrousels-1.png)

### Affichage style «&nbsp;À défilement&nbsp;»
![Carrousel style «&nbsp;À défilement&nbsp;»](https://inlibro.com/wp-content/uploads/2021/02/Carrousels-D%C3%A9filement.png)

## Différences entre versions Koha

**Attention!**

Si une version antérieure du Carrousel est déjà installée dans l'instance Koha, il faudra la désinstaller avant d’ajouter une version plus récente (version 2.0 et plus).

### Version Koha 19.05 et antérieures

Le code généré par cette extension sera inséré dans la préférence système **OpacMainUserBlock** avec des balises HTML afin de marquer le code de `Debut du carrousel` et de la `Fin du carrousel`.

### Version Koha 20.05 et plus

Pour les versions plus récentes de Koha, le contenu du carrousel sera géré dans une publication de l’outil **Personnalisations HTML** ayant comme *localisation d'affichage* **OpacMainUserBlock**.

## Page de configuration

*Pour atteindre la page de configuration, utiliser l'action **Configurer** de l'extension **Carrousel** dans le tableau des extensions.*

### Configuration des carrousels

#### Choisir et ordonner les carrousels
Lorsqu'au moins une source de données est choisie (voir la section suivante *Ajouter un carrousel*) les options respectives au carrousel qui sera généré par cette source deviennent disponibles dans un tableau au haut de la page.

- **Module** (*Lecture seule*)&nbsp;:  Permet d'identifier le type de la source de données.
- **Nom** (*Lecture seule*)&nbsp;:  Nom de la source de données.
- **Titre**&nbsp;: Texte à afficher en tant que titre du carrousel. Si vide, le *nom* sera utilisé.
- **Type**&nbsp;: Style du carrousel
    - *Carrousel*&nbsp;: Les images sont affichées en cercle avec un effet de perspective, c'est l'affichage traditionnel.
    - *À défilement*&nbsp;: Les images sont affichées horizontalement, c'est un affichage plus moderne.
    - *À défilement avec texte*&nbsp;: Alternative plus accessible du type *À défilement*. Affiche le titre du document sous l'image.
- **Autorotation**&nbsp;: Défilement automatiquement des éléments du carrousel selon les options définies dans la section *Options*. Si ce paramètre n’est pas activé, les utilisateurs devront cliquer sur les flèches pour avancer ou reculer dans le carrousel. À noter que les flèches sont toujours disponibles, même lorsque l'*autorotation* est activée.
- **Ordre**&nbsp;: L'ordre des lignes dans le tableau détermine l'ordre d'affichage à l'OPAC. Les boutons de cette case permettent respectivement de monter et de descendre d'une position, de mettre en premier et en dernier dans la liste, et de ne pas afficher le carrousel.
- **URL externe**&nbsp;: Permet d'utiliser le lien qui est dans la zone 856$u de la notice en cliquant sur l'image dans le carrousel. Si inactif ou si la notice n’a pas de lien dans 856$u, le lien de l’image mène à la notice dans le catalogue.
- **Suffixe d'URL**&nbsp;: Permet d'ajouter un suffixe à l'URL du lien des images de ce carrousel. Utilisé notamment pour l'intégration avec des outils d'analyse.

#### Ajouter un carrousel

Une liste déroulante par type de source de données permet de choisir une ou plusieurs sources à partir desquelles générer les carrousels.

### Options

#### Rotation automatique

- **Direction de la rotation automatique**&nbsp;: Indique le sens de rotation (*gauche* ou *droite*) des carrousels pour lesquels l'*auto rotation* est activé.
- **Délai de la rotation automatique (ms)**&nbsp;: Délai entre chaque mouvement du carrousel en mode *auto rotation*. La valeur par défaut est 1500ms.

#### Couleurs

- **Couleur du titre**&nbsp;: La couleur d'affichage du *titre* / *nom* de tous les carrousels.
- **Couleur du texte**&nbsp;: La couleur d'affichage du texte de tous les carrousels.
- **Couleur de l'arrière-plan**&nbsp;: La couleur de l'arrière-plan de tous les carrousels.

*Carrousel*&nbsp;: la couleur du texte et la couleur de l’arrière-plan affectent les flèches de défilement à gauche et à droite, ainsi que la bande en bas du carrousel où est écrit le titre du document au premier plan.

*À défilement*&nbsp;: la couleur du texte et la couleur de l’arrière-plan n’affectent que les flèches de défilement à gauche et à droite.

#### Autres

- **Générer un fichier JSON**&nbsp;: Lors de la génération des carrousels, aussi créer un fichier JSON contenant les informations concernant les éléments de chaque carrousel.
    - Le fichier est ensuite disponible à l'adresse&nbsp;: ***OPACBaseURL**/cgi-bin/koha/opac-retrieve-file.pl?id=carrousel*

## Générer les carrousels

Pour atteindre la page de génération des carrousels, utiliser l'action **Exécuter l'outil** de l'extension **Carrousel** dans le tableau des extensions.

Le bouton **Générer** affiché sur la page permet alors de relancer la génération de tous les carrousels déjà configurés.

*À noter que les carrousels existants ainsi que toutes modifications manuelles au code généré (via les* personnalisations HTML *du carrousel ou la section réservée à l'extension de la préférence système* OpacMainUserBlock *) risquent alors d'être écrasés.*

### Cron

Le script `Koha/Plugin/Carrousel/cron/generate.pl` permet de régénérer les carrousels via une tâche programmée (cron) ou une invite de commande. La commande a utiliser pourra alors prendre la forme&nbsp;:

```
perl -I <KOHA_PLUGINS_DIR> -I <KOHA_HOME>/Koha/Plugins <KOHA_PLUGINS_DIR>/Koha/Plugin/Carrousel/cron/generate.pl
```

Configurer un cron pour exécuter cette commande à une fréquence régulière (par exemple une fois par jour) permet de s'assurer de conserver une bonne synchronisation entre le contenu des sources et celui des carrousels. Cela peut éviter des oublis dans le cas de sources subissant des changements fréquents, par exemple une liste de nouveauté mise à jour au fil des acquisitions.

## IndependentBranches
Depuis la version 4.0.0, l'extension respecte la préférence système **IndependentBranches**. Ainsi, lorsque celle-ci est à **Oui**, les carrousels sont générés selon la bibliothèque à laquelle la source est associée.

On détermine la bibliothèque correspondante selon le type de la source&nbsp;:

- **Liste**&nbsp;: La bibliothèque de l'usager **propriétaire** de la liste
- **Rapport**&nbsp;: La bibliothèque de l'usager **auteur** du rapport
- **Collection**&nbsp;: La bibliothèque pour laquelle la **valeur autorisée** (de catégorie `CCODE`) de la collection est **limitée aux bibliothèques**
    - Dans le cas où la valeur autorisée a plus d'une *limite par bibliothèque*, ce sera la première bibliothèque de cette liste
    - Dans le cas où la valeur autorisée n'a pas de *limite par bibliothèque*, aucun carrousel ne sera généré pour cette collection

Pour chaque *bibliothèque* (pour laquelle l'extension a trouvé au moins un carrousel à générer), une *personnalisation HTML* distincte sera ajoutée (ou mise à jour) pour la *localisation d'affichage* **OpacMainUserBlock**.
