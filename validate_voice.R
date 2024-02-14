library(tidyverse)
d = read_csv("/tmp/bla5.csv")
table(d$spreker, d$majority_speaker, useNA = "a")
table(d$spreker == d$majority_speaker, useNA = "a")

d |>
  replace_na(list(spreker="", majority_speaker="")) |>
  mutate(haspol=spreker != "", 
            goed = spreker == majority_speaker) |>
  group_by(spreker) |> summarize(acc=mean(goed)) |> 
  left_join(nwons) |>
  View()


d |>
  replace_na(list(spreker="", majority_speaker="")) |>
  mutate(haspol=spreker != "", 
         goed = spreker == majority_speaker) |>
  group_by(majority_speaker) |> summarize(acc=mean(goed)) |> 
  #left_join(nwons) |>
  View()


nwons = d |> group_by(spreker) |> summarize(nwon = length(unique(won)))
