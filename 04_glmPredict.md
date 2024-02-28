How Predictive are Moneyline Bets?
================
Kyle Kurkela
2024-01-29

## requirements

External packages and functions required to run this report:

``` r
library(tidyverse)
library(RMariaDB)
library(implied)

calc_implied_probability <- function(x, method = 'basic'){
  # using the implied package, calculate the winning probability of a bet based
  # on the odds returns answer as a double

  require(implied)

  implied::implied_probabilities(x, method = method) %>% 
    magrittr::extract2('probabilities') %>% 
    as.double()

}
```

Initialize a connection to the MySQL database using the [RMariaDB R
package](https://rmariadb.r-dbi.org/index.html):

``` r
# username and password for the database are saved to local text files to avoid
# sharing them with the public
DB.user <- read_file(file = 'user.txt')
DB.pass <- read_file(file = 'password.txt')

# mysql database connection
db <- dbConnect(MariaDB(),
                user = DB.user,
                password = DB.pass,
                dbname = 'oddsDB',
                host = 'localhost')
```

## query data

…from the custom made MySQL database

``` sql
SELECT bets.id, name, price, bookie_id, pfmatch_id, `timestamp`, pfmatches.results_id, results.home_team, results.away_team, results.home_team_score, results.away_team_score FROM bets
LEFT JOIN pfmatches
  on bets.pfmatch_id = pfmatches.id
LEFT JOIN results
  on pfmatches.results_id = results.id
WHERE bookie_id IN ('draftkings', 'fanduel', 'pinnacle')
```

## Dataset Tidying

Below I “tidy” up this dataset by:  
1. Calculated the Log Odds (“logit”) implied by the price set by the
bookmakers.  
2. Removed a handful of problematic lines, where a team was predicted to
have a 0% chance of winning (and thus the odds and log odds were
infinite).  
3. Only look at select popular sportsbooks that can legally operate in
NY (FanDuel, DraftKings) and Pinnacle – a highly rated EU sportsbook.

``` r
# Note: R markdown saves the results from the above MySQL query in a custom R
# table. I named that table Odds.Tbl.tidy

# coerce to a tibble, and calculate:
# - price as a probability of winning (pricePer), 
# - the probability of winning implied by the price after accounting for sportsbooks' vigs
# - Odds and Log Odds (logit) to make them equivalent to those used in logistic regression
Odds.Tbl.tidy %>%
  as_tibble() %>%
  mutate(pricePer = 1/price) %>%
  group_by(pfmatch_id, timestamp, bookie_id) %>%
  mutate(impliedOdds = calc_implied_probability(price)) %>%
  ungroup() %>%
  mutate(Odds = pricePer/(1-pricePer)) %>%
  mutate(logit = log(Odds)) -> Odds.Tbl.tidy

# did bet win?
Odds.Tbl.tidy %>%
  mutate(win = case_when(name == home_team & home_team_score > away_team_score ~ TRUE,
                         name == away_team & away_team_score > home_team_score ~ TRUE,
                         .default = FALSE)) -> Odds.Tbl.tidy

# Remove problematic lines. For whatever reason, some bets in the database are
# listed at odds of 1.0, which implies a 0% chance of winning. These bets must
# be mistakes/errors -- no sportsbook would ever offer a bet nor would anyone
# ever take a bet where you cannot win any money.
Odds.Tbl.tidy %>%
  filter(!is.infinite(Odds)) -> Odds.Tbl.tidy

# Here I am coercing the column "bookie.id" to be a factor and then focing that
# factor to have treatment contrasts comparing the results to Pinnacle's odds --
# a sportsbook thought to be the gold standard against which others are
# compared.
Odds.Tbl.tidy %>%
  mutate(bookie_id = factor(bookie_id, levels = c('draftkings', 'fanduel', 'pinnacle'))) -> Odds.Tbl.tidy

contrasts(Odds.Tbl.tidy$bookie_id) <- contr.treatment(n = 3, base = 3)
```

4.  Only look at money line bets where the implied odds of winning were
    between 15% - 85%. In other words, excluding the heaviest of
    favorites and the longest of long shots. The NFL is known for being
    a competitively “balanced” league due to its structure of
    incorporating new players into the league, with the worst performing
    teams from the previous season having the first opportunity to
    rookie players to their teams, meaning that usually the worst teams
    get priority access to the best new players. This means that we very
    rarely have “super” underdogs and “super” favorites, resulting in a
    low sample size at these extremes.

``` r
ggplot(Odds.Tbl.tidy, aes(x = pricePer)) +
  geom_density(aes(y = after_stat(count), fill = win), position = 'stack') +
  geom_vline(xintercept = c(0.15, 0.85)) +
  labs(title = "Distribution of Moneyline Bets Offered on NFL Games from 2020-2024", 
       subtitle = "And how oftern those bets won or lost", 
       x = 'Likelihood of bet winning implied by the odds offered')
```

![](04_glmPredict_files/figure-gfm/unnamed-chunk-5-1.png)<!-- -->

As can be seen in the graph above, there is not a ton of observed data
for moneyline bets where the bet had less than a 15% chance to win OR
greater than 85% chance to win. Lets remove these extremes since the
sample sizes here are quite low.

``` r
# only look at bets where teams are estimated to have between a 15% and 85% chance of winning
Odds.Tbl.tidy %>%
  filter(pricePer > 0.15 & pricePer < 0.85) -> Odds.Tbl.tidy
```

# How accurate are moneyline odds at predicting outcomes of games?

To determine how accurate moneyline bets offered by sportsbook are at
predicting the outcomes of NFL games, we are going to build and compare
a couple of different logistic regression models.

## Do sports books charge a price on their moneyline bets?

First, IF odds offered by sports book were perfect predictors of the
outcomes of NFL games, then the best fitting model to our dataset should
be a logistic regression model where the intercept is set to zero and
the coefficient on the LogOdds offered by the sportsbooks is set to 1.
In other words, this model would suggest that when sports book say a
team has a 45% chance to win, they win 45% of the time. That model:

``` r
glm(win ~ 0, offset = logit, data = Odds.Tbl.tidy, family = 'binomial') -> model0.fit
```

An alternative model would suggest that sportsbooks as a whole
consistently overprice odds across the spectrum of odds offered. This
would make sense, since sportsbooks are looking to turn a profit. So if
a team had a 50% chance to win, the books would price their odds like
the team had a 55% chance to win. Sports would be collecting a profit or
“vig” on their moneyline bets. This would be capture by allowing the
intercept term to be something other than zero. If this model fit the
data better AND the intercept term was less than zero, it would imply
the existence of a “vig” in the market.

``` r
glm(win ~ 1, offset = logit, data = Odds.Tbl.tidy, family = 'binomial') -> model1.fit
```

Does a “perfect” model fit the data better than a “perfect world + vig”
model?

``` r
anova(model0.fit, model1.fit, test = 'Chisq')
```

    ## Analysis of Deviance Table
    ## 
    ## Model 1: win ~ 0
    ## Model 2: win ~ 1
    ##   Resid. Df Resid. Dev Df Deviance  Pr(>Chi)    
    ## 1      7880     9914.1                          
    ## 2      7879     9894.0  1   20.143 7.187e-06 ***
    ## ---
    ## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1

Yes it appears so. What is the size of the vig?

``` r
predict(model1.fit, newdata = tibble(logit = 0), type = 'response')
```

    ##         1 
    ## 0.4730342

The size of the vig in this market is approximately 2.7% (i.e., 0.5 -
0.473).

To answer the original question: yes, sports appear to overprice their
moneyline odds, incorporating about a 2.7% vig into their offered
moneyline bets.

## Do all sportsbooks add the same vig?

Do all of the sportsbook apply the same vig? IF sportsbook applied
different vigs in their markets, then we would expect a model that
incorporate sports book to fit better than a model (model 2 below) with
only an intercept term (model1).

``` r
glm(win ~ 1 + bookie_id, offset = logit, data = Odds.Tbl.tidy, family = 'binomial') -> model2.fit
```

``` r
anova(model1.fit, model2.fit, test = 'Chisq')
```

    ## Analysis of Deviance Table
    ## 
    ## Model 1: win ~ 1
    ## Model 2: win ~ 1 + bookie_id
    ##   Resid. Df Resid. Dev Df Deviance Pr(>Chi)
    ## 1      7879     9894.0                     
    ## 2      7877     9893.6  2   0.3695   0.8313

The answer is inconclusive. This dataset does not give us enough
evidence to reject the null hypothesis that the included sportsbooks
apply the same vig. It could be the case; perhaps the differences in the
vig applied are quite small between books and we would need a lot more
data to be certain.

I will note here that many online articles–including the sportsbook
itself–that suggest that Pinnacle charges substantially lower vigs
compared to competing sportsbooks.

## Is there any non-linearity in the sports books’ moneyline bet predictions?

Some people have written about a non-linearity in the sports betting
market, whereby vigs are greater for longshots then they are favorites.
Is there any evidence that this is the case for NFL moneylines?

To test this, I would expect a model that captures any non-linearity in
the relationship between odds offered and actual likelihood of the bet
to win to fit better than our simpler model.

``` r
# prob = 0 * 1*logit
glm(win ~ 1 + logit, data = Odds.Tbl.tidy, family = 'binomial') -> model3.fit
glm(win ~ 1 + logit + I(logit^2), data = Odds.Tbl.tidy, family = 'binomial') -> model4.fit
glm(win ~ 1 + logit + I(logit^2) + I(logit^3), data = Odds.Tbl.tidy, family = 'binomial') -> model5.fit
glm(win ~ 1 + logit + I(logit^2) + I(logit^3) + I(logit^4), data = Odds.Tbl.tidy, family = 'binomial') -> model6.fit
```

``` r
anova(model3.fit, model4.fit, model5.fit, model6.fit, test = "Chisq")
```

    ## Analysis of Deviance Table
    ## 
    ## Model 1: win ~ 1 + logit
    ## Model 2: win ~ 1 + logit + I(logit^2)
    ## Model 3: win ~ 1 + logit + I(logit^2) + I(logit^3)
    ## Model 4: win ~ 1 + logit + I(logit^2) + I(logit^3) + I(logit^4)
    ##   Resid. Df Resid. Dev Df Deviance Pr(>Chi)  
    ## 1      7878     9893.9                       
    ## 2      7877     9893.2  1   0.6729  0.41206  
    ## 3      7876     9887.7  1   5.4799  0.01924 *
    ## 4      7875     9887.4  1   0.3689  0.54363  
    ## ---
    ## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1

``` r
anova(model3.fit, model5.fit, test = "Chisq")
```

    ## Analysis of Deviance Table
    ## 
    ## Model 1: win ~ 1 + logit
    ## Model 2: win ~ 1 + logit + I(logit^2) + I(logit^3)
    ##   Resid. Df Resid. Dev Df Deviance Pr(>Chi)  
    ## 1      7878     9893.9                       
    ## 2      7876     9887.7  2   6.1528  0.04613 *
    ## ---
    ## Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1

Interestingly, a cubic model is the best fit to this dataset.

Lets see how this all looks in a couple of figures

## Figures

### Figure 1: Imperfect Sportsbook Predictions

``` r
# the "perfect prediction" model
Odds.Tbl.tidy$model0Predictions <- predict(model0.fit, type = 'response')

# the "perfect prediction + constant vig" model
Odds.Tbl.tidy$model1Predictions <- predict(model1.fit, type = 'response')

# the "perfect prediction + non-linear vig" model
Odds.Tbl.tidy$model5Predictions <- predict(model5.fit, type = 'response')

Odds.Tbl.tidy %>%
  ggplot(aes(x = pricePer, y = as.double(win))) +
  geom_density(aes(y = after_stat(count), fill = win), position = 'fill', alpha = 0.2) +
  geom_line(aes(y = model0Predictions), color = 'blue', linetype = 'solid', linewidth = 1) +
  labs(title = 'Sports Books Predicting NFL Games Outcomes',
       subtitle = "Moneyline Wagers Offered by NY Sportsbooks + Pinnacle, NFL seasons 2020-2024", 
       y = 'Predicted Chance A Moneyline Bet Will Win (Blue)', 
       x = 'Implied Probability a Bet Will Win from the Odds Offered on Bet') +
  scale_y_continuous(breaks = seq(0.2,0.8,0.2), 
                     sec.axis = sec_axis(trans = ~.*1, name = 'Proportion of Historical Bets Won (black)', 
                                         breaks = seq(0.2,0.8,0.2)))
```

![](04_glmPredict_files/figure-gfm/unnamed-chunk-16-1.png)<!-- -->

### Figure 2: Sports Moneyline Predictions are Imperfect by Design

``` r
Odds.Tbl.tidy %>%
  ggplot(aes(x = pricePer, y = as.double(win))) +
  geom_density(aes(y = after_stat(count), fill = win), position = 'fill', alpha = 0.2) +
  geom_line(aes(y = model0Predictions), color = 'blue', linetype = 'solid', linewidth = 1) +
  geom_line(aes(y = model1Predictions), color = 'red', linetype = 'solid', linewidth = 1) +
  annotate(geom = 'text', label = 'Perfect Prediction', color = 'blue', x = 0.5, y = 0.6, angle = 22) +
  labs(title = 'Accuracy Sports Books Predict NFL Games Outcomes',
       subtitle = "Moneyline Wagers Offered by NY Sportsbooks + Pinnacle, NFL seasons 2020-2024", 
       y = 'Predicted Chance A Moneyline Bet Will Win (Blue, Red)',
       x = 'Implied Probability a Bet Will Win from the Odds Offered on Bet') +
  scale_y_continuous(breaks = c(0.2, 0.4, 0.6, 0.8), 
                     sec.axis = sec_axis(trans = ~.*1, 
                                         name = 'Proportion of Historical Bets Won (black)', 
                                         breaks = seq(0.2,0.8,0.2)))
```

![](04_glmPredict_files/figure-gfm/unnamed-chunk-17-1.png)<!-- -->

### Figure 3: Non-linearity in the price’s offered?

``` r
Odds.Tbl.tidy %>%
  ggplot(aes(x = pricePer, y = as.double(win))) +
  geom_density(aes(y = after_stat(count), fill = win), position = 'fill', alpha = 0.2) +
  geom_line(aes(y = model0Predictions), color = 'blue', linetype = 'solid', linewidth = 1, alpha = 0.5) +
    geom_line(aes(y = model5Predictions), color = 'purple', linetype = 'solid', linewidth = 1) +
  annotate(geom = 'text', label = 'Perfect Prediction', color = 'blue', x = 0.5, y = 0.6, angle = 22) +
  labs(title = 'Accuracy Sports Books Predict NFL Games Outcomes',
       subtitle = "Moneyline Wagers Offered by NY Sportsbooks + Pinnacle, NFL seasons 2020-2024", 
       y = 'Predicted Chance A Moneyline Bet Will Win (Blue, Red)',
       x = 'Implied Probability a Bet Will Win from the Odds Offered on Bet') +
  scale_y_continuous(breaks = c(0.2, 0.4, 0.6, 0.8), 
                     sec.axis = sec_axis(trans = ~.*1, 
                                         name = 'Proportion of Historical Bets Won (black)', 
                                         breaks = seq(0.2,0.8,0.2)))
```

![](04_glmPredict_files/figure-gfm/unnamed-chunk-18-1.png)<!-- -->

``` r
dbDisconnect(db)
```

# What have I learned?

Sports books moneyline bets are pretty good predictors of the outcomes
of NFL games. Sportsbook appear to charge an approximate 2.3% vig on
their moneyline bets. There is some evidence that books do not charge a
constant vig in the NFL moneylines market.
