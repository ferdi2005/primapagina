require 'mediawiki_api'
if !File.exist? "#{__dir__}/.wikiuser"
    puts 'Inserisci username:'
    print '> '
    username = gets.chomp
    puts 'Inserisci password:'
    print '> '
    password = gets.chomp
    File.open("#{__dir__}/.wikiuser", "w") do |file| 
      file.puts username
      file.puts password
    end
  end  
userdata = File.open("#{__dir__}/.wikiuser", "r").to_a

client = MediawikiApi::Client.new 'https://it.wikinews.org/w/api.php'
client.log_in "#{userdata[0].gsub("\n", "")}", "#{userdata[1].gsub("\n", "")}"

pubblicati = client.query(list: :categorymembers, cmtitle: "Categoria:Pubblicati", cmsort: :timestamp, cmdir: :desc, cmlimit: 6)["query"]["categorymembers"]

# Rigetto cose non nel ns0 (eventuali errori)
pubblicati.reject! { |pubblicato| pubblicato["ns"] != 0 }

# Lista del contenuto
list = []
svolgimento = 0

pubblicati.each do |pubblicato|
    svolgimento += 1

    puts "Svolgo le operazioni per #{pubblicato["title"]} - #{svolgimento}º articolo"

    content = client.query(prop: :revisions, rvprop: :content, titles: pubblicato["title"], rvlimit: 1)["query"]["pages"]["#{pubblicato["pageid"]}"]["revisions"][0]["*"]
    match = content.match(/{{data\|(.+)\|(lunedì|martedì|mercoledì|giovedì|venerdì|sabato|domenica)}}/i)
    data = match[1]
    giorno = match[2]

    estratto = client.query(prop: :extracts, exsentences: 2, exintro: 1, explaintext: 1, titles: pubblicato["title"])["query"]["pages"]["#{pubblicato["pageid"]}"]["extract"]
    estratto.gsub!("#{giorno} #{data}", "")
    estratto.gsub!("\n", "")

    direzione = "right" if svolgimento.odd?
    direzione = "left" if svolgimento.even?

    image = client.query(prop: :pageimages, piprop: :name, pilimit: 1, titles: pubblicato["title"])["query"]["pages"]["#{pubblicato["pageid"]}"]["pageimage"]

    primopiano = "{{Primopiano|data=#{data}|link-titolo=#{pubblicato["title"]}|immagine=#{image}|grandezza=100px|direzione=#{direzione}|didascalia=none|testo=#{estratto}}}\n"
    primopiano.strip!
    list.push(primopiano)
end
list.insert(0, "<noinclude>
    [[Categoria:Template della pagina principale]]<!--

    Questa pagina viene aggiornata automaticamente da un bot. Se riscontri dei problemi puoi contattare Utente:Ferdi2005. Se tuttavia non riscontri problemi diretti col bot ma desideri modificare la pagina, segui le istruzioni riportate qui sottof.check_box :attribute
    SE VUOI CAMBIARLO MODIFICA IL TEMPLATE:PRIMOPIANO IN QUESTO MODO:
    
    {{Primopiano
    |data= data della pubblicazione della notizia. Esempio: 10 febbraio 2013
    |link-titolo= link esatto all'articolo (senza [[]]), vale anche come titolo
    |titolo-sostitutivo= da compilare solo se si vuole un titolo diverso da quello in link-titolo
    |immagine= nome dell'immagine (senza [[File:]]; esempio: Breaking it.png)
    |grandezza= dimensione in pixel (esempio: 100px)
    |direzione= può essere left o right a seconda che si voglia mettere l'immagine a sinistra o a destra
    |didascalia= breve descrizione dell'immagine. Se non presente scrivi none
    |introduzione= breve introduzione all'articolo. Non è obbligatoria
    |testo= breve testo che descrive l'articolo. Puoi prendere la parte introduttiva dell'articolo stesso oppure puoi scriverlo tu. *NON* inserire wikilink in questa descrizione!}}
    
    versione a campi vuoti per comodità di copia-e-incolla
    ------------------------------------------------------
    
    {{Primopiano
    |data=
    |link-titolo= 
    |titolo-sostitutivo=
    |immagine=
    |grandezza= 100px
    |direzione= left
    |didascalia= none
    |introduzione=
    |testo=
    }}
    
    PER FAVORE COMMENTATE L'IMMAGINE QUANDO NON SERVE MA *NON* CANCELLATELA!!
    QUANDO AGGIORNATE QUESTO TEMPLATE ELIMINATE GLI ARTICOLI DAL PIÙ VECCHIO AL PIÙ RECENTE
    INSERITE MASSIMO SEI ARTICOLI
    
    LE NOTIZIE COMINCIANO SOTTO GLI ASTERISCHI
    ************************************************************************-->
    </noinclude>\n")
puts "Finalizzo e pubblico"
client.edit(title: "Template:Pagina principale/Primo piano/Prima Pagina", text: list.join(""))