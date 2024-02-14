remotes::install_github('kasperwelbers/boolydict')
library(textdata)
library(boolydict)
library(amcatr)
library(tidyverse)
library(googlesheets4)
library(sotu)
library(tidytext)


conn = amcat.connect("https://vu.amcat.nl")
data = amcat.getarticlemeta(conn=conn, project = 65, articleset = 7805, columns = c("title", "publisher","date", "text"), dateparts = T)
data = data|>
  mutate(text = tolower(text),
         title = tolower(title))|>
  mutate(text=paste(title,text))

write_csv(data, "results/websites_amcat.csv")

head(data)

googlesheets4::gs4_deauth()
partijen <- read_sheet('https://docs.google.com/spreadsheets/d/1d3G1_y_HJP2Ik1v7rKrxeAXL4uCt5mLNgc8uC7vzQyI/edit#gid=0', sheet = 1)
write_csv(partijen, "results/party_queries.csv")

tokens = data |>unnest_tokens(word, text)
head(tokens)

hits = tokens |> 
  dict_add(partijen, text_col = 'word', by_label='label', fill = 0) |>
  as_tibble()

check = hits |> arrange(-sp) |> head()
colnames(hits)


hits2 = hits|>
  pivot_longer(`50Plus`:vvd)|>
  group_by(publisher,name)|>
  summarise(n=sum(value))|>
  mutate(perc=n/sum(n)*100)|>
  filter(publisher=="NOS.nl")
  
head(hits2)
ggplot(hits2, aes(x=perc, y=name, fill=name)) + geom_col()+
  facet_grid(~publisher)
  