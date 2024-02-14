remotes::install_github('kasperwelbers/boolydict')
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



googlesheets4::gs4_deauth()
partijen <- read_sheet('https://docs.google.com/spreadsheets/d/1d3G1_y_HJP2Ik1v7rKrxeAXL4uCt5mLNgc8uC7vzQyI/edit#gid=0', sheet = "politici")


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

