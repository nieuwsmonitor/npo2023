d <- read_csv("results/validatie_voices_radio.csv")
d <- d |> replace_na(list(majority_speaker="n")) |>
  mutate(goed = spreker == majority_speaker) 

v1 = d |>
  unique() |>
  group_by(title, speakernum, spreker, majority_speaker, goed) |>
  summarize(nturns=n(), .groups = "drop") |>
  group_by(spreker) |> 
  summarize(nwon=length(unique(title)), sumnturns=sum(nturns), n=n(), accmacro=mean(goed), accmicro=sum(goed*nturns)/sum(nturns)) 
v2 = d |>
  unique() |>
  group_by(title, speakernum, spreker, majority_speaker, goed) |>
  summarize(nturns=n(), .groups = "drop") |>
  summarize(nwon=length(unique(title)), sumnturns=sum(nturns), n=n(), accmacro=mean(goed), accmicro=sum(goed*nturns)/sum(nturns)) 
bind_rows(v2, v1) |> write_csv("~/Downloads/bla.csv")
  
  
  group_by(spreker) |>
  summarize(correct=mean(correct), n=n(), npub=length(unique(title))) |> arrange(-correct) |>
  View()


d |> filter(spreker == "eerdmans") |>
  group_by(title, speakernum, spreker, majority_speaker) |>
  summarize(n=n(), npub=length(unique(title)))

d |> filter(spreker == "eerdmans") |> View()


d <- read_csv("results/voices_radio.csv")

d = d |>
  mutate(duration = end - start) 

d |>
  group_by(majority_speaker) |>
  summarize(n=n(), npub=length(unique(won)), seconds=sum(duration)) |> View()

d |> filter(majority_speaker == "bontenbal") |> group_by(won, speakernum) |> summarize(n=n(), seconds=sum(duration)) |> arrange(-seconds)
d |> filter(majority_speaker == "marijnissen") |> group_by(won, speakernum) |> summarize(n=n(), seconds=sum(duration)) |> arrange(-seconds)
