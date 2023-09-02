require 'mediawiki_api'
require 'wikinotizie'
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
  
  parsed = Wikinotizie.parse(content)

  if parsed == false
    puts "Impossibile processare #{pubblicato["title"]}"
    pubblicati.delete(pubblicato)
  else
    pubblicato["content"] = parsed[0]
    pubblicato["match"] = parsed[1]
    pubblicato["data"] = parsed[2]
    pubblicato["giorno"] = parsed[3]
    pubblicato["rubydate"] = parsed[4]
  end
end

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