remotes::install_github('kasperwelbers/annotiner')
library(textdata)
library(boolydict)
library(amcat4r)
library(tidyverse)
library(googlesheets4)
library(sotu)
library(tidytext)



amcat4r::amcat_login("https://amcat4.labs.vu.nl/amcat")


data=amcat4r::query_documents("npo_tk2023",
                              fields = c('_id', 'date', 'publisher', 'title','text'),
                              max_pages = Inf, scroll='5m')|>
  filter(publisher=="NOS.nl", date>="2023-11-01" & date<="2023-11-22")


data= read_csv("results/websites_amcat.csv")

googlesheets4::gs4_deauth()
partijen <- read_sheet('https://docs.google.com/spreadsheets/d/1d3G1_y_HJP2Ik1v7rKrxeAXL4uCt5mLNgc8uC7vzQyI/edit#gid=0', sheet = "politici")

partijen = read_csv("results/party_queries.csv")


hits = data |> 
  dict_add(partijen, text_col = 'text', by_label='label', fill = 0) |>
  as_tibble()

head(hits)


hits2 = hits|>
  pivot_longer(baudet: yesilgoz)|>
  group_by(name)|>
  summarise(n=sum(value))|>
  mutate(perc=n/sum(n)*100)|>
  arrange(-perc)


ggplot(hits2, aes(x=perc, y=name, fill=name)) + geom_col() 


hits2 = hits|>
  mutate(week = lubridate::week(date))|>
  pivot_longer(baudet: yesilgoz)|>
  group_by(week,name)|>
  summarise(n=sum(value))|>
  mutate(perc=n/sum(n)*100)|>
  arrange(-perc)
  

ggplot(hits2, aes(x=perc, y=name, fill=name)) + geom_col() +
  facet_grid(~week)


partijen <- read_sheet('https://docs.google.com/spreadsheets/d/1d3G1_y_HJP2Ik1v7rKrxeAXL4uCt5mLNgc8uC7vzQyI/edit#gid=0', sheet = "Sheet7")


tv=tv|>
  mutate(medium="TV")

radio=radio|>
  mutate(medium="Radio")
data2=data|>
  mutate(medium="Website")|>
  bind_rows(tv,radio)

hits = data2 |> 
  dict_add(partijen, text_col = 'text', by_label='label', fill = 0) |>
  as_tibble()

d3=hits|>
  mutate(date=as.Date(date))|>
  mutate(week2=floor_date(date,'week'),
         Peilingen = ifelse(Peilingen>0,1,Peilingen))|>
  mutate(Peilingen=ifelse(is.na(Peilingen),0,Peilingen))|>
  group_by(date, Peilingen)|>
  summarise(n=n())|>
  mutate(perc=n/sum(n)*100)|>
  filter(Peilingen==1)

ggplot(d3, aes(x=date, y=n)) +
  geom_line(color="red")+ 
  theme_classic() +theme(legend.position = "")+
  xlab("")+
  ylab("Aantal artikelen/items waarin het gaat over peilingen")

  