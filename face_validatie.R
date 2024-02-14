library(tidyverse)

dists = (30:70)/100

raw <- read_csv("results/validatie_faces.csv")

x = purrr::map(dists, function (d) {
  f <-  raw |>
    mutate(found=ifelse(is.na(dist) | dist >= d, "others", found),
           found=ifelse(found == "olf", "others", found),
           actual=ifelse(actual == "olf", "others", actual))
  tibble(dist=d, acc=mean(f$actual == f$found))
}  ) |> list_rbind()

ggplot(x, aes(dist, acc)) + geom_point()


d <- read_csv("results/validatie_faces.csv") |>
  
  mutate(found=ifelse(is.na(dist) | dist >= .5, "others", found),
         found=ifelse(found == "olf", "others", found),
         actual=ifelse(actual == "olf", "others", actual))

mean(d$actual == d$found)

d |> group_by(actual) |> summarize(
  accuracy=mean(actual == found),
  n=n(),
  nwon=length(unique(test_won))
) |> arrange(accuracy) 

library(tidyverse)

d |> group_by(actual, found) |> 
  summarize(n=n()) |> 
  mutate(perc=n/sum(n)) |>
  filter(actual != found) |>
  arrange(-n) |> View()

d |> filter(found == "baarle", found != actual) 


# 



f = "WON02442276__faces.csv"

library(tidyverse)

COLS <- cols(
  won = col_character(),
  frame = col_double(),
  person = col_character(),
  file = col_character(),
  x = col_double(),
  y = col_double(),
  w = col_double(),
  h = col_number()
)
read_faces <- function(f) {
  read_csv(str_c("data/faces/", f), col_names = names(COLS$cols), skip=1, col_types = COLS)
}


faces <- list.files("data/faces") |>
  purrr::discard(function(f) file.info(str_c("data/faces/", f))$size == 30) |>
  purrr::map(read_faces, .progress = T) |> list_rbind()

write_csv(faces, "results/faces.csv")
