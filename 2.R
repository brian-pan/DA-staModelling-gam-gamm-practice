#install.package(gamm4)

library(devtools)
library(mgcv)
library(gamm4)
library(tidyverse)

# Load nCOVID-19 data
covid_data <- read_csv("covid_data.csv")

# Plot over time
covid_data %>% 
  filter(country_region %in% c('Hubei','Italy','Iran','South Korea','USA')) %>% 
  na.omit() %>% 
  ggplot(aes(time, dead, color=country_region)) +
  geom_point() +
  theme_minimal()

# Plot from initial death in region
covid_data %>% 
  filter(country_region %in% c('Hubei','Italy','Iran','South Korea','USA')) %>% 
  na.omit() %>% 
  ggplot(aes(timeInt, dead, color=country_region)) +
  geom_point() +
  theme_minimal()

# Fit a GAM with `dead` as the response a smooth on `timeInt` and `country_region` as covariate.
# In the smooth, use `pc=0`, which indicates a *point constraint*. The smooth will pass through 0 at this point.
resGam= mgcv::gam(
  dead ~ s(timeInt, pc=0) + country_region, 
  data=covid_data, 
  family=poisson(link='log'))

summary(resGam)
coef(resGam)
plot(resGam)

# This model will result in an error.
resGam2= mgcv::gam(
  dead ~ s(timeInt, k=150, pc=0) + country_region, 
  data=covid_data, 
  family=poisson(link='log'))

resGam3= mgcv::gam(
  dead ~ s(timeInt, k=50, pc=0) + country_region, data=covid_data, 
  family=poisson(link='log'), method='ML')
plot(resGam3)
gam.check(resGam3)

resGam4 = mgcv::gam(
  dead ~ s(timeInt, k=20, pc=0) + country_region, data=covid_data, 
  family=poisson(link='log'), method='ML')
plot(resGam4)
gam.check(resGam4)


covid_data$timeIntInd = covid_data$timeInt

resGammInd = gamm4::gamm4(
  dead ~ country_region + 
    s(timeInt, k=20, pc=0),
  random = ~ (1|timeIntInd), 
  data=covid_data, family=poisson(link='log'))

plot(resGammInd$gam)
summary(resGammInd$mer)
summary(resGammInd$gam)



covid_data_2 <- expand_grid(covid_data$timeInt, covid_data$country_region) %>% 
  as_tibble() %>% 
  rename(timeInt = 1, country_region = 2) %>% 
  distinct() 

covid_data_2$predicted <- predict(resGammInd$gam, newdata=covid_data_2, type="response")

#covid_data_3 <- bind_cols(covid_data_2, predicted) %>% 
#mutate(lower = fit - 2*se.fit, upper = fit + 2*se.fit)

covid_data_2 %>% 
  ggplot(aes(timeInt, predicted, colour=country_region)) +
  geom_line() +
  theme_minimal() +
  facet_wrap(~country_region) +
  ggtitle("Predicted deaths over time (time = 0 is first death)")

## soln
covid_data$timeSlope = covid_data$timeInt/100

resGammSlope = gamm4::gamm4(
  dead ~ country_region + s(timeInt, k=30, pc=0),
  random = ~(0+timeSlope|country_region) + 
    (1|timeIntInd:country_region), 
  data=covid_data, family=poisson(link='log'))

#save(resGammSlope, file='resGamSlope.RData')
plot(resGammSlope$gam)
summary(resGammSlope$mer)
names(lme4::ranef(resGammSlope$mer))
theRanef = lme4::ranef(resGammSlope$mer, condVar = TRUE)$country_region
(theRanefVec = sort(drop(t(theRanef))))

Dcountry = 'France'
toPredict = expand.grid(
  timeInt = 0:100, 
  country_region = Dcountry)
toPredict$timeSlope = toPredict$timeIntInd = 
  toPredict$timeInt
thePred = predict(resGammSlope$gam, 
                  newdata=toPredict, se.fit=TRUE)

matplot(toPredict$timeInt, 
        exp(do.call(cbind, thePred) %*% Pmisc::ciMat(0.75)), 
        type='l',
        col=c('black','grey','grey'), 
        ylim = c(0, 25))
points(covid_data[covid_data$country_region == Dcountry,c('timeInt','dead')], 
       col='red')


##
install.packages("devtools")
devtools::install_github("GuangchuangYu/nCov2019")
x1 <- nCov2019::load_nCov2019(lang = 'en')
cutoff=3

x2 = by(x1$global, x1$global[,'country', drop=FALSE], 
        function(xx) {
          xx$incidence = diff(c(0, xx$cum_confirm))
          xx$dead = diff(c(0, xx$cum_dead))
          if(any(xx$cum_dead >= cutoff)) {
            cutoffHere = min(xx[xx$cum_dead >= cutoff,'time'], na.rm=TRUE) +1
            xx$timeInt = as.numeric(difftime(xx$time, cutoffHere, units='days'))
            xx = xx[xx$timeInt >= 0, ]
            xx=					xx[,c('time','timeInt','cum_confirm','cum_dead','incidence','dead','country')]
          } else {
            xx = NULL
          }
          xx
        }, simplify=FALSE)

x3 = by(x1$province, x1$province[,'province', drop=FALSE], 
        function(xx) {
          xx$incidence = diff(c(0, xx$cum_confirm))
          xx$dead = diff(c(0, xx$cum_dead))
          colnames(xx) = gsub("province","country", colnames(xx))
          if(any(xx$cum_dead >= cutoff)) {
            cutoffHere = min(xx[xx$cum_dead >= cutoff,'time'], na.rm=TRUE) +1
            xx$timeInt = as.numeric(difftime(xx$time, cutoffHere, units='days'))
            xx = xx[xx$timeInt >= 0, ]
            xx=					xx[,c('time','timeInt','cum_confirm','cum_dead','incidence','dead','country')]
          } else {
            xx = NULL
          }
          xx
        }, simplify=FALSE)

class(x2) = class(x3) = 'list'
x2 = x2[grep('China', names(x2), invert=TRUE)]
x = c(x2, x3)
x$Hubei[x$Hubei$incidence > 4000,c('dead','incidence')] = NA

tidy_data <- compact(x) %>% bind_rows() %>% 
  rename(country_region = country) %>% 
  filter(dead>0)
write_csv(tidy_data, "covid_data.csv")
