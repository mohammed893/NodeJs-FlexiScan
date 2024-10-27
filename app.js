const express = require('express');
const {router} = require('./routes/Authentication/Auth');
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

module.exports = app;

