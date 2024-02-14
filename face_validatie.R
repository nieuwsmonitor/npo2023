library(tidyverse)

dists = (30:70)/100

raw <- read_csv("validatie_faces.csv")

x = purrr::map(dists, function (d) {
  f <-  raw |>
    mutate(found=ifelse(is.na(dist) | dist >= d, "others", found),
           found=ifelse(found == "olf", "others", found),
           actual=ifelse(actual == "olf", "others", actual))
  tibble(dist=d, acc=mean(f$actual == f$found))
}  ) |> list_rbind()

ggplot(x, aes(dist, acc)) + geom_point()


d <- read_csv("validatie_faces.csv") |>
  
  mutate(found=ifelse(is.na(dist) | dist >= .5, "others", found),
         found=ifelse(found == "olf", "others", found),
         actual=ifelse(actual == "olf", "others", actual))

mean(d$actual == d$found)

d |> group_by(actual) |> summarize(
  accuracy=mean(actual == found),
  n=n(),
  nwon=length(unique(test_won))
) |> arrange(accuracy) |>

"WON02439070" %in% d$test_won
"WON02443802" %in% d$test_won
"WON02438760" %in% d$test_won
"WON02440077" %in% d$test_won
"WON02440709" %in% d$test_won
"WON02440075" %in% d$test_won
"WON02438760" %in% d$test_won
for (won in c("WON02440081","WON02438760","WON02442245","WON02440075")) {
  message(str_c(won,"?", won %in% d$test_won))
}

library(tidyverse)
d |> group_by(actual, found) |> 
  summarize(n=n()) |> 
  mutate(perc=n/sum(n)) |>
  filter(actual != found) |>
  arrange(-n) |> View()

d |> filter(found == "baarle", found != actual) 


# 