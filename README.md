IstexMetadata
=============

Outil d’extraction des métadonnées d’un corpus de documents [**ISTEX**](https://www.istex.fr/) en utilisant les identifiants de ces documents. Il permet aussi d’extraire les descripteurs (ou mots-clés) obtenus par la méthode [_teeft_](https://enrichment-process.data.istex.fr/ark:/67375/R0H-R25KK4KZ-Q) (**T**erm **E**xtraction for **E**nglish **F**ull**T**ext).

Il est possible d’avoir ce programme sous forme d’une image [Docker](#docker).

### Usage

```bash
    IstexMetadata.pl -i input_file -m metadata_file -t teeft_file [ -l (fr|en) ]
    IstexMetadata.pl -i input_file -m metadata_file [ -l (fr|en) ]
    IstexMetadata.pl -i input_file -t teeft_file
    IstexMetadata.pl -h
```

### Options

```text
    -h  affiche cette aide et quitte
    -i  donne le nom du fichier en entrée
    -l  indique la langue utilisée, français ou anglais (anglais par défaut)
    -m  donne le nom du fichier de sortie contenant les métadonnées
    -t  donne le nom du fichier de sortie “doc × terme” avec l’indexation teeft
```

### Fichier d’entrée

Le fichier en entrée contient les identifiants ARK des documents **ISTEX**. Cette liste commence juste après la ligne contenant la mention `[ISTEX]`. Tout ce qui est avant cette ligne sera ignoré. Ensuite, on a une ligne par identifiant commençant par la mention `ark` suivie de l’identifiant proprement dit. 

```text
[ISTEX]
ark ark:/67375/WNG-TVRWVF37-H
ark ark:/67375/6H6-TVDKG7GP-X
ark ark:/67375/WNG-89GKVQHX-T
ark ark:/67375/WNG-DL88J7JW-V
ark ark:/67375/6H6-DS9HH21N-J
ark ark:/67375/JKT-0FG854P5-F
   ...
```

Il est possible d’ajouter, sur chaque ligne, un nom de fichier parce qu’un nom est plus facile à utiliser qu’un identifiant pour faire référence à un fichier. Pour cela, ajouter une série d’espaces, un symbole “**#**” et le nom du fichier. Exemple&nbsp;:

```text
[ISTEX]
ark ark:/67375/WNG-TVRWVF37-H           # Reptiles_v2b_00001
ark ark:/67375/6H6-TVDKG7GP-X           # Reptiles_v2b_00002
ark ark:/67375/WNG-89GKVQHX-T           # Reptiles_v2b_00003
ark ark:/67375/WNG-DL88J7JW-V           # Reptiles_v2b_00004
ark ark:/67375/6H6-DS9HH21N-J           # Reptiles_v2b_00005
ark ark:/67375/JKT-0FG854P5-F           # Reptiles_v2b_00006
   ...
```

### Docker

Pour construire une image Docker, faire&nbsp;:

```bash
   docker build -t visatm/istex-metadata .
```

Pour éviter que l’utilitaire `cpanm` ne perde du temps en effectuant les tests des modules Perl à installer, utilisez l’option “--build-arg” pour modifier l’option “cpanm_args” définie dans le Dockerfile. Ça donne&nbsp;:

```bash
   docker build -t visatm/istex-metadata --build-arg cpanm_args=--notest .
```

En fait, vous pouvez ainsi modifier ou ajouter toutes les options de [cpanm](https://www.unix.com/man-page/debian/1p/cpanm/) que vous voulez. 

À noter que les variables `http_proxy`, `https_proxy` et `no_proxy` ne sont pas définies dans le Dockerfile. Il est cependant possible de leur affecter une valeur lors de la création de l’image Docker&nbsp;:

```bash
   docker build --build-arg cpanm_args=--notest \
                --build-arg http_proxy="http://proxyout.inist.fr:8080/" \
                --build-arg https_proxy="http://proxyout.inist.fr:8080/" \
                --build-arg no_proxy="localhost, 127.0.0.1, .inist.fr" \
                -t visatm/istex-metadata .
```

Il est également possible depuis la version 17.07 de Docker d’obtenir le même résultat en configurant le client Docker. Pour cela, il faut modifer le fichier `~/.docker/config.json` pour ajouter ces informations sous la forme suivante&nbsp;:

```json
    "proxies": {
        "default": {
            "httpProxy": "http://proxyout.inist.fr:8080",
            "httpsProxy": "http://proxyout.inist.fr:8080",
            "noProxy": "localhost,127.0.0.1,.inist.fr"
        }
    }
```

Dans l’exemple suivant, on utilise `IstexMetadata.pl` à partir de son image Docker dans le cas où on veut télécharger des métadonnées ainsi que créer un fichier “doc × terme” en supposant que&nbsp;:

* l’utilisateur à l’identifiant (ou [UID](https://fr.wikipedia.org/wiki/User_identifier)) 1002
* l’utilisateur à l’identifiant de groupe (ou [GID](https://fr.wikipedia.org/wiki/Groupe_%28Unix%29)) 400
* le fichier d’identifiants s’appelle “**exemple.corpus**” et se trouve dans le répertoire courant


```bash
   docker run --rm -u 1002:400 -v `pwd`:/tmp visatm/istex-metadata IstexMetadata.pl -i exemple.corpus -m exemple_metadata.tsv -t exemple_teeft.txt
```

### Galaxy : fichiers de configuration

On a 4 fichiers de configuration pour `IstexMetadata.pl` sous Galaxy, 2 en anglais, 2 en français :

 * istex_metadata_en.xml
 * istex_metadata_fr.xml
 * istex_teeft_en.xml
 * istex_teeft_fr.xml

On peut installer l’un ou l’autre langue au choix sous Galaxy, de préférence avec les noms `istex_metadata.xml` et `istex_teeft.xml`, et on doit indiquer leur nom et leur chemin dans le fichier `config/tool_conf.xml`. Si l’on suppose que ce fichier a été placé dans le répertoire `tools/istex` de Galaxy, l’entrée dans le fichier `config/tool_conf.xml` est :

```xml
    <section id="istex" name="ISTEX Data">
      <tool file="istex/istex_metadata.xml" />
      <tool file="istex/istex_teeft.xml" />
    </section>
```
