const request = require('supertest');
const app = require('../../app');
const { pool } = require('../../models/configrations');
const jwt = require('jsonwebtoken');
const Test = require('supertest/lib/test');

beforeAll(async () => {
    const values = [
        'New Doctor',
        'newdoctor@example.com',
        'newPassword',
        '1990-01-01',
        'M',
        '123456789',
        34,
        'Example Hospital',
        '7925728',
        'verificationImageUrl',
    ]
    const result = await pool.query(`INSERT INTO doctors (full_name, email, PASSWORD, date_of_birth, gender, phone_number, age, hospital, national_id, verification_image_url)
                VALUES ($1, $2, crypt($3, gen_salt('bf')), $4, $5, $6, $7, $8, $9, $10) RETURNING *`, values);
    doctorId = result.rows[0].doctor_id;
    token = jwt.sign({ id: doctorId }, process.env.ACCESS_TOKEN_SECRET, { expiresIn: '1h' });
    console.log('Generated Token: ', token)
});


describe('Doctor Controller Tests', () => {
    // test getAllDoctors
    test('should return a list of all doctors from the test data', async () => {
        const response = await request(app)
            .get('/doctors');
        expect(response.status).toBe(200);
        expect(response.body.length).toBeGreaterThan(0);
        expect(response.body[0]).toHaveProperty('full_name');
    });


    // test getDoctor
    test('should return a specific doctor', async () => {
        const response = await request(app)
            .get('/doctors/profile')
            .set('Authorization', `Bearer ${token}`);
        console.log('Response for getDoctor:', response.body);
        expect(response.status).toBe(200);
    });

    // test updateDoctor
    test('should update doctor details', async () => {
        const updates = { full_name: 'doctor updeated' };
        const response = await request(app)
            .put('/doctors') 
            .send(updates)
            .set('Authorization', `Bearer ${token}`);
        expect(response.status).toBe(200);
        expect(response.body.full_name).toBe(updates.full_name);
    });

    // test deleteDoctor
    test('should delete a doctor', async () => {
        const response = await request(app)
            .delete('/doctors')
            .set('Authorization', `Bearer ${token}`);
        expect(response.status).toBe(200);
        expect(response.body).toEqual({ message: 'Doctor deleted successfully' });
    });
    // test delete when the doctor already exists
    test('should return 404 if doctor not found when deleting', async () => {
        await pool.query('DELETE FROM doctors'); 
        const response = await request(app)
            .delete('/doctors')
            .set('Authorization', `Bearer ${token}`);
        expect(response.status).toBe(404);
        expect(response.body).toEqual({ error: 'Doctor not found' });
    });

});

afterAll(async () => {
    await pool.query('DELETE FROM doctors');
    pool.end();
});