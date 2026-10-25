USE MicrocontrollerFirm;

-- 1. Manufacturer Analysis
SELECT
    man.CompanyName AS Manufacturer,
    COUNT(m.MicrocontrollerID) AS TotalModels,
    MAX(m.ClockSpeedMHz) AS MaxClockSpeed_MHz,
    AVG(m.CoreCount) AS AvgCoreCount,
    AVG(m.FlashMemoryKB) AS AvgFlashMemory_KB,
    AVG(m.PowerConsumptionMW) AS AvgPowerConsumption_mW
FROM Manufacturers man
JOIN Microcontrollers m ON man.ManufacturerID = m.ManufacturerID
GROUP BY man.CompanyName;

-- 2. Microcontrollers with Below-Average Voltage Stability
SELECT
    m.ModelName AS MicrocontrollerModel,
    tl.LabName AS TestingLab,
    tl.City AS LabCity,
    qt.TestDate AS TestDate,
    qt.VoltageStabilityPercent AS VoltageStability,
    qt.TemperatureResistanceC AS TemperatureResistance_C
FROM QualityTests qt
JOIN Microcontrollers m ON qt.MicrocontrollerID = m.MicrocontrollerID
JOIN TestingLabs tl ON qt.LabID = tl.LabID
WHERE qt.VoltageStabilityPercent < (SELECT AVG(VoltageStabilityPercent) FROM QualityTests)
ORDER BY qt.VoltageStabilityPercent ASC;

-- 3. Integrated Sensors per Model with Their Supplier
SELECT
    m.ModelName AS MicrocontrollerModel,
    s.SensorName AS SensorName,
    s.SensorType AS SensorType,
    ms.IntegrationLevel AS IntegrationLevel,
    ss.CompanyName AS SensorSupplier
FROM MicrocontrollerSensors ms
JOIN Microcontrollers m ON ms.MicrocontrollerID = m.MicrocontrollerID
JOIN Sensors s ON ms.SensorID = s.SensorID
JOIN SensorsSuppliers ss ON s.SupplierID = ss.SupplierID
ORDER BY m.ModelName, ms.IntegrationLevel DESC;

-- 4. Wireless Protocols and Supported Microcontroller Count
SELECT
    cp.ProtocolName AS WirelessProtocol,
    cp.MaxSpeedMbps AS MaxSpeed_Mbps,
    COUNT(mp.MicrocontrollerID) AS SupportedMicrocontrollerCount
FROM CommunicationProtocols cp
JOIN MicrocontrollerProtocols mp ON cp.ProtocolID = mp.ProtocolID
WHERE cp.Wireless = 1
GROUP BY cp.ProtocolName, cp.MaxSpeedMbps;

-- 5. Stable/Beta Firmware Versions with Age in Days
SELECT
    m.ModelName AS MicrocontrollerModel,
    fv.VersionName AS FirmwareVersion,
    fv.StabilityStatus AS StabilityStatus,
    fv.ReleaseDate AS ReleaseDate,
    DATEDIFF(CURDATE(), fv.ReleaseDate) AS DaysSinceRelease
FROM FirmwareVersions fv
JOIN Microcontrollers m ON fv.MicrocontrollerID = m.MicrocontrollerID
WHERE fv.StabilityStatus IN ('Stable', 'Beta')
ORDER BY fv.ReleaseDate DESC;

-- 6. Revenue Generated per Model
SELECT
    m.ModelName AS MicrocontrollerModel,
    SUM(od.Quantity) AS TotalUnitsSold,
    CAST(AVG(od.UnitPrice) AS DECIMAL(10,2)) AS AvgUnitPrice,
    CAST(SUM(od.UnitPrice * od.Quantity * (1 - (od.DiscountPercent / 100.0))) AS DECIMAL(10,2)) AS TotalRevenueGenerated
FROM OrderDetails od
JOIN Microcontrollers m ON od.MicrocontrollerID = m.MicrocontrollerID
GROUP BY m.ModelName;

-- 7. Inventory Status by Category
SELECT
    c.CategoryName AS Category,
    COUNT(m.MicrocontrollerID) AS ProductTypesCount,
    SUM(m.UnitsInStock) AS TotalUnitsInStock,
    CASE
        WHEN SUM(m.UnitsInStock) = 0 THEN 'URGENT RESTOCK'
        WHEN SUM(m.UnitsInStock) < 150 THEN 'CRITICAL STOCK'
        ELSE 'OPTIMAL STOCK'
    END AS InventoryStatus
FROM Microcontrollers m
JOIN Categories c ON m.CategoryID = c.CategoryID
GROUP BY c.CategoryName;