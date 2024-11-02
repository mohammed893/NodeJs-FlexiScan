const express = require('express');
const doctorRouter = express.Router();
const doctorsController = require('./Doctors.controller');
const { verifyToken } = require('../../middleware/verifyToken');

doctorRouter.get('/', doctorsController.getAllDoctors);
doctorRouter.get('/profile', verifyToken, doctorsController.getDoctor);
doctorRouter.delete('/', verifyToken, doctorsController.deleteDoctor);
doctorRouter.put('/', verifyToken, doctorsController.updateDoctor);
doctorRouter.post('/', doctorsController.createDoctor);

module.exports = {doctorRouter};
