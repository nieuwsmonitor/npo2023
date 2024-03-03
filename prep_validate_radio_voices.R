library(tidyverse)
w = googlesheets4::read_sheet("https://docs.google.com/spreadsheets/d/1u0CyQDNG9skAUUnn6x_hrLkpPAOLPECb2L5Cq8jfDrg/edit#gid=0")
n = googlesheets4::read_sheet("https://docs.google.com/spreadsheets/d/18VUMsQKoyZbH8VHZET82-Mfr_L38wU862JbcWpp7my0/edit#gid=0")


wcoded = w |> filter(!is.na(speaker)) |> pull(pub) |> unique() |> setdiff("nieuwsenco2023-11-03")
wc = w |> filter(pub %in% wcoded) |> select(pub, speakernum, speaker) |> add_column(coder="w")

ncoded = n |> filter(!is.na(speaker)) |> pull(pub) |> unique()
nc = n |> filter(pub %in% ncoded) |> select(pub, speakernum, speaker) |> add_column(coder="n")

c = bind_rows(nc, wc) |>
  mutate(speaker=case_match(
    speaker,
    "daSSEN+BONTEBAL" ~ "d",
    "timmermans en wilders" ~ "d",
    c("jesselgus","jessulgus","yesilgus")  ~ "yesilgoz",
    "plas" ~ "vanderplas",
    .default = speaker
  ))
table(c$speaker)

c |> filter(!is.na(speaker)) |> unique() |> group_by(pub, speakernum) |> filter(n() > 1) |> arrange(pub, speakernum)

c |> filter(!is.na(speaker)) |> unique() |> mutate(order=if_else(speaker == "n", 2, 1)) |> 
  group_by(coder, pub, speakernum) |> filter(n()>1) |> arrange(coder, pub, speakernum, order)

speakers = c |> unique() |> mutate(order=if_else(is.na(speaker), 3, if_else(speaker == "n", 2, 1))) |> 
  group_by(coder, pub, speakernum) |> slice_min(order_by=order, n=1) |>
  mutate(speaker=if_else(speaker %in% c("olf", "vanhaga"), "n", speaker)) |>
  replace_na(list(speaker="n"))

write_csv(speakers, "results/radio_speakers.csv")
table(speakers$speaker, useNA="a")
