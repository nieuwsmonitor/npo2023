remotes::install_github('kasperwelbers/boolydict')
library(textdata)
library(boolydict)
library(amcat4r)
library(tidyverse)
library(googlesheets4)
library(sotu)
library(tidytext)



amcat4r::amcat_login("https://amcat4.labs.vu.nl/amcat")
aandacht <- amcat4r::query_documents("tk2023_radio_tv",
                           fields = c('_id', 'publisher','date','text', 'speakernum','start','end','won'),
                           max_pages = Inf, scroll='5m')
write_csv(aandacht, "results/tv_amcat.csv")


table(aandacht$publisher)

nu = aandacht|>
  mutate(date=as.Date(date))|>
  filter(date=="2023-11-07" & publisher=="WNL GOEDEMORGEN NEDERLAND - Goedemorgen Nederland")

head(op1)
op1|>
  group_by(.id)|>
  summarise(embedding=do.call(embedding))


data = aandacht|>
  distinct(.id, .keep_all = T)|>
  mutate(text = tolower(text))

head(data)

googlesheets4::gs4_deauth()
partijen <- read_sheet('https://docs.google.com/spreadsheets/d/1d3G1_y_HJP2Ik1v7rKrxeAXL4uCt5mLNgc8uC7vzQyI/edit#gid=0', sheet = 1)

tokens = data |>unnest_tokens(word, text)
head(tokens)

hits = tokens |> 
  dict_add(partijen, text_col = 'word', by_label='label', fill = 0) |>
  as_tibble()

colnames(hits)
hits2 = hits|>
  pivot_longer(`50Plus`:vvd)|>
  group_by(publisher,name)|>
  summarise(n=sum(value))|>
  mutate(perc=n/sum(n)*100)
  
head(hits2)
ggplot(hits2, aes(x=perc, y=name, fill=name)) + geom_col()+
  facet_grid(~publisher)






###### UPLOADEN HANDMATIG GECODEERDE SPREKERS #######

amcat4r::amcat_login("https://amcat4.labs.vu.nl/amcat")
wons=amcat4r::query_documents("tk2023_radio_tv",
                         fields = c('_id', 'won', 'speakernum'),
                         max_pages = Inf, scroll='5m')


googlesheets4::gs4_deauth()
docs <- googlesheets4::read_sheet('https://docs.google.com/spreadsheets/d/10qSZponLZ06Rv5KOq83pn7vUpV4Fh5LdVlxhF9t6rgE/edit#gid=0', sheet = 1)

library(tidyverse)

update = wons |> 
  filter(won %in% docs$won) |>
  left_join(docs) |>
  select(.id, spreker=speaker_name)



nullen=namen|>
  left_join(wons) |>
  select(.id, spreker=speaker_name)

namen=docs|>
  left_join(wons) |>
  select(.id, spreker=speaker_name)


amcat4r::update_documents("tk2023_radio_tv", documents = update)
