/*Code tested on SQL Server 2012 and Visual Studio Code (mssql extension), using only local temporary tables.
My code works as follow:
1. Creating Randoms 15000 objects(planets,monsters) and assigning them habitable bit if object is a planet
2. Creating Geometry Values for coordinates X,Y,Z
3. Calculating Distance from home planet
4. Choosing 10 closest habitable planets
5. Calculating time to colonize from home planet
6. Selecting ObjectIds that can be colonized in 24h*/

--Creating 2 temporary tables, 1st for 15000 objects, 2nd to populate 10 closest objects
IF OBJECT_ID('tempdb..#TempObjects') IS NOT NULL
    DROP TABLE #TempObjects

create table #TempObjects
(	ObjectId int PRIMARY KEY IDENTITY(1,1) NOT NULL,
	coordinateX int NOT NULL, 
	coordinateY int NOT NULL, 
	coordinateZ int NOT NULL, 
	ObjectType varchar(10),
	Habitable bit NULL,
	SquareKm int NULL,
	GeometryValue geometry NULL,
	DistanceForHome decimal(16,4) NULL
)
GO 
IF OBJECT_ID('tempdb..#TempObjectsFinal') IS NOT NULL
    DROP TABLE #TempObjectsFinal

create table #TempObjectsFinal
(	ObjectId int PRIMARY KEY NOT NULL,
	coordinateX int NOT NULL, 
	coordinateY int NOT NULL, 
	coordinateZ int NOT NULL, 
	ObjectType varchar(10),
	Habitable bit NULL,
	SquareKm int NULL,
	GeometryValue geometry NULL,
	DistanceForHome decimal(16,4) NULL,
	HoursToInhabit decimal(16,4) NULL
)
GO 

DECLARE @Counter int
DECLARE @Rand decimal(10,5)
DECLARE @MaxCoordinate int
DECLARE @ObjectsToCreate int
DECLARE @HomeGeoPoint geometry

SET @Counter = 1
SET @Rand = 0
SET @MaxCoordinate = 999999999
SET @ObjectsToCreate = 15000
SET @HomeGeoPoint = geometry::STGeomFromText('POINT(123123991 098098111 456456999)', 0); /*Home geometry point, used later for calculating distance from home planet*/

WHILE @Counter <= @ObjectsToCreate
	BEGIN
		SET @Rand = RAND() /*rand within a loop to save Object Type value for habitable bit*/
		INSERT INTO #TempObjects (coordinateX,coordinateY,coordinateZ,SquareKm,ObjectType,Habitable)
		SELECT 
			 ABS(CHECKSUM(NEWID())) % @MaxCoordinate -- Random number from 0 to @MaxCoordinate
			,ABS(CHECKSUM(NEWID())) % @MaxCoordinate -- Random number from 0 to @MaxCoordinate
			,ABS(CHECKSUM(NEWID())) % @MaxCoordinate -- Random number from 0 to @MaxCoordinate
			,ABS(CHECKSUM(NEWID())) % 1000000
			/* Around 15% objects to be Monster type*/
			,CASE WHEN @Rand >= 0.85 THEN 'Monster' 
			ELSE 'Planet' END
			/* Around 50% for planet to be habitable*/
			,CASE WHEN @Rand >= 0.85 THEN NULL
				WHEN @Rand < 0.85 AND RAND() >= 0.5 THEN 1 
				WHEN @Rand < 0.85 AND RAND() < 0.5 THEN 0 
				ELSE 0
				END

		SET @Counter = @Counter + 1 

	END

/*Creating GeometryValues and calcualting distance from Home Planet*/
UPDATE #TempObjects
SET GeometryValue = geometry::STGeomFromText('POINT(' + CAST(coordinateX as varchar) + ' ' +  CAST(coordinateY as varchar) + ' ' + CAST(coordinateY as varchar) + ')', 0); 
UPDATE #TempObjects
SET DistanceForHome =  @HomeGeoPoint.STDistance(GeometryValue);  


/*Inserting 10 closest habitable planets to home world into #TempObjectsFinal Table,
Total SquareKm divided by 2 to find out min SquareKm to colonize the planet, 
multipled by 0.43 which will give us total seconds needed to colonize,
divided by 60 to get minutes,
+20 for travel and return,
divided again by 60 to get hours */

INSERT INTO #TempObjectsFinal
	SELECT TOP 10	
			*,
			((((SquareKm/2) * 0.43)/60) +20)/60 	
	FROM #TempObjects
		WHERE	ObjectType = 'Planet' 
		AND Habitable = 1
	ORDER BY DistanceForHome asc

	 
/*Final SELECT, calculating running hours of each row until SUM is below 24*/
SELECT * FROM 
	(SELECT 
		ObjectId,
		HoursToInhabit,
		SUM(HoursToInhabit) OVER(ORDER BY HoursToInhabit ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS RunningHoursToInhabit
	FROM #TempObjectsFinal
	) Dtbl
WHERE RunningHoursToInhabit < 24

  





