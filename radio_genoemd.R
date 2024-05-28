remotes::install_github('kasperwelbers/boolydict')
library(textdata)
library(boolydict)
library(amcat4r)
library(tidyverse)
library(googlesheets4)
library(sotu)
library(tidytext)


#journaal2023-11-08 - baudet
#2 nov - eerdmans
#16 nov omtzigt
#3nov van baarle

amcat4r::amcat_login("https://amcat4.labs.vu.nl/amcat")
aandacht <- amcat4r::query_documents("tk2023_radio",
                           fields = c('_id', 'publisher','date','text', 'speakernum','start','end','won'),
                           max_pages = Inf, scroll='5m')

radio = read_csv("results/radio_amcat.csv")
table(radio$publisher)

radio3=radio|>
  mutate(pub = paste0(publisher,date))|>
  filter(pub %in% c("journaal2023-11-07", "sven2023-11-10","ditisdedag2023-11-07"))

write_csv(radio3,"results/radio_transcripten_politici10.csv")
check=radio|>
  distinct(date,publisher, .keep_all = T)|>
  group_by(publisher)|>
  summarise(n=n())

check


data = aandacht|>
  distinct(.id, .keep_all = T)|>
  mutate(text = tolower(text))

head(data)

googlesheets4::gs4_deauth()
partijen <- read_sheet('https://docs.google.com/spreadsheets/d/1d3G1_y_HJP2Ik1v7rKrxeAXL4uCt5mLNgc8uC7vzQyI/edit#gid=0', sheet = 1)

tokens = radio |>unnest_tokens(word, text)
head(tokens)

hits = tokens |> 
  dict_add(partijen, text_col = 'word', by_label='label', fill = 0) |>
  as_tibble()

h2=hits|> pivot_longer(BBB:Volt)|>
  group_by(.id, name)|>
  summarise(n=sum(value))|>
  arrange(-n)|>
  group_by(name)|>
  summarize(n=n())|>
  filter(name=="JA21")|>
  arrange(-n)

aandacht2=aandacht|>
  filter(.id %in% h2$.id)

write_csv(aandacht2, "speakers_radio.csv")

head(hits)
colnames(hits)
hits2 = hits|>
  pivot_longer(BBB:Volt)|>
  group_by(name)|>
  summarise(n=sum(value))|>
  mutate(perc=n/sum(n)*100)
  

ggplot(hits2, aes(x=perc, y=reorder(name,perc), fill=name)) + geom_col()+
  geom_text(data=filter(hits2, perc > 1), aes(x=0, label=round(perc,1)),hjust=-0.5)+
  theme_classic() +theme(legend.position = "")+
  xlab("Percentage")+
  ylab("")


table(hits$publisher)


hits2 = hits|>
  mutate(publisher2=ifelse(publisher %in% c("ditisdedag","eenvandaag","journaal",
                                            "nieuwsbv","nieuwsenco", "oog",
                                            "spraakmakers","sven","villa","vroeg"), "Dagelijks","Wekelijks"))|>
  pivot_longer(BBB:VVD)|>
  group_by(publisher2,name)|>
  summarise(n=sum(value))|>
  mutate(perc=n/sum(n)*100)


ggplot(hits2, aes(x=perc, y=reorder(name,perc), fill=name)) + geom_col()+
  geom_text(data=filter(hits2, perc > 4), aes(x=0, label=round(perc,1)),hjust=-0.1)+
  theme_classic() +theme(legend.position = "")+
  xlab("Percentage")+
  ylab("")+
  facet_grid(~publisher2)


###PER PROGRAMMA


hits2 = hits|>
  mutate(publisher2=ifelse(publisher %in% c("ditisdedag","eenvandaag","journaal",
                                            "nieuwsbv","nieuwsenco", "oog",
                                            "spraakmakers","sven","villa","vroeg"), "Dagelijks","Wekelijks"))|>
  filter(publisher2 !="Dagelijks" & publisher !="pointer")|>
  pivot_longer(BBB:VVD)|>
  group_by(publisher,name)|>
  summarise(n=sum(value))|>
  mutate(perc=n/sum(n)*100)


ggplot(hits2, aes(x=perc, y=reorder(name,perc), fill=name)) + geom_col()+
  geom_text(data=filter(hits2, perc > 5), aes(x=0, label=round(perc,0)),hjust=0)+
  theme_classic() +theme(legend.position = "")+
  xlab("Percentage")+
  ylab("")+
  facet_grid(~publisher)
