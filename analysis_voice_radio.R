library(tidyverse)
library(amcat4r)


d = read_csv("results/voices_radio.csv")
d  

dtot=d|>
  filter(! is.na(majority_speaker) & majority_speaker != "Edson Olf")|>
  rename(person=majority_speaker)|>
  mutate(person = case_match(person, "timmermans" ~ "Frans Timmermans",
                             "vanderplas" ~ "Caroline van der Plas",
                             "omtzigt" ~ "Pieter Omtzigt",
                             "bontenbal" ~ "Henri Bontenbal",
                             "yesilgoz" ~ "Dilan Yeşilgöz",
                             "jetten" ~ "Rob Jetten",
                             "marijnissen" ~ "Lilian Marijnissen",
                             "bikker" ~ "Mirjam Bikker",
                             "eerdmans" ~ "Joost Eerdmans",
                             "ouwehand" ~ "Esther Ouwehand",
                             "dassen" ~ "Laurens Dassen",
                             "wilders" ~ "Geert Wilders",
                             "vanbaarle" ~ "Stephan van Baarle",
                             "baudet" ~ "Thierry Baudet",
                             "stoffer" ~ "Chris Stoffer"))|>
  mutate(spreektijd=end-start)|>
  select(won, person, spreektijd)|>
  group_by(person)|>
  summarise(spreektijd=sum(spreektijd))|>
  mutate(perc=spreektijd/sum(spreektijd)*100)|>
  arrange(-perc) |> 
  select(-perc) |>
  mutate(perc=spreektijd/sum(spreektijd)*100)


dtot
ggplot(dtot, aes(x=perc, y=reorder(person,perc), fill=person)) + geom_col()+
  geom_text(data=filter(dtot, perc > 0), aes(x=0, label=round(perc,1)),hjust=-.1)+
  theme_classic() +theme(legend.position = "")+
  xlab("Percentage")+
  ylab("")


hits2 = d|>
  mutate(publisher = str_remove_all(won, "2023\\d{4}"))|>
  mutate(publisher2=ifelse(publisher %in% c("ditisdedag","eenvandaag","journaal",
                                            "nieuwsbv","nieuwsenco", "oog",
                                            "spraakmakers","sven","villa","vroeg"), "Dagelijks","Wekelijks"))|>
  rename(person=majority_speaker)|>
  mutate(person = case_match(person, "timmermans" ~ "Frans Timmermans",
                             "vanderplas" ~ "Caroline van der Plas",
                             "omtzigt" ~ "Pieter Omtzigt",
                             "bontenbal" ~ "Henri Bontenbal",
                             "yesilgoz" ~ "Dilan Yeşilgöz",
                             "jetten" ~ "Rob Jetten",
                             "marijnissen" ~ "Lilian Marijnissen",
                             "bikker" ~ "Mirjam Bikker",
                             "eerdmans" ~ "Joost Eerdmans",
                             "ouwehand" ~ "Esther Ouwehand",
                             "dassen" ~ "Laurens Dassen",
                             "wilders" ~ "Geert Wilders",
                             "vanbaarle" ~ "Stephan van Baarle",
                             "baudet" ~ "Thierry Baudet",
                             "stoffer" ~ "Chris Stoffer"))|>
  filter(publisher2 !="Dagelijks" & publisher != "pointer")|>
  mutate(spreektijd=end-start)|>
  select(won, publisher, person, spreektijd)|>
  group_by(publisher,person)|>
  filter(! is.na(person) )|>
  summarise(spreektijd=sum(spreektijd))|>
  mutate(perc=spreektijd/sum(spreektijd)*100)


ggplot(hits2, aes(x=perc, y=reorder(person,perc), fill=person)) + geom_col()+
  geom_text(data=filter(hits2, perc > 5), aes(x=0, label=round(perc,0)),hjust=0)+
  theme_classic() +theme(legend.position = "")+
  xlab("Percentage")+
  ylab("")+
  facet_grid(~publisher)


table(d4$publisher2)

d4 = d |>
  filter(! is.na(majority_speaker) & majority_speaker != "Edson Olf")|>
  left_join(publishers)|>
  mutate(spreektijd=end-start)|>
  select(won, publisher2, majority_speaker, spreektijd)|>
  group_by(publisher2,majority_speaker)|>
  summarise(spreektijd=sum(spreektijd))|>
  mutate(perc=spreektijd/sum(spreektijd)*100)


table(d4$publisher2)

ggplot(d4, aes(x=perc, y=reorder(majority_speaker,perc), fill=majority_speaker)) + geom_col()+
  geom_text(data=filter(d4, perc > 4), aes(x=0, label=round(perc,1)),hjust=-.1)+
  theme_classic() +theme(legend.position = "")+
  xlab("Percentage")+
  ylab("")+
  facet_grid(~publisher2)




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


################## RADIO #########################



