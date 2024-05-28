library(tidyverse)
library(amcat4r)


d = read_csv("results/tv_voices.csv")
d  

table(tv2$won %in% d$won)

tijd_per_won = d|>
  group_by(won)|>
  summarise(start=min(start),
            end=max(end))|>
  mutate(tijd=end-start)|>
  select(won, tijd)

meta = read_csv("results/tv_amcat.csv") |> select(.id, won, date, publisher)
meta2=meta|>
  distinct(won, .keep_all = T)

head(d)

tijd_per_won=d|>
  group_by(won,majority_speaker)|>
  mutate(spreekbeurt=max(end)-min(start))|>
  group_by(won)
  
tijd_per_won

dtot=d|>
  filter(! is.na(majority_speaker) & majority_speaker != "Edson Olf" & majority_speaker != "Wybren van Haga" )|>
  mutate(spreektijd=end-start)|>
  select(won, majority_speaker, spreektijd)|>
  group_by(majority_speaker)|>
  summarise(spreektijd=sum(spreektijd))|>
  mutate(perc=spreektijd/sum(spreektijd)*100)|>
  arrange(-perc) |> 
  select(-perc) |>
  mutate(perc=spreektijd/sum(spreektijd)*100)


dtot
ggplot(dtot, aes(x=perc, y=reorder(majority_speaker,perc), fill=majority_speaker)) + geom_col()+
  geom_text(data=filter(dtot, perc > 0), aes(x=0, label=round(perc,1)),hjust=-.1)+
  theme_classic() +theme(legend.position = "")+
  xlab("Percentage")+
  ylab("")



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


mutate(publisher2= case_when(str_detect(publisher,"BUITENHOF") ~ "Buitenhof",
                             str_detect(publisher, "NOS Journaal") ~ "NOS Journaal",
                             str_detect(publisher, "EENVANDAAG") ~ "EenVandaag",
                             str_detect(publisher,"Op1") ~ "Op1",
                             str_detect(publisher,"Khalid") ~ "Khalid & Sophie",
                             str_detect(publisher,"NIEUWSUUR") ~ "Nieuwsuur",
                             str_detect(publisher,"EenVandaag") ~ "Debat EenVandaag",
                             str_detect(publisher,"Nederland Kiest") ~ "Debat NOS",
                             str_detect(publisher,"WNL OP ZONDAG") ~ "WNL op Zondag",
                             T ~ "Goedemorgen NL"))|>
  filter(! publisher2 %in% c("Buitenhof","WNL op Zondag", "Debat EenVandaag", "Debat NOS"))
  

table(d4$publisher2)

d4 = d |>
  filter(! is.na(majority_speaker) & majority_speaker != "Edson Olf" & majority_speaker != "Wybren van Haga" )|>
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



