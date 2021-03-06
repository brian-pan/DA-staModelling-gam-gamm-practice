# libraries
library(cowplot)
library(tidyverse)
library(mgcv)
library(XML)
library(RCurl)

mathGam = gam(
  MathAch ~ s(SES) + Minority*Sex, 
  data=MathAchieve)
knitr::kable(
  summary(mathGam)$p.table[,1:2], 
  digits=1)

plot(mathGam)

mathGam$sp

## Math, SES-minority interaction
mathGamInt = gam(
  MathAch ~ s(SES, by=Minority) + 
    Minority*Sex, 
  data=MathAchieve)
mathGamInt$sp

knitr::kable(
  summary(mathGamInt)$p.table[,1:2], 
  digits=1)

plot(mathGamInt, select=1)
plot(mathGamInt, select=2)

## Math, common smoothing parameter
mathGamIntC = gam(MathAch ~ 
                    s(SES, by=Minority, id=1) + 
                    Minority*Sex, 
                  data=MathAchieve)
mathGamIntC$sp

knitr::kable(
  summary(mathGamIntC)$p.table[,1:2], 
  digits=1)

plot(mathGamIntC, select=1)
plot(mathGamIntC, select=2)

## Math 2d

mathGam2 = gam(
  MathAch ~ s(SES, MEANSES) +
    Minority*Sex, 
  data=MathAchieve)
plot(mathGam2, scheme=2, n2=100)

mTable1 = XML::readHTMLTable(getURL(
  'https://en.wikipedia.org/wiki/List_of_countries_by_infant_mortality_rate'
), stringsAsFactors=FALSE, header=TRUE)
mTable1 = mTable1[[which.max(unlist(lapply(mTable1, nrow)))]]
mTable = mTable1[grep("^([[:digit:]]|[[:space:]])+$|^$|^Country|^World", mTable1[,1], invert=TRUE), ]
mTable = mTable[,c(1,3)]

colnames(mTable)=c('Country','mortality')

iTable = readHTMLTable(getURL(
  'https://en.wikipedia.org/wiki/List_of_countries_by_GDP_(PPP)_per_capita'
), stringsAsFactors=FALSE,header=TRUE)s

iTable = iTable[[5]]
colnames(iTable) = gsub("([[:punct:]]|[[:space:]]).*", "", colnames(iTable))
iTable$Country = gsub("[[:punct:]]", "", iTable$Country)
mTable$Country = gsub("[[:punct:]]", "", mTable$Country)

iTable$Country = gsub("�", "o", iTable$Country)
iTable$Country = gsub("�", "a", iTable$Country)
iTable$Country = gsub("�", "e", iTable$Country)
iTable$Country = gsub("�", "i", iTable$Country)

iMort = merge(iTable, mTable, by='Country')

ineqTable = readHTMLTable(getURL(
  'https://en.wikipedia.org/wiki/List_of_countries_by_income_equality'
), skip.rows=1:2, stringsAsFactors=FALSE)
ineqTable = ineqTable[[1]][-1,]
ineqTable = ineqTable[,c(1,4)]
colnames(ineqTable) = c('Country','gini')
ineqTable$Country = gsub("[[:punct:]]", "", ineqTable$Country)
iMort = merge(iMort, ineqTable, by='Country')
colnames(iMort) = gsub("[[:punct:]]", "", colnames(iMort))
iMort$income = as.numeric(gsub("[[:punct:]]", "", iMort$Int))
iMort$gini = as.numeric(iMort$gini)
iMort$mortality = as.numeric(iMort$mortality)
iMort = iMort[,c('Country','mortality','gini','income')]



library('mgcv')
iMort$logInc = log10(iMort$income)
iMort$logMort = log(iMort$mortality)
mortGam = gam(logMort ~ s(logInc, gini), data=iMort)
plot(mortGam, scheme=2)

### A prettier plot
predList = list(gini = seq(25,50,len=201), logInc = seq(
  log10(19000), log10(110000), len=101))
mortPred = exp(predict(mortGam, 
                       do.call(expand.grid, predList),
                       type='response'))
mortCol = mapmisc::colourScale(
  mortPred, digits=1.5, col='Spectral', 
  style='equal', transform=0.5, 
  breaks=9, rev=TRUE)
image(predList$gini,
      10^predList$logInc/1000,
      matrix(mortPred, length(predList$gini), 
             length(predList$logInc)),
      xlab = 'gini coef', ylab='income',
      log='y', col=mortCol$col, breaks=mortCol$breaks)
mapmisc::legendBreaks("right", mortCol, cex=0.8, inset=0)


zUrl = 'http://www20.statcan.gc.ca/tables-tableaux/cansim/csv/01020502-eng.zip'

cFile = Pmisc::downloadIfOld(
  'https://www150.statcan.gc.ca/n1/en/tbl/csv/13100708-eng.zip',
  path=file.path('..', ''))
cFile = cFile[which.max(file.info(cFile)$size)]
dTable = read.table(cFile, 
                    sep=',', header=TRUE, stringsAsFactors=FALSE)
dTable = dTable[grep("Number", dTable$UOM),]
dTable = dTable[grep("Total", dTable$Month.of.death, invert=TRUE),]

dTable$year = dTable[,grep("^ref.date$", colnames(dTable), ignore.case=TRUE)]
dTable$month = gsub("^[[:print:]]+ ", "", dTable$Month.of.death)
dTable$dateString = paste(dTable$year, dTable$month, '01')
dTable$date = strptime(dTable$dateString, 
                       format = '%Y %B %d', tz='UTC')

dTable$month  = factor(dTable$month, levels = months(ISOdate(0,1:12,1)))
dTable$province = gsub(",.+", "", dTable$GEO) 

dTable = dTable[order(dTable$date),]

cDeaths = dTable[grep("canada", dTable$GEO, ignore.case=TRUE, invert=TRUE),
                 c('province', 'date', 'month','VALUE')]
names(cDeaths) = gsub("VALUE", "Value", names(cDeaths))
oDeaths = cDeaths[cDeaths$province=='Ontario',]

# ontarioData tidy=false
timeOrigin = ISOdate(2000,1,1,0,0,0, tz='UTC')
oDeaths$timeNumeric = as.numeric(
  difftime(oDeaths$date, timeOrigin, 
           units='days'))
oDeaths[c(1,100,200),
        c('date', 'month', 'Value',
          'timeNumeric')]

# NoOffset gam
deathsGam = gam(
  Value ~ month + s(timeNumeric),
  data=oDeaths, family='poisson'
)
knitr::kable(
  summary(deathsGam)$p.table[,1:2], 
  digits=3, col.names=c('est','se'))

# Relative rate for each month
theMonths = grep( '^month', names(deathsGam$coef),value=TRUE)
plot(exp(deathsGam$coef[theMonths]), log='y',  xaxt='n', ylab='rr', xlab='')
mtext(gsub("^month", "", theMonths), 
      at=1:length(theMonths), 
      side=1, las=3, adj=0, line=2)

# Number of days in each month
oDeaths$daysInMonth =	Hmisc::monthDays(oDeaths$date)
oDeaths$nDays = log(oDeaths$daysInMonth)
oDeaths[c(1,2,100,200),c('date','month','daysInMonth','nDays')]

#gam
deathsGam = gam(
  Value ~ month + s(timeNumeric) + 
    offset(nDays), data=oDeaths, 
  family='poisson')
knitr::kable(
  summary(deathsGam)$p.table[,1:2], 
  digits=3, col.names=c('est','se'))

# Relative rate for each month
theMonths = grep( '^month', names(deathsGam$coef),value=TRUE)
plot(exp(deathsGam$coef[theMonths]), log='y', xaxt='n', ylab='rr', xlab='')
mtext(gsub("^month", "", theMonths), 
      at=1:length(theMonths), 
      side=1, las=3, adj=0, line=2)

#ontGamPlot
dSeq = 	seq(from=min(oDeaths$date),by='5 years', length.out=10)
plot(deathsGam, xaxt='n', xlab='date')
axis(1, at=difftime(dSeq,timeOrigin, units='days'), 
     labels=format(dSeq,'%Y'))

# ontGamPlotExp
dSeq =  seq(from=min(oDeaths$date),by='5 years', length.out=10)
deathPred = as.matrix(as.data.frame(predict.gam(deathsGam, 
                                                oDeaths, 
                                                type = 'terms', terms = 's(timeNumeric)', se.fit=TRUE)))
deathPred = exp(deathPred %*% Pmisc::ciMat())
matplot(oDeaths$timeNumeric, deathPred, log='y', xaxt='n', 
        xlab='date', type = 'l', lty = c(1,2,2), col='black', ylab='rr')
axis(1, at=difftime(dSeq,timeOrigin, units='days'), 
     labels=format(dSeq,'%Y'))

# Forecasting (ontForecast)
Stime = seq(from=as.Date("2000/1/1"), to=as.Date("2026/1/1"), by='months')
newX = data.frame(
  timeNumeric = as.numeric(difftime(Stime, timeOrigin, units='days')),
  month  = months(Stime),
  nDays =	log(Hmisc::monthDays(Stime)))
deathsPred = predict(deathsGam, newX, se.fit=TRUE)

# Predictions (ontForecastPredict)
deathsPred = as.data.frame(deathsPred)
deathsPred$lower = deathsPred$fit - 2*deathsPred$se.fit
deathsPred$upper = deathsPred$fit + 2*deathsPred$se.fit
matplot(Stime, exp(deathsPred[,c('lower','upper','fit')]), 
        type='l', lty=1, col=c('grey','grey','black'),
        lwd=c(2,2,1),  xlab='date', ylab='deaths', 
        yaxs='i', xaxs='i', xaxt='n')

forAxis = seq(from=as.Date("2000/1/1"), to=as.Date("2026/1/1"), by='5 years')
axis(1, as.numeric(forAxis), format(forAxis, '%Y'))
points(as.POSIXct(oDeaths$date, format="%Y/%m/%d" ), 
       oDeaths$Value, cex=0.5, col='red')

# a different constraint
deathsGamC = gam(
  Value ~ month + s(timeNumeric, pc=0) + 
    offset(nDays), data=oDeaths, 
  family='poisson')

knitr::kable(
  summary(deathsGamC)$p.table[,1:2], 
  digits=3, col.names=c('est','se'))

deathPredC = as.matrix(as.data.frame(predict.gam(deathsGamC, 
                                                 oDeaths, 
                                                 type = 'terms', terms = 's(timeNumeric)', se.fit=TRUE)))
deathPredC = exp(deathPredC %*% Pmisc::ciMat())

x <- data_frame(as.POSIXct(oDeaths$date, format="%Y/%m/%d"), deathGamPredMat[,1], deathGamPredMat[,2], deathGamPredMat[,3])

names(x) <- c("date", "est", "lower", "upper")

oDeaths$date <- as.POSIXct(oDeaths$date, format="%Y/%m/%d")

x <- left_join(x, oDeaths, by = "date")

x$date <- as.POSIXct(x$date, format="%Y/%m/%d")

x %>% 
  filter(date > as.Date("2017-06-01")) %>% 
  ggplot(aes(date, est)) +
  geom_line() +
  geom_ribbon(aes(ymin = lower, ymax = upper), alpha = 0.5, fill = "grey50") +
  geom_point(aes(date, nDays))

# A longer time span
x %>% 
  ggplot(aes(date, est)) +
  geom_line() +
  geom_ribbon(aes(ymin = lower, ymax = upper), alpha = 0.5, fill = "grey50")

library('mgcv')
library('cowplot')
set.seed(25)

f2 <- function(x) 0.2 * x^11 * (10 * (1 - x))^6 + 10 * (10 * x)^3 * (1 - x)^10

ysim <- function(n = 500, scale = 2) {
  x <- runif(n)
  e <- rnorm(n, 0, scale)
  f <- f2(x)
  y <- f + e
  data.frame(y = y, x = x, f2 = f)
}
my_data <- ysim()

p <- ggplot(my_data, aes(x = x, y = y)) +
  geom_point()
p

p_1_1000 <- p + geom_smooth(method="gam", color="purple", formula = y ~ s(x, k = 3, sp = 1000))

p_10_1000 <- p + geom_smooth(method="gam", color="purple", formula = y ~ s(x, k = 10, sp = 1000))


p_100_1000 <- p + geom_smooth(method="gam", color="purple", formula = y ~ s(x, k = 100, sp = 1000))


p_1_1 <- p + geom_smooth(method="gam", color="purple", formula = y ~ s(x, k = 3, sp = 1))


p_10_1 <- p + geom_smooth(method="gam", color="purple", formula = y ~ s(x, k = 10, sp = 1))

p_100_1 <- p + geom_smooth(method="gam", color="purple", formula = y ~ s(x, k = 100, sp = 1))


p_1_0.1 <- p + geom_smooth(method="gam", color="purple", formula = y ~ s(x, k = 3, sp = 0.1))

p_10_0.1 <- p + geom_smooth(method="gam", color="purple", formula = y ~ s(x, k = 10, sp = 0.1))


p_100_0.1 <- p + geom_smooth(method="gam", color="purple", formula = y ~ s(x, k = 100, sp = 0.1))

labels <- c("", "", "", 
            "k = 3, sp = 1000", "k = 10, sp = 1000", "k = 100, sp = 1000",
            "k = 3, sp = 1", "k = 10, sp = 1", "k = 100, sp = 1",
            "k = 3, sp = 0.1", "k = 10, sp = 0.1", "k = 100, sp = 0.1"
)

plot_grid("", "", "", p_1_1000, p_10_1000, p_100_1000, p_1_1, p_10_1, p_100_1, p_1_0.1, p_10_0.1, p_100_0.1, ncol=3,
          labels=labels, label_size = 8, label_colour = "purple", vjust = 0.009) 