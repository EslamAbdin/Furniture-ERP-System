-- Costing: Total Raw material cost per product 
SELECT p.ProductID, p.ProductName,
SUM(pr.RequiredQty * rm.UnitCost) AS TotalMaterialCost
FROM Inventory.Products p 
JOIN Inventory.ProductRecipe pr 
ON p.ProductID = pr.ProductID
JOIN Inventory.RawMaterials rm 
ON pr.MaterialID = rm.MaterialID
GROUP BY p.ProductID, p.ProductName;
GO

-- Efficiency: Labor cost per Work Order
SELECT wo.WorkOrderID, 
SUM((DATEDIFF(MINUTE, we.StartTime, ISNULL(we.EndTime, GETDATE())) / 60.0)
* (e.Salary / 160.0)) AS LaborCost
FROM Production.WorkOrders wo 
JOIN Production.WorkOrderExecution we
ON wo.WorkOrderID = we.WorkOrderID
JOIN HR.Employees e 
ON we.EmployeeID = e.EmployeeID
GROUP BY wo.WorkOrderID;
GO

-- Performance: The most productive workshops
SELECT w.WorkshopID,w.UnitCode,
COUNT(we.ExecutionID) AS TotalExecutions
FROM Production.Workshops w 
JOIN Production.WorkOrderExecution we 
ON w.WorkshopID = we.WorkshopID
GROUP BY w.WorkshopID, w.UnitCode
ORDER BY TotalExecutions DESC;
GO

-- Logistics: Fast Tracking (Simple Lookup)
SELECT * FROM Logistics.TripCargo
WHERE SerialNumber = 'SN-FORCED-100000-668';
GO

-- Maintenance: Asset Maintenance Cost Analysis
SELECT ta.AssetName,
SUM(ml.Cost) AS TotalMaintenanceCost
FROM Production.ToolAssets ta 
JOIN Production.MaintenanceLogs ml 
ON ta.AssetID = ml.AssetID
GROUP BY ta.AssetName
ORDER BY TotalMaintenanceCost DESC;
GO

-- CRM: Total Sales per Client
SELECT c.ClientName,
SUM(soi.QuantityOrdered * soi.UnitPrice) AS TotalSales
FROM Sales.SalesOrders so 
JOIN Sales.Clients c 
ON so.ClientID = c.ClientID 
JOIN Sales.SalesOrderItems soi 
ON so.SalesOrderID = soi.SalesOrderID
GROUP BY c.ClientName;
GO

-- Finance: Monthly Sales Report
SELECT YEAR(so.OrderDate) AS [Year], 
MONTH(so.OrderDate) AS [Month], 
SUM(soi.QuantityOrdered * soi.UnitPrice) AS MonthlySales
FROM Sales.SalesOrders so 
JOIN Sales.SalesOrderItems soi 
ON so.SalesOrderID = soi.SalesOrderID
GROUP BY YEAR(so.OrderDate), MONTH(so.OrderDate);
GO

-- Marketing: Product Sales Ranking
SELECT p.ProductName,SUM(soi.QuantityOrdered) AS TotalQuantitySold
FROM Inventory.Products p 
JOIN Sales.SalesOrderItems soi 
ON p.ProductID = soi.ProductID
GROUP BY p.ProductName
ORDER BY TotalQuantitySold DESC;
GO

-- HR: Employees per Department
SELECT d.DeptName,
COUNT(e.EmployeeID) AS EmployeeCount
FROM HR.Departments d 
LEFT JOIN HR.Employees e 
ON d.DepartmentID = e.DepartmentID
GROUP BY d.DeptName;
GO

-- HR: Average Salary per Department
SELECT d.DeptName,
AVG(e.Salary) AS AvgSalary
FROM HR.Departments d 
JOIN HR.Employees e 
ON d.DepartmentID = e.DepartmentID
GROUP BY d.DeptName;
GO

-- Procurement: Materials Received per Purchase Order
SELECT PurchaseOrderID, 
SUM(QuantityReceived) AS TotalReceived
FROM Inventory.MaterialBatches
GROUP BY PurchaseOrderID;
GO

-- Finance: Total Inventory Value
SELECT SUM(StockLevel * UnitCost) AS TotalInventoryValue
FROM Inventory.RawMaterials;
GO

-- Data Integrity: Orders Without Items (QA Check)
SELECT so.SalesOrderID
FROM Sales.SalesOrders so 
LEFT JOIN Sales.SalesOrderItems soi 
ON so.SalesOrderID = soi.SalesOrderID
WHERE soi.SalesOrderID IS NULL;
GO

-- Business Insight: Products Never Sold (Left Join Check)
SELECT p.ProductName
FROM Inventory.Products p 
LEFT JOIN Sales.SalesOrderItems soi 
ON p.ProductID = soi.ProductID
WHERE soi.ProductID IS NULL;
GO

-- Subquery: Top-Selling Products 
SELECT ProductName
FROM Inventory.Products
WHERE ProductID IN (
    SELECT ProductID
    FROM Sales.SalesOrderItems
    GROUP BY ProductID
    HAVING SUM(QuantityOrdered) > 1000
);
GO
--Subquery: above AVG Employees
SELECT FullName, Salary
FROM HR.Employees
WHERE Salary > (SELECT AVG(Salary) FROM HR.Employees);
GO

-----views
CREATE OR ALTER VIEW Sales.vw_SalesOrderSummary AS
SELECT so.SalesOrderID, c.ClientName, p.ProductName, soi.QuantityOrdered, soi.UnitPrice
FROM Sales.SalesOrders so 
JOIN Sales.Clients c 
ON so.ClientID = c.ClientID
JOIN Sales.SalesOrderItems soi 
ON so.SalesOrderID = soi.SalesOrderID
JOIN Inventory.Products p 
ON soi.ProductID = p.ProductID;
GO

--Production View: Live Production Status
CREATE OR ALTER VIEW Production.vw_ProductionStatus AS
SELECT si.SerialNumber, p.ProductName, si.CurrentStatus,l.City AS Destination
FROM Production.SerialItems si 
JOIN Inventory.Products p 
ON si.ProductID = p.ProductID
JOIN Logistics.Locations l 
ON si.DestinationLocationID = l.LocationID;
GO

-- Sales View: Sales Summary with Calculated Column
CREATE OR ALTER VIEW Sales.vw_SalesSummary AS
SELECT so.SalesOrderID, c.ClientName, 
SUM(soi.QuantityOrdered * soi.UnitPrice) AS OrderTotal
FROM Sales.SalesOrders so 
JOIN Sales.Clients c 
ON so.ClientID = c.ClientID 
JOIN Sales.SalesOrderItems soi 
ON so.SalesOrderID = soi.SalesOrderID
GROUP BY so.SalesOrderID, c.ClientName;
GO
------------
--cte
-----------
-- Production Unit Economics (CTE)
-- Purpose: Calculate true cost per item (Material + Man-Hours).
-- Logic: 
--   1. MaterialCosts: Sum of all parts in the recipe.
--   2. LaborCosts: Actual minutes worked * (Monthly Salary / 160 hours).
WITH MaterialCosts AS (
    SELECT wo.WorkOrderID, wo.ProductID,
        SUM(pr.RequiredQty * rm.UnitCost) AS Total_Material_Cost_Per_Unit
    FROM Production.WorkOrders wo
    JOIN Inventory.Products p ON wo.ProductID = p.ProductID
    JOIN Inventory.ProductRecipe pr ON p.ProductID = pr.ProductID
    JOIN Inventory.RawMaterials rm ON pr.MaterialID = rm.MaterialID
    GROUP BY wo.WorkOrderID, wo.ProductID
),
LaborCosts AS (
    SELECT wo.WorkOrderID,
    COUNT(DISTINCT we.EmployeeID) AS Employees_Assigned,
    SUM((DATEDIFF(MINUTE, we.StartTime, ISNULL(we.EndTime, GETDATE())) / 60.0) * (e.Salary / 160.0)) AS Total_Labor_Cost
    FROM Production.WorkOrders wo
    JOIN Production.WorkOrderExecution we ON wo.WorkOrderID = we.WorkOrderID
    JOIN HR.Employees e ON we.EmployeeID = e.EmployeeID
    GROUP BY wo.WorkOrderID
),
ProductionSummary AS (
    SELECT p.ProductID,p.ProductName,
    COUNT(wo.WorkOrderID) AS Total_Work_Orders,
    SUM(wo.BatchSize) AS Total_Units_Produced,
    AVG(ISNULL(mc.Total_Material_Cost_Per_Unit, 0)) AS Avg_Material_Cost,
    AVG(ISNULL(lc.Total_Labor_Cost, 0)) AS Avg_Labor_Cost
    FROM Inventory.Products p
    JOIN Production.WorkOrders wo ON p.ProductID = wo.ProductID
    LEFT JOIN MaterialCosts mc ON wo.WorkOrderID = mc.WorkOrderID
    LEFT JOIN LaborCosts lc ON wo.WorkOrderID = lc.WorkOrderID
    GROUP BY p.ProductID, p.ProductName
)
SELECT ProductID, ProductName, Total_Work_Orders, Total_Units_Produced,
    FORMAT(Avg_Material_Cost, 'C', 'ar-EG') AS Avg_Material_Cost,
    FORMAT(Avg_Labor_Cost, 'C', 'ar-EG') AS Avg_Labor_Cost,
    FORMAT(Avg_Material_Cost + Avg_Labor_Cost, 'C', 'ar-EG') AS Total_Avg_Cost_Per_Order,
    FORMAT((Avg_Material_Cost + Avg_Labor_Cost) / 
    NULLIF(Total_Units_Produced / NULLIF(Total_Work_Orders, 0), 0), 
    'C', 'ar-EG') AS Cost_Per_Unit
FROM ProductionSummary
WHERE Total_Work_Orders > 0 
ORDER BY (Avg_Material_Cost + Avg_Labor_Cost) DESC;
GO

-- Employee Productivity Ranking (CTE)
-- Purpose: Find top performers using Percentiles and Deciles.
-- Logic:
--   1. Units_Per_Hour = Total Units Made / Total Hours Worked.
--   2. Percentile_Rank = Shows where they stand compared to 100% of staff.
WITH EmployeeRawStats AS ( 
    SELECT e.EmployeeID, e.FullName, e.JobTitle, d.DeptName, e.Salary,
        COUNT(DISTINCT we.WorkOrderID) AS Work_Orders_Completed,
        COUNT(we.SerialNumber) AS Total_Units_Produced,
        SUM(DATEDIFF(MINUTE, we.StartTime, ISNULL(we.EndTime, GETDATE())) / 60.0) AS Total_Hours_Worked
    FROM HR.Employees e
    JOIN HR.Departments d ON e.DepartmentID = d.DepartmentID
    JOIN Production.WorkOrderExecution we ON e.EmployeeID = we.EmployeeID
    GROUP BY e.EmployeeID, e.FullName, e.JobTitle, d.DeptName, e.Salary
),
ProductivityCalculations AS (
    SELECT *, CAST(Total_Units_Produced AS FLOAT) / NULLIF(Total_Hours_Worked, 0) AS Units_Per_Hour
    FROM EmployeeRawStats
    WHERE Work_Orders_Completed > 0
),
ProductivityRanking AS (
    SELECT *,
        PERCENT_RANK() OVER (ORDER BY Units_Per_Hour DESC) AS Productivity_Percentile,
        NTILE(10) OVER (ORDER BY Units_Per_Hour DESC) AS Performance_Decile,
        ROW_NUMBER() OVER (PARTITION BY DeptName ORDER BY Units_Per_Hour DESC) AS Dept_Rank,
        AVG(Units_Per_Hour) OVER (PARTITION BY DeptName) AS Dept_Avg_Productivity,
        AVG(Units_Per_Hour) OVER () AS Company_Avg_Productivity
    FROM ProductivityCalculations
)
SELECT 
    EmployeeID, FullName, JobTitle, DeptName,
    FORMAT(Salary, 'C', 'ar-EG') AS Salary,
    Work_Orders_Completed, Total_Units_Produced,
    ROUND(Total_Hours_Worked, 2) AS Total_Hours_Worked,
    ROUND(Units_Per_Hour, 2) AS Productivity_Rate,
    ROUND(Company_Avg_Productivity, 2) AS Company_Avg,
    ROUND(Dept_Avg_Productivity, 2) AS Dept_Avg,
    ROUND((Units_Per_Hour - Dept_Avg_Productivity) / NULLIF(Dept_Avg_Productivity, 0) * 100, 2) AS Variance_From_Dept_Avg_Pct,
    Dept_Rank, Performance_Decile,
    ROUND(Productivity_Percentile * 100, 2) AS Percentile_Rank,
    CASE 
        WHEN Performance_Decile <= 2 THEN 'Top Performer'
        WHEN Performance_Decile <= 5 THEN 'Above Average'
        WHEN Performance_Decile <= 8 THEN 'Average'
        ELSE 'Needs Improvement'
    END AS Performance_Category,
    CASE 
        WHEN Performance_Decile <= 2 THEN 'Bonus Eligible'
        WHEN Performance_Decile >= 9 THEN 'Training Recommended'
        ELSE 'Standard'
    END AS HR_Action
FROM ProductivityRanking
ORDER BY Units_Per_Hour DESC;
GO
-----STORED PROCEDURES
CREATE OR ALTER PROCEDURE Sales.sp_ProcessNewOrder
    @ClientID INT,
    @ProductID INT,
    @Quantity INT,
    @BillingMethod NVARCHAR(50) = 'Standard', -- Replaces OrderType
    @LocationID INT = NULL,                   -- Replaces RouteID
    @SalesOrderID INT OUTPUT,
    @StatusMessage NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Validation 1: Check if client exists
        IF NOT EXISTS (SELECT 1 FROM Sales.Clients WHERE ClientID = @ClientID)
        BEGIN
            SET @StatusMessage = 'Error: Client does not exist';
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Validation 2: Check if product exists and get price
        DECLARE @UnitPrice DECIMAL(18,2);
        SELECT @UnitPrice = BasePrice FROM Inventory.Products WHERE ProductID = @ProductID;

        IF @UnitPrice IS NULL
        BEGIN
            SET @StatusMessage = 'Error: Product does not exist';
            ROLLBACK TRANSACTION;
            RETURN -2;
        END
        
        -- Validation 3: Check material availability using Product Recipe
        DECLARE @MaterialShortage INT = 0;
        
        SELECT @MaterialShortage = COUNT(*)
        FROM Inventory.ProductRecipe pr
        JOIN Inventory.RawMaterials rm ON pr.MaterialID = rm.MaterialID
        WHERE pr.ProductID = @ProductID
          AND rm.StockLevel < (pr.RequiredQty * @Quantity);
        
        IF @MaterialShortage > 0
        BEGIN
            SET @StatusMessage = 'Warning: Insufficient materials for order. Production may be delayed.';
        END
        
        -- Create the Sales Order
        INSERT INTO Sales.SalesOrders (ClientID, OrderDate, BillingMethod, TotalRevenue)
        VALUES (@ClientID, GETDATE(), @BillingMethod, (@UnitPrice * @Quantity));
        
        SET @SalesOrderID = SCOPE_IDENTITY();
        
        -- Add Product to Order Items
        INSERT INTO Sales.SalesOrderItems (SalesOrderID, ProductID, QuantityOrdered, UnitPrice)
        VALUES (@SalesOrderID, @ProductID, @Quantity, @UnitPrice);
        
        -- Create Work Order (Production)
        INSERT INTO Production.WorkOrders (SalesOrderID, ProductID, BatchSize, InstructionType, Status)
        VALUES (@SalesOrderID, @ProductID, @Quantity, 'Standard', 'Pending');
        
        -- Link Location if provided (Logistics Prep)
        IF @LocationID IS NOT NULL
        BEGIN
            -- Ensure the location is linked to the client
            IF NOT EXISTS (SELECT 1 FROM Sales.ClientLocations WHERE ClientID = @ClientID AND LocationID = @LocationID)
            BEGIN
                INSERT INTO Sales.ClientLocations (ClientID, LocationID, IsPrimary)
                VALUES (@ClientID, @LocationID, 0);
            END
        END
        
        COMMIT TRANSACTION;
        
        IF @StatusMessage IS NULL OR @StatusMessage = ''
            SET @StatusMessage = 'Success: Sales Order ' + CAST(@SalesOrderID AS NVARCHAR) + ' created successfully.';
        
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        SET @StatusMessage = 'Error: ' + ERROR_MESSAGE();
        RETURN -99;
    END CATCH
END;
GO

-- 2. AUTOMATED INVENTORY REORDER SYSTEM
CREATE OR ALTER PROCEDURE Inventory.sp_AutoReorderMaterials
    @ReorderThreshold FLOAT = 20.0,
    @MaxOrderValue DECIMAL(18,2) = 50000.00,
    @DryRun BIT = 0  -- 1 = Preview, 0 = Execute
AS
BEGIN
    SET NOCOUNT ON;

    -- Temporary table for reorder recommendations
    CREATE TABLE #ReorderRecommendations (
        MaterialID INT,
        MaterialName NVARCHAR(255),
        CurrentStock FLOAT,
        RecommendedOrderQty INT,
        EstimatedCost DECIMAL(18,2),
        SupplierID INT,
        SupplierName NVARCHAR(255),
        PriorityLevel NVARCHAR(20)
    );
    
    -- Identify materials needing reorder
    INSERT INTO #ReorderRecommendations
    SELECT 
        rm.MaterialID,
        rm.MaterialName,
        rm.StockLevel,
        -- Logic: Order enough to reach threshold + buffer (rounded up to nearest 10)
        CEILING(((@ReorderThreshold * 2) - rm.StockLevel) / 10.0) * 10 AS RecommendedOrderQty,
        -- Cost Calculation
        (CEILING(((@ReorderThreshold * 2) - rm.StockLevel) / 10.0) * 10) * rm.UnitCost AS EstimatedCost,
        s.SupplierID,
        s.SupplierName,
        CASE 
            WHEN rm.StockLevel < 10 THEN 'CRITICAL'
            ELSE 'HIGH'
        END AS PriorityLevel
    FROM Inventory.RawMaterials rm
    -- Find a supplier (First match)
    CROSS APPLY (SELECT TOP 1 * FROM Inventory.Suppliers) s 
    WHERE rm.StockLevel < @ReorderThreshold;
    
    -- Show recommendations
    SELECT * FROM #ReorderRecommendations ORDER BY EstimatedCost DESC;
    
    -- Execute Orders (If not Dry Run)
    IF @DryRun = 0
    BEGIN
        DECLARE @MatID INT, @SupID INT, @Qty INT, @Cost DECIMAL(18,2);
        DECLARE @TotalCost DECIMAL(18,2) = 0;
        
        DECLARE reorder_cursor CURSOR FOR
        SELECT MaterialID, SupplierID, RecommendedOrderQty, EstimatedCost
        FROM #ReorderRecommendations
        ORDER BY PriorityLevel DESC;
        
        OPEN reorder_cursor;
        FETCH NEXT FROM reorder_cursor INTO @MatID, @SupID, @Qty, @Cost;
        
        WHILE @@FETCH_STATUS = 0 AND (@TotalCost + @Cost) <= @MaxOrderValue
        BEGIN
            -- Create Purchase Order
            DECLARE @POID INT;
            INSERT INTO Inventory.PurchaseOrders (SupplierID, OrderDate, TotalCost, PaymentTerms)
            VALUES (@SupID, GETDATE(), @Cost, 'Net 30');
            SET @POID = SCOPE_IDENTITY();

            -- Create Batch (Received 0 initially)
            INSERT INTO Inventory.MaterialBatches (MaterialID, PurchaseOrderID, QuantityReceived, CurrentStockLevel)
            VALUES (@MatID, @POID, 0, 0);
            
            PRINT 'Created PO #' + CAST(@POID AS VARCHAR) + ' for Material ' + CAST(@MatID AS VARCHAR);
            
            SET @TotalCost = @TotalCost + @Cost;
            FETCH NEXT FROM reorder_cursor INTO @MatID, @SupID, @Qty, @Cost;
        END
        
        CLOSE reorder_cursor;
        DEALLOCATE reorder_cursor;
    END
    
    DROP TABLE #ReorderRecommendations;
END;
GO
-- CALCULATE SALES ORDER TOTAL
CREATE OR ALTER PROCEDURE Sales.sp_CalcSalesOrderTotal 
    @SalesOrderID INT
AS
BEGIN
    SELECT 
        @SalesOrderID AS OrderID, 
        SUM(QuantityOrdered * UnitPrice) AS TotalRevenue
    FROM Sales.SalesOrderItems
    WHERE SalesOrderID = @SalesOrderID;
END;
GO

-- ADD NEW MATERIAL BATCH (Inventory Update)
CREATE OR ALTER PROCEDURE Inventory.sp_AddMaterialBatch
    @MaterialID INT,
    @PurchaseOrderID INT,
    @Qty FLOAT
AS
BEGIN
    -- Record the batch
    INSERT INTO Inventory.MaterialBatches (MaterialID, PurchaseOrderID, QuantityReceived, CurrentStockLevel)
    VALUES (@MaterialID, @PurchaseOrderID, @Qty, @Qty);

    -- Update main inventory stock
    UPDATE Inventory.RawMaterials
    SET StockLevel = StockLevel + @Qty
    WHERE MaterialID = @MaterialID;
END;
GO

-- MONTHLY SALES REPORT
CREATE OR ALTER PROCEDURE Sales.sp_MonthlySalesReport 
    @Year INT, 
    @Month INT
AS
BEGIN
    SELECT SUM(soi.QuantityOrdered * soi.UnitPrice) AS TotalSales
    FROM Sales.SalesOrders so 
    JOIN Sales.SalesOrderItems soi ON so.SalesOrderID = soi.SalesOrderID
    WHERE YEAR(so.OrderDate) = @Year AND MONTH(so.OrderDate) = @Month;
END;
GO

-----------------
-- 1. Create Audit Table
BEGIN
    CREATE TABLE Sales.OrderAudit (
        AuditID INT IDENTITY(1,1) PRIMARY KEY,
        SalesOrderID INT,
        ActionType VARCHAR(20),  -- INSERT, UPDATE, DELETE
        OldRevenue DECIMAL(18,2),
        NewRevenue DECIMAL(18,2),
        ChangedBy VARCHAR(100),
        ChangedDate DATETIME DEFAULT GETDATE(),
        ChangeDetails NVARCHAR(MAX)
    );
END
GO

-- 2. Trigger for INSERT
CREATE OR ALTER TRIGGER Sales.trg_Order_Insert_Audit
ON Sales.SalesOrders
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Sales.OrderAudit (SalesOrderID, ActionType, NewRevenue, ChangedBy, ChangeDetails)
    SELECT i.SalesOrderID,'INSERT',i.TotalRevenue,SYSTEM_USER,
    'New order created for Client ID: ' + CAST(i.ClientID AS NVARCHAR)
    FROM inserted i;
END;
GO

-- 3. Trigger for UPDATE
CREATE OR ALTER TRIGGER Sales.trg_Order_Update_Audit
ON Sales.SalesOrders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Sales.OrderAudit (SalesOrderID, ActionType, OldRevenue, NewRevenue, ChangedBy, ChangeDetails)
    SELECT i.SalesOrderID,'UPDATE',d.TotalRevenue,i.TotalRevenue,
        SYSTEM_USER,
        CASE 
            WHEN d.TotalRevenue <> i.TotalRevenue 
            THEN 'Revenue changed from ' + CAST(d.TotalRevenue AS NVARCHAR) + ' to ' + CAST(i.TotalRevenue AS NVARCHAR)
            ELSE 'Order details updated'
        END
    FROM inserted i
    JOIN deleted d ON i.SalesOrderID = d.SalesOrderID;
END;
GO

-- 4. Trigger for DELETE
CREATE OR ALTER TRIGGER Sales.trg_Order_Delete_Audit
ON Sales.SalesOrders
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO Sales.OrderAudit (SalesOrderID, ActionType, OldRevenue, ChangedBy, ChangeDetails)
    SELECT 
        d.SalesOrderID,'DELETE',d.TotalRevenue,SYSTEM_USER,'Order deleted'
    FROM deleted d;
END;
GO

BACKUP DATABASE Furniture16
TO DISK = 'C:\DailyBackup.bak' 
WITH INIT;
