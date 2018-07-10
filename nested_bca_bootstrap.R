
# Notes -------------------------------------------------------------------

# this script contains two functions: one a simple mean, the other a weighted mean


# load packages -----------------------------------------------------------


library(boot)
library(tidyverse)
library(readxl)

# First I want to create my function to sit within `boot()`.

# (See more info here - http://www.stat.ucla.edu/~rgould/252w02/bs2.pdf)
# and here https://stackoverflow.com/questions/46231261/bootstrap-weighted-mean-in-r


# bootstrapping subfunction ------------------------------------------------


simple_mean <- function(x, i){
  mean(x[i])
}

#' and then the function to wrap around `boot()` ---------------------------

my_boot_mean <- 
  function(data, var, Rval){
    boot_dta <- boot(data[[var]], simple_mean, R = Rval)
    return(boot_dta)
  }

#' This was by far the most annoying part. I didn't realise that `boot()` wanted
#' a set of values and *not* a vector. So [[]] is required to extract the
#' innards of the vector, rather than [] to present the vector itself. 
#' h/t http://r4ds.had.co.nz/vectors.html.

#' let's test this to see if it works.

test_boot <- my_boot_mean(iris, "Sepal.Length", 500)

test_boot

#' looks good to me!


#' Now let's put together a function to extract the confidence intervals from the boot object:

bca_cis <- function(boot_out){
  
  results <- boot.ci(boot_out, type = "bca")
  mean <- results[["t0"]]
  low_ci <- pluck(results, "bca", 4)
  high_ci <- pluck(results, "bca", 5)
  
  output <- 
    tribble(
      ~statistic, ~value,
      "low_ci",   low_ci,
      "mean", mean,
      "high_ci", high_ci
    )
  
  return(output)
}

#' Let's try this on the object we just saw:

bca_cis(test_boot)

#' looks good!

#' package this all together and try it on an example on multiple groups


sep_length <- iris %>% 
  select(Sepal.Length, Species)

sep_length <- sep_length %>% 
  group_by(Species) %>% 
  nest()

sep_length <- sep_length %>% 
  mutate(boot_obj = pmap(list(data, "Sepal.Length", 500), my_boot_mean)) %>% 
  mutate(results = map(boot_obj, bca_cis))

cis <- sep_length %>% 
  unnest(results)


# now a similar function for a weighted mean using SIMD ------------------------------



# reading in data ---------------------------------------------------------

simd_ranks <- read_xlsx(here::here("data", "00510565.xlsx"), sheet = 2)

# renaming varaibles
names(simd_ranks) <- tolower(names(simd_ranks))


# adding fake packages variable
simd_ranks$fake_total <- rpois(6976, 1)

# weighted mean helper function from 
# https://stackoverflow.com/questions/46231261/bootstrap-weighted-mean-in-r

samplewmean <- function(d, i, j) {
  d <- d[i, ]
  w <- j[i, ]
  return(weighted.mean(d, w))   
}


# my weighted mean boot wrapper

my_weighted_boot <- 
  function(df, var, Rval, weightvar){
    df <- as.data.frame(df)
    boot_dta <- boot::boot(data = df[var], statistic = samplewmean, R = Rval, j = df[weightvar])
    return(boot_dta)
  }

weighted_boot <- 
  simd_ranks %>% 
  group_by(council_area) %>% 
  nest() %>% 
  mutate(boot_obj = pmap(list(data, "fake_total", 5000, "total_population"), my_weighted_boot)) %>% 
  mutate(results = map(boot_obj, bca_cis))

cis <- weighted_boot %>% 
  unnest(results)

cis

# looks good to me!