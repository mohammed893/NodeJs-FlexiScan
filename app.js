const express = require('express');
const app = express();
const cors = require('cors');
const morgan = require('morgan');
const doctors = require("./routes/Doctor/Doctors");
const bodyParser = require('body-parser');
const auth = require('./routes/Authentication/Auth');

app.use(cors());
app.use(morgan(
    format = "combined",
 ));
app.use(bodyParser.json());
app.use('/doctors', doctors);
app.use ('/auth' , auth)

module.exports = app;