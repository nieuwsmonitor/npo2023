library(tidyverse)
d = read_csv("results/validatie_voices.csv")
mean(d$spreker == d$majority_speaker)
table(d$spreker, d$majority_speaker, useNA = "a")
table(d$spreker == d$majority_speaker, useNA = "a")

d <- d |>
  replace_na(list(spreker="", majority_speaker="")) |>
  mutate(haspol=spreker != "", 
            goed = spreker == majority_speaker)

d |>
  group_by(won, speakernum, spreker, majority_speaker, goed) |>
  unique() |>
  summarize(nturns=n(), .groups = "drop") |>
#  group_by(spreker) |> 
  summarize(nwon=length(unique(won)), sumnturns=sum(nturns), n=n(), accmacro=mean(goed), accmicro=sum(goed*nturns)/sum(nturns)) |> 
  View()

d |> filter(!goed, spreker == "Henri Bontenbal")

d |>
  replace_na(list(spreker="", majority_speaker="")) |>
  mutate(haspol=spreker != "", 
         goed = spreker == majority_speaker) |>
  summarize(acc=mean(goed)) |> 
  View()

d |>
  replace_na(list(spreker="", majority_speaker="")) |>
  mutate(haspol=spreker != "", 
         goed = spreker == majority_speaker) |>
  group_by(majority_speaker) |> summarize(acc=mean(goed)) |> 
  #left_join(nwons) |>
  View()


nwons = d |> group_by(spreker) |> summarize(nwon = length(unique(won)))
