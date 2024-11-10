const request = require('supertest');
const app = require('../../app');
const { pool } = require('../../models/configrations');
const jwt = require('jsonwebtoken');
const Test = require('supertest/lib/test');

beforeAll(async () => {
    const values = [
        'New patient',
        'newpatient@example.com',
        'newPassword',
        '1990-01-01',
        'M',
        '123456789',
        false
    ]
    const result = await pool.query(`INSERT INTO patients (full_name, email, PASSWORD, date_of_birth, gender, phone_number, follow_up)
                VALUES ($1, $2 ,crypt($3, gen_salt('bf')), $4, $5, $6, $7)RETURNING *`, values);
    patientId = result.rows[0].patient_id;
    token = jwt.sign({ id: patientId }, process.env.ACCESS_TOKEN_SECRET, { expiresIn: '1h' });
    console.log('Generated Token: ', token)
});


describe('Doctor Controller Tests', () => {
    // test getAllPatient
    test('should return a list of all patients from the test data', async () => {
        const response = await request(app)
            .get('/patients');
        expect(response.status).toBe(200);
        expect(response.body[0]).toHaveProperty('full_name');
    });


    // test getPatient
    test('should return a specific patient', async () => {
        const response = await request(app)
            .get('/patients/profile')
            .set('Authorization', `Bearer ${token}`);
        expect(response.status).toBe(200);
    });

    // test updatePatient
    test('should update patient details', async () => {
        const updates = { full_name: 'patient updeated' };
        const response = await request(app)
            .put('/patients') 
            .send(updates)
            .set('Authorization', `Bearer ${token}`);
        expect(response.status).toBe(200);
        expect(response.body.full_name).toBe(updates.full_name);
    });

    // test deletePatient
    test('should delete a patient', async () => {
        const response = await request(app)
            .delete('/patients')
            .set('Authorization', `Bearer ${token}`);
        expect(response.status).toBe(200);
        expect(response.body).toEqual({ message: 'patient deleted successfully' });
    });
    // test delete when the patient already not exists
    test('should return 404 if doctor not found when deleting', async () => {
        await pool.query('DELETE FROM patients'); 
        const response = await request(app)
            .delete('/patients')
            .set('Authorization', `Bearer ${token}`);
        expect(response.status).toBe(404);
        expect(response.body).toEqual({ error: 'patient not found' });
    });

});

afterAll(async () => {
    await pool.query('DELETE FROM patients');
    pool.end();
});