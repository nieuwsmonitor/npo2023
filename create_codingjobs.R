library(annotinder)
library(tidyverse)

#connecting to annotinder
annotinder::backend_connect("https://uva-climate.up.railway.app", username="nelruigrok@nieuwsmonitor.org", .password = "test")


#read all sentences
d = read_csv("data/intermediate/units_tk2023.csv")
d = d|>
  mutate(unit_id2 = str_extract(unit_id,"\\w+-\\d+"))

head(d)
#coded sentences first trial CAP classification
#download from annotinder single job
coded = read_csv("data/coded_npo.csv")|>
  filter(variable=="issue position" & label_issue =="Ja")|>
  filter(! sent_id %in% c$unit_id)|>
  distinct(sent_id, .keep_all = T)


d6=sample_n(d5,100)
d5 = d|>
  filter(unit_id2 %in% coded$sent_id)|>
  distinct(unit_id2, .keep_all = T)


id = 282
c = download_annotations(id)
head(c)


d3=d|>
  filter(actor != "Overig")|>
  filter(! unit_id2 %in% c$unit_id)|>
  distinct(unit_id2, .keep_all = T )

d4=sample_n(d3,50)
# Create the units for annotinder including the data
units = create_units(d6, id = 'unit_id', set_text('text_hl', text_hl, bold=T, before = before, after =after )) 
class(units)

topic = question('topic', 'Wat is het onderwerp van deze tekst?', codes = c('Defensie', 'Gezondheids (zorg)', 'Boeren platteland', 
                                                                            'Beter Bestuur', 'Sociale zekerheid', 'Werk(gelegenheid)',
                                                                            'Investeren infrastructuur','Immigratie','Burgerrechten',
                                                                            'Internat.recht en ontw. samenwerking','Investeren in onderwijs en wetenschap', 
                                                                            'Investeren in Cultuur','Gezondh.zorg en welzijn','Overheidsfin. op orde (belastingen)',
                                                                            'Natuur en Klimaat','Woning(bouw)','Criminaliteits bestrijding veiligheid','Europese Unie',
                                                                            'Ondernemers klimaat', 'Ander/geen onderwerp'))

position = question('position', 'Is de actor voor, neutraal of tegen het onderwerp?', codes = c('Voor',
                                                                                                'Neutraal',
                                                                                                'Tegen'))

quality = question('quality', 'Stond er in deze zin nog een issuepositie van deze actor?', codes = c('Ja', 'Nee'))
codebook = create_codebook(topic=topic,position=position, quality=quality)

# Job uploaden naar de server
annotinder::backend_connect("https://uva-climate.up.railway.app", username="nelruigrok@nieuwsmonitor.org", .password = "test")

jobid = annotinder::upload_job("betrouwbaarheid", units, codebook)

url = glue::glue('https://uva-climate.netlify.app/?host=https%3A%2F%2Fuva-climate.up.railway.app&job_id={jobid}')
print(url)
browseURL(url)

write_csv(d2, "~/tmp/test.csv")
