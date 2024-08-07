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

warehouseCode	warehouseName	warehousePctCap

    a		   North		72
    b		   East			67
    c		   West			50
    d		   South		75

With this information it seems if we can shut a location down it would be the west, since they are only at 50% capacity. To confirm,
let's take a look at the actual quantitative data within the warehouses.
*/

-- I began by just taking at look at the rest of the tables, and I noted any observations I felt were important

select * from products;
-- info regarding quantity in stock and prices. Could help determine the most profitable items and WH data...

select * from productlines;
-- Qualitative data, could be useful for selling metrics...

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

WHC     WHN     QuantityInStock     SpaceLeftOver     TotalSpaceInWH     WHCapPct

 b      East        219183             107955           327138          67.000000
 c      West        124880             124880           249760          50.000000
 a      North       131688             51212            182900          72.000000
 d      South       79380              26460            105840          75.000000

From this we can see a pattern in the storage locations. Beginning with the East location, each facility differs in size to roughly 60,000-
80,000 products, with the South being the smallest location at only 105,840 max capacity.

Now knowing this, a shutdown of the West location doesn't seem ideal, and instead, it looks to be a prime candidate to host a merger
with the South location considering that the West has the lowest capacity (50%) while maintaining the second largest storage space (249,760).
It seems as though the West location is being underutilized. Before we make this suggestion, however, let's look at some more data to
back up this decision.

For example, in the case this merger does happen and the West location absorbs all of the South's stock, will we then be overstocked?
Will this merger negatively affect shipping for clients that the South typically dealt with?

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

WHN     MergedInStock     TotalWHSpace     MergedWHCapPct

West       204260            249760            82.00

Putting them at an 82% capacity doesn't sound so bad to me considering they would be able to close an entire location down, thus saving
a lot of money. Also, after a quick Google search to find what the ideal warehouse capacity is, it said close to 80%. This further
strengthens our proposal to move all of South's inventory over to the West location. However, let's make sure that in doing so, we will
not be hurting the shipping times and overall service to their customers.

Let's begin by looking into the average shipping metrics of each storage location.
*/

SELECT
	WH.warehouseName AS WHN,
	COUNT(DISTINCT O.orderNumber) AS TotalOrders,
	AVG(DATEDIFF(O.shippedDate, O.orderDate)) AS AvgOrderToShipTime,
	AVG(DATEDIFF(O.requiredDate, O.shippedDate)) AS AvgShippingDeadline
FROM orders AS O
JOIN orderDetails AS OD ON O.orderNumber = OD.orderNumber
JOIN products AS P ON OD.productCode = P.productCode
JOIN warehouses AS WH ON P.warehouseCode = WH.warehouseCode
WHERE O.shippedDate IS NOT NULL
  AND O.orderDate IS NOT NULL
  AND O.requiredDate IS NOT NULL
  AND O.shippedDate >= O.orderDate
  AND O.requiredDate >= O.shippedDate
GROUP BY WH.warehouseName
ORDER BY AvgShippingDeadline DESC;

/* And here were the results:

WHN	TotalOrders	AvgOrderToShipTime	AvgShippingDeadline

South	   136			3.3114			4.8426
East	   199			3.3936			4.8202
West	   175			3.5178			4.6262
North	   113			3.8930			4.1813

From this we can see that the South's operational efficiency is the best of all four locations. They get their orders out the door the
quickest of all four locations (3.3114 days on average), and they also have the largest amount of buffer from the time they ship to
the time the package needs to be delivered (4.8426 days on average). This indicates that they would be best suited of the four locations to
absorb any negative affects from a merger. Additionally, the good practices used in the South just may provide some improvement for the
West location.

Now, let's take a more detailed look at how to best optimize this merger. Let's dive into the productLines to see if either location
carries productLines with high turnover rates, which may pose as a challenge and something to plan for during the merger.
*/

WITH WarehouseProductSales AS (
    SELECT
        PL.productLine AS ProductLine,
        SUM(OD.quantityOrdered) AS TotalQuantitySold
    FROM orderdetails AS OD
    JOIN products AS P ON OD.productCode = P.productCode
    JOIN productlines AS PL ON P.productLine = PL.productLine
    JOIN warehouses AS WH ON P.warehouseCode = WH.warehouseCode
    WHERE WH.warehousename IN ('West', 'South')
    GROUP BY PL.productLine
),
WarehouseProductInventory AS (
    SELECT
        PL.productLine AS ProductLine,
        SUM(P.quantityInStock) AS TotalInventory
    FROM products AS P
    JOIN productlines AS PL ON P.productLine = PL.productLine
    JOIN warehouses AS WH ON P.warehouseCode = WH.warehouseCode
    WHERE WH.warehousename IN ('West', 'South')
    GROUP BY PL.productLine
)
SELECT
    WHSales.ProductLine,
    WHSales.TotalQuantitySold,
    WHInventory.TotalInventory,
    CASE
        WHEN WHInventory.TotalInventory = 0 THEN NULL
        ELSE ROUND((WHSales.TotalQuantitySold / WHInventory.TotalInventory) * 100)
    END AS TurnoverRate
FROM WarehouseProductSales AS WHSales
JOIN WarehouseProductInventory AS WHInventory ON WHSales.ProductLine = WHInventory.ProductLine
ORDER BY TurnoverRate DESC;

/* And here were the results:

ProductLine	TotalQuantitySold	TotalInventory		TurnoverRate

Ships			8532		    26833		     32
Trucks and Buses	11001		    35851		     31
Vintage Cars		22933		    124880		     18
Trains			2818		    16696		     17

Since I am not an expert in vehicular warehouse management, I'm not entirely sure if a 32% turnover rate is good or not. However,
logically thinking with this information, I would suggest carrying less trains and vintage cars in the warehouse, since their 
turnover rate is so low, and instead backorder more ships, trucks, and buses; as they have almost double as high of a turnover rate.
This would help minimize the possibility of shipping delays from running out of stock or waiting for shipments to come in, and in
overall, help to create a smooth merger between the West and the South.
*/

--                                                      Task 4
/*
Conclusion

In the end, the evidence all points to a merger between the West and South warehouse locations. The West location would host this merger,
absorbing all of the inventory that was being kept at the South location. Apart from the money that will be saved by closing an entire
warehouse, various metrics also show that this merger is the most beneficial for the company when considering all four locations.
This is due to the fact that the West had the most available space (currently only at 50% capacity) allowing it to still retain an 82%
capacity after the merger. Based on my research, 80% warehouse capacity is an ideal capacity to be at. Furthermore, considering that
the South's operational efficiency is the best of the four locations, it is best suited to partake in a merger that may negatively affect
shipping and handling times. To mitigate this risk, I advise to fire sale as many vintage cars and trains as you can and then order more
ships, trucks, and buses. This is due to the fact that the turnover rate for ships, trucks, and buses is nearly twice as high as vintage
cars and trains. Therefore, it can help prevent any delays that may occur if there is an uptick in orders.

Thank you so much for taking the time out to read through my project, I really enjoyed analyzing Mint Classics!
*/
