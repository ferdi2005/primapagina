# Prima Pagina
Bot sviluppato per gestire la sezione Prima pagina della pagina principale di [Wikinotizie in lingua italiana](https://it.wikinews.org/)
## Installazione
È necessario avere `ruby` installato e dare il comando:
```
gem install mediawiki_api
```
Fatto ciò, potrete tranquillamente avviare il bot digitando nel terminale `ruby primapagina.rb`. Al primo avvio vi verranno chiesti username e password del bot, da ottenere tramite Speciale:BotPasswords.
## Cron
Potete aggiungere lo script alla crontab affinché sia eseguito ciclicamente (in questo esempio una volta all'ora), chiedendo `which ruby `ed inserendo in crontab una cosa del genere (sostituendo user col nome del vostro utente, /usr/bin/ruby col risultato di which ruby e directory col path allo script):
```
0 1 * * * user /usr/bin/ruby /directory/primapagina.rb
```
## Contribuire
Ogni contributo è ben accetto!
