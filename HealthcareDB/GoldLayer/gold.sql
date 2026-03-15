-- HealthcareDB - Gold Layer SQL Queries

/*

    Problem 1 =  Patient Risk / Readmission Prediction

    Necessary Gold tables:

        Patient summary: patient_id, age, gender, city, blood_type, insurance, total_appointments, last_appointment_date

        Lab aggregates: patient_id, test_name, avg_value, max_value, min_value, abnormal_count

        Appointment history: patient_id, doctor_id, visit_reason, status, appointment_date
*/

-- Create Patient Summary Table

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'GoldPatientSummary')
    DROP TABLE GoldPatientSummary;

-- GoldPatientFeatures tablosunu oluştur
CREATE TABLE GoldPatientFeatures
(
    patient_id INT PRIMARY KEY,
    full_name NVARCHAR(255),
    gender NVARCHAR(10),
    age INT,
    city NVARCHAR(100),
    blood_type NVARCHAR(10),
    insurance_provider NVARCHAR(255),
    total_appointments INT,
    last_appointment_date DATE,
    avg_consultation_fee DECIMAL(10,2),
    total_abnormal_labs INT,
    last_lab_abnormal BIT,
    num_doctors_seen INT,
    most_frequent_doctor_id INT,
    last_doctor_id INT,
    avg_days_between_appointments DECIMAL(10,2),
    lab_abnormal_ratio DECIMAL(5,2),
    has_cardiology_appointment BIT,
    has_dermatology_appointment BIT,
    has_neurology_appointment BIT,
    has_orthopedics_appointment BIT
);

-- GoldPatientFeatures tablosuna veri ekle
WITH AppointmentDiffs AS (
    SELECT
        patient_id,
        appointment_id,
        appointment_date,
        DATEDIFF(
            DAY,
            LAG(appointment_date) OVER (PARTITION BY patient_id ORDER BY appointment_date),
            appointment_date
        ) AS days_diff
    FROM SilverAppointments
),
PatientDoctorCounts AS (
    SELECT
        patient_id,
        doctor_id,
        COUNT(*) AS doctor_count,
        ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY COUNT(*) DESC) AS rn
    FROM SilverAppointments
    GROUP BY patient_id, doctor_id
),
LabAggregates AS (
    SELECT
        a.patient_id,
        COUNT(l.test_id) AS total_tests,
        SUM(CASE WHEN l.is_abnormal = 'True' THEN 1 ELSE 0 END) AS total_abnormal,
        MAX(CASE WHEN l.is_abnormal = 'True' THEN 1 ELSE 0 END) AS last_lab_abnormal
    FROM SilverAppointments a
    LEFT JOIN SilverLabResults l
        ON a.appointment_id = l.appointment_id
    GROUP BY a.patient_id
),
SpecializationFlags AS (
    SELECT
        a.patient_id,
        MAX(CASE WHEN d.specialization = 'Cardiology' THEN 1 ELSE 0 END) AS has_cardiology_appointment,
        MAX(CASE WHEN d.specialization = 'Dermatology' THEN 1 ELSE 0 END) AS has_dermatology_appointment,
        MAX(CASE WHEN d.specialization = 'Neurology' THEN 1 ELSE 0 END) AS has_neurology_appointment,
        MAX(CASE WHEN d.specialization = 'Orthopedics' THEN 1 ELSE 0 END) AS has_orthopedics_appointment
    FROM SilverAppointments a
    LEFT JOIN SilverDoctors d
        ON a.doctor_id = d.doctor_id
    GROUP BY a.patient_id
),
PatientAggregates AS (
    SELECT
        p.patient_id,
        p.full_name,
        p.gender,
        p.patient_age AS age,
        p.city,
        p.blood_type,
        p.insurance_provider,
        COUNT(a.appointment_id) AS total_appointments,
        MAX(a.appointment_date) AS last_appointment_date,
        AVG(a.consultation_fee) AS avg_consultation_fee,
        COALESCE(CAST(lab.total_abnormal AS INT),0) AS total_abnormal_labs,
        COALESCE(CAST(lab.last_lab_abnormal AS BIT),0) AS last_lab_abnormal,
        COUNT(DISTINCT a.doctor_id) AS num_doctors_seen,
        pd.doctor_id AS most_frequent_doctor_id,
        MAX(a.doctor_id) AS last_doctor_id,
        AVG(ad.days_diff) AS avg_days_between_appointments,
        CASE WHEN lab.total_tests > 0 THEN CAST(lab.total_abnormal AS DECIMAL)/lab.total_tests ELSE 0 END AS lab_abnormal_ratio,
        sf.has_cardiology_appointment,
        sf.has_dermatology_appointment,
        sf.has_neurology_appointment,
        sf.has_orthopedics_appointment
    FROM SilverPatients p
    LEFT JOIN SilverAppointments a
        ON p.patient_id = a.patient_id
    LEFT JOIN AppointmentDiffs ad
        ON a.appointment_id = ad.appointment_id
    LEFT JOIN LabAggregates lab
        ON p.patient_id = lab.patient_id
    LEFT JOIN PatientDoctorCounts pd
        ON p.patient_id = pd.patient_id AND pd.rn = 1
    LEFT JOIN SpecializationFlags sf
        ON p.patient_id = sf.patient_id
    GROUP BY 
        p.patient_id,
        p.full_name,
        p.gender,
        p.patient_age,
        p.city,
        p.blood_type,
        p.insurance_provider,
        pd.doctor_id,
        lab.total_abnormal,
        lab.total_tests,
        lab.last_lab_abnormal,
        sf.has_cardiology_appointment,
        sf.has_dermatology_appointment,
        sf.has_neurology_appointment,
        sf.has_orthopedics_appointment
)
INSERT INTO GoldPatientFeatures
SELECT *
FROM PatientAggregates;

