-- Here is an organized list of how I went about the project

/*                                                        TASK 1
Familiarize yourself with the Mint Classic database and business processes.

Reverse engineered the EER, see the EER.png file uploaded to this repository. Viewed the relationships between entities.
*/

/*                                                        Task 2
Investigate the business problem and identify tables impacted.

Mint Classics wants to close a storage facility, or reorganize/reduce their inventory, while maintaining timely service to their customers.
Therefore, I theorized that we could exclude irrelevant tables: employees, customers, payments, and offices. This leaves us with warehouses,
products, productlines, orderdetails, and orders.

To begin digging, I first wanted to know some information regarding the warehouses. So I queried the warehouses tables to get an idea.
*/

select * from warehouses;

/*
We found that there are four warehouses, A,B,C, and D, or better yet, North (A), East (B), West (C), and South (D). Respectively,
their capacities are at North = 72%, East = 67%, West = 50%, and South = 75%.

With this information it seems if we can shut a location down it would be the west, since they are only at 50% capacity. To confirm,
let's take a look at the actual quantitative data within the warehouses.
*/

-- I began by just taking at look at the rest of the tables, and I noted any observations I felt were important

select * from products;
-- info regarding quantity in stock and prices. Could help determine the most profitable items and WH data...

select * from productlines;
-- unnecessary table actually, won't provide us insight into data driven decisions. Only contains qualitative data.

select * from orders;
/* info on shipping details... including date shipped and the required ship date (which I'm assuming is when the customer needs the
product by)... Could possibly help determine metrics on WH shipping */

select * from orderdetails;
-- info regarding quantity ordered, will further help with determining most profitable items...

--                                                      Task 3
/*
Formulate suggestions and recommendations for solving the business problem.

I began by summing up the total amount of products each warehouse contains, and how much free space each one then has.
*/

-- Used a CTE to avoid doing the same mathematical expressions more than once

WITH WarehouseData AS (
    SELECT
        WH.warehousecode AS WHC,
        WH.warehousename AS WHN,
        SUM(P.quantityinstock) AS QuantityInStock,
        CAST(WH.warehousepctcap AS DECIMAL(10,2)) / 100 AS WarehousePctCap
    FROM warehouses AS WH
    JOIN products AS P ON WH.warehousecode = P.warehousecode
    GROUP BY WH.warehousecode, WH.warehousename, WH.warehousepctcap
)
SELECT
    WHC,
    WHN,
    QuantityInStock,
    FLOOR(QuantityInStock / WarehousePctCap) - QuantityInStock AS SpaceLeftOver,
    FLOOR(QuantityInStock / WarehousePctCap) AS TotalSpaceInWH,
    WarehousePctCap * 100 as WHCapPct
FROM WarehouseData
ORDER BY TotalSpaceInWH DESC;

/*

WHC,     WHN,     QuantityInStock,     SpaceLeftOver,     TotalSpaceInWH,     WHCapPct
'b',    'East',      '219183',            '107955',          '327138',       '67.000000'
'c',    'West',      '124880',            '124880',          '249760',       '50.000000'
'a',    'North',     '131688',            '51212',            '182900',      '72.000000'
'd',    'South',      '79380',            '26460',            '105840',       '75.000000'

From this we can see a pattern in the storage locations. Beginning with the East location, each facility differs in size to roughly 60,000-
80,000 products, with the South being the smallest location at only 105,840 max capacity.

Now knowing this, a shutdown of the West location doesn't seem ideal, and instead, it looks to be a prime candidate to host a merger
with the South location considering that they are at the lowest capacity (50%) while maintaining the second largest storage space (249,760).
It seems as though the West location is being underutilized. Before we make this suggestion, however, let's look at some more data to
back up this decision.

For example, in the case this merger does happen and the West location absorbs all of the South's stock, will we then be overstocking?
Will this merger create a backup in shipping for clients that the South typically deals with?

Let's explore.

*/

-- I wanted to begin by seeing the capacity the West Location would be at in the scenario it absorbed all of the South's stock. So, we ran

WITH WarehouseData AS (
	SELECT
		WH.warehousecode as WHC,
		WH.warehousename as WHN,
		SUM(P.quantityinstock) as QuantityInStock,
		CAST(WH.warehousepctcap AS DECIMAL(10,2)) / 100 AS WarehousePctCap
	FROM warehouses as WH
	JOIN products AS P ON WH.warehousecode = P.warehousecode
	GROUP BY WH.warehousecode, WH.warehousename, WH.warehousepctcap
),
MergedData AS (
	SELECT
		SUM(QuantityInStock) AS MergedInStock
	FROM WarehouseData
    WHERE WHN IN ('West', 'South')
)
SELECT
	WHN,
	MergedInStock,
    FLOOR(QuantityInStock / WarehousePctCap) AS TotalWHSpace,
    CAST(MergedInStock / (QuantityInStock / WarehousePctCap)AS DECIMAL(10,2)) * 100 AS MergedWHCapPct
FROM WarehouseData
JOIN MergedData ON WarehouseData.WHN IN ('West', 'South')
WHERE WHN = 'West';

/* And the results were:

WHN,     MergedInStock,     TotalWHSpace,     MergedWHCapPct
West,       204260,            249760,            82.00

Putting them at an 82% capacity doesn't sound so bad to me considering they would be able to close an entire location down. Also,
after a quick Google search to find what the ideal warehouse capacity is, it said close to 80%. This further strengthens our proposal
to move all of South's inventory over to the West location. However, let's make sure that in doing so, we will not be hurting the
shipping times and overall service to their customers.

Let's begin by looking into ...



