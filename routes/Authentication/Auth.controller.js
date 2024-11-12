const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const { pool } = require('../../models/configrations');

const login = async (req, res) => {
    const email = req.body.email;
    const password = req.body.password;
    const isDoctor = req.body.type === 'd';

    console.log(req.body);

    const connection = await pool.connect();
    try {
        if (isDoctor) {
            const result = await connection.query('SELECT * FROM doctors WHERE email = $1;', [email]);

            if (result.rows.length === 0) {
                return res.status(401).json({ status: 'error', message: 'Invalid email or password' });
            }

            const doctor = result.rows[0];
            const isMatch = await bcrypt.compare(password, doctor.password);

            if (!isMatch) {
                return res.status(401).json({ status: 'error', message: 'Invalid email or password' });
            }

            const token = jwt.sign({ id: doctor.doctor_id }, process.env.ACCESS_TOKEN_SECRET, { expiresIn: '1h' });
            console.log("Login successful for doctor:", doctor.doctor_id);
            return res.status(200).json({ status: 'success', id: doctor.doctor_id, token: token });

        } else {
            const result = await connection.query('SELECT * FROM patients WHERE email = $1;', [email]);

            if (result.rows.length === 0) {
                return res.status(401).json({ status: 'error', message: 'Invalid email or password' });
            }

            const patient = result.rows[0];
            const isMatch = await bcrypt.compare(password, patient.password);

            if (!isMatch) {
                return res.status(401).json({ status: 'error', message: 'Invalid email or password' });
            }

            const token = jwt.sign({ id: patient.patient_id }, process.env.ACCESS_TOKEN_SECRET, { expiresIn: '1h' });
            console.log("Login successful for patient:", patient.patient_id);
            return res.status(200).json({ status: 'success', id: patient.patient_id, token: token });
        }

    } catch (err) {
        console.error("Error in login:", err);
        return res.status(500).json({ status: 'error', message: 'Internal server error' });
    } finally {
        connection.release();
    }
};

// Register Function
const register = async (req, res) => {
    const { fullname, email, password, Date_of_birth, Gender, PhoneNumber, Age, Hospital, nationalID, verification, available_days, type, working_hours, slot_duration, timezone, specialization, experience, follow_up, insurance_id } = req.body;
    const connection = await pool.connect();
    const followUpValue = follow_up || false ;
    try {
        const tableName = type === 'd' ? 'doctors' : 'patients';

        if (tableName === 'doctors') {
            const checkIdQuery = `SELECT national_id FROM doctors WHERE national_id = $1`;
            const checkIdResult = await connection.query(checkIdQuery, [nationalID]);

            if (checkIdResult.rows.length > 0) {
                return res.status(400).json({ status: 'error', message: 'National ID already exists for this doctor' });
            }
        }

        if (tableName === 'doctors') {
            await connection.query(
                `INSERT INTO doctors (full_name, email, PASSWORD, date_of_birth, gender, phone_number, age, hospital, national_id, verification_image_url, available_days, working_hours, slot_duration, timezone, specialization, experience)
                VALUES ($1, $2 ,crypt($3, gen_salt('bf')), $4, $5, $6, $7, $8, $9, $10, $11::jsonb, $12::jsonb, $13, $14, $15, $16)`,
                [fullname, email, password, Date_of_birth, Gender, PhoneNumber, Age, Hospital, nationalID, verification, available_days, working_hours, slot_duration, timezone, specialization, experience]
            );
            console.log("Doctor registered successfully:", fullname);
        } else {
            await connection.query(
                `INSERT INTO patients (full_name, email, PASSWORD, date_of_birth, gender, phone_number, follow_up, insurance_id)
                VALUES ($1, $2 ,crypt($3, gen_salt('bf')), $4, $5, $6, $7, $8);`,
                [fullname, email, password, Date_of_birth, Gender, PhoneNumber, followUpValue, insurance_id]
            );
            console.log("Patient registered successfully:", fullname);
        }

        const newToken = jwt.sign({ id: email }, process.env.ACCESS_TOKEN_SECRET, { expiresIn: '1h' });
        return res.status(201).json({ status: 'success', message: `${type === 'd' ? 'Doctor' : 'Patient'} registered successfully`, token: newToken });

    } catch (err) {
        console.error("Error in registration:", err);
        return res.status(500).json({ status: 'error', message: 'Internal server error' });
    } finally {
        connection.release();
    }
};

module.exports = {
    login,
    register
};
