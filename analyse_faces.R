library(tidyverse)

faces <- read_csv("results/faces.csv")

faces <- faces |> 
  rename(found=person)|>
  mutate(person=str_extract(found, "data/facedb2/(\\w+)__WON", group=1))

faces |> group_by(person) |> summarize(nwon=length(unique(won)), n=n()) |> arrange(-nwon)
