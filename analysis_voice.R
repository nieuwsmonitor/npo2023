library(tidyverse)




d = read_csv("voices2.csv")|>
  

tijd_per_won = d|>
  group_by(won)|>
  summarise(start=min(start),
            end=max(end))|>
  mutate(tijd=end-start)|>
  select(won, tijd)

amcat4r::amcat_login("https://amcat4.labs.vu.nl/amcat")
meta=amcat4r::query_documents("tk2023_radio_tv",
                              fields = c('_id', 'won', 'publisher'),
                              max_pages = Inf, scroll='5m')


check = d|>
  filter(won=="WON02443345")

d|>
  filter(! is.na(majority_speaker ))|>
  mutate(spreektijd=end-start)|>
  select(won, majority_speaker, spreektijd)|>
  group_by(won, majority_speaker)|>
  summarise(spreektijd=sum(spreektijd))|>
  left_join(tijd_per_won)|>
  mutate(perc=spreektijd/tijd*100)

publishers=meta|>
  select(-.id) |>
  unique()|>
  mutate(publisher2 = case_when(str_detect(publisher, "BUITENHOF") ~ "Buitenhof",
                               str_detect(publisher, "WNL") ~ "WNL",
                               str_detect(publisher, "NOS") ~ "NOS",
                               str_detect(publisher, "Op1") ~ "OP1",
                               str_detect(publisher, "EENVANDAAG") ~ "EenVandaag",
                               str_detect(publisher, "EenVandaag") ~ "EenVandaag",
                               T ~ publisher))

table(publishers$publisher)

d3=d|>
  filter(! is.na(majority_speaker))|>
  left_join(publishers)|>
  mutate(spreektijd=end-start)|>
  select(won, publisher2, majority_speaker, spreektijd)|>
  group_by(publisher2,majority_speaker)|>
  summarise(spreektijd=sum(spreektijd))|>
  mutate(perc=spreektijd/sum(spreektijd)*100)|>
  arrange(-perc) |> 
  select(-perc) |>
  pivot_wider(names_from=publisher2, values_from=spreektijd, values_fill = 0)



d |> filter(won == "WON02439500", majority_speaker == "Henri Bontenbal") 


d4=d|>
  filter(! is.na(majority_speaker ))|>
  left_join(publishers)|>
  filter(publisher=="WNL GOEDEMORGEN NEDERLAND - Goedemorgen Nederland" & majority_speaker=="Henri Bontenbal")
  

d|>
  filter(! is.na(majority_speaker ))|>
  left_join(publishers)|>
  filter(! publisher %in% c("BUITENHOF", "WNL OP ZONDAG"))|>
  filter(publisher2=="NOS")|>
  mutate(spreektijd=end-start)|>
  select(won, publisher2, majority_speaker, spreektijd)|>
  group_by(majority_speaker)|>
  summarise(spreektijd=sum(spreektijd))|>
  mutate(perc=spreektijd/sum(spreektijd)*100)|>
  arrange(-perc)


d|>
  filter(! is.na(majority_speaker ))|>
  left_join(publishers)|>
  filter(! publisher %in% c("BUITENHOF", "WNL OP ZONDAG", "NOS Nederland Kiest: Het Debat" , "EenVandaag - Verkiezingsdebat"))|>
  mutate(spreektijd=end-start)|>
  select(won, publisher2, majority_speaker, spreektijd)|>
  group_by(majority_speaker)|>
  summarise(spreektijd=sum(spreektijd))|>
  mutate(perc=spreektijd/sum(spreektijd)*100)|>
  arrange(-perc)

