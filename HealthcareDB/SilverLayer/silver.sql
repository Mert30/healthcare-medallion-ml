-- Silver Layer: Transform and enrich data from the Bronze Layer


-- Select current DB
USE HealthcareDB 


-- Create Silver tables

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'SilverPatients')
    DROP TABLE SilverPatients;
CREATE TABLE SilverPatients (
    patient_id INT PRIMARY KEY,
    full_name NVARCHAR(255),
    gender NVARCHAR(10),
    birth_date DATE,
    patient_age INT,
    city NVARCHAR(50),
    blood_type NVARCHAR(10),
    insurance_provider NVARCHAR(20),
    registration_date DATE
);

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'SilverDoctors')
    DROP TABLE SilverDoctors;
CREATE TABLE SilverDoctors (
    doctor_id INT PRIMARY KEY,
    doctor_name NVARCHAR(255),
    specialization NVARCHAR(50),
    hospital_wing NVARCHAR(5),
    hire_date DATE
);

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'SilverAppointments')
    DROP TABLE SilverAppointments;
CREATE TABLE SilverAppointments (
    appointment_id INT PRIMARY KEY,
    patient_id INT,
    doctor_id INT,
    appointment_date DATE,
    consultation_fee DECIMAL(10, 2),
    status NVARCHAR(50)
);

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'SilverLabResults')
    DROP TABLE SilverLabResults;
CREATE TABLE SilverLabResults (
    test_id INT PRIMARY KEY,
    appointment_id INT,
    test_name NVARCHAR(20),
    test_value DECIMAL(10, 2),
    test_status VARCHAR(20),
    unit NVARCHAR(50),
    is_abnormal VARCHAR(5)
);

-- Transform and load data into Silver tables

-- Table1: SilverPatients 

INSERT INTO SilverPatients
SELECT
    patient_id,
    full_name,
    gender,
    birth_date,
    DATEDIFF(YEAR, birth_date, GETDATE()) AS patient_age,
    city,
    blood_type,
    insurance_provider,
    registration_date
FROM
(
    SELECT
        patient_id,
        full_name,

        CASE 
            WHEN gender IN ('M','Male','male','MALE') THEN 'Male'
            WHEN gender IN ('F','Female','female','FEMALE') THEN 'Female'
            ELSE 'Unknown'
        END AS gender,

        COALESCE(
            TRY_CONVERT(DATE, birth_date,120),
            TRY_CONVERT(DATE, birth_date,103),
            TRY_CONVERT(DATE, birth_date)
        ) AS birth_date,

        CONCAT(
            CASE 
                WHEN LEFT(TRIM(city COLLATE Turkish_CI_AS),1) IN ('i','ı') THEN 'İ'
                ELSE UPPER(LEFT(TRIM(city COLLATE Turkish_CI_AS),1))
            END,
            SUBSTRING(LOWER(TRIM(city COLLATE Turkish_CI_AS)),2,LEN(city))
        ) AS city,

        ISNULL(blood_type,'Unknown') AS blood_type,

        insurance_provider,

        COALESCE(
            TRY_CONVERT(DATE, registration_date,120),
            TRY_CONVERT(DATE, registration_date,103),
            TRY_CONVERT(DATE, registration_date)
        ) AS registration_date,

        ROW_NUMBER() OVER (
            PARTITION BY patient_id
            ORDER BY 
                COALESCE(
                    TRY_CONVERT(DATE, registration_date,120),
                    TRY_CONVERT(DATE, registration_date,103),
                    TRY_CONVERT(DATE, registration_date)
                ) DESC
        ) AS rn

    FROM BronzePatients
) t
WHERE rn = 1

---------------------------------------------------------------------------------------------------------


-- Table2: SilverDoctors

INSERT INTO SilverDoctors
SELECT 
    doctor_id,
    doctor_name,
    CASE 
        WHEN specialization = 'Cardio' THEN 'Cardiology'
        WHEN specialization = 'Neuro' THEN 'Neurology'
        WHEN specialization = 'Ortho' THEN 'Orthopedics'
        ELSE specialization
    END AS specialization,
    UPPER(TRIM(hospital_wing)) AS hospital_wing,
    COALESCE(
        TRY_CONVERT(DATE, hire_date, 120),
        TRY_CONVERT(DATE, hire_date, 103),
        TRY_CONVERT(DATE, hire_date)
    ) AS hire_date
FROM BronzeDoctors

---------------------------------------------------------------------------------------------------------


-- Table3: SilverAppointments

INSERT INTO SilverAppointments
SELECT
    appointment_id,
    patient_id,
    doctor_id,
    appointment_date,
    consultation_fee,
    status
FROM
(
    SELECT
        appointment_id,
        patient_id,
        doctor_id,
        COALESCE(
            TRY_CONVERT(DATE, appointment_date,120),
            TRY_CONVERT(DATE, appointment_date,103),
            TRY_CONVERT(DATE, appointment_date)
        ) AS appointment_date,
        consultation_fee,
        status,
        ROW_NUMBER() OVER (
            PARTITION BY appointment_id
            ORDER BY appointment_date
        ) AS rn
    FROM BronzeAppointments
) t
WHERE rn = 1

----------------------------------------------------------------------------------------------------------


-- Table4: SilverLabResults

INSERT INTO SilverLabResults
(
    test_id,
    appointment_id,
    test_name,
    test_value,
    test_status,
    unit,
    is_abnormal
)
SELECT
    test_id,
    appointment_id,
    test_name,
    test_value,
    test_status,
    unit,
    is_abnormal
FROM
(
    SELECT
        test_id,
        appointment_id,
        test_name,
        
        CASE 
            WHEN TRY_CAST(test_value AS DECIMAL(10,2)) IS NOT NULL THEN
                CASE test_name
                    WHEN 'Blood Sugar' THEN
                        CASE unit
                            WHEN 'mg/dL' THEN TRY_CAST(test_value AS DECIMAL(10,2)) / 18
                            WHEN 'mmol/L' THEN TRY_CAST(test_value AS DECIMAL(10,2))
                            ELSE NULL
                        END
                    WHEN 'Cholesterol' THEN
                        CASE unit
                            WHEN 'mg/dL' THEN TRY_CAST(test_value AS DECIMAL(10,2)) / 38.67
                            WHEN 'mmol/L' THEN TRY_CAST(test_value AS DECIMAL(10,2))
                            ELSE NULL
                        END
                    WHEN 'Hemoglobin' THEN
                        CASE unit
                            WHEN 'g/dL' THEN TRY_CAST(test_value AS DECIMAL(10,2)) * 0.1553
                            ELSE NULL
                        END
                    WHEN 'Vitamin D' THEN
                        CASE unit
                            WHEN 'nmol/L' THEN TRY_CAST(test_value AS DECIMAL(10,2)) / 1000
                            WHEN 'ng/mL' THEN (TRY_CAST(test_value AS DECIMAL(10,2)) * 2.5) / 1000
                            ELSE NULL
                        END
                    ELSE NULL
                END
            ELSE NULL
        END AS test_value,
        
        'mmol/L' AS unit,

        CASE 
            WHEN test_value = 'Pending' THEN 'pending'
            WHEN test_value = 'Error' THEN 'error'
            ELSE 'Completed'
        END AS test_status,

        is_abnormal,
        
        ROW_NUMBER() OVER (
            PARTITION BY test_id
            ORDER BY appointment_id
        ) AS rn
    FROM BronzeLabResults
) t
WHERE rn = 1;