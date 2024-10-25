const express = require('express');
const router = express.Router();
const doctorsController = require('./Doctors.controller');
const {AuthToken} = require('../Authentication/Auth.controller');

router.get('/' ,doctorsController.getDoctor);

module.exports = router;
