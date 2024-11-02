const {pool} = require('../../models/configrations');

// Get all Patients
const getAllPatients = async (req, res) => {
    try {
        const allPatients = await pool.query('SELECT * FROM patients');
        res.status(200).json(allPatients.rows);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to retrieve Patients' });
    }
};

// Get a patient
const getPatient = async (req, res) => {
    const patient_id = req.userID; // get id from token 
    console.log(patient_id)
    try {
        const patient = await pool.query('SELECT * FROM patients WHERE patient_id = $1', [patient_id]);
        if (patient.rows.length === 0) {
            return res.status(404).json({ error: 'patient not found' });
        }
        res.status(200).json(patient.rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to retrieve patient' });
    }
};

// create a patient 
const createPatient = async (req, res) =>{
    const { fullname, email, password, Date_of_birth, Gender, PhoneNumber, follow_up } = req.body;
    try {
        // check if the doctor already exists
        const checkemailQuery = `SELECT email FROM patients WHERE email = $1`;
        const existingpatient = await pool.query(checkemailQuery, [email]);
        if (existingpatient.rows.length > 0) {
            return res.status(400).json({ status: 'error', message: 'patient already exists' });
        }

        const newPatient = await pool.query(`INSERT INTO patients (full_name, email, PASSWORD, date_of_birth, gender, phone_number, follow_up)
                VALUES ($1, $2 ,crypt($3, gen_salt('bf')), $4, $5, $6, $7)RETURNING *;`,
                [fullname, email, password, Date_of_birth, Gender, PhoneNumber, follow_up])
        console.log('patient created Successfully', fullname)
        return res.status(201).json(newPatient.rows[0])
        
    } catch (err) {
        res.status(500).json({ error: 'Failed to create patient' });
    }
    
}

//Delete a patient 
const deletePatient = async (req, res) => {
    const patient_id = req.userID;
    try {
        const patientdeleted = await pool.query('DELETE FROM patients WHERE patient_id = $1', [patient_id]);
        if (patientdeleted.rowCount === 0) { 
            return res.status(404).json({ error: 'patient not found' });
        }
        return res.status(200).json({ message: 'patient deleted successfully' });
    } catch (err) { 
        console.error(err);
        res.status(500).json({ error: 'Failed to delete patient' });
    }
};

//Update a patient 
const updatePatient = async (req, res) => {
    const patient_id = req.userID;
    const updates = req.body; 

  // If no data is provided to update, return an error
    if (Object.keys(updates).length === 0) {
        return res.status(400).json({ error: 'No datas to update' });
    }

  // Build dynamic SQL query
    const setClause = [];
    const values = [];

  // Add each updated field to the SQL query
    for (const key in updates) {
        setClause.push(`${key} = $${values.length + 1}`); // Add update field
        values.push(updates[key]);
    }

    values.push(patient_id); 

    try {
        const result = await pool.query( `UPDATE patients SET ${setClause.join(', ')} WHERE patient_id = $${values.length} RETURNING *`, values); 
        if (result.rows.length === 0) {
        return res.status(404).json({ error: 'patient not found' });
    }
        res.status(200).json(result.rows[0]); 
    } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to update patient' });
}
};

module.exports = {
    getAllPatients,
    getPatient,
    deletePatient,
    updatePatient,
    createPatient
} 
