const request = require('supertest');
const app = require('../../app');
const { pool } = require('../../models/configrations');
const jwt = require('jsonwebtoken');
require('dotenv').config();

describe('Auth Controller', () => {
    const loginSuccess = {
        email: 'doctor@example.com',
        password: 'validPassword',
        type: 'd'
    }

    const loginFails = {
        email: 'doctor@example.com',
        password: 'invalidPassword',
        type: 'd'
    }
    
    const registerSuccess = {
        fullname: 'New Doctor',
        email: 'newdoctor@example.com',
        password: 'newPassword',
        Date_of_birth: '1990-01-01',
        Gender: 'M',
        PhoneNumber: '123456789',
        Age: 34,
        Hospital: 'Example Hospital',
        nationalID: '12345678901234',
        verification: 'verificationImageUrl',
        type: 'd'
    }

    const registerFails = {
        fullname: 'New Doctor',
        email: 'newdoctor@example.com',
        password: 'newPassword',
        Date_of_birth: '1990-01-01',
        Gender: 'M',
        PhoneNumber: '123456789',
        Age: 34,
        Hospital: 'Example Hospital',
        nationalID: '12345678901234',
        verification: 'verificationImageUrl',
        type: 'd'
    }

    beforeAll(async () => {
        await pool.query(
            `INSERT INTO doctors (fullname, email, password, Date_of_birth, Gender, PhoneNumber, Age, Hospital, nationalID, verification, type)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
            [
                registerDoctor.fullname,
                registerDoctor.email,
                registerDoctor.password,
                registerDoctor.Date_of_birth,
                registerDoctor.Gender,
                registerDoctor.PhoneNumber,
                registerDoctor.Age,
                registerDoctor.Hospital,
                registerDoctor.nationalID,
                registerDoctor.verification,
                registerDoctor.type
            ]
        );

        await pool.query(
            `INSERT INTO patients (fullname, email, password, Date_of_birth, Gender, PhoneNumber, Age, Address, nationalID, type)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
            [
                registerPatient.fullname,
                registerPatient.email,
                registerPatient.password,
                registerPatient.Date_of_birth,
                registerPatient.Gender,
                registerPatient.PhoneNumber,
                registerPatient.Age,
                registerPatient.Address,
                registerPatient.nationalID,
                registerPatient.type
            ]
        );
    });

    // Login Test
    describe('POST /auth/login', () => {
        it('should return 200 for valid doctor credentials', async () => {
            const response = await request(app)
                .post('/auth/login')
                .send(loginSuccess)
            expect(response.status).toBe(200);
            expect(response.body).toHaveProperty('token');
        });

        it('should return 401 for invalid credentials', async () => {
            const response = await request(app)
                .post('/auth/login')
                .send(loginFails)
            expect(response.status).toBe(401);
            expect(response.body.message).toBe('Invalid email or password');
        });
    });

    // Register Test
    describe('POST /auth/register', () => {
        it('should return 201 for valid registration', async () => {
            const token = jwt.sign({ id: 1 }, process.env.ACCESS_TOKEN_SECRET); 
            const response = await request(app)
                .post('/auth/register')
                .set('Authorization', `Bearer ${token}`)
                .send(registerSuccess)
            expect(response.status).toBe(201);
            expect(response.body.message).toContain('Doctor registered successfully');
        });

        it('should return 403 for invalid token', async () => {
            const response = await request(app)
                .post('/auth/register')
                .set('Authorization', `Bearer invalidToken`)
                .send(registerFails)
            expect(response.status).toBe(403)
            expect(response.body.message).toBe('Invalid or expired token');
        });
    });
});

afterAll(async () => {
    await pool.query(`DELETE FROM doctors WHERE email = $1 AND type = 'd'`, [registerDoctor.email]);
    await pool.query(`DELETE FROM patients WHERE email = $1 AND type = 'p'`, [registerPatient.email]);
    await pool.end();
});
