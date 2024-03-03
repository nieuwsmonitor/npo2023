d <- read_csv("results/validatie_voices_radio.csv")
d |> replace_na(list(majority_speaker="n")) |>
  mutate(correct = spreker == majority_speaker) |>
  group_by(spreker) |>
  summarize(correct=mean(correct), n=n(), npub=length(unique(title))) |> arrange(-correct) |>
  View()


d |> filter(spreker == "jetten") |>
  group_by(title, speakernum, spreker, majority_speaker) |>
  summarize(n=n(), npub=length(unique(title)))

d |> filter(majority_speaker == "jetten")
