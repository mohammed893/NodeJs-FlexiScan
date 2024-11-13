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
    available_days:{
        "Monday": true,
        "Tuesday": true,
        "Wednesday": false,
        "Thursday": true,
        "Friday": true,
        "Saturday": false,
        "Sunday": false 
    }, 
    working_hours: {
        start: '09:00',
        end: '17:00'
    },
    slot_duration: 30,
    timezone: 'Africa/Cairo',
    specialization: 'Cardiology',
    experience: 10,
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
    type: 'p',
    insurance_id : '7464'
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
}); 

describe('Auth Controller', () => {
    describe('POST /auth/register', () => {
        test('should return 201 for valid doctor registration', async () => {
            const response = await request(app)
                .post('/auth/register')
                .send(doctorRegisterSuccess);
            console.log('check');
            expect(response.status).toBe(201); 
            expect(response.body.message).toContain('Doctor registered successfully');
        });

        test('should return 201 for valid patient registration', async () => {
            const response = await request(app)
                .post('/auth/register')
                .send(patientRegisterSuccess);
            expect(response.status).toBe(201);
            expect(response.body.message).toContain('Patient registered successfully');
        });
    });

    describe('POST /auth/login', () => {
        test('should return 200 for valid doctor credentials', async () => {
            const response = await request(app)
                .post('/auth/login')
                .send(doctorLoginSuccess);
            expect(response.status).toBe(200); 
            expect(response.body).toHaveProperty('token');
        });

        test('should return 401 for invalid doctor credentials', async () => {
            const response = await request(app)
                .post('/auth/login')
                .send(doctorLoginFails);
            expect(response.status).toBe(401);
            expect(response.body.message).toBe('Invalid email or password');
        });

        test('should return 200 for valid patient credentials', async () => {
            const response = await request(app)
                .post('/auth/login')
                .send(patientLoginSuccess);
            expect(response.status).toBe(200); 
            expect(response.body).toHaveProperty('token');
        });

        test('should return 401 for invalid patient credentials', async () => {
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
