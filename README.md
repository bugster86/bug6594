Descrizione Role
=========
* Distribuisce lo script checkdf.sh versione 1.1
  ** Accetta il parametro -P in sostituzione al parametro -m
  ** Logga l'operazione di azzeramento del livello di log nei file .lcf
* Smonta il cron attale che richiama checkdf.sh
* Installa 3 cron che permettono di schedulare lo script tranne nella fascia oraria 00:10 - 00:15


Requisiti
------------
Nessuno in particolare
Variabili
--------------
Nessuna

Dipendenze
------------
Nessuna

Esempio di chiamata
----------------

ansible-playbook /home/playbook/bugs/6594/main.yml -l <elenco hosts/gruppo> -C (dry run)
ansible-playbook /home/playbook/bugs/6594/main.yml -l <elenco hosts/gruppo>

Informazioni Autore
------------------

Martino.Viganò
Martino.Vigano@enghouse.com

![alt text](https://www.focus.it/site_stored/imgs/0001/010/get_96210194_web.630x360.jpg)
