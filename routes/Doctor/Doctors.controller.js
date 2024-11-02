const {pool} = require('../../models/configrations');

// Get all doctors
const getAllDoctors = async (req, res) => {
    try {
        const allDoctors = await pool.query('SELECT * FROM doctors');
        res.status(200).json(allDoctors.rows);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to retrieve doctors' });
    }
};

// Get a doctor
const getDoctor = async (req, res) => {
    const doctor_id = req.userID; // get id from token 
    console.log(doctor_id)
    try {
        const doctor = await pool.query('SELECT * FROM doctors WHERE doctor_id = $1', [doctor_id]);
        if (doctor.rows.length === 0) {
            return res.status(404).json({ error: 'Doctor not found' });
        }
        res.status(200).json(doctor.rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Failed to retrieve doctor' });
    }
};

// create a doctor 
const createDoctor = async (req, res) =>{
    const { fullname, email, password, Date_of_birth, Gender, PhoneNumber, Age, Hospital, nationalID, verification } = req.body;
    try {
        // check if the doctor already exists
        const checkIdQuery = `SELECT national_id FROM doctors WHERE national_id = $1`;
        const existingDoctor = await pool.query(checkIdQuery, [nationalID]);
        if (existingDoctor.rows.length > 0) {
            return res.status(400).json({ status: 'error', message: 'Doctor already exists' });
        }

        const newdoctor = await pool.query(`INSERT INTO doctors (full_name, email, PASSWORD, date_of_birth, gender, phone_number, age, hospital, national_id, verification_image_url)
                VALUES ($1, $2, crypt($3, gen_salt('bf')), $4, $5, $6, $7, $8, $9, $10) RETURNING *`,
                [fullname, email, password, Date_of_birth, Gender, PhoneNumber, Age, Hospital, nationalID, verification])
        console.log('Doctor created Successfully', fullname)
        return res.status(201).json(newdoctor.rows[0])
        
    } catch (err) {
        res.status(500).json({ error: 'Failed to create doctor' });
    }
    
}

//Delete a doctor 
const deleteDoctor = async (req, res) => {
    const doctor_id = req.userID;
    try {
        const doctorDeleted = await pool.query('DELETE FROM doctors WHERE doctor_id = $1', [doctor_id]);
        if (doctorDeleted.rowCount === 0) { 
            return res.status(404).json({ error: 'Doctor not found' });
        }
        return res.status(200).json({ message: 'Doctor deleted successfully' });
    } catch (err) { 
        console.error(err);
        res.status(500).json({ error: 'Failed to delete doctor' });
    }
};

//Update a doctor 
const updateDoctor = async (req, res) => {
    const doctor_id = req.userID;
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

    values.push(doctor_id); 

    try {
        const result = await pool.query( `UPDATE doctors SET ${setClause.join(', ')} WHERE doctor_id = $${values.length} RETURNING *`, values); // Execute the query
        if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Doctor not found' });
    }
        res.status(200).json(result.rows[0]); 
    } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to update doctor' });
}
};

module.exports = {
    getAllDoctors,
    getDoctor,
    deleteDoctor,
    updateDoctor,
    createDoctor
} 
