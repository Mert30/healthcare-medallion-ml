-- Bronze Layer: Create all tables for the HealthcareDB database and ingest raw data from CSV files

-- Select current DB
USE HealthcareDB

-- ===================================================
--                 Create Bronze tables
-- ===================================================


-- Patients Table

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'BronzePatients')
    DROP TABLE BronzePatients;
CREATE TABLE [dbo].[BronzePatients]
(
    [patient_id] INT NOT NULL,
    [full_name] NVARCHAR(255) NOT NULL,
    [gender] NVARCHAR(50) NOT NULL,
    [birth_date] NVARCHAR(50) NOT NULL,
    [city] NVARCHAR(100) NULL,
    [phone_number] NVARCHAR(20) NULL,
    [blood_type] NVARCHAR(10) NULL,
    [insurance_provider] NVARCHAR(255) NULL,
    [registration_date] NVARCHAR(50) NULL
)

-- Doctors Table

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'BronzeDoctors')
    DROP TABLE BronzeDoctors;
CREATE TABLE [dbo].[BronzeDoctors]
(
    [doctor_id] INT NOT NULL,
    [doctor_name] NVARCHAR(255) NOT NULL,
    [specialization] NVARCHAR(255) NOT NULL,
    [hospital_wing] NVARCHAR(100) NULL,
    [hire_date] NVARCHAR(50) NOT NULL
)

-- Lab Results Table

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'BronzeLabResults')
    DROP TABLE BronzeLabResults;
CREATE TABLE [dbo].[BronzeLabResults]
(
    [test_id] INT NOT NULL,
    [appointment_id] INT NOT NULL,
    [test_name] NVARCHAR(255) NOT NULL,
    [test_value] NVARCHAR(255) NOT NULL,
    [unit] NVARCHAR(50) NULL,
    [is_abnormal] NVARCHAR(10) NULL
)

-- Appointments Table

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'BronzeAppointments')
    DROP TABLE BronzeAppointments;
CREATE TABLE [dbo].[BronzeAppointments]
(
    [appointment_id] INT NOT NULL,
    [patient_id] INT NOT NULL,
    [doctor_id] INT NOT NULL,
    [appointment_date] NVARCHAR(50) NOT NULL,
    [status] NVARCHAR(50) NOT NULL,
    [visit_reason] NVARCHAR(255) NULL,
    [consultation_fee] DECIMAL(10, 2) NULL
)

------------------------------------------------------------------------------------------------------------------



-- ===========================================================================
--              Ingest raw data from CSV files into Bronze tables
-- ===========================================================================

-- Ingest patient data
BULK INSERT dbo.BronzePatients
FROM 'C:\Users\Casper\Desktop\DataScience\Kaggle\healthcare-medallion-ml\data\patients.csv'

WITH
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);


-- Ingest appointment data
BULK INSERT dbo.BronzeAppointments
FROM 'C:\Users\Casper\Desktop\DataScience\Kaggle\healthcare-medallion-ml\data\appointments.csv'

WITH
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);


-- Ingest doctors data
BULK INSERT dbo.BronzeDoctors
FROM 'C:\Users\Casper\Desktop\DataScience\Kaggle\healthcare-medallion-ml\data\doctors.csv'

WITH
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);


-- Ingest lab results data
BULK INSERT dbo.BronzeLabResults
FROM 'C:\Users\Casper\Desktop\DataScience\Kaggle\healthcare-medallion-ml\data\lab_results.csv'

WITH
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);