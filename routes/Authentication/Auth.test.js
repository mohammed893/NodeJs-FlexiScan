const request = require('supertest');
const app = require('../../app');
const { pool } = require('../../models/configrations');

const doctorRegisterSuccess = {
    fullname: 'New Doctor',
    email: 'newdoctor@example.com',
    password: 'newPassword',
    Date_of_birth: '1990-01-01',
    Gender: 'M',
    PhoneNumber: '123456789',
    Age: 34,
    Hospital: 'Example Hospital',
    nationalID: '7925728',
    verification: 'verificationImageUrl',
    type: 'd'
};

const patientRegisterSuccess = {
    fullname: 'New Patient',
    email: 'newpatient@example.com',
    password: 'newPassword',
    Date_of_birth: '1995-05-05',
    Gender: 'F',
    PhoneNumber: '987654321',
    Age: 29,
    Address: 'Patient Address',
    nationalID: '240135',
    follow_up: false,
    type: 'p'
};
const doctorLoginSuccess = {
    email: doctorRegisterSuccess.email,
    password: doctorRegisterSuccess.password,
    type: doctorRegisterSuccess.type
};

const doctorLoginFails = {
    email: 'doctor@example.com',
    password: 'invalidPassword',
    type: 'd'
};

const patientLoginSuccess = {
    email: patientRegisterSuccess.email,
    password: patientRegisterSuccess.password,
    type: patientRegisterSuccess.type
};

const patientLoginFails = {
    email: 'patient@example.com',
    password: 'invalidPassword',
    type: 'p'
};

beforeAll(async () => {
    await pool.query(`DELETE FROM doctors WHERE email = $1`, [doctorRegisterSuccess.email]);
    await pool.query(`DELETE FROM patients WHERE email = $1`, [patientRegisterSuccess.email]);

    await pool.query(
        `INSERT INTO doctors (full_name, email, PASSWORD, date_of_birth, gender, phone_number, age, hospital, national_id, verification_image_url)
        VALUES ($1, $2, crypt($3, gen_salt('bf')), $4, $5, $6, $7, $8, $9, $10);`,
        [
        doctorRegisterSuccess.fullname,
        doctorRegisterSuccess.email,
        doctorRegisterSuccess.password,
        doctorRegisterSuccess.Date_of_birth,
        doctorRegisterSuccess.Gender,
        doctorRegisterSuccess.PhoneNumber,
        doctorRegisterSuccess.Age,
        doctorRegisterSuccess.Hospital,
        doctorRegisterSuccess.nationalID,
        doctorRegisterSuccess.verification
    ]
    );

    await pool.query(
        `INSERT INTO patients (full_name, email, PASSWORD, date_of_birth, gender, phone_number, follow_up)
        VALUES ($1, $2, crypt($3, gen_salt('bf')), $4, $5, $6, $7);`,
        [
        patientRegisterSuccess.fullname,
        patientRegisterSuccess.email,
        patientRegisterSuccess.password,
        patientRegisterSuccess.Date_of_birth,
        patientRegisterSuccess.Gender,
        patientRegisterSuccess.PhoneNumber,
        patientRegisterSuccess.follow_up
    ]
    );
}); 

describe('Auth Controller', () => {
    describe('POST /auth/register', () => {
        it('should return 201 for valid doctor registration', async () => {
            const response = await request(app)
                .post('/auth/register')
                .send(doctorRegisterSuccess);
            console.log('check');
            expect(response.status).toBe(201); // 201
            expect(response.body.message).toContain('Doctor registered successfully');
        });

        it('should return 201 for valid patient registration', async () => {
            const response = await request(app)
                .post('/auth/register')
                .send(patientRegisterSuccess);
            expect(response.status).toBe(201); //201
            expect(response.body.message).toContain('Patient registered successfully');
        });
    });

    describe('POST /auth/login', () => {
        it('should return 200 for valid doctor credentials', async () => {
            const response = await request(app)
                .post('/auth/login')
                .send(doctorLoginSuccess);
            expect(response.status).toBe(200); // 200
            expect(response.body).toHaveProperty('token');
        });

        it('should return 401 for invalid doctor credentials', async () => {
            const response = await request(app)
                .post('/auth/login')
                .send(doctorLoginFails);
            expect(response.status).toBe(401);
            expect(response.body.message).toBe('Invalid email or password');
        });

        it('should return 200 for valid patient credentials', async () => {
            const response = await request(app)
                .post('/auth/login')
                .send(patientLoginSuccess);
            expect(response.status).toBe(200); // 200
            expect(response.body).toHaveProperty('token');
        });

        it('should return 401 for invalid patient credentials', async () => {
            const response = await request(app)
                .post('/auth/login')
                .send(patientLoginFails);
            expect(response.status).toBe(401);
            expect(response.body.message).toBe('Invalid email or password');
        });
    });
});

afterAll(async () => {
    await pool.query(`DELETE FROM doctors WHERE email = $1`, [doctorRegisterSuccess.email]);
    await pool.query(`DELETE FROM patients WHERE email = $1`, [patientRegisterSuccess.email]);
    await pool.end();
});
