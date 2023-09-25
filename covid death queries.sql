--'use' database for future shorthand of table selection

use COVIDproj

--Select data that we are going to be using

select * 
from CovidDeaths$
order by 3,4

select 
	Location, 
	date, 
	total_cases, 
	new_cases, 
	total_deaths, 
	population
from CovidDeaths$
order by 1,2

--looking at total cases vs. total deaths, 'where' contraint for country specific data
--shows liklihood of dying from COVID in your country dependent on the date
-----when getting error for data type change to float for division

select 
	Location, 
	date, 
	total_cases, 
	total_deaths, 
	(total_deaths/total_cases)*100 AS Mortality_Rate
from CovidDeaths$
where location = 'United States'
order by 1,2

--Looking at total cases vs population
--shows what % of population has contracted covid in your country or all countries omitting 'where'

select 
	Location, 
	date, 
	total_cases, 
	population, 
	(total_cases/population)*100 AS Infection_Rate
from CovidDeaths$
--where location = 'United States'
order by 1,2

--countries with highest infection rate

select 
	Location, 
	population, 
	MAX(total_cases) AS MaxInfectionCount, 
	MAX((total_cases/population)*100) AS Infection_Rate
from CovidDeaths$
Group by location, population
order by Infection_Rate desc

--showing countries with highest death counts

select 
	Location, 
	MAX(total_deaths) AS MaxDeathCount
from CovidDeaths$
Where continent is not null
Group by location
order by MaxDeathCount desc


-- showing the continents with the highest death counts

select 
	continent, 
	MAX(total_deaths) AS MaxDeathCount
from CovidDeaths$
Where continent is not null
Group by continent
order by MaxDeathCount desc

--Global Numbers by date

select 
	date, 
	SUM(new_cases) AS all_new_cases, 
	SUM(new_deaths) AS all_new_deaths, 
	SUM(new_deaths)/SUM(new_cases)*100 AS Mortality_Rate
from CovidDeaths$
where continent is not null
Group by date
having SUM(new_cases) > 0 --for division by 0 error
order by 1

--World mortality overall

select 
	SUM(new_cases) AS all_new_cases, 
	SUM(new_deaths) AS all_new_deaths, 
	SUM(new_deaths)/SUM(new_cases)*100 AS Mortality_Rate
from CovidDeaths$
where continent is not null
having SUM(new_cases) > 0 

--Joining in the Vax data
--looking at total population vs vaccination per country over time
--cte for alias of cumulative_vax

with popvsvax as 
(Select 
	dea.continent, 
	dea.location, 
	dea.date, 
	dea.population, 
	vax.new_vaccinations, 
	SUM(vax.new_vaccinations) OVER (partition by dea.location order by dea.date) AS Cumulative_Vax
from CovidDeaths$ dea
join CovidVaccinations$ vax
	on dea.location = vax.location
	and dea.date = vax.date
where dea.continent is not null)

Select  * , 
		(cumulative_vax/population)*100 AS vax_rate
From Popvsvax
where new_vaccinations is not null --added to avoid null values in vaccinations administered in order to find max vax counts and final vax rates easier with less rows per location

--Using count to find how often each location reported COVID numbers

with popvsvax as 
(Select 
	dea.continent, 
	dea.location, 
	dea.date, 
	dea.population, 
	vax.new_vaccinations, 
	SUM(vax.new_vaccinations) OVER (partition by dea.location order by dea.date) AS Cumulative_Vax
from CovidDeaths$ dea
join CovidVaccinations$ vax
	on dea.location = vax.location
	and dea.date = vax.date
where dea.continent is not null)

Select 
	location, 
	COUNT(new_vaccinations) AS days_reported
From Popvsvax
group by location
Order by 2 desc


--this adjusts to show only the most recent cumulative vax #'s and vaccination rate per location

WITH Popvsvax AS
(SELECT 
	dea.location, 
	MAX(dea.population)as population, 
	SUM(vax.new_vaccinations) AS final_cumulative_vax,
	(SUM(vax.new_vaccinations) / MAX(dea.population)) * 100 AS final_vax_rate
FROM CovidDeaths$ dea
JOIN CovidVaccinations$ vax
    ON dea.location = vax.location
    AND dea.date = vax.date
WHERE dea.continent IS NOT NULL
GROUP BY dea.location)

SELECT  
	location,
	population,
	final_cumulative_vax,
	final_vax_rate
FROM Popvsvax
WHERE final_cumulative_vax IS NOT NULL
order by 3 desc;

--notice the rates above 100%, and consider how second doses and boosters effect this

--same thing but using a temp table

Drop Table if exists #percentpopulationvaccinated
Create Table #percentpopulationvaccinated
	(location nvarchar(255),
	population numeric,
	Final_cumulative_vax numeric,
	final_vax_rate numeric)

Insert into #percentpopulationvaccinated 
	(location, 
	population, 
	Final_cumulative_vax, 
	final_vax_rate)
Select 
	dea.location,  
	MAX(dea.population) as population, 
	SUM(vax.new_vaccinations) as Final_cumulative_vax,
	(SUM(vax.new_vaccinations) / MAX(dea.population)) * 100 AS final_vax_rate
from CovidDeaths$ dea
join CovidVaccinations$ vax
	on dea.location = vax.location
	and dea.date = vax.date
where dea.continent is not null
group by dea.location

SELECT 
	location,
	population,
	Final_cumulative_vax,
	final_vax_rate
FROM #percentpopulationvaccinated
WHERE final_vax_rate IS NOT NULL
order by 3 desc;


-- creating views to store data for later visualizing

Create view percentpopulationvaccinated as
Select 
	dea.continent, 
	dea.location, 
	dea.date, 
	dea.population, 
	vax.new_vaccinations, 
	SUM(vax.new_vaccinations) OVER (partition by dea.location order by dea.date) AS cumulative_Vax
from CovidDeaths$ dea
join CovidVaccinations$ vax
	on dea.location = vax.location
	and dea.date = vax.date
where dea.continent is not null