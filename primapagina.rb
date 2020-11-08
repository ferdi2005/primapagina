require 'mediawiki_api'
require 'date'

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

pubblicati = client.query(list: :categorymembers, cmtitle: "Categoria:Notizie da prima pagina", cmsort: :timestamp, cmdir: :desc, cmlimit: 50)["query"]["categorymembers"]

# Rigetto cose non nel ns0 (eventuali errori)
pubblicati.reject! { |pubblicato| pubblicato["ns"] != 0 }

pubblicati.map do |pubblicato|
  content = client.query(prop: :revisions, rvprop: :content, titles: pubblicato["title"], rvlimit: 1)["query"]["pages"]["#{pubblicato["pageid"]}"]["revisions"][0]["*"]
  if content.match?(/{{data\|(\d{1,2} \w+ \d{4})\|(lunedì|martedì|mercoledì|giovedì|venerdì|sabato|domenica)}}/i)
    match = content.match(/{{data\|(\d{1,2} \w+ \d{4})\|(lunedì|martedì|mercoledì|giovedì|venerdì|sabato|domenica)}}/i)
    data = match[1]
    giorno = match[2]  
    pubblicato["with_luogo"] = false
  elsif content.match?(/{{luogodata\|luogo=([a-zA-ZÀ-ÖØ-öø-ÿ]+)\|1=(lunedì|martedì|mercoledì|giovedì|venerdì|sabato|domenica)\|data=(\d{1,2} \w+ \d{4})}}/i)
    match = content.match(/{{luogodata\|luogo=([a-zA-ZÀ-ÖØ-öø-ÿ]+)\|1=(lunedì|martedì|mercoledì|giovedì|venerdì|sabato|domenica)\|data=(\d{1,2} \w+ \d{4})}}/i)
    pubblicato["luogo"] = match[1]
    giorno = match[2]
    data = match[3]
    pubblicato["with_luogo"] = true
  elsif content.match?(/{{luogodata\|(lunedì|martedì|mercoledì|giovedì|venerdì|sabato|domenica)\|luogo=([a-zA-ZÀ-ÖØ-öø-ÿ]+)\|data=(\d{1,2} \w+ \d{4})}}/i)
    match = content.match(/{{luogodata\|(lunedì|martedì|mercoledì|giovedì|venerdì|sabato|domenica)\|luogo=([a-zA-ZÀ-ÖØ-öø-ÿ]+)\|data=(\d{1,2} \w+ \d{4})}}/i)
    pubblicato["luogo"] = match[2]
    giorno = match[1]
    data = match[3]
    pubblicato["with_luogo"] = true
  elsif content.match?(/{{data\|1=(\d{1,2} \w+ \d{4})\|2=(lunedì|martedì|mercoledì|giovedì|venerdì|sabato|domenica)}}/i)
    match = content.match(/{{data\|1=(\d{1,2} \w+ \d{4})\|2=(lunedì|martedì|mercoledì|giovedì|venerdì|sabato|domenica)}}/i)
    data = match[1]
    giorno = match[2]
    pubblicato["with_luogo"] = false
  else
    pubblicato["funzionante"] = false
    next
  end
  pubblicato["content"] = content
  pubblicato["match"] = match
  pubblicato["data"] = data
  pubblicato["giorno"] = giorno
  months = [["gennaio", "Jan"], ["febbraio", "Feb"], ["marzo", "Mar"], ["aprile", "Apr"], ["maggio", "May"], ["giugno", "Jun"], ["luglio", "Jul"], ["agosto", "Aug"], ["settembre", "Sep"], ["ottobre", "Oct"], ["novembre", "Nov"], ["dicembre", "Dec"]]
  months.each do |italian_month, english_month|
    if pubblicato["data"].match? italian_month      
      pubblicato["rubydate"] = DateTime.parse(pubblicato["data"].gsub(/#{italian_month}/, english_month))
    end
  end  
end

pubblicati = pubblicati.delete_if { |p| p["funzionante"] == false }

pubblicati = pubblicati.sort_by {|p| p["rubydate"]}.reverse.first(6)

# Lista del contenuto
list = []
svolgimento = 0

pubblicati.each do |pubblicato|
    svolgimento += 1

    puts "Svolgo le operazioni per #{pubblicato["title"]} - #{svolgimento}º articolo"

    content = pubblicato["content"]    
    data = pubblicato["data"]
    giorno = pubblicato["giorno"]

    estratto = client.query(prop: :extracts, exsentences: 2, exintro: 1, explaintext: 1, titles: pubblicato["title"])["query"]["pages"]["#{pubblicato["pageid"]}"]["extract"]
    if pubblicato["with_luogo"]
      estratto.gsub!("#{pubblicato["luogo"]}, #{giorno} #{data}", "").strip!
    else
      estratto.gsub!("#{giorno} #{data}", "").strip!
    end
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

    Questa pagina viene aggiornata automaticamente da un bot.
    
    Per far apparire gli articoli nella prima pagina, inserisci in essi la categoria [[Categoria:Notizie da prima pagina]]
    
    LE NOTIZIE COMINCIANO SOTTO GLI ASTERISCHI
    ************************************************************************-->
    </noinclude>\n")
puts "Finalizzo e pubblico"
client.edit(title: "Template:Pagina principale/Primo piano/Prima Pagina", text: list.join(""))