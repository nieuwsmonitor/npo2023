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

c <- c |> mutate(speaker=case_when(
  pub == "journaal2023-11-11" & speakernum == "SPEAKER_40" ~ "yesilgoz",
  pub == "nieuwsenco2023-11-03" & speakernum == "SPEAKER_12" ~ "yesilgoz",
  pub == "nieuwsenco2023-11-03" & speakernum == "SPEAKER_13" ~ "n",
  pub == "nieuwsenco2023-11-03" & speakernum == "SPEAKER_28" ~ "jetten",
  pub == "nieuwsenco2023-11-03" & speakernum == "SPEAKER_29" ~ "n",
  pub == "nieuwsenco2023-11-03" & speakernum == "SPEAKER_31" ~ "bontenbal",
  pub == "nieuwsenco2023-11-03" & speakernum == "SPEAKER_47" ~ "bikker",
  pub == "sven2023-11-06" & speakernum == "SPEAKER_13" ~ "dassen",
  T ~ speaker
  
))

c |> filter(!is.na(speaker)) |> unique() |> mutate(order=if_else(speaker == "n", 2, 1)) |> 
  group_by(coder, pub, speakernum) |> filter(n()>1) |> arrange(coder, pub, speakernum, order)

speakers = c |> unique() |> mutate(order=if_else(is.na(speaker), 3, if_else(speaker == "n", 2, 1))) |> 
  group_by(coder, pub, speakernum) |> slice_min(order_by=order, n=1) |>
  mutate(speaker=if_else(speaker %in% c("olf", "vanhaga"), "n", speaker)) |>
  replace_na(list(speaker="n"))|> 
  filter(speaker != "d")

speakers  |>
  write_csv("results/radio_speakers.csv")
table(speakers$speaker, useNA="a")

speakers |> group_by(speaker) |> summarize(npub = length(unique(pub))) |> arrange(-npub)

# extra coderingen, deze alleen als expliciet gecodeerd

n2 = googlesheets4::read_sheet("https://docs.google.com/spreadsheets/d/18VUMsQKoyZbH8VHZET82-Mfr_L38wU862JbcWpp7my0/edit#gid=0", sheet = "Sheet2") |>
  select(pub, speakernum, speaker=politici)
n3 = googlesheets4::read_sheet("https://docs.google.com/spreadsheets/d/18VUMsQKoyZbH8VHZET82-Mfr_L38wU862JbcWpp7my0/edit#gid=0", sheet = "Sheet3") |>
  select(pub, speakernum, speaker=politicus)
n4 = googlesheets4::read_sheet("https://docs.google.com/spreadsheets/d/18VUMsQKoyZbH8VHZET82-Mfr_L38wU862JbcWpp7my0/edit#gid=0", sheet = "Sheet4") |>
  select(pub, speakernum, speaker=politicus)
n5 = googlesheets4::read_sheet("https://docs.google.com/spreadsheets/d/18VUMsQKoyZbH8VHZET82-Mfr_L38wU862JbcWpp7my0/edit#gid=0", sheet = "Sheet5") |>
  select(pub, speakernum, speaker=politicus)
n6 = googlesheets4::read_sheet("https://docs.google.com/spreadsheets/d/18VUMsQKoyZbH8VHZET82-Mfr_L38wU862JbcWpp7my0/edit#gid=0", sheet = "Sheet6") |>
  select(pub, speakernum, speaker=politicus)
n7 = googlesheets4::read_sheet("https://docs.google.com/spreadsheets/d/18VUMsQKoyZbH8VHZET82-Mfr_L38wU862JbcWpp7my0/edit#gid=0", sheet = "Sheet7") |>
  select(pub, speakernum, speaker=politici)



n2 |> filter(speaker == "baudet")
n4 |> filter(speaker == "baudet")

e = bind_rows(n2, n3, n4, n5, n6, n7) |>
  mutate(speaker=case_when(
    pub == "sven2023-11-08" & speakernum == "SPEAKER_03" ~ "n",
    pub == "sven2023-11-08" & speakernum == "SPEAKER_04" ~ "eerdmans",
    pub == "journaal2023-11-08" & speakernum == "SPEAKER_126" ~ "n",
    speaker=="baarle" ~ "vanbaarle", 
    speaker=="bontentbal" ~ "bontenbal",
    T ~ speaker)) |>
  filter(speaker != "d", !is.na(speaker))

speaker2 = e |> select(pub, speakernum, speaker) |>
  unique()

speaker2 |>
  group_by(pub, speakernum) |>
  filter(n() > 1)

bind_rows(speakers, speaker2) |>
  group_by(speaker) |> 
  write_csv("results/radio_speakers.csv")

bind_rows(speakers, speaker2) |>
  group_by(speaker) |>
  summarize(npub = length(unique(pub)))

table(speaker2$speaker)


bind_rows(speakers, speaker2) |>
  group_by(pub) |> 
  summarize(n=n()) |> 
  View()
  