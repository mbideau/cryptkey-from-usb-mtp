��    \      �     �      �     �     �  -     T   <  7   �  U   �  1  	  	   Q
  	   [
  �  e
  ?   "  =   b     �  s   �  �   /  >   �     7  �   U  �   "  9   �  %   �  1     (   @  	   i  )   s  0   �     �     �     �       8     7   E  �   }     9     T  &   Z     �  !   �  *   �     �  (   	  +   2     ^  .   ~  3   �  '   �  ,   	  5   6  %   l  .   �     �  �  �     b  !   k     �  4   �  9   �  '        <  7   X  1   �  9   �     �  '     /   ,     \  ?   a  A   �     �     �               9  D   X  )   �  "   �  &   �  �     �   �  3   c  V   �  !   �       :     '   Q  #   y  >   �  5   �          /     7  Q  @  3   �     �  =   �  p      K   �   �   �   �  [!  	   #     #  >  #  a   W%  A   �%     �%  �   &  �   �&  G   �'  1   �'  
  �'  �   )  E   �)  ,   �)  :   *  9   N*     �*  <   �*  5   �*     +     "+     6+     :+  J   C+  ?   �+  �   �+  !   �,     �,  6   �,  &   -  0   ?-  8   p-  8   �-  W   �-  B   :.  '   }.  @   �.  =   �.  0   $/  -   U/  G   �/  )   �/  A   �/     70  H  K0     �3  %   �3  *   �3  N   �3  A   @4  B   �4      �4  Q   �4  @   85  >   y5     �5  -   �5  4   �5     #6  h   *6  ^   �6     �6  /   7     =7     D7  /   b7  L   �7  9   �7  &   8  .   @8  �   o8  -  E9  -   s:  k   �:  '   ;     5;  >   ;;  6   z;  %   �;  W   �;  _   /<  '   �<     �<  	   �<     T   Z      &   ;   U   4          %   #      >                  $          '            K   J       1                 N       :   Y       6          S   C       	      E   <   ,       @   Q   
   D          "   L           /              F   +   !          -   *         [                              =   3   V   7   H          M                  5   (           O      X   0   R   A              \       8   W         9          2   )   G   I   B            ?   .   P        %s failed to mount device '%s' '%s' binary not found (informative only) The disk source to unlock. A '%s' entry configuration without any key (key will be specified in a mapping file) A URL encoded key path with 'encrypted' option, in '%s' A URL encoded key path, to prevent crashing on spaces and non-alphanum chars, in '%s' A path to a key file.
                           The env var is optional if the argument '%s'
                           is specified, required otherwise.
                           Same process apply as for the '%s' argument,
                           i.e.: removing quotes, URL decoding and decrypting. ARGUMENTS Aborting. Add a mapping between a DM target %s and a
                           key path %s. The key might be encrypted in
                           which case you need to specify it with '%s'.
                           If the key path contains non-alphanum char it will be
                           automatically url-encoded and added option '%s'.
                           The mapping entry will be added to file:
                             '%s'. Add a whitelist filter based on currently available MTP devices Add the mapping between the DM target and the key (encrypted) Binary '%s' (%s) not found Check a mapping file.
                           %s is optional. It defaults to:
                             '%s'. Check that every requirements had been copied
                           inside the initramfs specified.
                           PATH is optional. It defaults to:
                             '%s'. Check that every requirements had been copied inside initramfs Check the mapping file syntax Create a filter list based on current available
                           devices (i.e.: produced by '%s').
                           PATH is optional. It defaults to:
                             '%s'. Create an initramfs hook at specified path.
                           PATH is optional. It defaults to:
                             '%s'. Create an initramfs hook to copy all required files in it DM target '%s' already have a mapping DM target '%s' do not match any DM target in '%s' DM target is empty for mapping line '%s' DM_TARGET Decode a URL encoded string, just to test Decode the STRING with url format then print it. Directory '%s' (%s) not found Display this help. ENV EXAMPLES Enable debug mode, update initramfs, check it and reboot Encode a string to URL format to further add it to '%s' Encode the STRING to url format and print it.
                           NOTE: Usefull to create a key path without spaces
                           to use into '%s' at the third column. Excluding device '%s' (%s) FILES Failed to add key '%s' to kernel cache Failed to create file '%s' Failed to create filter file '%s' Failed to decrypt key '%s' with cryptsetup Failed to get file size of '%s' Failed to set timeout on cached key '%s' Filesystem of device '%s' is not accessible Filter file '%s' already exists Ignoring device '%s' (filesystem unaccessible) Initramfs file '%s' doesn't exist or isn't readable Initramfs hook file '%s' already exists Initramfs hook shell script created at '%s'. Invalid MTP device filter strategy '%s' (must be: %s) Invalid argument '%s' for option '%s' Invalid key options '%s' for mapping line '%s' Invalid line '%s' Is the path to a key file.
                           The argument is optional if the env var %s
                           is specified, required otherwise.
                           It is relative to the device mount point/dir.
                           Quotes ['"] will be removed at the begining and end.
                           If it starts with '%s' it will be URL decoded.
                           If it starts with '%s' it will be decrypted with
                           '%s' on the file.
                           '%s' and '%s' can be combined in any order, 
                           i.e.: '%s'
                              or '%s'. KEY_PATH Kernel module '%s' (%s) not found Key caching is disabled Key content size '%s' exceeds cache max size of '%s' Key decrypted but device mapper '%s' doesn't exists! Bug? Key path is empty for mapping line '%s' Library '%s' (%s) not found MTP device list file '%s' doesn't exist nor is readable Mapping file '%s' doesn't exist or isn't readable OK. Initramfs '%s' seems to contain every thing required. OPTIONS On Debian you can install it with: > %s Override the mapping for DM target '%s' [Y/n] ? PATH Please unlock the device '%s', then hit enter ... ('s' to skip) Print a key to STDOUT from a key file stored on a USB MTP device. Reboot and pray hard! Removing key '%s' from cache STRING Shell script '%s' not found Skipping unlocking device '%s' The command above will result in the following mapping entry in '%s' The content for key '%s' cannot be cached The default path to initramfs hook The path to a list of filtered devices The path to a mapping file containing mapping between
                           crypttab DM target entries and key (options and path). The target device mapper name (unlocked).
                           It is used to do the mapping with a key if none is
                           specified in the crypttab file, else informative only. This shell script (to be included in the initramfs) To further investigate, you can use this command to list files inside initramfs:\n> %s Too few arguments for option '%s' USAGE Uh, I do not understand the cause of failure (bug?), sorry Unlocking '%s' with cached key '%s' ... Update the content of the initramfs Use this script as a standalone shell command to unlock a disk Value '%s' cannot contain mapping file separator '%s' You should execute '%s' now. keyfile optional Project-Id-Version: cryptkey-from-usb-mtp 0.0.1
Report-Msgid-Bugs-To: mica.devel@gmail.com
PO-Revision-Date: 2019-02-02 17:09+0100
Last-Translator: Automatically generated
Language-Team: none
Language: fr
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 8bit
Plural-Forms: nplurals=2; plural=(n > 1);
 %s n'a pas réussi à monter le périphérique '%s' binaire '%s' non trouvé (informationnel seulement) Le disque source a dévérouiller. Une entrée de configuration de '%s' sans clé spécifiée (celle-ci le sera dans un fichier de correspondances) Chemin de clé encodé au format url et avec l'option 'chiffrée' dans '%s' Chemin de clé encodé au format url, pour éviter un plantage dû aux espaces et aux caractères non-alpanumériques, dans '%s' Un chemin vers un fichier 'clé'.
                           La variable d'environnement est optionnelle si
                           l'argument '%s' est spécifié, sinon il est
                           requis.
                           Le même processus s'applique que pour l'argument
                           '%s', càd: suppression des guillements, décodage
                           de l'URL, et déchiffrement. ARGUMENTS Abandon. Ajout d'une correspondance entre un DM cible %s
                           et un chemin de la clé %s. La clé peut être
                           chiffrée, dans quel cas vous devez le spécifier
                           avec '%s'.
                           Si le chemin de la clé contient des charactères
                           non-alphanumérique il sera url-encodé automatiquement
                           et l'option '%s' sera ajoutée.
                           L'entrée de la correspondance sera ajoutée au fichier:
                             '%s'. Ajoute un filtrage par 'liste blanche' basé sur les périphériques MTP actuellement disponibles Ajoute la correspondance entre le DM cible et la clé (chiffrée) Binaire '%s' (%s) non trouvé Vérifie un fichier de correspondances.
                           %s est optionnel. Par défaut vaut:
                             '%s'. Vérifie que tous les (fichiers) pré-requis on été
                           copiés dans l'initramfs spécifiée.
                           CHEMIN est optionnel. Par défaut vaut:
                             '%s'. Vérifie que tous les fichiers requis ont été copié dans l'initramfs Vérifie la syntaxe du fichier de correspondances Crée une liste de filtres basée sur les 
                           périphériques actuellement disponibles
                           (càd: produits par '%s').
                           CHEMIN est optionnel. Par défaut vaut:
                             '%s'. Crée un 'hook' à l'initramfs au chemin spécifié.
                           CHEMIN est optionnel. Par défaut vaut:
                             '%s'. Crée un 'hook' initramfs pour copier tous les fichiers requis dedans Le DM cible '%s' a déjà une correspondance Le DM cible '%s' ne correspond à aucun DM cible dans '%s' Le DM cible est vide pour la ligne de correspondance '%s' DM_CIBLE Décode une chaine encodée au format URL, juste pour tester Décode une CHAINE avec le format url puis l'affiche. Dossier '%s' (%s) non trouvé Afficher cette aide ENV EXEMPLES Active le mode 'debug', met à jour l'initramfs, le vérifie et redémarre Encode une chaîne au format URL pour ensuite l'ajouter à '%s' Encode une CHAINE au format url puis l'affiche.
                           NOTE: Utile pour créer un chemin de clé sans
                           espaces, employable dans la troisième colonne de
                           '%s'. Exclu le périphérique '%s' (%s) FICHIERS Échec de l'ajout de la clé '%s' au cache du 'kernel' Échec de la création du fichier '%s' Échec de la création du fichier de filtre '%s' Échec du déchiffrage de la clé '%s' avec 'cryptsetup' Échec de la récupération de la taille du fichier '%s' Échec de la définition d'une limite de temps (timeout) sur la clé mise en cache '%s' Le système de fichier du périphérique '%s' n'est pas accessible Le fichier de filtre '%s' existe déjà Ignore le périphérique '%s' (système de fichier inaccessible) Le fichier d'initramfs '%s' n'existe pas ou n'est pas lisible Le fichier 'hook' d'initramfs '%s' existe déjà Fichier script shell de 'hook' créé à '%s' Stratégie de filtrage de périphérique '%s' invalide (doit être: %s) Argument '%s' invalide pour l'option '%s' Option de clé '%s' invalide pour la ligne de correspondance '%s' Ligne invalide '%s' Est le chemin vers un fichier de clé.
                           L'argument est optionnel si la variable
                           d'environnement %s est spécifiée, sinon 
                           il est requis.
                           Il est relatif au point de montage du périphérique.
                           Les guillements ['"] seront supprimés au début et
                           à la fin.
                           S'il débute par '%s' il sera décodé depuis un
                           format URL.
                           S'il débute par '%s' le fichier sera déchiffré
                           avec '%s'.
                           '%s' et '%s' peuvent être combiné dans
                           n'importe quel ordre, 
                           càd: '%s'
                              ou '%s'. FICHIER_CLE Module 'kernel' '%s' (%s) non trouvé La mise en cache des clé est désactivée La taille '%s' du contenu de la clé dépasse la taille maximale du cache '%s' Clé déchiffrée mais le 'device mapper' '%s' n'existe pas! Bug? Le chemin de la clé est vide pour la ligne de correspondance '%s' Librairie '%s' (%s) non trouvée Le fichier de la liste des périphériques MTP '%s' n'existe pas ou est illisible Le fichier de correspondances '%s' n'existe pas ou est illisible OK. L'initramfs '%s' semble contenir tous les fichiers requis. OPTIONS Sur Debian vous pouvez l'installer avec: > %s Remplacer la correspondance du DM cible '%s' [O/n] ? CHEMIN S'il vous plait, dévérouillez le périphérique '%s', puis appuyez sur 'entrée' ... ('s' pour passer) Affiche une clé dans STDOUT issue d'un fichier de clé stocké sur un périphérique USB MTP. Redémarrer et prier fort! Suppression de la mise en cache de la clé '%s' CHAINE Script shell '%s' non trouvé Passe le dévérouillage du périphérique '%s' La commande ci-dessus produit l'entrée de correspondance suivante dans '%s' Le contenu de la clé '%s' ne peut pas être mis en cache Chemin par défaut du 'hook' initramfs Chemin d'une liste de périphériques filtrés Chemin vers un fichier de correspondances contenant l'association
                           entre les DM cibles des entrées dans 'crypttab'
                           et les fichiers 'clés' (options et chemin). Nom du 'device mapper' cible (dévérouillé).
                           Est utilisé pour faire la correspondance avec 
                           une clé si aucune n'est spécifiée dans le
                           fichier 'crypttab', sinon est uniquement 
                           informatif. Ce script shell (à inclure dans l'initramfs) Pour investiguer plus, vous pouvez utiliser cette commande pour lister les fichiers dans l'initramfs:\n> %s Trop peu d'arguments pour l'option '%s' USAGE Euh, je ne comprends pas la cause de l'échec (bug?), désolé Dévérouille '%s' avec la clé mise en cache '%s' ... Met à jour le contenu de l'initramfs Utilise ce script en tant que commande shell 'standalone' pour dévérouiller un disque La value '%s' ne peut contenir le charactère '%s' de séparation du fichier de correspondances Vous devriez exécuter '%s' maintenant. fichier_cle optionnel 