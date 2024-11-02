const express = require('express');
const {router} = require('./routes/Authentication/Auth');
const {doctorRouter} = require('./routes/Doctor/Doctors')
const {patientRouter} = require('./routes/patient/patient')
const cors = require('cors');
const morgan = require('morgan');

const app = express();
app.use(express.json());
require('dotenv').config();

app.use(cors({
    origin: 'http://localhost:5000'
}));

app.use(morgan('combined'));

app.use('/auth', router)
app.use('/doctors', doctorRouter )
app.use('/patients', patientRouter )

module.exports = app;
