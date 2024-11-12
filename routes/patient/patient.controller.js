const {pool} = require('../../models/configrations');

// Get all Patients
const getAllPatients = async (req, res) => {
    try {
        const allPatients = await pool.query('SELECT * FROM patients');
        return res.status(200).json(allPatients.rows);
    } catch (error) {
        console.error(error);
        return res.status(500).json({ error: 'Failed to retrieve Patients' });
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
        return res.status(200).json(patient.rows[0]);
    } catch (error) {
        console.error(error);
        return res.status(500).json({ error: 'Failed to retrieve patient' });
    }
};

//Delete a patient 
const deletePatient = async (req, res) => {
    const patient_id = req.userID;
    try {
        const patientdeleted = await pool.query('DELETE FROM patients WHERE patient_id = $1 RETURNING *', [patient_id]);
        if (patientdeleted.rowCount === 0) { 
            return res.status(404).json({ error: 'patient not found' });
        }
        return res.status(200).json({ message: 'patient deleted successfully' });
    } catch (err) { 
        console.error(err);
        return res.status(500).json({ error: 'Failed to delete patient' });
    }
};

// Update a patient
const updatePatient = async (req, res) => {
    const patient_id = req.userID;
    const updates = req.body;
    if (!patient_id) {
        return res.status(400).json({ error: 'Invalid patient ID' });
    }
    const allowedFields = ['full_name', 'email', 'PhoneNumber'];
    const setClause = [];
    const values = [];

    // Filter updates to include only allowed fields
    for (const key in updates) {
        if (allowedFields.includes(key)) {
            setClause.push(`${key} = $${values.length + 1}`);
            values.push(updates[key]);
        }
    }

    if (setClause.length === 0) {
        return res.status(400).json({ error: 'No valid fields provided for update' });
    }

    values.push(patient_id);

    try {
        const result = await pool.query(
            `UPDATE patients SET ${setClause.join(', ')} WHERE patient_id = $${values.length} RETURNING *`,
            values
        );

        // Check if the patient was found
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Patient not found' });
        }

        // Return the updated patient data
        return res.status(200).json(result.rows[0]);
    } catch (error) {
        console.error(error);
        return res.status(500).json({ error: 'Failed to update patient' });
    }
};

module.exports = {
    getAllPatients,
    getPatient,
    deletePatient,
    updatePatient
} 
