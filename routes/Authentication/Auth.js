const express = require('express');
const router = express.Router();
const {Login} = require('./Auth.controller');

router.get('/login' , Login);


module.exports = router;