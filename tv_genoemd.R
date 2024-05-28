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
write_csv(aandacht, "results/tv_amcat2.csv")

tv = read_csv("results/tv_amcat2.csv")

tv2 = tv|>
  select(.id,publisher,won)

write_csv(tv2,"results/tv_meta.csv")


table(tv2$publisher)

head(tv)
check=tv|>
  distinct(publisher, won, .keep_all = T)|>
  group_by(publisher, date)|>
  summarise(n=n())

table(check$date, check$publisher)
tv3 = tv|>
  distinct(.id, .keep_all = T)|>
  mutate(text = tolower(text))


googlesheets4::gs4_deauth()
partijen <- read_sheet('https://docs.google.com/spreadsheets/d/1d3G1_y_HJP2Ik1v7rKrxeAXL4uCt5mLNgc8uC7vzQyI/edit#gid=0', sheet = 1)

partij= read_csv("results/party_queries.csv")
tokens = tv3 |>unnest_tokens(word, text)

head(tokens)

hits = tokens |> 
  dict_add(partij, text_col = 'word', by_label='label', fill = 0) |>
  as_tibble()

colnames(hits)
hits2 = hits|>
  pivot_longer(BBB:Volt)|>
  group_by(name)|>
  summarise(n=sum(value))|>
  mutate(perc=n/sum(n)*100)

sum(hits2$n)
library(ggthemes)
  
head(hits2)
ggplot(hits2, aes(x=perc, y=reorder(name,perc), fill=name)) + geom_col()+
  geom_text(data=filter(hits2, perc > 0), aes(x=0, label=round(perc,1)),hjust=-0.5)+
  theme_classic() +theme(legend.position = "")+
  xlab("Percentage")+
  ylab("")

#####PER PROGRAMMA

hits2 = hits|>
  mutate(publisher2 = case_when(str_detect(publisher, "BUITENHOF") ~ "Buitenhof",
                                str_detect(publisher, "WNL") ~ "WNL",
                                str_detect(publisher, "NOS") ~ "NOS",
                                str_detect(publisher, "Op1") ~ "OP1",
                                str_detect(publisher, "EENVANDAAG") ~ "EenVandaag",
                                str_detect(publisher, "EenVandaag") ~ "EenVandaag",
                                T ~ publisher))|>
  pivot_longer(BBB:Volt)|>
  group_by(publisher2, name)|>
  summarise(n=sum(value))|>
  mutate(perc=n/sum(n)*100)

table(hits$publisher)
head(hits2)
ggplot(hits2, aes(x=perc, y=reorder(name,perc), fill=name)) + geom_col()+
  geom_text(data=filter(hits2, perc > 4), aes(x=0, label=round(perc,1)),hjust=-.2)+
  theme_classic() +theme(legend.position = "")+
  xlab("Percentage")+
  ylab("")+
  facet_grid(~publisher2)


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
