-- All sports available on the odds-api
CREATE TABLE `SPORTS`(
    `id` VARCHAR(25) NOT NULL,
    `title` VARCHAR(25) NOT NULL,
PRIMARY KEY (id));
CREATE TABLE `BOOKIES`(
	`id` VARCHAR(25) NOT NULL,
    `title` VARCHAR(50) NOT NULL,
PRIMARY KEY (`id`));
CREATE TABLE `MARKETS`(
    `id` VARCHAR(50) NOT NULL,
    `title` VARCHAR(50) NOT NULL,
    `description` VARCHAR(125) NOT NULL,
    `note` VARCHAR(20),
PRIMARY KEY (`id`));
CREATE TABLE `COMPETITIONS`(
    `id` VARCHAR(100) NOT NULL,
    `title` VARCHAR(100) NOT NULL,
    `sport_id` VARCHAR(100) NOT NULL,
PRIMARY KEY (`id`),
FOREIGN KEY (`sport_id`) REFERENCES SPORTS(`id`));
CREATE TABLE `TEAMS`(
    `team_name` VARCHAR(50) NOT NULL,
    `sport_id` VARCHAR(50) NOT NULL,
PRIMARY KEY (`team_name`),
FOREIGN KEY (`sport_id`) REFERENCES SPORTS(`id`));
CREATE TABLE `RESULTS`(
    `id` VARCHAR(32) NOT NULL,
	`sport_key` VARCHAR(50) NOT NULL,
    `competition_id` VARCHAR(50) NOT NULL,
    `home_team` VARCHAR(50) NOT NULL,
    `away_team` VARCHAR(50) NOT NULL,
    `home_team_score` INT,
    `away_team_score` INT,
    `season` INT,
    `Week` VARCHAR(50),
    `commence_time` DATETIME NOT NULL,
PRIMARY KEY (id),
FOREIGN KEY (sport_key) REFERENCES SPORTS(id),
FOREIGN KEY (competition_id) REFERENCES COMPETITIONS(id),
FOREIGN KEY (home_team) REFERENCES TEAMS(team_name),
FOREIGN KEY (away_team) REFERENCES TEAMS(team_name)
);
CREATE TABLE `PFMATCHES`(
    `id` VARCHAR(32) NOT NULL,
	`sport_key` VARCHAR(50) NOT NULL,
    `competition_id` VARCHAR(50) NOT NULL,
    `home_team` VARCHAR(50) NOT NULL,
    `away_team` VARCHAR(50) NOT NULL,
    `commence_time` DATETIME NOT NULL,
    `results_id` VARCHAR(50),
PRIMARY KEY (id),
FOREIGN KEY (sport_key) REFERENCES SPORTS(id),
FOREIGN KEY (competition_id) REFERENCES competitions(id),
FOREIGN KEY (home_team) REFERENCES TEAMS(team_name),
FOREIGN KEY (away_team) REFERENCES TEAMS(team_name),
FOREIGN KEY (results_id) REFERENCES RESULTS(id)
);
CREATE TABLE `BETS`(
    `id` VARCHAR(50) NOT NULL,
    `name` VARCHAR(50) NOT NULL,
    `price` FLOAT,
    `bookie_id` VARCHAR(50) NOT NULL,
    `markets_key` VARCHAR(50) NOT NULL,
    `pfmatch_id` VARCHAR(32) NOT NULL,
    `timestamp` timestamp NOT NULL,
PRIMARY KEY (`id`),
FOREIGN KEY (`bookie_id`) REFERENCES BOOKIES(`id`),
FOREIGN KEY (`pfmatch_id`) REFERENCES PFMATCHES(`id`));