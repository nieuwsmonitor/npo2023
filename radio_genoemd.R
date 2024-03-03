remotes::install_github('kasperwelbers/boolydict')
library(textdata)
library(boolydict)
library(amcat4r)
library(tidyverse)
library(googlesheets4)
library(sotu)
library(tidytext)



amcat4r::amcat_login("https://amcat4.labs.vu.nl/amcat")
aandacht <- amcat4r::query_documents("tk2023_radio",
                           fields = c('_id', 'publisher','date','text', 'speakernum','start','end'),
                           max_pages = Inf, scroll='5m')
write_csv(aandacht, "results/radio_amcat.csv")

aandacht = read_csv("results/radio_amcat.csv")
table(aandacht$publisher)


head(aandacht)
op1|>
  group_by(.id)|>
  summarise(embedding=do.call(embedding))


data = aandacht|>
  distinct(.id, .keep_all = T)|>
  mutate(text = tolower(text))

head(data)

googlesheets4::gs4_deauth()
partijen <- read_sheet('https://docs.google.com/spreadsheets/d/1d3G1_y_HJP2Ik1v7rKrxeAXL4uCt5mLNgc8uC7vzQyI/edit#gid=0', sheet = 1)

partijen=read_csv("results/party_queries.csv")


tokens = data |>unnest_tokens(word, text)
head(tokens)

hits = tokens |> 
  dict_add(partijen, text_col = 'word', by_label='label', fill = 0) |>
  as_tibble()

colnames(hits)
hits2 = hits|>
  pivot_longer(BBB:VVD)|>
  group_by(publisher,name)|>
  summarise(n=sum(value))|>
  mutate(perc=n/sum(n)*100)



ggplot(hits2, aes(x=perc, y=reorder(name, perc), fill=name)) + geom_col()+
  geom_text(aes(label=round(perc,1)),vjust=1,hjust=1)

ggtheme
  
head(hits2)
ggplot(hits2, aes(x=perc, y=name, fill=name)) + geom_col()+
  facet_grid(~publisher)


hits2 = hits|>
  pivot_longer(BBB:VVD)|>
  group_by(name)|>
  summarise(n=sum(value))|>
  mutate(perc=n/sum(n)*100)

head(hits2)
ggplot(hits2, aes(x=perc, y=name, fill=name)) + geom_col()+
  facet_grid(~publisher)

table(data$publisher)

hits2=hits|>
  mutate(publisher2= ifelse(publisher %in% c("ditisdedag","journaal","eenvandaag","nieuwsbv",
                                            "nieuwsenco","oog","spraakmakers","vroeg","sven","villa"),"dagelijks","wekelijks"))|>
  pivot_longer(BBB:VVD)|>
  group_by(publisher2,name)|>
  summarise(n=sum(value))|>
  mutate(perc=n/sum(n)*100)


ggplot(hits2, aes(x=perc, y=reorder(name, perc), fill=name)) + geom_col()+
  geom_text(aes(label=round(perc,1)),vjust=1,hjust=1)+
  facet_grid(~publisher2)

table(data$publisher2)

hits2=hits|>
  mutate(publisher2= ifelse(publisher %in% c("ditisdedag","journaal","eenvandaag","nieuwsbv",
                                             "nieuwsenco","oog","spraakmakers","vroeg","sven","villa"),"dagelijks","wekelijks"))|>
  filter(publisher2=="wekelijks")|>
  pivot_longer(BBB:VVD)|>
  group_by(publisher,name)|>
  summarise(n=sum(value))|>
  mutate(perc=n/sum(n)*100)


ggplot(hits2, aes(x=perc, y=reorder(name, perc), fill=name)) + geom_col()+
  geom_text(aes(label=round(perc,1)),vjust=1,hjust=1)+
  facet_grid(~publisher)

