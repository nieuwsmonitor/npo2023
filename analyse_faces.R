library(tidyverse)

faces <- read_csv("results/faces.csv")
faces2 <- read_csv("results/faces_missing.csv")

faces = faces|>
  rbind(faces2)

faces <- faces |> 
  rename(found=person)|>
  mutate(person=str_extract(found, "data/facedb2/(\\w+)__WON", group=1))

all_wons = read_csv("results/voices_tv2.csv") |> select(won) |> unique()

meta = read_csv("results/tv_amcat.csv") |> select(won, publisher)

meta2=meta|>
  distinct(won, .keep_all = T) |>
  filter(won %in% all_wons$won)


length(unique(meta2$won))
length(unique(faces$won))

check = meta2|>
  anti_join(faces)
setdiff(meta2$won, faces$won)

missing_faces = faces|> 
  select(won) |>
  unique() |>
  add_column(inface=1) |>
  full_join(meta2)

table(missing_faces$inface, useNA = "a")

missing_faces |>
  group_by(publisher, inface)|>
  summarize(nwon=length(unique(won)), n=n()) 
  
missing_faces |> filter(is.na(inface)) |> pull(won)


table(faces$publisher)

faces2 = faces|>
  mutate(person = case_match(person, "timmermans" ~ "Frans Timmermans",
                             "vanderplas" ~ "Caroline van der Plas",
                             "omtzigt" ~ "Pieter Omtzigt",
                             "bontenbal" ~ "Henri Bontenbal",
                             "yesilguz" ~ "Dilan Yeşilgöz",
                             "jetten" ~ "Rob Jetten",
                             "marijnissen" ~ "Lilian Marijnissen",
                             "bikker" ~ "Mirjam Bikker",
                             "eerdmans" ~ "Joost Eerdmans",
                             "ouwehand" ~ "Esther Ouwehand",
                             "dassen" ~ "Laurens Dassen",
                             "wilders" ~ "Geert Wilders",
                             "baarle" ~ "Stephan van Baarle",
                             "baudet" ~ "Thierry Baudet",
                             "stoffer" ~ "Chris Stoffer",
                             "haga" ~ "Wybren van Haga"))|>
  filter(person != "Wybren van Haga")

faces3 =faces2|> group_by(person) |> summarize(nwon=length(unique(won)), n=n()) |>
  mutate(perc = n/sum(n)*100,
         n=n/60)|>arrange(-n)

ggplot(faces3, aes(x=perc, y=reorder(person,perc), fill=person)) + geom_col()+
  geom_text(data=filter(faces3, perc > 0), aes(x=0, label=round(perc,1)),hjust=-.1)+
  theme_classic() +theme(legend.position = "")+
  xlab("Percentage")+
  ylab("")



table(faces2$publisher)

faces5 = faces2|>
  left_join(meta2)|>
  mutate(publisher2 = case_when(str_detect(publisher, "BUITENHOF") ~ "Buitenhof",
                                str_detect(publisher, "WNL") ~ "WNL",
                                str_detect(publisher, "NOS") ~ "NOS",
                                str_detect(publisher, "Op1") ~ "OP1",
                                str_detect(publisher, "NIEUWSUUR") ~ "Nieuwsuur",
                                str_detect(publisher, "EENVANDAAG") ~ "EenVandaag",
                                str_detect(publisher, "EenVandaag") ~ "EenVandaag",
                                T ~ publisher))

check = faces|>
  #filter(publisher2=="NOS")|>
  group_by(publisher)|>
  summarize(nwon=length(unique(won)))
            
table(check$publisher)

d4 = faces5 |>
  filter(person != "Wybren van Haga")|>
  group_by(publisher2,person)|>
  summarize(nwon=length(unique(won)), n=n()) |>
  mutate(perc = n/sum(n)*100,
         n=n/60)|>arrange(-n)


table(d4$publisher2)

ggplot(d4, aes(x=perc, y=reorder(person,perc), fill=person)) + geom_col()+
  geom_text(data=filter(d4, perc > 4), aes(x=0, label=round(perc,1)),hjust=-.1)+
  theme_classic() +theme(legend.position = "")+
  xlab("Percentage")+
  ylab("")+
  facet_grid(~publisher2)



