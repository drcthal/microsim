library(tidyverse)
library(gtrendsR)

setwd('C:/Projects/microsim')
states <- haven::read_dta('raw/all_statefip.dta') %>%
    pull(abbr) %>% 
    as.character %>%
    paste0('US-',.) %>%
    split(ceiling(1:51/5))

states[[11]] <- c(states[[11]],'US')

trends <- lapply(states, function(st) {
    t <- gtrends(keyword = 'mask',
            geo = st,
            time = '2020-01-01 2020-07-25',
            onlyInterest=TRUE)
    return(t$interest_over_time)
}) %>%
    bind_rows
                 
trends %>%
    select(date, hits, keyword, geo) %>%
    mutate(geo = str_remove(geo,'US-'),
           date = as.character(date)) %>%
    write_csv('raw/trends/mask_search_trends.csv')

ggplot(data = trends, aes(x=date, y=hits, color=geo)) + 
    geom_line()
