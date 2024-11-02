const express = require('express');
const patientRouter = express.Router();
const patientController = require('./patient.controller'); 
const { verifyToken } = require('../../middleware/verifyToken');

patientRouter.get('/', patientController.getAllPatients);
patientRouter.get('/profile', verifyToken, patientController.getPatient);
patientRouter.delete('/', verifyToken, patientController.deletePatient);
patientRouter.put('/', verifyToken, patientController.updatePatient);
patientRouter.post('/', patientController.createPatient);

module.exports = {patientRouter};
