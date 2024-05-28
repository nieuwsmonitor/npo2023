library(boolydict)
library(amcat4r)
library(tidyverse)
library(googlesheets4)


meta_web = readRDS("data/tk2023_websites.rds")|>
  rename(doc_id=.id)|>
  mutate(doc_id=as.character(doc_id))|>
  mutate(week = as.character(lubridate::isoweek(date)))|>
  filter(publisher=="NOS.nl")|>
  mutate(week = case_when(week=="44" ~ "Week 44",
                          week=="45" ~ "Week 45",
                          week=="46" ~ "Week 46",
                          T ~ "Week 47"))


succes_web = read_csv("results/succes_websites.csv")|>
  mutate(frame="succes")
conflict_web = read_csv("results/conflict_websites.csv")|>
  mutate(frame="conflict")
issue_web = read_csv("results/issue_websites.csv")|>
  mutate(frame="issue")

web = succes_web|>
  bind_rows(conflict_web, issue_web)|>
  filter(prediction=="issue_yes")|>
  mutate(frame = case_when(frame=="issue" ~ "Issue positions",
                           frame=="conflict" ~ "Conflict news",
                           frame=="succes" ~ "Success & failure"))

  
web_pw=web|>
  left_join(meta_web)|>
  group_by(week,frame)|>
  summarise(n=n())|>
  mutate(perc=n/sum(n)*100)

ggplot(web_pw, aes(x=perc, y=frame, fill=frame)) + geom_col()+
  geom_text( aes(x=0, label=round(perc,0)),hjust=0)+
  theme_classic() +theme(legend.position = "")+
  xlab("Percentage")+
  ylab("")+
  facet_grid(~week)


googlesheets4::gs4_deauth()
partijen <- read_sheet('https://docs.google.com/spreadsheets/d/1d3G1_y_HJP2Ik1v7rKrxeAXL4uCt5mLNgc8uC7vzQyI/edit#gid=0', sheet = 1)

web_pp = web |>
  dict_add(partijen, text_col = 'text_prepared', by_label='label', fill = 0)|>
  select(doc_id, sent_id, frame, prediction,score, BBB:Volt)|>
  pivot_longer(BBB:Volt, names_to = 'party')|>
  left_join(meta_web)




web_pp2=web_pp|>
  filter(party !="Overig")|>
  group_by(party,frame)|>
  summarise(n=sum(value))|>
  mutate(perc=n/sum(n)*100)


ggplot(web_pp2, aes(x = party, y = perc, fill = frame)) +
  geom_col(position="stack") +
  geom_text(data=filter(web_pp2, perc > 0),aes(label = round(perc,0)), position = position_stack(vjust = 0.5), colour = "black")+
  theme_classic()+
  theme(axis.title.x=element_blank(),
        axis.title.y=element_blank())

####RADIO


issue_radio = read_csv("results/issue_radio.csv")|>
  mutate(frame="issue")

conflict_radio = read_csv("results/conflict_radio.csv")|>
  mutate(frame="conflict")

succes_radio = read_csv("results/succes_radio.csv")|>
  mutate(frame="succes")

radio=issue_radio|>
  bind_rows(conflict_radio,succes_radio)|>
  filter(prediction=="issue_yes")
  

meta_radio = readRDS("data/tk2023_radio.rds")|>
  select(.id, title,speakernum, date, publisher)|>
  rename(doc_id=.id)|>
  mutate(doc_id=as.character(doc_id))|>
  mutate(date=as.Date(date))|>
  mutate(week = as.character(lubridate::isoweek(date)))|>
  filter( publisher != "pointer")|>
  mutate(week = case_when(week=="44" ~ "Week 44",
                          week=="45" ~ "Week 45",
                          week=="46" ~ "Week 46",
                          T ~ "Week 47"))|>
  mutate(publisher2=ifelse(publisher %in% c("ditisdedag","eenvandaag","journaal",
                                            "nieuwsbv","nieuwsenco", "oog",
                                            "spraakmakers","sven","villa","vroeg"), "Dagelijks","Wekelijks"))
  


googlesheets4::gs4_deauth()
partijen <- read_sheet('https://docs.google.com/spreadsheets/d/1d3G1_y_HJP2Ik1v7rKrxeAXL4uCt5mLNgc8uC7vzQyI/edit#gid=0', sheet = 1)

radio2 = radio |>
  dict_add(partijen, text_col = 'text_prepared', by_label='label', fill = 0)|>
  select(doc_id, sent_id, frame, prediction,score, BBB:Volt)|>
  pivot_longer(BBB:Volt, names_to = 'party')|>
  left_join(meta_radio)|>
  mutate(frame = case_when(frame=="issue" ~ "Issue positions",
                           frame=="conflict" ~ "Conflict news",
                           frame=="succes" ~ "Success & failure"))
  

  
radio1 = radio |>
  filter( radio$doc_id %in% meta_radio$doc_id)|>
  left_join(meta_radio)|>
  mutate(frame = case_when(frame=="issue" ~ "Issue positions",
                           frame=="conflict" ~ "Conflict news",
                           frame=="succes" ~ "Success & failure"))|>
  group_by(week,frame)|>
  summarise(n=n())|>
  mutate(perc=n/sum(n)*100)

ggplot(radio1, aes(x=perc, y=frame, fill=frame)) + geom_col()+
  geom_text( aes(x=0, label=round(perc,0)),hjust=0)+
  theme_classic() +theme(legend.position = "")+
  xlab("Percentage")+
  ylab("")+
  facet_grid(~week)


radio4=radio2|>
  filter(publisher2=="Dagelijks")|>
  group_by(publisher,frame)|>
  summarise(n=n())|>
  mutate(perc=n/sum(n)*100)

ggplot(radio4, aes(x=perc, y=frame, fill=frame)) + geom_col()+
  geom_text( aes(x=0, label=round(perc,0)),hjust=0)+
  theme_classic() +theme(legend.position = "")+
  xlab("Percentage")+
  ylab("")+
  facet_grid(~publisher)

radio5=radio2|>
  filter(party != "Overig")|>
  group_by(party,frame)|>
  summarise(n=sum(value))|>
  mutate(perc=n/sum(n)*100)



ggplot(radio5, aes(x = party, y = perc, fill = frame)) +
  geom_col(position="stack") +
  geom_text(data=filter(radio5, perc > 0),aes(label = round(perc,0)), position = position_stack(vjust = 0.5), colour = "black")+
  theme_classic()+
  theme(axis.title.x=element_blank(),
        axis.title.y=element_blank())

######TELEVISIE


issue_tv = read_csv("results/issue_tv.csv")|>
  mutate(frame="issue")

conflict_tv = read_csv("results/conflict_tv.csv")|>
  mutate(frame="conflict")

succes_tv = read_csv("results/succes_tv.csv")|>
  mutate(frame="succes")
         
         

tv=issue_tv|>
  bind_rows(conflict_tv,succes_tv)|>
  filter(prediction=="issue_yes")


meta_tv = readRDS("data/tk2023_tv.rds")|>
  rename(doc_id=.id)|>
  mutate(doc_id=as.character(doc_id))|>
  mutate(date=as.Date(date))|>
  mutate(week = as.character(lubridate::isoweek(date)))|>
  mutate(week = case_when(week=="44" ~ "Week 44",
                          week=="45" ~ "Week 45",
                          week=="46" ~ "Week 46",
                          T ~ "Week 47"))|>
  mutate(publisher2 = case_when(str_detect(publisher, "BUITENHOF") ~ "Buitenhof",
                                str_detect(publisher, "WNL") ~ "WNL",
                                str_detect(publisher, "NOS") ~ "NOS",
                                str_detect(publisher, "Op1") ~ "OP1",
                                str_detect(publisher, "EENVANDAAG") ~ "EenVandaag",
                                str_detect(publisher, "EenVandaag") ~ "EenVandaag",
                                T ~ publisher))

  
tv1 = tv |>
  left_join(meta_tv)|>
  mutate(frame = case_when(frame=="issue" ~ "Issue positions",
                           frame=="conflict" ~ "Conflict news",
                           frame=="succes" ~ "Success & failure"))|>
  group_by(week,frame)|>
  summarise(n=n())|>
  mutate(perc=n/sum(n)*100)

ggplot(tv1, aes(x=perc, y=frame, fill=frame)) + geom_col()+
  geom_text( aes(x=0, label=round(perc,0)),hjust=0)+
  theme_classic() +theme(legend.position = "")+
  xlab("Percentage")+
  ylab("")+
  facet_grid(~week)



googlesheets4::gs4_deauth()
partijen <- read_sheet('https://docs.google.com/spreadsheets/d/1d3G1_y_HJP2Ik1v7rKrxeAXL4uCt5mLNgc8uC7vzQyI/edit#gid=0', sheet = 1)

tv2 = tv |>
  dict_add(partijen, text_col = 'text_prepared', by_label='label', fill = 0)|>
  select(doc_id, sent_id, frame, prediction,score, BBB:Volt)|>
  pivot_longer(BBB:Volt, names_to = 'party')|>
  left_join(meta_tv)|>
  mutate(frame = case_when(frame=="issue" ~ "Issue standpunten",
                           frame=="conflict" ~ "Steun en kritiek",
                           frame=="succes" ~ "Succes en falen"))


tv3=tv2|>
 # filter(party != "Overig")|>
  group_by(party,frame)|>
  summarise(n=sum(value))|>
  mutate(perc=n/sum(n)*100)

ggplot(tv3, aes(x = party, y = perc, fill = frame)) +
  geom_col(position="stack") +
  geom_text(data=filter(tv3, perc > 0),aes(label = round(perc,0)), position = position_stack(vjust = 0.5), colour = "black")+
  theme_classic()+
  theme(axis.title.x=element_blank(),
        axis.title.y=element_blank())

