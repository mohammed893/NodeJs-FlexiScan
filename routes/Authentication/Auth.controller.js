const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const { pool, database } = require('../../models/configrations');

const login = async (req, res) => {
    const email = req.body.email;
    const password = req.body.password;
    const isDoctor = req.body.type === 'd';

    console.log(req.body);

    const connection = await pool.connect();
    try {
        if (isDoctor) {
            const result = await connection.query('SELECT doctor_id FROM doctors WHERE email = $1  AND PASSWORD = crypt($2, PASSWORD);', [email, password]);
            
            // Check if the doctor exists
            if (result.rows.length === 0) {
                return res.status(401).json({ status: 'error', message: 'Invalid email or password' });
            }
            
            const doctor = result.rows[0];
            // Compare the provided password with the hashed password in the database
            const isMatch = await bcrypt.compare(password, doctor.password);

            // If the passwords don't match, return an error
            if (!isMatch) {
                return res.status(401).json({ status: 'error', message: 'Invalid email or password' });
            }

            // Generate a JWT token for the authenticated doctor
            const token = jwt.sign({ id: doctor.doctor_id }, process.env.ACCESS_TOKEN_SECRET, { expiresIn: '1h' });
            console.log("Login successful for doctor:", doctor.doctor_id);
            res.status(200).json({ status: 'success', id: doctor.doctor_id,'token': token });

        } else {
            const result = await connection.query('SELECT patient_id FROM patients WHERE email = $1 AND PASSWORD = crypt($2, PASSWORD);', [email, password]);

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
            res.status(200).json({ status: 'success', id: patient.patient_id, 'token': token });
        }

    // Log any unexpected errors and return a 500 response
    } catch (err) {
        console.error("Error in login:", err);
        res.status(500).json({ status: 'error', message: 'Internal server error' });
    } finally {
        connection.release();
    }
};


const register = async (req, res) => {
    const { fullname, email, password, Date_of_birth, Gender, PhoneNumber, Age, Hospital, nationalID, verification, type } = req.body;
    const token = req.headers.authorization?.split(" ")[1]; // Extract the token from the Authorization header

    // Verify the validity of the token
    jwt.verify(token, process.env.ACCESS_TOKEN_SECRET, async (err) => {
        if (err) {
            console.log(err);
            return res.status(403).json({ status: 'error', message: 'Invalid or expired token' }); // Return error if token is invalid
        }

        const connection = await pool.connect();
        try {
            // Determine the table name based on user type
            const tableName = type === 'd' ? 'doctors' : 'patients';
            const hashedPassword = await bcrypt.hash(password, 10); // Hash the password 

            // Insert data into the appropriate table
            if (tableName === 'doctors') {
                await connection.query(
                    `INSERT INTO doctors (full_name, email, PASSWORD, date_of_birth, gender, phone_number, age, hospital, national_id, verification_image_url)
                    VALUES ($1, $2, crypt($3, gen_salt('bf')), $4, $5, $6, $7, $8, $9, $10);`,
                    [fullname, email, hashedPassword, Date_of_birth, Gender, PhoneNumber, Age, Hospital, nationalID, verification]
                );
                console.log("Doctor registered successfully:", fullname);
            } else {
                await connection.query(
                    `INSERT INTO patients (full_name, email, PASSWORD, date_of_birth, gender, phone_number, follow_up)
                    VALUES ($1, $2, crypt($3, gen_salt('bf')), $4, $5, $6, $7);`,
                    [fullname, email, hashedPassword, Date_of_birth, Gender, PhoneNumber, verification] 
                );
                console.log("patient registered successfully:", fullname);
            }

            // registered Successfully
            res.status(201).json({ status: 'success', message: `${type === 'd' ? 'Doctor' : 'Patient'} registered successfully` });
        } catch (err) {
            console.error("Error in registration:", err);
            res.status(500).json({ status: 'error', message: 'Internal server error' }); 
        } finally {
            connection.release(); 
        }
    });
};

module.exports = {
    login,
    register
}